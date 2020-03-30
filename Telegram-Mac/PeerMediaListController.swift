//
//  PeerMediaListController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

enum PeerMediaSharedEntryStableId : Hashable {
    case messageId(MessageId)
    case search
    case emptySearch
    case date(MessageIndex)
    case sectionId(MessageIndex)
    var hashValue: Int {
        return 0
    }
    
}

private func bestGeneralViewType(_ array:[PeerMediaSharedEntry], for item: PeerMediaSharedEntry) -> GeneralViewType {
    for _ in array {
        if item == array.first && item == array.last {
            return .modern(position: .single, insets: NSEdgeInsetsMake(7, 7, 7, 12))
        } else if item == array.first {
            return .modern(position: .first, insets: NSEdgeInsetsMake(7, 7, 7, 12))
        } else if item == array.last {
            return .modern(position: .last, insets: NSEdgeInsetsMake(7, 7, 7, 12))
        } else {
            return .modern(position: .inner, insets: NSEdgeInsetsMake(7, 7, 7, 12))
        }
    }
    return .modern(position: .single, insets: NSEdgeInsetsMake(6, 6, 6, 12))
}

enum PeerMediaSharedEntry : Comparable, Identifiable {
    case messageEntry(Message, AutomaticMediaDownloadSettings, GeneralViewType)
    case emptySearchEntry(Bool)
    case date(MessageIndex)
    case sectionId(MessageIndex)
    var stableId: AnyHashable {
        switch self {
        case let .messageEntry(message, _, _):
            return PeerMediaSharedEntryStableId.messageId(message.id)
        case let .date(index):
            return PeerMediaSharedEntryStableId.date(index)
        case let .sectionId(index):
            return PeerMediaSharedEntryStableId.sectionId(index)
        case .emptySearchEntry:
            return PeerMediaSharedEntryStableId.emptySearch
        }
    }
    
    var index: MessageIndex {
        switch self {
        case let .date(index):
            return index
        case let .sectionId(index):
            return index
        case let .messageEntry(message, _, _):
            return MessageIndex(message).predecessor()
        case .emptySearchEntry:
            return MessageIndex.absoluteLowerBound()
        }
    }
    
    var message:Message? {
        switch self {
        case let .messageEntry(message, _, _):
            return message
        default:
            return nil
        }
    }
}

func <(lhs:PeerMediaSharedEntry, rhs: PeerMediaSharedEntry) -> Bool {
    return lhs.index < rhs.index
}


