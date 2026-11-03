// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient

/// Admission is supplied by the member-refresh producer; the app never derives scopes from display labels.
public enum DockMemberRefreshAdmission: Equatable, Sendable { case ready, deferred, unavailable }

@MainActor public protocol DockMemberRefreshAdapting: AnyObject {
    func admission(for member: EngineAccountMember, delivery: EngineDeliveryContext, now: Date) -> DockMemberRefreshAdmission
    func request(member: EngineAccountMember, delivery: EngineDeliveryContext) async throws
}
