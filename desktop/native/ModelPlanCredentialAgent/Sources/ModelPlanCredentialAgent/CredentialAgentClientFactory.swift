// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

private struct R2DeniedCredentialAgent: CredentialAgent {
    let isCurrent: @Sendable (EngineDeliveryContext) -> Bool
    func handle(_ operation: EngineCredentialOperation) async -> WireCredentialResult {
        let outcome: WireCredentialOutcome
        if Task.isCancelled || !isCurrent(operation.delivery) { outcome = .canceled }
        else if ContinuousClock.now >= operation.deadline { outcome = .timeout }
        else { outcome = .denied }
        return try! .init(operationId: operation.request.operationId, outcome: outcome)
    }
}

/// Constructor seam for the U6 owner: the same ProcessEngineClient supplies the
/// current-context veto and consumes the resulting credential denial. No start(),
/// polling, additional reader, consumer or strong client/agent cycle is introduced.
public enum CredentialAgentClientFactory {
    public static func make(configuration: EngineClientConfiguration,
                            initialFloor: EngineConsentFloor? = nil,
                            consumer: any EngineClientEventConsumer,
                            bundle: Bundle = .main) -> ProcessEngineClient {
        let authority = CredentialAgentAuthority()
        let fence: @Sendable (EngineDeliveryContext) -> Bool = { authority.isCurrent($0) }
        let agent: any CredentialAgent = FixedHelperCredentialAgent.bundled(in: bundle, isCurrent: fence)
            ?? R2DeniedCredentialAgent(isCurrent: fence)
        let client = ProcessEngineClient(configuration: configuration, initialFloor: initialFloor,
                                        credentialAgent: agent, consumer: consumer)
        authority.bind(client)
        return client
    }
}
