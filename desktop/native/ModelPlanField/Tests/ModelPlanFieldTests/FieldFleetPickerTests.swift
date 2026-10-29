// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
@testable import ModelPlanField

func pickerCatalogue(scope: [String] = ["m0","m1","m2"]) throws -> FieldPickerCatalogue {
    let object: [String: Any] = ["schemaVersion":1,"publicationId":"picker-public",
        "units":["ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"],
        "models": (0..<17).map { i -> [String:Any] in
            ["id":"m\(i)","name":"Example \(i)","developerId":i % 2 == 0 ? "maker-a":"maker-b",
             "recommended":"high","efforts":[["effort":"high","label":"High","ability":i+1,"cost":i+1]],
             "basis":["privateSentinel":"do-not-cross"]]
        },"lineups":[],"privateSentinel":"do-not-cross"]
    let pub = try JSONDecoder().decode(PublicPublication.self, from: JSONSerialization.data(withJSONObject: object))
    return try .init(projection:.init(publication:pub),scopeModelIDs:scope,siteModelIDs:(0..<7).map{"m\($0)"},
        rosterModelIDs:["m3"]+(0..<17).map{"m\($0)"},verdictRevision:"picker-public",verdicts:[.init(publicModelID:"m3",tags:[.strongest,.bestValue]),
            .init(publicModelID:"m4",tags:[.outclassed]),.init(publicModelID:"unknown",tags:[.cheapest])],
        developerNames:["maker-a":"Maker A","maker-b":"Maker B"])
}

final class FieldFleetPickerTests: XCTestCase {
    func testScopeRemovalDistinctPresetsCapacityAndResetStayFieldLocal() throws {
        let input = try pickerCatalogue(); var state = FieldFleetPicker(catalogue:input)
        XCTAssertEqual(state.selectedIDs(in:input),["m0","m1","m2"])
        XCTAssertTrue(state.setLaunched(false,publicID:"m0",in:input))
        XCTAssertEqual(state.selectedIDs(in:input),["m1","m2"])
        XCTAssertEqual(input.scopeModelIDs,["m0","m1","m2"])
        var counts:[Int]=[]
        for preset in [FieldPickerPreset.mine,.site,.all] {state.selectPreset(preset,in:input);counts.append(state.selectedIDs(in:input).count)}
        XCTAssertEqual(counts,[3,7,10])
        XCTAssertFalse(state.setLaunched(true,publicID:"m16",in:input))
        XCTAssertTrue(state.setLaunched(false,publicID:"m0",in:input));XCTAssertTrue(state.setLaunched(true,publicID:"m16",in:input))
        XCTAssertEqual(state.selectedIDs(in:input).count,10)
        state.reset(in:input);XCTAssertEqual(state.selectedIDs(in:input),input.scopeModelIDs)
    }
    func testSavedValueKeepsOnlyPublicIDsAndExplicitEmptySurvives() throws {
        let input = try pickerCatalogue()
        let mixed = try JSONSerialization.data(withJSONObject:["ids":["m1",["account":"private"],"unknown","m1",1],"preset":"bad","session":"private"])
        let state = FieldFleetPicker(catalogue:input,savedValue:mixed)
        XCTAssertEqual(state.selectedIDs(in:input),["m1"]);XCTAssertEqual(state.preset,.custom)
        let saved = try state.savedValue(in:input), object = try XCTUnwrap(JSONSerialization.jsonObject(with:saved) as? [String:Any])
        XCTAssertEqual(Set(object.keys),Set(["ids","preset"]))
        XCTAssertFalse(String(decoding:saved,as:UTF8.self).contains("private"))
        let empty = try JSONSerialization.data(withJSONObject:["ids":[],"preset":"mine"])
        XCTAssertEqual(FieldFleetPicker(catalogue:input,savedValue:empty).selectedIDs(in:input),[])
        XCTAssertEqual(FieldFleetPicker(catalogue:input,savedValue:Data("broken".utf8)).selectedIDs(in:input),input.scopeModelIDs)
    }
    func testRestoreAndReconcileDoNotOverwriteCurrentNormalScope() throws {
        let old = try pickerCatalogue();var state = FieldFleetPicker(catalogue:old)
        state.selectPreset(.site,in:old);let saved = try state.savedValue(in:old)
        let current = try pickerCatalogue(scope:["m10"])
        var restored = FieldFleetPicker(catalogue:current,savedValue:saved)
        restored.reconcile(with:current)
        XCTAssertEqual(restored.selectedIDs(in:current),(0..<7).map{"m\($0)"})
        XCTAssertEqual(current.scopeModelIDs,["m10"])
        restored.reset(in:current);XCTAssertEqual(restored.selectedIDs(in:current),["m10"])
    }
    func testTagsAndOrderAreSuppliedNotComputedFromHigherMetricsAndFiltersDoNotChoose() throws {
        let input=try pickerCatalogue();var state=FieldFleetPicker(catalogue:input)
        let english=FieldPickerPresentation(catalogue:input,state:state,locale:.english)
        XCTAssertEqual(english.rows.first?.publicID,"m3")
        XCTAssertEqual(english.rows.first?.tags.map(\.label),["Strongest","Best value"])
        XCTAssertEqual(english.rows.first{$0.publicID=="m4"}?.tags.map(\.label),["Outclassed"])
        XCTAssertTrue(english.rows.first{$0.publicID=="m16"}!.tags.isEmpty)
        let chinese=FieldPickerPresentation(catalogue:input,state:state,locale:.chinese)
        XCTAssertEqual(chinese.rows.first{$0.publicID=="m4"}?.tags.map(\.label),["被比下去"])
        state.filter(maker:"maker-a",query:"Example 1")
        let filtered=FieldPickerPresentation(catalogue:input,state:state,locale:.english)
        XCTAssertEqual(filtered.rows.map(\.publicID),["m10","m12","m14","m16"])
        XCTAssertEqual(state.selectedIDs(in:input),input.scopeModelIDs)
    }
    func testPublicProjectionSubsetIsBoundedAndCannotInjectUnknownOrPrivateFields() throws {
        let input=try pickerCatalogue()
        XCTAssertThrowsError(try input.projection.selecting(publicIDs:["unknown"]))
        XCTAssertThrowsError(try input.projection.selecting(publicIDs:["m0","m0"]))
        XCTAssertThrowsError(try input.projection.selecting(publicIDs:(0..<11).map{"m\($0)"}))
        let projection=try input.projection.selecting(publicIDs:["m2","m0"])
        XCTAssertEqual(projection.models.map(\.id),["m2","m0"])
        XCTAssertFalse(String(decoding:try JSONEncoder().encode(projection),as:UTF8.self).contains("privateSentinel"))
    }
    func testTagsRequireTheirMatchingPublishedRevisionAndAmbiguousFactsAreWithheld() throws {
        let projection=try pickerCatalogue().projection,tag=FieldPickerVerdict(publicModelID:"m0",tags:[.strongest])
        XCTAssertThrowsError(try FieldPickerCatalogue(projection:projection,scopeModelIDs:[],siteModelIDs:[],verdicts:[tag]))
        XCTAssertThrowsError(try FieldPickerCatalogue(projection:projection,scopeModelIDs:[],siteModelIDs:[],verdictRevision:"other",verdicts:[tag]))
        let ambiguous=try FieldPickerCatalogue(projection:projection,scopeModelIDs:[],siteModelIDs:[],
            verdictRevision:projection.revision,verdicts:[tag,tag])
        XCTAssertNil(ambiguous.tags["m0"])
    }
    func testRowFocusLaunchesOnlyWhenThereIsCapacityAndDoesNotChangeScope() throws {
        let input=try pickerCatalogue();var state=FieldFleetPicker(catalogue:input)
        XCTAssertTrue(state.focus("m16",in:input))
        XCTAssertEqual(state.selectedIDs(in:input),["m0","m1","m2","m16"])
        XCTAssertEqual(state.effectiveFocus(in:input),"m16")
        state.selectPreset(.all,in:input)
        XCTAssertFalse(state.focus("m16",in:input))
        XCTAssertEqual(state.selectedIDs(in:input).count,10)
        XCTAssertEqual(input.scopeModelIDs,["m0","m1","m2"])
    }
}

