
import Foundation
@available(macOS 13, *)
public struct AppIntentDataModel: Codable, Equatable {
    
    static let key: String = "appIntentData"
    static let keyInternal: String = "appIntentData_Internal"

    public init(alwaysUseDarkMode: Bool = false, useUnableStatus: Bool = false) {
        self.alwaysUseDarkMode = alwaysUseDarkMode
        self.useUnableStatus = useUnableStatus
    }
    
    public let alwaysUseDarkMode: Bool
    public let useUnableStatus: Bool

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
