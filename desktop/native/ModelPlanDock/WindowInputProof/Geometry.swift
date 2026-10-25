// SPDX-License-Identifier: MIT
import AppKit

// Neutral proof geometry only. No frozen dock outline or official art is defined here.
enum ProofEdge: String, CaseIterable { case left, right, top, bottom }
struct ProofDisplay: Equatable {
    let id: String
    let frame: CGRect
    let visible: CGRect
    let safeTop: CGFloat
    let scale: CGFloat
    var usable: CGRect {
        // Intersection, not subtraction: the menu bar may already exclude the camera housing.
        CGRect(x:frame.minX,y:frame.minY,width:frame.width,height:max(0,frame.height-max(0,safeTop))).intersection(visible)
    }
}
struct ProofPlacement {
    static func choose(preferred: String?, displays: [ProofDisplay], pointer: CGPoint, primary: String?) -> ProofDisplay? {
        let usable = displays.filter { !$0.usable.isEmpty }.sorted { $0.id < $1.id }
        if let preferred, usable.filter({$0.id == preferred}).count == 1 { return usable.first {$0.id == preferred} }
        return usable.first {$0.usable.contains(pointer)} ?? usable.first {$0.id == primary} ?? usable.first
    }
    static func cells(display: ProofDisplay, edge: ProofEdge, count: Int, side: CGFloat = 48, gap: CGFloat = 14) -> [CGRect] {
        let u = display.usable
        let vertical = edge == .left || edge == .right
        let length = vertical ? u.height : u.width
        let n = max(1, min(count, Int(max(1, (length + gap) / (side + gap)))))
        let total = CGFloat(n) * side + CGFloat(n - 1) * gap
        return (0..<n).map { i in
            let along = (length-total)/2 + CGFloat(i)*(side+gap)
            switch edge {
            case .left: return CGRect(x: u.minX, y: u.minY+along, width: side, height: side)
            case .right: return CGRect(x: u.maxX-side, y: u.minY+along, width: side, height: side)
            case .top: return CGRect(x: u.minX+along, y: u.maxY-side, width: side, height: side)
            case .bottom: return CGRect(x: u.minX+along, y: u.minY, width: side, height: side)
            }
        }
    }
    static func screenPoint(local: CGPoint, frame: CGRect, rootScale: CGFloat, flipped: Bool) -> CGPoint {
        CGPoint(x: frame.minX + local.x * rootScale,
                y: flipped ? frame.maxY - local.y * rootScale : frame.minY + local.y * rootScale)
    }
    static func localPoint(global: CGPoint, frame: CGRect, rootScale: CGFloat, flipped: Bool) -> CGPoint {
        CGPoint(x: (global.x-frame.minX)/rootScale,
                y: flipped ? (frame.maxY-global.y)/rootScale : (global.y-frame.minY)/rootScale)
    }
    static func fit(usable: CGSize, profiles: [CGSize], reserve: CGFloat) -> (Int, CGFloat) {
        precondition(!profiles.isEmpty && usable.width > 0 && usable.height > 0)
        if let i = profiles.firstIndex(where: {$0.width <= usable.width && $0.height+reserve <= usable.height}) { return (i,1) }
        let i = profiles.count-1
        return (i,min(1,min(usable.width/profiles[i].width,usable.height/(profiles[i].height+reserve))))
    }
}

struct ProofHold {
    enum Phase: String { case idle, holding, cancelled }
    static let movementSlack: CGFloat = 6 // Provisional; not the production ignition timing.
    private(set) var phase: Phase = .idle
    private(set) var generation: UInt = 0
    private(set) var commits = 0
    private var origin = CGPoint.zero
    mutating func begin(_ point: CGPoint) { generation &+= 1; origin=point; phase = .holding }
    mutating func move(_ point: CGPoint) {
        if hypot(point.x-origin.x,point.y-origin.y) > Self.movementSlack { cancel() }
    }
    mutating func cancel() { generation &+= 1; phase = .cancelled }
    mutating func finish(token: UInt) {
        if phase == .holding && token == generation { commits += 1; phase = .idle }
    }
}

