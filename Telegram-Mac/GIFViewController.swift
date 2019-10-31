//
//  GIFViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private func prepareEntries(left:[InputContextEntry], right:[InputContextEntry], context: AccountContext,  initialSize:NSSize, chatInteraction: RecentGifsArguments?) -> TableUpdateTransition {
   let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
        switch entry {
        case let .contextMediaResult(collection, row, index):
            return ContextMediaRowItem(initialSize, row, index, context, ContextMediaArguments(sendResult: { result, view in
                if let collection = collection {
                    chatInteraction?.sendInlineResult(collection, result, view)
                } else {
                    switch result {
                    case let .internalReference(_, _, _, _, _, _, file, _):
                        if let file = file {
                            chatInteraction?.sendAppFile(file, view)
                        }
                    default:
                        break
                    }
                }
            }, menuItems: { file in
                return context.account.postbox.transaction { transaction -> [ContextMenuItem] in
                    if let mediaId = file.id {
                        let gifItems = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).compactMap {$0.contents as? RecentMediaItem}
                        if let _ = gifItems.index(where: {$0.media.id == mediaId}) {
                            return [ContextMenuItem(L10n.messageContextRemoveGif, handler: {
                                let _ = removeSavedGif(postbox: context.account.postbox, mediaId: mediaId).start()
                            })]
                        } else {
                            return [ContextMenuItem(L10n.messageContextSaveGif, handler: {
                                let _ = addSavedGif(postbox: context.account.postbox, fileReference: FileMediaReference.savedGif(media: file)).start()
                            })]
                        }
                    }
                    return []
                }
            }))
        default:
            fatalError()
        }
    })
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated)
}

private func recentEntries(for view:OrderedItemListView?, initialSize:NSSize) -> [InputContextEntry] {
    if let view = view {
        let result = view.items.compactMap({($0.contents as? RecentMediaItem)?.media as? TelegramMediaFile}).map({ChatContextResult.internalReference(queryId: 0, id: "gif-panel", type: "gif", title: nil, description: nil, image: nil, file: $0, message: .auto(caption: "", entities: nil, replyMarkup: nil))})
        let values = makeMediaEnties(result, isSavedGifs: true, initialSize: NSMakeSize(initialSize.width, 100))
        var wrapped:[InputContextEntry] = []
        for value in values {
            wrapped.append(InputContextEntry.contextMediaResult(nil, value, Int64(arc4random()) | ((Int64(wrapped.count) << 40))))
        }
        return wrapped
    }
    return []
}

private func gifEntries(for collection: ChatContextResultCollection?, initialSize: NSSize) -> [InputContextEntry] {
    if let collection = collection {
        return makeMediaEnties(collection.results, isSavedGifs: true, initialSize: NSMakeSize(initialSize.width, 100)).map({InputContextEntry.contextMediaResult(collection, $0, arc4random64())})
    }
    return []
}

final class RecentGifsArguments {
    var sendInlineResult:(ChatContextResultCollection,ChatContextResult, NSView) -> Void = { _,_,_  in}
    var sendAppFile:(TelegramMediaFile, NSView) -> Void = { _,_ in}
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
    private var searchState: SearchState = .init(state: .None, request: nil) {
        didSet {
            self.searchValue.set(searchState)
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
        
        
        genericView.reinstall()
        genericView.updateRestricion(chatInteraction?.presentation.peer)
        
        _ = atomicSize.swap(_frameRect.size)
        let arguments = RecentGifsArguments()
        
        arguments.sendAppFile = { [weak self] file, view in
            if let slowMode = self?.chatInteraction?.presentation.slowMode, slowMode.hasLocked {
                showSlowModeTimeoutTooltip(slowMode, for: view)
            } else {
                self?.chatInteraction?.sendAppFile(file)
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
        
        let previous:Atomic<[InputContextEntry]> = Atomic(value: [])
        let initialSize = self.atomicSize
        let context = self.context
        
        
        let signal = combineLatest(queue: prepareQueue, context.account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)]), self.searchValue.get() |> distinctUntilChanged(isEqual: { prev, new in
            return prev.request == new.request
        })) |> mapToSignal { view, search -> Signal<TableUpdateTransition, NoError> in
            
            if search.request.isEmpty {
                let postboxView = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] as! OrderedItemListView
                let entries = recentEntries(for: postboxView, initialSize: initialSize.with { $0 }).sorted(by: <)
                return .single(prepareEntries(left: previous.swap(entries), right: entries, context: context, initialSize: initialSize.with { $0 }, chatInteraction: arguments))
            } else {
                return searchGifs(account: context.account, query: search.request.lowercased()) |> map { result in
                    let entries = gifEntries(for: result, initialSize: initialSize.with { $0 })
                    return prepareEntries(left: previous.swap(entries), right: entries, context: context, initialSize: initialSize.with { $0 }, chatInteraction: arguments)
                } |> delay(0.2, queue: Queue.concurrentDefaultQueue())
            }
            
        } |> deliverOnMainQueue
        
        var firstTime: Bool = true
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition, animated: !firstTime)
            self?.makeSearchCommand?(.normal)
            firstTime = false
            self?.genericView.tableView?.clipView.scroll(to: NSZeroPoint)
            self?.ready.set(.single(true))
        }))
    }
    
    
    override func scrollup() {
        self.genericView.tableView?.scroll(to: .up(true))
    }
    
    deinit {
        disposable.dispose()
        searchStateDisposable.dispose()
        chatInteraction?.remove(observer: self)
    }
    
}
