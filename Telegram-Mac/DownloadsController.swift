//
//  DownloadsController.swift
//  Telegram
//
//  Created by Mike Renoir on 21.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import InAppSettings
import FetchManager
import Postbox


private struct DownloadItem: Equatable {
    let resourceId: MediaResourceId
    let message: Message
    let priority: FetchManagerPriorityKey
    let isPaused: Bool
    
    static func ==(lhs: DownloadItem, rhs: DownloadItem) -> Bool {
        if lhs.resourceId != rhs.resourceId {
            return false
        }
        if lhs.message.id != rhs.message.id {
            return false
        }
        if lhs.priority != rhs.priority {
            return false
        }
        if lhs.isPaused != rhs.isPaused {
            return false
        }
        return true
    }
}


private final class Arguments {
    let context: AccountContext
    let interaction: ChatInteraction
    let clearRecent:()->Void
    let gallery:(Message, GalleryAppearType)->Void
    init(context: AccountContext, interaction: ChatInteraction, clearRecent:@escaping()->Void, gallery:@escaping(Message, GalleryAppearType)->Void) {
        self.context = context
        self.interaction = interaction
        self.clearRecent = clearRecent
        self.gallery = gallery
    }
}

private struct State : Equatable {
    var doneItems: [RenderedRecentDownloadItem]
    var inProgressItems: [DownloadItem]
}

private func _id_recent(_ messageId: MessageId) -> InputDataIdentifier {
    return .init("_id_recent_\(messageId.string)")
}
private func _id_downloading(_ messageId: MessageId) -> InputDataIdentifier {
    return .init("_id_downloading\(messageId.string)")
}

