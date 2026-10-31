// SPDX-License-Identifier: MIT
import ModelPlanEngineClient
import ModelPlanCredentialAgent

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
        if let credentialAgent {
            self.client = ProcessEngineClient(
                configuration: configuration, initialFloor: initialFloor,
                credentialAgent: credentialAgent, consumer: store
            )
        } else {
            self.client = CredentialAgentClientFactory.make(
                configuration: configuration, initialFloor: initialFloor, consumer: store
            )
        }
    }
}
