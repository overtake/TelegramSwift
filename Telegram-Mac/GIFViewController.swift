//
//  GIFViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

func requestContextResults(account: Account, botId: PeerId, query: String, peerId: PeerId, offset: String = "", existingResults: ChatContextResultCollection? = nil, limit: Int = 60) -> Signal<ChatContextResultCollection?, NoError> {
    return requestChatContextResults(account: account, botId: botId, peerId: peerId, query: query, offset: offset)
        |> `catch` { error -> Signal<ChatContextResultCollection?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { results -> Signal<ChatContextResultCollection?, NoError> in
            var collection = existingResults
            var updated: Bool = false
            if let existingResults = existingResults, let results = results {
                var newResults: [ChatContextResult] = []
                var existingIds = Set<String>()
                for result in existingResults.results {
                    newResults.append(result)
                    existingIds.insert(result.id)
                }
                for result in results.results {
                    if !existingIds.contains(result.id) {
                        newResults.append(result)
                        existingIds.insert(result.id)
                        updated = true
                    }
                }
                collection = ChatContextResultCollection(botId: existingResults.botId, peerId: existingResults.peerId, query: existingResults.query, geoPoint: existingResults.geoPoint, queryId: results.queryId, nextOffset: results.nextOffset, presentation: existingResults.presentation, switchPeer: existingResults.switchPeer, results: newResults, cacheTimeout: existingResults.cacheTimeout)
            } else {
                collection = results
                updated = true
            }
            if let collection = collection, collection.results.count < limit, let nextOffset = collection.nextOffset, updated {
                let nextResults = requestContextResults(account: account, botId: botId, query: query, peerId: peerId, offset: nextOffset, existingResults: collection, limit: limit)
                if collection.results.count > 10 {
                    return .single(collection)
                        |> then(nextResults)
                } else {
                    return nextResults
                }
            } else {
                return .single(collection)
            }
    }
}




func paneGifSearchForQuery(account: Account, query: String, offset: String?, updateActivity: ((Bool) -> Void)?) -> Signal<ChatContextResultCollection?, NoError> {
    let delayRequest = true
    
    let contextBot = account.postbox.transaction { transaction -> String in
        let configuration = currentSearchBotsConfiguration(transaction: transaction)
        return configuration.gifBotUsername ?? "gif"
        }
        |> mapToSignal { botName -> Signal<PeerId?, NoError> in
            return resolvePeerByName(account: account, name: botName)
        }
        |> mapToSignal { peerId -> Signal<Peer?, NoError> in
            if let peerId = peerId {
                return account.postbox.loadedPeerWithId(peerId)
                    |> map { peer -> Peer? in
                        return peer
                    }
                    |> take(1)
            } else {
                return .single(nil)
            }
        }
        |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> in
            if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                let results = requestContextResults(account: account, botId: user.id, query: query, peerId: account.peerId, offset: offset ?? "", limit: 50)
                    |> map { results -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                        return { _ in
                            return .contextRequestResult(user, results)
                        }
                }
                
                let botResult: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .single({ previousResult in
                    var passthroughPreviousResult: ChatContextResultCollection?
                    if let previousResult = previousResult {
                        if case let .contextRequestResult(previousUser, previousResults) = previousResult {
                            if previousUser.id == user.id {
                                passthroughPreviousResult = previousResults
                            }
                        }
                    }
                    return .contextRequestResult(user, passthroughPreviousResult)
                })
                
                let maybeDelayedContextResults: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>
                if delayRequest {
                    maybeDelayedContextResults = results |> delay(0.4, queue: Queue.concurrentDefaultQueue())
                } else {
                    maybeDelayedContextResults = results
                }
                
                return botResult |> then(maybeDelayedContextResults)
            } else {
                return .single({ _ in return nil })
            }
    }
    return contextBot |> map { result in
        if let r = result(nil), case let .contextRequestResult(_, collection) = r {
            return collection
        } else {
            return nil
        }
    }
    |> beforeStarted {
        updateActivity?(true)
    }
    |> afterCompleted {
        updateActivity?(false)
    }
}



struct GIFKeyboardConfiguration : Equatable {
    static var defaultValue: GIFKeyboardConfiguration {
        return GIFKeyboardConfiguration(emojis: [])
    }
    
    let emojis: [String]
    
    fileprivate init(emojis: [String]) {
        self.emojis = emojis.map { $0.fixed }
    }
    
    static func with(appConfiguration: AppConfiguration) -> GIFKeyboardConfiguration {
        if let data = appConfiguration.data, let value = data["gif_search_emojies"] as? [String] {
            return GIFKeyboardConfiguration(emojis: value.map { $0.fixed })
        } else {
            return .defaultValue
        }
    }
    
}

