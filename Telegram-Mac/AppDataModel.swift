/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A data model to use for sharing information between the app and its App Intents extension.
*/

import Foundation
@available(macOS 13, *)
public struct AppDataModel: Codable {
    public init(alwaysUseDarkMode: Bool = false,
         selectedAccountID: String? = nil) {
        self.alwaysUseDarkMode = alwaysUseDarkMode
        self.selectedAccountID = selectedAccountID
    }
    
    public let alwaysUseDarkMode: Bool
    public let selectedAccountID: String?
    
    public var isFocusFilterEnabled: Bool {
        alwaysUseDarkMode == true || selectedAccountID != nil
    }
}
