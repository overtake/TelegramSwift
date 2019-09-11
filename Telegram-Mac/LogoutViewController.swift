//
//  LogoutViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private struct LogoutControllerState : Equatable {
    
}

private final class LogoutControllerArguments  {
    let addAccount: ()->Void
    let setPasscode: ()->Void
    let clearCache: ()->Void
    let changePhoneNumber: ()->Void
    let contactSupport: ()->Void
    let logout: ()->Void
    init(addAccount: @escaping()-> Void, setPasscode: @escaping()->Void, clearCache: @escaping()->Void, changePhoneNumber: @escaping()->Void, contactSupport: @escaping()->Void, logout: @escaping()->Void) {
        self.addAccount = addAccount
        self.setPasscode = setPasscode
        self.clearCache = clearCache
        self.changePhoneNumber = changePhoneNumber
        self.contactSupport = contactSupport
        self.logout = logout
    }
}

private let _id_add_account: InputDataIdentifier = InputDataIdentifier("_id_add_account")
private let _id_set_a_passcode: InputDataIdentifier = InputDataIdentifier("_id_set_a_passcode")
private let _id_clear_cache: InputDataIdentifier = InputDataIdentifier("_id_clear_cache")
private let _id_change_phone_number: InputDataIdentifier = InputDataIdentifier("_id_change_phone_number")
private let _id_contact_support: InputDataIdentifier = InputDataIdentifier("_id_contact_support")

private let _id_log_out: InputDataIdentifier = InputDataIdentifier("_id_log_out")


private func logoutEntries(state: LogoutControllerState, activeAccounts: [AccountWithInfo], arguments: LogoutControllerArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.logoutOptionsAlternativeOptionsSection), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1
    
    if activeAccounts.count < 3 {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_account, data: InputDataGeneralData(name: L10n.logoutOptionsAddAccountTitle, color: theme.colors.text, icon: theme.icons.logoutOptionAddAccount, type: .next, viewType: .firstItem, description: L10n.logoutOptionsAddAccountText, action: arguments.addAccount)))
        index += 1
    }

    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_set_a_passcode, data: InputDataGeneralData(name: L10n.logoutOptionsSetPasscodeTitle, color: theme.colors.text, icon: theme.icons.logoutOptionSetPasscode, type: .next, viewType: .innerItem, description: L10n.logoutOptionsSetPasscodeText, action: arguments.setPasscode)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_clear_cache, data: InputDataGeneralData(name: L10n.logoutOptionsClearCacheTitle, color: theme.colors.text, icon: theme.icons.logoutOptionClearCache, type: .next, viewType: .innerItem, description: L10n.logoutOptionsClearCacheText, action: arguments.clearCache)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_change_phone_number, data: InputDataGeneralData(name: L10n.logoutOptionsChangePhoneNumberTitle, color: theme.colors.text, icon: theme.icons.logoutOptionChangePhoneNumber, type: .next, viewType: .innerItem, description: L10n.logoutOptionsChangePhoneNumberText, action: arguments.changePhoneNumber)))
    index += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_contact_support, data: InputDataGeneralData(name: L10n.logoutOptionsContactSupportTitle, color: theme.colors.text, icon: theme.icons.logoutOptionContactSupport, type: .next, viewType: .lastItem, description: L10n.logoutOptionsContactSupportText, action: arguments.contactSupport)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_log_out, data: InputDataGeneralData(name: L10n.logoutOptionsLogOut, color: theme.colors.redUI, viewType: .singleItem, action: arguments.logout)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.logoutOptionsLogOutInfo), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    
    return entries
}

func LogoutViewController(context: AccountContext, f: @escaping((ViewController)) -> Void) -> InputDataController {
    
    let state: ValuePromise<LogoutControllerState> = ValuePromise(LogoutControllerState())
    let stateValue: Atomic<LogoutControllerState> = Atomic(value: LogoutControllerState())
    
    let updateState:((LogoutControllerState)->LogoutControllerState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    let arguments = LogoutControllerArguments(addAccount: {
        let testingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
        context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
    }, setPasscode: {
        closeAllModals()
        f(PasscodeSettingsViewController(context))
    }, clearCache: {
        closeAllModals()
        f(StorageUsageController(context))
    }, changePhoneNumber: {
        closeAllModals()
        f(PhoneNumberIntroController(context))
    }, contactSupport: {
        confirm(for: mainWindow, information: L10n.accountConfirmAskQuestion, thridTitle: L10n.accountConfirmGoToFaq, successHandler: {  result in
            closeAllModals()
            switch result {
            case .basic:
                _ = showModalProgress(signal: supportPeerId(account: context.account), for: mainWindow).start(next: { peerId in
                    if let peerId = peerId {
                        f(ChatController(context: context, chatLocation: .peer(peerId)))
                    }
                })
            case .thrid:
                openFaq(context: context)
            }
        })
    }, logout: {
        confirm(for: mainWindow, header: L10n.accountConfirmLogout, information: L10n.accountConfirmLogoutText, successHandler: { _ in
            closeAllModals()
            _ = logoutFromAccount(id: context.account.id, accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
        })
    })
    
    let signal = combineLatest(state.get() |> distinctUntilChanged, context.sharedContext.activeAccountsWithInfo |> map {$0.accounts}) |> map { state, activeAccounts in
        return logoutEntries(state: state, activeAccounts: activeAccounts, arguments: arguments)
    }
    
    
    return InputDataController(dataSignal: signal |> map { InputDataSignalValue(entries: $0) }, title: L10n.logoutOptionsTitle, hasDone: false)
}
