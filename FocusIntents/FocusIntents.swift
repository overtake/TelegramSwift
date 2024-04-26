//
//  FocusIntents.swift
//  FocusIntents
//
//  Created by Mikhail Filimonov on 25.04.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import AppIntents
import OSLog
import TelegramCore
import Postbox
import SwiftSignalKit
import InAppSettings
import ApiCredentials

//private let accountManager: AccountManager<TelegramAccountManagerTypes> = {
//    let containerUrl = ApiEnvironment.containerURL!
//    let rootPath = containerUrl.path
//    return AccountManager<TelegramAccountManagerTypes>(basePath: containerUrl.path + "/accounts-metadata", isTemporary: false, isReadOnly: false, useCaches: true, removeDatabaseOnError: true)
//}()



@available(macOS 13, *)
struct FocusFilter: SetFocusFilterIntent {
    
    @Parameter(title: "Use Dark Mode", default: nil)
    var alwaysUseDarkMode: Bool?
    
    
    // MARK: - Filter information.
    static var title: LocalizedStringResource = "Set Appearance"
    
    static var description: LocalizedStringResource? = """
    Configure Appearance of app in focus mode
    """
    
    /// The dynamic representation that displays after creating a Focus filter.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Appearance",
                              subtitle: "Dark Mode")
    }
    

    var appContext: FocusFilterAppContext {
        return FocusFilterAppContext(notificationFilterPredicate: nil)
    }
    
    static func suggestedFocusFilters(for context: FocusFilterSuggestionContext) async -> [FocusFilter] {
        let workFilter = FocusFilter()
        workFilter.alwaysUseDarkMode = true
        return [workFilter]
    }
    
    func perform() async throws -> some IntentResult {
        let model = AppIntentDataModel(alwaysUseDarkMode: self.alwaysUseDarkMode)
        if let model = model.encoded() {
            UserDefaults(suiteName: ApiEnvironment.intentsBundleId)?.set(model, forKey: AppIntentDataModel.key)
        }
        return .result()
    }
}

extension FocusFilter {

}
