// SPDX-License-Identifier: MIT
package rows

// classification contains facts only; neither names nor provider text can
// decide consent. Candidate membership is applied before this total classifier.
type classification struct {
	Declared                        bool
	Veto                            Code
	Consent                         Consent
	Outdated, Changed, Cleanup      bool
	Detected, Retired, ReaderExists bool
	Keychain                        Code
	Current, Retained, None         int
	UnknownTime                     bool
	Latest                          AttemptResult
	Failure                         Code
	Busy                            bool
	Estimated                       bool
}

// classify is the first matching row of the approved table. Missing/retired
// precedes no_reader per the coordinator's adjudication on #570 (6492199667).
func classify(f classification) Outcome {
	if f.Veto != "" && (!f.Declared || f.Veto == CodePrivacyBlocked) {
		return Describe(f.Veto)
	} // 1
	if !f.Declared {
		if f.Changed {
			return Describe(CodeConsentChanged)
		} // 2
		if f.Cleanup {
			return Describe(CodeCleanupPending)
		}
		if f.Outdated {
			return Describe(CodeConsentOutdated)
		}
		switch f.Consent {
		case ConsentDenied:
			return Describe(CodeConsentDenied)
		case ConsentUnset, "":
			return Describe(CodeConsentRequired)
		}
		if f.Retired {
			return Describe(CodeCatalogueRetired)
		} // 3
		if !f.Detected {
			return Describe(CodeToolNotFound)
		}
		if !f.ReaderExists {
			return Describe(CodeNoReader)
		} // 4
		if f.Current == 0 && f.Keychain != "" {
			return Describe(f.Keychain)
		} // 5
		if f.Current == 0 && f.Retained == 0 && f.Latest == AttemptResultFailed { // 6
			return Describe(f.Failure)
		}
		if f.Current == 0 && f.Retained == 0 && f.Latest == AttemptResultSucceeded {
			return Describe(CodeNoUsageWindows)
		} // 7
	}
	if f.Current == 0 && f.Retained == 0 { // 8
		if f.Declared {
			return Describe(CodeNoManualReading)
		}
		if f.Busy {
			return Describe(CodeReaderBusy)
		}
		if f.Latest == AttemptResultNever || f.Latest == "" {
			return Describe(CodeNotReadYet)
		}
	} else if f.Retained > 0 { // 9
		if f.UnknownTime {
			return Describe(CodeObservationTimeUnknown)
		}
		return Describe(CodeStaleReading)
	} else if f.Current > 0 { // 10: C + N is fresh; R always took precedence.
		if f.Estimated {
			return Describe(CodeEstimated)
		}
		return Describe(CodeOK)
	}
	return Describe(CodeOther) // 11: unreachable for normalized facts; tested.
}
