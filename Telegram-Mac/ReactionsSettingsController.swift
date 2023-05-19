//
//  ReactionsSettingsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16.12.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let toggleReaction:([MessageReaction.Reaction])->Void
    let toggleValueReaction:(MessageReaction.Reaction)->Void
    let updateQuick:(MessageReaction.Reaction)->Void
    let toggleChatReactions:(State.ChatReactions)->Void
    init(context: AccountContext, toggleReaction:@escaping([MessageReaction.Reaction])->Void, updateQuick:@escaping(MessageReaction.Reaction)->Void, toggleValueReaction: @escaping(MessageReaction.Reaction)->Void, toggleChatReactions:@escaping(State.ChatReactions)->Void) {
        self.context = context
        self.toggleReaction = toggleReaction
        self.updateQuick = updateQuick
        self.toggleValueReaction = toggleValueReaction
        self.toggleChatReactions = toggleChatReactions
    }
}

private struct State : Equatable {
    
    enum ChatReactions : Equatable {
        case all
        case some
        case none
    }
    
    let mode: ReactionSettingsMode
    var quick: MessageReaction.Reaction?
    var reactions: [MessageReaction.Reaction]
    var availableReactions: AvailableReactions?
    var chatReactions: ChatReactions = .all
    var thumbs:[MessageReaction.Reaction: CGImage] = [:]
}

private let _id_allow: InputDataIdentifier = InputDataIdentifier("_id_allow")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    switch state.mode {
    case .chat:
        let all = state.availableReactions?.enabled.filter { value in
            return !value.isPremium || arguments.context.isPremium
        }.map { $0.value } ?? []
        
        
        if !state.mode.isGroup {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_allow, data: .init(name: strings().reactionSettingsAllow, color: theme.colors.text, type: .switchable(!state.reactions.isEmpty), viewType: .singleItem, action: {
                arguments.toggleReaction(state.reactions.isEmpty ? all : [])
            })))
            index += 1
        } else {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("all"), data: .init(name: strings().reactionSettingsGroupAll, color: theme.colors.text, type: .selectable(state.chatReactions == .all), viewType: .firstItem, action: {
                arguments.toggleChatReactions(.all)
            })))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("some"), data: .init(name: strings().reactionSettingsGroupSome, color: theme.colors.text, type: .selectable(state.chatReactions == .some), viewType: .innerItem, action: {
                arguments.toggleChatReactions(.some)
            })))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("no"), data: .init(name: strings().reactionSettingsGroupNone, color: theme.colors.text, type: .selectable(state.chatReactions == .none), viewType: .lastItem, action: {
                arguments.toggleChatReactions(.none)
            })))
            index += 1
        }
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.mode.isGroup ? strings().reactionSettingsAllowGroupInfo : strings().reactionSettingsAllowChannelInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
    default:
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().reactionSettingsQuickInfo), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
    }
    
    if let available = state.availableReactions {
        var accept = true
        if state.mode.isGroup, state.chatReactions != .some {
            accept = false
        }
        if accept {
            for (i, reaction) in available.enabled.enumerated() {
                let type: GeneralInteractedType
                switch state.mode {
                case .quick:
                    if state.quick != nil {
                        type = .selectable(state.quick == reaction.value)
                    } else {
                        type = .selectable(i == 0)
                    }
                case .chat:
                     type = .switchable(state.reactions.contains(reaction.value))
                }
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("_id_\(reaction.value.hashValue)"), data: .init(name: reaction.title, color: theme.colors.text, icon: state.thumbs[reaction.value], type: type, viewType: bestGeneralViewType(available.enabled, for: i), action: {
                    switch state.mode {
                    case .quick:
                        arguments.updateQuick(reaction.value)
                    case .chat:
                        arguments.toggleValueReaction(reaction.value)
                    }
                })))
                index += 1
            }
        }
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
//    switch state.mode {
//    case .quick:
//        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init("legacy"), data: .init(name: strings().reactionSettingsLegacy, color: theme.colors.text, type: .switchable(FastSettings.legacyReactions), viewType: .singleItem, action: {
//            FastSettings.toggleReactionMode(!FastSettings.legacyReactions)
//        })))
//        index += 1
//        
//        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().reactionSettingsLegacyInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
//        index += 1
//
//        entries.append(.sectionId(sectionId, type: .normal))
//        sectionId += 1
//    default:
//        break
//    }
//    
    return entries
}

