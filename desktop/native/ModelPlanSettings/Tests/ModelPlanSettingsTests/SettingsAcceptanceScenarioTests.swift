// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
@_spi(SettingsAcceptance) @testable import ModelPlanSettings

@MainActor final class SettingsAcceptanceScenarioTests:XCTestCase {
    private var root:URL {URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Acceptance")}
    private func data()throws->Data{try Data(contentsOf:root.appendingPathComponent("settings-short-scenarios.json"))}
    private func catalog()throws->SettingsAcceptanceScenarios{try .decode(data())}
    private func edited(_ edit:(inout [String:Any])->Void)throws->SettingsAcceptanceScenarios{
        var value=try XCTUnwrap(JSONSerialization.jsonObject(with:data()) as? [String:Any]);edit(&value)
        return try .decode(JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]))
    }
    private func bindings(_ scene:SettingsShortScenario,_ catalog:SettingsAcceptanceScenarios)->[String:String]{
        ["fixtureHash":catalog.fixtures.first{$0.id==scene.fixture}!.sha256,"sourceRevision":String(repeating:"a",count:40),"appRevision":String(repeating:"b",count:40),
         "cliRevision":"fixture-cli-unavailable","visualRevision":"neutral-fixture-only","toolchain":"test-fixture","os":"test-fixture","hardware":"test-fixture","profile":scene.profile]
    }
    func testCompleteCatalogFixturesAndManualGatesValidate()throws{
        let catalog=try catalog()
        XCTAssertEqual(catalog.scenarios.count,10);XCTAssertEqual(catalog.scenarios.filter{$0.evidence == .offscreen}.count,5)
        for fixture in catalog.fixtures{try catalog.validateFixture(Data(contentsOf:root.appendingPathComponent(fixture.path)),reference:fixture)}
        for scene in catalog.scenarios{
            let identity=try catalog.inputIdentity(bindings(scene,catalog),for:scene.id)
            XCTAssertEqual(identity.count,64)
            if scene.evidence == .humanInput{XCTAssertTrue(scene.steps.allSatisfy{$0.action == .awaitHuman || $0.action == .checkpoint})}
        }
    }
    func testInputValidationRejectsResultFlagsServicesWrongGatesAndPaths()throws{
        XCTAssertThrowsError(try edited{$0["physicalPass"]=true})
        XCTAssertThrowsError(try edited{value in var scenes=value["scenarios"] as! [[String:Any]];scenes[0]["expectedGate"]="voiceOver";value["scenarios"]=scenes})
        XCTAssertThrowsError(try edited{value in var scenes=value["scenarios"] as! [[String:Any]];scenes[5]["evidence"]="offscreen";value["scenarios"]=scenes})
        XCTAssertThrowsError(try edited{value in var scenes=value["scenarios"] as! [[String:Any]];scenes[0]["steps"]=[["action":"registerLogin"]];value["scenarios"]=scenes})
        XCTAssertThrowsError(try edited{value in var scenes=value["scenarios"] as! [[String:Any]];var steps=scenes[2]["steps"] as! [[String:Any]];steps[1]=["action":"choosePopup","key":"login","value":"true"];scenes[2]["steps"]=steps;value["scenarios"]=scenes})
        XCTAssertThrowsError(try edited{value in var fixtures=value["fixtures"] as! [[String:Any]];fixtures[0]["path"]="Fixtures/../settings.json";value["fixtures"]=fixtures})
        XCTAssertThrowsError(try edited{value in var profiles=value["profiles"] as! [[String:Any]];profiles[0]["physicalTopologyEstablished"]=true;value["profiles"]=profiles})
        XCTAssertThrowsError(try edited{value in var scenes=value["scenarios"] as! [[String:Any]];scenes[1]["id"]=scenes[0]["id"];value["scenarios"]=scenes})
        XCTAssertThrowsError(try edited{value in var scenes=value["scenarios"] as! [[String:Any]];scenes[1]["steps"]=[["action":"prepareFirstRun"],["action":"checkpoint","checkpoint":"wrong-surface"]];value["scenarios"]=scenes})
        XCTAssertThrowsError(try edited{value in var scenes=value["scenarios"] as! [[String:Any]];var steps=scenes[2]["steps"] as! [[String:Any]];steps[0]=["action":"visitPane","pane":"dock"];scenes[2]["steps"]=steps;value["scenarios"]=scenes})
        XCTAssertThrowsError(try edited{value in var scenes=value["scenarios"] as! [[String:Any]];var steps=scenes[3]["steps"] as! [[String:Any]];steps.removeAll{$0["action"] as? String=="cancelAliasDraft"};scenes[3]["steps"]=steps;value["scenarios"]=scenes})
    }
    func testFixtureHashAndRuntimeBindingChangesCannotReuseInputIdentity()throws{
        let catalog=try catalog(),scene=catalog.scenarios.first{$0.id == .search}!,reference=catalog.fixtures[0]
        var fixture=try Data(contentsOf:root.appendingPathComponent(reference.path));fixture.append(32)
        XCTAssertThrowsError(try catalog.validateFixture(fixture,reference:reference))
        let good=bindings(scene,catalog),identity=try catalog.inputIdentity(good,for:scene.id)
        var missing=good;missing.removeValue(forKey:"os");XCTAssertThrowsError(try catalog.inputIdentity(missing,for:scene.id))
        var wrong=good;wrong["profile"]="zh-day-1x-logical";XCTAssertThrowsError(try catalog.inputIdentity(wrong,for:scene.id))
        var changed=good;changed["appRevision"]=String(repeating:"c",count:40)
        XCTAssertNotEqual(try catalog.inputIdentity(changed,for:scene.id),identity)
        let definition=try edited{value in var scenes=value["scenarios"] as! [[String:Any]];scenes[1]["revision"]=2;value["scenarios"]=scenes}
        XCTAssertNotEqual(try definition.inputIdentity(good,for:scene.id),identity)
    }
    func testOffscreenShortScenesUseTheExistingXCTestControllerAdapter() async throws{
        let catalog=try catalog()
        for scene in catalog.scenarios where scene.evidence == .offscreen{
          for fixtureID in scene.allowedFixtures{
            let fixture=try await Fixture(root:root,catalog:catalog,scene:scene,fixtureID:fixtureID);defer{fixture.close()}
            var pane="general",query="",popup:(SettingKey,String)?
            let baseline=await fixture.store.snapshot().revision
            for step in scene.steps{
                switch step.action{
                case .visitPane:pane=step.pane!;fixture.controller.selectPane(pane)
                case .search:query=step.value!;fixture.search(query)
                case .choosePopup:
                    let key=try XCTUnwrap(SettingKey(rawValue:step.key!));try await fixture.choose(key,step.value!);popup=(key,step.value!)
                case .beginAliasDraft:try fixture.beginAlias(step.value!)
                case .cancelAliasDraft:try fixture.cancelAlias()
                case .prepareFirstRun:try await fixture.prepareFirstRun()
                case .checkpoint:
                    let observation:SettingsAcceptanceCheckpoint
                    if let firstRun=fixture.firstRun{observation=await firstRun.acceptanceCheckpoint()}
                    else{observation=await fixture.controller.acceptanceCheckpoint()}
                    XCTAssertTrue(observation.consistentRevision,scene.id.rawValue);XCTAssertFalse(observation.isSaving)
                    XCTAssertFalse(observation.physicalInputEstablished);XCTAssertFalse(observation.windowVisible)
                    XCTAssertEqual(observation.evidenceClass,"observation-only")
                    let saved=await fixture.store.snapshot()
                    switch scene.expectedGate{
                    case .paneMembership,.searchFilter:
                        XCTAssertEqual(observation.settings?.selectedPane,pane)
                        let rows=try SettingsCatalogue.rows(preferences:saved.preferences,context:fixture.editor.context,paneID:query.isEmpty ? pane:nil,query:query)
                        XCTAssertEqual(observation.settings?.visibleKeys,rows.map{$0.key.rawValue})
                        XCTAssertEqual(observation.settings?.searchLength,query.count)
                    case .localPopupCommit:
                        let (key,value)=try XCTUnwrap(popup)
                        if key == .theme{XCTAssertEqual(saved.preferences.theme.rawValue,value)}
                        if key == .motion{XCTAssertEqual(saved.preferences.motion.rawValue,value)}
                        if key == .size{XCTAssertEqual(saved.preferences.size.rawValue,value)}
                        XCTAssertTrue(observation.settings!.popups.contains{$0.key==key.rawValue && $0.selectedIndex>=0})
                    case .aliasCancelNoCommit:
                        XCTAssertEqual(saved.revision,baseline)
                        XCTAssertEqual(saved.preferences.subscriptionSettings["fixture.0"]?.alias,fixture.input.savedAlias)
                        if step.checkpoint=="alias.draft"{XCTAssertEqual(observation.settings?.editingAliases,1)}
                        if step.checkpoint=="alias.cancelled"{XCTAssertEqual(observation.settings?.editingAliases,0);XCTAssertEqual(observation.settings?.unsavedAliases,0)}
                    case .firstRunReady:
                        let state=try XCTUnwrap(observation.firstRun)
                        XCTAssertTrue(state.active && state.pageValid && state.keyChainMatches && state.doneEnabled)
                        XCTAssertEqual(state.subscriptionCount,fixture.input.subscriptionCount);XCTAssertEqual(state.checkedReaders,0)
                        XCTAssertTrue(state.loginChecked);XCTAssertFalse(state.helpEnabled)
                        XCTAssertEqual(observation.focus.initialRole,"firstRun.reader.0")
                    default:XCTFail("A human gate entered the offscreen driver")
                    }
                case .awaitHuman:XCTFail("Human input must not be synthesized by this adapter")
                }
            }
            XCTAssertTrue(fixture.requests.isEmpty);XCTAssertTrue(fixture.clipboard.writes.isEmpty)
          }
        }
    }
    func testCheckpointReadDoesNotReloadMutateOrDiscloseUserText() async throws{
        let catalog=try catalog(),scene=catalog.scenarios.first{$0.id == .search}!
        let fixture=try await Fixture(root:root,catalog:catalog,scene:scene);defer{fixture.close()}
        fixture.search(fixture.input.savedAlias)
        let before=await fixture.store.snapshot().revision
        let observation=await fixture.controller.acceptanceCheckpoint()
        let after=await fixture.store.snapshot().revision
        XCTAssertEqual(before,after);XCTAssertTrue(observation.consistentRevision)
        XCTAssertEqual(observation.settings?.searchLength,fixture.input.savedAlias.count)
        let text=String(decoding:try JSONEncoder().encode(observation),as:UTF8.self)
        for privateText in [fixture.input.savedAlias,"fixture.0","Fixture subscription"]{XCTAssertFalse(text.contains(privateText))}
        XCTAssertEqual(observation.focus.markedText,.unobserved);XCTAssertFalse(observation.physicalInputEstablished)
    }
    func testSyntheticMarkedTextIsAnObservationAndNeverHumanProof() async throws{
        let catalog=try catalog(),scene=catalog.scenarios.first{$0.id == .aliasCancel}!
        let fixture=try await Fixture(root:root,catalog:catalog,scene:scene);defer{fixture.close()}
        fixture.controller.selectPane("subscriptions")
        let field=try XCTUnwrap(fixture.controller.aliasControl(subscriptionID:"fixture.0"))
        XCTAssertTrue(fixture.controller.window!.makeFirstResponder(field))
        let editor=try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.setMarkedText("工",selectedRange:.init(location:1,length:0),replacementRange:.init(location:NSNotFound,length:0))
        let observation=await fixture.controller.acceptanceCheckpoint()
        XCTAssertEqual(observation.focus.actualRole,"settings.alias");XCTAssertEqual(observation.focus.markedText,.marked)
        XCTAssertFalse(observation.physicalInputEstablished)
        editor.unmarkText();XCTAssertTrue(field.control(field,textView:editor,doCommandBy:#selector(NSResponder.cancelOperation(_:))))
    }
}

@MainActor private final class Fixture {
    final class Clipboard:SettingsDiagnosticClipboard{var writes=[String]();func writeDiagnostics(_ text:String)->Bool{writes.append(text);return true}}
    let directory:URL,store:SettingsStore,editor:SettingsEditor,controller:SettingsWindowController,clipboard:Clipboard,input:SettingsScenarioFixtureInput
    var firstRun:SettingsFirstRunController?,requests=[SettingsHostRequest]()
    init(root:URL,catalog:SettingsAcceptanceScenarios,scene:SettingsShortScenario,fixtureID:String?=nil) async throws{
        let selected=fixtureID ?? scene.fixture
        guard scene.allowedFixtures.contains(selected) else{throw SettingsScenarioInputError.invalidFixture}
        let reference=catalog.fixtures.first{$0.id==selected}!,profile=catalog.profiles.first{$0.id==scene.profile}!
        let input=try catalog.validateFixture(Data(contentsOf:root.appendingPathComponent(reference.path)),reference:reference)
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("m4-b25-scene-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let store=try SettingsStore(url:directory.appendingPathComponent("preferences.json"))
        let language=SettingsLanguage(rawValue:profile.locale)!,theme=SettingsTheme(rawValue:profile.theme)!,alias=input.savedAlias
        try await store.update{$0.language=language;$0.theme=theme;if reference.subscriptionCount>0{$0.subscriptionSettings["fixture.0"] = .init(alias:alias)}}
        var context=SettingsPageContext();context.capabilities.login = .unavailable
        context.subscriptions=(0..<input.subscriptionCount).map{.init(id:"fixture.\($0)",name:.init("Fixture subscription \($0)","示例订阅 \($0)"))}
        var environment=SettingsEnvironment();environment.reduceMotion=true
        let editor=SettingsEditor(store:store,context:context,environment:environment),clipboard=Clipboard(),fixedEnvironment=environment
        let controller=SettingsWindowController(editor:editor,environmentProvider:{fixedEnvironment},clipboard:clipboard)
        self.input=input;self.directory=directory;self.store=store;self.editor=editor;self.clipboard=clipboard;self.controller=controller
        editor.onHostRequest={[weak self] in self?.requests.append($0)}
        await controller.prepare()
    }
    func search(_ value:String){controller.searchField.stringValue=value;controller.controlTextDidChange(.init(name:NSControl.textDidChangeNotification,object:controller.searchField))}
    func choose(_ key:SettingKey,_ value:String) async throws{
        let popup=try XCTUnwrap(controller.choice(key:key)),index=try XCTUnwrap(popup.itemArray.firstIndex{$0.representedObject as? String==value})
        popup.selectItem(at:index);XCTAssertTrue(popup.sendAction(popup.action,to:popup.target));await controller.waitForPendingSave()
    }
    func beginAlias(_ value:String)throws{
        let field=try XCTUnwrap(controller.aliasControl(subscriptionID:"fixture.0"))
        XCTAssertTrue(controller.window!.makeFirstResponder(field));field.controlTextDidBeginEditing(.init(name:NSControl.textDidBeginEditingNotification,object:field))
        let editor=try XCTUnwrap(field.currentEditor() as? NSTextView);editor.string=value;field.stringValue=value
    }
    func cancelAlias()throws{
        let field=try XCTUnwrap(controller.aliasControl(subscriptionID:"fixture.0")),editor=try XCTUnwrap(field.currentEditor() as? NSTextView)
        XCTAssertTrue(field.control(field,textView:editor,doCommandBy:#selector(NSResponder.cancelOperation(_:))))
    }
    func prepareFirstRun() async throws{let value=SettingsFirstRunController(editor:editor);firstRun=value;await value.prepare()}
    func close(){firstRun?.suspend();firstRun?.close();controller.close();try? FileManager.default.removeItem(at:directory)}
}
