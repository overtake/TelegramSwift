//
//  QuickSwitcherModalController.swift
//  Telegram
//
//  Created by keepcoder on 15/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

private class QuickSwitcherArguments {
    let context: AccountContext
    init(_ context:AccountContext) {
        self.context = context
    }
}

private enum QuickSwitcherSeparator : Int32 {
    case recently = 1
    case popular = 2
}

private enum QuickSwitcherStableId : Hashable {
    case peerId(PeerId, SecretChatWrapper?)
    case separator(QuickSwitcherSeparator)
    case empty
    var hashValue: Int {
        return 0
    }
    var effectivePeerId: PeerId? {
        switch self {
        case let .peerId(peerId, secretPeerId):
            return secretPeerId?.peerId ?? peerId
        default:
            return nil
        }
    }
}

private struct SecretChatWrapper : Equatable {
    let peerId:PeerId
}

private enum QuickSwitcherEntry : TableItemListNodeEntry {
    case peer(Int32, Peer, Bool, SecretChatWrapper?)
    case separator(Int32, QuickSwitcherSeparator)
    case empty
    var stableId:QuickSwitcherStableId {
        switch self {
        case let .peer(_, peer, _, secretChat):
            return .peerId(peer.id, secretChat)
        case .separator(_, let id):
            return .separator(id)
        case .empty:
            return .empty
        }
    }
    
    var index:Int32 {
        switch self {
        case .peer(let index, _, _, _):
            return index
        case .separator(let index, _):
            return index
        case .empty:
            return 0
        }
    }
    
    func item(_ arguments: QuickSwitcherArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .peer(_, peer, drawSeparator, secretChat):
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, height: 40, photoSize: NSMakeSize(30, 30), titleStyle: ControlStyle(font: .medium(.text), foregroundColor: secretChat != nil ? theme.colors.accent : theme.colors.text, highlightColor:.white), drawCustomSeparator: drawSeparator, isLookSavedMessage: true, action: {
                
            })
        case .separator(_, let id):
            let text:String
            switch id {
            case .recently:
                text = tr(L10n.quickSwitcherRecently)
            case .popular:
                text = tr(L10n.quickSwitcherPopular)
            }
            return SeparatorRowItem(initialSize, stableId, string: text.uppercased())
        case .empty:
            return SearchEmptyRowItem(initialSize, stableId: stableId)
        }
    }
}

private func ==(lhs: QuickSwitcherEntry, rhs: QuickSwitcherEntry) -> Bool {
    switch lhs {
    case let .peer(lhsIndex, lhsPeer, lhsDrawSeparator, lhsSecretChat):
        if case let .peer(rhsIndex, rhsPeer, rhsDrawSeparator, rhsSecretChat) = rhs {
            if lhsIndex != rhsIndex {
                return false
            }
            if lhsSecretChat != rhsSecretChat {
                return false
            }
            if lhsDrawSeparator != rhsDrawSeparator {
                return false
            }
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
           
            return true
        } else {
            return false
        }
    case let .separator(index, sectionId):
        if case .separator(index, sectionId) = rhs {
            return true
        } else {
            return false
        }
    case .empty:
        if case .empty = rhs {
            return true
        } else {
            return false
        }
    }
}
private func <(lhs: QuickSwitcherEntry, rhs: QuickSwitcherEntry) -> Bool {
    return lhs.index < rhs.index
}


