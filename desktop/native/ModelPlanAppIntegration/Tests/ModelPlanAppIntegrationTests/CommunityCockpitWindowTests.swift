// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
@testable import ModelPlanCockpitWeb
import ModelPlanWire
@testable import ModelPlanAppIntegration

final class CommunityCockpitWindowTests:XCTestCase {
    // Factory/window regressions salvaged from PR #465.
    @MainActor private func shellFixture() throws -> (CockpitConsoleOwner, VerifiedCockpitBundle, CockpitEngineContext, CGRect) {
        guard ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true", let screen=NSScreen.main,
              screen.visibleFrame.height > 706, screen.visibleFrame.width > 700 else {
            throw XCTSkip("Requires the CI graphical session and a display large enough for the shell")
        }
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("shell-entry-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:root) }
        func digest(_ data:Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        let html=Data("<html>synthetic</html>".utf8)
        try html.write(to:root.appendingPathComponent("index.html"))
        let manifest=try JSONSerialization.data(withJSONObject:["schemaVersion":1,"edition":"community","interfaceOnly":true,"files":["index.html":digest(html)]])
        try manifest.write(to:root.appendingPathComponent("bundle-manifest.json"))
        let verified=try VerifiedCockpitBundle(root:root,manifestSHA256:digest(manifest))
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root.appendingPathComponent("settings"))
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        owner.appearance = .init(theme:.night,locale:.en,profile:.full,reduceMotion:true)
        let anchor=CGRect(x:screen.visibleFrame.midX,y:screen.visibleFrame.maxY,width:20,height:20)
        owner.anchor = { anchor }
        let context=try CockpitEngineContext(sessionID:UUID(),storeEpoch:"synthetic",generation:1)
        return (owner,verified,context,anchor)
    }
    @MainActor func testNormalFactoryReopenRetainsDetachedPositionAndShutter() throws {
        let (owner,bundle,context,anchor)=try shellFixture()
        let first=owner.makePage(context:context,verified:bundle)
        first.open()
        let window=try XCTUnwrap(first.window)
        first.setAttached(false)
        first.toggleShutter()
        let origin=CGPoint(x:window.frame.minX-20,y:window.frame.minY-20)
        window.setFrameOrigin(origin)
        first.discard()
        let second=owner.makePage(context:context,verified:bundle)
        defer { second.discard() }
        second.open()
        XCTAssertTrue(owner.shell.detached)
        XCTAssertTrue(owner.shell.shutterClosed)
        let reopened=try XCTUnwrap(second.window)
        XCTAssertEqual(reopened.frame.origin.x,origin.x,accuracy:1)
        XCTAssertEqual(reopened.frame.origin.y,origin.y,accuracy:1)
        let fit=try XCTUnwrap(CockpitShellLayout.fit(usable:try XCTUnwrap(NSScreen.main).visibleFrame,anchor:anchor,shutterClosed:true))
        XCTAssertEqual(reopened.frame.height,fit.frame.height,accuracy:1)
    }
    @MainActor func testNormalFactoryTrayPressDoesNotCloseButOutsidePressDoes() throws {
        let (owner,bundle,context,anchor)=try shellFixture()
        let page=owner.makePage(context:context,verified:bundle)
        defer { page.discard() }
        page.open()
        page.outsidePress(CGPoint(x:anchor.midX,y:anchor.midY),eventType:.leftMouseDown)
        XCTAssertFalse(page.bridge.disposed)
        page.outsidePress(CGPoint(x:anchor.maxX+40,y:anchor.midY),eventType:.leftMouseDown)
        XCTAssertTrue(page.bridge.disposed)
    }
    @MainActor func testNormalEntryDockAndMenuToggleRestoresDetachedShell() async throws {
        let (owner,bundle,context,anchor)=try shellFixture()
        let client=RouteClient()
        var pages:[CockpitWindowController]=[]
        let coordinator=EngineCockpitCoordinator { context in
            let page=owner.makePage(context:context,verified:bundle);pages.append(page);return page
        }
        coordinator.bind(client:client);owner.coordinator=coordinator
        let delivery=EngineDeliveryContext(sessionID:"s-"+context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:context.storeEpoch,generation:context.generation),revision:1)
        await coordinator.consume(.context(delivery))
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:owner.settingsStore,createsNativePanels:false,cockpitEntryEnabled:true,
            makeClient:{_,_ in client},makeConsole:{ composition in
                SharedEngineCockpitConsole(owner:owner,composition:composition,activate:{})
            },activateSettings:{})
        app.composition.dock.setPresentationAllowed(true)
        _=app.composition.dock.perform(NSSelectorFromString("openConsole"))
        for _ in 0..<100 { if pages.count == 1 { break }; await Task.yield() }
        let first=try XCTUnwrap(pages.first)
        let window=try XCTUnwrap(first.window)
        first.setAttached(false);first.toggleShutter()
        let origin=CGPoint(x:window.frame.minX-20,y:window.frame.minY-20)
        window.setFrameOrigin(origin)
        _=app.perform(NSSelectorFromString("showConsoleMenu"))
        XCTAssertTrue(first.bridge.disposed)
        _=app.composition.dock.perform(NSSelectorFromString("openConsole"))
        for _ in 0..<100 { if pages.count == 2 { break }; await Task.yield() }
        XCTAssertEqual(pages.count,2)
        let second=try XCTUnwrap(pages.last)
        let reopened=try XCTUnwrap(second.window)
        XCTAssertTrue(owner.shell.detached);XCTAssertTrue(owner.shell.shutterClosed)
        XCTAssertEqual(reopened.frame.origin.x,origin.x,accuracy:1)
        XCTAssertEqual(reopened.frame.origin.y,origin.y,accuracy:1)
        let fit=try XCTUnwrap(CockpitShellLayout.fit(usable:try XCTUnwrap(NSScreen.main).visibleFrame,anchor:anchor,shutterClosed:true))
        XCTAssertEqual(reopened.frame.height,fit.frame.height,accuracy:1)
        second.discard();await coordinator.shutdown();await app.composition.stop()
    }
}