func convertEntries(from update: PeerMediaUpdate, tags: MessageTags, timeDifference: TimeInterval) -> [PeerMediaSharedEntry] {
    var converted:[PeerMediaSharedEntry] = []
   
    
    struct Item {
        let date: PeerMediaSharedEntry
        let section: PeerMediaSharedEntry
        let items:[PeerMediaSharedEntry]
        init(_ date: PeerMediaSharedEntry, _ section: PeerMediaSharedEntry, _ items: [PeerMediaSharedEntry]) {
            self.date = date
            self.section = section
            self.items = items.sorted(by: >)
        }
    }
    
    
    var tempItems:[(PeerMediaSharedEntry, PeerMediaSharedEntry?)] = []
    
    for i in 0 ..< update.messages.count {
        
        let message = update.messages[i]
        
        let next = i < update.messages.count - 1 ? update.messages[i + 1] : nil
        

        
        if let nextMessage = next {
            let dateId = mediaDateId(for: message.timestamp - Int32(timeDifference))
            let nextDateId = mediaDateId(for: nextMessage.timestamp - Int32(timeDifference))
            if dateId != nextDateId {
                let index = MessageIndex(id: message.id, timestamp: Int32(dateId))
                tempItems.append((.date(index), .sectionId(index.successor())))
            }
        } else {
            let dateId = mediaDateId(for: message.timestamp - Int32(timeDifference))
            let index = MessageIndex(id: message.id, timestamp: Int32(dateId))
            tempItems.append((.date(index), .sectionId(index.successor())))
        }
        tempItems.append((.messageEntry(message, update.automaticDownload, .singleItem), nil))

    }
    
    
    var groupItems:[Item] = []
    var current:[PeerMediaSharedEntry] = []
    for item in tempItems.sorted(by: { $0.0 < $1.0 }) {
        switch item.0 {
        case .date:
            if !current.isEmpty {
                groupItems.append(Item(item.0, item.1!, current))
                current.removeAll()
            }
        case .messageEntry:
            current.insert(item.0, at: 0)
        default:
            fatalError()
        }
    }
    
    
    
    for (i, group) in groupItems.reversed().enumerated() {
        if i != 0 {
            converted.append(group.section)
            converted.append(group.date)
        }
      
        
        for item in group.items {
            switch item {
            case let .messageEntry(message, settings, _):
                var viewType = bestGeneralViewType(group.items, for: item)
                
                if i == 0, item == group.items.first {
                    if group.items.count > 1 {
                        viewType = .modern(position: .inner, insets: NSEdgeInsetsMake(7, 7, 7, 12))
                    } else {
                        viewType = .modern(position: .last, insets: NSEdgeInsetsMake(7, 7, 7, 12))
                    }
                }
                
                converted.append(.messageEntry(message, settings, viewType))
            default:
                fatalError()
            }
        }
    }
    
   
    
    if !tempItems.isEmpty {
        converted.append(.sectionId(MessageIndex.absoluteLowerBound()))
    }

    if update.updateType == .search {
        if converted.isEmpty {
            converted.append(.emptySearchEntry(false))
        }
    } else if update.updateType == .loading {
        if converted.isEmpty {
            converted.append(.emptySearchEntry(true))
        }
    }
    converted = converted.sorted(by: <)

  
    
    return converted
}

