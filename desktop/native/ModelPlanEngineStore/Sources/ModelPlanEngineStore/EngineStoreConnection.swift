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
        self.client = Self.makeClient(configuration: configuration, initialFloor: initialFloor,
                                      credentialAgent: credentialAgent, consumer: store)
    }

    /// Uses the caller's existing awaited event consumer; does not allocate a second store.
    public static func makeClient(configuration: EngineClientConfiguration,
                                  initialFloor: EngineConsentFloor? = nil,
                                  credentialAgent: (any CredentialAgent)? = nil,
                                  consumer: any EngineClientEventConsumer) -> ProcessEngineClient {
        if let credentialAgent {
            return ProcessEngineClient(configuration: configuration, initialFloor: initialFloor,
                                       credentialAgent: credentialAgent, consumer: consumer)
        }
        return CredentialAgentClientFactory.make(configuration: configuration, initialFloor: initialFloor,
                                                 consumer: consumer)
    }
}
