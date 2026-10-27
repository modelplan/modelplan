// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanInstruments

/// Neutral catalogue-only map. Actual source controls are present only when a free block fits.
/// The complete frozen cockpit/Dock map remains the owning host's separate integration.
enum CommunityOptionHelpLayout {
    static func map(viewport: CGSize, readings: [CGRect], sourceTitle: String, dataTitle: String,
                    about: String, data: String) -> HelpUIMapInput {
        var map=HelpUIMapInput(mode:.heldOption,regionAnchors:[.screen:"community.main-screen"])
        let width=min(520,viewport.width-24),height:CGFloat=176
        guard width>0,viewport.height>=height+24 else { return map }
        let xs=[CGFloat(12),(viewport.width-width)/2,viewport.width-width-12]
        for y in stride(from:viewport.height-height-12,through:CGFloat(12),by:-12) {
            for x in xs {
                let block=CGRect(x:x,y:y,width:width,height:height)
                guard !readings.contains(where:{$0.intersects(block)}) else { continue }
                map.header=CGRect(x:x,y:y,width:width,height:58)
                map.columns=[CGRect(x:x,y:y+66,width:width,height:70)]
                map.sourceActionID=about;map.sourceActionTitle=sourceTitle
                map.sourceFrame=CGRect(x:x,y:y+144,width:width/2-4,height:28)
                map.secondarySourceActionID=data;map.secondarySourceActionTitle=dataTitle
                map.secondarySourceFrame=CGRect(x:x+width/2+4,y:y+144,width:width/2-4,height:28)
                return map
            }
        }
        return map // No label/source frame is published; the shared layout remains fail closed.
    }
}
