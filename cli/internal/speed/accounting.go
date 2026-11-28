// SPDX-License-Identifier: MIT
package speed

// Independent usage accounting, matched to ccusage@58866ba681343634ab6e5add61f18f3b70aa98f7:
// rust/adapters/{codex/src/{parser,aggregate,types},claude/src/lib}.rs (MIT).
// Timing parsers intentionally sample completed turns. These records instead describe
// responses, including responses in turns that have not finished. No transcript text,
// paths, request IDs or session IDs are persisted here; identities are hashed.
import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/idlework"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localday"
	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

// Buckets use the shared disjoint accounting contract. Codex output is split
// into ordinary output and reasoning here; legacy output fields still include both.
type usageBuckets = tokenacct.Buckets

func usageKinds(b usageBuckets) TokenKinds {
	total := b.Sum()
	return TokenKinds{InputTokens: &b.Input, CacheReadTokens: &b.CacheRead, CacheWriteTokens: &b.CacheWrite, TotalTokens: &total, ReasoningTokens: &b.Reasoning}
}

type usageRecord struct {
	Imported bool      `json:"imported,omitempty"`
	Key      string    `json:"key"`
	At       time.Time `json:"at"`
	Model    string    `json:"model"`
	usageBuckets
	Sidechain   bool   `json:"sidechain,omitempty"`
	Replay      string `json:"replay,omitempty"`
	Requestless bool   `json:"requestless,omitempty"`
	Response    bool   `json:"response,omitempty"`
	// Tier is the response's recorded speed tier: standard | fast | ultrafast | flex | unknown.
	// It selects a published API price multiplier; it is not a timing sample. Records written
	// before tiers were recorded have none, and responseTier reads that as unknown, never as
	// standard.
	Tier string `json:"tier,omitempty"`
}
type usageFile struct {
	LiveObserved bool          `json:"liveObserved,omitempty"` // Size/Modified describe a real live scan, not an import
	Tiered       bool          `json:"tiered,omitempty"`       // the records carry their speed tier (WP-06); older entries are rescanned
	Pending      bool          `json:"pending,omitempty"`      // the file holds a response dated after the scan; it is read again until the clock passes it
	Session      string        `json:"session,omitempty"`
	Parent       string        `json:"parent,omitempty"`
	Started      time.Time     `json:"started,omitempty"`
	Source       string        `json:"source"`
	Epoch        *GrantEpoch   `json:"epoch"`
	Size         int64         `json:"size"`
	Modified     int64         `json:"modified"`
	Records      []usageRecord `json:"records"`
}
type accountingLedger struct {
	Version int                  `json:"version"`
	Files   map[string]usageFile `json:"files"`
}

func accountingPath(cache string) string {
	return filepath.Join(cache, "observed", "accounting.json.gz")
}

const accountingMax = 64 << 20

func loadAccounting(cache string) (accountingLedger, bool) {
	l := accountingLedger{Version: 1, Files: map[string]usageFile{}}
	f, err := os.Open(accountingPath(cache))
	if errors.Is(err, os.ErrNotExist) {
		return l, true
	}
	if err != nil {
		return l, false
	}
	defer f.Close()
	idlework.Open()
	idlework.Decode()
	z, err := gzip.NewReader(idlework.Reader(f))
	if err != nil {
		return l, false
	}
	defer z.Close()
	b, err := io.ReadAll(io.LimitReader(z, accountingMax+1))
	if err != nil || len(b) > accountingMax || json.Unmarshal(b, &l) != nil || l.Version != 1 || l.Files == nil {
		return accountingLedger{}, false
	}
	return l, true
}

// sameUsageFile compares entries as they are stored (parsed times carry no location).
func sameUsageFile(a, b usageFile) bool {
	x, errA := json.Marshal(a)
	y, errB := json.Marshal(b)
	return errA == nil && errB == nil && bytes.Equal(x, y)
}

