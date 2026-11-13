// SPDX-License-Identifier: MIT
package shapecapture

import (
	"bufio"
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	_ "modernc.org/sqlite" // pure Go, read-only
)

const (
	maxFileBytes  = 8 << 20
	maxLineBytes  = 1 << 20
	maxLinesRead  = 2000
	maxLinesKept  = 20
	maxSampleRows = 3
)

// ManifestField is one key a sample kept.
type ManifestField struct {
	Name string `json:"name"`
	Kind Kind   `json:"kind"`
}

// ManifestFile describes one written (or withheld) sample.
type ManifestFile struct {
	Source      string          `json:"source"`
	Output      string          `json:"output,omitempty"`
	Records     int             `json:"records"`
	Kept        []ManifestField `json:"keptFields"`
	DroppedKeys int             `json:"droppedKeyCount"`
	Withheld    string          `json:"withheld,omitempty"`
}

// Manifest lists exactly which fields a tool's samples kept.
type Manifest struct {
	Schema string         `json:"schema"`
	Tool   string         `json:"tool"`
	Note   string         `json:"note,omitempty"`
	Files  []ManifestFile `json:"files"`
}

var safeLabel = regexp.MustCompile(`^[a-z0-9_-]+$`)

// Capture samples one tool into out/<tool>/ and returns its manifest. It never writes a
// sample the pattern guard rejects. Missing sources are simply absent from the manifest.
func Capture(t Tool, env Env, out string, now time.Time) (Manifest, error) {
	m := Manifest{Schema: "modelplan-shape-manifest/1", Tool: t.Name, Note: t.Note, Files: []ManifestFile{}}
	dir := filepath.Join(out, t.Name)
	root := t.Root(env)
	if root == "" {
		return m, nil
	}
	for _, s := range t.Sources {
		if !safeLabel.MatchString(s.Label) {
			continue
		}
		paths := newest(root, s.Glob, s.Newest)
		if s.File != nil {
			if f := s.File(env); f != "" {
				paths = nil
				if fi, err := os.Lstat(f); err == nil && fi.Mode().IsRegular() {
					paths = []string{f}
				}
			}
		}
		for i, path := range paths {
			r := NewRedactor(s.Allow, now)
			var doc []byte
			var records int
			var err error
			switch s.Format {
			case "jsonl":
				doc, records, err = shapeJSONL(path, r)
			case "sqlite":
				doc, records, err = shapeSQLite(path, s, r)
			default:
				doc, records, err = shapeJSON(path, r)
			}
			mf := ManifestFile{Source: s.Label, Records: records}
			rep := r.Report()
			mf.DroppedKeys = rep.Dropped
			for k, kind := range rep.Kept {
				mf.Kept = append(mf.Kept, ManifestField{k, kind})
			}
			sort.Slice(mf.Kept, func(a, b int) bool { return mf.Kept[a].Name < mf.Kept[b].Name })
			if err != nil {
				mf.Withheld = "unreadable"
			} else if verr := verifyDoc(doc, s.Format); verr != nil {
				mf.Withheld = verr.Error()
			} else {
				ext := ".shape.json"
				if s.Format == "jsonl" {
					ext = ".shape.jsonl"
				}
				name := fmt.Sprintf("%s-%d%s", s.Label, i+1, ext)
				if err := os.MkdirAll(dir, 0o700); err != nil {
					return m, err
				}
				if err := os.WriteFile(filepath.Join(dir, name), doc, 0o600); err != nil {
					return m, err
				}
				mf.Output = t.Name + "/" + name
			}
			m.Files = append(m.Files, mf)
		}
	}
	return m, nil
}

func verifyDoc(doc []byte, format string) error {
	if format != "jsonl" {
		return Verify(doc)
	}
	for _, line := range bytes.Split(bytes.TrimSpace(doc), []byte("\n")) {
		if len(line) == 0 {
			continue
		}
		if err := Verify(line); err != nil {
			return err
		}
	}
	return nil
}

func decode(b []byte) (any, error) {
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.UseNumber()
	var v any
	if err := dec.Decode(&v); err != nil {
		return nil, err
	}
	return v, nil
}

func shapeJSON(path string, r *Redactor) ([]byte, int, error) {
	fi, err := os.Stat(path)
	if err != nil || fi.Size() > maxFileBytes {
		return nil, 0, fmt.Errorf("unreadable")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, 0, err
	}
	if len(bytes.TrimSpace(b)) > 0 && b[0] != '{' && b[0] != '[' {
		// a JSONL chat file under a .json glob
		return shapeLines(bytes.NewReader(b), r)
	}
	v, err := decode(b)
	if err != nil {
		return shapeLines(bytes.NewReader(b), r)
	}
	out, err := marshal(r.Shape(v), true)
	return out, 1, err
}

