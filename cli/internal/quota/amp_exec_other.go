//go:build !linux

package quota

import (
	"errors"
	"io"
	"os"
)

// No mutable-path fallback. Other platforms need an equally immutable execution
// primitive and its own runtime audit before this route can be admitted.
func ampSealedArtifact(io.Reader) (*os.File, error) {
	return nil, errors.New("sealed execution unsupported")
}
func ampExecPath() string { return "" }
