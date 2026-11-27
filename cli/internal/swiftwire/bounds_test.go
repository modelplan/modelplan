// SPDX-License-Identifier: MIT
package swiftwire

import (
	"reflect"
	"strconv"
	"strings"
	"testing"
)

// macrevb-1299-1: every seeded number respects the schema bounds its field declares, so the Swift and web
// decoders accept the real Go captures (a share above 1 made Swift throw invalidBound).
func TestCaptureSeedsRespectSchemaBounds(t *testing.T) {
	m, err := load(repoRoot(t))
	if err != nil {
		t.Fatal(err)
	}
	checked := 0
	var walk func(v reflect.Value, path string, tag string)
	walk = func(v reflect.Value, path, tag string) {
		switch v.Kind() {
		case reflect.Pointer, reflect.Interface:
			if !v.IsNil() {
				walk(v.Elem(), path, tag)
			}
		case reflect.Float64:
			for _, part := range strings.Split(tag, ",") {
				k, val, ok := strings.Cut(part, "=")
				n, err := strconv.ParseFloat(val, 64)
				if !ok || err != nil {
					continue
				}
				if k == "minimum" && v.Float() < n || k == "maximum" && v.Float() > n {
					t.Errorf("%s = %v violates %s", path, v.Float(), part)
				}
				checked++
			}
		case reflect.Struct:
			for i := 0; i < v.NumField(); i++ {
				if f := v.Type().Field(i); f.IsExported() {
					walk(v.Field(i), path+"."+f.Name, f.Tag.Get("schema"))
				}
			}
		case reflect.Slice:
			for i := 0; i < v.Len(); i++ {
				walk(v.Index(i), path+"[]", tag)
			}
		case reflect.Map:
			for _, k := range v.MapKeys() {
				walk(v.MapIndex(k), path+"{}", tag)
			}
		}
	}
	for _, root := range captureRoots() {
		v, err := m.seed(root.Type, root.Name)
		if err != nil {
			t.Fatal(err)
		}
		walk(v, root.Name, "")
	}
	if checked == 0 {
		t.Fatal("no bounded number was seeded")
	}
}