func saveAccounting(cache string, l accountingLedger) error {
	raw, err := json.Marshal(l)
	if err != nil {
		return err
	}
	if len(raw) > accountingMax {
		return errors.New("accounting history exceeds cache limit")
	}
	var b bytes.Buffer
	z := gzip.NewWriter(&b)
	if _, err := z.Write(raw); err != nil {
		return err
	}
	if err := z.Close(); err != nil {
		return err
	}
	return write(accountingPath(cache), b.Bytes())
}
func usageHash(parts ...any) string {
	h := sha256.Sum256([]byte(fmt.Sprint(parts...)))
	return hex.EncodeToString(h[:16])
}

// A snapshot replaces a file's prior contribution when a stream is appended or rewritten.
// This also lets a later Claude streaming block replace its earlier, smaller usage.
func observeAccounting(cache, source string, paths []string, now time.Time) error {
	if Off() {
		return nil
	}
	unlock, ok := lock(cache, "perf.lock")
	if !ok {
		return nil
	}
	defer unlock()
	l, ok := loadAccounting(cache)
	if !ok {
		return nil
	}
	a := consent.Capture()
	epoch := currentEpoch(a, source)
	if epoch == nil {
		forgetLiveCursors(sourceTool(source))
		return nil
	}
	floor := LoadCleared(cache).floor(source)
	start := accountingLiveStart(cache, now)
	changed := false
	for _, path := range paths {
		fi, err := os.Stat(path)
		if err != nil || !fi.Mode().IsRegular() {
			continue
		}
		key := fileKey(path)
		old, exists := l.Files[key]
		if exists && old.LiveObserved && old.Source == source && sameEpoch(old.Epoch, epoch) && old.Tiered && !old.Pending && old.Size == fi.Size() && old.Modified == fi.ModTime().UnixNano() {
			continue
		}
		// Only the bytes appended since the last observation are parsed (accounting_cursor.go).
		p, err := readAccounting(func() error {
			if !sameEpoch(epoch, currentEpoch(consent.Capture(), source)) {
				return errGrantWithdrawn
			}
			return nil
		}, cache, source, path, epoch, now)
		if err != nil {
			continue
		}
		// A legacy (untiered) file is rescanned once to learn its speed tiers. The recording-day start is
		// computed in today's time zone and may be later than when the file was first recorded, so an
		// unchanged legacy file keeps every record it already has and only gains tiers by response identity.
		legacy := exists && old.LiveObserved && !old.Tiered && old.Source == source && sameEpoch(old.Epoch, epoch) && old.Size == fi.Size() && old.Modified == fi.ModTime().UnixNano()
		// A response this file already recorded live, under this grant, stays eligible on every reparse (an append
		// too, sampling 11-21 S12): the recomputed recording-day start never drops it. Only live records count: an
		// imported copy never makes its response live, so "Remove imported history" still removes it (S11).
		known := map[string]bool{}
		if exists && old.LiveObserved && old.Source == source && sameEpoch(old.Epoch, epoch) {
			for _, r := range old.Records {
				if !r.Imported {
					known[r.Key] = true
				}
			}
		}
		// A response dated ahead of this clock is not recorded yet; the unchanged file must be read
		// again until it is, so it is not skipped by size and time (G3-147 review). Checked
		// before the filter below.
		pending := false
		for _, r := range p.records {
			if r.At.After(now) {
				pending = true
				break
			}
		}
		records := make([]usageRecord, 0, len(p.records)) // p.records stays with the live cursor
		for _, r := range p.records {
			if day(r.At) >= windowFrom(now, 35) && !r.At.Before(floor) && (known[r.Key] || !r.At.Before(start)) && !r.At.After(now) {
				records = append(records, r)
			}
		}
		fresh := map[string]bool{}
		for _, r := range records {
			fresh[r.Key] = true
		}
		for _, r := range old.Records {
			keep := r.Imported
			if legacy && !fresh[r.Key] {
				keep = true // no longer parsed (or filtered): never delete a recorded response
			}
			if keep && old.Source == source && sameEpoch(old.Epoch, epoch) && !r.At.Before(floor) && day(r.At) >= windowFrom(now, 35) {
				records = append(records, r)
			}
		}
		next := usageFile{LiveObserved: true, Tiered: true, Pending: pending, Source: source, Epoch: epoch, Size: fi.Size(), Modified: fi.ModTime().UnixNano(), Records: records, Session: usageHash(p.session), Parent: p.parent, Started: p.started}
		// Re-reading a pending file changes nothing until the clock passes its response; an
		// identical entry is not a change, so the ledger is not rewritten meanwhile.
		if len(records) == 0 {
			next.Session, next.Parent, next.Started = "", "", time.Time{} // as the retention below keeps it
		}
		if !exists || !sameUsageFile(old, next) {
			changed = true
		}
		l.Files[key] = next
	}
	// Retain no expired or revoked observations, even from files no longer present.
	a = consent.Capture()
	for key, f := range l.Files {
		if !sameEpoch(f.Epoch, currentEpoch(a, f.Source)) {
			delete(l.Files, key)
			changed = true
			continue
		}
		records := f.Records[:0]
		floor := LoadCleared(cache).floor(f.Source)
		for _, r := range f.Records {
			if day(r.At) >= windowFrom(now, 35) && !r.At.Before(floor) {
				records = append(records, r)
			}
		}
		if len(records) != len(f.Records) {
			changed = true
		}
		f.Records = records
		if len(records) == 0 && f.LiveObserved && day(time.Unix(0, f.Modified)) >= windowFrom(now, 35) {
			// A live-scanned file with nothing in the window keeps only its size and time, so the
			// next observation skips it while it is unchanged. Dropping it made every 30 s pass
			// parse the whole file again and rewrite the ledger, which woke the change watcher
			// into a new snapshot (G3-147). It holds no record or session reference.
			if f.Session != "" || f.Parent != "" || !f.Started.IsZero() {
				f.Session, f.Parent, f.Started = "", "", time.Time{}
				changed = true
			}
			l.Files[key] = f
		} else if len(records) == 0 {
			delete(l.Files, key)
		} else {
			l.Files[key] = f
		}
	}
	if !changed {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(accountingPath(cache)), 0700); err != nil {
		return err
	}
	return saveAccounting(cache, l)
}

