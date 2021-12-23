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
    let toggleReaction:([String])->Void
    init(context: AccountContext, toggleReaction:@escaping([String])->Void) {
        self.context = context
        self.toggleReaction = toggleReaction
    }
}

private struct State : Equatable {
    var isGroup: Bool
    var reactions: [String]
    var availableReactions: AvailableReactions?
    var thumbs:[String: CGImage] = [:]
}

private let _id_allow: InputDataIdentifier = InputDataIdentifier("_id_allow")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let all = state.availableReactions?.reactions.map { $0.value } ?? []
  
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_allow, data: .init(name: strings().reactionSettingsAllow, color: theme.colors.text, type: .switchable(!state.reactions.isEmpty), viewType: .singleItem, action: {
        arguments.toggleReaction(state.reactions.isEmpty ? all : [])
    })))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.isGroup ? strings().reactionSettingsAllowGroupInfo : strings().reactionSettingsAllowChannelInfo), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if let available = state.availableReactions {
        for (i, reaction) in available.reactions.enumerated() {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: .init(reaction.value), data: .init(name: reaction.title, color: theme.colors.text, icon: state.thumbs[reaction.value], type: .switchable(state.reactions.contains(reaction.value)), viewType: bestGeneralViewType(available.reactions, for: i), action: {
                let contains = state.reactions.contains(reaction.value)
                var updated = state.reactions
                if contains {
                    updated.removeAll(where: {  $0 == reaction.value })
                } else {
                    updated.append(reaction.value)
                }
                arguments.toggleReaction(updated)
            })))
            index += 1
        }
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ReactionsSettingsController(context: AccountContext, peerId: PeerId, allowedReactions: [String]?, availableReactions: AvailableReactions?, isGroup: Bool) -> InputDataController {

    let actionsDisposable = DisposableSet()
    let update = MetaDisposable()
    actionsDisposable.add(update)
    let allowed = allowedReactions ?? availableReactions?.reactions.map { $0.value } ?? []
    
    let initialState = State(isGroup: isGroup, reactions: allowed, availableReactions: availableReactions)
    
    let statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    if let reactions = availableReactions {
        for reaction in reactions.reactions {
            
            let signal = chatMessageImageFile(account: context.account, fileReference: .standalone(media: reaction.staticIcon), scale: System.backingScale)
            
            let arguments = TransformImageArguments(corners: .init(), imageSize: NSMakeSize(24, 24), boundingSize: NSMakeSize(24, 24), intrinsicInsets: NSEdgeInsetsZero, emptyColor: .color(.clear))

            
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
        update.set(context.engine.peers.updatePeerAllowedReactions(peerId: peerId, allowedReactions: value).start())
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().reactionSettingsTitle, hasDone: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}

