// SPDX-License-Identifier: MIT
// Verification only. No application-wide input monitor or process discovery.
import AppKit
import WebKit
import Darwin
import CoreFoundation

struct WindowObservation: Codable {
    let appActive: Bool
    let keyWindow: Bool
    let windowVisible: Bool
    let occlusionVisible: Bool
    var ready: Bool { appActive && keyWindow && windowVisible && occlusionVisible }
    @MainActor static func capture(_ window: NSWindow) -> WindowObservation {
        WindowObservation(appActive: NSApp.isActive, keyWindow: window.isKeyWindow,
                          windowVisible: window.isVisible,
                          occlusionVisible: window.occlusionState.contains(.visible))
    }
    var fields: [String: Any] {
        ["event":"window-observation", "timestamp":ISO8601DateFormatter().string(from:Date()), "running":true, "appActive":appActive, "keyWindow":keyWindow,
         "windowVisible":windowVisible, "occlusionVisible":occlusionVisible, "ready":ready]
    }
}

struct RAFProgress {
    private var firstTime:Double?, firstFrame:Int?, lastFrame:Int?
    private(set) var failed=false
    private(set) var elapsedSeconds:Double=0
    mutating func observe(frame:Int,now:Double)->String {
        guard !failed,now.isFinite,frame>0 else{return "not-run"}
        if let last=lastFrame,frame<=last {failed=true;return "fail"}
        if let first=firstTime,now<first {failed=true;return "fail"}
        if firstTime==nil {firstTime=now;firstFrame=frame};lastFrame=frame
        elapsedSeconds=now-firstTime!
        return elapsedSeconds>=2 && frame>firstFrame! ? "pass":"not-run"
    }
}

#if MODELPLAN_TEST_ONLY_SPI
@MainActor enum VerificationActivation {
    static func requestKeyWindow(_ window:NSWindow)->[String:Any] {
        window.makeKeyAndOrderFront(nil)
        return ["event":"activation-call","activationCall":"makeKeyAndOrderFront",
                "timestamp":ISO8601DateFormatter().string(from:Date()),"target":"own-window"]
    }
}
// A separate preflight receiver; native elapsed time is authoritative. Teardown
// this view before cold baseline sampling. No page content is logged.
@MainActor final class VerificationFrameHandler: NSObject, WKScriptMessageHandler {
    private let scheme:String, host:String, emit:([String:Any])->Void
    private var proof=RAFProgress()
    init(scheme:String,host:String,emit:@escaping([String:Any])->Void) {
        self.scheme=scheme;self.host=host;self.emit=emit
    }
    func userContentController(_ controller:WKUserContentController,didReceive message:WKScriptMessage) {
        guard !proof.failed,message.frameInfo.isMainFrame,let url=message.frameInfo.request.url,
              url.scheme==scheme,url.host==host,
              let body=message.body as? [String:Any],body.count==1,
              let n=body["frames"] as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite,n.doubleValue>0,n.doubleValue.rounded()==n.doubleValue,
              n.doubleValue<Double(Int.max) else{return}
        let now=Double(DispatchTime.now().uptimeNanoseconds)/1e9
        let outcome=proof.observe(frame:n.intValue,now:now)
        emit(["event":"raf-preflight","nativeElapsedSeconds":proof.elapsedSeconds,"timestamp":ISO8601DateFormatter().string(from:Date()),"frames":n.intValue,"outcome":outcome])
    }
}
#endif

struct WebContentIdentity: Codable, Equatable {
    let pid: Int32
    let startSeconds: UInt64
    let startMicroseconds: UInt64
}

// WKWebView currently has no public PID accessor. This optional verification-only
// SPI is scoped to the supplied view; capability absence is explicitly unsupported.
// Never use this helper in the shipping product or fall back to process-name scans.
@MainActor final class WebContentAttribution {
    let viewID = UUID().uuidString
    private(set) var generation = 0
    private var identity: WebContentIdentity?
    private let allowScopedSPI: Bool
    init(allowScopedSPI: Bool = false) { self.allowScopedSPI = allowScopedSPI }
    func retire() { identity=nil; generation += 1 }
    func capture(_ view: WKWebView) -> [String: Any] {
        var receipt: [String: Any] = ["event":"process-attribution", "role":"WebContent",
            "viewID":viewID, "generation":generation, "source":"owned-WKWebView-scoped-SPI"]
        #if MODELPLAN_TEST_ONLY_SPI
        let selector=NSSelectorFromString("_webProcessIdentifier")
        guard allowScopedSPI, view.responds(to:selector),
              let number=view.value(forKey:"_webProcessIdentifier") as? NSNumber,
              number.int32Value>0 else {
            receipt["status"]="unsupported";receipt["reason"]="scoped-PID-capability-unavailable";return receipt
        }
        let pid=number.int32Value
        var info=proc_bsdinfo()
        let size=Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid,PROC_PIDTBSDINFO,0,&info,size)==size else {
            receipt["status"]="unsupported";receipt["reason"]="target-start-identity-unavailable";return receipt
        }
        let current=WebContentIdentity(pid:pid,startSeconds:info.pbi_start_tvsec,
                                      startMicroseconds:info.pbi_start_tvusec)
        if let old=identity, old != current { retire() }
        identity=current
        receipt["generation"]=generation;receipt["status"]="attributed"
        receipt["pid"]=pid;receipt["startSeconds"]=current.startSeconds
        receipt["startMicroseconds"]=current.startMicroseconds
        return receipt
        #else
        receipt["status"]="unsupported";receipt["reason"]="test-build-flag-disabled"
        return receipt
        #endif
    }
}
