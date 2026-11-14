// SPDX-License-Identifier: MIT
// Linux and Mac runner for the pure-Swift entrance checks: `swift run ModelPlanEntranceChecks`.
import Foundation
import ModelPlanEntranceChecksKit

let run = EntranceChecks.run()
for name in run.passed { print("PASS \(name)") }
for failure in run.failures { print("FAIL \(failure)") }
print("\(run.passed.count) groups passed, \(run.failures.count) failed, \(run.assertions) assertions")
exit(run.failures.isEmpty ? 0 : 1)
