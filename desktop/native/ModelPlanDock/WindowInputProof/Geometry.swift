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

// E00 is isolated to this probe executable; none of these APIs are linked into the product host.
import simd
import RealityKit
import Metal
import Darwin

enum EntranceProbeRoute: String { case quickOnly, isolatedProbe }
struct EntranceProbeCamera {
    let width: Float, height: Float, eye: SIMD3<Float>, near: Float, far: Float
    var matrix: simd_float4x4? {
        guard [width,height,eye.x,eye.y,eye.z,near,far].allSatisfy(\.isFinite), width>0,height>0,near>0,eye.z>near,far>eye.z else { return nil }
        let l=(-width/2-eye.x)*near/eye.z, r=(width/2-eye.x)*near/eye.z
        let b=(-height/2-eye.y)*near/eye.z, t=(height/2-eye.y)*near/eye.z
        return simd_float4x4(columns:(SIMD4(2*near/(r-l),0,0,0),SIMD4(0,2*near/(t-b),0,0),
            SIMD4((r+l)/(r-l),(t+b)/(t-b),far/(near-far),-1),SIMD4(0,0,near*far/(near-far),0)))
    }
    func pagePoint(_ point: SIMD3<Float>) -> SIMD2<Float>? {
        guard let matrix else { return nil }
        let p=matrix*SIMD4(point-eye,1)
        guard p.w.isFinite,p.w>0 else { return nil }
        return SIMD2((p.x/p.w+1)*width/2,(1-p.y/p.w)*height/2)
    }
    static func route(osMajor: Int, experimentRequested: Bool) -> EntranceProbeRoute {
        osMajor>=15 && experimentRequested ? .isolatedProbe : .quickOnly
    }
}
func entranceGeometryChecks() throws -> [String] {
    struct Failure:Error{let message:String}
    func check(_ value:Bool,_ text:String)throws{if !value{throw Failure(message:text)}}
    var points=0
    for eyeY:Float in [-120,0,150] {
        let camera=EntranceProbeCamera(width:640,height:480,eye:SIMD3(30,eyeY,900),near:1,far:2000)
        for x:Float in [-320,0,320] {for y:Float in [-240,0,240] {
            guard let p=camera.pagePoint(SIMD3(x,y,0)) else{throw Failure(message:"invalid projection")}
            try check(abs(p.x-(x+320))<0.001 && abs(p.y-(240-y))<0.001,"Z=0 one-point registration")
            points+=1
        }}
    }
    try check(EntranceProbeCamera.route(osMajor:14,experimentRequested:true) == .quickOnly,"14 cannot unlock")
    try check(EntranceProbeCamera.route(osMajor:26,experimentRequested:false) == .quickOnly,"no implicit scene allocation")
    try check(EntranceProbeCamera.route(osMajor:15,experimentRequested:true) == .isolatedProbe,"15 explicit experiment")
    try check(EntranceProbeCamera(width:0,height:1,eye:SIMD3(0,0,2),near:1,far:3).matrix==nil,"invalid geometry")
    return ["E00 \(points) analytic off-axis plane checks; no rendered-pixel claim", "E00 macOS14 quick-only and explicit15+ isolated-probe policy"]
}

