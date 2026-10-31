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
    static func validate(_ p: PointerPlan) throws {
        guard p.profile == "synthetic", !p.runID.isEmpty, !p.epoch.isEmpty, p.subjectPID>0,
              !p.steps.isEmpty, p.steps.count<=4096, !p.allowedRectangles.isEmpty,
              p.steps.allSatisfy({ [$0.x,$0.y,$0.seconds,$0.dwell].allSatisfy(\.isFinite) && $0.seconds>=0 && $0.dwell>=0 }),
              p.steps.reduce(0,{$0+$1.seconds+$1.dwell})<=1200,
              p.steps.allSatisfy({ pointAllowed(CGPoint(x:$0.x,y:$0.y),p) }) else { throw DriveError.invalidPlan }
    }
    // Construct the complete pair before pressing, then post down and up back to back with
    // no I/O between them; receipts are written only after the button is released. The
    // guard covers the remaining window: a SIGTERM/SIGINT from verification cleanup that
    // arrives while a button is held posts the matching up before the process exits.
    static func click(at point: CGPoint, post: (CGEvent) -> Void,
                      record: (CGEventType, Double, Double) throws -> Void, guardState: ButtonGuard = .shared) throws {
        guard let down = CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:point,mouseButton:.left),
              let up = CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:point,mouseButton:.left) else { throw DriveError.cannotCreateEvent }
        down.setIntegerValueField(.mouseEventClickState,value:1)
        up.setIntegerValueField(.mouseEventClickState,value:1)
        let downMono=ProcessInfo.processInfo.systemUptime, downAt=Date().timeIntervalSince1970
        guardState.press(down: down, up: up, post: post)
        guardState.release(post: post)
        let upMono=ProcessInfo.processInfo.systemUptime, upAt=Date().timeIntervalSince1970
        try record(.leftMouseDown,downMono,downAt)
        try record(.leftMouseUp,upMono,upAt)
    }
    static func execute(_ p: PointerPlan, file: FileHandle) throws {
        try validate(p)
        try live(p)
        let access = permission(); try append(access,to:file)
        guard access["postEvents"] as? Bool == true else {
            try append(["event":"pointer-result","outcome":"not-run","reason":"postEvents-not-granted"],to:file);return
        }
        var previous = CGPoint(x:p.steps[0].x,y:p.steps[0].y)
        for (index,step) in p.steps.enumerated() {
            let end = CGPoint(x:step.x,y:step.y)
            guard pointAllowed(previous,p),pointAllowed(end,p) else { throw DriveError.outsideScope }
            let count = max(1,Int(ceil(step.seconds*60)))
            for frame in 1...count {
                try live(p)
                guard AXIsProcessTrusted() else { throw DriveError.outsideScope }
                let f = Double(frame)/Double(count)
                let point = CGPoint(x:previous.x+(end.x-previous.x)*f,y:previous.y+(end.y-previous.y)*f)
                guard pointAllowed(point,p) else { throw DriveError.outsideScope }
                guard let event = CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:point,mouseButton:.left) else { throw DriveError.cannotCreateEvent }
                event.post(tap:.cghidEventTap)
                try append(["event":"mouse-moved-posted","kind":"move","runID":p.runID,"epoch":p.epoch,"subjectPID":p.subjectPID,"targetPID":p.subjectPID,
                    "step":index,"x":point.x,"y":point.y,"uptimeSeconds":ProcessInfo.processInfo.systemUptime,
                    "mono":ProcessInfo.processInfo.systemUptime,"at":Date().timeIntervalSince1970,
                    "timestamp":ISO8601DateFormatter().string(from:Date()),"tap":"kCGHIDEventTap"],to:file)
                if step.seconds>0 { Thread.sleep(forTimeInterval:step.seconds/Double(count)) }
            }
            if step.action == .click {
                try live(p)
                guard AXIsProcessTrusted(),pointAllowed(end,p) else { throw DriveError.outsideScope }
                try click(at:end,post: { $0.post(tap:.cghidEventTap) },record: { type,mono,at in
                    try append(["event":type == .leftMouseDown ? "mouse-button-down-posted" : "mouse-button-up-posted","kind":"click",
                        "runID":p.runID,"epoch":p.epoch,"subjectPID":p.subjectPID,"targetPID":p.subjectPID,"step":index,
                        "x":end.x,"y":end.y,"button":"left","clickCount":1,
                        "uptimeSeconds":mono,"mono":mono,"at":at,
                        "timestamp":ISO8601DateFormatter().string(from:Date()),"tap":"kCGHIDEventTap"],to:file)
                })
            }
            let until = ProcessInfo.processInfo.systemUptime+step.dwell
            while ProcessInfo.processInfo.systemUptime<until { try live(p);Thread.sleep(forTimeInterval:0.025) }
            previous = end
        }
        try append(["event":"pointer-result","outcome":"posted","arrivalProof":"requires-correlated-native-receipts"],to:file)
    }
    static func entry() throws {
        let args = CommandLine.arguments
        if args.count == 2 && args[1] == "--self-test" {
            try StatusMenuDrive.selfTest() // Decode/validate only; no AX query, I/O or input.
            func fixture(_ profile: String = "synthetic", _ seconds: Double = 1) -> PointerPlan {
                PointerPlan(profile:profile,runID:"fixture",epoch:"epoch",lease:"unused",stop:"unused",output:"unused",subjectPID:1,subjectBundle:"/unused.app",allowedRectangles:[[0,0,100,100]],steps:[.init(x:10,y:10,seconds:seconds,dwell:0.2)])
            }
            try validate(fixture())
            precondition(pointAllowed(CGPoint(x:10,y:10),fixture()))
            precondition(!pointAllowed(CGPoint(x:101,y:10),fixture()))
            for bad in [fixture("owner"),fixture("synthetic",-1),fixture("synthetic",Double.infinity),fixture("synthetic",1201)] {
                do { try validate(bad); preconditionFailure("invalid plan admitted") } catch DriveError.invalidPlan { }
            }
            let oldStep = try JSONDecoder().decode(PointerStep.self,from:Data(#"{"x":10,"y":10,"seconds":0,"dwell":0}"#.utf8))
            precondition(oldStep.action == nil) // Existing U5 plans remain move-only.
            let clickStep = try JSONDecoder().decode(PointerStep.self,from:Data(#"{"action":"click","x":42,"y":24,"seconds":0,"dwell":0.2}"#.utf8))
            precondition(clickStep.action == .click)
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
            print("PASS pointer bounds/profile/duration, move compatibility, click pair/coordinates, failure release, no I/O between down and up, termination release; no permission query or event posted");return
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
        catch { try append(["event":"pointer-result","outcome":"not-run","reason":"scope-lease-or-subject-ended"],to:out);throw error }
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
