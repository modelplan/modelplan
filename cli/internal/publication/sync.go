// Package publication implements the read protocol in clients/README.md:
// pointer (short TTL, ETag) → immutable manifest → immutable content-addressed component,
// each verified by sha256 before the local cache switches.
package publication

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/store"
)

const (
	DefaultBase = "https://modelplan.guanbear.com"
	// MinCheckInterval bounds how often interactive commands re-check the pointer.
	MinCheckInterval = 10 * time.Minute
	maxObjectBytes   = 150000
)

var (
	ErrNoData = errors.New("no verified publication in the local cache; run `modelplan sync`")
	idRe      = regexp.MustCompile(`^[0-9a-f]{24}$`)
	hashRe    = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

type Client struct {
	Base      string
	HTTP      *http.Client
	Store     *store.Store
	UserAgent string
	Now       func() time.Time
}

func New(base string, st *store.Store, version string) (*Client, error) {
	if base == "" {
		base = DefaultBase
	}
	u, err := url.Parse(base)
	if err != nil {
		return nil, err
	}
	local := u.Hostname() == "localhost" || u.Hostname() == "127.0.0.1"
	if u.User != nil || u.RawQuery != "" || u.Fragment != "" || (u.Scheme != "https" && !(u.Scheme == "http" && local)) {
		return nil, fmt.Errorf("base %q must be https (http only for localhost)", base)
	}
	return &Client{
		Base:      strings.TrimRight(base, "/"),
		HTTP:      &http.Client{Timeout: 20 * time.Second, CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return errors.New("publication redirects refused") }},
		Store:     st,
		UserAgent: "modelplan-cli/" + version,
		Now:       time.Now,
	}, nil
}

type pointer struct {
	SchemaVersion int    `json:"schemaVersion"`
	PublicationID string `json:"publicationId"`
	ManifestHash  string `json:"manifestHash"`
}

type manifest struct {
	SchemaVersion     int                  `json:"schemaVersion"`
	PublicationID     string               `json:"publicationId"`
	PublishedAt       string               `json:"publishedAt"`
	ComparisonVersion string               `json:"comparisonVersion"`
	Methods           map[string]string    `json:"methods"`
	Components        map[string]component `json:"components"`
	identityCore      []byte
}

type component struct {
	SchemaVersion int    `json:"schemaVersion"`
	Hash          string `json:"hash"`
	Bytes         int64  `json:"bytes"`
}

type Result struct {
	PublicationID string
	Switched      bool // a new publication was verified and is now current
	NotModified   bool
	Skipped       bool // checked less than MinCheckInterval ago
}

// Sync refreshes the cache. On any failure the last verified publication stays current.
func (c *Client) Sync(ctx context.Context, force bool) (Result, error) {
	unlock, err := c.Store.Lock()
	if err != nil {
		return Result{}, err
	}
	defer unlock()

	st, err := c.Store.State()
	if err != nil {
		return Result{}, err
	}
	if st.Base != c.Base { // another source: nothing cached is comparable
		st = store.State{Base: c.Base}
	}
	now := c.Now()
	if !force && st.PublicationID != "" && now.Sub(st.CheckedAt) < MinCheckInterval {
		return Result{PublicationID: st.PublicationID, Skipped: true}, nil
	}
	st.LastAttemptAt = now
	res, err := c.sync(ctx, &st)
	if err != nil {
		st.LastError = err.Error()
	} else {
		st.LastError = ""
		st.CheckedAt = now
	}
	if serr := c.Store.SaveState(st); err == nil {
		err = serr
	}
	return res, err
}

