
import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


private final class BlockedPeerControllerArguments {
    let account: Account
    
    let removePeer: (PeerId) -> Void
    let openPeer:(PeerId) -> Void
    init(account: Account, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping(PeerId)->Void) {
        self.account = account
        self.removePeer = removePeer
        self.openPeer = openPeer
    }
}

private enum BlockedPeerEntryStableId: Hashable {
    case peer(PeerId)
    case empty
    case whiteSpace
    var hashValue: Int {
        switch self {
        case let .peer(peerId):
            return peerId.hashValue
        case .empty:
            return 0
        case .whiteSpace:
            return 1
        }
    }
    
    static func ==(lhs: BlockedPeerEntryStableId, rhs: BlockedPeerEntryStableId) -> Bool {
        switch lhs {
        case let .peer(peerId):
            if case .peer(peerId) = rhs {
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
        case .whiteSpace:
            if case .whiteSpace = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum BlockedPeerEntry: Identifiable, Comparable {
    case peerItem(Int32, Peer, ShortPeerDeleting?, Bool)
    case empty(Bool)
    case whiteSpace(CGFloat)
    var stableId: BlockedPeerEntryStableId {
        switch self {
        case let .peerItem(_, peer, _, _):
            return .peer(peer.id)
        case .empty:
            return .empty
        case .whiteSpace:
            return .whiteSpace
        }
    }
    
    static func ==(lhs: BlockedPeerEntry, rhs: BlockedPeerEntry) -> Bool {
        switch lhs {
        case let .peerItem(lhsIndex, lhsPeer, lhsEditing, lhsEnabled):
            if case let .peerItem(rhsIndex, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .empty(loading):
            if case .empty(loading) = rhs {
                return true
            } else {
                return false
            }
        case let .whiteSpace(height):
            if case .whiteSpace(height) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: BlockedPeerEntry, rhs: BlockedPeerEntry) -> Bool {
        switch lhs {
        case let .peerItem(index, _, _, _):
            switch rhs {
            case let .peerItem(rhsIndex, _, _, _):
                return index < rhsIndex
            case .empty:
                return false
            case .whiteSpace:
                return false
            }
        case .empty:
            if case .empty = rhs {
                return true
            } else {
                return false
            }
        case .whiteSpace:
            if case .whiteSpace = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    func item(_ arguments: BlockedPeerControllerArguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case let .peerItem(_, peer, editing, enabled):
            
            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {
                
                interactionType = .deletable(onRemove: { peerId in
                    arguments.removePeer(peerId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: stableId, enabled: enabled, height:44, photoSize: NSMakeSize(32, 32), drawLastSeparator: true, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, action: {
                arguments.openPeer(peer.id)
            }, contextMenuItems: {
                if case .plain = interactionType {
                    return [ContextMenuItem(tr(L10n.chatInputUnblock), handler: {
                        arguments.removePeer(peer.id)
                    })]
                } else {
                    return []
                }
                
            })
        case let .empty(progress):
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: progress, text: tr(L10n.blockedPeersEmptyDescrpition))
        case let .whiteSpace(height):
            return GeneralRowItem(initialSize, height: height, stableId: stableId)
        }
    }
}

private struct BlockedPeerControllerState: Equatable {
    let editing: Bool
    let removingPeerId: PeerId?
    
    init() {
        self.editing = false
        self.removingPeerId = nil
    }
    
    init(editing: Bool, removingPeerId: PeerId?) {
        self.editing = editing
        self.removingPeerId = removingPeerId
    }
    
    static func ==(lhs: BlockedPeerControllerState, rhs: BlockedPeerControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.removingPeerId != rhs.removingPeerId {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> BlockedPeerControllerState {
        return BlockedPeerControllerState(editing: editing, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> BlockedPeerControllerState {
        return BlockedPeerControllerState(editing: self.editing, removingPeerId: self.removingPeerId)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> BlockedPeerControllerState {
        return BlockedPeerControllerState(editing: self.editing, removingPeerId: removingPeerId)
    }
}

private func blockedPeersControllerEntries(state: BlockedPeerControllerState, peers: [Peer]?) -> [BlockedPeerEntry] {
    
    var entries: [BlockedPeerEntry] = []
    
    if let peers = peers {
        var index: Int32 = 0
        
        if !peers.isEmpty {
            entries.append(.whiteSpace(16))
        }
        
        for peer in peers {
            var deleting:ShortPeerDeleting? = nil
            if state.editing {
                deleting = ShortPeerDeleting(editable: true)
            }
            
            entries.append(.peerItem(index, peer, deleting, state.removingPeerId != peer.id))
            index += 1
        }
        
    }
    if entries.isEmpty {
        entries.append(.empty(peers == nil))
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<BlockedPeerEntry>], right: [AppearanceWrapperEntry<BlockedPeerEntry>], initialSize:NSSize, arguments:BlockedPeerControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class BlockedPeersViewController: EditableViewController<TableView> {
    
    
    private let statePromise = ValuePromise(BlockedPeerControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: BlockedPeerControllerState())
    private let removePeerDisposable:MetaDisposable = MetaDisposable()
    
    private let disposable:MetaDisposable = MetaDisposable()
    private let openPeerDisposable = MetaDisposable()
    private let defaultPeers:[Peer]?
    private let updated:([Peer]?) -> Void
    init(_ account: Account, _ defaultPeers:[Peer]?, updated: @escaping([Peer]?) -> Void) {
        self.defaultPeers = defaultPeers
        self.updated = updated
        super.init(account)
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        let account = self.account
        
        let updateState: ((BlockedPeerControllerState) -> BlockedPeerControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let peersPromise = Promise<[Peer]?>(nil)
        
        let arguments = BlockedPeerControllerArguments(account: account, removePeer: { [weak self] memberId in
            
            updateState {
                return $0.withUpdatedRemovingPeerId(memberId)
            }
            
            let applyPeers: Signal<Void, NoError> = peersPromise.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { peers -> Signal<Void, NoError> in
                    if let peers = peers {
                        var updatedPeers = peers
                        for i in 0 ..< updatedPeers.count {
                            if updatedPeers[i].id == memberId {
                                updatedPeers.remove(at: i)
                                break
                            }
                        }
                        peersPromise.set(.single(updatedPeers))
                    }
                    
                    return .complete()
            }
            
            self?.removePeerDisposable.set((requestUpdatePeerIsBlocked(account: account, peerId: memberId, isBlocked: false) |> then(applyPeers) |> deliverOnMainQueue).start(error: { _ in
                updateState {
                    return $0.withUpdatedRemovingPeerId(nil)
                }
            }, completed: {
                updateState {
                    return $0.withUpdatedRemovingPeerId(nil)
                }
                
            }))
        }, openPeer: { [weak self] peerId in
            guard let `self` = self else {return}
            self.openPeerDisposable.set((self.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let strongSelf = self {
                    strongSelf.navigationController?.push(PeerInfoController(account: strongSelf.account, peer: peer))
                }
            }))
        })
        
        
        let peersSignal: Signal<[Peer]?, NoError> = .single(defaultPeers) |> then(requestBlockedPeers(account: account) |> map { Optional($0) })
        
        peersPromise.set(peersSignal)
        
        let initialSize = atomicSize
        let previousEntries:Atomic<[AppearanceWrapperEntry<BlockedPeerEntry>]> = Atomic(value: [])
        
        
        let signal = combineLatest(statePromise.get(), peersPromise.get(), appearanceSignal)
            |> deliverOnMainQueue
            |> map { state, peers, appearance -> (TableUpdateTransition, [Peer]?) in
                let entries = blockedPeersControllerEntries(state: state, peers: peers).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return (prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), peers)
            }
        
        disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] transition, newValue in
            if let strongSelf = self {
                strongSelf.genericView.merge(with: transition)
                strongSelf.readyOnce()
                strongSelf.updated(newValue)
                strongSelf.rightBarView.isHidden = strongSelf.genericView.item(at: 0) is SearchEmptyRowItem
            }
        }))
    }
    
    deinit {
        disposable.dispose()
        removePeerDisposable.dispose()
        openPeerDisposable.dispose()
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
}