@MainActor func geometryChecks() throws -> [String] {
    struct Failure: Error { let message: String }
    func check(_ v: Bool,_ s: String) throws { if !v { throw Failure(message:s) } }
    var count=0
    let arrangements = [CGRect(x:0,y:0,width:1440,height:900),CGRect(x:-1920,y:0,width:1920,height:1080),CGRect(x:0,y:900,width:1600,height:900)]
    for (idx,f) in arrangements.enumerated() {
        for density in [CGFloat(1),2] {
            let d=ProofDisplay(id:"fixture-\(idx)",frame:f,visible:CGRect(x:f.minX,y:f.minY+28,width:f.width,height:f.height-60),safeTop:40,scale:density)
            try check(d.usable.maxY == f.maxY-40,"safe area is intersected once")
            for edge in ProofEdge.allCases { for size in [CGFloat(44),52,64] { for n in [1,4,7] {
                for r in ProofPlacement.cells(display:d,edge:edge,count:n,side:size) {
                    try check(d.usable.contains(r),"cell contained in usable area")
                    let p=CGPoint(x:13.25,y:17.75)
                    for flipped in [false,true] {
                        let q=ProofPlacement.screenPoint(local:p,frame:r,rootScale:0.72,flipped:flipped)
                        let back=ProofPlacement.localPoint(global:q,frame:r,rootScale:0.72,flipped:flipped)
                        try check(abs(back.x-p.x)<0.0001 && abs(back.y-p.y)<0.0001,"scaled input round trip")
                    }
                    count += 1
                }
            } } }
        }
    }
    let p0=ProofDisplay(id:"primary",frame:arrangements[0],visible:arrangements[0],safeTop:0,scale:2)
    let p1=ProofDisplay(id:"left",frame:arrangements[1],visible:arrangements[1],safeTop:0,scale:1)
    try check(ProofPlacement.choose(preferred:"missing",displays:[p0,p1],pointer:CGPoint(x:-20,y:20),primary:"primary")?.id == "left","missing display -> pointer")
    try check(ProofPlacement.choose(preferred:"left",displays:[p0,p1],pointer:.zero,primary:"primary")?.id == "left","stable preference wins")
    try check(ProofPlacement.choose(preferred:"left",displays:[p0,p1,p1],pointer:CGPoint(x:10,y:10),primary:"primary")?.id == "primary","ambiguous preference -> usable pointer")
    try check(ProofPlacement.choose(preferred:nil,displays:[],pointer:.zero,primary:nil) == nil,"no screens")
    for height in [CGFloat(600),520] { for locale in ["en","zh-Hans"] { for density in [1,2] {
        // These are fixture silhouettes, not final B00 dimensions. The caller supplies profile order.
        let profiles=[CGSize(width:636,height:890),CGSize(width:636,height:640),CGSize(width:636,height:683)]
        let (i,s)=ProofPlacement.fit(usable:CGSize(width:900,height:height),profiles:profiles,reserve:34)
        try check(i==2 && (profiles[i].height+34)*s <= height+0.0001,"uniform compact containment")
        let r=CGRect(x:-900,y:0,width:636*s,height:683*s)
        let q=ProofPlacement.screenPoint(local:CGPoint(x:300,y:220),frame:r,rootScale:s,flipped:true)
        let b=ProofPlacement.localPoint(global:q,frame:r,rootScale:s,flipped:true)
        try check(abs(b.x-300)<0.001 && abs(b.y-220)<0.001,"compact hit transform \(locale) \(density)")
    } } }
    var hold=ProofHold(); hold.begin(.zero);let old=hold.generation;hold.cancel();hold.finish(token:old)
    try check(hold.commits==0,"old release after cancellation")
    hold.begin(.zero);let t=hold.generation;hold.move(CGPoint(x:ProofHold.movementSlack+1,y:0));hold.finish(token:t)
    try check(hold.commits==0,"drag cancellation")
    hold.begin(.zero);let fresh=hold.generation;hold.finish(token:fresh);hold.finish(token:fresh)
    try check(hold.commits==1,"one release -> one action")
    return ["\(count) edge/size/count/scale geometry cells", "negative and above origins, safe inset intersection", "stable/ambiguous/missing display selection", "en/zh 600/520 uniform fit and hit inverse", "generation-safe hold cancellation and single commit"]
}