func (c *Client) sync(ctx context.Context, st *store.State) (Result, error) {
	etag := ""
	if st.PublicationID != "" {
		etag = st.ETag
	}
	body, newTag, status, err := c.get(ctx, "/publications/current.json", etag)
	if err != nil {
		return Result{}, err
	}
	if status == http.StatusNotModified {
		if _, _, err := Load(c.Store); err != nil {
			return Result{}, err
		}
		return Result{PublicationID: st.PublicationID, NotModified: true}, nil
	}
	var p pointer
	if err := json.Unmarshal(body, &p); err != nil {
		return Result{}, fmt.Errorf("pointer: %w", err)
	}
	if p.SchemaVersion != 1 || !idRe.MatchString(p.PublicationID) || !hashRe.MatchString(p.ManifestHash) {
		return Result{}, errors.New("pointer: unsupported schema or malformed ids")
	}
	if p.PublicationID == st.PublicationID && p.ManifestHash == st.ManifestHash {
		if _, _, err := Load(c.Store); err != nil {
			return Result{}, err
		}
		st.ETag = newTag
		return Result{PublicationID: p.PublicationID, NotModified: true}, nil
	}

	mb, _, _, err := c.get(ctx, "/publications/releases/"+p.PublicationID+"/manifest.json", "")
	if err != nil {
		return Result{}, err
	}
	if sum(mb) != p.ManifestHash {
		return Result{}, errors.New("manifest: hash mismatch")
	}
	var m manifest
	if err := json.Unmarshal(mb, &m); err != nil {
		return Result{}, fmt.Errorf("manifest: %w", err)
	}
	if m.SchemaVersion != 1 || m.PublicationID != p.PublicationID {
		return Result{}, errors.New("manifest: unsupported schema or publication mismatch")
	}

	name := digest.ComponentClient
	comp, ok := m.Components[name]
	if !ok || comp.SchemaVersion != 1 || !hashRe.MatchString(comp.Hash) || comp.Bytes < 2 || comp.Bytes > maxObjectBytes {
		return Result{}, errors.New("manifest: no supported client component")
	}
	ob, err := c.Store.Object(comp.Hash)
	if err != nil || sum(ob) != comp.Hash {
		ob, _, _, err = c.get(ctx, "/publications/objects/"+comp.Hash+".json", "")
		if err != nil {
			return Result{}, err
		}
		if sum(ob) != comp.Hash || (comp.Bytes > 0 && int64(len(ob)) != comp.Bytes) {
			return Result{}, fmt.Errorf("%s: hash or size mismatch", name)
		}
	}
	if err := verify(m, ob); err != nil { // never switch to something we cannot read
		return Result{}, fmt.Errorf("%s: %w", name, err)
	}
	if err := c.Store.PutObject(comp.Hash, ob); err != nil {
		return Result{}, err
	}
	if err := c.Store.PutManifest(p.PublicationID, mb); err != nil {
		return Result{}, err
	}
	prev := st.ComponentHash
	st.PublicationID, st.ManifestHash, st.PublishedAt = p.PublicationID, p.ManifestHash, m.PublishedAt
	st.Component, st.ComponentHash, st.ETag = name, comp.Hash, newTag
	st.VerifiedAt = c.Now()
	c.Store.Prune(map[string]bool{comp.Hash: true, prev: true})
	return Result{PublicationID: p.PublicationID, Switched: true}, nil
}

// Load returns the digest of the current verified publication without touching the network.
func Load(s *store.Store) (*digest.Digest, store.State, error) {
	st, err := s.State()
	if err != nil {
		return nil, st, err
	}
	if st.ComponentHash == "" {
		return nil, st, ErrNoData
	}
	b, err := s.Object(st.ComponentHash)
	if err != nil {
		return nil, st, ErrNoData
	}
	mb, err := os.ReadFile(s.ManifestPath(st.PublicationID))
	if err != nil || sum(mb) != st.ManifestHash {
		return nil, st, errors.New("cache: manifest hash mismatch")
	}
	var m manifest
	if err = json.Unmarshal(mb, &m); err != nil {
		return nil, st, err
	}
	if m.PublicationID != st.PublicationID {
		return nil, st, errors.New("cache: publication mismatch")
	}
	if err = verify(m, b); err != nil {
		return nil, st, err
	}
	d, err := digest.Parse(st.Component, b)
	if err != nil {
		return nil, st, err
	}
	d.PublicationID, d.PublishedAt = st.PublicationID, st.PublishedAt
	return d, st, nil
}

func (c *Client) get(ctx context.Context, path, etag string) ([]byte, string, int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.Base+path, nil)
	if err != nil {
		return nil, "", 0, err
	}
	req.Header.Set("User-Agent", c.UserAgent)
	req.Header.Set("Accept", "application/json")
	if etag != "" {
		req.Header.Set("If-None-Match", etag)
	}
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, "", 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotModified {
		return nil, etag, resp.StatusCode, nil
	}
	if resp.StatusCode != http.StatusOK {
		return nil, "", resp.StatusCode, fmt.Errorf("GET %s: HTTP %d", path, resp.StatusCode)
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, maxObjectBytes+1))
	if err != nil {
		return nil, "", 0, err
	}
	if len(b) > maxObjectBytes {
		return nil, "", 0, fmt.Errorf("GET %s: response too large", path)
	}
	if strings.HasPrefix(path, "/publications/objects/") {
		b, err = decodeStorage(b)
		if err != nil {
			return nil, "", 0, err
		}
	}
	return b, resp.Header.Get("ETag"), resp.StatusCode, nil
}

