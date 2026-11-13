// SPDX-License-Identifier: MIT
import Foundation
import CoreFoundation
import ModelPlanCore

actor SyntheticCLI: CLITransport {
    let personal: Data, publication: Data
    init(personal: Data, publication: Data) { self.personal = personal; self.publication = publication }
    func execute(_ command: CLICommand) async throws -> CommandResult {
        CommandResult(exitCode: 0, stdout: command == .desktop ? personal : publication)
    }
}

MainActor.assumeIsolated {
    let start = Date(), iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let document: [String:Any] = [
        "schemaVersion":1, "kind":"modelplan.personal-snapshot", "generatedAt":iso.string(from:start),
        "validUntil":iso.string(from:start.addingTimeInterval(0.45)), "dataRevision":"unchanged",
        "publication":["publicationId":"synthetic"],
        "accounts":[["source":"codex", "observedAt":iso.string(from:start), "stale":false,
            "windows":[["kind":"five_hour", "remainingPercent":37, "observedAt":iso.string(from:start),
                "resetsAt":iso.string(from:start.addingTimeInterval(0.25))]]]]
    ]
    let personal = try! JSONSerialization.data(withJSONObject: document)
    let publication = Data(#"{"schemaVersion":1,"publicationId":"synthetic","units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},"models":[],"lineups":[]}"#.utf8)
    let store = SnapshotStore(transport:SyntheticCLI(personal:personal,publication:publication))
    var tracking = false, resetDuringTracking = false, expiryDuringTracking = false, callbacks = 0
    store.onChange = {
        guard tracking else { return }
        callbacks += 1
        if store.view()?.presentation.quotas.first?.remaining == nil { resetDuringTracking = true }
        if store.view()?.presentation.actionable == false { expiryDuringTracking = true }
    }
    store.start()
    let readyLimit = Date().addingTimeInterval(0.15)
    while !store.idle && Date() < readyLimit { RunLoop.main.run(until:Date().addingTimeInterval(0.005)) }
    guard store.idle, store.view()?.presentation.quotas.first?.remaining == 37 else {
        fputs("FAIL synthetic run-loop setup did not become ready before its deadline\n",stderr); exit(1)
    }
    let mode = CFRunLoopMode(rawValue: "ModelPlanSyntheticTracking" as CFString)
    CFRunLoopAddCommonMode(CFRunLoopGetMain(),mode)
    tracking = true
    CFRunLoopRunInMode(mode,0.65,false)
    tracking = false
    store.suspend()
    RunLoop.main.run(until:Date().addingTimeInterval(0.03))
    guard resetDuringTracking, expiryDuringTracking, callbacks >= 2, callbacks <= 8 else {
        fputs("FAIL deadlines deferred/spinning in common tracking mode: callbacks=\(callbacks)\n",stderr); exit(1)
    }
    print("PASS common-mode reset and validUntil expiry inside a nested CFRunLoop mode; callbacks=\(callbacks)")
    print("Synthetic timer integration only; physical AppKit menu/input and OS lifecycle acceptance remain separate")
}