private let _id_recent_separator = InputDataIdentifier("_id_recent_separator")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
  
    
    
    let viewType: GeneralViewType = .modern(position: .last, insets: NSEdgeInsets(left: 10, right: 10, top: 4, bottom: 4))
    
    if !state.inProgressItems.isEmpty {
        for item in state.inProgressItems {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_downloading(item.message.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return PeerMediaFileRowItem(initialSize, arguments.interaction, .messageEntry(item.message, [], .defaultSettings, viewType), galleryType: .recentDownloaded, gallery: arguments.gallery, viewType: viewType)
            }))
            index += 1
        }
    }
    
    if !state.doneItems.isEmpty {
               
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_recent_separator, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return SeparatorRowItem(initialSize, stableId, string: strings().downloadsManagerRecently, right: strings().downloadsManagerRecentlyClear, state: .none, action: arguments.clearRecent, leftInset: 10, border: [.Right])
        }))
        index += 1
      
        
        for item in state.doneItems {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_recent(item.message.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return PeerMediaFileRowItem(initialSize, arguments.interaction, .messageEntry(item.message, [], .defaultSettings, viewType), galleryType: .recentDownloaded, gallery: arguments.gallery, viewType: viewType)
            }))
            index += 1
        }
    }
    
    
    return entries
}

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
                    if let item = item as? PeerMediaRowItem {
                        if item.message.id == message.id {
                            found = item.view?.interactionContentView(for: message.id, animateIn: animateIn)
                        }
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


func DownloadsController(context: AccountContext, searchValue: Signal<String, NoError>) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(doneItems: [], inProgressItems: [])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let interaction = ChatInteraction(chatLocation: .peer(.init(0)), context: context)

    interaction.focusMessageId = { _, focusTarget, animated in
        let navigation = context.bindings.rootNavigation()
        if let current = navigation.controller as? ChatController {
            if current.chatInteraction.peerId == focusTarget.messageId.peerId {
                current.chatInteraction.focusMessageId(nil, focusTarget, .center(id: AnyHashable(0), innerId: nil, animated: true, focus: .init(focus: true, action: nil), inset: 0))
            } else {
                navigateToChat(navigation: navigation, context: context, chatLocation: .peer(focusTarget.messageId.peerId), focusTarget: focusTarget)
            }
        } else {
            navigateToChat(navigation: navigation, context: context, chatLocation: .peer(focusTarget.messageId.peerId), focusTarget: focusTarget)
        }
        
    }
    interaction.forwardMessages = { messages in
        showModal(with: ShareModalController(ForwardMessagesObject(context, messages: messages)), for: context.window)
    }
    interaction.deleteMessages = { ids in
        let signal = context.account.postbox.transaction { transaction -> [Message] in
            return ids.compactMap { transaction.getMessage($0) }
        } |> mapToSignal { messages ->Signal<Float, NoError> in
            let ids = messages.compactMap { $0.file?.resource.id }
            return context.account.postbox.mediaBox.removeCachedResources(ids, force: true, notify: true)
        }
        _ = signal.start()
    }
    
    var gallery:((Message, GalleryAppearType)->Void)? = nil

    let arguments = Arguments(context: context, interaction: interaction, clearRecent: {
        _ = clearRecentDownloadList(postbox: context.account.postbox).start()
    }, gallery: { message, type in
        gallery?(message, type)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    
    let recentItems = recentDownloadItems(postbox: context.account.postbox) |> map { items in
        return items.compactMap { value in
            
            var media: Media = value.message.media.first!
            var resourceId = value.resourceId
            var size: Int64?
            if let file = media as? TelegramMediaFile {
                size = file.size
                if value.resourceId != file.resource.id.stringRepresentation {
                    for alternativeRepresentation in file.alternativeRepresentations {
                        if let alternative = alternativeRepresentation as? TelegramMediaFile {
                            if alternative.resource.id.stringRepresentation == value.resourceId {
                                media = alternative
                                resourceId = value.resourceId
                                size = value.size
                                break
                            }
                        }
                    }
                }
            }
            
            return RenderedRecentDownloadItem(message: value.message.withUpdatedMedia([media]), timestamp: value.timestamp, isSeen: value.isSeen, resourceId: resourceId, size: size ?? 0)
        }
    }
    
    let downloadItems: Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError>
    downloadItems = combineLatest(queue: .mainQueue(), (context.fetchManager as! FetchManagerImpl).entriesSummary, recentItems)
    |> mapToSignal { entries, recentDownloadItems -> Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError> in
        var itemSignals: [Signal<DownloadItem?, NoError>] = []
        
        for entry in entries {
            switch entry.id.locationKey {
            case let .messageId(id):
                itemSignals.append(context.account.postbox.transaction { transaction -> DownloadItem? in
                    if let message = transaction.getMessage(id) {
                        
                        var media: Media = message.media.first!
                        if let file = media as? TelegramMediaFile {
                            if file.resource.id != entry.resourceReference.resource.id {
                                for alternativeRepresentation in file.alternativeRepresentations {
                                    if let alternative = alternativeRepresentation as? TelegramMediaFile {
                                        if alternative.resource.id == entry.resourceReference.resource.id {
                                            media = alternative
                                            break
                                        }
                                    }
                                }
                            }
                        }
                        return DownloadItem(resourceId: entry.resourceReference.resource.id, message: message.withUpdatedMedia([media]), priority: entry.priority, isPaused: entry.isPaused)
                    }
                    return nil
                })
            default:
                break
            }
        }
        
        return combineLatest(queue: .mainQueue(), itemSignals)
        |> map { items -> (inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]) in
            return (items.compactMap { $0 }, recentDownloadItems)
        }
    }
        
    
    actionsDisposable.add(combineLatest(queue: .mainQueue(), searchValue, downloadItems).start(next: { search, values in
        
        let sf:(TelegramMediaFile)->Bool = { file -> Bool in
            if let filename = file.fileName {
                return filename.lowercased().hasPrefix(search.lowercased())
            } else {
                return true
            }
        }
        
        updateState { current in
            var current = current
            current.doneItems = values.doneItems.filter { $0.message.file != nil }.filter { sf($0.message.file!) }
            current.inProgressItems = values.inProgressItems.filter { $0.message.file != nil }.filter { sf($0.message.file!) }
            return current
        }
    }))
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    controller.bar = .init(height: 0)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.makeFirstResponder = false
    
    
    controller.didLoad = { controller, _ in
        controller.tableView.getBackgroundColor = {
            return theme.colors.background
        }
      //  controller.genericView.border = [.Right]
      //  controller.tableView.border = [.Right]
        
        let supplyment = GallerySupplyment(tableView: controller.tableView)
        
        controller.tableView.supplyment = supplyment
        
        gallery = { message, type in
            showChatGallery(context: context, message: message, supplyment, nil, type: type, chatMode: nil, chatLocation: nil)
        }
    }

    controller.afterTransaction = { controller in
        actionsDisposable.add(markAllRecentDownloadItemsAsSeen(postbox: context.account.postbox).start())
    }
    
    return controller
    
}