func sum(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

func canonical(v any) []byte {
	raw, _ := json.Marshal(v)
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var normalized any
	_ = dec.Decode(&normalized)
	v = normalized
	var b bytes.Buffer
	e := json.NewEncoder(&b)
	e.SetEscapeHTML(false)
	_ = e.Encode(v)
	return bytes.TrimSuffix(b.Bytes(), []byte("\n"))
}
func verify(m manifest, ob []byte) error {
	if m.SchemaVersion != 1 || len(m.Components) != 8 || m.Methods["index"] != "unified-v03-estimator-0.1.0-internal" || m.Methods["recommendation"] != "balanced-coding-absolute-v4" {
		return errors.New("manifest: incompatible graph")
	}
	for _, name := range []string{"methods", "registry", "models", "plans", "rules", "news", "calendar", "client"} {
		r, ok := m.Components[name]
		if !ok || r.SchemaVersion != 1 || !hashRe.MatchString(r.Hash) || r.Bytes < 2 {
			return errors.New("manifest: invalid references")
		}
	}
	if manifestIdentity(m) != m.PublicationID {
		return errors.New("manifest: identity mismatch")
	}
	r := m.Components["client"]
	if len(ob) > maxObjectBytes || int64(len(ob)) != r.Bytes || sum(ob) != r.Hash {
		return errors.New("client: hash or size mismatch")
	}
	var c struct {
		Dependencies map[string]string `json:"dependencies"`
	}
	if err := json.Unmarshal(ob, &c); err != nil {
		return err
	}
	if len(c.Dependencies) != 4 {
		return errors.New("client: incompatible dependencies")
	}
	for _, name := range []string{"models", "registry", "rules", "calendar"} {
		if c.Dependencies[name] != m.Components[name].Hash {
			return errors.New("client: dependency mismatch")
		}
	}
	_, err := digest.Parse(digest.ComponentClient, ob)
	return err
}
func decodeStorage(b []byte) ([]byte, error) {
	if !bytes.HasPrefix(b, []byte{'M', 'P', 'G', 'Z', '1', 0}) {
		return b, nil
	}
	if len(b) <= 10 {
		return nil, errors.New("client: corrupt storage envelope")
	}
	length := int(binary.BigEndian.Uint32(b[6:10]))
	if length < 4096 || length > maxObjectBytes {
		return nil, errors.New("client: storage size budget")
	}
	r, err := gzip.NewReader(bytes.NewReader(b[10:]))
	if err != nil {
		return nil, err
	}
	defer r.Close()
	out, err := io.ReadAll(io.LimitReader(r, int64(length)+1))
	if err != nil || len(out) != length {
		return nil, errors.New("client: corrupt compressed body")
	}
	return out, nil
}

func manifestIdentity(m manifest) string { return sum(m.identityCore)[:24] }

// The producer hashes JSON.stringify insertion order, not a sorted-map canonicalization.
// Preserve the raw methods/components subobjects while reconstructing its fixed core order.
type identityCore struct {
	SchemaVersion     json.RawMessage `json:"schemaVersion"`
	ComparisonVersion json.RawMessage `json:"comparisonVersion"`
	Methods           json.RawMessage `json:"methods"`
	Components        json.RawMessage `json:"components"`
}

func orderedJSON(v any) []byte {
	var b bytes.Buffer
	e := json.NewEncoder(&b)
	e.SetEscapeHTML(false)
	_ = e.Encode(v)
	return bytes.TrimSuffix(b.Bytes(), []byte("\n"))
}
func (m *manifest) UnmarshalJSON(b []byte) error {
	type alias manifest
	var a alias
	if err := json.Unmarshal(b, &a); err != nil {
		return err
	}
	var core identityCore
	if err := json.Unmarshal(b, &core); err != nil {
		return err
	}
	*m = manifest(a)
	m.identityCore = orderedJSON(core)
	return nil
}
