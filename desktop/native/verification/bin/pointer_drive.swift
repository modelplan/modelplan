// SPDX-License-Identifier: MIT
// Build only for synthetic verification: swiftc -parse-as-library
// -DMODELPLAN_TEST_ONLY_SPI pointer_drive.swift -o <owned-build>/pointer_drive
#if MODELPLAN_TEST_ONLY_SPI
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Darwin

struct PointerStep: Decodable { let x: Double; let y: Double; let seconds: Double; let dwell: Double }
struct PointerPlan: Decodable {
    let profile: String, runID: String, epoch: String, lease: String, stop: String, output: String
    let subjectPID: Int32, subjectBundle: String
    let allowedRectangles: [[Double]]
    let steps: [PointerStep]
}
enum DriveError: Error { case invalidPlan, outsideScope, staleLease, subjectEnded, cannotCreateEvent }

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
              p.steps.reduce(0,{$0+$1.seconds+$1.dwell})<=1200 else { throw DriveError.invalidPlan }
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
                try append(["event":"mouse-moved-posted","runID":p.runID,"epoch":p.epoch,"subjectPID":p.subjectPID,
                    "step":index,"x":point.x,"y":point.y,"uptimeSeconds":ProcessInfo.processInfo.systemUptime,
                    "timestamp":ISO8601DateFormatter().string(from:Date()),"tap":"kCGHIDEventTap"],to:file)
                if step.seconds>0 { Thread.sleep(forTimeInterval:step.seconds/Double(count)) }
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
            func fixture(_ profile: String = "synthetic", _ seconds: Double = 1) -> PointerPlan {
                PointerPlan(profile:profile,runID:"fixture",epoch:"epoch",lease:"unused",stop:"unused",output:"unused",subjectPID:1,subjectBundle:"/unused.app",allowedRectangles:[[0,0,100,100]],steps:[.init(x:10,y:10,seconds:seconds,dwell:0.2)])
            }
            try validate(fixture())
            precondition(pointAllowed(CGPoint(x:10,y:10),fixture()))
            precondition(!pointAllowed(CGPoint(x:101,y:10),fixture()))
            for bad in [fixture("owner"),fixture("synthetic",-1),fixture("synthetic",Double.infinity),fixture("synthetic",1201)] {
                do { try validate(bad); preconditionFailure("invalid plan admitted") } catch DriveError.invalidPlan { }
            }
            print("PASS pointer plan bounds/profile/duration; no permission query or event posted");return
        }
        if args.count == 2 && args[1] == "--check" {
            let data = try JSONSerialization.data(withJSONObject:permission(),options:[.sortedKeys]);print(String(decoding:data,as:UTF8.self));return
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
        do { try entry() }
        catch { print("{\"event\":\"pointer-error\",\"outcome\":\"not-run\",\"reason\":\"invalid-or-ended-verification-contract\"}");exit(1) }
    }
}
#else
#error("pointer_drive is test-only; compile with MODELPLAN_TEST_ONLY_SPI")
#endif
