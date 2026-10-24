// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

/// Explicit test-only CLI access receipt. The caller supplies an isolated synthetic home and output.
/// Runs the packaged helper with the same production Process boundary. No real account access.
struct ProbeReceipt: Codable {
    var schemaVersion = 1
    let launchedFromApp: Bool
    let helperBundled: Bool
    let outcome: String
    let cliVersion: String?
    let quotaWindows: Int
    let remaining: [Double]
    let readOnlyArguments: [String]
}
enum AccessProbe {
    static func run(home: URL, result: URL) async {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/modelplan")
        let environment = ["HOME":home.path, "CODEX_HOME":home.appendingPathComponent("codex").path,
            "CLAUDE_CONFIG_DIR":home.appendingPathComponent("claude").path,
            "MODELPLAN_CACHE":home.appendingPathComponent("cache").path,
            "XDG_CONFIG_HOME":home.appendingPathComponent("config").path,
            "XDG_DATA_HOME":home.appendingPathComponent("data").path,
            "PATH":"/usr/bin:/bin", "NO_COLOR":"1"]
        var outcome = "unavailable", count = 0, remaining: [Double] = []
        var cliVersion: String?
        do {
            let response = try await ProcessCLITransport(executable: helper, environment: environment).execute(.desktop)
            if response.exitCode == 0 {
                let snapshot = try FeedDecoder.personal(response.stdout)
                cliVersion = snapshot.cliVersion
                let windows = (snapshot.accounts ?? []).flatMap { $0.windows ?? [] }
                count = windows.count; remaining = windows.compactMap(\.remainingPercent)
                outcome = remaining.isEmpty ? "unavailable" : "observed"
            }
        } catch { outcome = "helper-unavailable" }
        let receipt = ProbeReceipt(launchedFromApp: Bundle.main.bundleURL.pathExtension == "app",
            helperBundled: FileManager.default.isExecutableFile(atPath: helper.path), outcome: outcome,
            cliVersion: cliVersion, quotaWindows: count, remaining: remaining, readOnlyArguments: CLICommand.desktop.arguments)
        if let encoded = try? JSONEncoder().encode(receipt) { try? encoded.write(to: result, options: .atomic) }
    }
}
