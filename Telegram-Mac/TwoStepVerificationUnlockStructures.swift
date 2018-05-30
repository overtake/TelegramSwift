//
//  TwoStepVerificationUnlockStructures.swift
//  Telegram
//
//  Created by keepcoder on 16/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit


final class TwoStepVerificationUnlockSettingsControllerArguments {
    let updatePasswordText: (String) -> Void
    let openForgotPassword: () -> Void
    let openSetupPassword: () -> Void
    let openDisablePassword: () -> Void
    let openSetupEmail: () -> Void
    let openResetPendingEmail: () -> Void
    
    init(updatePasswordText: @escaping (String) -> Void, openForgotPassword: @escaping () -> Void, openSetupPassword: @escaping () -> Void, openDisablePassword: @escaping () -> Void, openSetupEmail: @escaping () -> Void, openResetPendingEmail: @escaping () -> Void) {
        self.updatePasswordText = updatePasswordText
        self.openForgotPassword = openForgotPassword
        self.openSetupPassword = openSetupPassword
        self.openDisablePassword = openDisablePassword
        self.openSetupEmail = openSetupEmail
        self.openResetPendingEmail = openResetPendingEmail
    }
}

enum TwoStepVerificationUnlockSettingsSection: Int32 {
    case password
}


enum TwoStepVerificationUnlockSettingsEntry: TableItemListNodeEntry {
    case passwordEntry(sectionId: Int32, String, String)
    case passwordEntryInfo(sectionId: Int32, String)
    
    case passwordSetup(sectionId: Int32, String)
    case passwordSetupInfo(sectionId: Int32, String)
    
    case changePassword(sectionId: Int32, String)
    case turnPasswordOff(sectionId: Int32, String)
    case setupRecoveryEmail(sectionId: Int32, String)
    case passwordInfo(sectionId: Int32, String)
    
    case pendingEmailInfo(sectionId: Int32, String)
    case section(Int32)

    
    var stableId: Int32 {
        switch self {
        case .passwordEntry:
            return 0
        case .passwordEntryInfo:
            return 1
        case .passwordSetup:
            return 2
        case .passwordSetupInfo:
            return 3
        case .changePassword:
            return 4
        case .turnPasswordOff:
            return 5
        case .setupRecoveryEmail:
            return 6
        case .passwordInfo:
            return 7
        case .pendingEmailInfo:
            return 8
        case .section(let id):
            return (id + 1) * 1000 - id
        }
    }
    
