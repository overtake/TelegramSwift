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
    
}

enum PeerMediaSharedEntry : Comparable, Identifiable {
    case messageEntry(Message, AutomaticMediaDownloadSettings)
    case searchEntry(Bool)
    case emptySearchEntry(Bool)
    case date(MessageIndex)
    var stableId: PeerMediaSharedEntryStableId {
        switch self {
        case let .messageEntry(message, _):
            return .messageId(message.id)
        case let .date(index):
            return .date(index)
        case .searchEntry:
            return .search
        case .emptySearchEntry:
            return .emptySearch
        }
    }
    
    var message:Message? {
        switch self {
        case let .messageEntry(message, _):
            return message
        default:
            return nil
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
        case let .messageEntry(rhsMessage, _):
            return lhsIndex < MessageIndex(rhsMessage)
        default:
            return true
        }
    case let .messageEntry(lhsMessage, _):
        switch rhs {
        case let .messageEntry(rhsMessage, _):
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
    case let .messageEntry(lhsMessage, _):
        if case let .messageEntry(rhsMessage, _) = rhs {
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
    case let .emptySearchEntry(loading):
        if case .emptySearchEntry(loading) = rhs {
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
    }
}


func convertEntries(from update: PeerMediaUpdate, tags: MessageTags, timeDifference: TimeInterval) -> [PeerMediaSharedEntry] {
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
        
        converted.append(.messageEntry(message, update.automaticDownload))
    }

    if update.updateType == .search {
        if update.searchState.state == .None {
            converted.append(.searchEntry(false))
        }
        if update.messages.isEmpty {
            converted.append(.emptySearchEntry(false))
        }
    } else if update.updateType == .loading {
        if update.searchState.state == .None {
            if !tags.contains(.voiceOrInstantVideo) {
                converted.append(.searchEntry(true))
            }
        }
        if update.messages.isEmpty {
            converted.append(.emptySearchEntry(true))
        }
    } else if update.searchState.state == .None {
        if !update.messages.isEmpty && !tags.contains(.voiceOrInstantVideo) {
            converted.append(.searchEntry(false))
        }
    }
   
    return converted.sorted(by: <)
}

fileprivate func preparedMediaTransition(from fromView:[AppearanceWrapperEntry<PeerMediaSharedEntry>]?, to toView:[AppearanceWrapperEntry<PeerMediaSharedEntry>], account:Account, initialSize:NSSize, interaction:ChatInteraction, animated:Bool, scroll:TableScrollState, tags:MessageTags, searchInteractions:SearchInteractions) -> TableUpdateTransition {
    let (removed,inserted,updated) = proccessEntries(fromView, right: toView, { entry -> TableRowItem in
        
        switch entry.entry {
        case let .messageEntry(message, _):
            if tags == .file, message.media.first is TelegramMediaFile {
                return PeerMediaFileRowItem(initialSize, interaction, entry.entry)
            } else if tags == .webPage {
                return PeerMediaWebpageRowItem(initialSize,interaction, entry.entry)
            } else if tags == .music, message.media.first is TelegramMediaFile {
                return PeerMediaMusicRowItem(initialSize, interaction, entry.entry)
            } else if tags == .voiceOrInstantVideo, message.media.first is TelegramMediaFile {
                return PeerMediaVoiceRowItem(initialSize,interaction, entry.entry)
            } else {
                return GeneralRowItem(initialSize, height: 1, stableId: entry.stableId)
            }
        case .date(let index):
            return PeerMediaDateItem(initialSize, index: index, stableId: entry.stableId)
        case let .searchEntry(isLoading):
            return SearchRowItem(initialSize, stableId: entry.stableId, searchInteractions: searchInteractions, isLoading: isLoading, inset: NSEdgeInsets(left: 10, right: 10, top: 10, bottom: 10))
        case .emptySearchEntry:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId, isLoading: false)
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
    let automaticDownload: AutomaticMediaDownloadSettings
    let searchState: SearchState
    init (messages: [Message] = [], updateType:PeerMediaUpdateState = .loading, laterId:MessageIndex? = nil, earlierId:MessageIndex? = nil, automaticDownload: AutomaticMediaDownloadSettings = .defaultSettings, searchState: SearchState = SearchState(state: .None, request: nil)) {
        self.messages = messages
        self.updateType = updateType
        self.laterId = laterId
        self.earlierId = earlierId
        self.automaticDownload = automaticDownload
        self.searchState = searchState
    }
    
    func withUpdatedUpdatedType(_ updateType:PeerMediaUpdateState) -> PeerMediaUpdate {
        return PeerMediaUpdate(messages: self.messages, updateType: updateType, laterId: self.laterId, earlierId: self.earlierId, automaticDownload: self.automaticDownload, searchState: self.searchState)
    }
}


struct MediaSearchState : Equatable {
    let state: SearchState
    let animated: Bool
    let isLoading: Bool
    let view: SearchView?
}

class PeerMediaListController: GenericViewController<TableView> {
    
    private var context: AccountContext
    private var chatLocation:ChatLocation
    private var chatInteraction:ChatInteraction
    private let disposable: MetaDisposable = MetaDisposable()
    private let entires = Atomic<[AppearanceWrapperEntry<PeerMediaSharedEntry>]?>(value: nil)
    private let updateView = Atomic<PeerMediaUpdate?>(value: nil)
    private let mediaSearchState:ValuePromise<MediaSearchState> = ValuePromise(ignoreRepeated: true)
    private let searchState:ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)

    var mediaSearchValue:Signal<MediaSearchState, NoError> {
        return mediaSearchState.get()
    }

    
    public init(context: AccountContext, chatLocation: ChatLocation, chatInteraction: ChatInteraction) {
        self.context = context
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
    
    private var isFirst: Bool = true
    
    public func load(with tagMask:MessageTags) -> Void {
     
        
        
        genericView.clipView.scroll(to: NSMakePoint(0, 0), animated: false)

        let isFirst = self.isFirst
        self.isFirst = false
        
        let location = ValuePromise<ChatHistoryLocation>(ignoreRepeated: true)
        searchState.set(SearchState(state: .None, request: nil))
        genericView.emptyItem = PeerMediaEmptyRowItem(atomicSize.modify {$0}, tags: tagMask)

        genericView.set(stickClass: PeerMediaDateItem.self, handler: { item in
            
        })
        
        let historyPromise: Promise<PeerMediaUpdate> = Promise(PeerMediaUpdate())
        
        
        let historyViewUpdate = combineLatest(location.get(), searchState.get()) |> deliverOnMainQueue
         |> mapToSignal { [weak self] location, searchState -> Signal<PeerMediaUpdate, NoError> in
            if let strongSelf = self {
                if searchState.request.isEmpty {
                    return combineLatest(queue: prepareQueue, chatHistoryViewForLocation(location, account: strongSelf.context.account, chatLocation: strongSelf.chatLocation, fixedCombinedReadStates: nil, tagMask: tagMask, additionalData: []), automaticDownloadSettings(postbox: strongSelf.context.account.postbox)) |> mapToQueue { view, settings -> Signal<PeerMediaUpdate, NoError> in
                        switch view {
                        case .Loading:
                            return .single(PeerMediaUpdate())
                        case let .HistoryView(view: view, type: _, scrollPosition: _, initialData: _):
                            var messages:[Message] = []
                            for entry in view.entries {
                                messages.append(entry.message)
                            }
                            
                            let laterId = view.laterId
                            let earlierId = view.earlierId

                            return .single(PeerMediaUpdate(messages: messages, updateType: .history, laterId: laterId, earlierId: earlierId, automaticDownload: settings, searchState: searchState))
                        }
                    }
                } else {
                    let searchMessagesLocation: SearchMessagesLocation
                    switch strongSelf.chatLocation {
                    case let .peer(peerId):
                        searchMessagesLocation = .peer(peerId: peerId, fromId: nil, tags: tagMask)
                    }
                    
                    let signal = searchMessages(account: strongSelf.context.account, location: searchMessagesLocation, query: searchState.request, state: nil) |> deliverOnMainQueue |> map {$0.0.messages} |> map { messages -> PeerMediaUpdate in
                        return PeerMediaUpdate(messages: messages, updateType: .search, laterId: nil, earlierId: nil, searchState: searchState)
                    }
                    
                    let update = strongSelf.updateView.modify {$0?.withUpdatedUpdatedType(.loading)} ?? PeerMediaUpdate()
                    
                    if isFirst {
                        return .single(update) |> then(signal)
                    } else {
                        return .single(update) |> then(signal)
                    }
                    
                }
            }
           
            return .complete()
        }
        
        let animated:Atomic<Bool> = Atomic(value:false)
        
        let searchInteractions = SearchInteractions({ [weak self] state, _ in
            if let strongSelf = self {
                strongSelf.searchState.set(state)
            }
        }, { [weak self] (state) in
            if let strongSelf = self {
                strongSelf.searchState.set(state)
            }
        })
        let context = self.context
        let chatInteraction = self.chatInteraction
        let initialSize = self.atomicSize
        let _updateView = self.updateView
        let _entries = self.entires
        
        
        
        let historyViewTransition = combineLatest(queue: prepareQueue,historyPromise.get(), appearanceSignal) |> map { update, appearance -> (transition: TableUpdateTransition, previousUpdate: PeerMediaUpdate?, currentUpdate: PeerMediaUpdate) in
            let animated = animated.swap(true)
            let scroll:TableScrollState = animated ? .none(nil) : .saveVisible(.upper)
            
            let entries = convertEntries(from: update, tags: tagMask, timeDifference: context.timeDifference).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            let previous = _entries.swap(entries)
            let previousUpdate = _updateView.swap(update)
            
            let transition = preparedMediaTransition(from: previous, to: entries, account: context.account, initialSize: initialSize.modify({$0}), interaction: chatInteraction, animated: previousUpdate?.searchState.state != update.searchState.state, scroll:scroll, tags:tagMask, searchInteractions: searchInteractions)
            
            return (transition: transition, previousUpdate: previousUpdate, currentUpdate: update)

        } |> deliverOnMainQueue
        
        
        disposable.set(historyViewTransition.start(next: { [weak self] values in
            guard let `self` = self else {return}

           // CATransaction.begin()
//            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
//            CATransaction.setAnimationDuration(0.2)
            
            let searchView: SearchView? = (self.genericView.firstItem?.view as? SearchRowView)?.searchView
            
            
            searchView?.searchInteractions = searchInteractions
            
            let state = MediaSearchState(state: values.currentUpdate.searchState, animated: values.currentUpdate.searchState != values.previousUpdate?.searchState, isLoading: values.currentUpdate.updateType == .loading, view: searchView)
            self.genericView.merge(with: values.transition)
            self.mediaSearchState.set(state)
          // CATransaction.commit()
            
            if let controller = globalAudio {
                (self.navigationController?.header?.view as? InlineAudioPlayerView)?.update(with: controller, context: context, tableView: (self.navigationController?.first {$0 is ChatController} as? ChatController)?.genericView.tableView, supportTableView: self.genericView)
            }
        }))
        
        historyPromise.set(historyViewUpdate)

        
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
                    location.set(.Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: 140, side: scroll.direction == .bottom ? .lower : .upper))
                }
            }
        }
        
    }
    
    override func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> () -> Void {
        return {
            
        }
    }
    
    
}

