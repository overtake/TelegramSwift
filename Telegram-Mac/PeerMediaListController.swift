//
//  PeerMediaListController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

enum PeerMediaSharedEntryStableId : Hashable {
    case messageId(MessageId)
    case search
    case emptySearch
    case date(MessageIndex)
    var hashValue: Int {
        switch self {
        case let .messageId(messageId):
            return messageId.hashValue
        case .date(let index):
            return index.hashValue
        case .search:
            return 0
        case .emptySearch:
            return 1
        }
    }
    
    static func ==(lhs:PeerMediaSharedEntryStableId, rhs: PeerMediaSharedEntryStableId) -> Bool {
        switch lhs {
        case let .messageId(lhsMessageId):
            if case let .messageId(rhsMessageId) = rhs, lhsMessageId == rhsMessageId {
                return true
            } else {
                return false
            }
        case .search:
            if case .search = rhs {
                return true
            } else {
                return false
            }
        case .date(let index):
            if case .date(index) = rhs {
                return true
            } else {
                return false
            }
        case .emptySearch:
            if case .emptySearch = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

enum PeerMediaSharedEntry : Comparable, Identifiable {
    case messageEntry(Message)
    case searchEntry(Bool)
    case emptySearchEntry
    case date(MessageIndex)
    var stableId: PeerMediaSharedEntryStableId {
        switch self {
        case let .messageEntry(message):
            return .messageId(message.id)
        case let .date(index):
            return .date(index)
        case .searchEntry:
            return .search
        case .emptySearchEntry:
            return .emptySearch
        }
    }
}

func <(lhs:PeerMediaSharedEntry, rhs: PeerMediaSharedEntry) -> Bool {
    switch lhs {
    case .searchEntry:
        if case .searchEntry = rhs {
            return true
        } else {
            return false
        }
    case .emptySearchEntry:
        switch rhs {
        case .searchEntry:
            return true
        default:
            return false
        }
    case .date(let lhsIndex):
        switch rhs {
        case .date(let rhsIndex):
            return lhsIndex < rhsIndex
        case let .messageEntry(rhsMessage):
            return lhsIndex < MessageIndex(rhsMessage)
        default:
            return true
        }
    case let .messageEntry(lhsMessage):
        switch rhs {
        case let .messageEntry(rhsMessage):
            return MessageIndex(lhsMessage) < MessageIndex(rhsMessage)
        default:
            if case .date(let rhsIndex) = rhs {
                return MessageIndex(lhsMessage) < rhsIndex
            }
            return true
        }
    }
}

func ==(lhs: PeerMediaSharedEntry, rhs: PeerMediaSharedEntry) -> Bool {
    switch lhs {
    case let .messageEntry(lhsMessage):
        if case let .messageEntry(rhsMessage) = rhs {
            if lhsMessage.id != rhsMessage.id {
                return false
            }
            
            if lhsMessage.stableVersion != rhsMessage.stableVersion {
                return false
            }
            return true
        } else {
            return false
        }
    case let .date(index):
        if case .date(index) = rhs {
            return true
        } else {
            return false
        }
    case let .searchEntry(lhsProgress):
        if case let .searchEntry(rhsProgress) = rhs {
            return lhsProgress == rhsProgress
        } else {
            return false
        }
    default :
        return lhs.stableId == rhs.stableId
    }
}


func convertEntries(from update: PeerMediaUpdate, timeDifference: TimeInterval) -> [PeerMediaSharedEntry] {
    var converted:[PeerMediaSharedEntry] = []
   
    for i in 0 ..< update.messages.count {
        
        let message = update.messages[i]
        
        let prev = i > 0 ? update.messages[i - 1] : nil
        let next = i < update.messages.count - 1 ? update.messages[i + 1] : nil
        

        
        if let nextMessage = next {
            let dateId = mediaDateId(for: message.timestamp - Int32(timeDifference))
            let nextDateId = mediaDateId(for: nextMessage.timestamp - Int32(timeDifference))
            if dateId != nextDateId {
                let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: INT32_MAX), timestamp: message.timestamp)
                converted.append(.date(index))
            }
        } else {
            var time = TimeInterval(message.timestamp)
            time -= timeDifference
            let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: INT32_MAX), timestamp: message.timestamp)
            converted.append(.date(index))
        }
        
