
import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


private final class BlockedPeerControllerArguments {
    let context: AccountContext
    
    let removePeer: (PeerId) -> Void
    let openPeer:(PeerId) -> Void
    init(context: AccountContext, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping(PeerId)->Void) {
        self.context = context
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
            
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, enabled: enabled, height:44, photoSize: NSMakeSize(32, 32), drawLastSeparator: true, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, action: {
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

private func blockedPeersControllerEntries(state: BlockedPeerControllerState, blockedState: BlockedPeersContextState) -> [BlockedPeerEntry] {
    
    var entries: [BlockedPeerEntry] = []
    
    var index: Int32 = 0
    
    if !blockedState.peers.isEmpty {
        entries.append(.whiteSpace(16))
    }
    for peer in blockedState.peers {
        if let peer = peer.peer {
            var deleting:ShortPeerDeleting? = nil
            if state.editing {
                deleting = ShortPeerDeleting(editable: true)
            }
            
            entries.append(.peerItem(index, peer, deleting, state.removingPeerId != peer.id))
            index += 1
        }
    }
    if entries.isEmpty {
        entries.append(.empty(blockedState.peers.isEmpty))
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        
        let updateState: ((BlockedPeerControllerState) -> BlockedPeerControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let arguments = BlockedPeerControllerArguments(context: context, removePeer: { [weak self] memberId in
            updateState {
                return $0.withUpdatedRemovingPeerId(memberId)
            }
            self?.removePeerDisposable.set((context.blockedPeersContext.remove(peerId: memberId) |> deliverOnMainQueue).start(error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: L10n.unknownError)
                }
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
            self.navigationController?.push(PeerInfoController(context: self.context, peerId: peerId))
        })
        
        
        
        let initialSize = atomicSize
        let previousEntries:Atomic<[AppearanceWrapperEntry<BlockedPeerEntry>]> = Atomic(value: [])
        
        
        let signal = combineLatest(statePromise.get(), context.blockedPeersContext.state, appearanceSignal)
            |> deliverOnMainQueue
            |> map { state, blockedState, appearance -> TableUpdateTransition in
                let entries = blockedPeersControllerEntries(state: state, blockedState: blockedState).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
            }
        
        disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] transition in
            if let strongSelf = self {
                strongSelf.genericView.merge(with: transition)
                strongSelf.readyOnce()
                strongSelf.rightBarView.isHidden = strongSelf.genericView.item(at: 0) is SearchEmptyRowItem
            }
        }))
        
        genericView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                context.blockedPeersContext.loadMore()
            default:
                break
            }
        }
    }
    
    deinit {
        disposable.dispose()
        removePeerDisposable.dispose()
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
}

