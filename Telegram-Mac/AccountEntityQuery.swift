/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An entity query that Focus filters or Shortcuts use to suggest or find entity objects.
*/

import AppIntents

@available(macOS 13, *)
public struct AccountEntityQuery: EntityQuery {
    public func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        AppIntentsData.shared.accountsLoggedIn.filter {
            identifiers.contains($0.id)
        }
    }
    
    public init() {
        
    }
    
    public func suggestedEntities() async throws -> [AccountEntity] {
        AppIntentsData.shared.accountsLoggedIn
    }
}
