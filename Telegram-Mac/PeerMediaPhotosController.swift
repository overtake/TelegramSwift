//
//  PeerMediaPhotosController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.10.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
extension Message : Equatable {
    public static func ==(lhs: Message, rhs: Message) -> Bool {
        return isEqualMessages(lhs, rhs)
    }
}

private enum PeerMediaMonthEntry : TableItemListNodeEntry {
    case month(index: MessageIndex, items: [Message])
    case date(index: MessageIndex)
    case section(index: MessageIndex)
        
    static func < (lhs: PeerMediaMonthEntry, rhs: PeerMediaMonthEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy";
        switch self {
        case let .month(index, _):
            let date = Date(timeIntervalSince1970: TimeInterval(index.timestamp))
            return "items: \(formatter.string(from: date))"
        case let .date(index):
            let date = Date(timeIntervalSince1970: TimeInterval(index.timestamp))
            return "date: \(formatter.string(from: date))"
        case let .section(index):
            let date = Date(timeIntervalSince1970: TimeInterval(index.timestamp))
            return "section: \(formatter.string(from: date))"
        }
    }
    
    func item(_ arguments: PeerMediaPhotosArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .month(_, items):
            return PeerPhotosMonthItem(initialSize, stableId: stableId, context: arguments.context, chatInteraction: arguments.chatInteraction, gallerySupplyment: arguments.gallerySupplyment, items: items)
        case .date:
            return PeerMediaDateItem(initialSize, index: index, stableId: stableId)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        }
    }
    
    var stableId: MessageIndex {
        return self.index
    }
    
    var index: MessageIndex {
        switch self {
        case let .month(index, _):
            return index
        case let .date(index):
            return index
        case let .section(index):
            return index
        }
    }
}

private final class PeerMediaPhotosArguments {
    let context: AccountContext
    let chatInteraction: ChatInteraction
    let gallerySupplyment: InteractionContentViewProtocol
    init(context: AccountContext, chatInteraction: ChatInteraction, gallerySupplyment: InteractionContentViewProtocol) {
        self.context = context
        self.gallerySupplyment = gallerySupplyment
        self.chatInteraction = chatInteraction
    }
}



private struct PeerMediaPhotosState : Equatable {
    let isLoading: Bool
    let messages:[Message]
    init(isLoading: Bool, messages: [Message]) {
        self.isLoading = isLoading
        self.messages = messages.reversed()
    }
    func withAppendMessages(_ collection: [Message]) -> PeerMediaPhotosState {
        var messages = self.messages
        messages.append(contentsOf: collection)
        return PeerMediaPhotosState(isLoading: self.isLoading, messages: messages)
    }
    func withUpdatedMessages(_ collection: [Message]) -> PeerMediaPhotosState {
        return PeerMediaPhotosState(isLoading: self.isLoading, messages: collection)
    }
    func withUpdatedLoading(_ isLoading: Bool) -> PeerMediaPhotosState {
        return PeerMediaPhotosState(isLoading: isLoading, messages: self.messages)
    }
}

