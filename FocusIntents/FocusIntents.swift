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


@available(macOS 13, *)
struct FocusFilter: SetFocusFilterIntent {
    
    @Parameter(title: "Use Dark Mode", description: "Automatically enable dark mode.", default: false)
    var alwaysUseDarkMode: Bool
    
    @Parameter(title: "Set Unable Status", description: "Set your account status to Unable. This feature requires Telegram Premium.", default: false)
    var unableStatus: Bool

    
    static var title: LocalizedStringResource = "Set Appearance And Status"
    
    static var description: LocalizedStringResource? = """
    Configure Appearance of app in focus mode
    """
    
    var displayRepresentation: DisplayRepresentation {
        var status: String = ""
        if alwaysUseDarkMode {
            status += "Dark Mode"
        }
        if unableStatus {
            if status.isEmpty {
                status += "Status"
            } else {
                status += ", Status"
            }
        }
        return DisplayRepresentation(title: "Appearance And Status",
                                     subtitle: LocalizedStringResource(stringLiteral: status))
    }
    

    var appContext: FocusFilterAppContext {
        return FocusFilterAppContext(notificationFilterPredicate: nil)
    }
    
    static func suggestedFocusFilters(for context: FocusFilterSuggestionContext) async -> [FocusFilter] {
        let workFilter = FocusFilter()
        workFilter.alwaysUseDarkMode = true
        workFilter.unableStatus = true
        return [workFilter]
    }
    
    func perform() async throws -> some IntentResult {
        let model = AppIntentDataModel(alwaysUseDarkMode: self.alwaysUseDarkMode, useUnableStatus: self.unableStatus)
        if let model = model.encoded() {
            UserDefaults(suiteName: ApiEnvironment.intentsBundleId)?.set(model, forKey: AppIntentDataModel.key)
        }
        return .result()
    }
}
