// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore

// A disposable, synthetic input harness. Never posts/replays an event to another application.
let arguments=CommandLine.arguments
func option(_ name:String)->String? { guard let i=arguments.firstIndex(of:name),i+1<arguments.count else{return nil};return arguments[i+1] }
let receiverMode=arguments.contains("--receiver") || URL(fileURLWithPath:arguments[0]).lastPathComponent == "ModelPlanInputReceiver"
let checksMode=arguments.contains("--checks")
let receiptURL=option("--receipt").map{URL(fileURLWithPath:$0)}
@MainActor final class Receipt {
    var entries=[[String:Any]]()
    let start=ProcessInfo.processInfo.systemUptime
    func add(_ event:String,_ extra:[String:Any]=[:]) {
        var row=extra;row["event"]=event;row["elapsed"]=ProcessInfo.processInfo.systemUptime-start
        entries.append(row);save()
    }
    func save() {
        guard let url=receiptURL else{return}
        let value:[String:Any] = ["schemaVersion":1,"role":receiverMode ? "receiver":"probe","pid":ProcessInfo.processInfo.processIdentifier,"events":entries]
        if let data=try? JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]) {try? data.write(to:url,options:.atomic)}
    }
}
let receipt=MainActor.assumeIsolated { Receipt() }
func rect(_ r:CGRect)->[Double] { [r.minX,r.minY,r.width,r.height].map(Double.init) }

@MainActor class ProofPanel:NSPanel {
    var explicit=false
    override var canBecomeKey:Bool {explicit}
    override var canBecomeMain:Bool {false}
}
@MainActor final class FirstClickButton:NSButton {
    override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
}
@MainActor final class ReceiverView:NSView {
    var clicks=0
    let readout=NSTextField(labelWithString:"No original clicks received yet")
    override init(frame:NSRect) {
        super.init(frame:frame)
        wantsLayer=true;layer?.backgroundColor=NSColor.windowBackgroundColor.cgColor
        readout.frame=CGRect(x:25,y:300,width:650,height:30);addSubview(readout)
        let message=NSTextField(wrappingLabelWithString:"M1 B05b RECEIVER (separate process)\nClick gaps around the small backed panels. Every original mouseDown increments here. No forwarding is installed.")
        message.frame=CGRect(x:25,y:195,width:420,height:90);addSubview(message)
        let editor=NSTextField(frame:CGRect(x:25,y:130,width:380,height:30));editor.placeholderString="Synthetic typing target";editor.identifier=NSUserInterfaceItemIdentifier("receiver-editor")
        editor.setAccessibilityIdentifier("receiver-editor");addSubview(editor)
        let focus=NSTextField(labelWithString:"Type synthetic text, then reveal the dock without clicking. Typing should stay here.")
        focus.frame=CGRect(x:25,y:80,width:650,height:35);addSubview(focus)
        setAccessibilityLabel("Original mouse event receiver")
    }
    required init?(coder:NSCoder){fatalError()}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
    override func mouseDown(with event:NSEvent) {
        clicks+=1;readout.stringValue="Original mouseDown count: \(clicks)"
        receipt.add("originalMouseDown",["count":clicks,"eventNumber":event.eventNumber,"timestamp":event.timestamp,"window":event.windowNumber,"point": [event.locationInWindow.x,event.locationInWindow.y]])
    }
}

