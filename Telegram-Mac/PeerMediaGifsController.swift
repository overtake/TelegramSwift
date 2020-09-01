//
//  PeerMediaGifsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/05/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import SyncCore

private final class PeerMediaGifsArguments {
    let context: AccountContext
    let chatInteraction: ChatInteraction
    let gallerySupplyment: InteractionContentViewProtocol
    let openMessage: (Message)->Void
    let menuItems:(Message, NSView)->Signal<[ContextMenuItem], NoError>
    init(context: AccountContext, chatInteraction: ChatInteraction, gallerySupplyment: InteractionContentViewProtocol, openMessage: @escaping(Message)->Void, menuItems: @escaping(Message, NSView)->Signal<[ContextMenuItem], NoError>) {
        self.context = context
        self.gallerySupplyment = gallerySupplyment
        self.chatInteraction = chatInteraction
        self.menuItems = menuItems
        self.openMessage = openMessage
    }
}


final class PeerMediaGifsView : View {
    let tableView: TableView = TableView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
}

private func mediaEntires(state: PeerMediaGifsState, initialSize: NSSize) -> [InputContextEntry] {
    
    let values = makeChatGridMediaEnties(state.messages, initialSize: NSMakeSize(initialSize.width, 100))
    
    var wrapped:[InputContextEntry] = []
    for value in values {
        wrapped.append(InputContextEntry.contextMediaResult(nil, value, Int64(arc4random()) | ((Int64(wrapped.count) << 40))))
    }
    
    return wrapped
}


private struct PeerMediaGifsState : Equatable {
    let isLoading: Bool
    let messages:[Message]
    init(isLoading: Bool, messages: [Message]) {
        self.isLoading = isLoading
        self.messages = messages.reversed()
    }
    func withAppendMessages(_ collection: [Message]) -> PeerMediaGifsState {
        var messages = self.messages
        messages.append(contentsOf: collection)
        return PeerMediaGifsState(isLoading: self.isLoading, messages: messages)
    }
    func withUpdatedMessages(_ collection: [Message]) -> PeerMediaGifsState {
        return PeerMediaGifsState(isLoading: self.isLoading, messages: collection)
    }
    func withUpdatedLoading(_ isLoading: Bool) -> PeerMediaGifsState {
        return PeerMediaGifsState(isLoading: isLoading, messages: self.messages)
    }
}

private final class PeerMediaGifsSupplyment : InteractionContentViewProtocol {
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
                    if let item = item as? ContextMediaRowItem {
                        if item.contains(message.id) {
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
        if let stableId = stableId.base as? ChatHistoryEntryId, let tableView = tableView {
            switch stableId {
            case let .message(message):
                tableView.enumerateItems { item -> Bool in
                    if let item = item as? PeerPhotosMonthItem {
                        if item.contains(message.id) {
                            item.view?.addAccesoryOnCopiedView(innerId: message.id, view: view)
                            return false
                        }
                    }
                    return true
                }
            default:
                break
            }
        }
    }
    func videoTimebase(for stableId: AnyHashable) -> CMTimebase? {
        return nil
    }
    func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?) {
        
    }
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<InputContextEntry>], right: [AppearanceWrapperEntry<InputContextEntry>], animated: Bool, initialSize:NSSize, arguments: PeerMediaGifsArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        switch entry.entry {
        case let .contextMediaResult(_, row, index):
            return ContextMediaRowItem(initialSize, row, index, arguments.context, ContextMediaArguments(openMessage: arguments.openMessage, messageMenuItems: arguments.menuItems))
        default:
            fatalError("not supported")
        }
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated)
}

class PeerMediaGifsController: TelegramGenericViewController<PeerMediaGifsView> {

