//
//  DataStorageExceptions.swift
//  Telegram
//
//  Created by Mike Renoir on 15.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let add:()->Void
    let updateKeepMedia:(PeerId, Int32?)->Void
    let removeAll:()->Void
    init(context: AccountContext, add:@escaping()->Void, updateKeepMedia:@escaping(PeerId, Int32?)->Void, removeAll:@escaping()->Void) {
        self.context = context
        self.updateKeepMedia = updateKeepMedia
        self.add = add
        self.removeAll = removeAll
    }
}

private class AddExceptionCallbackObject : ShareObject {
    private let callback:([PeerId])->Signal<Never, NoError>
    private let exceptions: [StorageCacheException]
    private let category: CacheStorageSettings.PeerStorageCategory
    init(_ context: AccountContext, category: CacheStorageSettings.PeerStorageCategory, exceptions: [StorageCacheException], callback:@escaping([PeerId])->Signal<Never, NoError>) {
        self.callback = callback
        self.category = category
        self.exceptions = exceptions
        super.init(context)
    }
    
    override var hasFolders: Bool {
        return false
    }
    
    
    override func statusString(_ peer: Peer, presence: PeerStatusStringResult?, autoDeletion: Int32?) -> String? {
        return nil
    }
    
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        if exceptions.contains(where: { $0.peer.peer.id == peer.id }) {
            return false
        }
        switch category {
        case .privateChats:
            return peer.isBot || peer.isUser
        case .groups:
            return peer.isGroup || peer.isSupergroup || peer.isGigagroup
        case .channels:
            return peer.isChannel
        case .stories:
            return peer.isUser
        }
    }
    
    override func statusStyle(_ peer: Peer, presence: PeerStatusStringResult?, autoDeletion: Int32?) -> ControlStyle {
        return ControlStyle(font: .normal(.text), foregroundColor: theme.colors.grayText, highlightColor: .white)
    }
    
    override var interactionOk: String {
        return strings().modalDone
    }
    
    override var hasCaptionView: Bool {
        return false
    }
    
    override var multipleSelection: Bool {
        return false
    }
    override var mutableSelection: Bool {
        return false
    }
    override var hasInteraction: Bool {
        return false
    }
    override var selectTopics: Bool {
        return false
    }
    
    override var searchPlaceholderKey: String {
        return "SearchField.Search"
    }
    
    override func perform(to peerIds:[PeerId], threadId: Int64?, comment: ChatTextInputState? = nil, sendPaidMessageStars: [PeerId: StarsAmount] = [:]) -> Signal<Never, String> {
        return callback(peerIds) |> castError(String.self)
    }
}



private struct State : Equatable {
    var settings: CacheStorageSettings
    var category: CacheStorageSettings.PeerStorageCategory
    var exceptions: [StorageCacheException]
    var editing: Bool
}

private let _id_add_exception = InputDataIdentifier("_id_add_exception")
private let _id_remove_all = InputDataIdentifier("_id_remove_all")
private func _id_exception(_ peerId: PeerId) -> InputDataIdentifier {
    return .init("_id_exception_\(peerId.toInt64())")
}

private extension CacheStorageSettings.PeerStorageCategory {
    var titleString: String {
        switch self {
        case .channels:
            return strings().storageExceptionsTitleChannel
        case .groups:
            return strings().storageExceptionsTitleGroup
        case .privateChats:
            return strings().storageExceptionsTitlePrivate
        case .stories:
            return strings().storageExceptionsTitleStories
        }
    }
    var addString: String {
        switch self {
        case .channels:
            return strings().storageExceptionsAddChannel
        case .groups:
            return strings().storageExceptionsAddGroup
        case .privateChats:
            return strings().storageExceptionsAddPrivate
        case .stories:
            return strings().storageExceptionsTitleStories
        }
    }
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let items = filterStorageCacheExceptions(state.exceptions, for: state.category)

    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storageUsageKeepMediaHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_exception, data: .init(name: state.category.addString, color: theme.colors.accent, icon: theme.icons.proxyAddProxy, viewType: items.isEmpty ? .singleItem : .firstItem, action: arguments.add)))
    index += 1
    
    
    if !items.isEmpty {
        
        struct Tuple : Equatable {
            let item: StorageCacheException
            let viewType: GeneralViewType
            let editing: Bool
        }
        
        let array = items
        

        
        for (i, item) in array.enumerated() {
            let viewType: GeneralViewType
            if i == 0 {
                if array.count == 1 {
                    viewType = .lastItem
                } else {
                    viewType = .innerItem
                }
            } else {
                viewType = bestGeneralViewType(array, for: i)
            }
            let tuple: Tuple = .init(item: item, viewType: viewType, editing: state.editing)
            
            
            var menuItems = [ContextMenuItem(strings().timerDaysCountable(1), handler: {
                arguments.updateKeepMedia(item.peer.peer.id, 1 * 24 * 60 * 60)
            }, itemImage: MenuAnimation.menu_autodelete_1d.value),
            ContextMenuItem(strings().timerWeeksCountable(1), handler: {
                arguments.updateKeepMedia(item.peer.peer.id, 7 * 24 * 60 * 60)
            }, itemImage: MenuAnimation.menu_autodelete_1w.value),
            ContextMenuItem(strings().timerMonthsCountable(1), handler: {
                arguments.updateKeepMedia(item.peer.peer.id, 1 * 31 * 24 * 60 * 60)
            }, itemImage: MenuAnimation.menu_autodelete_1m.value),
            ContextMenuItem(strings().timerForever, handler: {
                arguments.updateKeepMedia(item.peer.peer.id, .max)
            }, itemImage: MenuAnimation.menu_forever.value)]
            

            menuItems.append(ContextSeparatorItem())
            
            menuItems.append(ContextMenuItem(strings().storageExceptionsRemove, handler: {
                arguments.updateKeepMedia(item.peer.peer.id, nil)
            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
            
            let interactionType: ShortPeerItemInteractionType
            if tuple.editing {
                interactionType = .deletable(onRemove: { peerId in
                    arguments.updateKeepMedia(item.peer.peer.id, nil)
                }, deletable: true)
            } else {
                interactionType = .plain
            }
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_exception(item.peer.peer.id), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 42, photoSize: NSMakeSize(30, 30), inset: NSEdgeInsets(left: 20, right: 20), interactionType: interactionType, generalType: .nextContext(stringForKeepMediaTimeout(item.value)), viewType: tuple.viewType, contextMenuItems: {
                    return .single(menuItems)
                })
            }))
            index += 1
        }
        index = 1000
    }
    // entries
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    
    if !items.isEmpty {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_remove_all, data: .init(name: strings().storageExceptionsRemoveAll, color: theme.colors.redUI, icon: theme.icons.general_delete, viewType: .singleItem, action: arguments.removeAll)))
        index += 1

    }
    
    return entries
}

