// SPDX-License-Identifier: MIT
// Verification only. No application-wide input monitor or process discovery.
import AppKit
import WebKit
import Darwin

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
        ["event":"window-observation", "appActive":appActive, "keyWindow":keyWindow,
         "windowVisible":windowVisible, "occlusionVisible":occlusionVisible, "ready":ready]
    }
}

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
    }
}
