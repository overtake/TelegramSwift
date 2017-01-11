//
//  SelectController.swift
//  TelegramMac
//
//  Created by keepcoder on 04/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac


let searchTheme = SearchTheme(#imageLiteral(resourceName: "Icon_SearchField").precomposed(), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(), localizedString("ShareExtension.Search"))
class ShareModalView : View {
    let searchView:SearchView = SearchView(frame: NSZeroRect, theme:searchTheme)
    let tableView:TableView = TableView()
    let acceptView:TitleButton = TitleButton()
    let cancelView:TitleButton = TitleButton()
    let borderView:View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        borderView.backgroundColor = .border
        
        acceptView.style = ControlStyle(font:.medium(.text),foregroundColor:.blueUI)
        acceptView.set(text: localizedString("ShareExtension.Share"), for: .Normal)
        acceptView.sizeToFit()
        
        cancelView.style = ControlStyle(font:.medium(.text),foregroundColor:.blueUI)
        cancelView.set(text: localizedString("ShareExtension.Cancel"), for: .Normal)
        cancelView.sizeToFit()
        
        addSubview(acceptView)
        addSubview(cancelView)
        addSubview(searchView)
        addSubview(tableView)
        addSubview(borderView)
    }
    
    override func layout() {
        super.layout()
        searchView.frame = NSMakeRect(10, 10, frame.width - 20, 30)
        tableView.frame = NSMakeRect(0, 50, frame.width, frame.height - 50 - 40)
        borderView.frame = NSMakeRect(0, tableView.frame.maxY, frame.width, .borderSize)
        acceptView.setFrameOrigin(frame.width - acceptView.frame.width - 30, floorToScreenPixels(tableView.frame.maxY + (40 - acceptView.frame.height) / 2.0))
        cancelView.setFrameOrigin(acceptView.frame.minX - cancelView.frame.width - 30, floorToScreenPixels(tableView.frame.maxY + (40 - cancelView.frame.height) / 2.0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


class ShareObject {
    let account:Account
    let context:NSExtensionContext
    init(_ account:Account, _ context:NSExtensionContext) {
        self.account = account
        self.context = context
    }
    
    func perform(to entries:[PeerId]) {
                
        for peerId in entries {
            for item in context.inputItems {
                if let item = item as? NSExtensionItem {
                    if let text = item.attributedContentText?.string {
                        _ = sendText(text, to:peerId).start()
                    } else if let attachments = item.attachments as? [NSItemProvider] {
                        for attach in attachments {
                            attach.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (coding, error) in

                                if let url = coding as? URL {
                                    if !url.isFileURL {
                                        _ = self.sendText(url.absoluteString, to:peerId).start()
                                    } else {
                                        _ = self.sendMedia(url.absoluteString, to:peerId).start()
                                    }
                                }
                            })
                        }
                    }
                }
            }
        }
        
        context.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    private func sendText(_ text:String, to peerId:PeerId) -> Signal<Void,Void> {
        return enqueueMessages(account: account, peerId: peerId, messages: [EnqueueMessage.message(text: text, attributes: [], media: nil, replyToMessageId: nil)])
    }
    
    private func sendMedia(_ text:String, to peerId:PeerId) -> Signal<Void,Void> {
        return .single()
    }
    
    func cancel() {
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        context.cancelRequest(withError: cancelError)
    }
}



enum SelectablePeersEntry : Comparable, Identifiable {
    case plain(Peer,MessageIndex)
    case other(MessageIndex)
    var stableId: Int64 {
        switch self {
        case let .plain(peer,_):
            return peer.id.toInt64()
        case let .other(index):
            return Int64(index.id.id)
        }
    }
    
    var index:MessageIndex {
        switch self {
        case let .plain(_,id):
            return id
        case let .other(index):
            return index
        }
    }
}

func <(lhs:SelectablePeersEntry, rhs:SelectablePeersEntry) -> Bool {
    return lhs.index < rhs.index
}

func ==(lhs:SelectablePeersEntry, rhs:SelectablePeersEntry) -> Bool {
    switch lhs {
    case let .plain(lhsPeer, lhsIndex):
        if case let .plain(rhsPeer, rhsIndex) = rhs {
            return lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex
        } else {
            return false
        }
    case let .other(lhsIndex):
        if case let .other(rhsIndex) = rhs {
            return lhsIndex == rhsIndex
        } else {
            return false
        }
        
    }
}



fileprivate func prepareEntries(from:[SelectablePeersEntry]?, to:[SelectablePeersEntry], account:Account, initialSize:NSSize, animated:Bool, selectInteraction:SelectPeerInteraction) -> Signal<TableEntriesTransition<[SelectablePeersEntry]>,Void> {
    
    return Signal {subscriber in
        let (deleted,inserted,updated) = proccessEntries(from, right: to, { (entry) -> TableRowItem in
            
            switch entry {
            case let .plain(peer, _):
                return  ShortPeerRowItem(initialSize, peer: peer, account:account, height:40, photoSize:NSMakeSize(30,30), inset:EdgeInsets(left: 10, right:10), interactionType:.selectable(selectInteraction))
            case let .other(index):
                return ChatListNothingItem(initialSize,index)
            }
            
            
        })
        
        let transition = TableEntriesTransition<[SelectablePeersEntry]>(deleted: deleted, inserted: inserted, updated:updated, entries:to, animated:animated, state: animated ? .none(nil) : .saveVisible(.lower))
        
        subscriber.putNext(transition)
        subscriber.putCompletion()
        return EmptyDisposable
        
    }
    
}

fileprivate struct SearchState : Equatable {
    let state:SearchFieldState
    let request:String
    init(state:SearchFieldState, request:String?) {
        self.state = state
        self.request = request ?? ""
    }
}

fileprivate func ==(lhs:SearchState, rhs:SearchState) -> Bool {
    return lhs.state == rhs.state && lhs.request == rhs.request
}

class SESelectController: GenericViewController<ShareModalView>, Notifable {
    private let share:ShareObject
    private let selectInteractions:SelectPeerInteraction = SelectPeerInteraction()
    private let search:ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)
    private let inSearchSelected:Atomic<[PeerId]> = Atomic(value:[])
    private let disposable:MetaDisposable = MetaDisposable()

    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
            if genericView.searchView.state == .Focus {
                let new = value.selected.subtracting(oldValue.selected)
                _ = inSearchSelected.modify { (peers) -> [PeerId] in
                    return new + peers
                }
            } else {
                
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return false
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let search = self.search
        search.set(SearchState(state: .None, request: nil))
        let searchView = genericView.searchView
        
        
        let previous:Atomic<[SelectablePeersEntry]?> = Atomic(value: nil)
        let initialSize = self.atomicSize
        let account = share.account
        let table = genericView.tableView
        let selectInteraction = self.selectInteractions
        let inSearch = self.inSearchSelected
        selectInteraction.add(observer: self)
        
        let list:Signal<TableEntriesTransition<[SelectablePeersEntry]>,Void> = search.get() |> distinctUntilChanged |> mapToSignal { search -> Signal<TableEntriesTransition<[SelectablePeersEntry]>,Void> in
            
            if search.state == .None {
                
                return account.postbox.tailChatListView(150) |> deliverOn(prepareQueue) |> mapToQueue { (value) -> Signal<TableEntriesTransition<[SelectablePeersEntry]>, Void> in
                    var entries:[SelectablePeersEntry] = []
                    
                    let fromSearch = inSearch.modify({$0})
                    let fromSetIds:Set<PeerId> = Set(fromSearch)
                    var fromPeers:[PeerId:Peer] = [:]
                    
                    
                    for entry in value.0.entries {
                        switch entry {
                        case let .HoleEntry(hole):
                            entries.append(.other(hole.index))
                        case let .MessageEntry(id, message, _, _, _):
                            if let peer = message.peers[message.id.peerId] {
                                if !fromSetIds.contains(peer.id) {
                                    entries.append(.plain(peer,id))
                                } else {
                                    fromPeers[peer.id] = peer
                                }
                            }
                        case let .Nothing(index):
                            entries.append(.other(index))
                        }
                    }
                    
                    var i:Int32 = Int32.max
                    for peerId in fromSearch {
                        if let peer = fromPeers[peerId] {
                            let index = MessageIndex(id: MessageId(peerId: peer.id, namespace: 1, id: i), timestamp: i)
                            entries.append(.plain(peer, index))
                        }
                        i -= 1
                    }
                    entries.sort(by: <)
                    
                    return prepareEntries(from: previous.modify({$0}), to: entries, account: account, initialSize: initialSize.modify({$0}), animated: true, selectInteraction:selectInteraction) |> deliverOnMainQueue
                }
            } else {
                return ( search.request.isEmpty ? recentPeers(account: account) : account.postbox.searchPeers(query: search.request.lowercased())) |> deliverOn(prepareQueue) |> mapToSignal { (peers) -> Signal<TableEntriesTransition<[SelectablePeersEntry]>, Void> in
                    var entries:[SelectablePeersEntry] = []
                    var i:Int32 = Int32.max
                    for peer in peers {
                        let index = MessageIndex(id: MessageId(peerId: peer.id, namespace: 1, id: i), timestamp: i)
                        entries.append(.plain(peer, index))
                        i -= 1
                    }
                    entries.sort(by: <)
                    return  prepareEntries(from: previous.modify({$0}), to: entries, account: account, initialSize: initialSize.modify({$0}), animated: true, selectInteraction:selectInteraction) |> deliverOnMainQueue
                }
            }
            
        }
        
        disposable.set(list.start(next: { [weak self] (transition) in
            table.resetScrollNotifies()
            _ = previous.swap(transition.entries)
            table.merge(with:transition)
            self?.readyOnce()
        }))
        
        self.genericView.searchView.searchInteractions = SearchInteractions({ state in
            search.set(SearchState(state: state, request: searchView.input.string))
        }, { (text) in
            search.set(SearchState(state: searchView.state, request: text))
        })
        
        self.genericView.acceptView.set(handler: { [weak self] in
            self?.share.perform(to: selectInteraction.presentation.list.map{$0.id})
        }, for: .Click)
        
        self.genericView.cancelView.set(handler: { [weak self] in
            self?.share.cancel()
        }, for: .Click)
        
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.searchView.input
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.searchView.state == .Focus {
            return genericView.searchView.changeResponder() ? .invoked : .rejected
        }
        return .rejected
    }
    
    
    init(_ share:ShareObject) {
        self.share = share
        super.init(frame: NSMakeRect(0, 0, 300, 400))
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disposable.set(nil)
    }
    
    deinit {
        disposable.dispose()
    }
    
}
