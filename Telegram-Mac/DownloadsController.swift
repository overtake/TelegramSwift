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
    init(context: AccountContext, interaction: ChatInteraction, clearRecent:@escaping()->Void) {
        self.context = context
        self.interaction = interaction
        self.clearRecent = clearRecent
    }
}

private struct State : Equatable {
    var doneItems: [RenderedRecentDownloadItem]
    var inProgressItems: [DownloadItem]
}

private func _id_recent(_ messageId: MessageId) -> InputDataIdentifier {
    return .init("_id_recent_\(messageId.toInt64())")
}
private func _id_downloading(_ messageId: MessageId) -> InputDataIdentifier {
    return .init("_id_downloading\(messageId.toInt64())")
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
                return PeerMediaFileRowItem(initialSize, arguments.interaction, .messageEntry(item.message, [], .defaultSettings, viewType), gallery: .recentDownloaded, viewType: viewType)
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
                return PeerMediaFileRowItem(initialSize, arguments.interaction, .messageEntry(item.message, [], .defaultSettings, viewType), gallery: .recentDownloaded, viewType: viewType)
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

    interaction.focusMessageId = { _, messageId, animated in
        let navigation = context.bindings.rootNavigation()
        if let current = navigation.controller as? ChatController {
            if current.chatInteraction.peerId == messageId.peerId {
                current.chatInteraction.focusMessageId(nil, messageId, .center(id: AnyHashable(0), innerId: nil, animated: true, focus: .init(focus: true, action: nil), inset: 0))
            } else {
                navigation.push(ChatController(context: context, chatLocation: .peer(messageId.peerId), messageId: messageId))
            }
        } else {
            navigation.push(ChatController(context: context, chatLocation: .peer(messageId.peerId), messageId: messageId))
        }
        
    }
    interaction.forwardMessages = { ids in
        showModal(with: ShareModalController(ForwardMessagesObject(context, messageIds: ids)), for: context.window)
    }
    interaction.deleteMessages = { ids in
        let signal = context.account.postbox.transaction { transaction -> [Message] in
            return ids.compactMap { transaction.getMessage($0) }
        } |> mapToSignal { messages ->Signal<Float, NoError> in
            let ids = messages.compactMap { $0.file?.resource.id }
            return context.account.postbox.mediaBox.removeCachedResources(Set(ids), force: true, notify: true)
        }
        _ = signal.start()
    }

    let arguments = Arguments(context: context, interaction: interaction, clearRecent: {
        _ = clearRecentDownloadList(postbox: context.account.postbox).start()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let downloadItems: Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError>
    downloadItems = combineLatest(queue: .mainQueue(), (context.fetchManager as! FetchManagerImpl).entriesSummary, recentDownloadItems(postbox: context.account.postbox))
    |> mapToSignal { entries, recentDownloadItems -> Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError> in
        var itemSignals: [Signal<DownloadItem?, NoError>] = []
        
        for entry in entries {
            switch entry.id.locationKey {
            case let .messageId(id):
                itemSignals.append(context.account.postbox.transaction { transaction -> DownloadItem? in
                    if let message = transaction.getMessage(id) {
                        return DownloadItem(resourceId: entry.resourceReference.resource.id, message: message, priority: entry.priority, isPaused: entry.isPaused)
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
    
    
    controller.didLoaded = { controller, _ in
        controller.tableView.getBackgroundColor = {
            return theme.colors.background
        }
        controller.genericView.border = [.Right]
        controller.tableView.border = [.Right]
        controller.tableView.supplyment = GallerySupplyment(tableView: controller.tableView)
    }

    controller.afterTransaction = { controller in
        actionsDisposable.add(markAllRecentDownloadItemsAsSeen(postbox: context.account.postbox).start())
    }
    
    return controller
    
}
