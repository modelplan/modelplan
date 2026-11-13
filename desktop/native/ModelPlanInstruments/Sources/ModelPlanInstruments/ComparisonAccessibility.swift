// SPDX-License-Identifier: MIT
import Foundation

extension ComparisonPresentation {
    /// Reuses plotted traces, gaps and published order. No ranking, interpolation or extra Fast data.
    public func accessibilityDetails(for chart:ComparisonChartGeometry)->[MainScreenAccessibilityDetail] {
        guard let axis=chartAxis,chart.axis==axis,chart.effortKeys==efforts.map(\.key),chart.traces.allSatisfy({$0.points.count==efforts.count}) else {return []}
        let zh=language == .chinese
        var result:[MainScreenAccessibilityDetail]=[
            .init(id:"effortOrder",label:zh ? "发布档位顺序":"Published effort order",value:efforts.map(\.title).joined(separator:" → ")),
            .init(id:"traceMeaning",label:zh ? "曲线含义":"Trace meanings",value:zh
                  ? "能力：亮实线；成本：中等亮度实线；耗时：点线。快速配置以虚线叠加成本和耗时。"
                  : "Ability: bright solid; cost: medium solid; time: dotted. Fast adds dashed cost and time overlays.")
        ]
        for column in columns where !column.unlit {
            let key:String,shape:String
            switch column.role {
            case .current:key="current";shape=zh ? "白色实线标记":"white solid marker"
            case .recommended:key="recommended";shape=zh ? "金色 ★ 点线标记":"gold ★ dotted marker"
            case .trial:key="trial";shape=zh ? "蓝色虚线标记，只是本地比较":"blue dashed marker, local comparison only"
            }
            let speed=column.configuration?.fast == true ? (zh ? "快速 ⚡":"Fast ⚡"):(zh ? "标准":"Standard")
            result.append(.init(id:"marker."+key,label:column.title,value:[column.effort,speed,shape,column.equality].compactMap{$0}.joined(separator:" · ")))
        }
        for trace in chart.traces {
            let speed=trace.fast ? (zh ? "快速":"Fast"):(zh ? "标准":"Standard")
            let id="trace."+(trace.fast ? "fast.":"standard.")+String(describing:trace.metric)
            let endpoint=trace.points.enumerated().compactMap { index,point -> String? in
                guard let point else {return nil}
                return efforts[index].title+" · "+Self.multiple(point.ratio)
            }.last ?? (zh ? "无可绘制端点":"No plotted endpoint")
            result.append(.init(id:id,label:speed+" · "+trace.metric.title(language),value:(zh ? "最后一个可绘制端点：":"Last plotted endpoint: ")+endpoint))
            for (index,effort) in efforts.enumerated() {
                let value=trace.points[index].map{Self.multiple($0.ratio)} ?? (zh ? "不可用，曲线留空":"Unavailable; trace gap")
                result.append(.init(id:id+"."+effort.key,label:effort.title,value:speed+" · "+trace.metric.title(language)+" · "+value))
            }
        }
        return result
    }
}
