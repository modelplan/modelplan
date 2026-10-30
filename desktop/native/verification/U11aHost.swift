// SPDX-License-Identifier: MIT
import AppKit
import WebKit
import Darwin

#if MODELPLAN_TEST_ONLY_SPI
@MainActor final class U11aHost:NSObject,NSApplicationDelegate,WKNavigationDelegate,WKScriptMessageHandler {
    var config:[String:Any]=[:],output:FileHandle!,timer:Timer?,window:NSWindow?,web:WKWebView?
    var attribution:WebContentAttribution?,frameHandler:VerificationFrameHandler?,monitor:Any?
    var phase="before-open",cycle=1,raf=false,subjectReady=false,armed=false,ending=false,busy=false
    var start=DispatchTime.now().uptimeNanoseconds,lastSecond = -1,activation:[String:Any]=[:]
    var root:URL!,leaseURL:URL!,controlURL:URL!,stopURL:URL!,origin:URL!
    var currentCommand=""
    func emit(_ row:[String:Any]) {
        var r=row;r["elapsedSeconds"]=Double(DispatchTime.now().uptimeNanoseconds-start)/1e9
        r["timestampUnix"]=Date().timeIntervalSince1970;r["phase"]=phase;r["cycle"]=cycle
        if let a=attribution {r["viewID"]=a.viewID;r["generation"]=a.generation}
        if let b=try? JSONSerialization.data(withJSONObject:r,options:[.sortedKeys]) {output?.write(b);output?.write(Data([10]))}
    }
    func permitted()->Bool {
        guard let b=try? Data(contentsOf:leaseURL),let l=(try? JSONSerialization.jsonObject(with:b)) as? [String:Any],
            l["runID"] as? String==config["runID"] as? String,l["epoch"] as? String==config["epoch"] as? String,
            l["exclusive"] as? Bool==true,l["ownerPreempted"] as? Bool==false,
            let begin=l["notBefore"] as? Double,let end=l["expiresAt"] as? Double,let beat=l["guardianHeartbeatAt"] as? Double else{return false}
        let now=Date().timeIntervalSince1970
        return begin<=now && now<end && end-begin<=1200 && 0<=now-beat && now-beat<=2
    }
    func applicationDidFinishLaunching(_ n:Notification) {
        guard CommandLine.arguments.count==2,let b=try? Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])),
            let c=(try? JSONSerialization.jsonObject(with:b)) as? [String:Any] else {NSApp.terminate(nil);return}
        config=c
        guard let lease=c["lease"] as? String,let control=c["control"] as? String,let stopPath=c["stop"] as? String,
            let out=c["output"] as? String,let url=c["entryURL"] as? String,let u=URL(string:url),u.scheme=="http",u.host=="127.0.0.1" else {NSApp.terminate(nil);return}
        leaseURL=URL(fileURLWithPath:lease);controlURL=URL(fileURLWithPath:control);stopURL=URL(fileURLWithPath:stopPath);origin=u
        guard permitted() else{NSApp.terminate(nil);return}
        let fd=Darwin.open(out,O_WRONLY|O_CREAT|O_EXCL,S_IRUSR|S_IWUSR);guard fd>=0 else{NSApp.terminate(nil);return}
        output=FileHandle(fileDescriptor:fd,closeOnDealloc:true);start=DispatchTime.now().uptimeNanoseconds
        let masks:NSEvent.EventTypeMask=[.keyDown,.keyUp,.flagsChanged,.leftMouseDown,.rightMouseDown,.otherMouseDown,.scrollWheel,.mouseMoved,.leftMouseDragged,.rightMouseDragged,.otherMouseDragged,.magnify,.rotate,.swipe]
        monitor=NSEvent.addLocalMonitorForEvents(matching:masks){[weak self] event in
            guard let self,!self.ending else{return event}
            if self.window==nil && self.armed {self.stop("app-input");return nil}
            guard let w=self.window,event.window===w || (event.window==nil && w.isKeyWindow) else{return event}
            self.stop("window-input");return nil
        }
        guard monitor != nil else{stop("input-monitor-unavailable");return}
        armed=c["ownerObservationEstablished"] as? Bool ?? false
        if armed {let requested = !NSApp.isActive;if requested {NSApp.activate(ignoringOtherApps:true)};emit(["event":"activation-call","activationCall":requested ? "NSApplication.activate(ignoringOtherApps:true)":"not-invoked-already-active","target":"own-App-cold-baseline"])}
        emit(["event":"host-start","appPID":ProcessInfo.processInfo.processIdentifier,"mode":c["mode"] ?? "measure"])
        timer=Timer.scheduledTimer(withTimeInterval:0.25,repeats:true){[weak self] _ in MainActor.assumeIsolated{self?.step()}}
    }
    func step(){
        guard !ending else{return};guard permitted() else{stop("lease-stop-or-expiry");return}
        if let b=try? Data(contentsOf:controlURL),let c=(try? JSONSerialization.jsonObject(with:b)) as? [String:Any],
            c["runID"] as? String==config["runID"] as? String,c["epoch"] as? String==config["epoch"] as? String,
            let command=c["command"] as? String,let nonce=c["nonce"] as? String,nonce != currentCommand {
            currentCommand=nonce;phase=c["phase"] as? String ?? phase;cycle=c["cycle"] as? Int ?? cycle
            if command=="open" {openView()} else if command=="close" {closeView()} else if command=="quit" {finish();return}
            emit(["event":"command-ack","command":command,"nonce":nonce])
        }
        if window==nil && armed && !NSApp.isActive {stop("doctor-app-inactive");return}
        if let w=window {
            var r=WindowObservation.capture(w).fields;r["activationCall"]=activation["activationCall"] ?? "not-invoked";emit(r)
            if WindowObservation.capture(w).ready {armed=true}
        }
        let second=Int(Double(DispatchTime.now().uptimeNanoseconds-start)/1e9)
        if second != lastSecond {lastSecond=second;sample();observe()}
    }
    func diskOK()->Bool {
        guard let path=config["resourceRoot"] as? String,let attrs=try? FileManager.default.attributesOfFileSystem(forPath:path),let free=attrs[.systemFreeSize] as? NSNumber else{return false}
        let gib:UInt64=1_073_741_824
        let floor:UInt64=8*gib+2*(3*gib+200*1_048_576)
        return free.uint64Value>=floor
    }
    func sample(){
        var usage=rusage();let ru=getrusage(RUSAGE_SELF,&usage)
        var info=mach_task_basic_info();var count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<natural_t>.size)
        let code=withUnsafeMutablePointer(to:&info){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)}}
        var r:[String:Any]=["event":"app-sample","pid":ProcessInfo.processInfo.processIdentifier]
        if ru==0 {r["cpuSeconds"]=Double(usage.ru_utime.tv_sec+usage.ru_stime.tv_sec)+Double(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1e6}
        if code==KERN_SUCCESS {r["rssBytes"]=info.resident_size};emit(r)
    }
    func observe(){
        guard let w=web,!busy else{return};busy=true
        if let a=attribution {emit(a.capture(w))}
        let id=attribution?.viewID
        w.evaluateJavaScript("({activity:window.__u11aObserve?.(),frames:window.__u11aFrameObserver?.snapshot()})"){[weak self] result,error in
            guard let self else{return};self.busy=false
            guard !self.ending,self.attribution?.viewID==id else{return}
            if let result=result as? [String:Any] {
                if let frames=result["frames"] as? [String:Any] {self.emit(frames)}
                if let activity=result["activity"] as? [String:Any] {
                    self.emit(activity)
                    let count=activity["staticPNGCount"] as? Int ?? 0
                    self.subjectReady=activity["phase"] as? String=="open" && count>0 && activity["loadedPNGCount"] as? Int==count
                }
            }
            if self.raf && self.subjectReady,let window=self.window {
                let state=WindowObservation.capture(window)
                let checks:[String:Bool]=["running":true,"active":state.appActive,"key":state.keyWindow,"visible":state.windowVisible,"WebKit":self.attribution != nil,"disk":self.diskOK(),"lease":self.permitted()]
                self.emit(["event":"doctor","checks":checks,"activationCall":self.activation["activationCall"] ?? "not-invoked","rafProof":true,"subjectReady":true])
                if checks.values.contains(false) {self.stop("doctor-failed")}
            } else if error != nil {self.emit(["event":"subject-observation-pending"])}
        }
    }
    func openView(){
        guard web==nil,permitted() else{return};raf=false;subjectReady=false
        attribution=WebContentAttribution(allowScopedSPI:true)
        let c=WKWebViewConfiguration();c.websiteDataStore = .nonPersistent()
        c.userContentController.add(self,name:"u11a")
        let expectedViewID=attribution!.viewID
        frameHandler=VerificationFrameHandler(scheme:"http",host:"127.0.0.1"){[weak self] row in
            guard let self,self.attribution?.viewID==expectedViewID else{return};self.emit(row);if row["outcome"] as? String=="pass" && !self.raf {self.raf=true;self.web?.evaluateJavaScript("window.__u11aStopTicks?.()",completionHandler:nil)}
        }
        c.userContentController.add(frameHandler!,name:"verificationFrames")
        guard let files=config["scripts"] as? [String] else{stop("missing-driver");return}
        var scripts=""
        for path in files {guard let s=try? String(contentsOfFile:path,encoding:.utf8) else{stop("missing-driver");return};scripts+=s+"\n"}
        scripts+="window.__u11aFrameObserver=installVerificationAnimationObserver({indicator:'.lamp,.caution,.fd-leds,.ck-lamp,.ck-eng',session:'.tl,.ck-tape,.dk-mfd,.mfd-session',HUD:'.hud'});window.__u11aStopTicks=installVerificationRAFTicks('verificationFrames');"
        c.userContentController.addUserScript(WKUserScript(source:scripts,injectionTime:.atDocumentEnd,forMainFrameOnly:true))
        let v=WKWebView(frame:NSRect(x:0,y:0,width:1100,height:1000),configuration:c);web=v;v.navigationDelegate=self
        let w=NSWindow(contentRect:v.frame,styleMask:[.titled],backing:.buffered,defer:false);window=w;w.contentView=v;w.title="Synthetic U11a verification";w.acceptsMouseMovedEvents=true
        emit(["event":"open-request"]);v.load(URLRequest(url:origin))
        let requested = !NSApp.isActive
        if requested {NSApp.activate(ignoringOtherApps:true)}
        activation=VerificationActivation.requestKeyWindow(w);activation["activationCall"]=requested ? "NSApplication.activate(ignoringOtherApps:true);makeKeyAndOrderFront":"makeKeyAndOrderFront";emit(activation)
    }
    func closeView(){
        if let a=attribution {a.retire();emit(["event":"process-attribution-retired"])}
        web?.stopLoading();web?.navigationDelegate=nil;web?.configuration.userContentController.removeScriptMessageHandler(forName:"u11a");web?.configuration.userContentController.removeScriptMessageHandler(forName:"verificationFrames")
        window?.contentView=nil;window?.close();web=nil;window=nil;attribution=nil;frameHandler=nil;busy=false
        emit(["event":"view-released"])
    }
    func stop(_ reason:String){
        guard !ending else{return}
        let r:[String:Any]=["stop":true,"reason":reason,"runID":config["runID"] ?? "","epoch":config["epoch"] ?? ""]
        if let b=try? JSONSerialization.data(withJSONObject:r){try? b.write(to:stopURL,options:.withoutOverwriting)}
        emit(["event":"local-stop","reason":reason]);finish()
    }
    func applicationDidResignActive(_ n:Notification){if armed && !ending {stop("app-deactivated")}}
    func finish(){guard !ending else{return};ending=true;timer?.invalidate();if let m=monitor {NSEvent.removeMonitor(m);monitor=nil};closeView();emit(["event":"app-cleanup-complete"]);NSApp.terminate(nil)}
    func applicationWillTerminate(_ n:Notification){timer?.invalidate();try? output?.close()}
    func userContentController(_ c:WKUserContentController,didReceive m:WKScriptMessage){
        guard m.frameInfo.isMainFrame,m.frameInfo.request.url?.host=="127.0.0.1",let r=m.body as? [String:Any],let b=try? JSONSerialization.data(withJSONObject:r),b.count<16384,let event=r["event"] as? String,["activation-configured","activity-observed","activation-error","activation-timeout"].contains(event) else{return};emit(r)
        if r["event"] as? String=="activation-error" || r["event"] as? String=="activation-timeout" {stop("subject-not-ready")}
    }
    func webView(_ v:WKWebView,decidePolicyFor a:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void){decisionHandler(a.request.url?.scheme==origin.scheme && a.request.url?.host==origin.host && a.request.url?.port==origin.port && a.targetFrame?.isMainFrame==true && permitted() ? .allow:.cancel)}
    func webViewWebContentProcessDidTerminate(_ v:WKWebView){attribution?.retire();stop("WebContent-terminated")}
}
@main struct U11aMain {
    @MainActor static func main(){let app=NSApplication.shared;let delegate=U11aHost();app.delegate=delegate;app.setActivationPolicy(.regular);withExtendedLifetime(delegate){app.run()}}
}
#endif