        converted.append(.messageEntry(message))
    }

    if update.updateType == .search {
        converted.append(.searchEntry(false))
        if update.messages.isEmpty {
            converted.append(.emptySearchEntry)
        }
    } else if update.updateType == .loading {
         converted.append(.searchEntry(true))
         converted.append(.emptySearchEntry)
    } else if update.laterId == nil {
        if !update.messages.isEmpty {
            converted.append(.searchEntry(false))
        }
    }
   
    return converted.sorted(by: <)
}

fileprivate func preparedMediaTransition(from fromView:[PeerMediaSharedEntry]?, to toView:[PeerMediaSharedEntry], account:Account, initialSize:NSSize, interaction:ChatInteraction, animated:Bool, scroll:TableScrollState, tags:MessageTags, searchInteractions:SearchInteractions) -> TableUpdateTransition {
    let (removed,inserted,updated) = proccessEntries(fromView, right: toView, { (entry) -> TableRowItem in
        
        switch entry {
        case .messageEntry(let message):
            if tags == .file, message.media.first is TelegramMediaFile {
                return PeerMediaFileRowItem(initialSize, interaction, account, entry)
            } else if tags == .webPage, message.media.first is TelegramMediaWebpage {
                return PeerMediaWebpageRowItem(initialSize,interaction,account,entry)
            } else if tags == .music, message.media.first is TelegramMediaFile {
                return PeerMediaMusicRowItem(initialSize, interaction, account, entry)
            } else if !message.text.isEmpty {
                return PeerMediaWebpageRowItem(initialSize,interaction,account,entry)
            } else {
                return GeneralRowItem(initialSize, height: 1, stableId: entry.stableId)
            }
        case .date(let index):
            return PeerMediaDateItem(initialSize, index: index, stableId: entry.stableId)
        case let .searchEntry(isLoading):
            return SearchRowItem(initialSize, stableId: entry.stableId, searchInteractions: searchInteractions, isLoading: isLoading, inset: NSEdgeInsets(left: 10, right: 10, top: 10, bottom: 10))
        case .emptySearchEntry:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId)
        }
        
    })
    
    for item in inserted {
        _ = item.1.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    for item in updated {
        _ = item.1.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated:updated, animated:animated, state:scroll)
}

enum PeerMediaUpdateState {
    case search
    case history
    case loading
}

struct PeerMediaUpdate {
    let messages:[Message]
    let updateType: PeerMediaUpdateState
    let laterId: MessageIndex?
    let earlierId: MessageIndex?
    init (messages: [Message] = [], updateType:PeerMediaUpdateState = .loading, laterId:MessageIndex? = nil, earlierId:MessageIndex? = nil) {
        self.messages = messages
        self.updateType = updateType
        self.laterId = laterId
        self.earlierId = earlierId
    }
}



class PeerMediaListController: GenericViewController<TableView> {
    