// accountingRows merges copies across files. Identical Codex events within one
// file retain an occurrence ordinal; copied files repeat the same ordinal.
func accountingRows(cache string) ([]PerfRow, map[string]bool) {
	l, ok := loadAccounting(cache)
	if !ok {
		return nil, nil
	}
	clear := LoadCleared(cache)
	type stamped struct {
		usageRecord
		source string
		epoch  *GrantEpoch
	}
	seen := map[string]stamped{}
	replayAt, sideAt, replayRequestless, sideRequestless := map[string]string{}, map[string]string{}, map[string]string{}, map[string]string{}
	sources := map[string]bool{}
	keys := make([]string, 0, len(l.Files))
	for key := range l.Files {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		f := l.Files[key]
		sources[f.Source] = true
		for _, r := range withoutForkReplay(f, l) {
			if r.At.Before(clear.floor(f.Source)) {
				continue
			}
			id := usageHash(f.Source, "\x00", f.Epoch, "\x00", r.Key)
			atKey, requestlessKey := "", ""
			if r.Replay != "" {
				requestlessKey = usageHash(f.Source, f.Epoch, r.Replay)
				atKey = usageHash(requestlessKey, r.At)
				alias := sideAt[atKey]
				if r.Sidechain {
					alias = replayAt[atKey]
				}
				if r.Requestless {
					other := sideRequestless[requestlessKey]
					if r.Sidechain {
						other = replayRequestless[requestlessKey]
					}
					if other != "" {
						alias = other
					}
				}
				if alias != "" {
					id = alias
				}
			}
			old, exists := seen[id]
			if !exists || old.Sidechain && !r.Sidechain || old.Sidechain == r.Sidechain && (r.Sum() > old.Sum() || r.Sum() == old.Sum() && old.Imported && !r.Imported) {
				seen[id] = stamped{r, f.Source, f.Epoch}
			}
			if atKey != "" {
				replayAt[atKey] = id
				if r.Sidechain {
					sideAt[atKey] = id
				}
				if r.Requestless {
					replayRequestless[requestlessKey] = id
					if r.Sidechain {
						sideRequestless[requestlessKey] = id
					}
				}
			}
		}
	}
	rows := map[string]*PerfRow{}
	for _, v := range seen {
		key := usageHash(v.source, day(v.At), unreviewed(v.Model), v.epoch, v.Imported)
		r := rows[key]
		if r == nil {
			parser := ParserCodex
			if v.source == "claude-code" {
				parser = ParserClaude
			}
			r = &PerfRow{GrantEpoch: v.epoch, Day: day(v.At), Source: v.source, Model: unreviewed(v.Model), EffortStatus: "unreported", Parser: parser, Eligibility: EligibilityV1}
			if v.Imported {
				r.Origin = OriginImport
			}
			rows[key] = r
		}
		r.TokenKinds.add(usageKinds(v.usageBuckets), r.ObservedRequests == 0)
		r.Responses = append(r.Responses, Response{At: v.At, Tier: responseTier(v.Tier), Buckets: v.usageBuckets})
		r.ObservedRequests++
		r.ObservedOutputTokens += v.Output + v.Reasoning
	}
	out := make([]PerfRow, 0, len(rows))
	for _, r := range rows {
		out = append(out, *r)
	}
	sort.Slice(out, func(i, j int) bool { a, b := out[i], out[j]; return a.Day+a.Source+a.Model < b.Day+b.Source+b.Model })
	return out, sources
}
func accountingOverlay(cache string, l PerfLedger) PerfLedger {
	l.UsageRows, _ = accountingRows(cache)
	return l
}

