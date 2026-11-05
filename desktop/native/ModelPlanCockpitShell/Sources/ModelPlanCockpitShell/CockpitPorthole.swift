// SPDX-License-Identifier: MIT
import AppKit

public struct CockpitRocketProjection: Equatable, Sendable {
    public struct Point: Equatable, Sendable {
        public let modelID:String, normalized:CGPoint
        public let visible:Bool
        public init(modelID:String,normalized:CGPoint,visible:Bool = true) {
            self.modelID = modelID;self.normalized = normalized;self.visible = visible
        }
    }
    public let captureID:String,stillKey:String,points:[Point]
    public init(captureID:String,stillKey:String,points:[Point]) {
        self.captureID = captureID;self.stillKey = stillKey;self.points = points
    }
}
