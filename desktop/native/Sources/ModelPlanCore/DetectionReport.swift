// SPDX-License-Identifier: MIT
import Foundation

/// CLI detect schema 1 reports presence only, never sign-in, subscription or consent.
/// Strings remain wire evidence for an allowlisted adapter; they are not UI copy.
public struct DetectionReport: Decodable, Sendable {
    public let schemaVersion: Int
    public let catalogueSource: String?
    public let catalogueRevision: Int?
    public let tools: [DetectedTool]
}

public struct DetectedTool: Decodable, Sendable {
    public let providerId: String
    public let displayName: String?
    public let readerId: String?
    public let preferred: String?
    public let minCli: String?
    public let beta: Bool?
    public let detectionStatus: String?
    public let detected: Bool?
    public let status: String?
}