private func mediaEntires(state: PeerMediaPhotosState, arguments: PeerMediaPhotosArguments) -> [PeerMediaMonthEntry] {
    var entries:[PeerMediaMonthEntry] = []

    let timeDifference = Int32(arguments.context.timeDifference)
    var temp:[Message] = []
    for i in 0 ..< state.messages.count {
        
        let message = state.messages[i]
    
        temp.append(message)
        let next = i < state.messages.count - 1 ? state.messages[i + 1] : nil
        if let nextMessage = next {
            let dateId = mediaDateId(for: message.timestamp - timeDifference)
            let nextDateId = mediaDateId(for: nextMessage.timestamp - timeDifference)
            if dateId != nextDateId {
                let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: 0), timestamp: Int32(dateId))
                entries.append(.section(index: index.successor()))
                entries.append(.date(index: index))
                entries.append(.month(index: index.predecessor(), items: temp))
                temp.removeAll()
            }
        } else {
            let dateId = mediaDateId(for: message.timestamp - timeDifference)
            let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: 0), timestamp: Int32(dateId))
            
            if !entries.isEmpty {
                switch entries[entries.count - 1] {
                case let .month(prevIndex, items):
                    let prevDateId = mediaDateId(for: prevIndex.timestamp)
                    if prevDateId != dateId {
                        entries.append(.section(index: index.successor()))
                        entries.append(.date(index: index))
                        entries.append(.month(index: index.predecessor(), items: temp))
                    } else {
                        entries[entries.count - 1] = .month(index: prevIndex, items: items + temp)
                    }
                default:
                    assertionFailure()
                }
            } else {
                entries.append(.section(index: index.successor()))
                entries.append(.date(index: index))
                entries.append(.month(index: index.predecessor(), items: temp))
            }
            
        }
    }
    if !state.messages.isEmpty {
        entries.append(.section(index: MessageIndex.absoluteLowerBound()))
    }

    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PeerMediaMonthEntry>], right: [AppearanceWrapperEntry<PeerMediaMonthEntry>], animated: Bool, initialSize:NSSize, arguments: PeerMediaPhotosArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated)
}


private final class PeerMediaSupplyment : InteractionContentViewProtocol {
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
                    if let item = item as? PeerPhotosMonthItem {
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

class PeerMediaPhotosController: TableViewController {
    private let peerId: PeerId
    private let disposable = MetaDisposable()
    private let historyDisposable = MetaDisposable()
    private let chatInteraction: ChatInteraction
    private let previous: Atomic<[AppearanceWrapperEntry<PeerMediaMonthEntry>]> = Atomic(value: [])
    init(_ context: AccountContext, chatInteraction: ChatInteraction, peerId: PeerId) {
        self.peerId = peerId
        self.chatInteraction = chatInteraction
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let peerId = self.peerId
        let initialSize = self.atomicSize

        self.genericView.set(stickClass: PeerMediaDateItem.self, handler: { item in
            
        })
        
        self.genericView.emptyItem = PeerMediaEmptyRowItem(NSZeroSize, tags: .photoOrVideo)
        
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

        var requestCount = perPageCount()
        
        let location: ValuePromise<ChatHistoryLocation> = ValuePromise(.Initial(count: requestCount), ignoreRepeated: true)
        
        let initialState = PeerMediaPhotosState(isLoading: false, messages: [])
        let state: ValuePromise<PeerMediaPhotosState> = ValuePromise()
        let stateValue: Atomic<PeerMediaPhotosState> = Atomic(value: initialState)
        let updateState:((PeerMediaPhotosState)->PeerMediaPhotosState) -> Void = { f in
            state.set(stateValue.modify(f))
        }
        
        let supplyment = PeerMediaSupplyment(tableView: genericView)
        
        let arguments = PeerMediaPhotosArguments(context: context, chatInteraction: chatInteraction, gallerySupplyment: supplyment)
        
        
        let applyHole:() -> Void = {
            location.set(.Initial(count: requestCount))
        }
        
        let history = location.get() |> mapToSignal { location in
            return chatHistoryViewForLocation(location, account: context.account, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tagMask: [.photoOrVideo])
        }
        
        historyDisposable.set(history.start(next: { update in
            
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
        
        let transition: Signal<TableUpdateTransition, NoError> = combineLatest(queue: queue, state.get(), appearanceSignal) |> mapToSignal { state, appearance in
            let entries = mediaEntires(state: state, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return .single(prepareTransition(left: previous.swap(entries), right: entries, animated: true, initialSize: initialSize.with { $0 }, arguments: arguments))
        } |> deliverOnMainQueue
        
        
        
        disposable.set(transition.start(next: { [weak self] transition in
            guard let `self` = self else {
                return
            }
            self.genericView.merge(with: transition)
            self.readyOnce()
        }))
        
        genericView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                requestCount += perPageCount() * 10
                location.set(.Initial(count: requestCount))
            default:
                break
            }
        }
    }
    
    deinit {
        disposable.dispose()
        historyDisposable.dispose()
        _ = previous.swap([])
    }
    
}
