// SPDX-License-Identifier: MIT
import Foundation
import CryptoKit

@_spi(SettingsAcceptance) public enum SettingsScenarioEvidence:String,Codable,Sendable {case offscreen,humanInput}
@_spi(SettingsAcceptance) public enum SettingsScenarioGate:String,Codable,Sendable {
    case paneMembership,searchFilter,localPopupCommit,aliasCancelNoCommit,firstRunReady
    case hostCommandComma,nativePopupEscape,imeCancelNoCommit,firstRunKeyboardOrder,voiceOver
}
@_spi(SettingsAcceptance) public enum SettingsScenarioID:String,Codable,CaseIterable,Sendable {
    case panes="settings.panes",search="settings.search",popups="settings.popups",aliasCancel="settings.alias-cancel"
    case firstRun="first-run.structure",commandComma="settings.command-comma.human",popupEscape="settings.popup-escape.human"
    case imeCancel="settings.ime-cancel.human",firstRunFocus="first-run.focus.human",voiceOver="settings.voiceover.human"
    public var evidence:SettingsScenarioEvidence {
        switch self{case .panes,.search,.popups,.aliasCancel,.firstRun:return .offscreen;default:return .humanInput}
    }
    public var gate:SettingsScenarioGate {
        switch self{
        case .panes:return .paneMembership;case .search:return .searchFilter;case .popups:return .localPopupCommit
        case .aliasCancel:return .aliasCancelNoCommit;case .firstRun:return .firstRunReady;case .commandComma:return .hostCommandComma
        case .popupEscape:return .nativePopupEscape;case .imeCancel:return .imeCancelNoCommit;case .firstRunFocus:return .firstRunKeyboardOrder;case .voiceOver:return .voiceOver
        }
    }
}
@_spi(SettingsAcceptance) public enum SettingsScenarioAction:String,Codable,Sendable {
    case visitPane,search,choosePopup,beginAliasDraft,cancelAliasDraft,prepareFirstRun,checkpoint,awaitHuman
}
@_spi(SettingsAcceptance) public enum SettingsScenarioInputError:Error,Equatable {case invalidCatalog,invalidFixture,invalidScene,invalidStep,missingBinding}

@_spi(SettingsAcceptance) public struct SettingsScenarioStep:Decodable,Sendable {
    public let action:SettingsScenarioAction
    public let pane:String?,key:String?,value:String?,checkpoint:String?,instruction:String?
}
@_spi(SettingsAcceptance) public struct SettingsScenarioProfile:Decodable,Equatable,Sendable {
    public let id:String,locale:String,theme:String,scale:Int
    public let physicalTopologyEstablished:Bool
}
@_spi(SettingsAcceptance) public struct SettingsScenarioFixture:Decodable,Equatable,Sendable {
    public let id:String,path:String,sha256:String,subscriptionCount:Int
}
@_spi(SettingsAcceptance) public struct SettingsScenarioFixtureInput:Decodable,Sendable {
    public let id:String,subscriptionCount:Int,savedAlias:String,serviceEffects:String
}
@_spi(SettingsAcceptance) public struct SettingsScenarioSource:Decodable,Sendable {
    public let nativeBaseRevision:String,contract:String
}
@_spi(SettingsAcceptance) public struct SettingsShortScenario:Decodable,Sendable {
    public let id:SettingsScenarioID,revision:Int,fixture:String,profile:String
    public let fixtureVariants:[String]?
    public let evidence:SettingsScenarioEvidence,expectedGate:SettingsScenarioGate
    public let steps:[SettingsScenarioStep]
    public var allowedFixtures:[String]{[fixture]+(fixtureVariants ?? [])}
}

