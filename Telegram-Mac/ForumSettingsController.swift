//
//  ForumSettingsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16.05.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let toggleForum: ()->Void
    let toggleMonoforum: (Bool)->Void
    init(context: AccountContext, toggleForum: @escaping()->Void, toggleMonoforum: @escaping(Bool)->Void) {
        self.context = context
        self.toggleForum = toggleForum
        self.toggleMonoforum = toggleMonoforum
    }
}

private struct State : Equatable {
    var isForum: Bool = false
    var isMonoforum: Bool = false
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_toggle = InputDataIdentifier("_id_toggle")
private let _id_monoforum = InputDataIdentifier("_id_monoforum")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.topics, text: .initialize(string: strings().forumSettingsTopicInfo, color: theme.colors.listGrayText, font: .normal(.text)))
    }))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

  
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_toggle, data: .init(name: strings().forumSettingsEnable, color: theme.colors.text, type: .switchable(state.isForum), viewType: .singleItem, action: arguments.toggleForum)))
    
    
    if state.isForum {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().forumSettingsDisplayAs), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_monoforum, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return ChatListFilterVisibilityItem(initialSize, stableId: stableId, sidebar: !state.isMonoforum, viewType: .singleItem, source: .forum, toggle: arguments.toggleMonoforum)
        }))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().forumSettingsDisplayAsInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ForumSettingsController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
    actionsDisposable.add(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)).start(next: { peer in
        if let peer {
            switch peer {
            case let .channel(channel):
                updateState { current in
                    var current = current
                    current.isForum = channel.flags.contains(.isForum)
                    current.isMonoforum = channel.flags.contains(.displayForumAsTabs)
                    return current
                }
            default:
                break
            }
        }
    }))
    
    let update:()->Void = {
        let state = stateValue.with { $0 }
        _ = showModalProgress(signal: context.engine.peers.setChannelForumMode(id: peerId, isForum: state.isForum, displayForumAsTabs: state.isMonoforum), for: context.window).start()
    }

    let arguments = Arguments(context: context, toggleForum: {
        updateState { current in
            var current = current
            current.isForum = !current.isForum
            return current
        }
        update()
    }, toggleMonoforum: { value in
        updateState { current in
            var current = current
            current.isMonoforum = !value
            return current
        }
        update()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().forumSettingsTitle, hasDone: false)
    
    controller.afterDisappear = {
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
