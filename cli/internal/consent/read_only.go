// SPDX-License-Identifier: MIT
package consent

// ReadOnly returns the same scope decisions as a schema-one migration without
// writing a backup, epoch, lock or consent file. It is for cache-only views;
// mutations and capture stamps still require the ordinary authoritative Load.
func ReadOnly(file string) (State, error) {
	s, _, err := loadRaw(file)
	if err != nil {
		return Empty(), err
	}
	if s.SchemaVersion == 1 {
		s.SchemaVersion = 2
		s.Scopes = map[string]Record{}
		for tool, record := range s.Tools {
			setToolScopes(&s, tool, record)
		}
	}
	return s, nil
}