// accounted is used by usage views only. Configuration-level timing samples stay
// intact, and their eligible output/timing sums remain the sole basis of t/s.
func (v PerfView) accounted() PerfView {
	sources := map[string]bool{}
	for _, r := range v.Ledger.UsageRows {
		sources[r.Source] = true
	}
	if len(sources) == 0 {
		return v
	}
	rows := append([]PerfRow(nil), v.Ledger.Rows...)
	for i := range rows {
		r := &rows[i]
		if sources[r.Source] {
			r.TokenKinds = TokenKinds{}
			r.ObservedRequests = 0
			r.ObservedOutputTokens = 0
		}
	}
	v.Ledger.Rows = append(rows, v.Ledger.UsageRows...)
	return v
}

type accountingParser struct {
	parent                       string
	started                      time.Time
	pending                      map[string]usageRecord
	pendingTotals                map[string]usageBuckets
	latest                       string
	compacted, emitted           map[string]bool
	source, file, session, model string
	tier                         string // Codex: the latest thread_settings_applied service tier
	previous                     map[string]int64
	records                      []usageRecord
	occurrences                  map[string]int
}

func newAccountingParser(source, file string) *accountingParser {
	return &accountingParser{source: source, file: file, model: "unknown", occurrences: map[string]int{}, pending: map[string]usageRecord{}, pendingTotals: map[string]usageBuckets{}, compacted: map[string]bool{}, emitted: map[string]bool{}}
}
func (p *accountingParser) finish() ([]turn, int64)       { return nil, -1 }
func (p *accountingParser) line(off, end int64, b []byte) { p.lineDoc(off, end, b, nil) }

