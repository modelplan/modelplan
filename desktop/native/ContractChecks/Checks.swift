// SPDX-License-Identifier: MIT
import Foundation
import Darwin
import ModelPlanCore

struct CheckFailure: Error { let message: String }
func require(_ condition: Bool, _ message: String) throws { if !condition { throw CheckFailure(message: message) } }
func fixture(_ name: String) throws -> Data {
    let indexURL = Bundle.module.url(forResource: "index", withExtension: "json", subdirectory: "Fixtures")!
    let index = try JSONDecoder().decode([String:String].self, from: Data(contentsOf:indexURL))
    return try Data(contentsOf:indexURL.deletingLastPathComponent().appendingPathComponent(index[name]! + ".json"))
}
func modified(_ original: Data, _ change: (inout [String:Any]) -> Void) throws -> Data {
    var json = try JSONSerialization.jsonObject(with: original) as! [String:Any]; change(&json)
    return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
}
func project(_ s: PersonalSnapshot, _ now: Date) -> PersonalProjection { var l = ExpiryLedger(); return .evaluate(s, now: now, ledger: &l) }

@MainActor final class FakeTime: RefreshTimeSource { var wall: Date; var elapsed = 0.0; init(_ wall: Date) { self.wall = wall } }
actor FakeCLI: CLITransport {
    var calls: [CLICommand] = [], active = 0, peak = 0
    var personal: Data, publication: Data
    var delay: UInt64 = 1_000_000
    var offline = false, warning = false, ignoreCancellation = false
    init(_ personal: Data, _ publication: Data) { self.personal = personal; self.publication = publication }
    func configure(offline: Bool = false, warning: Bool = false, delay: UInt64 = 1_000_000, ignoreCancellation: Bool = false) {
        self.offline = offline; self.warning = warning; self.delay = delay; self.ignoreCancellation = ignoreCancellation
    }
    func execute(_ command: CLICommand) async throws -> CommandResult {
        calls.append(command); active += 1; peak = max(peak, active); defer { active -= 1 }
        if ignoreCancellation { try? await Task.sleep(nanoseconds: delay) } else { try await Task.sleep(nanoseconds: delay) }
        if offline && command != .desktop { return CommandResult(exitCode: 3, stdout: Data()) }
        return CommandResult(exitCode: 0, stdout: command == .desktop ? personal : publication, warning: warning)
    }
    func setPersonal(_ data: Data) { personal = data }
    func setPublication(_ data: Data) { publication = data }
    func stats() -> ([CLICommand], Int) { (calls, peak) }
}
@MainActor func settle(_ store: SnapshotStore) async throws {
    for _ in 0..<300 { if store.idle { return }; try await Task.sleep(nanoseconds: 5_000_000) }
    throw CheckFailure(message: "scheduler did not settle")
}

