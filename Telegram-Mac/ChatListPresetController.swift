//
//  ChatListPresetController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/01/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TGUIKit

class SelectCallbackObject : ShareObject {
    private let callback:([PeerId])->Signal<Never, NoError>
    init(_ context: AccountContext, excludePeerIds: Set<PeerId>, callback:@escaping([PeerId])->Signal<Never, NoError>) {
        self.callback = callback
        super.init(context, excludePeerIds: excludePeerIds)
    }
    
    override var interactionOk: String {
        return L10n.chatListAddSave
    }
    
    override var hasCaptionView: Bool {
        return false
    }
    
    override func perform(to peerIds:[PeerId], comment: String? = nil) -> Signal<Never, String> {
        return callback(peerIds) |> mapError { _ in return String() }
    }
    override var searchPlaceholderKey: String {
        return "ChatList.Add.Placeholder"
    }
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        return !self.excludePeerIds.contains(peer.id)
    }
    
}

private struct ChatListPresetState: Equatable {
    let preset: ChatListFilterPreset
    init(preset: ChatListFilterPreset) {
        self.preset = preset
    }
    func withUpdatedPreset(_ preset: ChatListFilterPreset) -> ChatListPresetState {
        return ChatListPresetState(preset: preset)
    }
}

private final class ChatListPresetArguments {
    let context: AccountContext
    let toggleOption:(ChatListFilter)->Void
    let addPeer:()->Void
    let removePeer:(PeerId)->Void
    let toggleApplyForExceptions: (Bool)->Void
    let openInfo:(PeerId)->Void
    init(context: AccountContext, toggleOption:@escaping(ChatListFilter)->Void, addPeer: @escaping()->Void, removePeer: @escaping(PeerId)->Void, toggleApplyForExceptions: @escaping(Bool)->Void, openInfo: @escaping(PeerId)->Void) {
        self.context = context
        self.toggleOption = toggleOption
        self.addPeer = addPeer
        self.removePeer = removePeer
        self.toggleApplyForExceptions = toggleApplyForExceptions
        self.openInfo = openInfo
    }
}

private let _id_name_input = InputDataIdentifier("_id_name_input")
private let _id_private_chats = InputDataIdentifier("_id_private_chats")

private let _id_public_groups = InputDataIdentifier("_id_public_groups")
private let _id_private_groups = InputDataIdentifier("_id_private_groups")
private let _id_secret_chats = InputDataIdentifier("_id_secret_chats")


private let _id_channels = InputDataIdentifier("_id_channels")
private let _id_bots = InputDataIdentifier("_id_bots")
private let _id_exclude_muted = InputDataIdentifier("_id_exclude_muted")
private let _id_exclude_read = InputDataIdentifier("_id_exclude_read")
private let _id_apply_exception = InputDataIdentifier("_id_apply_exception")

private let _id_add_exception = InputDataIdentifier("_id_add_exception")

private func _id_peer_id(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_id_\(peerId)")
}

