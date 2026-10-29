// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

extension EventProbe {
    func publications() -> [EngineReply<WirePublicationResult>] { events.compactMap {
        if case .response(_, .publication(let reply)) = $0 { return reply }; return nil
    } }
    func installations() -> [EngineReply<WirePluginInstallResult>] { events.compactMap {
        if case .response(_, .pluginInstall(let reply)) = $0 { return reply }; return nil
    } }
    func cockpits() -> [EngineReply<WireCockpitData>] { events.compactMap {
        if case .response(_, .cockpit(let reply)) = $0 { return reply }; return nil
    } }
    func failed(_ feature: EngineFeature) -> Bool { events.contains {
        if case .featureFailure(let value, _) = $0 { return value == feature }; return false
    } }
}

extension ProcessEngineClient {
    func pendingQueryCount() -> Int { pending.values.filter { ["cockpit/query", "history/query"].contains($0.method) }.count }
    func hasQueuedCockpit() -> Bool { deliveries.contains { if case .response(_, .cockpit) = $0.event { return true }; return false } }
}

extension RealBinaryTests {
    func preparedFeatureHome(_ binary: URL) throws -> URL {
        let root = try home()
        try cli(binary, home: root, arguments: ["consent", "init", "--json"])
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        let grant = try grantParams(state(root), allow: ["codex.local_history"])
        try cli(binary, home: root, arguments: ["consent", "grant", "--json"], input: JSONEncoder().encode(grant))
        return root
    }
    func seedPublication(_ root: URL) throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_ENGINE_TEST_PROXY"] else { throw XCTSkip("Build FrameProxy") }
        try cli(URL(fileURLWithPath: path), home: root, arguments: ["seed-publication"])
    }
    func releaseFeatures(_ root: URL) throws { try Data().write(to: root.appendingPathComponent("release-feature")) }

    func testRealPluginResultReplacesProvisionalFailure() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        _ = try await client.start()
        for tool in [WirePluginTool.codex, .claudeCode] {
            let completion = try await client.pluginInstall(try WirePluginInstallParams(tool: tool, offline: true))
            let observed1 = await probe.installations().last
            let reply = try XCTUnwrap(observed1)
            XCTAssertEqual(reply.envelope.data.tool, tool)
            XCTAssertEqual(reply.envelope.data.status, .planned)
            XCTAssertEqual(reply.envelope.data.completed, 0)
            XCTAssertEqual(reply.envelope.data.commands.count, 2)
            XCTAssertEqual(reply.envelope.data.schemaVersion, 1)
            XCTAssertFalse(requestKey(completion.requestID).isEmpty)
        }
        let observed2 = await probe.installations().count
        XCTAssertEqual(observed2, 2)
        let observed3 = await probe.orderedClears()
        XCTAssertTrue(observed3)
    }

    func testRealPublicationMatchesVerifiedCLIProjection() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        try seedPublication(home)
        let expected = try cli(binary, home: home, arguments: ["publication", "--json", "--offline"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let context = try await client.start()
        _ = try await client.publication()
        let observed4 = await probe.publications().last
        let reply = try XCTUnwrap(observed4)
        XCTAssertEqual(reply.delivery, context)
        XCTAssertEqual(reply.envelope.data.units.ability, "websiteAbility")
        XCTAssertEqual(reply.envelope.data.selectionRevision, "synthetic-revision")
        // Compare original verified values, including null and an integer above 2^53.
        let actual = try JSONSerialization.jsonObject(with: JSONEncoder().encode(reply.envelope.data)) as? NSDictionary
        let original = try JSONSerialization.jsonObject(with: expected) as? NSDictionary
        XCTAssertEqual(actual, original)
        let observed5 = await probe.orderedClears()
        XCTAssertTrue(observed5)
    }

    func testRealCockpitDeliversTypedProjectionAndScopes() async throws {
        let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let context = try await client.start()
        _ = try await client.cockpit()
        let observed6 = await probe.cockpits().last
        let reply = try XCTUnwrap(observed6)
        XCTAssertEqual(reply.delivery, context)
        XCTAssertEqual(reply.envelope.sessionId, context.sessionID)
        XCTAssertTrue(reply.envelope.scopes?.contains("codex.local_history") == true)
        XCTAssertEqual(reply.envelope.data.projection.rowsVersion, 1)
        XCTAssertFalse(reply.envelope.data.projection.rows.isEmpty)
        let observed7 = await probe.orderedClears()
        XCTAssertTrue(observed7)
    }

    func testRealCockpitHigherGenerationWaitsForAcknowledgedClear() async throws {
        let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "cockpit-higher"), home: home), consumer: probe)
        addTeardownBlock { await probe.resumeClear(); await client.stop() }
        let original = try await client.start()
        await probe.suspendNextClear()
        let flag = CompletionFlag()
        let request = Task { let result = try await client.cockpit(); await flag.complete(); return result }
        try await eventually { await probe.clearIsPaused() }
        let observed8 = await probe.cockpits().count
        XCTAssertEqual(observed8, 0)
        let observed9 = await flag.value()
        XCTAssertFalse(observed9)
        await probe.resumeClear()
        _ = try await request.value
        let observed10 = await probe.cockpits().last
        let reply = try XCTUnwrap(observed10)
        XCTAssertEqual(reply.delivery.floor.generation, original.floor.generation + 1)
        let observed11 = await probe.orderedClears()
        XCTAssertTrue(observed11)
    }

    func testRealCockpitUnfamiliarEpochRequiresAuthoritativeConfirmation() async throws {
        let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "cockpit-foreign-epoch"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let original = try await client.start()
        do { _ = try await client.cockpit(); XCTFail("unconfirmed epoch delivered") }
        catch EngineClientError.supersededEpoch {} catch EngineClientError.staleValue {}
        try await eventually { await client.hasOpenFloor(original.floor) }
        let observed12 = await probe.cockpits().count
        XCTAssertEqual(observed12, 0)
        let observed13 = await client.floor
        XCTAssertEqual(observed13, original.floor)
        XCTAssertTrue(traceContains(home, method: "consent/get"))
        let observed14 = await probe.orderedClears()
        XCTAssertTrue(observed14)
    }

    func testRealCockpitWrongSessionDoesNotChangeFloor() async throws {
        let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "cockpit-wrong-session"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let original = try await client.start()
        _ = try await client.cockpit()
        let observed15 = await probe.cockpits().count
        XCTAssertEqual(observed15, 1)
        let observed16 = await client.floor
        XCTAssertEqual(observed16, original.floor)
    }

    func testRealCockpitAndHistoryShareTwoQuerySlotsAndCancel() async throws {
        let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "hold-features"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        _ = try await client.start()
        let cockpit = Task { try await client.cockpit() }
        let history = Task { try await client.history(try WireHistoryQueryParams(kind: .tokens, tool: "codex", limit: 1)) }
        try await eventually { await client.pendingQueryCount() == 2 }
        do { _ = try await client.cockpit(); XCTFail("third query exceeded shared limit") } catch EngineClientError.localBusy {}
        do { _ = try await client.history(try WireHistoryQueryParams(kind: .tokens, tool: "codex", limit: 1)); XCTFail("history bypassed shared limit") } catch EngineClientError.localBusy {}
        try await eventually { self.traceContains(home, method: "held-cockpit/query") }
        cockpit.cancel(); history.cancel()
        do { _ = try await cockpit.value; XCTFail("canceled query succeeded") } catch EngineClientError.interrupted(.cancelled) {}
        do { _ = try await history.value; XCTFail("canceled history succeeded") } catch EngineClientError.interrupted(.cancelled) {}
        try await eventually { self.traceContains(home, method: "$/cancel") }
        try releaseFeatures(home)
        try await Task.sleep(for: .milliseconds(100))
        let observed17 = await probe.cockpits().count
        XCTAssertEqual(observed17, 0)
    }

    func testRealCockpitLateReplyAfterEpochResetIsDiscarded() async throws {
        let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "hold-features"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let original = try await client.start()
        let request = Task { try await client.cockpit() }
        try await eventually { self.traceContains(home, method: "held-cockpit/query") }
        try cli(binary, home: home, arguments: ["consent", "reset", "confirmed", "--json"])
        do { _ = try await request.value; XCTFail("old epoch query succeeded") } catch EngineClientError.supersededEpoch {}
        try await eventually { await probe.readyContexts().contains { $0.floor.storeEpoch != original.floor.storeEpoch } }
        try releaseFeatures(home)
        _ = try await client.diagnostics()
        let observed18 = await probe.cockpits().count
        XCTAssertEqual(observed18, 0)
        let observed19 = await probe.orderedClears()
        XCTAssertTrue(observed19)
    }

    func testRealCockpitDeadlineSendsCancelAndDropsLateReply() async throws {
        let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "hold-features"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        _ = try await client.start()
        do { _ = try await client.cockpit(timeout: .milliseconds(150)); XCTFail("held query succeeded") } catch EngineClientError.deadlineExceeded(.cancelled) {}
        try await eventually { self.traceContains(home, method: "$/cancel") }
        try releaseFeatures(home)
        try await Task.sleep(for: .milliseconds(100))
        let observed20 = await probe.cockpits().count
        XCTAssertEqual(observed20, 0)
    }

    func testRealSentPluginCancellationAndRestartAreUnknown() async throws {
        for reason in ["cancel", "restart", "deadline"] {
            let binary = try binary(); let home = try home(); let probe = EventProbe()
            try cli(binary, home: home, arguments: ["consent", "init", "--json"])
            let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "hold-features"), home: home), consumer: probe)
            addTeardownBlock { await client.stop() }
            _ = try await client.start()
            let request = Task { try await client.pluginInstall(try WirePluginInstallParams(tool: .codex, offline: true), timeout: .milliseconds(500)) }
            try await eventually { self.traceContains(home, method: "held-plugin/install") }
            if reason == "cancel" { request.cancel() }
            let observed21 = await client.processIdentifier
            if reason == "restart" { XCTAssertEqual(kill(try XCTUnwrap(observed21), SIGKILL), 0) }
            do { _ = try await request.value; XCTFail("unknown install reported success") }
            catch EngineClientError.interrupted(.outcomeUnknown) { XCTAssertNotEqual(reason, "deadline") }
            catch EngineClientError.deadlineExceeded(.outcomeUnknown) { XCTAssertEqual(reason, "deadline") }
            let observed22 = await probe.installations().count
            XCTAssertEqual(observed22, 0)
        }
    }

    func testRealMalformedTypedResultsAreFeatureLocal() async throws {
        for mode in ["cockpit-malformed", "publication-malformed", "plugin-wrong-tool", "plugin-unknown-status", "plugin-invalid-completed"] {
            let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
            try seedPublication(home)
            let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: mode), home: home), consumer: probe)
            addTeardownBlock { await client.stop() }
            let original = try await client.start()
            try await eventually { await probe.rowCount() > 0 }
            let feature: EngineFeature = mode.hasPrefix("cockpit") ? .cockpit : mode.hasPrefix("publication") ? .publication : .pluginInstall
            do {
                if feature == .cockpit { _ = try await client.cockpit() }
                else if feature == .publication { _ = try await client.publication() }
                else { _ = try await client.pluginInstall(try WirePluginInstallParams(tool: .codex, offline: true)) }
                XCTFail("malformed typed body reported success: " + mode)
            } catch EngineClientError.featureDecode(let value) { XCTAssertEqual(value, feature) }
            _ = try await client.diagnostics()
            let observed23 = await probe.failed(feature)
            XCTAssertTrue(observed23)
            let observed24 = try await client.start()
            XCTAssertEqual(observed24, original)
            let observed25 = await probe.cockpits().count
            let observed26 = await probe.publications().count
            let observed27 = await probe.installations().count
            XCTAssertEqual(observed25 + observed26 + observed27, 0)
        }
    }
}

