//
//  QuickSwitcherModalController.swift
//  Telegram
//
//  Created by keepcoder on 15/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private class QuickSwitcherArguments {
    let account:Account
    init(_ account:Account) {
        self.account = account
    }
}

private enum QuickSwitcherSeparator : Int32 {
    case recently = 1
    case popular = 2
}

private enum QuickSwitcherStableId : Hashable {
    case peerId(PeerId)
    case separator(QuickSwitcherSeparator)
    case empty
    var hashValue: Int {
        switch self {
        case .peerId(let peerId):
            return Int(peerId.id)
        case .separator(let id):
            return Int(id.hashValue)
        case .empty:
            return 0
        }
    }
    
    static func ==(lhs:QuickSwitcherStableId, rhs: QuickSwitcherStableId) -> Bool {
        switch lhs {
        case .peerId(let peerId):
            if case .peerId(peerId) = rhs {
                return true
            } else {
                return false
            }
        case .separator(let id):
            if case .separator(id) = rhs {
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
}

private enum QuickSwitcherEntry : TableItemListNodeEntry {
    case peer(Int32, Peer, Bool)
    case separator(Int32, QuickSwitcherSeparator)
    case empty
    var stableId:QuickSwitcherStableId {
        switch self {
        case .peer(_, let peer, _):
            return .peerId(peer.id)
        case .separator(_, let id):
            return .separator(id)
        case .empty:
            return .empty
        }
    }
    
    var index:Int32 {
        switch self {
        case .peer(let index, _, _):
            return index
        case .separator(let index, _):
            return index
        case .empty:
            return 0
        }
    }
    
    func item(_ arguments: QuickSwitcherArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .peer(_, let peer, let drawSeparator):
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: stableId, height: 40, photoSize: NSMakeSize(30, 30), drawCustomSeparator: drawSeparator, isLookSavedMessage: true, action: {
                
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
    case let .peer(lhsIndex, lhsPeer, lhsDrawSeparator):
        if case let .peer(rhsIndex, rhsPeer, rhsDrawSeparator) = rhs {
            if lhsIndex != rhsIndex {
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
        _ = attributed.append(string: tr(L10n.quickSwitcherDescription), color: theme.colors.grayText, font: .normal(.text))
        attributed.detectBoldColorInString(with: .medium(.text))
        let descLayout = TextViewLayout(attributed, alignment: .center)
        descLayout.measure(width: frameRect.width - 20)
        textView.update(descLayout)
        textView.backgroundColor = theme.colors.background
        layout()
    }
    
    override func layout() {
        super.layout()
        searchView.centerX(y: floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - 30)/2))
        tableView.frame = NSMakeRect(0, 50, frame.width, frame.height - 100)
        textView.centerX(y: frame.height - floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - textView.frame.height)/2) - textView.frame.height)
        separator.frame = NSMakeRect(0, frame.height - 50, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private func searchEntriesForPeers(_ peers:[Peer], account:Account, recentlyUsed:[Peer], isLoading: Bool) -> [QuickSwitcherEntry] {
    var entries: [QuickSwitcherEntry] = []
    
    var index:Int32 = 0

    if !recentlyUsed.isEmpty {
        entries.append(.separator(index, .recently))
        index += 1
    }
   
    
    var isset:[PeerId:PeerId] = [:]
    for peer in recentlyUsed {
        if isset[peer.id] == nil {
            entries.append(.peer(index, peer, peer.id != recentlyUsed.last?.id))
            index += 1
            isset[peer.id] = peer.id
        }
    }
    
    if !recentlyUsed.isEmpty {
        entries.append(.separator(index, .popular))
        index += 1
    }
    
    for peer in peers {
        if isset[peer.id] == nil {
            entries.append(.peer(index, peer, true))
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
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class QuickSwitcherModalController: ModalViewController, TableViewDelegate {
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private let account:Account
    private let search:ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)
    private let disposable = MetaDisposable()
    fileprivate func start(account: Account, recentlyUsed:[PeerId], search:Signal<SearchState, Void>) -> Signal<([QuickSwitcherEntry], Bool), Void> {
        
        return search |> mapToSignal { search -> Signal<([QuickSwitcherEntry], Bool), Void> in
            
            if search.request.isEmpty {
                return combineLatest(account.postbox.recentPeers(), account.postbox.multiplePeersView(recentlyUsed) |> take(1))
                    |> deliverOn(prepareQueue)
                    |> mapToSignal { peers, view -> Signal<([QuickSwitcherEntry], Bool), Void> in
                        
                        var recentl:[Peer] = []
                        for peerId in recentlyUsed {
                            if let peer = view.peers[peerId] {
                                recentl.append(peer)
                            }
                        }
                        
                        
                        return .single((searchEntriesForPeers(peers, account: account, recentlyUsed: recentl, isLoading: false), false))
                }
                
            } else  {
                let foundLocalPeers = account.postbox.searchContacts(query: search.request.lowercased())
                
                let foundRemotePeers = account.postbox.searchPeers(query: search.request.lowercased(), groupId: nil) |> map {$0.flatMap({$0.chatMainPeer}).filter({!($0 is TelegramSecretChat)})}
                
                return combineLatest(foundLocalPeers, foundRemotePeers, account.postbox.loadedPeerWithId(account.peerId)) |> map { values -> ([Peer], Bool) in
                    var peers = (values.1 + values.0)
                    if L10n.peerSavedMessages.lowercased().hasPrefix(search.request.lowercased()) {
                        peers.insert(values.2, at: 0)
                    }
                    return (uniquePeers(from: peers), false)
                }
                |> runOn(prepareQueue)
                |> map { values -> ([QuickSwitcherEntry], Bool) in
                    
                    return (searchEntriesForPeers(values.0, account: account, recentlyUsed: [], isLoading: values.1), values.1)
                }
            }
            
        }
        
    }
    
    
    init(account:Account) {
        self.account = account
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
    
    func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
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
        
        let searchInteractions = SearchInteractions({ [weak self] state in
            self?.search.set(state)
        }, { [weak self] state in
            self?.search.set(state)
        })
        
        let arguments = QuickSwitcherArguments(account)
        
        genericView.searchView.searchInteractions = searchInteractions
        
        genericView.searchView.change(state: .Focus, false)
        
        
        let previous:Atomic<[AppearanceWrapperEntry<QuickSwitcherEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        disposable.set((combineLatest(start(account: account, recentlyUsed: account.context.recentlyPeerUsed, search: search.get()), appearanceSignal) |> map { value, appearance -> (TableUpdateTransition, Bool) in
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
            account.context.mainNavigation?.push(ChatController(account: account, chatLocation: .peer(selectedItem.peer.id)))
            close()
        }
        return .rejected
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
