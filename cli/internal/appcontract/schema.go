// SPDX-License-Identifier: MIT
// Package appcontract is tooling/test support, never linked into the shipped CLI.
package appcontract

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/santhosh-tekuri/jsonschema/v6"
)

type offlineLoader struct{}

func (offlineLoader) Load(url string) (any, error) {
	return nil, fmt.Errorf("schema reference is not local: %s", url)
}

type Validator struct{ schemas map[string]*jsonschema.Schema }

func NewValidator(root string) (*Validator, error) {
	c := jsonschema.NewCompiler()
	c.AssertFormat()
	c.UseLoader(offlineLoader{})
	files := []string{}
	err := filepath.WalkDir(filepath.Join(root, "schema"), func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() && d.Name() == "fixtures" {
			return filepath.SkipDir
		}
		if d.IsDir() || !strings.HasSuffix(path, ".json") {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(b))
		if err != nil {
			return err
		}
		m, ok := doc.(map[string]any)
		if !ok || m["$id"] == nil {
			return nil
		}
		if err := c.AddResource(m["$id"].(string), doc); err != nil {
			return err
		}
		if filepath.Dir(path) == filepath.Join(root, "schema", "app-cli") {
			files = append(files, strings.TrimSuffix(filepath.Base(path), ".json"))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	v := &Validator{schemas: map[string]*jsonschema.Schema{}}
	for _, name := range files {
		s, err := c.Compile("https://modelplan.ai/schema/app-cli/" + name + ".json")
		if err != nil {
			return nil, err
		}
		v.schemas[name] = s
	}
	return v, nil
}
func (v *Validator) Validate(name string, raw []byte) error {
	s, ok := v.schemas[name]
	if !ok {
		return fmt.Errorf("unknown app contract schema: %s", name)
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(raw))
	if err != nil {
		return err
	}
	return s.Validate(doc)
}
