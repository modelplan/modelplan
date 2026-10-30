// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanShell

@MainActor private final class PresenceWindow: PulsePresenceWindow {
    var isVisible = false, isMiniaturized = false, closes = 0
    func close() { closes += 1; isVisible = false; isMiniaturized = false }
}
@MainActor private final class LoginService: PulseLoginService {
    var value: PulseLoginState = .off, reads = 0, registers = 0, unregisters = 0, fail = false
    var afterRegister: PulseLoginState = .needsApproval
    var state: PulseLoginState { reads += 1; return value }
    func register() throws { registers += 1; if fail { throw Failure.rejected }; value = afterRegister }
    func unregister() throws { unregisters += 1; if fail { throw Failure.rejected }; value = .off }
    enum Failure: Error { case rejected }
}
@MainActor final class PulseAppServicesTests: XCTestCase {
    func testPresenceTracksAllVisibleAndMinimizedWindowsAndExcludesClosingOne() {
        var policy: NSApplication.ActivationPolicy = .accessory, changes = 0, activations = 0
        let presence = PulseDockPresence(currentPolicy: { policy }, setPolicy: { policy = $0; changes += 1 }, activate: { activations += 1 })
        let settings = PresenceWindow(), cockpit = PresenceWindow()
        settings.isVisible = true; cockpit.isMiniaturized = true
        presence.track(settings); presence.track(settings); presence.track(cockpit)
        XCTAssertEqual(changes, 0, "tracking must not change activation policy")
        presence.apply(activateIfRegular: true); presence.apply()
        XCTAssertEqual(policy, .regular); XCTAssertEqual(changes, 1); XCTAssertEqual(activations, 1)
        presence.apply(closing: settings)
        XCTAssertEqual(policy, .regular, "the other minimized window still needs Dock/Command-Tab presence")
        settings.isVisible = false; presence.apply(closing: cockpit)
        XCTAssertEqual(policy, .accessory); XCTAssertEqual(changes, 2); XCTAssertEqual(activations, 1)
    }
    func testPresenceKeepsOnlyWeakWindowsAndCloseDoesNotQuitApplication() {
        var policy: NSApplication.ActivationPolicy = .accessory, activations = 0
        let presence = PulseDockPresence(currentPolicy: { policy }, setPolicy: { policy = $0 }, activate: { activations += 1 })
        var temporary: PresenceWindow? = PresenceWindow(); temporary?.isVisible = true
        weak var weakWindow = temporary
        presence.track(temporary!); presence.apply(); temporary = nil
        XCTAssertNil(weakWindow); presence.apply(); XCTAssertEqual(policy, .accessory)
        let visible = PresenceWindow(), minimized = PresenceWindow(), hidden = PresenceWindow()
        visible.isVisible = true; minimized.isMiniaturized = true
        presence.track(visible); presence.track(minimized); presence.track(hidden)
        presence.setShowsIcon(false); XCTAssertEqual(policy, .accessory)
        presence.setShowsIcon(true); XCTAssertEqual(policy, .regular)
        presence.closeWindows()
        XCTAssertEqual(visible.closes, 1); XCTAssertEqual(minimized.closes, 1); XCTAssertEqual(hidden.closes, 0)
        XCTAssertEqual(policy, .accessory); XCTAssertEqual(activations, 0)
    }
    func testRestoredPresenceDoesNotActivateUnlessExplicitUserPresentationRequestsIt() {
        var policy: NSApplication.ActivationPolicy = .accessory, activations = 0
        let presence = PulseDockPresence(currentPolicy: { policy }, setPolicy: { policy = $0 }, activate: { activations += 1 })
        let window = PresenceWindow(); window.isVisible = true; presence.track(window)
        presence.apply()
        XCTAssertEqual(policy, .regular); XCTAssertEqual(activations, 0)
        presence.setShowsIcon(false); presence.setShowsIcon(true)
        XCTAssertEqual(activations, 0)
        presence.setShowsIcon(false); presence.setShowsIcon(true, activateIfRegular: true)
        XCTAssertEqual(policy, .regular); XCTAssertEqual(activations, 1)
    }
    func testLoginConstructionRestorationAndObservationNeverRegister() {
        let service = LoginService(), item = PulseLoginItem(isAppBundle: true, service: service)
        XCTAssertEqual(service.reads, 0); XCTAssertEqual(service.registers, 0)
        XCTAssertEqual(item.state, .off)
        XCTAssertEqual(item.request(enabled: true, origin: .restoration), .unchanged(.off))
        XCTAssertEqual(item.request(enabled: true, origin: .systemObservation), .unchanged(.off))
        XCTAssertEqual(service.registers, 0); XCTAssertEqual(service.unregisters, 0)
    }
    func testLoginRequiresApprovalRemainsObservedAndDisableUsesModernServiceOnly() {
        let service = LoginService(), item = PulseLoginItem(isAppBundle: true, service: service)
        XCTAssertEqual(item.request(enabled: true, origin: .explicitUserChoice), .performed(.needsApproval))
        XCTAssertEqual(item.request(enabled: true, origin: .firstRunCompletion), .unchanged(.needsApproval))
        XCTAssertEqual(service.registers, 1, "approval-required must not be repaired/re-registered")
        XCTAssertEqual(item.request(enabled: false, origin: .explicitUserChoice), .performed(.off))
        XCTAssertEqual(service.unregisters, 1)
    }
    func testLoginBareExecutableAndUnavailableNeverTouchRegistration() {
        let service = LoginService(), bare = PulseLoginItem(isAppBundle: false, service: service)
        XCTAssertEqual(bare.state, .unavailable)
        XCTAssertEqual(bare.request(enabled: true, origin: .explicitUserChoice), .unsupported)
        XCTAssertEqual(service.reads, 0); XCTAssertEqual(service.registers, 0)
        service.value = .unavailable
        let app = PulseLoginItem(isAppBundle: true, service: service)
        XCTAssertEqual(app.request(enabled: false, origin: .explicitUserChoice), .unsupported)
        XCTAssertEqual(service.unregisters, 0)
    }
    func testLoginFailureReportsObservedStateAndOnStateIsNotRegisteredAgain() {
        let service = LoginService(), item = PulseLoginItem(isAppBundle: true, service: service)
        service.fail = true
        XCTAssertEqual(item.request(enabled: true, origin: .explicitUserChoice), .failed(.off))
        service.fail = false; service.value = .on
        XCTAssertEqual(item.request(enabled: true, origin: .explicitUserChoice), .unchanged(.on))
        XCTAssertEqual(service.registers, 1)
        XCTAssertEqual(item.request(enabled: false, origin: .firstRunCompletion), .performed(.off))
    }
}