@main struct ContractChecks {
    @MainActor static func main() async throws {
        var count = 0
        func passed(_ name: String) { count += 1; print("PASS \(name)") }
        let data = try fixture("calm-4"), pubData = try fixture("publication")
        let personal = try FeedDecoder.personal(data), pub = try FeedDecoder.publication(pubData)
        let now = try WireInstant("2026-10-20T21:05:00Z").date
        _ = try FeedDecoder.personal(fixture("upstream-personal"))
        try require(personal.accounts?.count == 4, "F01 four subscriptions")
        let p = project(personal, now)
        try require(p.quotas.first?.remaining == 0 && p.quotas[1].remaining == nil, "F03 zero versus null")
        try require(p.live.filter(\.working).count == 2 && p.live.allSatisfy { $0.rate == 42 }, "F01 own live rates")
        let six = try FeedDecoder.personal(fixture("working-6"))
        try require(Set(project(six, now).live.compactMap(\.subscription)).count == 6, "F01 six distinct subscriptions")
        passed("F01/F03 personal golden, four/six IDs, zero/null, own rates")

        let unknown = project(try FeedDecoder.personal(fixture("unknown-stale")), now)
        try require(unknown.quotas.first?.remaining == nil && unknown.current.first?.effort == nil && unknown.live.first?.rate == nil, "unknown not fabricated")
        let duplicate = try FeedDecoder.personal(fixture("duplicate-bindings"))
        try require(project(duplicate, now).live.allSatisfy { !$0.working && $0.rate == nil }, "ambiguous source lights neither")
        try require(MetricMath.todayRate(duplicate, subscription: "sub-0") == nil, "source totals not duplicated")
        passed("F03/F05 unknown effort, sample gate and ambiguous source")

        func sums(_ requests: Int, _ tokens: Int, _ ms: Int) throws -> MetricSums {
            try JSONDecoder().decode(MetricSums.self, from: JSONSerialization.data(withJSONObject: ["eligibleRequests":requests,"eligibleOutputTokens":tokens,"genMs":ms]))
        }
        let rate = MetricMath.generationRate(try [sums(3,200,10000), sums(2,800,100000)])
        try require(abs((rate ?? 0) - 1000.0/110) < 0.000001, "ratio of sums")
        try require(MetricMath.generationRate(try [sums(4,200,10000)]) == nil, "five sample gate")
        try require(MetricMath.cacheHit(input: 100, cacheRead: 900) == 0.9 && MetricMath.cacheHit(input: nil, cacheRead: 0) == nil, "cache basis")
        passed("F09 weighted generation speed and cache denominator")

        let dst = try FeedDecoder.personal(fixture("dst")), hours = dst.hourly!
        try require(hours[0].hour.raw != hours[1].hour.raw && hours[1].hour.date.timeIntervalSince(hours[0].hour.date) == 3600, "DST repeated hours")
        try require(hours[0].observedOutputTokens == 0 && hours[1].observedOutputTokens == nil && hours.count == 2, "no missing-hour zero fill")
        try require(try WireInstant("2026-10-20T21:05:00+05:45").raw.hasSuffix("+05:45"), "quarter hour offset")
        passed("F19 DST offsets, local day preservation, zero/missing hour")

        var ledger = ExpiryLedger()
        _ = PersonalProjection.evaluate(personal, now: now, ledger: &ledger)
        let reset = PersonalProjection.evaluate(personal, now: now.addingTimeInterval(31), ledger: &ledger)
        try require(reset.quotas.first?.remaining == nil && reset.quotas.first?.historicalRemaining == 0, "passed reset")
        let expired = PersonalProjection.evaluate(personal, now: now.addingTimeInterval(61), ledger: &ledger)
        try require(!expired.actionable && expired.live.allSatisfy { !$0.working }, "unchanged revision expires")
        try require(!PersonalProjection.evaluate(personal, now: now.addingTimeInterval(-100), ledger: &ledger).actionable, "wall rollback resurrected")
        passed("F03/F19 unchanged revision, reset deadline, sticky wall rollback")

        let joined = JoinedSnapshot.make(personal: personal, presentation: p, publication: pub)
        try require(joined.model(harness: "codex", id: "native-z") == "z-model", "exact alias")
        try require(joined.model(harness: "codex", id: "Synthetic Z") == nil, "no display-name fallback")
        try require(pub.models[0].efforts?[1].ability == nil && pub.normalizedSpeedTiers.last?.models?.first?.modelId == nil, "nullable published scores/model IDs")
        try require(pub.normalizedSpeedTiers.first?.models?.first?.speed?.qualifier == "up-to", "qualifier retained")
        let mismatch = try FeedDecoder.publication(modified(pubData) { $0["publicationId"] = "other" })
        try require(JoinedSnapshot.make(personal: personal, presentation: p, publication: mismatch).publication == nil && p.quotas.first?.remaining == 0, "ID mismatch independent quota")
        let units = try FeedDecoder.publication(modified(pubData) { $0["units"] = ["ability":"wrong","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"] })
        try require(JoinedSnapshot.make(personal: personal, presentation: p, publication: units).scoredUnavailableReason == "unsupported-units", "unit mismatch")
        let noTime = try FeedDecoder.publication(modified(pubData) { $0["publishedAt"] = NSNull(); $0["speedTiers"] = NSNull() })
        try require(noTime.publishedAt == nil && noTime.normalizedSpeedTiers.isEmpty, "no invented publication time")
        passed("F06/F18 flattened publication, exact join, nullable verdicts and qualifiers")

        for bad in [Data("{}".utf8), Data("{\"value\":NaN}".utf8), Data(repeating: 32, count: FeedDecoder.maximumBytes + 1), try modified(data) { $0["schemaVersion"] = 99 }, try modified(data) { $0["generatedAt"] = "bad" }] {
            do { _ = try FeedDecoder.personal(bad); throw CheckFailure(message: "bad payload accepted") } catch is CheckFailure { throw CheckFailure(message: "bad payload accepted") } catch {}
        }
        passed("F03 malformed/schema/NaN/timestamp/8 MiB rejection")

        let time = FakeTime(now), fake = FakeCLI(data, pubData)
        let store = SnapshotStore(transport: fake, time: time, automaticTimers: false)
        store.start(); try await settle(store)
        let firstCalls = await fake.stats()
        try require(firstCalls.0 == [.desktop,.publicationOffline,.publication] && firstCalls.1 == 1, "start order/single child")
        time.elapsed = 30; time.wall = now.addingTimeInterval(31); store.tick(); try await settle(store)
        try require(store.view()?.presentation.quotas.first?.remaining == nil, "deadline invalidates without revision change")
        time.elapsed = 631; time.wall = now.addingTimeInterval(631); store.tick(); try await settle(store)
        try require((await fake.stats()).0.filter { $0 == .publication }.count == 2, "public cadence")
        try require(store.view()?.publication == nil, "expired personal withheld public joins")
        await store.stopAndWait()
        passed("B04 startup offline/online, one slot, 60s/10min cadence and expiry")

        let slow = FakeCLI(data, pubData), t2 = FakeTime(now)
        await slow.configure(delay: 80_000_000, ignoreCancellation: true)
        let recovering = SnapshotStore(transport: slow, time: t2, automaticTimers: false)
        recovering.start(); try await Task.sleep(nanoseconds: 10_000_000)
        recovering.suspend(); t2.wall = now.addingTimeInterval(1000); t2.elapsed = 1000
        recovering.resume(); recovering.resume(); recovering.resume()
        try await settle(recovering)
        let recovered = await slow.stats()
        try require(recovered.1 == 1 && recovered.0.filter { $0 == .desktop }.count <= 2, "coalesced wake/no overlap")
        try require(recovering.view()?.presentation.actionable == false, "no stale callback revived state")
        await recovering.stopAndWait()
        passed("F19/F20 cancellation generation and coalesced offline-time wake")

        let offline = FakeCLI(data,pubData)
        await offline.configure(offline: true)
        let offlineStore = SnapshotStore(transport: offline, time: FakeTime(now), automaticTimers: false)
        offlineStore.start(); try await settle(offlineStore)
        try require(offlineStore.view()?.publication == nil && offlineStore.view()?.presentation.quotas.first?.remaining == 0, "offline3 quota independent")
        await offline.configure(warning: true); offlineStore.refresh(); try await settle(offlineStore)
        try require(offlineStore.view()?.publication != nil && offlineStore.diagnostics.publicationWarning && offlineStore.view()?.publication?.publishedAt?.raw == "2026-10-20T20:00:00Z", "last-good timestamp retained")
        await offlineStore.stopAndWait()
        passed("F18 offline exit3/empty stdout and last-good warning")

        try await processChecks()
        passed("real fake-process args, cap, deadline, cancellation/reaping, missing executable")
        let prefURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("prefs.json")
        let preferences = PreferenceFile(url: prefURL); var value = CommunityPreferences(); value.favouriteModelIDs = ["synthetic"]
        try preferences.save(value); try require(try preferences.load() == value, "preference atomic roundtrip")
        try FileManager.default.removeItem(at: prefURL.deletingLastPathComponent())
        try require(!NativeWindowRole.dock.canBecomeKeyOnExplicitEntry && NativeWindowRole.settings.canBecomeMain && !NativeWindowRole.cockpit.canBecomeMain, "window role policy")
        passed("app-owned preferences and native window role policy")
        count += try await additionalChecks()
        print("\(count) contract groups passed; synthetic, no visual/minimum-runtime/performance claim")
    }
}

