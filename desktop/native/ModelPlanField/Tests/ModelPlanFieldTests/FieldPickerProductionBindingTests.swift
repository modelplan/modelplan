// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanField

@MainActor private final class PickerHostFixture: FieldPickerProductionHost {
    var input: FieldPickerHostInput
    var focusConnected = true, stillConnected = true
    var field: FieldPublicProjection?, focusedID: String?, saved: Data?, restoredScopeIDs: [String]?
    var expanded: Bool?
    init(_ catalogue: FieldPickerCatalogue) { input = .init(catalogue: catalogue, savedValue: nil) }
    func fieldPickerInput() throws -> FieldPickerHostInput { input }
    func applyEnlargedField(_ projection: FieldPublicProjection, focusedPublicID: String?) throws {
        guard focusConnected else { throw FieldPickerConnectionError.disconnected }
        field = projection; focusedID = focusedPublicID
    }
    func saveFieldPickerValue(_ value: Data) throws { saved = value }
    func setFieldPickerExpanded(_ expanded: Bool) throws { self.expanded = expanded }
    func closeEnlargedFieldAndRestoreCurrentScopeStill() throws {
        guard stillConnected else { throw FieldPickerConnectionError.disconnected }
        field = nil; restoredScopeIDs = input.catalogue.scopeModelIDs
    }
}

@MainActor final class FieldPickerProductionBindingTests: XCTestCase {
    func testProductionBindingRejectsMissingFocusAndStillPortsRatherThanSilentlyPassing() async throws {
        let missing = FieldPickerProductionBinding(view: FieldFleetPickerView(), host: nil, locale: .english)
        XCTAssertThrowsError(try missing.open()); XCTAssertFalse(missing.view.isPresented); missing.dispose()
        let input = try pickerCatalogue(), host = PickerHostFixture(input)
        let view = FieldFleetPickerView(frame: .init(x: 0,y: 0,width: 430,height: 664))
        let binding = FieldPickerProductionBinding(view: view, host: host, locale: .english)
        host.focusConnected = false
        XCTAssertThrowsError(try binding.open()); XCTAssertFalse(view.isPresented)
        host.focusConnected = true; try binding.open()
        host.stillConnected = false
        XCTAssertThrowsError(try binding.close()); XCTAssertFalse(view.isPresented)
        XCTAssertNotNil(binding.lastError); binding.dispose()
    }
    func testBindingForwardsPublicFocusLayoutAndPersistenceThenRestoresLatestScopeNotFieldExtras() async throws {
        let input = try pickerCatalogue(), host = PickerHostFixture(input)
        let view = FieldFleetPickerView(frame: .init(x: 0,y: 0,width: 430,height: 664))
        let binding = FieldPickerProductionBinding(view: view, host: host, locale: .english)
        try binding.open()
        XCTAssertEqual(host.field?.models.map(\.id), ["m0","m1","m2"])
        view.focus("m16")
        XCTAssertEqual(host.focusedID, "m16")
        XCTAssertEqual(host.field?.models.map(\.id), ["m0","m1","m2","m16"])
        XCTAssertNotNil(host.saved)
        view.setExpanded(false); XCTAssertEqual(host.expanded, false)
        view.setExpanded(true); XCTAssertEqual(host.expanded, true)
        host.input = .init(catalogue: try pickerCatalogue(scope: ["m10"]), savedValue: host.saved)
        try binding.close()
        XCTAssertEqual(host.restoredScopeIDs, ["m10"]); XCTAssertNil(host.field)
        binding.dispose(); XCTAssertNil(view.window)
    }
}