@MainActor final class HoldView:NSView {
    var hold=ProofHold();var token:UInt=0
    var action:(()->Void)?
    let label=NSTextField(labelWithString:"HOLD")
    override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.backgroundColor=NSColor.controlAccentColor.cgColor
        label.frame=bounds.insetBy(dx:4,dy:10);label.font = .systemFont(ofSize:11);label.textColor = .white;addSubview(label)
        setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityLabel("Synthetic hold, release once; drag to cancel");setAccessibilityIdentifier("dock-hold")}
    required init?(coder:NSCoder){fatalError()}
    override func hitTest(_ point:NSPoint)->NSView? {bounds.contains(point) ? self:nil}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    override func mouseDown(with event:NSEvent){hold.begin(event.locationInWindow);token=hold.generation;receipt.add("holdBegan",["generation":token,"key":window?.isKeyWindow ?? false,"appActive":NSApp.isActive]);label.stringValue="DOWN"}
    override func mouseDragged(with event:NSEvent){hold.move(event.locationInWindow);if hold.phase == .cancelled {label.stringValue="CANCEL"}}
    override func mouseUp(with event:NSEvent){let before=hold.commits;hold.finish(token:token);label.stringValue="HOLD";receipt.add("holdRelease",["commits":hold.commits,"phase":hold.phase.rawValue]);if before != hold.commits {action?()}}
    override func accessibilityPerformPress()->Bool{action?();return true}
    func cancel(_ reason:String){hold.cancel();label.stringValue="HOLD";receipt.add("holdCancelled",["reason":reason])}
}

@MainActor final class TrialSlider:NSSlider {
    var committed:Double=2
    var star:Double=3
    override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    override func accessibilityValue()->Any? {"current \(Int(committed)), trial \(Int(doubleValue)), recommended \(Int(star)); local only"}
    override func accessibilityPerformIncrement()->Bool{doubleValue=min(maxValue,doubleValue+1);sendAction(action,to:target);return true}
    override func accessibilityPerformDecrement()->Bool{doubleValue=max(minValue,doubleValue-1);sendAction(action,to:target);return true}
    override func keyDown(with event:NSEvent){
        if [123,125].contains(event.keyCode){_ = accessibilityPerformDecrement()}
        else if [124,126].contains(event.keyCode){_ = accessibilityPerformIncrement()}
        else if event.keyCode==53 {doubleValue=committed;sendAction(action,to:target)}
        else{super.keyDown(with:event)}
    }
}

@MainActor final class ProofDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate,NSTextFieldDelegate {
    var dashboard:NSWindow!
    var panels=[ProofPanel]()
    var transient:ProofPanel?
    var settings:NSWindow?
    var holdView:HoldView?
    var outsideMonitor:Any?
    var tokens=[NSObjectProtocol]()
    var priorApp:NSRunningApplication?
    var dockActions=0
    var topology=[ProofDisplay]()
    var sharedSpaces=false
    var label=NSTextField(labelWithString:"Synthetic probe; no accounts, no art, no permissions")
    var trialLabel:NSTextField?
    var chosenEdge=ProofEdge.right

