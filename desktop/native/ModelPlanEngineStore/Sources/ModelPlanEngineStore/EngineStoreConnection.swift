// SPDX-License-Identifier: MIT
import ModelPlanEngineClient

/// Production construction seam; constructing it launches no process.
/// The real app entry will retain this pair and explicitly start/stop client.
@MainActor public struct EngineStoreConnection {
    public let store: EngineStore
    public let client: ProcessEngineClient

    public init(configuration: EngineClientConfiguration,
                initialFloor: EngineConsentFloor? = nil,
                credentialAgent: (any CredentialAgent)? = nil) {
        let store = EngineStore()
        self.store = store
        self.client = ProcessEngineClient(
            configuration: configuration, initialFloor: initialFloor,
            credentialAgent: credentialAgent, consumer: store
        )
    }
}