private func prepareEntries(left:[InputContextEntry], right:[InputContextEntry], context: AccountContext,  initialSize:NSSize, arguments: RecentGifsArguments?) -> TableUpdateTransition {
   let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
        switch entry {
        case let .contextMediaResult(collection, row, index):
            return ContextMediaRowItem(initialSize, row, index, context, ContextMediaArguments(sendResult: { result, view in
                if let collection = collection {
                    arguments?.sendInlineResult(collection, result, view)
                } else {
                    switch result {
                    case let .internalReference(values):
                        if let file = values.file {
                            arguments?.sendAppFile(file, view, false)
                        }
                    default:
                        break
                    }
                }
            }, menuItems: { file, view in
                return context.account.postbox.transaction { transaction -> [ContextMenuItem] in
                    var items: [ContextMenuItem] = []
                    if let mediaId = file.id {
                        let gifItems = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).compactMap {$0.contents as? RecentMediaItem}
                        if let _ = gifItems.firstIndex(where: {$0.media.id == mediaId}) {
                            items.append(ContextMenuItem(L10n.messageContextRemoveGif, handler: {
                                let _ = removeSavedGif(postbox: context.account.postbox, mediaId: mediaId).start()
                            }))
                        } else {
                            items.append(ContextMenuItem(L10n.messageContextSaveGif, handler: {
                                let _ = addSavedGif(postbox: context.account.postbox, fileReference: FileMediaReference.savedGif(media: file)).start()
                            }))
                        }
                        items.append(ContextMenuItem(L10n.chatSendWithoutSound, handler: {
                            arguments?.sendAppFile(file, view, true)
                        }))
                    }
                    return items
                }
            }))
        case let .separator(string, _, _):
            return SeparatorRowItem(initialSize, entry.stableId, string: string)
        case let .emoji(clues, selected, _, _):
            return ContextClueRowItem(initialSize, stableId: entry.stableId, context: context, clues: clues, selected: selected, canDisablePrediction: false, callback: { emoji in
                arguments?.searchBySuggestion(emoji)
            })
        default:
            fatalError()
        }
    })
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private func recentEntries(for view:OrderedItemListView?, initialSize:NSSize, emojis: [String]) -> [InputContextEntry] {
    if let view = view {
        
        
        
        let result: [ChatContextResult] = view.items.compactMap({($0.contents as? RecentMediaItem)?.media as? TelegramMediaFile}).map { file in
            let reference = ChatContextResult.InternalReference(queryId: 0, id: "gif-panel", type: "gif", title: nil, description: nil, image: nil, file: file, message: .auto(caption: "", entities: nil, replyMarkup: nil))
            return .internalReference(reference)
        }
        let values = makeMediaEnties(result, isSavedGifs: true, initialSize: NSMakeSize(initialSize.width, 100))
        var wrapped:[InputContextEntry] = []
        for value in values {
            wrapped.append(InputContextEntry.contextMediaResult(nil, value, Int64(arc4random()) | ((Int64(wrapped.count) << 40))))
        }
        

        
        if !emojis.isEmpty {
            wrapped.insert(.separator(L10n.gifsPaneTrending, 2, arc4random64()), at: 0)
            wrapped.insert(.emoji(emojis, nil, true, 1), at: 0)
            wrapped.insert(.separator(L10n.gifsPaneReactions, 0, arc4random64()), at: 0)
        }
        
        
        return wrapped
    }
    return []
}

private func gifEntries(for collection: ChatContextResultCollection?, results: [ChatContextResult], initialSize: NSSize, suggest: Bool, emojis: [String], search: String) -> [InputContextEntry] {
    var result: [InputContextEntry] = []
    if let collection = collection {
        result = makeMediaEnties(results, isSavedGifs: true, initialSize: NSMakeSize(initialSize.width, 100)).map({InputContextEntry.contextMediaResult(collection, $0, arc4random64())})
    }
    
    if suggest, !emojis.isEmpty {
        result.insert(.separator(L10n.gifsPaneTrending, 2, arc4random64()), at: 0)
        result.insert(.emoji(emojis, search, true, 1), at: 0)
        result.insert(.separator(L10n.gifsPaneReactions, 0, arc4random64()), at: 0)
    }
    
    return result
}

final class RecentGifsArguments {
    var sendInlineResult:(ChatContextResultCollection,ChatContextResult, NSView) -> Void = { _,_,_  in}
    var sendAppFile:(TelegramMediaFile, NSView, Bool) -> Void = { _,_,_ in}
    var searchBySuggestion:(String)->Void = { _ in }
}