// lineDoc is line with a Claude Code line's reduced form (claudeDoc) already made, or nil.
func (p *accountingParser) lineDoc(_, _ int64, b, doc []byte) {
	var e struct {
		Type      string    `json:"type"`
		Timestamp time.Time `json:"timestamp"`
		RequestID string    `json:"requestId"`
		SessionID string    `json:"sessionId"`
		Sidechain bool      `json:"isSidechain"`
		Payload   struct {
			ThreadSettings *struct {
				ServiceTier *string `json:"service_tier"`
			} `json:"thread_settings"`
			ForkedFrom           string           `json:"forked_from_id"`
			Source               json.RawMessage  `json:"source"`
			Type                 string           `json:"type"`
			ID                   string           `json:"id"`
			Model                string           `json:"model"`
			CompactionResponseID string           `json:"compaction_response_id"`
			ThreadUsage          map[string]int64 `json:"thread_token_usage"`
			ResponseID           string           `json:"response_id"`
			Usage                map[string]int64 `json:"usage"`
			Info                 *struct {
				Last  map[string]int64 `json:"last_token_usage"`
				Total map[string]int64 `json:"total_token_usage"`
			} `json:"info"`
		} `json:"payload"`
		Message struct {
			ID    string          `json:"id"`
			Model string          `json:"model"`
			Usage json.RawMessage `json:"usage"`
		} `json:"message"`
	}
	if p.source == "codex" && !bytes.Contains(b, []byte("token_count")) && !bytes.Contains(b, []byte("token_usage_record")) && !bytes.Contains(b, []byte("turn_context")) && !bytes.Contains(b, []byte("session_meta")) && !bytes.Contains(b, []byte("compacted")) && !bytes.Contains(b, []byte("thread_settings_applied")) {
		return
	}
	if p.source == "claude-code" {
		if doc == nil {
			doc = claudeDoc(b)
		}
		b = doc
	}
	if b == nil || json.Unmarshal(b, &e) != nil {
		return
	}
	if e.Type == "compacted" {
		id := e.Payload.CompactionResponseID
		if id != "" {
			p.compacted[id] = true
			if r, ok := p.pending[id]; ok && !p.emitted[id] {
				p.records = append(p.records, r)
				p.emitted[id] = true
				delete(p.pending, id)
			}
		}
		return
	}
	if p.source == "claude-code" {
		if e.Type != "assistant" || len(e.Message.Usage) == 0 || e.Message.Model == "<synthetic>" || e.Timestamp.IsZero() {
			return
		}
		var u struct {
			Speed  string `json:"speed"`
			Input  *int64 `json:"input_tokens"`
			Read   int64  `json:"cache_read_input_tokens"`
			Write  int64  `json:"cache_creation_input_tokens"`
			Output *int64 `json:"output_tokens"`
		}
		if json.Unmarshal(e.Message.Usage, &u) != nil || u.Input == nil || u.Output == nil {
			return
		}
		buckets := usageBuckets{Input: max(0, *u.Input), CacheRead: max(0, u.Read), CacheWrite: claudeCacheWrites(e.Message.Usage, max(0, u.Write)), Output: max(0, *u.Output)}
		buckets.Total = buckets.Sum()
		key := usageHash(p.file, len(p.records))
		if e.Message.ID != "" {
			key = usageHash(e.Message.ID, "\x00", e.RequestID)
			if e.RequestID == "" {
				session := e.SessionID
				if session == "" {
					session = p.file
				}
				key = usageHash(key, session)
				if !strings.HasPrefix(e.Message.ID, "msg_") && !strings.HasPrefix(e.Message.ID, "resp_") {
					key = usageHash(key, e.Timestamp)
				}
			}
		}
		session := e.SessionID
		if session == "" {
			session = p.file
		}
		replay := ""
		if e.Message.ID != "" {
			replay = usageHash(session, "\x00", e.Message.ID)
		}
		p.records = append(p.records, usageRecord{Key: key, At: e.Timestamp, Model: e.Message.Model, usageBuckets: buckets, Sidechain: e.Sidechain, Replay: replay, Requestless: e.RequestID == "", Tier: storedTier(claudeTier(u.Speed))})
		return
	}
	if e.Type == "session_meta" {
		p.session = e.Payload.ID
		p.started = e.Timestamp
		parent := e.Payload.ForkedFrom
		if parent == "" {
			var source struct {
				Subagent struct {
					ThreadSpawn struct {
						Parent string `json:"parent_thread_id"`
					} `json:"thread_spawn"`
				} `json:"subagent"`
			}
			if json.Unmarshal(e.Payload.Source, &source) == nil {
				parent = source.Subagent.ThreadSpawn.Parent
			}
		}
		if parent != "" {
			p.parent = usageHash(parent)
		}
		return
	}
	if e.Type == "event_msg" && e.Payload.Type == "thread_settings_applied" {
		// ccusage codex/src/parser.rs: an event without service_tier says nothing about the tier.
		if s := e.Payload.ThreadSettings; s != nil && s.ServiceTier != nil {
			p.tier = codexTier(*s.ServiceTier)
		}
		return
	}
	if e.Type == "turn_context" && e.Payload.Model != "" {
		p.model = e.Payload.Model
		return
	}
	if (e.Type != "event_msg" && e.Type != "token_usage_record") || e.Timestamp.IsZero() {
		return
	}
	var u map[string]int64
	if e.Payload.Type == "token_count" && e.Payload.Info != nil {
		info := e.Payload.Info
		same := info.Total != nil && p.previous != nil && codexCumulative(info.Total) == codexCumulative(p.previous)
		if !same {
			u = info.Last
		}
		if u == nil && info.Total != nil {
			u = map[string]int64{}
			cur, prev := codexCumulative(info.Total), codexCumulative(p.previous)
			for i, key := range []string{"input_tokens", "cached_input_tokens", "cache_write_input_tokens", "output_tokens", "reasoning_output_tokens", "total_tokens"} {
				u[key] = max(0, cur[i]-prev[i])
			}
		}
		if info.Total != nil {
			p.previous = info.Total
		}
	} else if e.Type == "token_usage_record" || e.Payload.Type == "token_usage_record" {
		u = e.Payload.Usage
	} else {
		return
	}
	if u == nil {
		return
	}
	buckets := codexBuckets(u)
	if buckets.Sum() == 0 && buckets.Reasoning == 0 {
		return
	}
	model := p.model
	if e.Payload.Model != "" {
		model = e.Payload.Model
	}
	if autoReview(model) {
		model = "" // the tokens stay in the Codex total; the reviewer id is not a model
	}
	session := p.session
	if session == "" {
		session = p.file
	}
	key := usageHash(session, "\x00", e.Timestamp, "\x00", model, "\x00", buckets)
	occurrence := p.occurrences[key]
	p.occurrences[key]++
	key = usageHash(key, ":", occurrence)
	if e.Payload.ResponseID != "" {
		key = usageHash("response:", e.Payload.ResponseID)
	}
	record := usageRecord{Key: key, At: e.Timestamp, Model: model, usageBuckets: buckets, Response: e.Type == "token_usage_record" || e.Payload.Type == "token_usage_record", Tier: storedTier(p.tier)}
	if e.Type == "token_usage_record" || e.Payload.Type == "token_usage_record" {
		id := e.Payload.ResponseID
		if id == "" || p.emitted[id] {
			return
		}
		p.latest = id
		if p.compacted[id] {
			p.records = append(p.records, record)
			p.emitted[id] = true
		} else {
			p.pending[id] = record
			if e.Payload.ThreadUsage != nil {
				p.pendingTotals[id] = codexBuckets(e.Payload.ThreadUsage)
			}
		}
	} else {
		if pending, ok := p.pending[p.latest]; ok {
			matches := pending.usageBuckets == buckets
			if totals, ok := p.pendingTotals[p.latest]; ok && e.Payload.Info != nil && e.Payload.Info.Total != nil {
				matches = matches || totals == codexBuckets(e.Payload.Info.Total)
			}
			if matches {
				delete(p.pending, p.latest)
				p.emitted[p.latest] = true
			}
		}
		p.records = append(p.records, record)
	}
}
func usageNumber(u map[string]int64, keys ...string) int64 {
	for _, key := range keys {
		if n, ok := u[key]; ok {
			return max(0, n)
		}
	}
	return 0
}

