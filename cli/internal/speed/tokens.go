package speed

import "math"

// TokenKinds keeps unknown distinct from zero. Input is uncached input; cached reads and
// writes are separate. A sum is known only if every observed request supplied that field.
type TokenKinds struct {
	InputTokens      *int64 `json:"inputTokens"`
	CacheReadTokens  *int64 `json:"cacheReadTokens"`
	CacheWriteTokens *int64 `json:"cacheWriteTokens"`
}

func nonnegative(n *int64) *int64 {
	if n == nil || *n < 0 {
		return nil
	}
	x := *n
	return &x
}
func addKind(dst **int64, src *int64, first bool) {
	if first {
		*dst = nonnegative(src)
		return
	}
	if *dst == nil || src == nil || *src < 0 {
		*dst = nil
		return
	}
	if **dst > math.MaxInt64-*src {
		*dst = nil
		return
	}
	x := **dst + *src
	*dst = &x
}
func (k *TokenKinds) add(src TokenKinds, first bool) {
	addKind(&k.InputTokens, src.InputTokens, first)
	addKind(&k.CacheReadTokens, src.CacheReadTokens, first)
	addKind(&k.CacheWriteTokens, src.CacheWriteTokens, first)
}
func maxKind(dst **int64, src *int64) {
	if src != nil && *src >= 0 && (*dst == nil || *src > **dst) {
		x := *src
		*dst = &x
	}
}
func (k *TokenKinds) enrich(src TokenKinds) {
	maxKind(&k.InputTokens, src.InputTokens)
	maxKind(&k.CacheReadTokens, src.CacheReadTokens)
	maxKind(&k.CacheWriteTokens, src.CacheWriteTokens)
}

// Codex input_tokens includes cached_input_tokens. Normalize it before exposing the same
// cacheRead/(input+cacheRead) definition as Claude Code. Cache writes are optional in newer Codex protocol records.
type cxUsage struct {
	Write  *int64 `json:"cache_write_input_tokens"`
	Input  *int64 `json:"input_tokens"`
	Cached *int64 `json:"cached_input_tokens"`
	Output *int64 `json:"output_tokens"`
}

func (u *cxUsage) kinds() TokenKinds {
	k := TokenKinds{}
	if u == nil {
		return k
	}
	k.CacheReadTokens = nonnegative(u.Cached)
	k.CacheWriteTokens = nonnegative(u.Write)
	if u.Input != nil && u.Cached != nil && *u.Input >= *u.Cached && *u.Cached >= 0 {
		n := *u.Input - *u.Cached
		k.InputTokens = &n
	} else if u.Input != nil && u.Cached != nil && *u.Cached > *u.Input {
		k.CacheReadTokens = nil
	}
	return k
}
func usageDelta(cur, prev *cxUsage) *cxUsage {
	if cur == nil || prev == nil {
		return nil
	}
	diff := func(a, b *int64) *int64 {
		if a == nil || b == nil || *a < 0 || *b < 0 || *a < *b {
			return nil
		}
		n := *a - *b
		return &n
	}
	d := &cxUsage{Input: diff(cur.Input, prev.Input), Cached: diff(cur.Cached, prev.Cached), Output: diff(cur.Output, prev.Output), Write: diff(cur.Write, prev.Write)}
	if d.Output == nil {
		return nil
	}
	if *d.Output == 0 && (d.Input == nil || *d.Input == 0) {
		return nil
	}
	return d
}
