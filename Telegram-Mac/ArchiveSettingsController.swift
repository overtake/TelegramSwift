//
//  ArchiveSettingsController.swift
//  Telegram
//
//  Created by Mike Renoir on 22.08.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation

import TelegramCore
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    let toggleKeepUnmuted:()->Void
    let toggleKeepFolders:()->Void
    let toggleNewChats:()->Void
    let showPremium:()->Void
    init(context: AccountContext, toggleKeepUnmuted:@escaping()->Void, toggleKeepFolders:@escaping()->Void, toggleNewChats:@escaping()->Void, showPremium:@escaping()->Void) {
        self.context = context
        self.toggleKeepUnmuted = toggleKeepUnmuted
        self.toggleKeepFolders = toggleKeepFolders
        self.toggleNewChats = toggleNewChats
        self.showPremium = showPremium
    }
}

private struct State : Equatable {
    var settings: GlobalPrivacySettings
    var isPremium: Bool
}

private let _id_always_keep_archived_unmuted = InputDataIdentifier("_id_always_keep_archived_unmuted")
private let _id_always_keep_archived_folders = InputDataIdentifier("_id_always_keep_archived_folders")
private let _id_new_chats = InputDataIdentifier("_id_new_chats")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let privacy = state.settings
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().archiveUnmutedChatsTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
      
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_always_keep_archived_unmuted, data: .init(name: strings().archiveUnmutedChatsText, color: theme.colors.text, type: .switchable(privacy.keepArchivedUnmuted), viewType: .singleItem, action: arguments.toggleKeepUnmuted)))
    index += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().archiveUnmutedChatsDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().archiveFoldersTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_always_keep_archived_folders, data: .init(name: strings().archiveFoldersText, color: theme.colors.text, type: .switchable(privacy.keepArchivedFolders), viewType: .singleItem, action: arguments.toggleKeepFolders)))
    index += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().archiveFoldersDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    let context = arguments.context
    
    let autoarchiveConfiguration = AutoarchiveConfiguration.with(appConfiguration: context.appConfiguration)

    
    if autoarchiveConfiguration.autoarchive_setting_available {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().archiveNewChatsTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
          
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_new_chats, data: .init(name: strings().archiveNewChatsText, color: theme.colors.text, type: .switchable(privacy.automaticallyArchiveAndMuteNonContacts), viewType: .singleItem, enabled: state.isPremium, action: arguments.toggleNewChats, disabledAction: arguments.showPremium)))
          index += 1

          entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().archiveNewChatsDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
          index += 1
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ArchiveSettingsController(context: AccountContext, privacy: GlobalPrivacySettings?, update:@escaping(GlobalPrivacySettings)->Void) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(settings: privacy ?? .init(automaticallyArchiveAndMuteNonContacts: false, keepArchivedUnmuted: false, keepArchivedFolders: false, hideReadTime: false, nonContactChatsRequirePremium: false), isPremium: context.isPremium)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, toggleKeepUnmuted: {
        updateState { current in
            var current = current
            current.settings.keepArchivedUnmuted = !current.settings.keepArchivedUnmuted
            return current
        }
        _ = context.engine.privacy.updateGlobalPrivacySettings(settings: stateValue.with { $0.settings }).start()
        update(stateValue.with { $0.settings })
    }, toggleKeepFolders: {
        updateState { current in
            var current = current
            current.settings.keepArchivedFolders = !current.settings.keepArchivedFolders
            return current
        }
        _ = context.engine.privacy.updateGlobalPrivacySettings(settings: stateValue.with { $0.settings }).start()
        update(stateValue.with { $0.settings })
    }, toggleNewChats: {
        updateState { current in
            var current = current
            current.settings.automaticallyArchiveAndMuteNonContacts = !current.settings.automaticallyArchiveAndMuteNonContacts
            return current
        }
        _ = context.engine.privacy.updateGlobalPrivacySettings(settings: stateValue.with { $0.settings }).start()
        update(stateValue.with { $0.settings })
    }, showPremium: {
        showModalText(for: context.window, text: strings().archiveNewChatsPremium, button: strings().alertLearnMore, callback: { value in
            showModal(with: PremiumBoardingController(context: context, source: .settings), for: context.window)
        })
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    
    actionsDisposable.add(combineLatest(context.engine.privacy.requestAccountPrivacySettings(), getPeerView(peerId: context.peerId, postbox: context.account.postbox)).start(next:{ privacy, peer in
        updateState { current in
            var current = current
            current.settings = privacy.globalSettings
            current.isPremium = peer?.isPremium ?? context.isPremium
            return current
        }
        update(privacy.globalSettings)
    }))
    let controller = InputDataController(dataSignal: signal, title: strings().archiveTitle, hasDone: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
