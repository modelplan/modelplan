// SPDX-License-Identifier: MIT
// Build only for synthetic verification: swiftc -parse-as-library
// -DMODELPLAN_TEST_ONLY_SPI StatusMenu/Sources/ModelPlanMenuVerification/*.swift
// bin/status_menu_drive.swift bin/pointer_drive.swift -o <owned-build>/pointer_drive
#if MODELPLAN_TEST_ONLY_SPI
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Darwin

enum PointerAction: String, Decodable { case move, click }
struct PointerStep: Decodable {
    let x: Double, y: Double, seconds: Double, dwell: Double
    let action: PointerAction?
    init(x: Double, y: Double, seconds: Double, dwell: Double, action: PointerAction? = nil) {
        self.x = x; self.y = y; self.seconds = seconds; self.dwell = dwell; self.action = action
    }
}
struct PointerPlan: Decodable {
    let profile: String, runID: String, epoch: String, lease: String, stop: String, output: String
    let subjectPID: Int32, subjectBundle: String
    let allowedRectangles: [[Double]]
    let steps: [PointerStep]
    let u6InputKind: String?, u6Observations: String?
    let u6FrameSeq: UInt64?, u6StatusFrameGeneration: UInt64?
    let u6StatusWindowNumber: Int?
    init(profile:String,runID:String,epoch:String,lease:String,stop:String,output:String,
         subjectPID:Int32,subjectBundle:String,allowedRectangles:[[Double]],steps:[PointerStep],
         u6InputKind:String? = nil,u6Observations:String? = nil,u6FrameSeq:UInt64? = nil,
         u6StatusFrameGeneration:UInt64? = nil,u6StatusWindowNumber:Int? = nil) {
        self.profile=profile;self.runID=runID;self.epoch=epoch;self.lease=lease;self.stop=stop;self.output=output
        self.subjectPID=subjectPID;self.subjectBundle=subjectBundle;self.allowedRectangles=allowedRectangles;self.steps=steps
        self.u6InputKind=u6InputKind;self.u6Observations=u6Observations;self.u6FrameSeq=u6FrameSeq
        self.u6StatusFrameGeneration=u6StatusFrameGeneration;self.u6StatusWindowNumber=u6StatusWindowNumber
    }
}
enum DriveError: Error { case invalidPlan, outsideScope, staleLease, subjectEnded, cannotCreateEvent }

/// Serialises each button transaction with termination. `press` posts down and records the
/// pending release inside one critical section; `release` posts up and clears it inside one
/// critical section. On SIGTERM/SIGINT, `terminate` takes the same lock, posts only a recorded
/// release, and the process exits while still holding the lock, so the main thread can never
/// post a down after the emergency up. Both signals share one serial queue.
final class ButtonGuard: @unchecked Sendable {
    static let shared = ButtonGuard()
    private let lock = NSLock()
    private var pendingUp: CGEvent?
    func press(down: CGEvent, up: CGEvent, post: (CGEvent) -> Void) {
        lock.lock(); post(down); pendingUp = up; lock.unlock()
    }
    func release(post: (CGEvent) -> Void) {
        lock.lock(); if let up = pendingUp { post(up); pendingUp = nil }; lock.unlock()
    }
    /// Termination path only: acquires the lock and intentionally never releases it.
    /// Returns whether a held button was released.
    @discardableResult func terminate(post: (CGEvent) -> Void) -> Bool {
        lock.lock()
        guard let up = pendingUp else { return false }
        post(up); pendingUp = nil; return true
    }
    private var sources: [DispatchSourceSignal] = []
    private let signalQueue = DispatchQueue(label: "pointer_drive.termination")
    func installTerminationRelease() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: signalQueue)
            source.setEventHandler { [unowned self] in
                self.terminate(post: { $0.post(tap: .cghidEventTap) })
                exit(128 + sig)
            }
            source.resume()
            sources.append(source)
        }
    }
}