@available(macOS 15.0, *) @MainActor final class EntrancePlaceholderScene {
    let root=Entity(),camera=Entity()
    let renderer: RealityRenderer
    let device: any MTLDevice
    let texture: any MTLTexture
    private let emitter=Entity()
    init() throws {
        struct Missing:Error{}
        guard let device=MTLCreateSystemDefaultDevice() else{throw Missing()}
        self.device=device
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:256,height:256,mipmapped:false)
        descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .private
        guard let texture=device.makeTexture(descriptor:descriptor) else{throw Missing()};self.texture=texture
        renderer=try RealityRenderer()
        let projection=EntranceProbeCamera(width:2,height:2,eye:SIMD3(0.2,0.3,4),near:0.1,far:20)
        camera.position=projection.eye
        camera.components.set(ProjectiveTransformCameraComponent(projectionMatrix:projection.matrix!))
        root.addChild(camera)
        let box=ModelEntity(mesh:.generateBox(size:0.4),materials:[UnlitMaterial(color:.white)])
        root.addChild(box)
        let occluder=ModelEntity(mesh:.generateBox(size:SIMD3(0.25,0.6,0.01)),materials:[OcclusionMaterial(receivesDynamicLighting:false)])
        occluder.position=SIMD3(0.15,0,0.3);root.addChild(occluder)
        var alpha=UnlitMaterial(color:.white);alpha.blending = .transparent(opacity:.init(floatLiteral:0.5))
        let transparent=ModelEntity(mesh:.generateBox(size:0.2),materials:[alpha]);transparent.position=SIMD3(-0.4,0,0.3);root.addChild(transparent)
        var particles=ParticleEmitterComponent();particles.isEmitting=true
        particles.mainEmitter.birthRate=16;particles.mainEmitter.birthRateVariation=0
        particles.mainEmitter.lifeSpan=0.25;particles.mainEmitter.lifeSpanVariation=0
        particles.mainEmitter.blendMode = .additive
        emitter.components.set(particles);root.addChild(emitter)
        renderer.entities.append(root);renderer.activeCamera=camera
        renderer.cameraSettings.isToneMappingEnabled=false
        renderer.cameraSettings.colorBackground = .color(CGColor(gray:0,alpha:0))
    }
    func renderOneFrame() async throws {
        let output=try RealityRenderer.CameraOutput(.singleProjection(colorTexture:texture))
        let completion=EntranceFrameCompletion()
        try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) in
            completion.continuation=continuation
            completion.timeout=Task { @MainActor in
                do{try await Task.sleep(for:.seconds(5))}catch{return}
                completion.finish(.failure(EntranceFrameCompletion.TimedOut()))
            }
            do{try renderer.updateAndRender(deltaTime:1.0/60,cameraOutput:output,onComplete:{_ in Task { @MainActor in completion.finish(.success(())) }})}
            catch{completion.finish(.failure(error))}
        }
    }
    func dispose(){emitter.components.remove(ParticleEmitterComponent.self);renderer.activeCamera=nil;renderer.entities.removeAll();root.children.removeAll()}
}
@MainActor private final class EntranceFrameCompletion {
    struct TimedOut:Error{}
    var continuation:CheckedContinuation<Void,Error>?,timeout:Task<Void,Never>?
    func finish(_ result:Result<Void,Error>){guard let continuation else{return};self.continuation=nil;timeout?.cancel();timeout=nil;continuation.resume(with:result)}
}
struct EntranceProcessSample {
    let at=ProcessInfo.processInfo.systemUptime
    let cpu:Double?,footprint:UInt64?
    init(){
        var time=timespec()
        cpu=clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&time)==0 ? Double(time.tv_sec)+Double(time.tv_nsec)/1e9:nil
        var info=task_vm_info_data_t(),count=mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size/MemoryLayout<integer_t>.size)
        let result=withUnsafeMutablePointer(to:&info){pointer in pointer.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(TASK_VM_INFO),$0,&count)}}
        footprint=result==KERN_SUCCESS ? info.phys_footprint:nil
    }
}
@MainActor func entranceHeadlessProbe(render: Bool) async throws -> [String:Any] {
    let checks=try entranceGeometryChecks(),before=EntranceProcessSample()
    var result:[String:Any]=["schemaVersion":1,"scope":"isolated-offscreen-placeholder-probe","analyticChecks":checks,"windowCount":0,"capture":false,"productEnabled":false,"minimumRuntimeAccepted":false,"pixelParityAccepted":false,"performanceAccepted":false]
    guard #available(macOS 15.0, *),render else{result["route"]="quick-only-or-plan-checks";return result}
    var frames=0
    do{
        let scene=try EntrancePlaceholderScene();defer{scene.dispose()}
        for _ in 0..<4{try await scene.renderOneFrame();frames+=1}
    }
    let after=EntranceProcessSample(),elapsed=after.at-before.at
    result["route"]="isolated-probe";result["completedFrames"]=frames;result["elapsedSeconds"]=elapsed
    if let a=before.cpu,let b=after.cpu{result["processCPUSeconds"]=max(0,b-a)}
    if let a=before.footprint,let b=after.footprint{result["processFootprintBeforeBytes"]=a;result["processFootprintAfterBytes"]=b}
    result["limits"]="Four finite renderer completions only, no GPU/WindowServer/helper accounting, no actual macOS15 receipt, no pixel readback, Metal custom material or frozen particle parity. Process samples are not paired performance acceptance."
    return result
}
