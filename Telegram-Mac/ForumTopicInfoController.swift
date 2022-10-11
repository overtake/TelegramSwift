//
//  ForumTopicInfoController.swift
//  Telegram
//
//  Created by Mike Renoir on 27.09.2022.
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
    let purpose: ForumTopicInfoPurpose
    let updateName:(String)->Void
    let getView:()->NSView
    init(context: AccountContext, purpose: ForumTopicInfoPurpose, updateName:@escaping(String)->Void, getView:@escaping()->NSView) {
        self.context = context
        self.purpose = purpose
        self.updateName = updateName
        self.getView = getView
    }
}

private struct State : Equatable {
    
    var icon: ForumNameRowItem.Icon?
    var name: String
}

private let _id_name = InputDataIdentifier("_id_name")
private let _id_emojies = InputDataIdentifier("_id_emojies")
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    let t1 = arguments.purpose == .create ? strings().forumTopicNewTopicName : strings().forumTopicEditTopicName
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(t1), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_name, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return ForumNameRowItem(initialSize, stableId: stableId, context: arguments.context, icon: state.icon, name: state.name, updatedText: arguments.updateName, viewType: .singleItem)
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let t2 = arguments.purpose == .create ? strings().forumTopicNewTopicIcon : strings().forumTopicEditTopicIcon

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(t2), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emojies, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return ForumTopicEmojiSelectRowItem(initialSize, stableId: stableId, context: arguments.context, getView: arguments.getView, viewType: .singleItem)
    }))
    index += 1
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum ForumTopicInfoPurpose : Equatable {
    case create
    case edit(EngineMessageHistoryThread.Info, Int64)
}

func ForumTopicInfoController(context: AccountContext, purpose: ForumTopicInfoPurpose, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    
    let initialState: State
    let title: String
    switch purpose {
    case .create:
        let file = ForumUI.makeIconFile(title: "A")
        initialState = State(icon: .init(file: file, fileId: file.fileId.id, fromRect: nil), name: "")
        title = strings().forumTopicTitleCreate
    case let .edit(info, _):
        let icon: ForumNameRowItem.Icon?
        if let fileId = info.icon {
            icon = .init(file: nil, fileId: fileId, fromRect: nil)
        } else {
            let file = ForumUI.makeIconFile(title: info.title, iconColor: info.iconColor)
            icon = .init(file: file, fileId: file.fileId.id, fromRect: nil)
        }
        initialState = State(icon: icon, name: info.title)
        title = strings().forumTopicTitleEdit
    }
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let emojis = EmojiesController(context, mode: .forumTopic, selectedItems: [])
    emojis._frameRect = NSMakeRect(0, 0, context.bindings.rootNavigation().frame.width - 60, 250)
    emojis.loadViewIfNeeded()
    
    
    let interactions = EntertainmentInteractions(.emoji, peerId: peerId)
    
    interactions.sendAnimatedEmoji = { sticker, _, _, fromRect in
        updateState { current in
            var current = current
            current.icon = .init(file: sticker.file, fileId: sticker.file.fileId.id, fromRect: fromRect)
            return current
        }
    }
    
    emojis.update(with: interactions, chatInteraction: .init(chatLocation: .peer(peerId), context: context))

    
    let arguments = Arguments(context: context, purpose: purpose, updateName: { updated in
        updateState { current in
            var current = current
            current.name = updated
            if let file = current.icon?.file {
                if let resource = file.resource as? ForumTopicIconResource {
                    let f = ForumUI.makeIconFile(title: updated, iconColor: resource.iconColor)
                    current.icon = .init(file: f, fileId: f.fileId.id, fromRect: nil)
                }
            }
            return current
        }
    }, getView: {
        return emojis.genericView
    })
    
    let signal = combineLatest(statePromise.get(), emojis.ready.get() |> filter { $0 }) |> deliverOnPrepareQueue |> map { state, _ in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: title, updateDoneValue: { data in
        return { f in
            let title = purpose == .create ? strings().forumTopicDoneNew : strings().forumTopicDoneEdit
            if data[_id_name]?.stringValue == "" {
                f(.disabled(title))
            } else {
                f(.enabled(title))
            }
        }
    }, hasDone: true)
    
    controller.validateData = { data in
        
        let state = stateValue.with { $0 }
        
        if !state.name.isEmpty {
            let fileId: Int64?
            if state.icon?.file?.mimeType == "bundle/topic" {
                fileId = nil
            } else {
                fileId = state.icon?.fileId
            }
            switch purpose {
            case .create:
                let iconColor = ForumUI.randomTopicColor()
                let signal = context.engine.peers.createForumChannelTopic(id: peerId, title: state.name, iconColor: iconColor, iconFileId: fileId)
                _ = showModalProgress(signal: signal, for: context.window).start(next: { threadId in
                    ForumUI.openTopic(threadId, peerId: peerId, context: context)
                }, error: { error in
                    alert(for: context.window, info: "create topic error: \(error)")
                })
            case let .edit(_, threadId):
                let signal = context.engine.peers.editForumChannelTopic(id: peerId, threadId: threadId, title: state.name, iconFileId: fileId)
                
                _ = showModalProgress(signal: signal, for: context.window).start(error: { error in
                    alert(for: context.window, info: "edit topic error: \(error)")
                }, completed: {
                    context.bindings.rootNavigation().back()
                })
            }
            
            return .fail(.none)
        } else {
            return .fail(.fields([_id_name : .shake]))
        }
        
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
                                                                                
    controller.afterTransaction = { [weak emojis] controller in
        let value = stateValue.with { value in
            return value
        }
        if let file = value.icon?.file, let resource = file.resource as? ForumTopicIconResource {
            emojis?.setExternalForumTitle(value.name, iconColor: resource.iconColor)
        }
    }
    
    return controller

    
}
