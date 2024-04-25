/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A data model to use for sharing information between the app and its App Intents extension.
*/

import Foundation
@available(macOS 13, *)
public struct AppDataModel: Codable {
    public init(alwaysUseDarkMode: Bool = false,
         status: String? = nil,
         selectedAccountID: String? = nil) {
        self.alwaysUseDarkMode = alwaysUseDarkMode
        self.status = status
        self.selectedAccountID = selectedAccountID
    }
    
    public let alwaysUseDarkMode: Bool
    public let status: String?
    public let selectedAccountID: String?
    
    public var isFocusFilterEnabled: Bool {
        alwaysUseDarkMode == true || status != nil || selectedAccountID != nil
    }
}
