// SPDX-License-Identifier: MIT
package releaseguard

import (
	"bytes"
	"errors"
	"os"
)

// KnownPrivateSPINames is deliberately small. The release backstop looks for
// these names in the built binary's strings, symbols and selector data, regardless
// of how a source literal was written. This is not a catalogue of all Apple SPI.
var KnownPrivateSPINames = []string{"_webProcessIdentifier"}

func CheckBinary(path string) ([]string, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() || info.Size() == 0 {
		return nil, errors.New("release binary must be a non-empty regular file")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var hits []string
	for _, name := range KnownPrivateSPINames {
		if bytes.Contains(data, []byte(name)) {
			hits = append(hits, name)
		}
	}
	return hits, nil
}
