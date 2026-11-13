// SPDX-License-Identifier: MIT
package consent

// FinalizationError distinguishes failures after the durable commit point.
// Its receipt is the original committed recovery result, never the unpersisted
// in-memory cleanup result. It contains no provider or credential error text.
type FinalizationError struct {
	cause    error
	fence    Fence
	receipts map[string]Receipt
}

func (e *FinalizationError) Error() string {
	return "consent committed; cleanup persistence incomplete"
}
func (e *FinalizationError) Unwrap() error { return e.cause }
func (e *FinalizationError) Fence() Fence  { return e.fence }
func (e *FinalizationError) Receipt(key string) (Receipt, bool) {
	r, ok := e.receipts[key]
	return copyReceipt(r), ok
}
func copyReceipt(r Receipt) Receipt {
	r.Result = append([]byte(nil), r.Result...)
	r.PendingForget = append([]string(nil), r.PendingForget...)
	if r.ForgetScopes != nil {
		m := map[string]bool{}
		for k, v := range r.ForgetScopes {
			m[k] = v
		}
		r.ForgetScopes = m
	}
	return r
}
