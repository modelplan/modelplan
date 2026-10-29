// SPDX-License-Identifier: MIT
package queries

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/store"
)

type publicationFixture struct {
	calls  int
	result digest.Publication
	err    error
}

func (f *publicationFixture) Publication(context.Context) (digest.Publication, error) {
	f.calls++
	return f.result, f.err
}

func TestPublicationUsesExistingPublicProjection(t *testing.T) {
	var data digest.Publication
	fixture := []byte(`{"contractVersion":1,"schemaVersion":1,"publicationId":"aaaaaaaaaaaaaaaaaaaaaaaa","publishedAt":null,"models":[{"id":"synthetic","ability":null}],"lineups":[],"speedTiers":[],"resets":[],"windows":[],"accounts":[{"accessToken":"synthetic-private-canary"}],"sessions":[{"path":"synthetic-private-path"}]}`)
	if err := json.Unmarshal(fixture, &data); err != nil {
		t.Fatal(err)
	}
	source := &publicationFixture{result: data}
	handler, err := PublicationHandler(source)
	if err != nil {
		t.Fatal(err)
	}
	stamp := appserver.Stamp{Epoch: "epoch-one", Generation: 41}
	reply, err := handler.Handle(context.Background(), json.RawMessage(`{}`), stamp)
	if err != nil {
		t.Fatal(err)
	}
	if handler.Private || handler.Query || handler.Capability != "publication" || len(reply.Scopes) != 0 || reply.Stamp != stamp || source.calls != 1 {
		t.Fatal("publication used a private query or lost context")
	}
	encoded, err := json.Marshal(reply.Data)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(encoded, []byte("synthetic-private")) || bytes.Contains(encoded, []byte("accessToken")) {
		t.Fatal("personal fields escaped the existing public projection")
	}
	var got digest.Publication
	if err := json.Unmarshal(encoded, &got); err != nil {
		t.Fatal(err)
	}
	if got.PublicationID != data.PublicationID || got.PublishedAt != nil || !bytes.Equal(got.Models, data.Models) {
		t.Fatal("published data was recomputed or nulls were lost")
	}
}

func TestPublicationRejectsParametersAndRawErrors(t *testing.T) {
	source := &publicationFixture{err: errors.New("synthetic-private-canary /private/path")}
	handler, err := PublicationHandler(source)
	if err != nil {
		t.Fatal(err)
	}
	for _, raw := range []string{`null`, `[]`, `{"path":"/private"}`, `{"accessToken":"synthetic-private-canary"}`} {
		reply, err := handler.Handle(context.Background(), json.RawMessage(raw), appserver.Stamp{})
		expectCode(t, reply, err, wire.CodeInvalidParams)
	}
	if source.calls != 0 {
		t.Fatal("untrusted parameters reached cache")
	}
	reply, err := handler.Handle(context.Background(), nil, appserver.Stamp{})
	expectCode(t, reply, err, wire.CodeInternal)
	if bytes.Contains([]byte(err.Error()), []byte("synthetic-private")) {
		t.Fatal("raw source error escaped")
	}
}

func TestVerifiedPublicationMissingCacheDoesNotCreateState(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "absent-cache")
	source := VerifiedPublication{Store: &store.Store{Dir: dir}}
	_, err := source.Publication(context.Background())
	var p appserver.ProtocolError
	if !errors.As(err, &p) || p.Code != wire.CodeInternal {
		t.Fatal("missing cache not refused", err)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatal("cache read created state")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, err = source.Publication(ctx)
	if !errors.Is(err, context.Canceled) {
		t.Fatal(err)
	}
}