    func displays()->[ProofDisplay] {
        NSScreen.screens.compactMap {s in
            guard let number=s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else{return nil}
            let did=CGDirectDisplayID(number.uint32Value)
            // Mirrored followers must not create duplicate docks.
            guard !CGDisplayIsInMirrorSet(did).boolValue || CGDisplayMirrorsDisplay(did)==kCGNullDirectDisplay else{return nil}
            let stable=CGDisplayCreateUUIDFromDisplayID(did).map{CFUUIDCreateString(nil,$0.takeRetainedValue()) as String} ?? "session-\(did)"
            return ProofDisplay(id:stable,frame:s.frame,visible:s.visibleFrame,safeTop:s.safeAreaInsets.top,scale:s.backingScaleFactor)
        }
    }
    func applicationDidFinishLaunching(_ notification:Notification){
        if checksMode {
            do {let lines=try geometryChecks()+entranceGeometryChecks()+nativeContracts();receipt.add("geometryChecks",["passed":lines]);print(lines.joined(separator:"\n"));NSApp.terminate(nil)}
            catch{fputs("FAIL \(error)\n",stderr);exit(1)}
            return
        }
        let screen=NSScreen.screens.first?.visibleFrame ?? CGRect(x:0,y:0,width:1440,height:900)
        let receiverFrame=CGRect(x:screen.midX-350,y:screen.midY-190,width:700,height:380)
        dashboard=NSWindow(contentRect:receiverMode ? receiverFrame : CGRect(x:screen.minX+40,y:screen.maxY-220,width:700,height:170),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        dashboard.isReleasedWhenClosed=false;dashboard.delegate=self
        dashboard.title=receiverMode ? "M1 Original Input Receiver":"M1 Window Input Proof"
        if receiverMode {dashboard.contentView=ReceiverView(frame:dashboard.contentView!.bounds)}
        else {
            let v=NSView(frame:dashboard.contentView!.bounds);dashboard.contentView=v
            label.frame=CGRect(x:15,y:128,width:675,height:25);v.addSubview(label)
            let buttons:[(String,Selector)]=[("Over receiver",#selector(overReceiver)),("Edge L",#selector(left)),("Edge R",#selector(right)),("Edge T",#selector(top)),("Edge B",#selector(bottom)),("Cockpit / AX",#selector(cockpit)),("Settings / IME",#selector(openSettings)),("Close surfaces",#selector(closeSurfaces)),("Space pref",#selector(toggleSpaces))]
            for (i,p) in buttons.enumerated(){let b=NSButton(title:p.0,target:self,action:p.1);b.frame=CGRect(x:15+CGFloat(i%5)*135,y:77-CGFloat(i/5)*40,width:130,height:30);v.addSubview(b)}
            topology=displays()
            receipt.add("displayInventory",["displays":topology.map{["id":$0.id,"frame":rect($0.frame),"visible":rect($0.visible),"usable":rect($0.usable),"safeTop":Double($0.safeTop),"scale":Double($0.scale)]}])
            observe(NotificationCenter.default,NSApplication.didChangeScreenParametersNotification){[weak self] in self?.screenChange()}
            observe(NSWorkspace.shared.notificationCenter,NSWorkspace.activeSpaceDidChangeNotification){[weak self] in self?.cancelTransient("spaceChanged")}
            observe(NSWorkspace.shared.notificationCenter,NSWorkspace.screensDidSleepNotification){[weak self] in self?.cancelTransient("screensSleep")}
            observe(NSWorkspace.shared.notificationCenter,NSWorkspace.sessionDidResignActiveNotification){[weak self] in self?.cancelTransient("sessionResign")}
            observe(NSWorkspace.shared.notificationCenter,NSWorkspace.didActivateApplicationNotification){[weak self] in
                if !NSApp.isActive {self?.holdView?.cancel("otherAppActivated")}
            }
            outsideMonitor=NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]){[weak self] _ in
                MainActor.assumeIsolated {self?.dismissTransient(restore:false,reason:"outsideOriginalClick")}
            }
            DispatchQueue.main.asyncAfter(deadline:.now()+1){[weak self] in self?.overReceiver()}
        }
        if arguments.contains("--no-activate") {dashboard.orderFront(nil)}
        else{dashboard.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
        receipt.add("started",["frame":rect(dashboard.frame),"minimumTarget":"14.0","noEventReplay":true])
        let duration=min(1800,max(10,Double(option("--seconds") ?? "600") ?? 600))
        DispatchQueue.main.asyncAfter(deadline:.now()+duration){NSApp.terminate(nil)}
        if let auto=option("--auto-reveal-after"),let delay=Double(auto) {DispatchQueue.main.asyncAfter(deadline:.now()+delay){[weak self] in self?.overReceiver();receipt.add("passiveReveal",["appActive":NSApp.isActive,"keyDock":self?.panels.contains{$0.isKeyWindow} ?? false])}}
    }
    func observe(_ center:NotificationCenter,_ name:Notification.Name,_ body:@escaping @MainActor ()->Void){tokens.append(center.addObserver(forName:name,object:nil,queue:.main){_ in MainActor.assumeIsolated{body()}})}
    func nativeContracts() throws->[String] {
        struct Failure:Error{let message:String}
        func check(_ ok:Bool,_ message:String)throws{if !ok{throw Failure(message:message)}}
        let p=makePanel(CGRect(x:20,y:20,width:200,height:180))
        defer{p.close()}
        try check(!p.canBecomeKey && !p.canBecomeMain,"passive panel must never be key/main")
        try check(p.isOpaque && !p.ignoresMouseEvents && p.level == .floating,"fully backed regular input cell")
        try check(!p.collectionBehavior.contains(.canJoinAllSpaces),"all Spaces is opt-in")
        p.explicit=true
        try check(p.canBecomeKey && !p.canBecomeMain,"explicit panel key eligibility only")
        let slider=TrialSlider(frame:CGRect(x:10,y:10,width:160,height:24));slider.minValue=0;slider.maxValue=4;slider.doubleValue=2
        slider.setAccessibilityIdentifier("stable-trial");p.contentView?.addSubview(slider)
        try check(slider.accessibilityIdentifier()=="stable-trial","native slider AX stable ID: \(String(describing:slider.accessibilityIdentifier()))")
        _=slider.accessibilityPerformIncrement()
        try check(slider.doubleValue==3 && slider.committed==2 && slider.star==3,"AX increment changes trial only")
        _=slider.accessibilityPerformDecrement()
        try check(slider.doubleValue==2 && slider.committed==2,"AX decrement leaves current fixed")
        try check(p.makeFirstResponder(slider) && p.firstResponder === slider,"explicit native responder assignment")
        let stable=ObjectIdentifier(slider);slider.setAccessibilityLabel("Updated semantic label")
        try check(stable==ObjectIdentifier(slider) && p.firstResponder === slider,"refresh preserves object and responder")
        let h=HoldView(frame:CGRect(x:0,y:0,width:58,height:48))
        try check(h.hitTest(CGPoint(x:20,y:20)) === h && h.hitTest(CGPoint(x:70,y:20)) == nil,"hold label does not absorb cell input")
        let w=NSWindow(contentRect:CGRect(x:0,y:0,width:200,height:100),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        w.isReleasedWhenClosed=false;defer{w.close()}
        w.orderFront(nil)
        try check(w.canBecomeKey && w.canBecomeMain,"ordinary Settings window eligibility: key=\(w.canBecomeKey),main=\(w.canBecomeMain)")
        let editor=NSTextField(frame:CGRect(x:10,y:10,width:160,height:24));w.contentView?.addSubview(editor)
        try check(w.makeFirstResponder(editor) && w.firstResponder is NSTextView,"native text field uses AppKit field editor")
        return ["native passive/explicit/Settings role and default-Space contracts", "native AX slider current/trial/star and stable responder", "hold-cell backed hit contract and native field editor (not real IME)"]
    }
    func makePanel(_ frame:CGRect)->ProofPanel {
        let p=ProofPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        p.level = .floating;p.hidesOnDeactivate=false;p.isReleasedWhenClosed=false;p.isFloatingPanel=true
        p.isOpaque=true;p.backgroundColor = .windowBackgroundColor;p.hasShadow=false;p.becomesKeyOnlyIfNeeded=true
        p.collectionBehavior=sharedSpaces ? [.canJoinAllSpaces,.fullScreenAuxiliary]:[.moveToActiveSpace]
        return p
    }
    func showCells(_ frames:[CGRect]) {
        holdView?.cancel("reflow");panels.forEach{$0.orderOut(nil);$0.close()};panels=[]
        for (i,frame) in frames.enumerated(){let p=makePanel(frame)
            if i==0 {let h=HoldView(frame:p.contentView!.bounds);h.action={[weak self] in self?.recordAction("hold")};p.contentView=h;holdView=h}
            else {let b=FirstClickButton(title:i==1 ? "Alias":"+N",target:self,action:#selector(dockClick(_:)));b.frame=p.contentView!.bounds;b.setAccessibilityIdentifier("dock-\(i)");b.toolTip="Native backed region; original gaps belong to the other app";p.contentView?.addSubview(b)}
            panels.append(p);p.orderFrontRegardless()
        }
        receipt.add("cellsShown",["frames":frames.map(rect),"allNonkey":panels.allSatisfy{!$0.isKeyWindow && !$0.canBecomeKey && !$0.canBecomeMain},"appActive":NSApp.isActive,"strategy":"separate fully backed rectangular windows; no enclosing transparent window"])
    }
    @objc func overReceiver(){
        let s=NSScreen.screens.first?.visibleFrame ?? CGRect(x:0,y:0,width:1440,height:900)
        let base=CGPoint(x:s.midX+160,y:s.midY-80)
        showCells((0..<3).map{CGRect(x:base.x,y:base.y+CGFloat($0)*70,width:58,height:48)})
    }
    func edge(_ e:ProofEdge){chosenEdge=e;guard let d=ProofPlacement.choose(preferred:nil,displays:displays(),pointer:NSEvent.mouseLocation,primary:displays().first?.id) else{return};showCells(ProofPlacement.cells(display:d,edge:e,count:3))}
    @objc func left(){edge(.left)};@objc func right(){edge(.right)};@objc func top(){edge(.top)};@objc func bottom(){edge(.bottom)}
    @objc func toggleSpaces(){sharedSpaces.toggle();edge(chosenEdge);receipt.add("spacePreference",["allSpaces":sharedSpaces])}
    @objc func dockClick(_ sender:NSButton){recordAction(sender.title)}
    func recordAction(_ source:String){dockActions+=1;label.stringValue="Dock actions: \(dockActions); active \(NSApp.isActive); dock never key";receipt.add("dockAction",["count":dockActions,"source":source,"appActive":NSApp.isActive,"keyDock":panels.contains{$0.isKeyWindow}])}
    @objc func cockpit(){
        dismissTransient(restore:false,reason:"replace")
        priorApp=NSWorkspace.shared.frontmostApplication
        let screen=NSScreen.screens.first!.visibleFrame
        let p=makePanel(CGRect(x:screen.midX-230,y:screen.midY-110,width:460,height:220));p.explicit=true;p.delegate=self
        let v=p.contentView!
        let title=NSTextField(labelWithString:"B05b native calibration (synthetic)");title.frame=CGRect(x:15,y:180,width:430,height:25);v.addSubview(title)
        let sub=FirstClickButton(title:"Subscription fixture",target:self,action:#selector(calibrationAction));sub.frame=CGRect(x:15,y:140,width:170,height:30);sub.setAccessibilityIdentifier("subscription-stable-fixture");sub.toolTip="Synthetic quota; no real subscriptions";v.addSubview(sub)
        let slider=TrialSlider(frame:CGRect(x:15,y:100,width:220,height:25));slider.minValue=0;slider.maxValue=4;slider.doubleValue=2;slider.numberOfTickMarks=5;slider.allowsTickMarkValuesOnly=true;slider.target=self;slider.action=#selector(sliderChanged(_:));slider.setAccessibilityLabel("Effort; current, trial and recommendation");slider.setAccessibilityIdentifier("effort-fixture");v.addSubview(slider)
        let t=NSTextField(labelWithString:"Current 2 · trial 2 · ★ 3 (local only)");t.frame=CGRect(x:15,y:70,width:430,height:25);v.addSubview(t);trialLabel=t
        let alert=FirstClickButton(title:"ALERT",target:self,action:#selector(acknowledge));alert.frame=CGRect(x:255,y:140,width:90,height:30);alert.setAccessibilityLabel("Warning, unacknowledged; press to acknowledge");alert.setAccessibilityIdentifier("alert-fixture");v.addSubview(alert)
        let chart=NSTextField(labelWithString:"Chart text: unknown, zero, twelve tokens");chart.frame=CGRect(x:15,y:35,width:370,height:25);chart.setAccessibilityIdentifier("chart-text-fixture");v.addSubview(chart)
        let close=FirstClickButton(title:"Close",target:self,action:#selector(closeTransient));close.frame=CGRect(x:355,y:140,width:85,height:30);close.keyEquivalent="\u{1b}";v.addSubview(close)
        p.initialFirstResponder=sub;transient=p;NSApp.activate(ignoringOtherApps:true);p.makeKeyAndOrderFront(nil);p.makeFirstResponder(sub)
        receipt.add("cockpitExplicit",["key":p.isKeyWindow,"main":p.isMainWindow,"firstResponder":p.firstResponder === sub,"axIDs":["subscription-stable-fixture","effort-fixture","alert-fixture","chart-text-fixture"]])
    }
    @objc func calibrationAction(){receipt.add("calibrationAction")}
    @objc func sliderChanged(_ sender:TrialSlider){trialLabel?.stringValue="Current 2 · trial \(Int(sender.doubleValue)) · ★ 3 (local only)";receipt.add("trialChanged",["current":2,"trial":sender.doubleValue,"recommended":3])}
    @objc func acknowledge(_ sender:NSButton){sender.setAccessibilityLabel("Warning, acknowledged");receipt.add("alertAcknowledged")}
    @objc func openSettings(){
        if let settings {settings.makeKeyAndOrderFront(nil);return}
        let w=NSWindow(contentRect:CGRect(x:200,y:200,width:440,height:170),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false);w.title="M1 Settings IME Proof";w.isReleasedWhenClosed=false;w.delegate=self
        let editor=NSTextField(frame:CGRect(x:20,y:85,width:390,height:30));editor.placeholderString="Type synthetic 中文 here";editor.delegate=self;editor.setAccessibilityIdentifier("settings-ime");w.contentView?.addSubview(editor)
        let note=NSTextField(wrappingLabelWithString:"Native text field. Only character count and marked-text state are saved. No aliases or account data are read.");note.frame=CGRect(x:20,y:15,width:390,height:60);w.contentView?.addSubview(note)
        settings=w;NSApp.activate(ignoringOtherApps:true);w.makeKeyAndOrderFront(nil);w.makeFirstResponder(editor)
        receipt.add("settingsExplicit",["key":w.isKeyWindow,"main":w.isMainWindow,"editorFocused":w.firstResponder is NSTextView])
    }
    func controlTextDidChange(_ obj:Notification){guard let field=obj.object as? NSTextField else{return};receipt.add("settingsTextChanged",["characterCount":field.stringValue.count,"markedText":(field.currentEditor() as? NSTextView)?.hasMarkedText() ?? false,"containsCJK":field.stringValue.unicodeScalars.contains{$0.value>=0x4e00 && $0.value<=0x9fff}])}
    func screenChange(){let current=displays();if current==topology {receipt.add("benignScreenNotification");return};cancelTransient("displayGeometryOrRemoval");topology=current;edge(chosenEdge);receipt.add("screenReflow",["displayCount":current.count])}
    func cancelTransient(_ reason:String){holdView?.cancel(reason);dismissTransient(restore:false,reason:reason);panels.forEach{$0.orderOut(nil)};receipt.add("lifetimeCancelled",["reason":reason])}
    func dismissTransient(restore:Bool,reason:String){guard let p=transient else{return};p.orderOut(nil);p.close();transient=nil;receipt.add("transientClosed",["reason":reason]);if restore && NSApp.isActive,let priorApp,priorApp.processIdentifier != ProcessInfo.processInfo.processIdentifier{priorApp.activate(options:[])}}
    @objc func closeTransient(){dismissTransient(restore:true,reason:"explicitClose")}
    @objc func closeSurfaces(){cancelTransient("explicitCloseAll")}
    func windowDidResignKey(_ notification:Notification){if notification.object as? NSWindow === transient {holdView?.cancel("keyResigned")}}
    func windowWillClose(_ notification:Notification){if notification.object as? NSWindow === dashboard {NSApp.terminate(nil)};if notification.object as? NSWindow === settings {settings=nil}}
    func applicationWillTerminate(_ notification:Notification){if let outsideMonitor{NSEvent.removeMonitor(outsideMonitor)};tokens.forEach{NotificationCenter.default.removeObserver($0);NSWorkspace.shared.notificationCenter.removeObserver($0)};receipt.add("terminated")}
}
extension boolean_t {var boolValue:Bool{self != 0}}
if arguments.contains("--entrance-plan-checks") || arguments.contains("--entrance-offscreen") {
    Task { @MainActor in
        do{
            let value=try await entranceHeadlessProbe(render:arguments.contains("--entrance-offscreen"))
            let data=try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys])
            if let receiptURL{try data.write(to:receiptURL,options:.atomic)}
            print(String(decoding:data,as:UTF8.self));exit(0)
        }catch{fputs("E00 probe failed: \(error)\n",stderr);exit(1)}
    }
    dispatchMain()
}
MainActor.assumeIsolated {
    let app=NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate=ProofDelegate();app.delegate=delegate;app.run()
}
