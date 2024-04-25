/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An app entity data model that represents a chat account in this app.
*/

import AppIntents

@available(macOS 13, *)
public struct AccountEntity: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "A chat account")
    }
    
    public static var defaultQuery = AccountEntityQuery()
    
    public let id: String
    public let displayName: String
    public let displaySubtitle: String
    public let image: DisplayRepresentation.Image
    
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName) account",
                              subtitle: "\(displaySubtitle)",
                              image: image)
    }
    
    public static var exampleAccounts: [String: AccountEntity] {
        [
            "work-account-identifier":
            AccountEntity(id: "work-account-identifier",
                          displayName: "Work",
                          displaySubtitle: "Team project communications",
                          image: DisplayRepresentation.Image(systemName: "list.bullet.rectangle.portrait.fill")),
            
            "personal-account-identifier":
            AccountEntity(id: "personal-account-identifier",
                          displayName: "Personal",
                          displaySubtitle: "Friends group chat",
                          image: DisplayRepresentation.Image(systemName: "person.fill")),
            
            "gaming-account-identifier":
            AccountEntity(id: "gaming-account-identifier",
                          displayName: "Gaming",
                          displaySubtitle: "Game lobby",
                          image: DisplayRepresentation.Image(systemName: "gamecontroller.fill"))
        ]
    }
}