@MainActor @main enum PointerDrive {
    private struct NativeFrame: Decodable {
        struct Checks: Decodable {
            let settled:Bool?,visible:Bool?,frameGeneration:UInt64?,windowNumber:Int?
            let stableSinceMono:Double?,cgX:Double?,cgY:Double?,width:Double?,height:Double?
            let displayBounds:[Double]?,menuBarBand:[Double]?
        }
        let runID:String,epoch:String,pid:Int32,seq:UInt64,mono:Double
        let event:String?,checks:Checks?
    }
    static func currentStatusFrame(_ p:PointerPlan,now:Double=ProcessInfo.processInfo.systemUptime) throws {
        let bound=p.u6InputKind == "status" || p.u6FrameSeq != nil && p.steps.contains { $0.action == .click }
        guard bound else { return }
        guard let path=p.u6Observations,let generation=p.u6StatusFrameGeneration,generation>0,
              let number=p.u6StatusWindowNumber,number>0,let sequence=p.u6FrameSeq else { throw DriveError.outsideScope }
        let url=URL(fileURLWithPath:path)
        guard (try url.resourceValues(forKeys:[.isSymbolicLinkKey])).isSymbolicLink != true else { throw DriveError.outsideScope }
        let data=try Data(contentsOf:url);guard data.count<=8_000_000 else { throw DriveError.outsideScope }
        var latest:NativeFrame?,lastSequence:UInt64=0,lastMono = -Double.infinity
        for line in data.split(separator:10) where !line.isEmpty {
            let row=try JSONDecoder().decode(NativeFrame.self,from:Data(line))
            guard row.runID==p.runID,row.epoch==p.epoch,row.pid==p.subjectPID else { continue }
            guard row.seq>lastSequence,row.mono.isFinite,row.mono>=lastMono else { throw DriveError.outsideScope }
            lastSequence=row.seq;lastMono=row.mono
            if row.event=="status-item-frame" { latest=row }
        }
        guard let row=latest,let c=row.checks,c.settled==true,c.visible==true,
              c.frameGeneration==generation,c.windowNumber==number,row.seq>=sequence,
              now.isFinite,now-row.mono>=0,now-row.mono<=2,
              let since=c.stableSinceMono,since.isFinite,row.mono-since>=0.5,
              let x=c.cgX,let y=c.cgY,let w=c.width,let h=c.height,
              [x,y,w,h].allSatisfy(\.isFinite),w>0,h>0,
              let d=c.displayBounds,let b=c.menuBarBand,d.count==4,b.count==4,
              (d+b).allSatisfy(\.isFinite),d[2]>0,d[3]>0,b[2]>0,b[3]>0,
              y<=d[1]+1,y+h>=d[1]-1,b[0]==d[0],b[1]==d[1],b[2]==d[2],b[3]<=d[3] else { throw DriveError.outsideScope }
        let frame=CGRect(x:x,y:y,width:w,height:h),display=CGRect(x:d[0],y:d[1],width:d[2],height:d[3])
        let band=CGRect(x:b[0],y:b[1],width:b[2],height:b[3])
        guard p.steps.allSatisfy({ let point=CGPoint(x:$0.x,y:$0.y);return frame.contains(point) && display.contains(point) && band.contains(point) }) else { throw DriveError.outsideScope }
    }
    /// Query only the exact native-bound own window; no global window/AX scan,
    /// image capture, title read or other-application geometry is used.
    static func currentStatusWindow(_ p:PointerPlan) throws {
        guard p.u6InputKind=="status" || p.u6FrameSeq != nil && p.steps.contains(where:{$0.action == .click}) else { return }
        guard let number=p.u6StatusWindowNumber,number>0,
              let entries=CGWindowListCopyWindowInfo(.optionIncludingWindow,CGWindowID(number)) as? [[String:Any]],
              entries.count==1,let entry=entries.first,
              (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==p.subjectPID,
              entry[kCGWindowIsOnscreen as String] as? Bool == true,
              let raw=entry[kCGWindowBounds as String] as? [String:Any],
              let bounds=CGRect(dictionaryRepresentation:raw as CFDictionary),
              p.steps.allSatisfy({ bounds.contains(CGPoint(x:$0.x,y:$0.y)) }) else { throw DriveError.outsideScope }
    }
    static func permission() -> [String: Any] {
        ["event":"pointer-host-permission","postEvents":AXIsProcessTrusted(),
         "helperPID":ProcessInfo.processInfo.processIdentifier,
         "timestamp":ISO8601DateFormatter().string(from:Date()),"requestsPermission":false]
    }
    static func append(_ row: [String: Any], to file: FileHandle) throws {
        let bytes = try JSONSerialization.data(withJSONObject:row,options:[.sortedKeys])
        try file.write(contentsOf:bytes + Data([10]))
    }
    static func live(_ p: PointerPlan) throws {
        guard !FileManager.default.fileExists(atPath:p.stop),
              let l = try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:p.lease))) as? [String:Any],
              l["runID"] as? String == p.runID, l["epoch"] as? String == p.epoch,
              l["exclusive"] as? Bool == true, l["ownerPreempted"] as? Bool == false,
              let until = l["expiresAt"] as? Double,
              let start = l["notBefore"] as? Double, 0 < until-start && until-start <= 1200,
              Date().timeIntervalSince1970 >= start, Date().timeIntervalSince1970 < until,
              let beat = l["guardianHeartbeatAt"] as? Double, (0...2).contains(Date().timeIntervalSince1970-beat) else { throw DriveError.staleLease }
        guard let subject = NSRunningApplication(processIdentifier:p.subjectPID), !subject.isTerminated,
              subject.bundleURL?.standardizedFileURL == URL(fileURLWithPath:p.subjectBundle).standardizedFileURL else { throw DriveError.subjectEnded }
    }
    static func pointAllowed(_ point: CGPoint, _ p: PointerPlan) -> Bool {
        p.allowedRectangles.contains { r in r.count == 4 && r.allSatisfy(\.isFinite) && r[2]>0 && r[3]>0 &&
            CGRect(x:r[0],y:r[1],width:r[2],height:r[3]).contains(point) }
    }
    static func activeDisplayBounds() throws -> [CGRect] {
        var count: UInt32=0
        guard CGGetActiveDisplayList(0,nil,&count) == .success,count>0,count<=64 else { throw DriveError.outsideScope }
        var ids=[CGDirectDisplayID](repeating:0,count:Int(count));var actual=count
        let result=ids.withUnsafeMutableBufferPointer { CGGetActiveDisplayList(UInt32($0.count),$0.baseAddress,&actual) }
        guard result == .success,actual>0,actual<=count else { throw DriveError.outsideScope }
        let bounds=ids.prefix(Int(actual)).map { CGDisplayBounds($0) }
        guard bounds.allSatisfy({ !$0.isEmpty && !$0.isInfinite && !$0.isNull }) else { throw DriveError.outsideScope }
        return bounds
    }
    static func onDisplay(_ point: CGPoint, _ displays: [CGRect]) -> Bool {
        displays.contains { $0.contains(point) }
    }
    static func validate(_ p: PointerPlan, displays: [CGRect]) throws {
        guard p.profile == "synthetic", !p.runID.isEmpty, !p.epoch.isEmpty, p.subjectPID>0,
              !p.steps.isEmpty, p.steps.count<=4096, !p.allowedRectangles.isEmpty,
              p.steps.allSatisfy({ [$0.x,$0.y,$0.seconds,$0.dwell].allSatisfy(\.isFinite) && $0.seconds>=0 && $0.dwell>=0 }),
              p.steps.reduce(0,{$0+$1.seconds+$1.dwell})<=1200,
              !displays.isEmpty,
              p.steps.allSatisfy({ pointAllowed(CGPoint(x:$0.x,y:$0.y),p) && onDisplay(CGPoint(x:$0.x,y:$0.y),displays) }) else { throw DriveError.invalidPlan }
    }
    // Construct the complete pair before pressing, then post down and up back to back with
    // no I/O between them; receipts are written only after the button is released. The
    // guard covers the remaining window: a SIGTERM/SIGINT from verification cleanup that
    // arrives while a button is held posts the matching up before the process exits.
    static func click(at point: CGPoint, post: (CGEvent) -> Void,
                      record: (CGEventType, Double, Double) throws -> Void, guardState: ButtonGuard = .shared,
                      beforePress: () throws -> Void = {}) throws {
        guard let down = CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:point,mouseButton:.left),
              let up = CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:point,mouseButton:.left) else { throw DriveError.cannotCreateEvent }
        down.setIntegerValueField(.mouseEventClickState,value:1)
        up.setIntegerValueField(.mouseEventClickState,value:1)
        try beforePress() // file/window checks finish before the atomic down/up pair
        let downMono=ProcessInfo.processInfo.systemUptime, downAt=Date().timeIntervalSince1970
        guardState.press(down: down, up: up, post: post)
        guardState.release(post: post)
        let upMono=ProcessInfo.processInfo.systemUptime, upAt=Date().timeIntervalSince1970
        try record(.leftMouseDown,downMono,downAt)
        try record(.leftMouseUp,upMono,upAt)
    }
    static func execute(_ p: PointerPlan, file: FileHandle) throws {
        try validate(p,displays:activeDisplayBounds())
        try live(p)
        try currentStatusFrame(p);try currentStatusWindow(p)
        let access = permission(); try append(access,to:file)
        guard access["postEvents"] as? Bool == true else {
            try append(["event":"pointer-result","outcome":"not-run","reason":"postEvents-not-granted"],to:file);return
        }
        var previous = CGPoint(x:p.steps[0].x,y:p.steps[0].y)
        for (index,step) in p.steps.enumerated() {
            let end = CGPoint(x:step.x,y:step.y)
            let displays=try activeDisplayBounds()
            guard pointAllowed(previous,p),pointAllowed(end,p),onDisplay(previous,displays),onDisplay(end,displays) else { throw DriveError.outsideScope }
            let count = max(1,Int(ceil(step.seconds*60)))
            for frame in 1...count {
                try live(p)
                guard AXIsProcessTrusted() else { throw DriveError.outsideScope }
                let f = Double(frame)/Double(count)
                let point = CGPoint(x:previous.x+(end.x-previous.x)*f,y:previous.y+(end.y-previous.y)*f)
                guard pointAllowed(point,p),onDisplay(point,try activeDisplayBounds()) else { throw DriveError.outsideScope }
                guard let event = CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:point,mouseButton:.left) else { throw DriveError.cannotCreateEvent }
                try currentStatusFrame(p);try currentStatusWindow(p)
                event.post(tap:.cghidEventTap)
                try append(["event":"mouse-moved-posted","kind":"move","runID":p.runID,"epoch":p.epoch,"subjectPID":p.subjectPID,"targetPID":p.subjectPID,
                    "step":index,"x":point.x,"y":point.y,"uptimeSeconds":ProcessInfo.processInfo.systemUptime,
                    "mono":ProcessInfo.processInfo.systemUptime,"at":Date().timeIntervalSince1970,
                    "timestamp":ISO8601DateFormatter().string(from:Date()),"tap":"kCGHIDEventTap"],to:file)
                if step.seconds>0 { Thread.sleep(forTimeInterval:step.seconds/Double(count)) }
            }
            if step.action == .click {
                try live(p)
                guard AXIsProcessTrusted(),pointAllowed(end,p),onDisplay(end,try activeDisplayBounds()) else { throw DriveError.outsideScope }
                try click(at:end,post: { $0.post(tap:.cghidEventTap) },record: { type,mono,at in
                    try append(["event":type == .leftMouseDown ? "mouse-button-down-posted" : "mouse-button-up-posted","kind":"click",
                        "runID":p.runID,"epoch":p.epoch,"subjectPID":p.subjectPID,"targetPID":p.subjectPID,"step":index,
                        "x":end.x,"y":end.y,"button":"left","clickCount":1,
                        "uptimeSeconds":mono,"mono":mono,"at":at,
                        "timestamp":ISO8601DateFormatter().string(from:Date()),"tap":"kCGHIDEventTap"],to:file)
                },beforePress: { try currentStatusFrame(p);try currentStatusWindow(p) })
            }
            let until = ProcessInfo.processInfo.systemUptime+step.dwell
            while ProcessInfo.processInfo.systemUptime<until { try live(p);Thread.sleep(forTimeInterval:0.025) }
            previous = end
        }
        try append(["event":"pointer-result","outcome":"posted","runID":p.runID,"epoch":p.epoch,
            "targetPID":p.subjectPID,"mono":ProcessInfo.processInfo.systemUptime,"at":Date().timeIntervalSince1970,
            "arrivalProof":"requires-correlated-native-receipts"],to:file)
    }
    static func entry() throws {
        let args = CommandLine.arguments
        if args.count == 3 && args[1] == "--fixture-receipts" {
            // Serialization capture only: no live(), permission(), CGEvent or AX call.
            let data=try Data(contentsOf:URL(fileURLWithPath:args[2]))
            guard let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]] else { throw DriveError.invalidPlan }
            for row in rows { try append(row,to:FileHandle.standardOutput) }
            return
        }
        if args.count == 2 && args[1] == "--self-test" {
            try StatusMenuDrive.selfTest() // Decode/validate only; no AX query, I/O or input.
            func fixture(_ profile: String = "synthetic", _ seconds: Double = 1) -> PointerPlan {
                PointerPlan(profile:profile,runID:"fixture",epoch:"epoch",lease:"unused",stop:"unused",output:"unused",subjectPID:1,subjectBundle:"/unused.app",allowedRectangles:[[0,0,100,100]],steps:[.init(x:10,y:10,seconds:seconds,dwell:0.2)])
            }
            let displays=[CGRect(x:0,y:0,width:100,height:100)]
            try validate(fixture(),displays:displays)
            precondition(!onDisplay(CGPoint(x:30,y:1440),[CGRect(x:0,y:0,width:2560,height:1440)]))
            precondition(onDisplay(CGPoint(x:1826,y:15),[CGRect(x:0,y:0,width:2560,height:1440)]))
            precondition(onDisplay(CGPoint(x:-20,y:10),[CGRect(x:0,y:0,width:100,height:100),CGRect(x:-100,y:0,width:100,height:100)]))
            do { try validate(fixture(),displays:[CGRect(x:100,y:100,width:100,height:100)]);preconditionFailure("off-display point admitted") }
            catch DriveError.invalidPlan { }
            precondition(pointAllowed(CGPoint(x:10,y:10),fixture()))
            precondition(!pointAllowed(CGPoint(x:101,y:10),fixture()))
            for bad in [fixture("owner"),fixture("synthetic",-1),fixture("synthetic",Double.infinity),fixture("synthetic",1201)] {
                do { try validate(bad,displays:displays); preconditionFailure("invalid plan admitted") } catch DriveError.invalidPlan { }
            }
            let oldStep = try JSONDecoder().decode(PointerStep.self,from:Data(#"{"x":10,"y":10,"seconds":0,"dwell":0}"#.utf8))
            precondition(oldStep.action == nil) // Existing U5 plans remain move-only.
            let clickStep = try JSONDecoder().decode(PointerStep.self,from:Data(#"{"action":"click","x":42,"y":24,"seconds":0,"dwell":0.2}"#.utf8))
            precondition(clickStep.action == .click)
            // Real file guard plus fake post sink: a state change between plan
            // creation and delivery must post neither movement nor button input.
            let frameFile=FileManager.default.temporaryDirectory.appendingPathComponent("u6-frame-"+UUID().uuidString)
            defer { try? FileManager.default.removeItem(at:frameFile) }
            let bound=PointerPlan(profile:"synthetic",runID:"fixture",epoch:"epoch",lease:"unused",stop:"unused",output:"unused",
                subjectPID:1,subjectBundle:"/unused.app",allowedRectangles:[[0,0,100,100]],steps:[clickStep],
                u6InputKind:"status",u6Observations:frameFile.path,u6FrameSeq:1,u6StatusFrameGeneration:1,u6StatusWindowNumber:7)
            let ready:[String:Any] = ["settled":true,"visible":true,"frameGeneration":1,"windowNumber":7,
                "stableSinceMono":99,"cgX":0,"cgY":0,"width":100,"height":50,
                "displayBounds":[0,0,100,100],"menuBarBand":[0,0,100,28]]
            func writeFrames(_ changes:[[String:Any]]) throws {
                var data=Data()
                for (index,checks) in ([ready]+changes).enumerated() {
                    data += try JSONSerialization.data(withJSONObject:["event":"status-item-frame","runID":"fixture","epoch":"epoch",
                        "pid":1,"seq":index+1,"mono":100+Double(index)*0.1,"checks":checks]) + Data([10])
                }
                try data.write(to:frameFile)
            }
            try writeFrames([]);try currentStatusFrame(bound,now:100.2)
            for change:[String:Any] in [
                ["settled":false,"visible":true,"frameGeneration":2,"windowNumber":7],
                ["settled":false,"visible":false,"frameGeneration":2,"windowNumber":7],
                ["settled":false,"visible":true,"frameGeneration":2,"windowNumber":8]] {
                try writeFrames([change]);var postedCount=0
                do {
                    try click(at:CGPoint(x:42,y:24),post:{ _ in postedCount+=1 },record:{ _,_,_ in },
                        beforePress:{ try currentStatusFrame(bound,now:100.2) })
                    preconditionFailure("invalidated frame delivered")
                } catch DriveError.outsideScope { }
                precondition(postedCount==0)
            }
            try writeFrames([])
            do { try currentStatusFrame(bound,now:103);preconditionFailure("stale frame admitted") }
            catch DriveError.outsideScope { }
            do {
                _ = try JSONDecoder().decode(PointerStep.self,from:Data(#"{"action":"double-click","x":10,"y":10,"seconds":0,"dwell":0}"#.utf8))
                preconditionFailure("unknown click action admitted")
            } catch is DecodingError { }
            let target = CGPoint(x:42,y:24)
            var events: [CGEvent] = [], records: [CGEventType] = []
            try click(at:target,post: { events.append($0) },record: { type,_,_ in records.append(type) })
            precondition(events.map(\.type) == [.leftMouseDown,.leftMouseUp])
            precondition(records == [.leftMouseDown,.leftMouseUp])
            precondition(events.allSatisfy { $0.location == target && $0.getIntegerValueField(.mouseEventButtonNumber) == 0 && $0.getIntegerValueField(.mouseEventClickState) == 1 })
            enum ReceiptFailure: Error { case expected }
            for failAt in [CGEventType.leftMouseDown,.leftMouseUp] {
                events = []
                do {
                    try click(at:target,post: { events.append($0) },record: { type,_,_ in if type == failAt { throw ReceiptFailure.expected } })
                    preconditionFailure("receipt failure swallowed")
                } catch ReceiptFailure.expected { }
                precondition(events.map(\.type) == [.leftMouseDown,.leftMouseUp])
            }
            // No receipt I/O runs between down and up: when the first receipt write starts,
            // both events have already been posted.
            final class Posted { var types: [CGEventType] = [] }
            let posted = Posted()
            try click(at:target,post: { posted.types.append($0.type) },record: { type,_,_ in
                if type == .leftMouseDown { precondition(posted.types == [.leftMouseDown,.leftMouseUp]) }
            })
            // A termination while the button is held posts exactly one up, after the down.
            final class Seen { var types: [CGEventType] = [] }
            guard let pDown = CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:target,mouseButton:.left),
                  let pUp = CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:target,mouseButton:.left) else { throw DriveError.cannotCreateEvent }
            let held = ButtonGuard(), heldSeen = Seen()
            held.press(down: pDown, up: pUp, post: { heldSeen.types.append($0.type) })
            precondition(held.terminate(post: { heldSeen.types.append($0.type) }))
            precondition(heldSeen.types == [.leftMouseDown,.leftMouseUp])
            // After a normal release, termination posts nothing.
            let done = ButtonGuard(), doneSeen = Seen()
            done.press(down: pDown, up: pUp, post: { doneSeen.types.append($0.type) })
            done.release(post: { doneSeen.types.append($0.type) })
            precondition(!done.terminate(post: { doneSeen.types.append($0.type) }))
            precondition(doneSeen.types == [.leftMouseDown,.leftMouseUp])
            // Termination before any press posts nothing (no up without a down).
            let idle = ButtonGuard(), idleSeen = Seen()
            precondition(!idle.terminate(post: { idleSeen.types.append($0.type) }) && idleSeen.types.isEmpty)
            print("PASS pointer bounds/profile/duration, current frame generation/window/visibility/freshness, invalidation before click posts nothing, move compatibility, click pair/coordinates, failure release, no I/O between down and up, termination release; no permission query or event posted");return
        }
        if args.count == 2 && args[1] == "--check" {
            let data = try JSONSerialization.data(withJSONObject:permission(),options:[.sortedKeys]);print(String(decoding:data,as:UTF8.self));return
        }
        if args.count == 3 && args[1] == "--status-menu-plan" {
            try StatusMenuDrive.entry(path:args[2]);return
        }
        guard args.count == 3 && args[1] == "--plan" else { throw DriveError.invalidPlan }
        let plan = try JSONDecoder().decode(PointerPlan.self,from:Data(contentsOf:URL(fileURLWithPath:args[2])))
        let path = URL(fileURLWithPath:plan.output)
        guard !FileManager.default.fileExists(atPath:path.path) else { throw DriveError.invalidPlan }
        guard FileManager.default.createFile(atPath:path.path,contents:nil,attributes:[.posixPermissions:0o600]) else { throw DriveError.invalidPlan }
        let out = try FileHandle(forWritingTo:path);defer { try? out.close() }
        do { try execute(plan,file:out) }
        catch { try append(["event":"pointer-result","outcome":"not-run","reason":"scope-lease-or-subject-ended",
            "runID":plan.runID,"epoch":plan.epoch,"targetPID":plan.subjectPID,
            "mono":ProcessInfo.processInfo.systemUptime,"at":Date().timeIntervalSince1970],to:out);throw error }
    }
    static func main() {
        ButtonGuard.shared.installTerminationRelease()
        do { try entry() }
        catch { print("{\"event\":\"pointer-error\",\"outcome\":\"not-run\",\"reason\":\"invalid-or-ended-verification-contract\"}");exit(1) }
    }
}
#else
#error("pointer_drive is test-only; compile with MODELPLAN_TEST_ONLY_SPI")
#endif
