// SPDX-License-Identifier: MIT
import Foundation

public enum HelpUITextRole { case caption, header, contextTitle, contextBody, hintBody, button }

/// Generic geometry only: top-left overlay coordinates, no drawing assets or instrument reflow.
public enum HelpUIGeometry {
    static func valid(_ rect: CGRect) -> Bool {
        [rect.minX,rect.minY,rect.width,rect.height].allSatisfy(\.isFinite) && rect.width > 0 && rect.height > 0
    }
    static func safe(_ size: CGSize) -> CGRect { .init(x: 8, y: 30, width: size.width - 16, height: size.height - 38) }
    static func intersects(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX && a.maxX > b.minX && a.minY < b.maxY && a.maxY > b.minY
    }
    static func free(_ rect: CGRect, from blocked: [CGRect]) -> Bool { !blocked.contains { intersects(rect,$0) } }
    public static func placeCard(anchor: CGRect, size: CGSize, viewport: CGSize, blocked: [CGRect]) -> CGRect? {
        let area = safe(viewport)
        guard valid(anchor), valid(area), size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0, size.width <= area.width, size.height <= area.height,
              blocked.count <= 64, blocked.allSatisfy(valid) else { return nil }
        let gap: CGFloat = 10
        var origins = [CGPoint(x: anchor.minX - size.width - gap,y: anchor.minY),
                       .init(x: anchor.maxX + gap,y: anchor.minY),
                       .init(x: anchor.midX - size.width / 2,y: anchor.minY - size.height - gap),
                       .init(x: anchor.midX - size.width / 2,y: anchor.maxY + gap)]
        for r in blocked {
            origins += [.init(x:r.minX-size.width-gap,y:anchor.minY),.init(x:r.maxX+gap,y:anchor.minY),
                        .init(x:anchor.minX,y:r.minY-size.height-gap),.init(x:anchor.minX,y:r.maxY+gap)]
        }
        return origins.map { origin -> CGRect in
            .init(x: min(max(origin.x,area.minX),area.maxX-size.width),
                  y: min(max(origin.y,area.minY),area.maxY-size.height),width:size.width,height:size.height)
        }.filter { free($0,from:blocked+[anchor]) }.min {
            hypot($0.midX-anchor.midX,$0.midY-anchor.midY) < hypot($1.midX-anchor.midX,$1.midY-anchor.midY)
        }
    }

    /// Rectilinear A* over gutter coordinates. There is no direct-line fallback through a live rectangle.
    public static func leader(from start: CGPoint, to end: CGPoint, avoiding blocks: [CGRect], viewport: CGSize) -> [CGPoint] {
        guard blocks.count <= 96, blocks.allSatisfy(valid),
              [start.x,start.y,end.x,end.y,viewport.width,viewport.height].allSatisfy(\.isFinite),
              viewport.width > 16,viewport.height > 38 else { return [] }
        var xValues:Set<CGFloat> = [start.x,end.x,4,viewport.width-4]
        var yValues:Set<CGFloat> = [start.y,end.y,28,viewport.height-4]
        for block in blocks {
            xValues.insert(block.minX-3);xValues.insert(block.maxX+3)
            yValues.insert(block.minY-3);yValues.insert(block.maxY+3)
        }
        let xs:[CGFloat] = xValues.filter { $0>=4 && $0<=viewport.width-4 }.sorted()
        let ys:[CGFloat] = yValues.filter { $0>=28 && $0<=viewport.height-4 }.sorted()
        guard xs.count * ys.count <= 40_000,let sx=xs.firstIndex(of:start.x),let sy=ys.firstIndex(of:start.y),
              let ex=xs.firstIndex(of:end.x),let ey=ys.firstIndex(of:end.y) else { return [] }
        let count=xs.count, source=sy*count+sx, destination=ey*count+ex
        func point(_ index:Int)->CGPoint { .init(x:xs[index%count],y:ys[index/count]) }
        func validPoint(_ p:CGPoint)->Bool { !blocks.contains { p.x>$0.minX && p.x<$0.maxX && p.y>$0.minY && p.y<$0.maxY } }
        guard validPoint(start),validPoint(end) else { return [] }
        var heap=Heap(),cost=[source:CGFloat.zero],previous=[Int:Int](),closed=Set<Int>(),validity=[Int:Bool]()
        heap.push(source,priority:abs(start.x-end.x)+abs(start.y-end.y))
        while let node=heap.pop() {
            if closed.contains(node) { continue }
            if node==destination { break }; closed.insert(node)
            let x=node%count,y=node/count,p=point(node)
            for (i,j) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] where i>=0 && i<count && j>=0 && j<ys.count {
                let next=j*count+i,q=point(next)
                let allowed=validity[next] ?? validPoint(q); validity[next]=allowed
                guard allowed,!closed.contains(next),segmentIsClear(p,q,blocks:blocks) else { continue }
                let candidate=cost[node]!+abs(p.x-q.x)+abs(p.y-q.y)
                if candidate < (cost[next] ?? .infinity) {
                    cost[next]=candidate;previous[next]=node
                    heap.push(next,priority:candidate+abs(q.x-end.x)+abs(q.y-end.y))
                }
            }
        }
        guard cost[destination] != nil else { return [] }
        var path=[point(destination)],cursor=destination
        while let prior=previous[cursor] { path.append(point(prior));cursor=prior }
        guard cursor==source else { return [] };path.reverse()
        return path.enumerated().compactMap { i,p in
            if i==0 || i==path.count-1 { return p }
            return (path[i-1].x==p.x && p.x==path[i+1].x)||(path[i-1].y==p.y && p.y==path[i+1].y) ? nil:p
        }
    }
    public static func segmentIsClear(_ a:CGPoint,_ b:CGPoint,blocks:[CGRect])->Bool {
        guard a.x==b.x || a.y==b.y else { return false }
        return !blocks.contains { r in
            a.x==b.x ? a.x>r.minX && a.x<r.maxX && max(a.y,b.y)>r.minY && min(a.y,b.y)<r.maxY
                : a.y>r.minY && a.y<r.maxY && max(a.x,b.x)>r.minX && min(a.x,b.x)<r.maxX
        }
    }
    private struct Heap {
        var values:[(Int,CGFloat)]=[]
        mutating func push(_ id:Int,priority:CGFloat) {
            values.append((id,priority));var i=values.count-1
            while i>0 { let p=(i-1)/2;guard values[i].1<values[p].1 else { break };values.swapAt(i,p);i=p }
        }
        mutating func pop()->Int? {
            guard !values.isEmpty else { return nil };let first=values[0].0
            if values.count==1 { values.removeLast();return first }
            let last=values.removeLast();values[0]=last;var i=0
            while 2*i+1<values.count {
                var child=2*i+1
                if child+1<values.count && values[child+1].1<values[child].1 { child+=1 }
                guard values[child].1<values[i].1 else { break };values.swapAt(i,child);i=child
            }
            return first
        }
    }
}
