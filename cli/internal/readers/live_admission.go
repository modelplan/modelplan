// SPDX-License-Identifier: MIT
package readers

import (
	"context"
	"errors"
)

// ErrAdmissionWithdrawn stops a dispatch whose consent changed after the read was admitted.
var ErrAdmissionWithdrawn = errors.New("reader_admission_withdrawn")

type liveAdmissionKey struct{}

// WithLiveAdmission attaches the captured grant's live check to one admitted read. The
// ReadTransport calls it immediately before every underlying dispatch, so a revoke committed
// by another process between two stages of a read stops the next credentialed request rather
// than only discarding its outcome at publication (review 11-24 #3). A nil check is ignored.
func WithLiveAdmission(ctx context.Context, stillValid func() bool) context.Context {
	if stillValid == nil {
		return ctx
	}
	return context.WithValue(ctx, liveAdmissionKey{}, stillValid)
}

func checkLiveAdmission(ctx context.Context) error {
	if ctx == nil {
		return nil
	}
	if stillValid, ok := ctx.Value(liveAdmissionKey{}).(func() bool); ok && !stillValid() {
		return ErrAdmissionWithdrawn
	}
	return nil
}