private func chatListPresetEntries(state: ChatListPresetState, peers: [Peer], arguments: ChatListPresetArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("FILTER NAME"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.preset.title), error: nil, identifier: _id_name_input, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: "Filter Name", filter: { $0 }, limit: 20))
    index += 1
   
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("INCLUDE CHAT TYPES"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_private_chats, data: .init(name: L10n.chatListFilterPrivateChats, color: theme.colors.text, type: .selectable(state.preset.includeCategories.contains(.privateChats)), viewType: .firstItem, enabled: true, action: {
        arguments.toggleOption(.privateChats)
    })))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_secret_chats, data: .init(name: L10n.chatListFilterSecretChat, color: theme.colors.text, type: .selectable(state.preset.includeCategories.contains(.secretChats)), viewType: .innerItem, enabled: true, action: {
        arguments.toggleOption(.secretChats)
    })))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_public_groups, data: .init(name: L10n.chatListFilterPublicGroups, color: theme.colors.text, type: .selectable(state.preset.includeCategories.contains(.publicGroups)), viewType: .innerItem, enabled: true, action: {
        arguments.toggleOption(.publicGroups)
    })))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_private_groups, data: .init(name: L10n.chatListFilterPrivateGroups, color: theme.colors.text, type: .selectable(state.preset.includeCategories.contains(.privateGroups)), viewType: .innerItem, enabled: true, action: {
        arguments.toggleOption(.privateGroups)
    })))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_channels, data: .init(name: L10n.chatListFilterChannels, color: theme.colors.text, type: .selectable(state.preset.includeCategories.contains(.channels)), viewType: .innerItem, enabled: true, action: {
        arguments.toggleOption(.channels)
    })))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_bots, data: .init(name: L10n.chatListFilterBots, color: theme.colors.text, type: .selectable(state.preset.includeCategories.contains(.bots)), viewType: .lastItem, enabled: true, action: {
        arguments.toggleOption(.bots)
    })))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_exclude_muted, data: .init(name: "Exclude Muted", color: theme.colors.text, type: .switchable(!state.preset.includeCategories.contains(.muted)), viewType: .firstItem, enabled: true, action: {
        arguments.toggleOption(.muted)
    })))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_exclude_read, data: .init(name: "Exclude Read", color: theme.colors.text, type: .switchable(!state.preset.includeCategories.contains(.read)), viewType: .lastItem, enabled: true, action: {
        arguments.toggleOption(.read)
    })))
    index += 1
    
   
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("ALWAYS INCLUDE"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_exception, equatable: InputDataEquatable(state), item: { initialSize, stableId in
        return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: "Add Chats", nameStyle: blueActionButton, type: .none, viewType: peers.isEmpty ? .singleItem : .firstItem, action: arguments.addPeer, thumb: GeneralThumbAdditional(thumb: theme.icons.chat_filter_add, textInset: 46, thumbInset: 4))
    }))
    index += 1
    
    
    var fake:[Int] = []
    fake.append(0)
    for (i, _) in peers.enumerated() {
        fake.append(i + 1)
    }
    
    for (i, peer) in peers.enumerated() {
        
        struct E : Equatable {
            let viewType: GeneralViewType
            let peer: PeerEquatable
        }
        
        let viewType = bestGeneralViewType(fake, for: i + 1)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer_id(peer.id), equatable: InputDataEquatable(E(viewType: viewType, peer: PeerEquatable(peer))), item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, height: 44, photoSize: NSMakeSize(30, 30), inset: NSEdgeInsets(left: 30, right: 30), viewType: viewType, action: {
                arguments.openInfo(peer.id)
            }, contextMenuItems: {
                return [ContextMenuItem.init("Remove", handler: {
                    arguments.removePeer(peer.id)
                })]
            })
        }))
        index += 1
    }
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("These chats will be always included to the chat list."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ChatListPresetController(context: AccountContext, preset: ChatListFilterPreset) -> InputDataController {
    
    
    let initialState = ChatListPresetState(preset: preset)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChatListPresetState) -> ChatListPresetState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let updateDisposable = MetaDisposable()
    
    let save:()->Void = {
        updateDisposable.set(updateChatListFilterPreferencesInteractively(postbox: context.account.postbox, {
            $0.withAddedPreset(stateValue.with { $0.preset }, onlyReplace: true)
        }).start())
    }
    
    
    
    let arguments = ChatListPresetArguments(context: context, toggleOption: { option in
        updateState {
            $0.withUpdatedPreset($0.preset.withToggleOption(option))
        }
        save()
        
    }, addPeer: {
        showModal(with: ShareModalController(SelectCallbackObject(context, excludePeerIds: Set(stateValue.with { $0.preset.additionallyIncludePeers }), callback: { peerIds in
            
            updateState {
                $0.withUpdatedPreset($0.preset.withAddedPeerIds(peerIds))
            }
            
            return updateChatListFilterPreferencesInteractively(postbox: context.account.postbox, {
                $0.withAddedPreset(stateValue.with { $0.preset }, onlyReplace: true)
            }) |> ignoreValues
            
        })), for: context.window)
    }, removePeer: { peerId in
        updateState {
            $0.withUpdatedPreset($0.preset.withRemovedPeerId(peerId))
        }
        save()
    }, toggleApplyForExceptions: { value in
        updateState {
            $0.withUpdatedPreset($0.preset.withUpdatedApplyReadMutedForExceptions(value))
        }
        save()
    }, openInfo: { peerId in
        context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
    })
    
    
    let dataSignal = combineLatest(queue: prepareQueue, appearanceSignal, statePromise.get()) |> mapToSignal { _, state -> Signal<(ChatListPresetState, [Peer]), NoError> in
        return context.account.postbox.transaction { transaction -> [Peer] in
            return state.preset.additionallyIncludePeers.compactMap { transaction.getPeer($0) }
        } |> map {
            (state, $0)
        }
    } |> map {
        return chatListPresetEntries(state: $0, peers: $1, arguments: arguments)
    } |> map {
          return InputDataSignalValue(entries: $0)
    }
    
    let controller = InputDataController(dataSignal: dataSignal, title: L10n.chatListFilterPresetTitle, removeAfterDisappear: false)
    
    controller.updateDatas = { data in
        
        if let name = data[_id_name_input]?.stringValue {
            updateState {
                $0.withUpdatedPreset($0.preset.withUpdatedName(.custom(name)))
            }
            
            updateDisposable.set(updateChatListFilterPreferencesInteractively(postbox: context.account.postbox, {
                $0.withAddedPreset(stateValue.with { $0.preset }, onlyReplace: true)
            }).start())
        }
        
        return .none
    }
    
//    controller.updateDoneValue = { data in
//        return { f in
//            f(.enabled(L10n.navigationAdd))
//        }
//    }
    
    controller.onDeinit = {
        updateDisposable.dispose()
    }
    
    
    controller.validateData = { data in
        
        let emptyTitle = stateValue.with { $0.preset.title.isEmpty }
        
        if emptyTitle {
            return .fail(.fields([_id_name_input : .shake]))
        }
        
        _ = updateChatListFilterPreferencesInteractively(postbox: context.account.postbox, {
            $0.withAddedPreset(stateValue.with { $0.preset })
        }).start()
        
        return .success(.navigationBack)
    }
    
    return controller
    
}