func shapeJSONL(path string, r *Redactor) ([]byte, int, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, 0, err
	}
	defer f.Close()
	return shapeLines(f, r)
}

// shapeLines keeps up to maxLinesKept lines with distinct shapes out of the first maxLinesRead.
func shapeLines(rd interface{ Read([]byte) (int, error) }, r *Redactor) ([]byte, int, error) {
	sc := bufio.NewScanner(rd)
	sc.Buffer(make([]byte, 0, 64<<10), maxLineBytes)
	seen := map[string]bool{}
	var buf bytes.Buffer
	kept := 0
	for n := 0; sc.Scan() && n < maxLinesRead && kept < maxLinesKept; n++ {
		v, err := decode(sc.Bytes())
		if err != nil {
			continue
		}
		line, err := marshal(r.Shape(v), false)
		line = bytes.TrimSpace(line)
		if err != nil || seen[string(line)] {
			continue
		}
		seen[string(line)] = true
		buf.Write(line)
		buf.WriteByte('\n')
		kept++
	}
	return buf.Bytes(), kept, nil
}

var tableName = regexp.MustCompile(`^[a-z_][a-z0-9_]{0,40}$`)

type sqlSample struct {
	Table   string           `json:"table"`
	Columns []map[string]any `json:"columns"`
	Rows    []any            `json:"rows"`
}

// shapeSQLite writes the allow-listed tables' columns (name and declared type) and a few rows
// whose allow-listed cells are shaped; JSON text cells are parsed and shaped too.
func shapeSQLite(path string, s Source, r *Redactor) ([]byte, int, error) {
	q := url.Values{}
	q.Set("mode", "ro")
	q.Add("_pragma", "query_only(1)")
	q.Add("_pragma", "busy_timeout(1000)")
	q.Add("_pragma", "trusted_schema(0)")
	db, err := sql.Open("sqlite", "file:"+(&url.URL{Path: path}).EscapedPath()+"?"+q.Encode())
	if err != nil {
		return nil, 0, err
	}
	defer db.Close()
	var samples []sqlSample
	total := 0
	for _, tbl := range s.Tables {
		if !tableName.MatchString(tbl) {
			continue
		}
		rows, err := db.Query("PRAGMA table_info(" + tbl + ")")
		if err != nil {
			continue
		}
		smp := sqlSample{Table: tbl, Columns: []map[string]any{}, Rows: []any{}}
		var names []string
		for rows.Next() {
			var cid int
			var name, typ string
			var notnull, pk int
			var dflt any
			if rows.Scan(&cid, &name, &typ, &notnull, &dflt, &pk) != nil {
				continue
			}
			if !KeyOK(name) {
				continue
			}
			smp.Columns = append(smp.Columns, map[string]any{"name": name, "type": strings.ToLower(typ)})
			if _, ok := s.Allow[name]; ok {
				names = append(names, name)
				r.rep.Kept[name] = s.Allow[name]
			} else {
				r.rep.Dropped++
			}
		}
		rows.Close()
		if len(smp.Columns) == 0 {
			continue
		}
		if len(names) > 0 {
			rs, err := db.Query("SELECT " + strings.Join(names, ",") + " FROM " + tbl + " ORDER BY rowid DESC LIMIT " + fmt.Sprint(maxSampleRows))
			if err == nil {
				for rs.Next() {
					vals := make([]any, len(names))
					ptr := make([]any, len(names))
					for i := range vals {
						ptr[i] = &vals[i]
					}
					if rs.Scan(ptr...) != nil {
						continue
					}
					row := map[string]any{}
					for i, n := range names {
						row[n] = cell(vals[i])
					}
					smp.Rows = append(smp.Rows, r.Shape(row))
					total++
				}
				rs.Close()
			}
		}
		samples = append(samples, smp)
	}
	out, err := marshal(samples, true)
	return out, total, err
}

func cell(v any) any {
	switch x := v.(type) {
	case int64:
		return float64(x)
	case []byte:
		return string(x)
	case string:
		t := strings.TrimSpace(x)
		if strings.HasPrefix(t, "{") || strings.HasPrefix(t, "[") {
			if j, err := decode([]byte(t)); err == nil {
				return j
			}
		}
		return x
	}
	return v
}

// WriteManifest writes out/manifest.json.
func WriteManifest(out string, ms []Manifest) error {
	if err := os.MkdirAll(out, 0o700); err != nil {
		return err
	}
	b, err := marshal(map[string]any{"schema": "modelplan-shape-capture/1", "tools": ms}, true)
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(out, "manifest.json"), b, 0o600)
}