func DataStorageExceptions(context: AccountContext, category: CacheStorageSettings.PeerStorageCategory) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(settings: .defaultSettings, category: category, exceptions: [], editing: false)
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let cacheSettingsPromise = Promise<CacheStorageSettings>()
    cacheSettingsPromise.set(context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.cacheStorageSettings])
        |> map { view -> CacheStorageSettings in
            return view.entries[SharedDataKeys.cacheStorageSettings]?.get(CacheStorageSettings.self) ?? CacheStorageSettings.defaultSettings
        })
    
    let accountSpecificCacheSettingsPromise = Promise<AccountSpecificCacheStorageSettings>()
    let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.accountSpecificCacheStorageSettings]))
    accountSpecificCacheSettingsPromise.set(context.account.postbox.combinedView(keys: [viewKey])
    |> map { views -> AccountSpecificCacheStorageSettings in
        let cacheSettings: AccountSpecificCacheStorageSettings
        if let view = views.views[viewKey] as? PreferencesView, let value = view.values[PreferencesKeys.accountSpecificCacheStorageSettings]?.get(AccountSpecificCacheStorageSettings.self) {
            cacheSettings = value
        } else {
            cacheSettings = AccountSpecificCacheStorageSettings.defaultSettings
        }

        return cacheSettings
    })
    
    
    let accountSpecificCacheSettingsAndPeers: Signal<[StorageCacheException], NoError> = accountSpecificCacheSettingsPromise.get() |> mapToSignal { settings in
        return context.account.postbox.transaction { transaction in
            var data: [StorageCacheException] = []
            for value in settings.peerStorageTimeoutExceptions {
                if let peer = transaction.getPeer(value.key) {
                    data.append(.init(value: value.value, peer: PeerEquatable(peer)))
                }
            }
            return data
        }
    }
    
    actionsDisposable.add(combineLatest(accountSpecificCacheSettingsAndPeers, cacheSettingsPromise.get()).start(next: { exceptions, settings in
        updateState { current in
            var current = current
            current.settings = settings
            current.exceptions = exceptions
            return current
        }
    }))

    let arguments = Arguments(context: context, add: {
        showModal(with: ShareModalController(AddExceptionCallbackObject(context, category: category, exceptions: stateValue.with { $0.exceptions }, callback: { peerIds in
            return updateAccountSpecificCacheStorageSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                for peerId in peerIds {
                    let index = settings.peerStorageTimeoutExceptions.firstIndex(where: { $0.key == peerId })
                    if let index = index {
                        settings.peerStorageTimeoutExceptions[index] = .init(key: peerId, value: .max)
                    } else {
                        settings.peerStorageTimeoutExceptions.insert(.init(key: peerId, value: .max), at: 0)
                    }
                }
                return settings
            }) |> deliverOnMainQueue |> ignoreValues
        })), for: context.window)
    }, updateKeepMedia: { peerId, timeout in
        let signal = updateAccountSpecificCacheStorageSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            if let timeout = timeout {
                let index = settings.peerStorageTimeoutExceptions.firstIndex(where: { $0.key == peerId })
                if let index = index {
                    settings.peerStorageTimeoutExceptions[index] = .init(key: peerId, value: timeout)
                }
            } else {
                settings.peerStorageTimeoutExceptions.removeAll(where: { $0.key == peerId})
            }
            return settings
        })
        actionsDisposable.add(signal.start())
    }, removeAll: {
        verifyAlert_button(for: context.window, information: strings().storageExceptionsRemoveAllConfirm, ok: strings().alertYes, successHandler: { _ in
            let exceptions = stateValue.with { $0.exceptions.map { $0.peer.peer.id }}
            let signal = updateAccountSpecificCacheStorageSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.peerStorageTimeoutExceptions.removeAll(where: { exceptions.contains($0.key )})
                return settings
            })
            actionsDisposable.add(signal.start())
        })
        
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: category.titleString, hasDone: true)
//
    controller.updateDoneValue = { data in
        return { f in
            if !stateValue.with({ $0.editing }) {
                f(.enabled(strings().navigationEdit))
            } else {
                f(.enabled(strings().navigationDone))
            }
        }
    }
    controller.validateData = { _ in
        updateState { current in
            var current = current
            current.editing = !current.editing
            return current
        }
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