private class QuickSwitcherView : View {
    let tableView:TableView = TableView()
    let textView:TextView = TextView()
    let searchView:SearchView = SearchView(frame: NSMakeRect(0,0, 280, 30))
    let separator:View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(searchView)
        addSubview(textView)
        addSubview(separator)
        textView.isSelectable = false
        separator.backgroundColor = theme.colors.border
        self.backgroundColor = theme.colors.background
        let attributed = NSMutableAttributedString()
        _ = attributed.append(string: L10n.quickSwitcherDescription, color: theme.colors.grayText, font: .normal(.text))
        attributed.detectBoldColorInString(with: .medium(.text))
        let descLayout = TextViewLayout(attributed, alignment: .center)
        descLayout.measure(width: frameRect.width - 20)
        textView.update(descLayout)
        textView.backgroundColor = theme.colors.background
        layout()
    }
    
    override func layout() {
        super.layout()
        searchView.centerX(y: floorToScreenPixels(backingScaleFactor, (50 - 30)/2))
        tableView.frame = NSMakeRect(0, 50, frame.width, frame.height - 100)
        textView.centerX(y: frame.height - floorToScreenPixels(backingScaleFactor, (50 - textView.frame.height)/2) - textView.frame.height)
        separator.frame = NSMakeRect(0, frame.height - 50, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private func searchEntriesForPeers(_ peers:[Peer], account:Account, recentlyUsed:[(Peer, SecretChatWrapper?)], isLoading: Bool) -> [QuickSwitcherEntry] {
    var entries: [QuickSwitcherEntry] = []
    
    var index:Int32 = 0

    if !recentlyUsed.isEmpty {
        entries.append(.separator(index, .recently))
        index += 1
    }
   
    
    var isset:[PeerId:PeerId] = [:]
    for peer in recentlyUsed {
        if isset[peer.0.id] == nil {
            entries.append(.peer(index, peer.0, peer.0.id != recentlyUsed.last?.0.id, peer.1))
            index += 1
            isset[peer.0.id] = peer.0.id
        }
    }
    
    if !recentlyUsed.isEmpty {
        entries.append(.separator(index, .popular))
        index += 1
    }
    
    for peer in peers {
        if isset[peer.id] == nil {
            entries.append(.peer(index, peer, true, nil))
            index += 1
            isset[peer.id] = peer.id
        }
    }
    
    if entries.isEmpty && !isLoading {
        entries.append(.empty)
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<QuickSwitcherEntry>], right: [AppearanceWrapperEntry<QuickSwitcherEntry>], initialSize:NSSize, arguments:QuickSwitcherArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: false)
}


class QuickSwitcherModalController: ModalViewController, TableViewDelegate {
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private let context:AccountContext
    private let search:ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)
    private let disposable = MetaDisposable()
    fileprivate func start(context: AccountContext, recentlyUsed:[PeerId], search:Signal<SearchState, NoError>) -> Signal<([QuickSwitcherEntry], Bool), NoError> {
        
        return search |> mapToSignal { search -> Signal<([QuickSwitcherEntry], Bool), NoError> in
            
            if search.request.isEmpty {
                return combineLatest(recentPeers(account: context.account) |> take(1), context.account.postbox.multiplePeersView(recentlyUsed) |> take(1))
                    |> deliverOn(prepareQueue)
                    |> mapToSignal { recentPeers, view -> Signal<([QuickSwitcherEntry], Bool), NoError> in
                        
                        var peers:[Peer] = []
                        
                        switch recentPeers {
                        case let .peers(list):
                            peers = list
                        default:
                            break
                        }
                        
                        var recentl:[(Peer, SecretChatWrapper?)] = []
                        for peerId in recentlyUsed {
                            if let peer = view.peers[peerId] {
                                recentl.append((peer, nil))
                            }
                        }
                        let secretChats = recentl.compactMap { $0.0 as? TelegramSecretChat }.compactMap { $0.associatedPeerId }
                        
                        if !secretChats.isEmpty {
                            return context.account.postbox.multiplePeersView(secretChats) |> take(1) |> map { secretPeers in
                                var recentl:[(Peer, SecretChatWrapper?)] = []
                                for peerId in recentlyUsed {
                                    if let peer = view.peers[peerId] {
                                        if let peer = peer as? TelegramSecretChat {
                                            if let secretPeer = secretPeers.peers[peer.associatedPeerId!] {
                                                recentl.append((secretPeer, SecretChatWrapper(peerId: peer.id)))
                                            }
                                        } else {
                                            recentl.append((peer, nil))
                                        }
                                    }
                                }
                                return (searchEntriesForPeers(peers, account: context.account, recentlyUsed: recentl, isLoading: false), false)
                            }
                        } else {
                            return .single((searchEntriesForPeers(peers, account: context.account, recentlyUsed: recentl, isLoading: false), false))
                        }
                }
                
            } else  {
                
                var all = search.request.transformKeyboard
                all.insert(search.request.lowercased(), at: 0)
                all = all.uniqueElements
                let localPeers = combineLatest(all.map {
                    return context.account.postbox.searchPeers(query: $0)
                }) |> map { result in
                    return result.reduce([], {
                        return $0 + $1
                    })
                }
                
                let foundLocalPeers = localPeers |> map {
                    return $0.compactMap({$0.chatMainPeer}).filter({!($0 is TelegramSecretChat)})
                }
                
                let foundRemotePeers = Signal<[Peer], NoError>.single([]) |> then( searchPeers(account: context.account, query: search.request.lowercased()) |> map { $0.0.map({$0.peer}) + $0.1.map{$0.peer} } )
                
                return combineLatest(combineLatest(foundLocalPeers, foundRemotePeers) |> map {$0 + $1}, context.account.postbox.loadedPeerWithId(context.peerId)) |> map { values -> ([Peer], Bool) in
                    var peers = values.0
                    if L10n.peerSavedMessages.lowercased().hasPrefix(search.request.lowercased()) || NSLocalizedString("Peer.SavedMessages", comment: "nil").lowercased().hasPrefix(search.request.lowercased()) {
                        peers.insert(values.1, at: 0)
                    }
                    
                    return (uniquePeers(from: peers), false)
                }
                |> runOn(prepareQueue)
                |> map { values -> ([QuickSwitcherEntry], Bool) in
                    
                    return (searchEntriesForPeers(values.0, account: context.account, recentlyUsed: [], isLoading: values.1), values.1)
                }
            }
        }
    }
    
    
    init(_ context: AccountContext) {
        self.context = context
        super.init(frame: NSMakeRect(0, 0, 300, 360))
        bar = .init(height: 0)
    }
    
    override func viewClass() -> AnyClass {
        return QuickSwitcherView.self
    }
    
    private var genericView:QuickSwitcherView {
        return self.view as! QuickSwitcherView
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.searchView.input
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    func selectionWillChange(row:Int, item:TableRowItem, byClick: Bool) -> Bool {
        return item is ShortPeerRowItem
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        if byClick {
            _ = returnKeyAction()
        }
    }
    
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.tableView.delegate = self
        search.set(SearchState(state: .None, request: nil))
        
        let searchInteractions = SearchInteractions({ [weak self] state, _ in
            self?.search.set(state)
        }, { [weak self] state in
            self?.search.set(state)
        })
        
        let arguments = QuickSwitcherArguments(context)
        
        genericView.searchView.searchInteractions = searchInteractions
        
        genericView.searchView.change(state: .Focus, false)
        
        
        let previous:Atomic<[AppearanceWrapperEntry<QuickSwitcherEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        disposable.set((combineLatest(start(context: context, recentlyUsed: context.recentlyPeerUsed, search: search.get()), appearanceSignal) |> map { value, appearance -> (TableUpdateTransition, Bool) in
            let entries = value.0.map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return (prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify {$0}, arguments: arguments), value.1)
        } |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.genericView.tableView.merge(with: value.0)
            self?.genericView.searchView.isLoading = value.1
            self?.genericView.tableView.cancelSelection()
            self?.genericView.tableView.selectNext(false)
            self?.readyOnce()
        }))
        
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let selectedItem = genericView.tableView.selectedItem() as? ShortPeerRowItem {
            let query = self.genericView.searchView.query
            var peerId = selectedItem.peer.id
            var messageId: MessageId? = nil
            let link = inApp(for: query as NSString, context: context, peerId: peerId, openInfo: { _, _, _, _ in }, hashtag: nil, command: nil, applyProxy: nil, confirm: false)
            switch link {
            case let .followResolvedName(_, _, postId, _, _, _):
                if let postId = postId {
                    messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: postId)
                }
            default:
                break
            }
            
            if let stableId = selectedItem.stableId as? QuickSwitcherStableId, let effectivePeerId = stableId.effectivePeerId {
                peerId = effectivePeerId
            }
            
            context.sharedContext.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId), messageId: messageId))
            close()
        }
        return .invoked
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.selectPrev()
            return .invoked
        }, with: modal!, for: .UpArrow, priority: .modal)
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.selectNext()
            return .invoked
        }, with: modal!, for: .DownArrow, priority: .modal)
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.selectNext()
            return .invoked
        }, with: modal!, for: .Tab, priority: .modal)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
}