fileprivate func preparedMediaTransition(from fromView:[AppearanceWrapperEntry<PeerMediaSharedEntry>]?, to toView:[AppearanceWrapperEntry<PeerMediaSharedEntry>], account:Account, initialSize:NSSize, interaction:ChatInteraction, animated:Bool, scroll:TableScrollState, tags:MessageTags, searchInteractions:SearchInteractions) -> TableUpdateTransition {
    let (removed,inserted,updated) = proccessEntries(fromView, right: toView, { entry -> TableRowItem in
        
        switch entry.entry {
        case let .messageEntry(message, _, viewType):
            if tags == .file, message.media.first is TelegramMediaFile {
                return PeerMediaFileRowItem(initialSize, interaction, entry.entry, viewType: viewType)
            } else if tags == .webPage {
                return PeerMediaWebpageRowItem(initialSize,interaction, entry.entry, viewType: viewType)
            } else if tags == .music, message.media.first is TelegramMediaFile {
                return PeerMediaMusicRowItem(initialSize, interaction, entry.entry, viewType: viewType)
            } else if tags == .voiceOrInstantVideo, message.media.first is TelegramMediaFile {
                return PeerMediaVoiceRowItem(initialSize,interaction, entry.entry, viewType: viewType)
            } else {
                return GeneralRowItem(initialSize, height: 1, stableId: entry.stableId)
            }
        case .date(let index):
            return PeerMediaDateItem(initialSize, index: index, stableId: entry.stableId)
        case .sectionId:
            return GeneralRowItem(initialSize, height: 20, stableId: entry.stableId, viewType: .separator)
        case .emptySearchEntry:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId, isLoading: false, viewType: .separator)
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
}

class PeerMediaListController: TableViewController {
    
    private var chatLocation:ChatLocation
    private var chatInteraction:ChatInteraction
    private let disposable: MetaDisposable = MetaDisposable()
    private let entires = Atomic<[AppearanceWrapperEntry<PeerMediaSharedEntry>]?>(value: nil)
    private let updateView = Atomic<PeerMediaUpdate?>(value: nil)
    private let mediaSearchState:ValuePromise<MediaSearchState> = ValuePromise(ignoreRepeated: true)
    let searchState:ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)

    var mediaSearchValue:Signal<MediaSearchState, NoError> {
        return mediaSearchState.get()
    }
    private var isSearch: Bool = false {
        didSet {
            if isSearch {
                searchState.set(.init(state: .Focus, request: nil))
            } else {
                searchState.set(.init(state: .None, request: nil))
            }
        }
    }
    func toggleSearch() {
        let old = self.isSearch
        self.isSearch = !old
    }

    
    public init(context: AccountContext, chatLocation: ChatLocation, chatInteraction: ChatInteraction) {
        self.chatLocation = chatLocation
        self.chatInteraction = chatInteraction
        super.init(context)
    }
    
    
    deinit {
        disposable.dispose()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        if let stableId = stableId.base as? ChatHistoryEntryId {
            switch stableId {
            case let .message(message):
                return PeerMediaSharedEntryStableId.messageId(message.id)
            default:
                break
            }
        }
        return nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        genericView.stopMerge()
    }
    
    private var isFirst: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
    }
    
    public func load(with tagMask:MessageTags) -> Void {
     
        
        
        genericView.clipView.scroll(to: NSMakePoint(0, 0), animated: false)

        let isFirst = self.isFirst
        self.isFirst = false
        
        let location = ValuePromise<ChatHistoryLocation>(ignoreRepeated: true)
        searchState.set(SearchState(state: .None, request: nil))
        genericView.emptyItem = PeerMediaEmptyRowItem(atomicSize.modify {$0}, tags: tagMask)

        genericView.set(stickClass: PeerMediaDateItem.self, handler: { item in
            
        })
        
        let historyPromise: Promise<PeerMediaUpdate> = Promise()
        
        
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
            var scroll:TableScrollState = animated ? .none(nil) : .saveVisible(.upper)
            
            
            
            let entries = convertEntries(from: update, tags: tagMask, timeDifference: context.timeDifference).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            let previous = _entries.swap(entries)
            let previousUpdate = _updateView.swap(update)
            
            if previousUpdate?.searchState != update.searchState {
                scroll = .up(animated)
            }
            
            let transition = preparedMediaTransition(from: previous, to: entries, account: context.account, initialSize: initialSize.modify({$0}), interaction: chatInteraction, animated: previousUpdate?.searchState.state != update.searchState.state, scroll:scroll, tags:tagMask, searchInteractions: searchInteractions)
            
            return (transition: transition, previousUpdate: previousUpdate, currentUpdate: update)

        } |> deliverOnMainQueue
        
        
        disposable.set(historyViewTransition.start(next: { [weak self] values in
            guard let `self` = self else {return}
            
            let state = MediaSearchState(state: values.currentUpdate.searchState, animated: values.currentUpdate.searchState != values.previousUpdate?.searchState, isLoading: values.currentUpdate.updateType == .loading)
            self.genericView.merge(with: values.transition)
            self.mediaSearchState.set(state)
            self.readyOnce()
            if let controller = globalAudio {
                (self.navigationController?.header?.view as? InlineAudioPlayerView)?.update(with: controller, context: context, tableView: (self.navigationController?.first {$0 is ChatController} as? ChatController)?.genericView.tableView, supportTableView: self.genericView)
            }
        }))
        
        historyPromise.set(historyViewUpdate)

        
        let perPageCount:()->Int = { [weak self] in
            guard let `self` = self else {
                return 0
            }
            return Int(self.frame.height / 50)
        }
        
        var requestCount: Int = perPageCount() + 5
        
        
        location.set(.Initial(count: requestCount))
     
        genericView.setScrollHandler { [weak self] scroll in
            switch scroll.direction {
            case .bottom:
                animated.swap(false)
                requestCount += perPageCount() * 3
                location.set(.Initial(count: requestCount))
            default:
                break
            }
        }
        
    }
    
    override func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> () -> Void {
        return {
            
        }
    }
    
}

