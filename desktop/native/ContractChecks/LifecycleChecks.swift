// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

@MainActor func lifecycleChecks() async throws -> Int {
    let now = try WireInstant("2026-10-20T21:05:00Z").date
    let data = try fixture("calm-4"), publicData = try fixture("publication")
    let time = FakeTime(now), fake = FakeCLI(data, publicData)
    let store = SnapshotStore(transport: fake, time: time, automaticTimers: false)
    let gate = LifecycleCoordinator(store: store)
    var frames: [Bool] = [], expiredOnRestoration = false
    gate.onPresentationChange = { allowed in
        frames.append(allowed)
        if allowed && time.wall > now { expiredOnRestoration = store.view()?.presentation.actionable == false }
    }
    gate.set(.screenLocked, blocked: true); gate.start()
    try require(store.idle && !gate.canPresent, "initial blocked state must not launch")
    gate.set(.screenLocked, blocked: false); try await settle(store)
    try require(gate.canPresent && frames == [true], "initial unblocked restore")
    let before = await fake.stats()
    gate.set(.systemSleep, blocked: true); gate.set(.screenLocked, blocked: true)
    gate.set(.sessionInactive, blocked: true); gate.set(.systemSleep, blocked: false)
    try require(!gate.canPresent && store.idle, "wake must not clear lock/session pause")
    gate.set(.screenLocked, blocked: false)
    try require(!gate.canPresent, "unlock must not clear inactive user session")
    time.wall = now.addingTimeInterval(1000); gate.clockChanged()
    // Remember the expiry while suspended, even after the wall clock moves back.
    time.wall = now.addingTimeInterval(-100); gate.clockChanged()
    gate.set(.sessionInactive, blocked: false)
    try require(store.view()?.presentation.actionable == false, "blocked forward/back clock must not resurrect")
    try await settle(store)
    try require((await fake.stats()).0.count == before.0.count + 3, "overlapping reasons coalesce one recovery")
    time.wall = now.addingTimeInterval(1000)
    gate.set(.screenSleep, blocked: true); gate.set(.screenSleep, blocked: false)
    try require(expiredOnRestoration, "restored frame must validate passed UTC deadlines")
    try await settle(store)
    let beforeDisplay = await fake.stats()
    gate.displayRemoved(); gate.displayRemoved(); gate.displayRemoved()
    try require(!gate.canPresent, "display removal hides synchronously")
    await Task.yield(); try await Task.sleep(nanoseconds: 20_000_000); try await settle(store)
    try require((await fake.stats()).0.count == beforeDisplay.0.count + 3, "display burst coalesced")
    gate.set(.noDisplay, blocked: true); gate.displayRemoved()
    await Task.yield(); try await Task.sleep(nanoseconds: 10_000_000)
    try require(!gate.canPresent && store.idle, "display recovery must not clear no-display reason")
    await gate.stop(); gate.set(.noDisplay, blocked: false); gate.start()
    try require(store.idle && !gate.canPresent, "stopped lifecycle must not restart")
    print("PASS B04 overlapping OS reasons, display recovery, suspended clock rollback and restored-frame ordering")
    return 1
}
