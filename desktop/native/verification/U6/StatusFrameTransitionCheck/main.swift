// SPDX-License-Identifier: MIT
import AppKit

// Exercises the production sampler state machine without constructing an app,
// window, status item, permission query or input event.
@main @MainActor enum StatusFrameTransitionCheck {
    static func main() throws {
        let screen=CGRect(x:0,y:0,width:2560,height:1440)
        func geometry(_ x:CGFloat) -> U6StatusItemFrameSampler.Geometry {
            U6StatusItemFrameSampler.geometry(frame:CGRect(x:x,y:1403,width:60,height:44),
                screen:screen,primaryTop:1440,menuHeight:28,active:true)!
        }
        var result:[String:[[String:Any]]]=[:]
        for change in ["move","hidden","replacement"] {
            var tracker=U6StatusItemFrameSampler.Stability(),rows:[[String:Any]]=[]
            func row(_ value:U6StatusItemFrameSampler.Publication?,_ mono:Double) {
                if let value { rows.append(["event":"status-item-frame","runID":"run","epoch":"epoch",
                    "pid":42,"seq":rows.count+1,"mono":mono,"checks":value.fields]) }
            }
            row(tracker.observe(geometry(1796),windowNumber:7,visible:true,mono:99),99)
            row(tracker.observe(geometry(1796),windowNumber:7,visible:true,mono:100),100)
            let number=change=="replacement" ? 8 : 7,visible=change != "hidden"
            let next=change=="move" ? geometry(1700) : geometry(1796)
            row(tracker.observe(visible ? next : nil,windowNumber:number,visible:visible,mono:100.1),100.1)
            result[change]=rows
            row(tracker.observe(next,windowNumber:number,visible:true,mono:101),101)
            row(tracker.observe(next,windowNumber:number,visible:true,mono:101.6),101.6)
            result[change+"-settled"]=rows
        }
        let data=try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys])
        FileHandle.standardOutput.write(data)
    }
}