extension RealBinaryTests {
    func testRealPluginStatusesRemainTypedReceiptsNotInstallationAssertions() async throws {
        for status in [WirePluginInstallStatus.instructions, .installed, .failed] {
            let binary = try binary(); let home = try home(); let probe = EventProbe()
            try cli(binary, home: home, arguments: ["consent", "init", "--json"])
            let bin = home.appendingPathComponent("bin")
            try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
            if status != .instructions {
                // Inert host under this test's HOME. No real plugin/network call.
                let script = status == .installed ? "#!/bin/sh\nexit 0\n" : "#!/bin/sh\nif [ \"$2\" = \"add\" ]; then exit 7; fi\nexit 0\n"
                let host = bin.appendingPathComponent("codex")
                try Data(script.utf8).write(to: host)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: host.path)
            }
            var env = environment(home); env["PATH"] = bin.path
            let config = EngineClientConfiguration(executableURL: binary, applicationVersion: "synthetic-typed-results", allowedEnvironment: env)
            let client = ProcessEngineClient(configuration: config, consumer: probe)
            addTeardownBlock { await client.stop() }
            _ = try await client.start()
            _ = try await client.pluginInstall(try WirePluginInstallParams(tool: .codex))
            let replies = await probe.installations()
            let reply = try XCTUnwrap(replies.last)
            XCTAssertEqual(reply.envelope.data.status, status)
            XCTAssertEqual(reply.envelope.data.completed, status == .installed ? 2 : status == .failed ? 1 : 0)
            XCTAssertEqual(reply.envelope.data.commands.count, 2)
            XCTAssertEqual(reply.envelope.data.docs, "https://github.com/modelplan/modelplan/tree/main/codex")
        }
    }

    func testRealNewMethodsRequireCapabilitiesBeforeSending() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "without-features"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        _ = try await client.start()
        do { _ = try await client.cockpit(); XCTFail("unsupported cockpit sent") } catch EngineClientError.unsupportedCapability {}
        do { _ = try await client.publication(); XCTFail("unsupported publication sent") } catch EngineClientError.unsupportedCapability {}
        do { _ = try await client.pluginInstall(try WirePluginInstallParams(tool: .codex)); XCTFail("unsupported install sent") } catch EngineClientError.unsupportedCapability {}
        for method in ["cockpit/query", "publication/get", "plugin/install"] { XCTAssertFalse(traceContains(home, method: method)) }
    }

    func testRealQueuedCockpitIsRecheckedAfterRevoke() async throws {
        let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await probe.resumeResponse(); await client.stop() }
        let original = try await client.start()
        try await eventually { await probe.rowCount() > 0 }
        await probe.suspendNextResponse()
        let control = Task { try await client.diagnostics() }
        try await eventually { await probe.responseIsPaused() }
        let query = Task { try await client.cockpit() }
        try await eventually { await client.hasQueuedCockpit() }
        try externalGrant(binary, home: home, deny: ["codex.local_history"])
        try await eventually { await client.floor?.generation != original.floor.generation }
        await probe.resumeResponse()
        _ = try await control.value
        do { _ = try await query.value; XCTFail("queued old cockpit escaped") } catch EngineClientError.staleValue {}
        let delivered = await probe.cockpits().count
        XCTAssertEqual(delivered, 0)
        try await eventually { await probe.readyContexts().contains { $0.floor.generation > original.floor.generation } }
        let ordered = await probe.orderedClears()
        XCTAssertTrue(ordered)
    }

    func testRealLateCockpitAfterSameEpochRevokeIsDiscarded() async throws {
        let binary = try binary(); let home = try preparedFeatureHome(binary); let probe = EventProbe()
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "hold-features"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let original = try await client.start()
        let query = Task { try await client.cockpit() }
        try await eventually { self.traceContains(home, method: "held-cockpit/query") }
        try externalGrant(binary, home: home, deny: ["codex.local_history"])
        try await eventually { await client.floor?.generation != original.floor.generation }
        try releaseFeatures(home)
        do { _ = try await query.value; XCTFail("late revoked cockpit escaped") } catch EngineClientError.staleValue {}
        let delivered = await probe.cockpits().count
        XCTAssertEqual(delivered, 0)
        let current = await client.floor
        XCTAssertEqual(current?.storeEpoch, original.floor.storeEpoch)
        let ordered = await probe.orderedClears()
        XCTAssertTrue(ordered)
    }
}
