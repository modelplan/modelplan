package main

import "os"

// Tests here point HOME at a temporary directory and write consent and cache files there.
// An inherited MODELPLAN_PROFILE_ROOT would win over HOME and send those writes into a real
// profile, so no test in this package starts with one. A test that needs a root sets its own.
var _ = os.Unsetenv("MODELPLAN_PROFILE_ROOT")
