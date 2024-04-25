/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A repository class that handles storing a data model into user defaults.
*/

import OSLog
import AppIntents

@available(macOS 13, *)
public final class AppIntentsData: Sendable {
    public enum RepositoryError: Error, CustomLocalizedStringResourceConvertible {
        case notFound
        
        public var localizedStringResource: LocalizedStringResource {
            switch self {
            case .notFound: return "Element not found"
            }
        }
    }
    
    
    public static let shared = AppIntentsData()

    public static var suiteUserDefaults = UserDefaults(suiteName: "ru.keepcoder.Telegram")!
    
    public func updateAppDataModelStore(_ appDataModel: AppDataModel) {
        let encoder = JSONEncoder()
        do {
            let appDataModelEncoded = try encoder.encode(appDataModel)
            Self.suiteUserDefaults.set(appDataModelEncoded, forKey: "AppData")
            logger.debug("Stored app data model")
        } catch {
            logger.error("Failed to encode app data model \(error.localizedDescription)")
        }
    }

    public var accountsLoggedIn: [AccountEntity] {
        Array(AccountEntity.exampleAccounts.values)
    }
    
    public func accountEntity(identifier: String) throws -> AccountEntity {
        guard let account = AccountEntity.exampleAccounts[identifier] else {
            throw RepositoryError.notFound
        }
        return account
    }
}

@available(macOS 13, *)
public extension AppIntentsData {
    var logger: Logger {
        let subsystem = Bundle.main.bundleIdentifier!
        return Logger(subsystem: subsystem, category: "Repository")
    }
}
