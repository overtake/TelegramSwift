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
private let _id_hide_general = InputDataIdentifier("_id_hide_general")

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
    
    let isGeneral: Bool
    let isHidden: Bool
    switch arguments.purpose {
    case .create:
        isGeneral = false
        isHidden = false
    case let .edit(data, threadId):
        isHidden = data.isHidden
        isGeneral = threadId == 1
    }
    
    if !isGeneral {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emojies, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return ForumTopicEmojiSelectRowItem(initialSize, stableId: stableId, context: arguments.context, getView: arguments.getView, viewType: .singleItem)
        }))
        index += 1
    } else {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_hide_general, data: .init(name: strings().forumTopicEditGeneralShow, color: theme.colors.text, type: .switchable(!isHidden), viewType: .singleItem)))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().forumTopicEditGeneralInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }
    
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum ForumTopicInfoPurpose : Equatable {
    case create
    case edit(MessageHistoryThreadData, Int64)
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
    case let .edit(data, threadId):
        let icon: ForumNameRowItem.Icon?
        if let fileId = data.info.icon {
            icon = .init(file: nil, fileId: fileId, fromRect: nil)
        } else {
            let file = ForumUI.makeIconFile(title: data.info.title, iconColor: data.info.iconColor, isGeneral: threadId == 1)
            icon = .init(file: file, fileId: file.fileId.id, fromRect: nil)
        }
        initialState = State(icon: icon, name: data.info.title)
        title = strings().forumTopicTitleEdit
    }
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let emojis = EmojiesController(context, mode: .forumTopic, selectedItems: [])
    emojis._frameRect = NSMakeRect(0, 0, context.bindings.rootNavigation().frame.width - 40, 250)
    emojis.loadViewIfNeeded()
    
    
    let interactions = EntertainmentInteractions(.emoji, peerId: peerId)
    
    let showPremiumAlert:()->Void = {
        showModalText(for: context.window, text: strings().customEmojiPremiumAlert, callback: { _ in
            showModal(with: PremiumBoardingController(context: context, source: .premium_emoji), for: context.window)
        })
    }
    
    interactions.sendAnimatedEmoji = { sticker, _, _, fromRect in
        let pass: Bool
        switch purpose {
        case let .edit(data, _):
            pass = data.info.icon == sticker.file.fileId.id
        default:
            pass = false
        }
        
        let freeItems: Signal<[StickerPackItem], NoError> = context.engine.stickers.loadedStickerPack(reference: .iconTopicEmoji, forceActualized: false) |> map { result in
            switch result {
            case let .result(_, items, _):
                return items
            default:
                return []
            }
        } |> take(1) |> deliverOnMainQueue
        
        _ = freeItems.start(next: { freeItems in
            let accept = freeItems.contains(where: { $0.file.fileId == sticker.file.fileId })
            if !context.isPremium, sticker.file.isPremiumEmoji && !pass && !accept {
                showPremiumAlert()
            } else {
                updateState { current in
                    var current = current
                    current.icon = .init(file: sticker.file, fileId: sticker.file.fileId.id, fromRect: fromRect)
                    return current
                }
            }
        })
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
    
    let CheckEdited:()->Bool = {
        let state = stateValue.with { $0}
        switch purpose {
        case .create:
            return true
        case let .edit(data, _):
            return data.info.title != state.name || data.info.icon != state.icon?.fileId
        }
    }
    
    let controller = InputDataController(dataSignal: signal, title: title, updateDoneValue: { data in
        return { f in
            let title = purpose == .create ? strings().forumTopicDoneNew : strings().forumTopicDoneEdit
            if data[_id_name]?.stringValue == "" {
                f(.disabled(title))
            } else {
                if CheckEdited() {
                    f(.enabled(title))
                } else {
                    f(.disabled(title))
                }
            }
        }
    }, hasDone: true, identifier: "ForumTopic")
    
    controller.validateData = { data in
        
        let state = stateValue.with { $0 }
        return .fail(.doSomething(next: { f in
            if !state.name.isEmpty && CheckEdited() {
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
                        _ = ForumUI.openTopic(threadId, peerId: peerId, context: context).start()
                    }, error: { error in
                        alert(for: context.window, info: "create topic error: \(error)")
                    })
                case let .edit(_, threadId):
                    let signal = context.engine.peers.editForumChannelTopic(id: peerId, threadId: threadId, title: state.name, iconFileId: threadId == 1 ? nil : fileId)
                    
                    _ = showModalProgress(signal: signal, for: context.window).start(error: { error in
                        alert(for: context.window, info: "edit topic error: \(error)")
                    }, completed: {
                        context.bindings.rootNavigation().back()
                    })
                }
                f(.fail(.none))
            } else if !CheckEdited() {
                f(.fail(.none))
            } else {
                f(.fail(.fields([_id_name : .shake])))
            }
        }))
            
        
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.autoInputAction = true
                                                                                
    controller.afterTransaction = { [weak emojis] controller in
        let value = stateValue.with { value in
            return value
        }
        if let file = value.icon?.file, let resource = file.resource as? ForumTopicIconResource {
            emojis?.setExternalForumTitle(value.name, iconColor: resource.iconColor)
        } else if let fileId = value.icon?.fileId {
            emojis?.setSelectedItem(.init(source: .custom(fileId), type: .normal))
        }
    }
    
    return controller

    
}
