//
//  StorageUsage_Block_MediaList.swift
//  Telegram
//
//  Created by Mike Renoir on 26.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class GallerySupplyment : InteractionContentViewProtocol {
    private weak var tableView: TableView?
    init(tableView: TableView) {
        self.tableView = tableView
    }
    
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        if let stableId = stableId.base as? ChatHistoryEntryId, let tableView = tableView {
            switch stableId {
            case let .message(message):
                var found: NSView? = nil
                tableView.enumerateItems { item -> Bool in
                    if let item = item as? StorageUsageMediaItem {
                        if item.message.id == message.id {
                            found = item.view?.interactionContentView(for: message.id, animateIn: animateIn)
                        }
                    } else if let item = item as? StorageUsageMediaCells {
                        found = item.view?.interactionContentView(for: message.id, animateIn: animateIn)
                    }
                    return found == nil
                }
                return found
            default:
                break
            }
        }
        return nil
    }
    func interactionControllerDidFinishAnimation(interactive: Bool, for stableId: AnyHashable) {
        
    }
    func addAccesoryOnCopiedView(for stableId: AnyHashable, view: NSView) {
        
    }
    func videoTimebase(for stableId: AnyHashable) -> CMTimebase? {
        return nil
    }
    func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?) {
        
    }
}




private final class Arguments {
    let context: AccountContext
    let tag: StorageUsageCollection
    let toggle: (EngineMessage.Id, Bool?)->Void
    let getSelected:(EngineMessage.Id) -> Bool?
    let menuItems:(Message)->[ContextMenuItem]
    let preview:(Message)->Void
    init(context: AccountContext, tag: StorageUsageCollection, toggle: @escaping(EngineMessage.Id, Bool?)->Void, getSelected: @escaping(EngineMessage.Id) -> Bool?, menuItems: @escaping(Message)->[ContextMenuItem], preview:@escaping(Message)->Void) {
        self.context = context
        self.tag = tag
        self.toggle = toggle
        self.getSelected = getSelected
        self.menuItems = menuItems
        self.preview = preview
    }
}


private func _id_message(_ id: MessageId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer\(id.description)")
}
private let _id_media = InputDataIdentifier("_id_media")

private func entries(_ state: StorageUsageUIState, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    let sizes:[EngineMessage.Id : Int64] = state.msgSizes
    
    let messages = state.messageList(for: arguments.tag)
    
    
    let sorted = messages.filter {
        return sizes[$0.id] != nil
    }.sorted(by: { lhs, rhs in
        let lhsSize = sizes[lhs.id] ?? 0
        let rhsSize = sizes[rhs.id] ?? 0
        if lhsSize != rhsSize {
            return lhsSize > rhsSize
        } else {
            return lhs.id > rhs.id
        }
    })

    
    switch arguments.tag {
    case .media:
        struct TupleMessages: Equatable {
            let messages: [Message]
            let sizes: [MessageId : Int64]
        }
        let tuple = TupleMessages(messages: sorted, sizes: sizes)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_media, equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return StorageUsageMediaCells(initialSize, stableId: stableId, viewType: .lastItem, context: arguments.context, items: tuple.messages, sizes: tuple.sizes, getSelected: arguments.getSelected, toggle: arguments.toggle, menuItems: arguments.menuItems)
        }))
    default:
        struct TupleMessage: Equatable {
            let message: Message
            let size: Int64
            let viewType: GeneralViewType
        }
        
        var items:[TupleMessage] = []
        for (i, message) in sorted.enumerated() {
            let size = sizes[message.id]!
            let viewType: GeneralViewType
            if i == 0 {
                if sorted.count == 1 {
                    viewType = .lastItem
                } else {
                    viewType = .innerItem
                }
            } else {
                viewType = bestGeneralViewType(sorted, for: i)
            }
            items.append(.init(message: message, size: size, viewType: viewType))
        }
        
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: 0, value: .none, identifier: _id_message(item.message.id), equatable: .init(item), comparable: .init(data: item.message.id, compare: { lhs, rhs in
                
                let lhs = lhs as? MessageId
                let rhs = rhs as? MessageId

                if let lhs = lhs, let rhs = rhs {
                    let lhsSize = state.msgSizes[lhs] ?? 0
                    let rhsSize = state.msgSizes[rhs] ?? 0
                    if lhsSize != rhsSize {
                        return lhsSize > rhsSize
                    } else {
                        return lhs > rhs
                    }
                } else {
                    return false
                }
            }, equatable: { lhs, rhs in
                let lhs = lhs as? MessageId
                let rhs = rhs as? MessageId
                return lhs == rhs
            }), item: { initialSize, stableId in
                return StorageUsageMediaItem(initialSize, stableId: stableId, context: arguments.context, getSelected: arguments.getSelected, message: item.message, size: item.size, viewType: item.viewType, toggle: arguments.toggle, preview: arguments.preview, menuItems: {
                    return arguments.menuItems(item.message)
                })
            }))
        }
    }
   
 
    if state.editing {
        entries.append(.sectionId(sectionId, type: .customModern(70)))
        sectionId += 1
    } else {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
    return entries
}