func processChecks() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("modelplan-process-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let exe = dir.appendingPathComponent("fake-cli")
    let script = """
    #!/usr/bin/python3
    import json,os,sys,time,signal
    mode=os.environ.get('MODE','args')
    if os.environ.get('PIDFILE'):
        with open(os.environ['PIDFILE'],'w') as f: f.write(str(os.getpid()))
    if mode=='cap':
        sys.stdout.buffer.write(b' '*(8*1024*1024+1)); sys.stdout.flush()
    elif mode=='slow':
        signal.signal(signal.SIGTERM,signal.SIG_IGN)
        time.sleep(5)
    else:
        print(json.dumps(sys.argv[1:]))
        sys.stderr.write('x'*70000)
    """
    try Data(script.utf8).write(to: exe); try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: exe.path)
    let argsTransport = ProcessCLITransport(executable: exe, environment: ["MODE":"args"])
    let args = try await argsTransport.execute(.desktop)
    let argv = try JSONDecoder().decode([String].self, from: args.stdout)
    try require(argv == ["desktop","--json","--read-only"] && args.warning && args.stderrTruncated, "fixed readonly args/stderr cap")
    do { _ = try await ProcessCLITransport(executable: exe, environment: ["MODE":"cap"]).execute(.desktop); throw CheckFailure(message: "cap accepted") } catch TransportError.outputLimit {}
    let slow = ProcessCLITransport(executable: exe, environment: ["MODE":"slow"], timeoutOverride: 0.15)
    let start = ContinuousClock.now
    do { _ = try await slow.execute(.desktop); throw CheckFailure(message: "timeout accepted") } catch TransportError.timeout {}
    try require(start.duration(to: .now) < .seconds(2), "bounded kill/reap")
    let pidFile = dir.appendingPathComponent("owned-child.pid")
    let cancelling = ProcessCLITransport(executable: exe, environment: ["MODE":"slow","PIDFILE":pidFile.path])
    let task = Task { try await cancelling.execute(.desktop) }
    let launchedAt = ContinuousClock.now
    while !FileManager.default.fileExists(atPath:pidFile.path) && launchedAt.duration(to:.now) < .seconds(2) {
        try await Task.sleep(nanoseconds:5_000_000)
    }
    do { _ = try await cancelling.execute(.desktop); throw CheckFailure(message:"overlapping command accepted") } catch TransportError.busy {}
    task.cancel()
    do { _ = try await task.value; throw CheckFailure(message: "cancel accepted") } catch TransportError.cancelled {}
    if FileManager.default.fileExists(atPath:pidFile.path), let pid = Int32(try String(contentsOf:pidFile)) {
        try require(kill(pid,0) == -1 && errno == ESRCH, "cancel returned before owned child was reaped")
    } else { throw CheckFailure(message:"synthetic child did not report its PID") }
    let retry = Task { try await cancelling.execute(.desktop) }; try await Task.sleep(nanoseconds: 30_000_000); retry.cancel()
    do { _ = try await retry.value; throw CheckFailure(message: "cancel accepted") } catch TransportError.cancelled {}
    do { _ = try await ProcessCLITransport(executable: dir.appendingPathComponent("absent")).execute(.publication); throw CheckFailure(message: "missing executable accepted") } catch TransportError.launchFailed {}
}