// ForgetAccountingLocked erases only this tool's snapshots. Caller holds perf.lock.
func ForgetAccountingLocked(cache, tool string) error {
	forgetLiveCursors(tool)
	l, ok := loadAccounting(cache)
	if !ok {
		return errors.New("accounting history unreadable; retry cleanup")
	}
	changed := false
	for key, f := range l.Files {
		if sourceTool(f.Source) == tool {
			delete(l.Files, key)
			changed = true
		}
	}
	if !changed {
		return nil
	}
	return saveAccounting(cache, l)
}

// accountingTee shares the importer's cancellation/consent checks and file read.
type accountingTee struct {
	parser
	usage *accountingParser
}

func (p *accountingTee) line(start, end int64, b []byte) {
	// A Claude Code line is validated and reduced once for both readers.
	if c, ok := p.parser.(*claudeParser); ok && p.usage.source == "claude-code" {
		doc := claudeDoc(b)
		if doc == nil {
			return // not JSON: both readers skip it
		}
		c.lineDoc(start, end, b, doc)
		p.usage.lineDoc(start, end, b, doc)
		return
	}
	p.parser.line(start, end, b)
	p.usage.line(start, end, b)
}
func (p *accountingTee) finish() ([]turn, int64) { p.usage.finish(); return p.parser.finish() }

