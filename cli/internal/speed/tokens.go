package speed

// Token counts distinguish an observed zero from an absent/old field. A sum is known only if
// every contributing request recorded that kind; partial sums must not masquerade as totals.
func validToken(v *int64) *int64 {
	if v == nil || *v < 0 {
		return nil
	}
	x := *v
	return &x
}
func sumToken(a, b *int64, prior int) *int64 {
	if prior == 0 {
		return validToken(b)
	}
	if a == nil || b == nil || *a < 0 || *b < 0 {
		return nil
	}
	x := *a + *b
	if x < *a {
		return nil
	}
	return &x
}
func maxToken(a, b *int64) *int64 {
	if b == nil || *b < 0 {
		return a
	}
	if a == nil || *b > *a {
		return validToken(b)
	}
	return a
}
func equalToken(a, b *int64) bool { return a == nil && b == nil || a != nil && b != nil && *a == *b }
func tokenDelta(a, b *int64) *int64 {
	if a == nil || b == nil || *a < *b {
		return nil
	}
	x := *a - *b
	return &x
}
func uncachedInput(input, cached *int64) *int64 {
	return tokenDelta(validToken(input), validToken(cached))
}
