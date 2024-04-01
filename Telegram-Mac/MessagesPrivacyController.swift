//
//  MessagesPrivacyController.swift
//  Telegram
//
//  Created by Mike Renoir on 09.01.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private final class Arguments {
    let context: AccountContext
    let alert:()->Void
    let premium:()->Void
    let toggle:(Bool)->Void
    init(context: AccountContext, alert:@escaping()->Void, premium:@escaping()->Void, toggle:@escaping(Bool)->Void) {
        self.context = context
        self.premium = premium
        self.alert = alert
        self.toggle = toggle
    }
}

private struct State : Equatable {
    var globalSettings: GlobalPrivacySettings
    var isPremium: Bool
}

private let _id_everyone = InputDataIdentifier("_id_everyone")
private let _id_contacts = InputDataIdentifier("_id_contacts")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().privacySettingsMessagesHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_everyone, data: .init(name: strings().privacySettingsMessagesEveryone, color: theme.colors.text, type: .selectable(!state.globalSettings.nonContactChatsRequirePremium), viewType: .firstItem, action: {
        arguments.toggle(false)
    })))
    
    let new_noncontact_peers_require_premium_without_ownpremium = arguments.context.appConfiguration.getBoolValue("new_noncontact_peers_require_premium_without_ownpremium", orElse: false)
    
    let isAvailable = state.isPremium || new_noncontact_peers_require_premium_without_ownpremium
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_contacts, data: .init(name: strings().privacySettingsMessagesContacts, color: theme.colors.text, type: state.globalSettings.nonContactChatsRequirePremium ? .selectable(true) : isAvailable ? .selectable(false) : .image(theme.icons.premium_lock_gray), viewType: .lastItem, action: {
        if isAvailable {
            arguments.toggle(true)
        } else {
            arguments.alert()
        }
    })))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().privacySettingsMessagesInfo, linkHandler: { _ in
        arguments.premium()
    }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    // entries
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func MessagesPrivacyController(context: AccountContext, globalSettings: GlobalPrivacySettings, updated:@escaping(GlobalPrivacySettings)->Void) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(globalSettings: globalSettings, isPremium: context.isPremium)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, alert: {
        if !context.isPremium {
            showModalText(for: context.window, text: strings().privacySettingsMessagesPremiumError, button: strings().alertLearnMore, callback: { _ in
                showModal(with: PremiumBoardingController(context: context, source: .message_privacy, openFeatures: true), for: context.window)
            })
            return
        }
    }, premium: {
        showModal(with: PremiumBoardingController(context: context, source: .message_privacy, openFeatures: true), for: context.window)
    }, toggle: { value in
        updateState { current in
            var current = current
            current.globalSettings.nonContactChatsRequirePremium = value
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().privacySettingsMessages, hasDone: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.afterDisappear = {
        updated(stateValue.with { $0.globalSettings })
        _ = context.engine.privacy.updateGlobalPrivacySettings(settings: stateValue.with { $0.globalSettings }).start()
    }

    return controller
    
}