func StorageUsage_Block_MediaList(context: AccountContext, storageArguments: StorageUsageArguments, tag: StorageUsageCollection, state: Signal<StorageUsageUIState, NoError>, updateState:@escaping((StorageUsageUIState)->StorageUsageUIState)->StorageUsageUIState) -> InputDataController {

    let actionsDisposable = DisposableSet()
    
    var currentState: StorageUsageUIState?
    
    var gallery: GallerySupplyment? = nil
    var getTableView:(()->TableView?)? = nil
    
    let preview:(Message)->Void = { message in
        let id: ChatHistoryEntryId = .message(message)
        switch tag {
        case .media:
            showChatGallery(context: context, message: message, gallery, nil, type: .alone, chatMode: nil, chatLocation: nil)
        case .files:
            if let file = message.anyMedia as? TelegramMediaFile {
                if file.isGraphicFile {
                    showChatGallery(context: context, message: message, gallery, nil, type: .alone, chatMode: nil, chatLocation: nil)
                } else {
                    QuickLookPreview.current.show(context: context, with: file, stableId: id, gallery)
                }
            }
        case .music, .voice:
            if let file = message.anyMedia as? TelegramMediaFile {
                if let controller = context.sharedContext.getAudioPlayer(), let song = controller.currentSong, song.entry.isEqual(to: message) {
                    _ = controller.playOrPause()
                } else {
                    
                    let name: String
                    let performer: String
                    if file.isVoice {
                        name = strings().storageUsageMediaVoice
                        performer = message.author?.displayTitle ?? ""
                    } else if file.isInstantVideo {
                        name = strings().storageUsageMediaVideoMessage
                        performer = message.author?.displayTitle ?? ""
                    } else {
                        name = file.musicText.0
                        performer = file.musicText.1
                    }
                    
                    let controller = APSingleResourceController(context: context, wrapper: .init(resource: file.resource, name: name, performer: performer, duration: file.duration, id: id), streamable: true, volume: FastSettings.volumeRate)
                    
                    let object = InlineAudioPlayerView.ContextObject(controller: controller, context: context, tableView: getTableView?(), supportTableView: nil)
                    context.bindings.rootNavigation().header?.show(true, contextObject: object)
                    controller.start()
                }
            }
            break
        default:
            break
        }
    }

    let arguments = Arguments(context: context, tag: tag, toggle: { id, update in
        _ = updateState { current in
            var current = current
            if let updated = update {
                if !updated {
                    current.selectedMessages.remove(id)
                } else {
                    current.selectedMessages.insert(id)
                }
            } else {
                if current.selectedMessages.contains(id) {
                    current.selectedMessages.remove(id)
                } else {
                    current.selectedMessages.insert(id)
                }
            }
            
            return current
        }
    }, getSelected: { id in
        if let currentState = currentState, currentState.editing {
            return currentState.selectedMessages.contains(id)
        } else {
            return nil
        }
    }, menuItems: { message in
        var items: [ContextMenuItem] = []
        items.append(.init(strings().storageUsageMessageContextPreview, handler: {
            preview(message)
        }, itemImage: MenuAnimation.menu_open_with.value))
        
        items.append(.init(strings().storageUsageMessageContextShowInChat, handler: {
            if let peer = message.peers[message.id.peerId] {
                if peer.isForum, let threadId = message.threadId {
                    ForumUI.open(message.id.peerId, addition: true, context: context, threadId: threadId)
                } else {
                    context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(message.id.peerId), focusTarget: .init(messageId: message.id)))
                }
            }
        }, itemImage: MenuAnimation.menu_show_message.value))
        
        items.append(.init(strings().storageUsageMessageContextSelect, handler: {
            _ = updateState { current in
                var current = current
                current.selectedMessages.insert(message.id)
                current.editing = true
                return current
            }

        }, itemImage: MenuAnimation.menu_select_messages.value))
        
        items.append(ContextSeparatorItem())
        
        items.append(.init(strings().storageUsageMessageContextDelete, handler: {
            storageArguments.clearMessage(message)
        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
        
        return items
    }, preview: preview)
    
    let signal = state |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments), grouping: false, animateEverything: true)
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    controller.didLoad = { controller, _ in
        gallery = .init(tableView: controller.tableView)
        getTableView = { [weak controller] in
            return controller?.tableView
        }
    }
    
    controller.beforeTransaction = { _ in
        currentState = updateState { $0 }
    }
    controller.afterTransaction = { controller in
        controller.tableView.enumerateViews(with: { view in
            if let item = view.item {
                view.set(item: item, animated: true)
            }
            return true
        })
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
