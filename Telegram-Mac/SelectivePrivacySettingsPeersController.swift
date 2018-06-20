//
//  SelectivePrivacySettingsPeersController.swift
//  Telegram
//
//  Created by keepcoder on 02/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac


private final class SelectivePrivacyPeersControllerArguments {
    let account: Account
    
    let removePeer: (PeerId) -> Void
    let addPeer: () -> Void
    let openInfo:(Peer) -> Void
    init(account: Account, removePeer: @escaping (PeerId) -> Void, addPeer: @escaping () -> Void, openInfo:@escaping(Peer) -> Void) {
        self.account = account
        self.removePeer = removePeer
        self.addPeer = addPeer
        self.openInfo = openInfo
    }
}



private enum SelectivePrivacyPeersEntryStableId: Hashable {
    case peer(PeerId)
    case add
    case section(Int32)
    var hashValue: Int {
        switch self {
        case let .peer(peerId):
            return peerId.hashValue
        case .add:
            return 1
        case .section(let id):
            return 100 + Int(id)
        }
    }
    
    static func ==(lhs: SelectivePrivacyPeersEntryStableId, rhs: SelectivePrivacyPeersEntryStableId) -> Bool {
        switch lhs {
        case let .peer(peerId):
            if case .peer(peerId) = rhs {
                return true
            } else {
                return false
            }
        case .add:
            if case .add = rhs {
                return true
            } else {
                return false
            }
        case let .section(sectionId):
            if case .section(sectionId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum SelectivePrivacyPeersEntry: TableItemListNodeEntry {
    case peerItem(Int32, Int32, Peer, ShortPeerDeleting?)
    case addItem(Int32, Bool)
    case section(Int32)
    
    var stableId: SelectivePrivacyPeersEntryStableId {
        switch self {
        case let .peerItem(_, _, peer, _):
            return .peer(peer.id)
        case .addItem:
            return .add
        case let .section(sectionId):
            return .section(sectionId)
        }
    }
    
    var stableIndex:Int32 {
        switch self {
        case let .peerItem(sectionId, index, _, _):
            return (sectionId * 1000) + index + 100
        case .addItem(let sectionId, _):
            return (sectionId * 1000) + 9999
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func ==(lhs: SelectivePrivacyPeersEntry, rhs: SelectivePrivacyPeersEntry) -> Bool {
        switch lhs {
        case let .peerItem(lhsSectionId, lhsIndex, lhsPeer, lhsEditing):
            if case let .peerItem(rhsSectionId, rhsIndex, rhsPeer, rhsEditing) = rhs {
                
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if lhsIndex != rhsIndex {
                    return false
                }
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .addItem(sectionId, editing):
            if case .addItem(sectionId, editing) = rhs {
                return true
            } else {
                return false
            }
        case let .section(sectionId):
            if case .section(sectionId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: SelectivePrivacyPeersEntry, rhs: SelectivePrivacyPeersEntry) -> Bool {
        return lhs.stableIndex < rhs.stableIndex
    }
    
    func item(_ arguments: SelectivePrivacyPeersControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .peerItem(_, _, peer, editing):
            
            
            
            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {
                
                interactionType = .deletable(onRemove: { peerId in
                    arguments.removePeer(peerId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: stableId, enabled: true, height:44, photoSize: NSMakeSize(32, 32), drawLastSeparator: true, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, generalType: .none, action: {
                arguments.openInfo(peer)
            })

        case .addItem:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.privacySettingsPeerSelectAddNew), nameStyle: blueActionButton, type: .none, action: {
                arguments.addPeer()
            })
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

private struct SelectivePrivacyPeersControllerState: Equatable {
    let editing: Bool
    
    init() {
        self.editing = false
    }
    
    init(editing: Bool) {
        self.editing = editing
    }
    
    static func ==(lhs: SelectivePrivacyPeersControllerState, rhs: SelectivePrivacyPeersControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> SelectivePrivacyPeersControllerState {
        return SelectivePrivacyPeersControllerState(editing: editing)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> SelectivePrivacyPeersControllerState {
        return SelectivePrivacyPeersControllerState(editing: self.editing)
    }
}

private func selectivePrivacyPeersControllerEntries(state: SelectivePrivacyPeersControllerState, peers: [Peer]) -> [SelectivePrivacyPeersEntry] {
    var entries: [SelectivePrivacyPeersEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    var index: Int32 = 0
    for peer in peers {
        var deleting:ShortPeerDeleting? = nil
        if state.editing {
            deleting = ShortPeerDeleting(editable: true)
        }
        entries.append(.peerItem(sectionId, index, peer, deleting))
        index += 1
    }
    
    entries.append(.addItem(sectionId, state.editing))
    
    return entries
}


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<SelectivePrivacyPeersEntry>], right: [AppearanceWrapperEntry<SelectivePrivacyPeersEntry>], initialSize:NSSize, arguments:SelectivePrivacyPeersControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class SelectivePrivacySettingsPeersController: EditableViewController<TableView> {

    private let title:String
    private let initialPeerIds:[PeerId]
    private let updated:([PeerId])->Void
    private let statePromise = ValuePromise(SelectivePrivacyPeersControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: SelectivePrivacyPeersControllerState())
    init(account: Account, title: String, initialPeerIds: [PeerId], updated: @escaping ([PeerId]) -> Void) {
        self.title = title
        self.initialPeerIds = initialPeerIds
        self.updated = updated
        super.init(account)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        let title = self.title
        self.setCenterTitle(title)
        let initialPeerIds = self.initialPeerIds
        let updated = self.updated
        let initialSize = self.atomicSize
        
        let statePromise = self.statePromise
        let stateValue = self.stateValue
        
        let actionsDisposable = DisposableSet()
        
        let addPeerDisposable = MetaDisposable()
        actionsDisposable.add(addPeerDisposable)
        
        let removePeerDisposable = MetaDisposable()
        actionsDisposable.add(removePeerDisposable)
        
        let peersPromise = Promise<[Peer]>()
        peersPromise.set(account.postbox.transaction { transaction -> [Peer] in
            var result: [Peer] = []
            for peerId in initialPeerIds {
                if let peer = transaction.getPeer(peerId) {
                    result.append(peer)
                }
            }
            return result
        })
        
        var currentPeerIds:[PeerId] = []
        
        let arguments = SelectivePrivacyPeersControllerArguments(account: account, removePeer: { memberId in
            let applyPeers: Signal<Void, NoError> = peersPromise.get()
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { peers -> Signal<Void, NoError> in
                    var updatedPeers = peers
                    for i in 0 ..< updatedPeers.count {
                        if updatedPeers[i].id == memberId {
                            updatedPeers.remove(at: i)
                            break
                        }
                    }
                    peersPromise.set(.single(updatedPeers))
                    updated(updatedPeers.map { $0.id })
                    
                    return .complete()
            }
            
            removePeerDisposable.set(applyPeers.start())
        }, addPeer: {
            
            addPeerDisposable.set(selectModalPeers(account: account, title: title, settings: [.contacts], excludePeerIds: currentPeerIds, limit: 0, confirmation: {_ in return .single(true)}).start(next: { peerIds in
                
                let applyPeers: Signal<Void, NoError> = peersPromise.get()
                    |> take(1)
                    |> mapToSignal { peers -> Signal<[Peer], NoError> in
                        return account.postbox.transaction { transaction -> [Peer] in
                            var updatedPeers = peers
                            var existingIds = Set(updatedPeers.map { $0.id })
                            for peerId in peerIds {
                                if let peer = transaction.getPeer(peerId), !existingIds.contains(peerId) {
                                    existingIds.insert(peerId)
                                    updatedPeers.append(peer)
                                }
                            }
                            return updatedPeers
                        }
                    }
                    |> deliverOnMainQueue
                    |> mapToSignal { updatedPeers -> Signal<Void, NoError> in
                        peersPromise.set(.single(updatedPeers))
                        updated(updatedPeers.map { $0.id })
                        return .complete()
                }
                
                removePeerDisposable.set(applyPeers.start())
            }))
        }, openInfo: { [weak self] peer in
            self?.navigationController?.push(PeerInfoController(account: account, peer: peer))
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<SelectivePrivacyPeersEntry>]> = Atomic(value: [])
        
        let signal = combineLatest(statePromise.get() |> deliverOnMainQueue, peersPromise.get() |> deliverOnMainQueue, appearanceSignal)
            |> map { state, peers, appearance -> TableUpdateTransition in
                
                currentPeerIds = peers.map({$0.id})
                
                let entries = selectivePrivacyPeersControllerEntries(state: state, peers: peers).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
                
            } |> afterDisposed {
                actionsDisposable.dispose()
        }
        
        genericView.merge(with: signal)

        readyOnce()
        
    }

    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
}