// Forks replay a parent prefix. If the parent is unavailable, ccusage recognizes
// the leading usage burst rewritten to the fork instant (at most 1 s between events).
func withoutForkReplay(f usageFile, l accountingLedger) []usageRecord {
	if f.Source != "codex" || f.Parent == "" || f.Parent == f.Session {
		return f.Records
	}
	var parent []usageRecord
	for _, candidate := range l.Files {
		if candidate.Session == f.Parent {
			parent = candidate.Records
			break
		}
	}
	n := 0
	for n < len(f.Records) && n < len(parent) && !f.Records[n].Response && f.Records[n].usageBuckets == parent[n].usageBuckets {
		n++
	}
	if n > 0 {
		return f.Records[n:]
	}
	if len(f.Records) < 2 || f.Records[0].Response || f.Records[1].Response {
		return f.Records
	}
	first, second := f.Records[0].At, f.Records[1].At
	dense := !second.Before(first) && second.Sub(first) <= time.Second
	if !dense || !f.Started.IsZero() && absDuration(first.Sub(f.Started)) > time.Second {
		return f.Records
	}
	n = 1
	for n < len(f.Records) && !f.Records[n].Response && !f.Records[n].At.Before(f.Records[n-1].At) && f.Records[n].At.Sub(f.Records[n-1].At) <= time.Second {
		n++
	}
	return f.Records[n:]
}
func absDuration(d time.Duration) time.Duration {
	if d < 0 {
		return -d
	}
	return d
}

func codexBuckets(u map[string]int64) usageBuckets {
	input := usageNumber(u, "input_tokens", "prompt_tokens", "input")
	read := min(input, usageNumber(u, "cached_input_tokens", "cache_read_input_tokens", "cached_tokens"))
	write := min(input-read, usageNumber(u, "cache_write_input_tokens", "cache_creation_input_tokens"))
	output := usageNumber(u, "output_tokens", "completion_tokens", "output")
	reasoning := min(output, usageNumber(u, "reasoning_output_tokens", "reasoning_tokens"))
	// Codex reasoning is a subset of output, not additional consumption.
	b := usageBuckets{Input: input - read - write, CacheRead: read, CacheWrite: write, Output: output - reasoning, Reasoning: reasoning}
	b.Total = b.Sum()
	return b
}

// A live observer backfills its local starting day, never silently importing
// older days on a later hook. Import ownership is independent of this boundary.
func accountingLiveStart(cache string, now time.Time) time.Time {
	if l, ok := loadPerf(cache); ok && !l.Since.IsZero() {
		return dayStart(l.Since)
	}
	return dayStart(now)
}
func removeImportedAccountingLocked(cache string) error {
	l, ok := loadAccounting(cache)
	if !ok {
		return errors.New("accounting history unreadable; retry removal")
	}
	changed := false
	for key, f := range l.Files {
		records := f.Records[:0]
		for _, r := range f.Records {
			if r.Imported || !f.LiveObserved {
				changed = true
			} else {
				records = append(records, r)
			}
		}
		f.Records = records
		l.Files[key] = f
	}
	if !changed {
		return nil
	}
	return saveAccounting(cache, l)
}

func codexCumulative(u map[string]int64) [6]int64 {
	return [6]int64{usageNumber(u, "input_tokens", "prompt_tokens", "input"), usageNumber(u, "cached_input_tokens", "cache_read_input_tokens", "cached_tokens"), usageNumber(u, "cache_write_input_tokens", "cache_creation_input_tokens"), usageNumber(u, "output_tokens", "completion_tokens", "output"), usageNumber(u, "reasoning_output_tokens", "reasoning_tokens"), usageNumber(u, "total_tokens")}
}

