
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
    case sectionId(Int32)
    var hashValue: Int {
        switch self {
        case let .peer(peerId):
            return peerId.hashValue
        case .empty:
            return 0
        case .sectionId:
            return 1
        }
    }

}

private enum BlockedPeerEntry: Identifiable, Comparable {
    case section(Int32)
    case peerItem(Int32, Int32, Peer, ShortPeerDeleting?, Bool, GeneralViewType)
    case empty(Bool)
    var stableId: BlockedPeerEntryStableId {
        switch self {
        case let .peerItem(_, _, peer, _, _, _):
            return .peer(peer.id)
        case .empty:
            return .empty
        case let .section(id):
            return .sectionId(id)
        }
    }
    
    static func ==(lhs: BlockedPeerEntry, rhs: BlockedPeerEntry) -> Bool {
        switch lhs {
        case let .peerItem(lhsSectionId, lhsIndex, lhsPeer, lhsEditing, lhsEnabled, lhsViewType):
            if case let .peerItem(rhsSectionId, rhsIndex, rhsPeer, rhsEditing, rhsEnabled, rhsViewType) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                if rhsViewType != lhsViewType {
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
        case let .section(id):
            if case .section(id) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var index: Int32 {
        switch self {
        case .empty:
            return 0
        case let .peerItem(sectionId, index, _, _, _, _):
            return (sectionId * 1000) + index
        case let .section(sectionId):
            return (sectionId * 1000) + sectionId
        }
    }
    
    static func <(lhs: BlockedPeerEntry, rhs: BlockedPeerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: BlockedPeerControllerArguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case let .peerItem(_, _, peer, editing, enabled, viewType):
            
            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {
                
                interactionType = .deletable(onRemove: { peerId in
                    arguments.removePeer(peerId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, enabled: enabled, height:46, photoSize: NSMakeSize(32, 32), inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, viewType: viewType, action: {
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
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: progress, text: L10n.blockedPeersEmptyDescrpition, viewType: .singleItem)
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
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
    var sectionId: Int32 = 0
    if !blockedState.peers.isEmpty {
        entries.append(.section(sectionId))
        sectionId += 1
    }
    for rendered in blockedState.peers {
        if let peer = rendered.peer {
            var deleting:ShortPeerDeleting? = nil
            if state.editing {
                deleting = ShortPeerDeleting(editable: true)
            }

            entries.append(.peerItem(sectionId, index, peer, deleting, state.removingPeerId != peer.id, bestGeneralViewType(blockedState.peers, for: rendered)))
            index += 1
        }
    }
    
    if blockedState.peers.isEmpty {
        entries.append(.empty(blockedState.peers.isEmpty))
    } else {
        entries.append(.section(sectionId))
        sectionId += 1
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<BlockedPeerEntry>], right: [AppearanceWrapperEntry<BlockedPeerEntry>], initialSize:NSSize, arguments:BlockedPeerControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true, grouping: false)
}


class BlockedPeersViewController: EditableViewController<TableView> {
    
    
    private let statePromise = ValuePromise(BlockedPeerControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: BlockedPeerControllerState())
    private let removePeerDisposable:MetaDisposable = MetaDisposable()
    
    private let disposable:MetaDisposable = MetaDisposable()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
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