    static func ==(lhs: TwoStepVerificationUnlockSettingsEntry, rhs: TwoStepVerificationUnlockSettingsEntry) -> Bool {
        switch lhs {
        case let .passwordEntry(lhsSection, lhsText, lhsValue):
            if case let .passwordEntry(rhsSection, rhsText, rhsValue) = rhs, lhsSection == rhsSection, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        case let .passwordEntryInfo(lhsSection, lhsText):
            if case let .passwordEntryInfo(rhsSection, rhsText) = rhs, lhsSection == rhsSection, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .passwordSetupInfo(lhsSection, lhsText):
            if case let .passwordSetupInfo(rhsSection, rhsText) = rhs, lhsSection == rhsSection, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .setupRecoveryEmail(lhsSection, lhsText):
            if case let .setupRecoveryEmail(rhsSection, rhsText) = rhs, lhsSection == rhsSection, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .passwordInfo(lhsSection, lhsText):
            if case let .passwordInfo(rhsSection, rhsText) = rhs, lhsSection == rhsSection, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .pendingEmailInfo(lhsSection, lhsText):
            if case let .pendingEmailInfo(rhsSection, rhsText) = rhs, lhsSection == rhsSection, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .passwordSetup(lhsSection, lhsText):
            if case let .passwordSetup(rhsSection, rhsText) = rhs, lhsSection == rhsSection, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .changePassword(lhsSection, lhsText):
            if case let .changePassword(rhsSection, rhsText) = rhs, lhsSection == rhsSection, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .turnPasswordOff(lhsSection, lhsText):
            if case let .turnPasswordOff(rhsSection, rhsText) = rhs, lhsSection == rhsSection, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .section(section):
            if case .section(section) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var index: Int32 {
        switch self {
        case let .changePassword(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .passwordEntry(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .passwordEntryInfo(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .passwordSetup(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .passwordSetupInfo(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .turnPasswordOff(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .setupRecoveryEmail(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .passwordInfo(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .pendingEmailInfo(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    static func <(lhs: TwoStepVerificationUnlockSettingsEntry, rhs: TwoStepVerificationUnlockSettingsEntry) -> Bool {
        return lhs.index < rhs.index
    }
    

    func item(_ arguments: TwoStepVerificationUnlockSettingsControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .passwordEntry(_, text, value):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: tr(L10n.twoStepAuthEnterPasswordPassword), text: value, limit: INT32_MAX, textChangeHandler: { updatedText in
                arguments.updatePasswordText(updatedText)
            }, inputType: .secure)
        case let .passwordEntryInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .markdown(text, linkHandler: { _ in
                arguments.openForgotPassword()
            }), inset: NSEdgeInsetsMake(5, 28, 5, 28))

        case let .passwordSetup(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .next, action: {
                arguments.openSetupPassword()
            })
        case let .passwordSetupInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .markdown(text, linkHandler: { _ in }), inset: NSEdgeInsetsMake(5, 28, 5, 28))
        case let .changePassword(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .next, action: {
                arguments.openSetupPassword()
            })
        case let .turnPasswordOff(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .next, action: {
                arguments.openDisablePassword()
            })
        case let .setupRecoveryEmail(_, text):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, type: .next, action: {
                arguments.openSetupEmail()
            })
        case let .passwordInfo(_, text):
            return GeneralTextRowItem(initialSize, text: .plain(text), inset: NSEdgeInsetsMake(5, 28, 5, 28))
        case let .pendingEmailInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .markdown(text, linkHandler: {_ in
                arguments.openResetPendingEmail()
            }), inset: NSEdgeInsetsMake(5, 28, 5, 28))
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

struct TwoStepVerificationUnlockSettingsControllerState: Equatable {
    let passwordText: String
    let checking: Bool
    
    init(passwordText: String, checking: Bool) {
        self.passwordText = passwordText
        self.checking = checking
    }
    
    static func ==(lhs: TwoStepVerificationUnlockSettingsControllerState, rhs: TwoStepVerificationUnlockSettingsControllerState) -> Bool {
        if lhs.passwordText != rhs.passwordText {
            return false
        }
        if lhs.checking != rhs.checking {
            return false
        }
        
        return true
    }
    
    func withUpdatedPasswordText(_ passwordText: String) -> TwoStepVerificationUnlockSettingsControllerState {
        return TwoStepVerificationUnlockSettingsControllerState(passwordText: passwordText, checking: self.checking)
    }
    
    func withUpdatedChecking(_ cheking: Bool) -> TwoStepVerificationUnlockSettingsControllerState {
        return TwoStepVerificationUnlockSettingsControllerState(passwordText: self.passwordText, checking: cheking)
    }
}


enum TwoStepVerificationUnlockSettingsControllerMode {
    case access
    case manage(password: String, email: String, pendingEmailPattern: String)
}

enum TwoStepVerificationUnlockSettingsControllerData {
    case access(configuration: TwoStepVerificationConfiguration?)
    case manage(password: String, emailSet: Bool, pendingEmailPattern: String)
}






final class TwoStepVerificationPasswordEntryControllerArguments {
    let updateEntryText: (String) -> Void
    let next: () -> Void
    let skipEmail:() ->Void
    init(updateEntryText: @escaping (String) -> Void, next: @escaping () -> Void, skipEmail:@escaping()->Void) {
        self.updateEntryText = updateEntryText
        self.next = next
        self.skipEmail = skipEmail
    }
}



enum TwoStepVerificationPasswordEntryEntry: TableItemListNodeEntry {
    case passwordEntry(sectionId:Int32, String, String)
    
    case hintEntry(sectionId:Int32, String, String)
    
    case emailEntry(sectionId:Int32, String)
    case emailInfo(sectionId:Int32, String)
    case section(Int32)
    
    var stableId: Int32 {
        switch self {
        case .passwordEntry:
            return 1
        case .hintEntry:
            return 3
        case .emailEntry:
            return 5
        case .emailInfo:
            return 6
        case .section(let id):
            return (id + 1) * 1000 - id
        }
    }
    
    var index: Int32 {
        switch self {
        case let .passwordEntry(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .hintEntry(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .emailEntry(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .emailInfo(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    static func ==(lhs: TwoStepVerificationPasswordEntryEntry, rhs: TwoStepVerificationPasswordEntryEntry) -> Bool {
        switch lhs {
        case let .passwordEntry(sectionId, text, placeholder):
            if case .passwordEntry(sectionId, text, placeholder) = rhs {
                return true
            } else {
                return false
            }
        case let .hintEntry(sectionId, text, placeholder):
            if case .hintEntry(sectionId, text, placeholder) = rhs {
                return true
            } else {
                return false
            }
        case let .emailEntry(lhsSectionId, lhsText):
            if case let .emailEntry(rhsSectionId, rhsText) = rhs, lhsSectionId == rhsSectionId, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .emailInfo(lhsSectionId, lhsText):
            if case let .emailInfo(rhsSectionId, rhsText) = rhs, lhsSectionId == rhsSectionId, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .section(id):
            if case .section(id) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: TwoStepVerificationPasswordEntryEntry, rhs: TwoStepVerificationPasswordEntryEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: TwoStepVerificationPasswordEntryControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .passwordEntry(_, text, placeholder):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: placeholder, text: text, limit: INT32_MAX, textChangeHandler: { updatedText in
                arguments.updateEntryText(updatedText)
            }, inputType: .secure)
        case let .hintEntry(_, text, placeholder):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: placeholder, text: text, limit: 30, textChangeHandler: { updatedText in
                arguments.updateEntryText(updatedText)
            }, inputType: .plain)
        case let .emailEntry(_, text):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: tr(L10n.twoStepAuthEmail), text: text, limit: 40, textChangeHandler: { updatedText in
                arguments.updateEntryText(updatedText)
            }, inputType: .plain)
        case let .emailInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .markdown(text, linkHandler: { _ in
                arguments.skipEmail()
            }), inset: NSEdgeInsetsMake(5, 28, 5, 28))
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

enum PasswordEntryStage: Equatable {
    case entry(text: String)
    case reentry(first: String, text: String)
    case hint(password: String, text: String)
    case email(password: String, hint: String, text: String)
    
    func updateCurrentText(_ text: String) -> PasswordEntryStage {
        switch self {
        case .entry:
            return .entry(text: text)
        case let .reentry(first, _):
            return .reentry(first: first, text: text)
        case let .hint(password, _):
            return .hint(password: password, text: text)
        case let .email(password, hint, _):
            return .email(password: password, hint: hint, text: text)
        }
    }
    
    static func ==(lhs: PasswordEntryStage, rhs: PasswordEntryStage) -> Bool {
        switch lhs {
        case let .entry(text):
            if case .entry(text) = rhs {
                return true
            } else {
                return false
            }
        case let .reentry(first, text):
            if case .reentry(first, text) = rhs {
                return true
            } else {
                return false
            }
        case let .hint(password, text):
            if case .hint(password, text) = rhs {
                return true
            } else {
                return false
            }
        case let .email(password, hint, text):
            if case .email(password, hint, text) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

struct TwoStepVerificationPasswordEntryControllerState: Equatable {
    let stage: PasswordEntryStage
    let updating: Bool
    
    init(stage: PasswordEntryStage, updating: Bool) {
        self.stage = stage
        self.updating = updating
    }
    
    static func ==(lhs: TwoStepVerificationPasswordEntryControllerState, rhs: TwoStepVerificationPasswordEntryControllerState) -> Bool {
        if lhs.stage != rhs.stage {
            return false
        }
        if lhs.updating != rhs.updating {
            return false
        }
        
        return true
    }
    
    func withUpdatedStage(_ stage: PasswordEntryStage) -> TwoStepVerificationPasswordEntryControllerState {
        return TwoStepVerificationPasswordEntryControllerState(stage: stage, updating: self.updating)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> TwoStepVerificationPasswordEntryControllerState {
        return TwoStepVerificationPasswordEntryControllerState(stage: self.stage, updating: updating)
    }
}

func twoStepVerificationPasswordEntryControllerEntries(state: TwoStepVerificationPasswordEntryControllerState, mode: TwoStepVerificationPasswordEntryMode) -> [TwoStepVerificationPasswordEntryEntry] {
    var entries: [TwoStepVerificationPasswordEntryEntry] = []
    
    var sectionId:Int32 = 0
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    switch state.stage {
    case let .entry(text):
        let placeholder:String
        switch mode {
        case .change:
            placeholder = tr(L10n.twoStepAuthSetupPasswordEnterPasswordNew)
        default:
            placeholder = tr(L10n.twoStepAuthSetupPasswordEnterPassword)
        }
        entries.append(.passwordEntry(sectionId: sectionId, text, placeholder))
    case let .reentry(_, text):
        entries.append(.passwordEntry(sectionId: sectionId, text, tr(L10n.twoStepAuthSetupPasswordConfirmPassword)))
    case let .hint(_, text):
        entries.append(.hintEntry(sectionId: sectionId, text, tr(L10n.twoStepAuthSetupHint)))
    case let .email(_, _, text):
        
        var emailText = tr(L10n.twoStepAuthEmailHelp)
        switch mode {
        case .setupEmail:
            break
        default:
            emailText += "\n\n[\(tr(L10n.twoStepAuthEmailSkip))]()"
        }
        entries.append(.emailEntry(sectionId: sectionId, text))
        entries.append(.emailInfo(sectionId: sectionId, emailText))
    }
    
    return entries
}

enum TwoStepVerificationPasswordEntryMode {
    case setup
    case change(current: String)
    case setupEmail(password: String)
}

struct TwoStepVerificationPasswordEntryResult {
    let password: String
    let pendingEmailPattern: String?
}




final class TwoStepVerificationResetControllerArguments {
    let updateEntryText: (String) -> Void
    let next: () -> Void
    let openEmailInaccessible: () -> Void
    
    init(updateEntryText: @escaping (String) -> Void, next: @escaping () -> Void, openEmailInaccessible: @escaping () -> Void) {
        self.updateEntryText = updateEntryText
        self.next = next
        self.openEmailInaccessible = openEmailInaccessible
    }
}

enum TwoStepVerificationResetEntry: TableItemListNodeEntry {
    case codeEntry(sectionId:Int32, String)
    case codeInfo(sectionId:Int32, String)
    case section(Int32)

    var stableId: Int32 {
        switch self {
        case .codeEntry:
            return 0
        case .codeInfo:
            return 1
        case .section(let id):
            return (id + 1) * 1000 - id
        }
    }
    
    static func ==(lhs: TwoStepVerificationResetEntry, rhs: TwoStepVerificationResetEntry) -> Bool {
        switch lhs {
        case let .codeEntry(sectionId, text):
            if case .codeEntry(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case let .codeInfo(sectionId, text):
            if case .codeInfo(sectionId, text) = rhs {
                return true
            } else {
                return false
            }
        case .section(let id):
            if case .section(id) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var index: Int32 {
        switch self {
        case let .codeInfo(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .codeEntry(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    static func <(lhs: TwoStepVerificationResetEntry, rhs: TwoStepVerificationResetEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: TwoStepVerificationResetControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .codeEntry(_, text):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: tr(L10n.twoStepAuthRecoveryCode), text: text, limit: 6, textChangeHandler: { updatedText in
                arguments.updateEntryText(updatedText)
            }, textFilter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})})
        case let .codeInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .markdown(text, linkHandler: { _ in
                arguments.openEmailInaccessible()
            }))
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

struct TwoStepVerificationResetControllerState: Equatable {
    let codeText: String
    let checking: Bool
    
    init(codeText: String, checking: Bool) {
        self.codeText = codeText
        self.checking = checking
    }
    
    static func ==(lhs: TwoStepVerificationResetControllerState, rhs: TwoStepVerificationResetControllerState) -> Bool {
        if lhs.codeText != rhs.codeText {
            return false
        }
        if lhs.checking != rhs.checking {
            return false
        }
        
        return true
    }
    
    func withUpdatedCodeText(_ codeText: String) -> TwoStepVerificationResetControllerState {
        return TwoStepVerificationResetControllerState(codeText: codeText, checking: self.checking)
    }
    
    func withUpdatedChecking(_ checking: Bool) -> TwoStepVerificationResetControllerState {
        return TwoStepVerificationResetControllerState(codeText: self.codeText, checking: checking)
    }
}
