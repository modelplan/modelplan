// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// F3 (SET-9-18): the forecast kind delivers through the shared policy, once per window cycle.
@MainActor final class EngineForecastNotifierTests: XCTestCase {
    private let now=Date(timeIntervalSince1970:1_800_000_000)
    private func stamp(_ seconds:TimeInterval) -> String { ISO8601DateFormatter().string(from:now.addingTimeInterval(seconds)) }
    private func rows(runsOut:TimeInterval?=1200,reset:TimeInterval=18000,valueState:String="current") throws -> WireRowsSnapshot {
        var repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath:repo.appendingPathComponent("schema/app-cli/captures").path) { repo.deleteLastPathComponent() }
        var data=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:repo.appendingPathComponent("schema/app-cli/captures/WireRowsSnapshot.json"))) as? [String:Any])
        var projection=try XCTUnwrap(data["projection"] as? [String:Any])
        var list=try XCTUnwrap(projection["rows"] as? [[String:Any]])
        var accounts=try XCTUnwrap(list[0]["accounts"] as? [[String:Any]])
        var windows=try XCTUnwrap(accounts[0]["windows"] as? [[String:Any]])
        windows[0]["current"]=true;windows[0]["resetsAt"]=stamp(reset);windows[0]["validUntil"]=stamp(reset)
        accounts[0]["windows"]=windows;accounts[0]["valueState"]=valueState
        list[0]["accounts"]=accounts;projection["rows"]=list
        var forecast:[String:Any]=["source":try XCTUnwrap(list[0]["id"] as? String),"subscriptionRef":try XCTUnwrap(accounts[0]["subscriptionRef"] as? String),
                                   "windowId":try XCTUnwrap(windows[0]["id"] as? String),"pace":"tight","basis":"recent-rate","observedAt":stamp(-60)]
        forecast["runsOutAt"]=runsOut.map(stamp) ?? NSNull()
        projection["forecasts"]=[forecast];data["projection"]=projection
        return try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
    }
    func testOnlyAFutureRunOutBeforeTheResetOfACurrentReadingIsAnEpisode() throws {
        XCTAssertEqual(EngineForecastDecoder.episodes(try rows(),now:now).count,1)
        XCTAssertTrue(EngineForecastDecoder.episodes(try rows(runsOut:nil),now:now).isEmpty)
        XCTAssertTrue(EngineForecastDecoder.episodes(try rows(runsOut:-60),now:now).isEmpty)
        XCTAssertTrue(EngineForecastDecoder.episodes(try rows(runsOut:18060),now:now).isEmpty)
        XCTAssertTrue(EngineForecastDecoder.episodes(try rows(valueState:"retained"),now:now).isEmpty)
        XCTAssertTrue(EngineForecastDecoder.episodes(nil,now:now).isEmpty)
    }
    func testOneNotificationPerWindowCycleAndOnlyWhenTheKindIsOn() async throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("forecast-notices-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        try await store.update { $0.notifications.optedIn=true;$0.notifications.kinds.remove(.forecast) }
        let clock=now
        let notifier=EngineForecastNotifier(settings:store,cacheURL:directory.appendingPathComponent("forecast.json"),deliverToSystem:false,now:{ clock })
        var delivered:[String]=[]
        notifier.deliveryOverride={ delivered.append($0) }
        func settle() async throws { for _ in 0..<50 { await Task.yield();try await Task.sleep(for:.milliseconds(2)) } }
        notifier.apply(rows:try rows());try await settle()
        XCTAssertEqual(delivered.count,0,"The kind is off")
        try await store.update { $0.notifications.kinds.insert(.forecast) }
        notifier.apply(rows:try rows());try await settle()
        XCTAssertEqual(delivered.count,1)
        notifier.apply(rows:try rows(runsOut:2400));try await settle()
        XCTAssertEqual(delivered.count,1,"A moved run-out in one cycle is the same episode")
        notifier.apply(rows:try rows(runsOut:90000,reset:100000));try await settle()
        XCTAssertEqual(delivered.count,2,"A new cycle is a new episode")
        let reopened=EngineForecastNotifier(settings:store,cacheURL:directory.appendingPathComponent("forecast.json"),deliverToSystem:false,now:{ clock })
        reopened.deliveryOverride={ delivered.append($0) }
        reopened.apply(rows:try rows());try await settle()
        XCTAssertEqual(delivered.count,2,"The ledger survives a restart")
    }
}