enum ReactionSettingsMode : Equatable {
    case chat(isGroup: Bool)
    case quick
    
    var isGroup: Bool {
        switch self {
        case let .chat(isGroup):
            return isGroup
        default:
            return false
        }
    }
}

func ReactionsSettingsController(context: AccountContext, peerId: PeerId, allowedReactions: PeerAllowedReactions?, availableReactions: AvailableReactions?, mode: ReactionSettingsMode) -> InputDataController {

    let actionsDisposable = DisposableSet()
    let update = MetaDisposable()
    actionsDisposable.add(update)
    let allowed:[MessageReaction.Reaction]
    let chatReactions: State.ChatReactions
    if let allowedReactions = allowedReactions {
        switch allowedReactions {
        case let .limited(reactions):
            allowed = reactions
            chatReactions = .some
        case .all:
            allowed = availableReactions?.enabled.map { $0.value } ?? []
            chatReactions = .all
        case .empty:
            allowed = []
            chatReactions = .none
        }
    } else {
        allowed = availableReactions?.enabled.map { $0.value } ?? []
        chatReactions = .all
    }
    
    let initialState = State(mode: mode, reactions: allowed, availableReactions: availableReactions, chatReactions: chatReactions)
    
    let statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let settings = context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
       |> map { preferencesView -> ReactionSettings in
           let reactionSettings: ReactionSettings
           if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
               reactionSettings = value
           } else {
               reactionSettings = .default
           }
           return reactionSettings
       }
    
    actionsDisposable.add(settings.start(next: { settings in
        updateState { current in
            var current = current
            current.quick = settings.quickReaction
            return current
        }
    }))
    
    if let reactions = availableReactions {
        for reaction in reactions.reactions {
            
            let signal = chatMessageSticker(postbox: context.account.postbox, file: .standalone(media: reaction.staticIcon), small: false, scale: System.backingScale)
            
            let arguments = TransformImageArguments(corners: .init(), imageSize: NSMakeSize(24, 24), boundingSize: NSMakeSize(24, 24), intrinsicInsets: NSEdgeInsetsZero, emptyColor: nil)

            
            actionsDisposable.add(signal.start(next: { value in
                updateState { current in
                    var current = current
                    if let image = value.execute(arguments, value.data)?.generateImage() {
                        current.thumbs[reaction.value] = NSImage(cgImage: image, size: NSMakeSize(24, 24)).precomposed(flipVertical: true)
                    }
                    return current
                }
            }))
        }
    }
    
    
    let arguments = Arguments(context: context, toggleReaction: { value in
        updateState { current in
            var current = current
            current.reactions = value
            return current
        }
    }, updateQuick:{ value in
        context.reactions.updateQuick(value)
    }, toggleValueReaction: { value in
        updateState { current in
            var current = current
            var list = current.reactions
            if list.contains(value) {
                list.removeAll(where: { $0 == value })
            } else {
                list.append(value)
            }
            current.reactions = list
            return current
        }
    }, toggleChatReactions: { value in
        updateState { current in
            var current = current
            current.chatReactions = value
            if value == .some {
                var list = current.reactions
                list = list.filter({ reaction in
                    if let available = current.availableReactions {
                        if available.enabled.count <= 2 {
                            return false
                        }
                        if reaction == available.enabled[0].value {
                            return true
                        }
                        if reaction == available.enabled[1].value {
                            return true
                        }
                    }
                    return false
                })
                current.reactions = list
            }
            return current
        }
    })
    
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: mode == .quick ? strings().reactionSettingsQuickTitle : strings().reactionSettingsTitle, hasDone: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
        switch mode {
        case .chat:
            let updated: PeerAllowedReactions
            let state = stateValue.with { $0 }
            if state.mode.isGroup {
                switch state.chatReactions {
                case .none:
                    updated = .empty
                case .all:
                    updated = .all
                case .some:
                    updated = .limited(state.reactions)
                }
            } else {
                let selected = state.reactions.map { value in
                    return value
                }
                if selected.isEmpty {
                    updated = .empty
                } else if selected.count == state.availableReactions?.enabled.count {
                    updated = .all
                } else {
                    updated = .limited(selected)
                }
            }
            
            _ = context.engine.peers.updatePeerAllowedReactions(peerId: peerId, allowedReactions: updated).start()
        default:
            break
        }
    }

    return controller
    
}

