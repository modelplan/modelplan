// SPDX-License-Identifier: MIT
package wire

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"testing"
)

func TestCredentialResultFormattingNeverPrintsToken(t *testing.T) {
	token := "credential-token-canary"
	result := CredentialResult{OperationID: "op-1", Outcome: OutcomeOK, AccessToken: &token}
	for _, value := range []any{result, &result} {
		for _, format := range []string{"%v", "%+v", "%#v", "%s", "%q"} {
			if output := fmt.Sprintf(format, value); strings.Contains(output, token) {
				t.Errorf("%s exposed token: %s", format, output)
			}
		}
		for _, jsonLogs := range []bool{false, true} {
			var output bytes.Buffer
			var handler slog.Handler
			if jsonLogs {
				handler = slog.NewJSONHandler(&output, nil)
			} else {
				handler = slog.NewTextHandler(&output, nil)
			}
			slog.New(handler).Info("credential", slog.Any("result", value))
			if strings.Contains(output.String(), token) {
				t.Errorf("structured logger exposed token: %s", output.String())
			}
		}
	}
	// Intentional wire encoding must still carry the successful credential.
	data, err := json.Marshal(result)
	if err != nil || !bytes.Contains(data, []byte(`"accessToken":"`+token+`"`)) {
		t.Fatal("redaction broke the credential wire field")
	}
}
