/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A data model to use for sharing information between the app and its App Intents extension.
*/

import Foundation
@available(macOS 13, *)
public struct AppIntentDataModel: Codable {
    
    static let key: String = "appIntentData"
    
    public init(alwaysUseDarkMode: Bool? = nil) {
        self.alwaysUseDarkMode = alwaysUseDarkMode
    }
    
    public let alwaysUseDarkMode: Bool?
    
    public var isFocusFilterEnabled: Bool {
        alwaysUseDarkMode == true
    }
    
    func encoded() -> Data? {
        let encoder = JSONEncoder()
        do {
            let appDataModelEncoded = try encoder.encode(self)
            return appDataModelEncoded
        } catch {
            return nil
        }
    }
    
    static func decoded(_ data: Data) -> AppIntentDataModel? {
        let decoder = JSONDecoder()
        guard let appDataModelDecoded = try? decoder.decode(AppIntentDataModel.self, from: data) else {
            return nil
        }
        return appDataModelDecoded
    }
}
