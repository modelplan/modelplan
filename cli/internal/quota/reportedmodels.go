package quota

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"
)

// D99: the model slugs a tool itself reports for the signed-in account, read alongside the quota read and
// never more often. Every read is best effort with a 3 s cap: a failure, timeout or malformed reply yields
// none and never changes the quota outcome. Only the slug is kept; identifiers, tokens and e-mails never
// reach a snapshot, log or the wire. Calls go only to the host the reader already uses.
const reportedModelsMax = 256

// A var only so tests can shorten the cap.
var reportedModelsTimeout = 3 * time.Second

var reportedSlug = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$`)

// cleanReportedModels keeps well-formed slugs once each, sorted, at most reportedModelsMax. Anything with
// an '@', a space or other punctuation (an e-mail, a display name, a token) is dropped.
func cleanReportedModels(ids []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, id := range ids {
		id = strings.TrimSpace(id)
		if !reportedSlug.MatchString(id) || seen[id] {
			continue
		}
		seen[id] = true
		out = append(out, id)
	}
	sort.Strings(out)
	if len(out) > reportedModelsMax {
		out = out[:reportedModelsMax]
	}
	return out
}

// reportedModelIDs reads the slugs out of an OpenAI-style model list: {"data":[{"id":..}]}, {"models":[..]}
// or a bare array, each item an object with id (or model), or a plain string. Malformed input yields none.
func reportedModelIDs(raw []byte) []string {
	var list []json.RawMessage
	var wrapped struct {
		Data   []json.RawMessage `json:"data"`
		Models []json.RawMessage `json:"models"`
	}
	if json.Unmarshal(raw, &wrapped) == nil && (wrapped.Data != nil || wrapped.Models != nil) {
		list = append(wrapped.Data, wrapped.Models...)
	} else if json.Unmarshal(raw, &list) != nil {
		return nil
	}
	if len(list) > 4*reportedModelsMax {
		list = list[:4*reportedModelsMax]
	}
	var ids []string
	for _, item := range list {
		var s string
		if json.Unmarshal(item, &s) == nil {
			ids = append(ids, s)
			continue
		}
		var o struct {
			ID    string `json:"id"`
			Model string `json:"model"`
		}
		if json.Unmarshal(item, &o) != nil {
			continue
		}
		if o.ID != "" {
			ids = append(ids, o.ID)
		} else {
			ids = append(ids, o.Model)
		}
	}
	return cleanReportedModels(ids)
}

// reportedModelsGET fetches a model list from the host the reader already talks to, with the reader's own
// headers, redirects refused, a 3 s cap and a bounded body. nil on any failure.
func reportedModelsGET(ctx context.Context, c *http.Client, url string, header map[string]string) []string {
	ctx, cancel := context.WithTimeout(ctx, reportedModelsTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil
	}
	for k, v := range header {
		req.Header.Set(k, v)
	}
	if c == nil {
		c = nativeClient
	}
	client := *c
	client.Jar = nil
	client.Timeout = reportedModelsTimeout
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	resp, err := client.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
	if err != nil || len(b) > nativeMaxBody {
		return nil
	}
	return reportedModelIDs(b)
}

// claudeModelAccess reads only the modelAccessCache field of the Claude Code config file (a list of
// {apiName, entitled}) and keeps the entitled apiNames. Nothing else in the file is decoded or kept, and the
// file is never logged. The undocumented bootstrap endpoint is deliberately not called.
func claudeModelAccess(file string) []string {
	if file == "" {
		return nil
	}
	fi, err := os.Lstat(file)
	if err != nil || !fi.Mode().IsRegular() || fi.Size() > maxClaudeConfig {
		return nil
	}
	f, err := os.Open(file)
	if err != nil {
		return nil
	}
	defer f.Close()
	d := json.NewDecoder(io.LimitReader(f, maxClaudeConfig))
	if t, err := d.Token(); err != nil || t != json.Delim('{') {
		return nil
	}
	for d.More() {
		t, err := d.Token()
		if err != nil {
			return nil
		}
		if k, _ := t.(string); k == "modelAccessCache" {
			var list []struct {
				APIName  string `json:"apiName"`
				Entitled *bool  `json:"entitled"`
			}
			if d.Decode(&list) != nil {
				return nil
			}
			var ids []string
			for _, m := range list {
				if m.Entitled != nil && *m.Entitled {
					ids = append(ids, m.APIName)
				}
			}
			return cleanReportedModels(ids)
		}
		var skip json.RawMessage
		if d.Decode(&skip) != nil {
			return nil
		}
	}
	return nil
}
