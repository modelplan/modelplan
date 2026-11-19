// SPDX-License-Identifier: MIT
import Foundation

/// Wall-clock budgets on shared GitHub-hosted Macs. The convention is the one `U6StatusItemFrameTests` uses:
/// `GITHUB_ACTIONS=true` with `RUNNER_ENVIRONMENT=github-hosted`. There a single slow sample is load on a
/// shared machine, not a product regression, so a time or budget bound is enforced on the median of the
/// samples (each sample is still printed). Everywhere else, our own runners and local runs, every sample
/// must meet the bound. Only time and budget assertions use this; functional assertions never do.
enum HostedRunnerTiming {
    static var isHosted: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["GITHUB_ACTIONS"] == "true" && environment["RUNNER_ENVIRONMENT"] == "github-hosted"
    }

    static func median(_ samples: [Int]) -> Int {
        let sorted = samples.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted.count % 2 == 1 ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
    }
}