/// This leaf catalog is input to a caller-owned runner. It has no executor, scheduler or pass receipts.
@_spi(SettingsAcceptance) public struct SettingsAcceptanceScenarios:Decodable,Sendable {
    public let catalogVersion:Int,source:SettingsScenarioSource
    public let requiredRuntimeBindings:[String]
    public let fixtures:[SettingsScenarioFixture],profiles:[SettingsScenarioProfile],scenarios:[SettingsShortScenario]
    public private(set) var definitionSHA256=""
    private enum CodingKeys:String,CodingKey {case catalogVersion,source,requiredRuntimeBindings,fixtures,profiles,scenarios}
    public static let runtimeBindingKeys:Set<String>=["fixtureHash","sourceRevision","appRevision","cliRevision","visualRevision","toolchain","os","hardware","profile"]
    public static func decode(_ data:Data)throws->Self {
        guard data.count<=65_536 else{throw SettingsScenarioInputError.invalidCatalog}
        do{
            // Closed input shapes prevent a hand-authored result/permission flag from becoming a receipt.
            guard let root=try JSONSerialization.jsonObject(with:data) as? [String:Any] else{throw SettingsScenarioInputError.invalidCatalog}
            try keys(root,["catalogVersion","source","requiredRuntimeBindings","fixtures","profiles","scenarios"])
            guard let source=root["source"] as? [String:Any] else{throw SettingsScenarioInputError.invalidCatalog}
            try keys(source,["nativeBaseRevision","contract"])
            for fixture in root["fixtures"] as? [[String:Any]] ?? []{try keys(fixture,["id","path","sha256","subscriptionCount"])}
            for profile in root["profiles"] as? [[String:Any]] ?? []{try keys(profile,["id","locale","theme","scale","physicalTopologyEstablished"])}
            for scene in root["scenarios"] as? [[String:Any]] ?? []{
                try keys(scene,["id","revision","fixture","fixtureVariants","profile","evidence","expectedGate","steps"])
                for step in scene["steps"] as? [[String:Any]] ?? []{try keys(step,["action","pane","key","value","checkpoint","instruction"])}
            }
            var value=try JSONDecoder().decode(Self.self,from:data);try value.validate()
            value.definitionSHA256=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined();return value
        }catch let error as SettingsScenarioInputError{throw error}
        catch{throw SettingsScenarioInputError.invalidCatalog}
    }
    private static func keys(_ value:[String:Any],_ allowed:Set<String>)throws {
        guard Set(value.keys).isSubset(of:allowed) else{throw SettingsScenarioInputError.invalidCatalog}
    }
    private static func hex(_ value:String,count:Int)->Bool {
        value.utf8.count==count && value.utf8.allSatisfy{(48...57).contains($0)||(97...102).contains($0)}
    }
    private static func identifier(_ value:String)->Bool {
        !value.isEmpty && value.utf8.count<=80 && value.utf8.allSatisfy{(97...122).contains($0)||(48...57).contains($0)||[45,46,95].contains($0)}
    }
    public func validate()throws {
        guard catalogVersion==1,Self.hex(source.nativeBaseRevision,count:40),source.contract=="settings.task65",
              Set(requiredRuntimeBindings)==Self.runtimeBindingKeys,requiredRuntimeBindings.count==Self.runtimeBindingKeys.count,
              (1...6).contains(fixtures.count),Set(fixtures.map(\.id)).count==fixtures.count,
              (1...4).contains(profiles.count),Set(profiles.map(\.id)).count==profiles.count,
              Set(scenarios.map(\.id))==Set(SettingsScenarioID.allCases),scenarios.count==SettingsScenarioID.allCases.count else{throw SettingsScenarioInputError.invalidCatalog}
        for fixture in fixtures{
            guard Self.identifier(fixture.id),Self.hex(fixture.sha256,count:64),[0,1,6].contains(fixture.subscriptionCount),
                  fixture.path.hasPrefix("Fixtures/"),fixture.path.hasSuffix(".json"),fixture.path.utf8.count<=160,
                  !fixture.path.contains(".."),!fixture.path.contains("\\"),!fixture.path.contains(":"),
                  fixture.path.split(separator:"/",omittingEmptySubsequences:false).count==2 else{throw SettingsScenarioInputError.invalidFixture}
        }
        for profile in profiles{
            guard Self.identifier(profile.id),["en","zh-CN"].contains(profile.locale),["day","night"].contains(profile.theme),
                  [1,2].contains(profile.scale),!profile.physicalTopologyEstablished else{throw SettingsScenarioInputError.invalidCatalog}
        }
        let paneIDs=SettingsStructure.task65.panes.map(\.id)
        for scene in scenarios{
            guard (1...1000).contains(scene.revision),scene.evidence==scene.id.evidence,scene.expectedGate==scene.id.gate,fixtures.contains(where:{$0.id==scene.fixture}),
                  scene.allowedFixtures.count<=3,Set(scene.allowedFixtures).count==scene.allowedFixtures.count,
                  scene.allowedFixtures.allSatisfy({id in fixtures.contains{$0.id==id}}),
                  profiles.contains(where:{$0.id==scene.profile}),(1...32).contains(scene.steps.count) else{throw SettingsScenarioInputError.invalidScene}
            let checkpoints=scene.steps.compactMap(\.checkpoint)
            guard !checkpoints.isEmpty,Set(checkpoints).count==checkpoints.count else{throw SettingsScenarioInputError.invalidScene}
            if scene.id == .panes{guard scene.steps.filter({$0.action == .visitPane}).compactMap(\.pane)==paneIDs else{throw SettingsScenarioInputError.invalidScene}}
            if scene.evidence == .humanInput{guard scene.steps.contains(where:{$0.action == .awaitHuman}) else{throw SettingsScenarioInputError.invalidScene}}
            if scene.id == .aliasCancel || scene.id == .imeCancel{guard fixtures.filter({scene.allowedFixtures.contains($0.id)}).allSatisfy({$0.subscriptionCount>0}) else{throw SettingsScenarioInputError.invalidScene}}
            if scene.id == .imeCancel{guard profiles.first(where:{$0.id==scene.profile})!.locale=="zh-CN" else{throw SettingsScenarioInputError.invalidScene}}
            for step in scene.steps{try Self.validate(step,evidence:scene.evidence,paneIDs:paneIDs)}
            try Self.validatePlan(scene,paneIDs:paneIDs)
        }
    }
    private static func validatePlan(_ scene:SettingsShortScenario,paneIDs:[String])throws {
        let allowed:Set<SettingsScenarioAction>
        switch scene.id{
        case .panes:allowed=[.visitPane,.checkpoint]
        case .search:allowed=[.visitPane,.search,.checkpoint]
        case .popups:allowed=[.visitPane,.choosePopup,.checkpoint]
        case .aliasCancel:allowed=[.visitPane,.beginAliasDraft,.cancelAliasDraft,.checkpoint]
        case .firstRun:allowed=[.prepareFirstRun,.checkpoint]
        default:allowed=[.awaitHuman,.checkpoint]
        }
        guard scene.steps.allSatisfy({allowed.contains($0.action)}) else{throw SettingsScenarioInputError.invalidScene}
        if scene.id == .panes{
            guard scene.steps.count==paneIDs.count*2 else{throw SettingsScenarioInputError.invalidScene}
            for index in paneIDs.indices{guard scene.steps[index*2].pane==paneIDs[index],scene.steps[index*2+1].action == .checkpoint else{throw SettingsScenarioInputError.invalidScene}}
        }
        if scene.id == .search{let values=scene.steps.filter{$0.action == .search}.compactMap(\.value);guard values.contains(where:{!$0.isEmpty}),values.last=="" else{throw SettingsScenarioInputError.invalidScene}}
        if scene.id == .popups{guard scene.steps.contains(where:{$0.action == .choosePopup}) else{throw SettingsScenarioInputError.invalidScene}}
        if scene.id == .aliasCancel{
            guard scene.steps.filter({$0.action == .beginAliasDraft}).count==1,scene.steps.filter({$0.action == .cancelAliasDraft}).count==1,
                  scene.steps.firstIndex(where:{$0.action == .beginAliasDraft})! < scene.steps.firstIndex(where:{$0.action == .cancelAliasDraft})! else{throw SettingsScenarioInputError.invalidScene}
        }
        if scene.id == .firstRun{guard scene.steps.first?.action == .prepareFirstRun,scene.steps.filter({$0.action == .prepareFirstRun}).count==1 else{throw SettingsScenarioInputError.invalidScene}}
        var pane="general"
        for step in scene.steps{
            if step.action == .visitPane{pane=step.pane!}
            if step.action == .beginAliasDraft{guard pane=="subscriptions" else{throw SettingsScenarioInputError.invalidScene}}
            if step.action == .choosePopup{
                guard let key=SettingKey(rawValue:step.key!),SettingsStructure.task65.panes.first(where:{$0.groups.contains(where:{$0.keys.contains(key)})})?.id==pane else{throw SettingsScenarioInputError.invalidScene}
            }
        }
    }
    private static func validate(_ step:SettingsScenarioStep,evidence:SettingsScenarioEvidence,paneIDs:[String])throws {
        if evidence == .humanInput,step.action != .awaitHuman && step.action != .checkpoint{throw SettingsScenarioInputError.invalidStep}
        switch step.action{
        case .visitPane:guard let pane=step.pane,paneIDs.contains(pane),step.key==nil,step.value==nil,step.checkpoint==nil,step.instruction==nil else{throw SettingsScenarioInputError.invalidStep}
        case .search,.beginAliasDraft:
            guard let value=step.value,value.count<=128,value.utf8.count<=512,!value.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains),
                  step.pane==nil,step.key==nil,step.checkpoint==nil,step.instruction==nil else{throw SettingsScenarioInputError.invalidStep}
        case .choosePopup:
            let safe:[String:Set<String>]=["theme":["system","day","night"],"size":["S","M","L"],"motion":["system","on"],"percentageMode":["remaining","used"]]
            guard let key=step.key,let value=step.value,safe[key]?.contains(value)==true,step.pane==nil,step.checkpoint==nil,step.instruction==nil else{throw SettingsScenarioInputError.invalidStep}
        case .checkpoint:guard let id=step.checkpoint,identifier(id),step.pane==nil,step.key==nil,step.value==nil,step.instruction==nil else{throw SettingsScenarioInputError.invalidStep}
        case .awaitHuman:
            guard evidence == .humanInput,let instruction=step.instruction,!instruction.isEmpty,instruction.utf8.count<=1024,
                  step.pane==nil,step.key==nil,step.value==nil,step.checkpoint==nil else{throw SettingsScenarioInputError.invalidStep}
        case .cancelAliasDraft,.prepareFirstRun:
            guard step.pane==nil,step.key==nil,step.value==nil,step.checkpoint==nil,step.instruction==nil else{throw SettingsScenarioInputError.invalidStep}
        }
    }
    @discardableResult public func validateFixture(_ data:Data,reference:SettingsScenarioFixture)throws->SettingsScenarioFixtureInput {
        guard fixtures.contains(reference),data.count<=8192,SHA256.hash(data:data).map({String(format:"%02x",$0)}).joined()==reference.sha256,
              let shape=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              Set(shape.keys)==["id","subscriptionCount","savedAlias","serviceEffects"],
              let value=try? JSONDecoder().decode(SettingsScenarioFixtureInput.self,from:data),
              value.id==reference.id,value.subscriptionCount==reference.subscriptionCount,value.serviceEffects=="disabled",
              value.savedAlias.count<=128,value.savedAlias.utf8.count<=512,
              !value.savedAlias.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains) else{throw SettingsScenarioInputError.invalidFixture}
        return value
    }
    /// Format/completeness only. Global run identity, actual provenance and receipt invalidation belong to M0.
    public func validateRuntimeBindings(_ bindings:[String:String],for sceneID:SettingsScenarioID)throws {
        guard let scene=scenarios.first(where:{$0.id==sceneID}),let fixture=fixtures.first(where:{scene.allowedFixtures.contains($0.id) && $0.sha256==bindings["fixtureHash"]}),
              Set(bindings.keys)==Self.runtimeBindingKeys,bindings.values.allSatisfy({!$0.isEmpty && $0.utf8.count<=256 && !$0.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains)}),
              Self.hex(bindings["sourceRevision"] ?? "",count:40),Self.hex(bindings["appRevision"] ?? "",count:40),
              bindings["fixtureHash"]==fixture.sha256,bindings["profile"]==scene.profile else{throw SettingsScenarioInputError.missingBinding}
    }
    /// Caller-owned checkpoints may match this token; this module neither persists nor resumes a run.
    public func inputIdentity(_ bindings:[String:String],for sceneID:SettingsScenarioID)throws->String {
        try validateRuntimeBindings(bindings,for:sceneID)
        guard Self.hex(definitionSHA256,count:64),let scene=scenarios.first(where:{$0.id==sceneID}) else{throw SettingsScenarioInputError.invalidCatalog}
        let parts=[definitionSHA256,sceneID.rawValue,String(scene.revision)]+bindings.keys.sorted().flatMap{[$0,bindings[$0]!]}
        return SHA256.hash(data:Data(parts.joined(separator:"\u{0}").utf8)).map{String(format:"%02x",$0)}.joined()
    }
}