    private var account:Account
    private var chatLocation:ChatLocation
    private var chatInteraction:ChatInteraction
    private let disposable: MetaDisposable = MetaDisposable()
    private let entires = Atomic<[PeerMediaSharedEntry]?>(value: nil)
    private let updateView = Atomic<PeerMediaUpdate?>(value: nil)
    private let searchState:ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)
    public init(account: Account, chatLocation: ChatLocation, chatInteraction: ChatInteraction) {
        self.account = account
        self.chatLocation = chatLocation
        self.chatInteraction = chatInteraction
        super.init()
    }
    
    
    deinit {
        disposable.dispose()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        genericView.stopMerge()
    }
    
    
    public func load(with tagMask:MessageTags) -> Void {
     
        
        let location = ValuePromise<ChatHistoryLocation>(ignoreRepeated: true)
        searchState.set(SearchState(state: .None, request: nil))
        genericView.emptyItem = PeerMediaEmptyRowItem(atomicSize.modify {$0}, tags: tagMask)

        let historyViewUpdate = combineLatest(location.get(), searchState.get()) |> deliverOnMainQueue
         |> mapToSignal { [weak self] location, searchState -> Signal<PeerMediaUpdate, NoError> in
            if let strongSelf = self {
                if searchState.request.isEmpty {
                    return chatHistoryViewForLocation(location, account: strongSelf.account, chatLocation: strongSelf.chatLocation, fixedCombinedReadStates: nil, tagMask: tagMask, additionalData: []) |> mapToQueue { view -> Signal<PeerMediaUpdate, Void> in
                        switch view {
                        case .Loading:
                            return .single(PeerMediaUpdate())
                        case let .HistoryView(view: view, type: _, scrollPosition: _, initialData: _):
                            var messages:[Message] = []
                            for entry in view.entries {
                                switch entry {
                                case let .MessageEntry(message, _, _, _):
                                    messages.append(message)
                                default:
                                    break
                                }
                            }
                            return .single(PeerMediaUpdate(messages: messages, updateType: .history, laterId: view.laterId, earlierId: view.earlierId))
                        }
                    }
                } else {
                    let searchMessagesLocation: SearchMessagesLocation
                    switch strongSelf.chatLocation {
                    case let .group(groupId):
                        searchMessagesLocation = .group(groupId)
                    case let .peer(peerId):
                        searchMessagesLocation = .peer(peerId: peerId, fromId: nil, tags: tagMask)
                    }
                    
                    return .single(PeerMediaUpdate()) |> then(searchMessages(account: strongSelf.account, location: searchMessagesLocation, query: searchState.request) |> deliverOnMainQueue |> map { messages -> PeerMediaUpdate in
                        return PeerMediaUpdate(messages: messages, updateType: .search, laterId: nil, earlierId: nil)
                    })
                }
            }
           
            return .complete()
        }
        
        let animated:Atomic<Bool> = Atomic(value:true)
        
        let searchInteractions = SearchInteractions({ [weak self] state in
            if let strongSelf = self {
                strongSelf.searchState.set(state)
            }
        }, { [weak self] (state) in
            if let strongSelf = self {
                strongSelf.searchState.set(state)
            }
        })
        let account = self.account
        let chatInteraction = self.chatInteraction
        let initialSize = self.atomicSize
        let _updateView = self.updateView
        let _entries = self.entires
        
        let historyViewTransition = historyViewUpdate |> deliverOnPrepareQueue |> map { update -> TableUpdateTransition in
            let animated = animated.swap(true)
            let scroll:TableScrollState = animated ? .none(nil) : .saveVisible(.upper)
            
            let entries = convertEntries(from: update, timeDifference: account.context.timeDifference)
            let previous = _entries.swap(entries)
            _ = _updateView.swap(update)
            
            return preparedMediaTransition(from: previous, to: entries, account: account, initialSize: initialSize.modify({$0}), interaction: chatInteraction, animated: animated, scroll:scroll, tags:tagMask, searchInteractions: searchInteractions)

        } |> deliverOnMainQueue
        
        
        disposable.set(historyViewTransition.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
        }))

        
        location.set(.Scroll(index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, sourceIndex: MessageHistoryAnchorIndex.upperBound, scrollPosition: .none(nil), count: 140, animated: false))
     
        genericView.setScrollHandler { [weak self] scroll in
            
            let view = self?.updateView.modify({$0})
            if let view = view, view.updateType == .history {
                var messageIndex:MessageIndex?
                switch scroll.direction {
                case .bottom:
                    messageIndex = view.earlierId
                case .top:
                    messageIndex = view.laterId
                case .none:
                    break
                }
                
                if let messageIndex = messageIndex {
                    let _ = animated.swap(false)
                    location.set(.Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: 140))
                }
            }
        }
        
    }
    
    
}




//                let view = strongSelf.messagesView.modify {$0}
//                if let view = view {
//                    let range = strongSelf.genericView.visibleRows()
//                    let indexRange = (max(view.entries.count - 1 - range.max,0), max(view.entries.count - 1 - range.min,0))
//
//                    if indexRange.1 > 0 {
//                        strongSelf.account.postbox.updateMessageHistoryViewVisibleRange(view.id, earliestVisibleIndex: view.entries[indexRange.0].index, latestVisibleIndex: view.entries[indexRange.1].index)
//                    }
//
//                }
                