final class TableContainer : View {
    private var searchState: SearchState = SearchState(state: .None, request: nil)
    fileprivate var tableView: TableView?
    fileprivate var restrictedView:RestrictionWrappedView?
    fileprivate let progressView: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
    fileprivate let emptyResults: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        emptyResults.contentGravity = .center
        updateLocalizationAndTheme(theme: theme)
        
        reinstall()
    }
    
    func updateSeacrhState(_ searchState: SearchState) {
        if searchState != self.searchState {
            self.searchState = searchState
            tableView?.change(pos: NSMakePoint(0, searchState.state == .Focus ? 50 : 0), animated: true)
            needsLayout = true
        }
    }
    
    func updateRestricion(_ peer: Peer?) {
        if let peer = peer, let text = permissionText(from: peer, for: .banSendGifs) {
            restrictedView?.removeFromSuperview()
            restrictedView = RestrictionWrappedView(text)
            addSubview(restrictedView!)
        } else {
            restrictedView?.removeFromSuperview()
            restrictedView = nil
        }
        setFrameSize(frame.size)
        needsLayout = true
    }
    
    func reinstall() {
        tableView?.removeFromSuperview()
        tableView = TableView(frame: bounds)
        var subviews:[NSView] = [tableView!, emptyResults]
        
        restrictedView?.removeFromSuperview()
        if let restrictedView = restrictedView {
            subviews.append(restrictedView)
        }
        self.subviews = subviews
    }
    
    fileprivate func merge(with transition: TableUpdateTransition, animated: Bool) {
        self.tableView?.merge(with: transition)
        if let tableView = tableView {
            let emptySearchHidden: Bool = !tableView.isEmpty
            
            if !emptySearchHidden {
                emptyResults.isHidden = false
            }
            emptyResults.change(opacity: emptySearchHidden ? 0 : 1, animated: animated, completion: { [weak self] completed in
                if completed {
                    self?.emptyResults.isHidden = emptySearchHidden
                }
            })
            
        } else {
            emptyResults.isHidden = true
        }
    }

    func deinstall() {
        tableView?.removeFromSuperview()
        tableView = nil
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.restrictedView?.updateLocalizationAndTheme(theme: theme)
        emptyResults.background = theme.colors.background
        emptyResults.image = theme.icons.stickersEmptySearch
    }
    
    override func layout() {
        super.layout()
        tableView?.frame = NSMakeRect(0, self.searchState.state == .Focus ? 50 : 0, frame.width, frame.height - (self.searchState.state == .Focus ? 50 : 0))
        restrictedView?.setFrameSize(frame.size)
        progressView.center()
        emptyResults.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GIFViewController: TelegramGenericViewController<TableContainer>, Notifable {
    
    private let searchValue = ValuePromise<SearchState>()
    private let forceSuggeset = ValuePromise<Bool>(false)
    private var searchState: SearchState = .init(state: .None, request: nil) {
        didSet {
            let value = searchState
            switch value.state {
            case .Focus:
                forceSuggeset.set(true)
            case .None:
                self.forceSuggeset.set(false)
            }
            if value.request.isEmpty {
               // delay(0.2, closure: { [weak self] in
                    self.searchValue.set(value)
              //  })
            } else {
                self.searchValue.set(value)
            }
            
        }
    }
    
    private var interactions:EntertainmentInteractions?
    private weak var chatInteraction: ChatInteraction?
    private let disposable = MetaDisposable()
    private let searchStateDisposable = MetaDisposable()
    var makeSearchCommand:((ESearchCommand)->Void)?
    init(_ context: AccountContext, search: Signal<SearchState, NoError>) {
        super.init(context)
        bar = .init(height: 0)
        
        self.searchStateDisposable.set(search.start(next: { [weak self] state in
            self?.searchState = state
            if !state.request.isEmpty {
                self?.makeSearchCommand?(.loading)
            }
            self?.genericView.updateSeacrhState(state)
        }))
    }
    
    func update(with interactions:EntertainmentInteractions?, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction?.remove(observer: self)
        self.chatInteraction = chatInteraction
        chatInteraction.add(observer: self)
        if isLoaded() {
            genericView.updateRestricion(chatInteraction.presentation.peer)
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState, let peer = value.peer, let oldPeer = oldValue.peer {
            if permissionText(from: peer, for: .banSendGifs) != permissionText(from: oldPeer, for: .banSendGifs) {
                genericView.updateRestricion(peer)
            }
        }
    }
    
    
    
    func isEqual(to other: Notifable) -> Bool {
        return other === self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disposable.set(nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        genericView.tableView?.removeAll()
        genericView.tableView?.removeFromSuperview()
        genericView.tableView = nil
        ready.set(.single(false))
    }
    
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    
    override var canBecomeResponder: Bool {
        if let view = context.sharedContext.bindings.rootNavigation().view as? SplitView {
            return view.state == .single
        }
        return false
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        
        let value = GIFKeyboardConfiguration.with(appConfiguration: context.appConfiguration)
        
        genericView.reinstall()
        genericView.updateRestricion(chatInteraction?.presentation.peer)
        
        
        _ = atomicSize.swap(_frameRect.size)
        let arguments = RecentGifsArguments()
        
        arguments.sendAppFile = { [weak self] file, view, silent in
            if let slowMode = self?.chatInteraction?.presentation.slowMode, slowMode.hasLocked {
                showSlowModeTimeoutTooltip(slowMode, for: view)
            } else {
                self?.chatInteraction?.sendAppFile(file, silent)
                self?.makeSearchCommand?(.close)
                self?.context.sharedContext.bindings.entertainment().closePopover()
            }
        }
        
        arguments.sendInlineResult = { [weak self] results, result, view in
            if let slowMode = self?.chatInteraction?.presentation.slowMode, slowMode.hasLocked {
                showSlowModeTimeoutTooltip(slowMode, for: view)
            } else {
                self?.chatInteraction?.sendInlineResult(results, result)
                self?.makeSearchCommand?(.close)
                self?.context.sharedContext.bindings.entertainment().closePopover()
            }
        }
        
        arguments.searchBySuggestion = { [weak self] value in
            self?.makeSearchCommand?(.apply(value))
        }
        
        let previous:Atomic<[InputContextEntry]> = Atomic(value: [])
        let initialSize = self.atomicSize
        let context = self.context
        
        struct SearchGifsState {
            var request: String
            var values:[ChatContextResult]
            var nextOffset: String
        }
        
        let loadNext: ValuePromise<Bool> = ValuePromise(true, ignoreRepeated: false)
        
        let searchState:Atomic<SearchGifsState> = Atomic(value: SearchGifsState(request: "", values: [], nextOffset: ""))
        
        let signal = combineLatest(queue: prepareQueue, context.account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)]), self.searchValue.get(), forceSuggeset.get(), loadNext.get()) |> mapToSignal { view, search, forceSuggeset, _ -> Signal<TableUpdateTransition, NoError> in
            
            let suggest = value.emojis.contains(search.request) || search.request.isEmpty
            
            switch search.state {
            case .Focus:
                let searchSignal: Signal<ChatContextResultCollection?, NoError>
                
                _ = searchState.modify { current -> SearchGifsState in
                    var current = current
                    if current.request != search.request {
                        current.values = []
                    }
                    current.nextOffset = ""
                    return current
                }

                
                searchSignal = searchGifs(account: context.account, query: search.request, nextOffset: searchState.with { $0.nextOffset })
                return searchSignal |> map { result in
                    _ = searchState.modify { current -> SearchGifsState in
                        var current = current
                        current.values += (result?.results ?? [])
                        current.request = search.request
                        current.nextOffset = result?.nextOffset ?? ""
                        return current
                    }
                    let entries = gifEntries(for: result, results: searchState.with { $0.values }, initialSize: initialSize.with { $0 }, suggest: suggest, emojis: forceSuggeset ? value.emojis : [], search: search.request)
                    return prepareEntries(left: previous.swap(entries), right: entries, context: context, initialSize: initialSize.with { $0 }, arguments: arguments)
                }
            default:
                _ = searchState.swap(SearchGifsState(request: "", values: [], nextOffset: ""))
                let postboxView = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] as! OrderedItemListView
                let entries = recentEntries(for: postboxView, initialSize: initialSize.with { $0 }, emojis: forceSuggeset ? value.emojis : []).sorted(by: <)
                return .single(prepareEntries(left: previous.swap(entries), right: entries, context: context, initialSize: initialSize.with { $0 }, arguments: arguments))
            }
            
        } |> deliverOnMainQueue
        
        var firstTime: Bool = true
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition, animated: !firstTime)
            self?.makeSearchCommand?(.normal)
            firstTime = false
            self?.ready.set(.single(true))
        }))
        
        genericView.tableView?.setScrollHandler { [weak self] position in
            if !searchState.with({ $0.values.isEmpty && !$0.nextOffset.isEmpty }) {
                switch position.direction {
                case .bottom:
                    loadNext.set(true)
                default:
                    break
                }
            }
        }
    }
    
    
    override func scrollup(force: Bool = false) {
        self.genericView.tableView?.scroll(to: .up(true))
    }
    
    deinit {
        disposable.dispose()
        searchStateDisposable.dispose()
        chatInteraction?.remove(observer: self)
    }
    
}
