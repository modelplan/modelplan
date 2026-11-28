//go:build windows

package quota

import "os"

func antigravityOpenNoFollow(string) (*os.File, error) { return nil, os.ErrPermission }

func antigravityOwnedByUser(os.FileInfo) bool { return false }
