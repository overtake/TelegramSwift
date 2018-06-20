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

private func prepareEntries(left:[InputContextEntry], right:[InputContextEntry], account:Account,  initialSize:NSSize, chatInteraction: RecentGifsArguments?) -> TableUpdateTransition {
   let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
        switch entry {
        case let .contextMediaResult(collection, row, index):
            return ContextMediaRowItem(initialSize, row, index, account, ContextMediaArguments(sendResult: { result in
                if let collection = collection {
                    chatInteraction?.sendInlineResult(collection, result)
                } else {
                    switch result {
                    case let .internalReference(_, _, _, _, _, file, _):
                        if let file = file {
                            chatInteraction?.sendAppFile(file)
                        }
                    default:
                        break
                    }
                }
            }, menuItems: { file in
                return account.postbox.transaction { transaction -> [ContextMenuItem] in
                    if let mediaId = file.id {
                        let gifItems = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).flatMap {$0.contents as? RecentMediaItem}
                        if let _ = gifItems.index(where: {$0.media.id == mediaId}) {
                            return [ContextMenuItem(L10n.messageContextRemoveGif, handler: {
                                let _ = removeSavedGif(postbox: account.postbox, mediaId: mediaId).start()
                            })]
                        } else {
                            return [ContextMenuItem(L10n.messageContextSaveGif, handler: {
                                let _ = addSavedGif(postbox: account.postbox, file: file).start()
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
        let result = view.items.prefix(70).flatMap({($0.contents as? RecentMediaItem)?.media as? TelegramMediaFile}).map({ChatContextResult.internalReference(id: "", type: "gif", title: nil, description: nil, image: nil, file: $0, message: .auto(caption: "", entities: nil, replyMarkup: nil))})
        
        let values = makeMediaEnties(result, initialSize: NSMakeSize(initialSize.width, 100))
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
        return makeMediaEnties(collection.results, initialSize: NSMakeSize(initialSize.width, 100)).map({InputContextEntry.contextMediaResult(collection, $0, arc4random64())})
    }
    return []
}

final class RecentGifsArguments {
    var sendInlineResult:(ChatContextResultCollection,ChatContextResult) -> Void = {_,_  in}
    var sendAppFile:(TelegramMediaFile) -> Void = {_ in}
}

final class TableContainer : View {
    fileprivate var tableView: TableView?
    fileprivate var restrictedView:RestrictionWrappedView?
    fileprivate let searchView: SearchView
    fileprivate let searchContainer: View = View()
    fileprivate let progressView: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
    fileprivate let emptyResults: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        searchView = SearchView(frame: NSMakeRect(0, 0, frameRect.width - 20, 30))
        super.init(frame: frameRect)
        searchContainer.addSubview(searchView)
        addSubview(searchContainer)
        addSubview(emptyResults)
        
        updateLocalizationAndTheme()
    }
    
    func updateRestricion(_ peer: Peer?) {
        if let peer = peer as? TelegramChannel {
            if peer.stickersRestricted, let bannedRights = peer.bannedRights {
                restrictedView?.removeFromSuperview()
                restrictedView = RestrictionWrappedView(bannedRights.untilDate != .max ? tr(L10n.channelPersmissionDeniedSendGifsUntil(bannedRights.formattedUntilDate)) : tr(L10n.channelPersmissionDeniedSendGifsForever))
                addSubview(restrictedView!)
            } else {
                restrictedView?.removeFromSuperview()
                restrictedView = nil
            }
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
        addSubview(tableView!)
        restrictedView?.removeFromSuperview()
        if let restrictedView = restrictedView {
            addSubview(restrictedView)
        }
    }
    
    fileprivate func updateLoading(_ isLoading: Bool) {
        if isLoading {
            if progressView.superview == nil {
                addSubview(progressView)
            }
            progressView.center()
        } else {
            progressView.removeFromSuperview()
        }
        tableView?.isHidden = isLoading
        if let tableView = tableView {
            emptyResults.isHidden = !tableView.isEmpty || isLoading
            tableView.isHidden = tableView.isHidden || tableView.isEmpty
        } else {
            emptyResults.isHidden = true
        }
    }

    func deinstall() {
        tableView?.removeFromSuperview()
        tableView = nil
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        self.restrictedView?.updateLocalizationAndTheme()
        emptyResults.image = theme.icons.stickersEmptySearch
        emptyResults.sizeToFit()
        searchView.updateLocalizationAndTheme()
    }
    
    override func layout() {
        super.layout()
        searchContainer.frame = NSMakeRect(0, 0, frame.width, 50)
        searchView.setFrameSize(searchContainer.frame.width - 20, 30)
        searchView.center()
        tableView?.frame = NSMakeRect(0, searchContainer.frame.maxY, frame.width, frame.height - searchContainer.frame.height)
        restrictedView?.setFrameSize(frame.size)
        progressView.center()
        emptyResults.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GIFViewController: TelegramGenericViewController<TableContainer>, Notifable {
    private var interactions:EntertainmentInteractions?
    private var chatInteraction: ChatInteraction?
    private let disposable = MetaDisposable()
    init(account:Account) {
        super.init(account)
        bar = .init(height: 0)
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
            if peer.stickersRestricted != oldPeer.stickersRestricted {
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
        genericView.searchView.change(state: .None, true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        genericView.deinstall()
        ready.set(.single(false))
    }
    
    override func firstResponder() -> NSResponder? {
        return self.genericView.searchView.input
    }
    
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    
    override var canBecomeResponder: Bool {
        if let view = account.context.mainNavigation?.view as? SplitView {
            return view.state == .single
        }
        return false
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        genericView.reinstall()
        
        genericView.updateRestricion(chatInteraction?.presentation.peer)
        
        _ = atomicSize.swap(_frameRect.size)
        let arguments = RecentGifsArguments()
        
        arguments.sendAppFile = { [weak self] file in
            self?.chatInteraction?.sendAppFile(file)
            self?.genericView.searchView.change(state: .None, true)
            self?.account.context.entertainment.closePopover()
        }
        
        arguments.sendInlineResult = { [weak self] results, result in
            self?.chatInteraction?.sendInlineResult(results, result)
            self?.genericView.searchView.change(state: .None, true)
            self?.account.context.entertainment.closePopover()
        }
        
        let previous:Atomic<[InputContextEntry]> = Atomic(value: [])
        let initialSize = self.atomicSize
        let account = self.account
        
        let search:ValuePromise<SearchState> = ValuePromise(SearchState(state: genericView.searchView.state, request: genericView.searchView.query), ignoreRepeated: true)
        
        let searchInteractions = SearchInteractions({ [weak self] state in
            search.set(state)
            switch state.state {
            case .None:
                self?.scrollup()
            default:
                break
            }
        }, { [weak self] state in
            search.set(state)
            switch state.state {
            case .None:
                self?.scrollup()
            default:
                break
            }
        })
        
        
        genericView.searchView.searchInteractions = searchInteractions
        
        let signal = combineLatest( account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)]) |> deliverOnPrepareQueue, search.get() |> deliverOnPrepareQueue) |> mapToSignal { view, search -> Signal<TableUpdateTransition?, Void> in
            
            if search.request.isEmpty {
                let postboxView = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] as! OrderedItemListView
                let entries = recentEntries(for: postboxView, initialSize: initialSize.modify({$0})).sorted(by: <)
                return .single(prepareEntries(left: previous.swap(entries), right: entries, account: account, initialSize: initialSize.modify({$0}), chatInteraction: arguments))
            } else {
                return .single(nil) |> then(searchGifs(account: account, query: search.request.lowercased()) |> map { result in
                    let entries = gifEntries(for: result, initialSize: initialSize.modify({$0}))
                    return prepareEntries(left: previous.swap(entries), right: entries, account: account, initialSize: initialSize.modify({$0}), chatInteraction: arguments)
                } |> delay(0.2, queue: Queue.concurrentDefaultQueue()))
            }
            
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            if let transition = transition {
                self?.genericView.tableView?.merge(with: transition)
            }
            self?.genericView.updateLoading(transition == nil)
            self?.ready.set(.single(true))
        }))
    }
    
    
    
    
    deinit {
        disposable.dispose()
        chatInteraction?.remove(observer: self)
    }
    
}