// AccountingWindows publishes the common family-neutral contract. Timing and
// request eligibility are deliberately absent from these usage-only windows.
func (v PerfView) AccountingWindows() map[string]tokenacct.Windows {
	if !v.OK || !v.Recording {
		return nil
	}
	by := map[string][]tokenacct.Entry{}
	for _, r := range v.Ledger.UsageRows {
		if r.TotalTokens == nil || r.InputTokens == nil || r.CacheReadTokens == nil || r.CacheWriteTokens == nil || r.ReasoningTokens == nil {
			continue
		}
		date, err := time.Parse("2006-01-02", r.Day)
		if err != nil {
			continue
		}
		y, m, d := date.Date()
		at := localday.Start(y, m, d, time.Local)
		b := tokenacct.Buckets{Input: *r.InputTokens, CacheRead: *r.CacheReadTokens, CacheWrite: *r.CacheWriteTokens, Output: r.ObservedOutputTokens - *r.ReasoningTokens, Reasoning: *r.ReasoningTokens}
		b.Total = b.Sum()
		by[r.Source] = append(by[r.Source], tokenacct.Entry{At: at, Buckets: b})
	}
	out := map[string]tokenacct.Windows{}
	for source, entries := range by {
		out[source] = tokenacct.Summarize(entries, v.Now)
	}
	return out
}

// Advisor requests may split cache writes across message iterations. Match
// ccusage-core/types/iterations.rs: use the split only if every message has one.
func claudeCacheWrites(raw json.RawMessage, fallback int64) int64 {
	var u struct {
		Split      json.RawMessage `json:"cache_creation"`
		Iterations json.RawMessage `json:"iterations"`
	}
	if json.Unmarshal(raw, &u) != nil {
		return fallback
	}
	split := func(raw json.RawMessage) (int64, bool) {
		var s struct {
			Five int64 `json:"ephemeral_5m_input_tokens"`
			Hour int64 `json:"ephemeral_1h_input_tokens"`
		}
		if len(raw) == 0 || string(raw) == "null" || json.Unmarshal(raw, &s) != nil {
			return 0, false
		}
		b := tokenacct.Buckets{CacheWrite: max(0, s.Five)}
		b.Add(tokenacct.Buckets{CacheWrite: max(0, s.Hour)})
		return b.CacheWrite, true
	}
	var iterations []json.RawMessage
	if json.Unmarshal(u.Iterations, &iterations) == nil {
		has, complete := false, true
		b := tokenacct.Buckets{}
		for _, raw := range iterations {
			var item struct {
				Type  string          `json:"type"`
				Split json.RawMessage `json:"cache_creation"`
			}
			if json.Unmarshal(raw, &item) != nil || item.Type != "message" {
				continue
			}
			has = true
			n, ok := split(item.Split)
			if !ok {
				complete = false
			}
			b.Add(tokenacct.Buckets{CacheWrite: n})
		}
		if has && complete {
			return b.CacheWrite
		}
	}
	if n, ok := split(u.Split); ok {
		return n
	}
	return fallback
}

// A partial import replaces only its own intervals. Live observations are an
// independent contribution and must survive both imports and import removal.
func mergeImportedUsage(old, incoming usageFile, ranges []span) usageFile {
	if old.Source != incoming.Source || !sameEpoch(old.Epoch, incoming.Epoch) {
		return incoming
	}
	incoming.LiveObserved = old.LiveObserved
	if old.LiveObserved {
		incoming.Size, incoming.Modified = old.Size, old.Modified
		// The live records kept below are as tier-aware as the live scan that wrote them; an import
		// must not mark an older scan's records as tiered, or the next observation skips the rescan.
		incoming.Tiered = old.Tiered
		incoming.Pending = old.Pending
	}
	for _, r := range old.Records {
		// Pre-release caches without live-scan provenance cannot prove live ownership.
		if !old.LiveObserved {
			r.Imported = true
		}
		if !r.Imported || !inRange(ranges, r.At) {
			incoming.Records = append(incoming.Records, r)
		}
	}
	return incoming
}

// unreviewed maps records stored before the auto-review rule to the same unnamed model.
func unreviewed(model string) string {
	if autoReview(model) {
		return ""
	}
	return model
}
