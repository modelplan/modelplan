// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
import AppKit
import CryptoKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
@testable import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

@MainActor final class CockpitSettingsNormalEntryTests: XCTestCase {
    func testCommittedAppearanceReachesActualPageLoadAndLaterMessages() async throws {
        for initial in [16,nil] as [Int?] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-settings-entry-"+UUID().uuidString)
            let assets=root.appendingPathComponent("bundle")
            try FileManager.default.createDirectory(at:assets,withIntermediateDirectories:true)
            defer { try? FileManager.default.removeItem(at:root) }
            func hash(_ bytes:Data)->String { SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined() }
            let html=Data("<html>synthetic</html>".utf8);try html.write(to:assets.appendingPathComponent("index.html"))
            let manifest=try JSONSerialization.data(withJSONObject:["schemaVersion":1,"edition":"community","interfaceOnly":true,"files":["index.html":hash(html)]])
            try manifest.write(to:assets.appendingPathComponent("bundle-manifest.json"))
            let bundle=try VerifiedCockpitBundle(root:assets,manifestSHA256:hash(manifest))
            let store=try EngineRowsEntry.makeSettingsStore(applicationSupport:root.appendingPathComponent("profile"),preferredLanguages:["en"])
            _ = try await store.update { p in p.theme = .night;p.motion = .on;p.transparency = .on;if let initial { p.redBelow=initial } }
            var fanout:CockpitStoreFanout?, page:CockpitWindowController?, sent=[String]()
            let previous=CommunityCockpitApplicationFactory.verificationPage
            CommunityCockpitApplicationFactory.verificationPage = { actual in
                page=actual
                actual.verificationNoWindowShell = .init(closed:false,attached:true,forcedClosed:false,tier:.tall)
                actual.verificationNoWindowDelivery = { raw,complete in sent.append(raw);complete(.accepted) }
                actual.onFailure = { failure in XCTFail("Actual page failure: \(failure)") }
            }
            defer { CommunityCockpitApplicationFactory.verificationPage=previous;page?.discard() }
            let app=CommunityCockpitApplicationFactory.makeForChecks(configuration:.init(executableURL:root.appendingPathComponent("not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:store,bundleURL:root,cockpitEntryEnabled:true,verifiedBundleForChecks:bundle) { config,consumer in
                fanout=consumer as? CockpitStoreFanout
                return ProcessEngineClient(configuration:config,consumer:consumer)
            }
            defer { app.composition.dock.close() }
            await app.prepare()
            let context=EngineDeliveryContext(sessionID:UUID().uuidString,floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
            await try XCTUnwrap(fanout).consume(.context(context))
            app.showConsole()
            let until=ContinuousClock.now + .seconds(5)
            while page == nil, ContinuousClock.now < until { await Task.yield() }
            let actual=try XCTUnwrap(page)
            actual.verificationStartPageWithoutWindow()
            let load=try XCTUnwrap(sent.first)
            func object(_ raw:String) throws -> [String:Any] { try XCTUnwrap(JSONSerialization.jsonObject(with:Data(raw.utf8)) as? [String:Any]) }
            let first=try object(load), appearance=try XCTUnwrap(first["appearance"] as? [String:Any])
            XCTAssertEqual(first["type"] as? String,"load")
            XCTAssertEqual(first["redBelow"] as? Int,initial ?? 25)
            XCTAssertEqual(appearance["reduceMotion"] as? Bool,true)
            XCTAssertEqual(appearance["reduceTransparency"] as? Bool,true)
            // The peer is the browser boundary only. Controller, bridge, factory and Settings are real.
            var ready=first
            for key in ["data","appearance","shell","redBelow","nowUnixMs","reason"] { ready[key]=nil }
            ready["type"]="ready";ready["sequence"]="1";ready["appearanceVersion"]=2
            ready["capabilities"]=["appearanceUpdates","shellState","shellActions"]
            actual.verificationReceive(String(decoding:try JSONSerialization.data(withJSONObject:ready),as:UTF8.self),source:.init(mainFrame:true,origin:"modelplan-cockpit://bundle"))
            try actual.verificationConfirmVisible()
            app.updateSystemAccessibility(SettingsEnvironment())
            _ = try await app.settingsHost.application.editor.commit(SettingsB20Edit.redBelow(20))
            _ = try await app.settingsHost.application.editor.commit(SettingsB20Edit.motion(.system))
            _ = try await app.settingsHost.application.editor.commit(SettingsB20Edit.transparency(.system))
            let updates=try sent.map(object).filter { $0["type"] as? String == "appearance" }
            let latest=try XCTUnwrap(updates.last)
            XCTAssertEqual(latest["redBelow"] as? Int,20)
            XCTAssertEqual(latest["reduceMotion"] as? Bool,false)
            XCTAssertEqual(latest["reduceTransparency"] as? Bool,false)
            XCTAssertNil(actual.window);XCTAssertFalse(actual.stateForChecks.hasWebView)
        }
    }
}
#endif
