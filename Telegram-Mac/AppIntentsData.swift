/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A repository class that handles storing a data model into user defaults.
*/

import OSLog
import AppIntents
import ApiCredentials
import SwiftSignalKit
import TelegramCore
import Postbox
import InAppSettings


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
    
}
