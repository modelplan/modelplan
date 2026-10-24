// SPDX-License-Identifier: MIT
import Foundation
import Darwin
import ModelPlanCore

@MainActor func additionalChecks() async throws -> Int {
    var count = 0
    func pass(_ name: String) { count += 1; print("PASS \(name)") }
    let data = try fixture("calm-4"), publicData = try fixture("publication")
    let now = try WireInstant("2026-10-20T21:05:00Z").date

    for (name, working) in [("calm-4-idle",0),("calm-4-working-1",1),("calm-4",2)] {
        let snapshot = try FeedDecoder.personal(fixture(name))
        try require(snapshot.subscriptions?.count == 4 && project(snapshot,now).live.filter(\.working).count == working, "matched F01 working-count variant")
    }
    pass("F01 matched four-subscription zero/one/two-working variants")

    let fewData = try modified(data) { json in
        var sessions = json["liveSessions"] as! [[String:Any]]
        var rate = sessions[0]["rate"] as! [String:Any]; rate["n"] = 4
        sessions[0]["rate"] = rate; json["liveSessions"] = sessions
    }
    let few = project(try FeedDecoder.personal(fewData),now)
    try require(few.live[0].working && few.live[0].rate == nil && few.live[1].rate == 42, "own sample gate must not borrow a peer rate")
    let oldSignalData = try modified(data) { json in
        json["validUntil"] = "2026-10-20T21:20:00Z"
        var sessions = json["liveSessions"] as! [[String:Any]]
        sessions[0]["lastAt"] = "2026-10-20T21:00:00Z"; json["liveSessions"] = sessions
    }
    let oldSignal = project(try FeedDecoder.personal(oldSignalData),now)
    try require(!oldSignal.live[0].working && oldSignal.live[0].rate == nil && oldSignal.actionable, "five-minute signal expires independently")
    let oldRateData = try modified(data) { json in
        json["validUntil"] = "2026-10-20T21:20:00Z"
        var sessions = json["liveSessions"] as! [[String:Any]]
        var rate = sessions[0]["rate"] as! [String:Any]; rate["lastAt"] = "2026-10-20T21:04:00Z"
        sessions[0]["rate"] = rate; json["liveSessions"] = sessions
    }
    let oldRate = project(try FeedDecoder.personal(oldRateData),now)
    try require(oldRate.live[0].working && oldRate.live[0].rate == nil && oldRate.actionable, "60-second own rate expires independently")
    let off = try FeedDecoder.personal(modified(data) { $0["recording"] = false; $0["todayTotals"] = NSNull(); $0["liveSessions"] = [] })
    try require(off.recording == false && off.todayTotals == nil && project(off,now).live.isEmpty, "recording-off fixture must not invent metrics")
    pass("F03 independent own-rate sample/60s gates, five-minute signal and recording-off")

    let basisData = try modified(publicData) { json in
        var models = json["models"] as! [[String:Any]]
        models[0]["harnessEvidence"] = ["qualification":"published-alias-only"]
        var efforts = models[0]["efforts"] as! [[String:Any]]
        efforts[0]["abilityBasis"] = "assumed"
        efforts[0]["timeEstimated"] = true
        efforts[0]["costBasisId"] = "synthetic-reference-task"
        efforts[0]["timeBasis"] = ["boundary":"trial_wall","source":"synthetic"]
        for i in 0..<5 { efforts.append(["effort":"native-\(i)","ability":NSNull(),"cost":NSNull(),"time":NSNull()]) }
        models[0]["efforts"] = efforts; json["models"] = models
        var lineups = json["lineups"] as! [[String:Any]]
        var members = lineups[0]["members"] as! [[String:Any]]
        members[0]["dominatedBy"] = ["id":"another-published-model","kind":"equivalent"]
        lineups[0]["members"] = members; json["lineups"] = lineups
    }
    let publication = try FeedDecoder.publication(basisData)
    let knownData = try modified(data) { json in
        json["sessions"] = [["source":"codex","model":["harnessId":"native-z"],"effort":["key":"medium"],"effortStatus":"reported"]]
    }
    let known = try FeedDecoder.personal(knownData)
    let joined = JoinedSnapshot.make(personal: known, presentation: project(known,now), publication: publication)
    let rows = joined.efforts(harness: "codex", id: "native-z", current: project(known,now).current.first)
    try require(rows.count == 7 && rows[0].isCurrent && rows[0].isRecommended, "current = published star")
    try require(rows[0].abilityBasis == "assumed" && rows[0].timeEstimated == true && rows[0].timeBasis != nil && rows[0].costBasisID == "synthetic-reference-task", "published bases retained")
    try require(publication.models[0].harnessEvidence != nil && publication.lineups[0].members?.first?.dominatedBy != nil, "opaque public evidence retained")
    let otherData = try modified(knownData) { json in
        json["sessions"] = [["source":"codex","model":["harnessId":"native-z"],"effort":["key":"high"],"effortStatus":"reported"]]
    }
    let other = try FeedDecoder.personal(otherData), otherProjection = project(other,now)
    let otherRows = JoinedSnapshot.make(personal: other, presentation: otherProjection, publication: publication).efforts(harness: "codex", id: "native-z", current: otherProjection.current.first)
    try require(otherRows[1].isCurrent && !otherRows[1].isRecommended && otherRows[0].isRecommended, "current differs from star")
    let unknownData = try modified(otherData) { json in
        json["sessions"] = [["source":"codex","model":["harnessId":"native-z"],"effort":["key":"medium"],"effortStatus":"recommended"]]
    }
    let unknown = try FeedDecoder.personal(unknownData), unknownProjection = project(unknown,now)
    let unknownRows = JoinedSnapshot.make(personal: unknown, presentation: unknownProjection, publication: publication).efforts(harness: "codex", id: "native-z", current: unknownProjection.current.first)
    try require(unknownRows.allSatisfy { !$0.isCurrent } && unknownRows.first?.isRecommended == true, "unknown current never borrows star")
    try require(joined.efforts(harness: "codex", id: "unknown-alias", current: nil).isEmpty && rows[2].ability == nil, "missing scored effort withheld")
    pass("F06 published bases, >5 efforts, independent current/star and unknown current")

    let collisions = try FeedDecoder.publication(modified(publicData) { json in
        var models = json["models"] as! [[String:Any]]
        models[1]["harnessIds"] = ["codex":["native-z"]]; json["models"] = models
    })
    let collisionJoin = JoinedSnapshot.make(personal: known, presentation: project(known,now), publication: collisions)
    try require(collisionJoin.model(harness: "codex",id: "native-z") == nil && collisionJoin.ambiguousAliases.count == 1, "ambiguous alias withheld")
    for invalid in [try modified(publicData) { $0["schemaVersion"] = 99 }, try modified(publicData) { $0["publicationId"] = "" }] {
        do { _ = try FeedDecoder.publication(invalid); throw CheckFailure(message: "invalid public identity/schema accepted") } catch is CheckFailure { throw CheckFailure(message: "invalid public identity/schema accepted") } catch {}
    }
    let noUntil = try FeedDecoder.personal(modified(data) { $0.removeValue(forKey: "validUntil") })
    try require(!project(noUntil,now).actionable, "unknown snapshot lifetime withheld")
    let noDeadline = try FeedDecoder.personal(modified(data) { $0["validUntil"] = NSNull() })
    try require(noDeadline.validUntilReported && project(noDeadline,now).actionable, "explicit null means no global clock deadline")
    let deep = Data((#"{"schemaVersion":1,"kind":"modelplan.personal-snapshot","generatedAt":"2026-10-20T21:05:00Z","unknownExtension":"# + String(repeating: "[", count: 70) + "0" + String(repeating: "]", count: 70) + "}").utf8)
    for invalid in [deep, Data(#"{"schemaVersion":1,"kind":"modelplan.personal-snapshot","generatedAt":"2026-10-20T21:05:00Z","unknownExtension":NaN}"#.utf8)] {
        do { _ = try FeedDecoder.personal(invalid); throw CheckFailure(message: "malformed/deep extension accepted") } catch is CheckFailure { throw CheckFailure(message: "malformed/deep extension accepted") } catch {}
    }
    pass("F03/F18 ambiguous aliases, schema/identity and deep/invalid additive values")

    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let spring = calendar.date(from: DateComponents(year:2026,month:3,day:8))!
    let fall = calendar.date(from: DateComponents(year:2026,month:11,day:1))!
    try require(calendar.dateInterval(of: .day, for: spring)!.duration == 23*3600 && calendar.dateInterval(of: .day, for: fall)!.duration == 25*3600, "fixed fixture DST calendar")
    let clock = FakeTime(now), fake = FakeCLI(data,publicData)
    let store = SnapshotStore(transport: fake, time: clock, automaticTimers: false)
    store.start(); try await settle(store)
    let before = await fake.stats()
    store.clockOrTimeZoneChanged(); try await settle(store)
    try require((await fake.stats()).0 == before.0, "timezone formatting event must not launch unnecessary reads")
    store.suspend(); try require(store.view()?.presentation.actionable == false, "suspended state is passive")
    clock.wall = now.addingTimeInterval(1000); clock.elapsed = 1000
    await fake.configure(offline: true); store.resume(); try await settle(store)
    try require(store.view()?.presentation.actionable == false && store.view()?.presentation.live.allSatisfy { !$0.working } == true, "offline wake after reset")
    clock.wall = now.addingTimeInterval(-100); store.clockOrTimeZoneChanged()
    try require(store.view()?.presentation.actionable == false, "awake rollback after expired state")
    await store.stopAndWait()
    pass("F19/F20 23/25h local days, timezone event, suspension and offline wake")

    let failing = FakeCLI(data,publicData), t2 = FakeTime(now)
    let retaining = SnapshotStore(transport: failing, time: t2, automaticTimers: false)
    retaining.start(); try await settle(retaining)
    await failing.setPersonal(Data("{}".utf8)); retaining.refresh(); try await settle(retaining)
    try require(retaining.view()?.presentation.quotas.first?.historicalRemaining == 0 && retaining.view()?.presentation.quotas.first?.remaining == nil, "last personal truth retained but not actionable")
    await failing.setPersonal(data); retaining.refresh(); try await settle(retaining)
    try require(retaining.view()?.presentation.quotas.first?.remaining == 0, "valid personal recovery")
    await retaining.stopAndWait()
    pass("B04 failed personal read preserves historical truth and recovers")
    return count
}
