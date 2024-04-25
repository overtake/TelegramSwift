//
//  FocusIntents.swift
//  FocusIntents
//
//  Created by Mikhail Filimonov on 25.04.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import AppIntents
import OSLog


@available(macOS 13, *)
struct FocusFilter: SetFocusFilterIntent {
    
    /// Providing a default value ensures setting this required Boolean value.
    @Parameter(title: "Use Dark Mode", default: false)
    var alwaysUseDarkMode: Bool
    
    /// A representation of a chat account this app uses for notification filtering and suppression.
    /// The user receives suggestions from the suggestedEntities() function that AccountEntityQuery declares.
    @Parameter(title: "Selected Account")
    var account: AccountEntity?
    
    @Dependency
    var repository: AppIntentsData
    
    // MARK: - Filter information.
    static var title: LocalizedStringResource = "Set account, status & look"
    
    static var description: IntentDescription? = """
    Select an account, set your status, and configure the look of Example Chat App.
    """
    
    /// The dynamic representation that displays after creating a Focus filter.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(primaryText)")
    }
    
    private var primaryText: String {
        guard let accountName = self.account?.displayName else {
            return "Account: none selected"
        }
        return "Account: \(accountName)"
    }
    
    
    // MARK: - Notification filtering and suppression.
    /// The system suppresses notifications from this app that include a filter criteria field if the
    /// FocusFilterAppContext notificationFilterPredicate evaluates to false.
    var appContext: FocusFilterAppContext {
        logger.debug("App Context Called")
        let predicate: NSPredicate
        // Evaluate the predicate against parameters from this instance.
        if let account = account {
            // If there’s a selected account, suppress notifications that don't have
            // the selected account's identifier in the notification's filter criteria.
            predicate = NSPredicate(format: "SELF IN %@", [account.id])
        } else {
            predicate = NSPredicate(value: true)
        }
        return FocusFilterAppContext(notificationFilterPredicate: predicate)
    }
    
    /// The system uses this to prefill the filter parameters when you choose Settings > Focus > Do Not Disturb (or another Focus)
    /// and then choose Add Filter > Example Chat App.
    static func suggestedFocusFilters(for context: FocusFilterSuggestionContext) async -> [FocusFilter] {
        let workFilter = FocusFilter()
        workFilter.alwaysUseDarkMode = true
        workFilter.account = AccountEntity.exampleAccounts["work-account-identifier"]
        
        return [workFilter]
    }
    
    /// The system calls this function when enabling or disabling Focus.
    func perform() async throws -> some IntentResult {
        logger.debug("Perform called")
        let appDataModel = AppDataModel(alwaysUseDarkMode: self.alwaysUseDarkMode,
                                        selectedAccountID: nil)
        repository.updateAppDataModelStore(appDataModel)
        return .result()
    }
}

extension FocusFilter {
    var logger: Logger {
        let subsystem = Bundle.main.bundleIdentifier!
        return Logger(subsystem: subsystem, category: "ExampleFocusFilter")
    }
}
