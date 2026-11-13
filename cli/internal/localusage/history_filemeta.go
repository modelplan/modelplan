package localusage

import (
	"fmt"
	"io"
	"os"
	"reflect"
	"strconv"
)

type historySource interface {
	io.Reader
	io.ReaderAt
	io.Seeker
	io.Closer
	Stat() (os.FileInfo, error)
}

var historyOpenSource = func(path string) (historySource, os.FileInfo, error) { return historyOpen(path) }

func historyInteger(v reflect.Value) (string, bool) {
	if v.IsValid() && v.CanInt() {
		return strconv.FormatInt(v.Int(), 10), true
	}
	if v.IsValid() && v.CanUint() {
		return strconv.FormatUint(v.Uint(), 10), true
	}
	return "", false
}

// Dev is signed int32 on Darwin and unsigned on Linux. Keep either representation
// exact and transient; only keyed inode/change references enter the cache.
func historyMetadata(fi os.FileInfo, key []byte) (string, string) {
	if fi == nil {
		return "", ""
	}
	v := reflect.ValueOf(fi.Sys())
	if v.Kind() == reflect.Pointer {
		v = v.Elem()
	}
	if v.Kind() != reflect.Struct {
		return "", ""
	}
	dev, okDev := historyInteger(v.FieldByName("Dev"))
	ino, okIno := historyInteger(v.FieldByName("Ino"))
	if !okDev || !okIno {
		return "", ""
	}
	ref := historyHash(key, "history/file", dev+":"+ino)
	change := v.FieldByName("Ctim")
	if !change.IsValid() {
		change = v.FieldByName("Ctimespec")
	}
	if !change.IsValid() || change.Kind() != reflect.Struct {
		return ref, ""
	}
	sec, okSec := historyInteger(change.FieldByName("Sec"))
	nano, okNano := historyInteger(change.FieldByName("Nsec"))
	if !okSec || !okNano {
		return ref, ""
	}
	generation := fmt.Sprintf("%s:%s:%d:%d", sec, nano, fi.ModTime().UnixNano(), fi.Size())
	return ref, historyHash(key, "history/change", generation)
}
func historyFileRef(fi os.FileInfo, key []byte) string {
	ref, _ := historyMetadata(fi, key)
	return ref
}
func historySegment(f io.ReaderAt, key []byte, start, length int64) (string, int64) {
	if length == 0 {
		return "", 0
	}
	b := make([]byte, length)
	n, err := f.ReadAt(b, start)
	if err != nil {
		return "", int64(n)
	}
	return historyHash(key, "history/checkpoint", string(b)), int64(n)
}
