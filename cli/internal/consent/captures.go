// SPDX-License-Identifier: MIT
package consent

// CaptureStamp records the authority under which a retained private reading
// was obtained. Its generation belongs only to its store epoch and scope.
type CaptureStamp struct {
	StoreEpoch string `json:"storeEpoch"`
	Generation uint64 `json:"generation"`
	Scope      string `json:"scope"`
}

func (s State) CaptureStamp(scope string) *CaptureStamp {
	return &CaptureStamp{s.StoreEpoch, s.Generation, scope}
}

// CaptureAllowed never relabels a retained reading with a newer grant. Revoke
// watermarks are generations within State.StoreEpoch, keyed by exact scope.
func (s State) CaptureAllowed(stamp *CaptureStamp, scope string) bool {
	// Legacy unbound caches are readable only before a consent store exists.
	// Initialization/migration and every reset make this exception unavailable.
	if stamp == nil {
		return s.StoreEpoch == "" && len(s.Revoked) == 0
	}
	if stamp.Scope != scope || stamp.StoreEpoch != s.StoreEpoch || stamp.Generation > s.Generation {
		return false
	}
	watermark, revoked := s.Revoked[scope]
	return !revoked || stamp.Generation > watermark
}
func (s *State) RevokeScope(scope string) {
	if s.Revoked == nil {
		s.Revoked = map[string]uint64{}
	}
	s.Revoked[scope] = s.Generation + 1
}
func (s State) ScopeFor(tool, class string) string { return s.scopeFor(tool, class) }
