// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

@MainActor func accountRefreshChecks() async throws -> Int {
    let now = try WireInstant("2026-10-20T21:05:00Z").date
    let data = try fixture("calm-4"), publication = try fixture("publication")
    let time = FakeTime(now), cli = FakeCLI(data, publication)
    let store = SnapshotStore(transport: cli, time: time, automaticTimers: false)
    store.setSurfacesVisible(dock: true, cockpit: false)
    store.start(); store.start(); try await settle(store)
    try require((await cli.stats()).0 == [.refreshAccount, .desktop, .publicationOffline, .publication],
        "visible startup refresh precedes the read exactly once")
    for instant in [60.0, 120, 299] {
        time.elapsed = instant; store.tick(); store.refresh(); try await settle(store)
    }
    try require((await cli.stats()).0.filter { $0 == .refreshAccount }.count == 1,
        "ticks and explicit refreshes respect five-minute attempt spacing")
    time.elapsed = 300; store.tick(); store.tick(); try await settle(store)
    let atBoundary = await cli.stats()
    try require(atBoundary.0.filter { $0 == .refreshAccount }.count == 2 && atBoundary.1 == 1,
        "exact five-minute boundary refreshes once without overlap")
    try require(atBoundary.0.suffix(2) == [.refreshAccount, .desktop], "due refresh precedes next desktop read")
    // Attempt spacing uses elapsed time even if the wall clock jumps or the app resumes briefly.
    store.suspend(); time.wall = now.addingTimeInterval(-100); time.elapsed = 301
    store.resume(); try await settle(store)
    try require((await cli.stats()).0.filter { $0 == .refreshAccount }.count == 2, "brief resume cannot retry early")
    time.wall = now
    store.suspend(); time.elapsed = 600; store.resume(); store.resume(); try await settle(store)
    try require((await cli.stats()).0.filter { $0 == .refreshAccount }.count == 3, "due resume refreshes once")
    await store.stopAndWait()
    print("PASS D590 visible start/resume, five-minute boundary, monotonic spacing and one command slot")

    let hiddenTime = FakeTime(now), hiddenCLI = FakeCLI(data, publication)
    let hidden = SnapshotStore(transport: hiddenCLI, time: hiddenTime, automaticTimers: false)
    hidden.start(); try await settle(hidden)
    hiddenTime.elapsed = 1000; hidden.tick(); hidden.refresh(); try await settle(hidden)
    try require(!(await hiddenCLI.stats()).0.contains(.refreshAccount), "hidden UI never refreshes account")
    hidden.setSurfacesVisible(dock: false, cockpit: true); try await settle(hidden)
    try require((await hiddenCLI.stats()).0.suffix(2) == [.refreshAccount, .desktop], "cockpit alone enables refresh before read")
    hidden.setSurfacesVisible(dock: false, cockpit: false)
    hiddenTime.elapsed = 1300; hidden.tick(); try await settle(hidden)
    try require((await hiddenCLI.stats()).0.filter { $0 == .refreshAccount }.count == 1, "hiding suspends account cadence")
    hidden.setSurfacesVisible(dock: true, cockpit: false); try await settle(hidden)
    try require((await hiddenCLI.stats()).0.filter { $0 == .refreshAccount }.count == 2, "Dock alone resumes due account refresh")
    await hidden.stopAndWait()
    print("PASS D590 Dock/cockpit visibility and hidden suspension")

    let sleepTime = FakeTime(now), sleepCLI = FakeCLI(data, publication)
    let sleeping = SnapshotStore(transport: sleepCLI, time: sleepTime, automaticTimers: false)
    let gate = LifecycleCoordinator(store: sleeping)
    gate.set(.systemSleep, blocked: true)
    sleeping.setSurfacesVisible(dock: true, cockpit: false); gate.start()
    sleepTime.elapsed = 1000; sleeping.tick(); sleeping.refresh()
    try require((await sleepCLI.stats()).0.isEmpty, "sleep suppresses visible startup and manual/timer work")
    gate.set(.screenLocked, blocked: true); gate.set(.systemSleep, blocked: false)
    try require((await sleepCLI.stats()).0.isEmpty, "wake cannot bypass the lock")
    gate.set(.screenLocked, blocked: false); try await settle(sleeping)
    try require((await sleepCLI.stats()).0.first == .refreshAccount, "unblocked resume refreshes before desktop")
    gate.set(.systemSleep, blocked: true); sleepTime.elapsed = 2000
    sleeping.setSurfacesVisible(dock: false, cockpit: true); sleeping.tick(); sleeping.refresh()
    let beforeWake = (await sleepCLI.stats()).0
    gate.set(.systemSleep, blocked: false); try await settle(sleeping)
    try require(Array((await sleepCLI.stats()).0.dropFirst(beforeWake.count).prefix(2)) == [.refreshAccount, .desktop],
        "due wake runs refresh then read")
    await gate.stop()
    print("PASS D590 asleep/locked suspension and due wake ordering")

    for failure in [TransportError.timeout, .launchFailed] {
        let failureTime = FakeTime(now), failingCLI = FakeCLI(data, publication)
        let retaining = SnapshotStore(transport: failingCLI, time: failureTime, automaticTimers: false)
        retaining.setSurfacesVisible(dock: true, cockpit: false); retaining.start(); try await settle(retaining)
        await failingCLI.failRefresh(failure)
        var lostReading = false
        retaining.onChange = { if retaining.view()?.presentation.quotas.first?.remaining != 0 { lostReading = true } }
        failureTime.elapsed = 300; retaining.tick(); try await settle(retaining)
        try require(!lostReading && retaining.diagnostics.personal == nil && retaining.diagnostics.publication == nil,
            "failed refresh is silent and retains validated feeds")
        try require((await failingCLI.stats()).0.suffix(2) == [.refreshAccount, .desktop], "failed refresh still runs desktop read")
        retaining.refresh(); try await settle(retaining)
        try require((await failingCLI.stats()).0.filter { $0 == .refreshAccount }.count == 2, "failed attempts are throttled")
        retaining.onChange = nil; await retaining.stopAndWait()
    }
    let exitCLI = FakeCLI(data, publication), exitTime = FakeTime(now)
    await exitCLI.failRefresh(exitCode: 1)
    let exitStore = SnapshotStore(transport: exitCLI, time: exitTime, automaticTimers: false)
    exitStore.setSurfacesVisible(dock: true, cockpit: false); exitStore.start(); try await settle(exitStore)
    try require(exitStore.view()?.presentation.quotas.first?.remaining == 0 && exitStore.diagnostics.publication == nil,
        "nonzero refresh exit must not block reads or mark feeds unavailable")
    await exitStore.stopAndWait()
    print("PASS D590 refresh timeout/launch/nonzero failures leave feeds intact and permit desktop reads")

    let slowTime = FakeTime(now), slowCLI = FakeCLI(data, publication)
    await slowCLI.configure(delay: 80_000_000, ignoreCancellation: true)
    let recovering = SnapshotStore(transport: slowCLI, time: slowTime, automaticTimers: false)
    recovering.setSurfacesVisible(dock: true, cockpit: false); recovering.start()
    for _ in 0..<100 {
        if (await slowCLI.stats()).0.contains(.refreshAccount) { break }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    try require((await slowCLI.stats()).0 == [.refreshAccount], "slow refresh occupies the only slot")
    recovering.suspend(); slowTime.elapsed = 1000
    recovering.resume(); recovering.resume(); try await settle(recovering)
    let recovered = await slowCLI.stats()
    try require(recovered.1 == 1 && recovered.0.prefix(3) == [.refreshAccount, .refreshAccount, .desktop],
        "cancelled refresh is reaped before due wake refresh/read without overlapping children")
    await recovering.stopAndWait()
    print("PASS D590 suspend during account refresh retains the slot until cancellation finishes")
    return 5
}
