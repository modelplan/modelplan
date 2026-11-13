package qwenusage

import (
	"fmt"
	"io"
	"os"
	"reflect"
	"strconv"
)

type nativeSource interface {
	io.Reader
	io.ReaderAt
	io.Seeker
	io.Closer
	Stat() (os.FileInfo, error)
}

var nativeOpenSource = func(path string) (nativeSource, error) { return nativeOpen(path) }

func nativeInteger(v reflect.Value) (string, bool) {
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
func nativeMetadata(fi os.FileInfo, key []byte) (string, string) {
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
	dev, okDev := nativeInteger(v.FieldByName("Dev"))
	ino, okIno := nativeInteger(v.FieldByName("Ino"))
	if !okDev || !okIno {
		return "", ""
	}
	ref := nativeHash(key, "qwen/file", dev+":"+ino)
	change := v.FieldByName("Ctim")
	if !change.IsValid() {
		change = v.FieldByName("Ctimespec")
	}
	if !change.IsValid() || change.Kind() != reflect.Struct {
		return ref, ""
	}
	sec, okSec := nativeInteger(change.FieldByName("Sec"))
	nano, okNano := nativeInteger(change.FieldByName("Nsec"))
	if !okSec || !okNano {
		return ref, ""
	}
	generation := fmt.Sprintf("%s:%s:%d:%d", sec, nano, fi.ModTime().UnixNano(), fi.Size())
	return ref, nativeHash(key, "qwen/change", generation)
}
func nativeFileRef(fi os.FileInfo, key []byte) string { ref, _ := nativeMetadata(fi, key); return ref }
func nativeSegment(f io.ReaderAt, key []byte, start, length int64) (string, int64) {
	if length == 0 {
		return "", 0
	}
	b := make([]byte, length)
	n, err := f.ReadAt(b, start)
	if err != nil {
		return "", int64(n)
	}
	return nativeHash(key, "qwen/checkpoint", string(b)), int64(n)
}