@MainActor final class FieldFleetPickerViewTests:XCTestCase {
    func testOffscreenPickerEmitsOnlyFieldProjectionAndSavedValuesAndRetiresWhenHidden() async throws {
        let input=try pickerCatalogue(),view=FieldFleetPickerView(frame:.init(x:0,y:0,width:430,height:664))
        var changes:[FieldPickerChange]=[];view.onChange={changes.append($0)}
        view.update(catalogue:input,locale:.english)
        XCTAssertNil(view.presentation)
        view.selectPreset(.all);XCTAssertTrue(changes.isEmpty)
        view.setPresentationAllowed(true);view.selectPreset(.all)
        XCTAssertEqual(view.presentation?.selectedIDs.count,10)
        XCTAssertEqual(changes.last?.projection.models.count,10)
        XCTAssertNotNil(changes.last?.savedValue)
        view.focus("m3");XCTAssertEqual(changes.last?.focusedPublicID,"m3");XCTAssertNil(changes.last?.savedValue)
        view.setExpanded(false);XCTAssertFalse(view.presentation!.expanded)
        view.setExpanded(true);XCTAssertTrue(view.presentation!.expanded)
        XCTAssertEqual(input.scopeModelIDs,["m0","m1","m2"])
        let count=changes.count;view.setPresentationAllowed(false);view.reset();XCTAssertEqual(changes.count,count)
        view.dispose();view.setPresentationAllowed(true);view.reset();XCTAssertEqual(changes.count,count)
        XCTAssertNil(view.window)
    }
}
