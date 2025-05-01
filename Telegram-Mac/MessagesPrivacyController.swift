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
import CurrencyFormat


private final class Arguments {
    let context: AccountContext
    let alert:()->Void
    let premium:()->Void
    let toggle:(GlobalPrivacySettings.NonContactChatsPrivacy)->Void
    let paidMessagesExceptions:()->Void
    init(context: AccountContext, alert:@escaping()->Void, premium:@escaping()->Void, toggle:@escaping(GlobalPrivacySettings.NonContactChatsPrivacy)->Void, paidMessagesExceptions:@escaping()->Void) {
        self.context = context
        self.premium = premium
        self.alert = alert
        self.toggle = toggle
        self.paidMessagesExceptions = paidMessagesExceptions
    }
}

private struct State : Equatable {
    var globalSettings: GlobalPrivacySettings
    var isPremium: Bool
    var noPaidMessages: SelectivePrivacySettings
}

private let _id_everyone = InputDataIdentifier("_id_everyone")
private let _id_contacts = InputDataIdentifier("_id_contacts")
private let _id_charge = InputDataIdentifier("_id_charge")
private let _id_charge_price = InputDataIdentifier("_id_charge_price")
private let _id_exceptions = InputDataIdentifier("_id_exceptions")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().privacySettingsMessagesHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_everyone, data: .init(name: strings().privacySettingsMessagesEveryone, color: theme.colors.text, type: .selectable(state.globalSettings.nonContactChatsPrivacy == .everybody), viewType: .firstItem, action: {
        arguments.toggle(.everybody)
    })))
    
    let new_noncontact_peers_require_premium_without_ownpremium = arguments.context.appConfiguration.getBoolValue("new_noncontact_peers_require_premium_without_ownpremium", orElse: false)
    
    let isAvailable = state.isPremium || new_noncontact_peers_require_premium_without_ownpremium
    let paidAvailable = arguments.context.appConfiguration.getBoolValue("stars_paid_messages_available", orElse: false)

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_contacts, data: .init(name: strings().privacySettingsMessagesContacts, color: theme.colors.text, type: state.globalSettings.nonContactChatsPrivacy == .requirePremium ? .selectable(true) : isAvailable ? .selectable(false) : .image(theme.icons.premium_lock_gray), viewType: paidAvailable ? .innerItem : .lastItem, action: {
        if isAvailable {
            arguments.toggle(.requirePremium)
        } else {
            arguments.alert()
        }
    })))
        
    let paidMessages: Bool
    switch state.globalSettings.nonContactChatsPrivacy {
    case .paidMessages:
        paidMessages = true
    default:
        paidMessages = false
    }
    
    
    if paidAvailable {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_charge, data: .init(name: strings().messagesPrivacyChargeforMessages, color: theme.colors.text, type: isAvailable ? .selectable(paidMessages) : .image(theme.icons.premium_lock_gray), viewType: .lastItem, action: {
            if isAvailable {
                arguments.toggle(.paidMessages(.init(value: 10, nanos: 0)))
            } else {
                arguments.alert()
            }
        })))
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().messagesPrivacyChargeforMessagesInfo, linkHandler: { _ in
            arguments.premium()
        }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
    }
   
    
    let maximumStars = arguments.context.appConfiguration.getGeneralValue("stars_paid_message_amount_max", orElse: 10000)
    let commission = arguments.context.appConfiguration.getGeneralValue("stars_paid_message_commission_permille", orElse: 850).decemial

    
    switch state.globalSettings.nonContactChatsPrivacy {
    case let .paidMessages(stars):
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().messagesPrivacyChargeforMessagesSelectHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_charge_price, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return PrecieSliderRowItem(initialSize, stableId: stableId, current: Double(stars.value) / (Double(maximumStars) - 1), magnit: [], markers: ["1", "\(maximumStars)"], showValue: strings().starListItemCountCountable(Int(stars.value)), update: { value in
                arguments.toggle(.paidMessages(.init(value: Int64(1 + value * (Double(maximumStars) - 1)), nanos: 0)))
            }, viewType: .singleItem)
            
        }))
        
        let amount = "\(Double(stars.value) * 0.013 * (commission / 100))".prettyCurrencyNumberUsd

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().messagesPrivacyChargeforMessagesSelectInfo("\(commission.string)%", amount)), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().messagesPrivacyChargeforMessagesExceptions), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        
        var enabledFor: [PeerId: SelectivePrivacyPeer] = [:]
        
        switch state.noPaidMessages {
        case let .enableContacts(_enableFor, _, _, _):
            enabledFor = _enableFor
        default:
            break
        }

        let count = countForSelectivePeers(enabledFor)
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_exceptions, data: .init(name: strings().messagesPrivacyChargeforMessagesExceptionsRemoveFee, color: theme.colors.text, type: .nextContext(count > 0 ?  "\(countForSelectivePeers(enabledFor))" : ""), viewType: .singleItem, action: arguments.paidMessagesExceptions)))

        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().messagesPrivacyChargeforMessagesExceptionsInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    default:
        break
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func MessagesPrivacyController(context: AccountContext, noPaidMessages: SelectivePrivacySettings, globalSettings: GlobalPrivacySettings, updated:@escaping(SelectivePrivacySettings, GlobalPrivacySettings)->Void) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(globalSettings: globalSettings, isPremium: context.isPremium, noPaidMessages: noPaidMessages)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, alert: {
        if !context.isPremium {
            showModalText(for: context.window, text: strings().privacySettingsMessagesPremiumError, button: strings().alertLearnMore, callback: { _ in
                prem(with: PremiumBoardingController(context: context, source: .message_privacy, openFeatures: true), for: context.window)
            })
            return
        }
    }, premium: {
        prem(with: PremiumBoardingController(context: context, source: .message_privacy, openFeatures: true), for: context.window)
    }, toggle: { value in
        updateState { current in
            var current = current
            current.globalSettings.nonContactChatsPrivacy = value
            return current
        }
    }, paidMessagesExceptions: {
        
        let state = stateValue.with { $0 }
        
        let initialPeers: [PeerId: SelectivePrivacyPeer]
        switch state.noPaidMessages {
        case let .enableContacts(enableFor, _, _, _):
            initialPeers = enableFor
        default:
            initialPeers = [:]
        }
        
        context.bindings.rootNavigation().push(SelectivePrivacySettingsPeersController(context, title: strings().privacySettingsControllerRemoveFee, initialPeers: initialPeers, premiumUsers: nil, enableForBots: nil, updated: { updatedPeerIds in
            updateState { current in
                var current = current
                current.noPaidMessages = .enableContacts(enableFor: updatedPeerIds, disableFor: [:], enableForPremium: false, enableForBots: false)
                return current
            }
        }))
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().privacySettingsMessages, removeAfterDisappear: false, hasDone: false)
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.afterDisappear = {
        let state = stateValue.with { $0 }
        updated(state.noPaidMessages, state.globalSettings)
        _ = context.engine.privacy.updateGlobalPrivacySettings(settings: stateValue.with { $0.globalSettings }).start()
    }

    return controller
    
}