    private let peerId: PeerId
    private let historyDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    private let chatInteraction: ChatInteraction
    private let previous: Atomic<[AppearanceWrapperEntry<InputContextEntry>]> = Atomic(value: [])
    init(_ context: AccountContext, chatInteraction: ChatInteraction, peerId: PeerId) {
        self.peerId = peerId
        self.chatInteraction = chatInteraction
        super.init(context)
    }
    
    deinit {
        historyDisposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let peerId = self.peerId
        let initialSize = self.atomicSize
        let chatInteraction = self.chatInteraction
        
        
        self.genericView.tableView.emptyItem = PeerMediaEmptyRowItem(NSZeroSize, tags: .gif)
        
        let perPageCount:()->Int = {
            var rowCount:Int = 4
            var perWidth: CGFloat = 0
            let blockWidth = min(600, initialSize.with { $0.width } - 60)
            while true {
                let maximum = blockWidth - 7 - 7 - CGFloat(rowCount * 2)
                perWidth = maximum / CGFloat(rowCount)
                if perWidth >= 90 {
                    break
                } else {
                    rowCount -= 1
                }
            }
            return Int((initialSize.with { $0.height } / perWidth) * CGFloat(rowCount) + CGFloat(rowCount))
        }
        
        var requestCount = perPageCount() + 20
        
        let location: ValuePromise<ChatHistoryLocation> = ValuePromise(.Initial(count: requestCount), ignoreRepeated: true)
        
        let initialState = PeerMediaGifsState(isLoading: false, messages: [])
        let state: ValuePromise<PeerMediaGifsState> = ValuePromise()
        let stateValue: Atomic<PeerMediaGifsState> = Atomic(value: initialState)
        let updateState:((PeerMediaGifsState)->PeerMediaGifsState) -> Void = { f in
            state.set(stateValue.modify(f))
        }
        
        let supplyment = PeerMediaGifsSupplyment(tableView: genericView.tableView)
        
        let arguments = PeerMediaGifsArguments(context: context, chatInteraction: chatInteraction, gallerySupplyment: supplyment, openMessage: { message in
            showChatGallery(context: context, message: message, supplyment, nil, type: .history, reversed: true)
        }, menuItems: { message, view in
            return .single([])
        })
        
        
        let applyHole:() -> Void = {
            location.set(.Initial(count: requestCount))
        }
        
        let history = location.get() |> mapToSignal { location in
            return chatHistoryViewForLocation(location, context: context, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tagMask: [.gif])
        }
        
        self.historyDisposable.set(history.start(next: { update in
            
            let isLoading: Bool
            let view: MessageHistoryView?
            let updateType: ChatHistoryViewUpdateType
            switch update {
            case let .Loading(_, ut):
                view = nil
                isLoading = true
                updateType = ut
            case let .HistoryView(values):
                view = values.view
                isLoading = values.view.isLoading
                updateType = values.type
            }
            
            switch updateType {
            case let .Generic(type: type):
                switch type {
                case .FillHole:
                    DispatchQueue.main.async(execute: applyHole)
                default:
                    break
                }
            default:
                break
            }
            let messages = view?.entries.map { value in
                return value.message
                } ?? []
            
            updateState {
                $0.withUpdatedMessages(messages).withUpdatedLoading(false).withUpdatedLoading(isLoading)
            }
        }))
        
        let previous = self.previous
        
        let transition: Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, state.get(), appearanceSignal) |> mapToSignal { state, appearance in
            let entries = mediaEntires(state: state, initialSize: initialSize.with { $0 }).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return .single(prepareTransition(left: previous.swap(entries), right: entries, animated: true, initialSize: initialSize.with { $0 }, arguments: arguments))
            } |> deliverOnMainQueue
        
        
        
        disposable.set(transition.start(next: { [weak self] transition in
            guard let `self` = self else {
                return
            }
            self.genericView.tableView.merge(with: transition)
            self.readyOnce()
        }))
        
        genericView.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                requestCount += perPageCount() * 10
                location.set(.Initial(count: requestCount))
            default:
                break
            }
        }
    }
}
