//
//  SelectivePrivacySettingsPeersController.swift
//  Telegram
//
//  Created by keepcoder on 02/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox


private final class SelectivePrivacyPeersControllerArguments {
    let context: AccountContext

    let removePeer: (PeerId) -> Void
    let addPeer: () -> Void
    let openInfo:(Peer) -> Void
    init(context: AccountContext, removePeer: @escaping (PeerId) -> Void, addPeer: @escaping () -> Void, openInfo:@escaping(Peer) -> Void) {
        self.context = context
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
}

private enum SelectivePrivacyPeersEntry: TableItemListNodeEntry {
    case addItem(Int32, Bool, GeneralViewType)
    case peerItem(Int32, Int32, SelectivePrivacyPeer, ShortPeerDeleting?, GeneralViewType)
    case section(Int32)

    var stableId: SelectivePrivacyPeersEntryStableId {
        switch self {
        case let .peerItem(_, _, peer, _, _):
            return .peer(peer.peer.id)
        case .addItem:
            return .add
        case let .section(sectionId):
            return .section(sectionId)
        }
    }

    var stableIndex:Int32 {
        switch self {
        case .addItem(let sectionId, _, _):
            return (sectionId * 1000) + 1_000_000
        case let .peerItem(sectionId, index, _, _, _):
            return (sectionId * 1000) + index
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }

    static func <(lhs: SelectivePrivacyPeersEntry, rhs: SelectivePrivacyPeersEntry) -> Bool {
        return lhs.stableIndex < rhs.stableIndex
    }

    func item(_ arguments: SelectivePrivacyPeersControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .peerItem(_, _, peer, editing, viewType):



            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {

                interactionType = .deletable(onRemove: { peerId in
                    arguments.removePeer(peerId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }

            var status: String? = nil
            let count = peer.participantCount
            if let count = count {
                let count = Int(count)
                let countValue = strings().privacySettingsGroupMembersCountCountable(count)
                status = countValue.replacingOccurrences(of: "\(count)", with: count.separatedNumber)
            }


            return ShortPeerRowItem(initialSize, peer: peer.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, enabled: true, height:44, photoSize: NSMakeSize(30, 30), status: status, drawLastSeparator: true, inset: NSEdgeInsets(left: 20, right: 20), interactionType: interactionType, generalType: .none, viewType: viewType, action: {
                arguments.openInfo(peer.peer)
            }, contextMenuItems: {
                return .single([ContextMenuItem(strings().confirmDelete, handler: {
                    arguments.removePeer(peer.peer.id)
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)])
            })

        case let .addItem(_, _, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().privacySettingsPeerSelectAddUserOrGroup, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.addPeer()
            })
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
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

private func selectivePrivacyPeersControllerEntries(state: SelectivePrivacyPeersControllerState, peers: [SelectivePrivacyPeer]) -> [SelectivePrivacyPeersEntry] {
    var entries: [SelectivePrivacyPeersEntry] = []

    var sectionId:Int32 = 1

    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.addItem(sectionId, state.editing, .singleItem))

    entries.append(.section(sectionId))
    sectionId += 1
    
    var index: Int32 = 0
    for (i, peer) in peers.enumerated() {
        var deleting:ShortPeerDeleting? = nil
        if state.editing {
            deleting = ShortPeerDeleting(editable: true)
        }
        entries.append(.peerItem(sectionId, index, peer, deleting, bestGeneralViewType(peers, for: i)))
        index += 1
    }
    
    entries.append(.section(sectionId))
    sectionId += 1

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
    private let initialPeers:[PeerId: SelectivePrivacyPeer]
    private let updated:([PeerId: SelectivePrivacyPeer])->Void
    private let statePromise = ValuePromise(SelectivePrivacyPeersControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: SelectivePrivacyPeersControllerState())
    init(_ context: AccountContext, title: String, initialPeers: [PeerId: SelectivePrivacyPeer], updated: @escaping ([PeerId: SelectivePrivacyPeer]) -> Void) {
        self.title = title
        self.initialPeers = initialPeers
        self.updated = updated
        super.init(context)
    }
    
    override var defaultBarTitle: String {
        return self.title
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }

        let context = self.context
        let title = self.title
        self.setCenterTitle(title)
        let initialPeers = self.initialPeers
        let updated = self.updated
        let initialSize = self.atomicSize

        let statePromise = self.statePromise
        let stateValue = self.stateValue

        let actionsDisposable = DisposableSet()

        let addPeerDisposable = MetaDisposable()
        actionsDisposable.add(addPeerDisposable)

        let removePeerDisposable = MetaDisposable()
        actionsDisposable.add(removePeerDisposable)

        let peersPromise = Promise<[SelectivePrivacyPeer]>()
        peersPromise.set(context.account.postbox.transaction { transaction -> [SelectivePrivacyPeer] in
            return Array(initialPeers.values)
        })


        var currentPeerIds:[PeerId] = []

        let arguments = SelectivePrivacyPeersControllerArguments(context: context, removePeer: { memberId in
            let applyPeers: Signal<Void, NoError> = peersPromise.get()
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { peers -> Signal<Void, NoError> in
                    var updatedPeers = peers
                    for i in 0 ..< updatedPeers.count {
                        if updatedPeers[i].peer.id == memberId {
                            updatedPeers.remove(at: i)
                            break
                        }
                    }
                    peersPromise.set(.single(updatedPeers))

                    var updatedPeerDict: [PeerId: SelectivePrivacyPeer] = [:]
                    for peer in updatedPeers {
                        updatedPeerDict[peer.peer.id] = peer
                    }
                    updated(updatedPeerDict)

                    return .complete()
            }

            removePeerDisposable.set(applyPeers.start())

        }, addPeer: {

            addPeerDisposable.set(selectModalPeers(window: context.window, context: context, title: title, excludePeerIds: currentPeerIds, limit: 0, behavior: SelectChatsBehavior(settings: [.groups, .contacts, .remote, .bots]), confirmation: {_ in return .single(true) }).start(next: { peerIds in
                let applyPeers: Signal<Void, NoError> = peersPromise.get()
                    |> take(1)
                    |> mapToSignal { peers -> Signal<[SelectivePrivacyPeer], NoError> in
                        return context.account.postbox.transaction { transaction -> [SelectivePrivacyPeer] in
                            var updatedPeers = peers
                            var existingIds = Set(updatedPeers.map { $0.peer.id })
                            for peerId in peerIds {
                                if let peer = transaction.getPeer(peerId), !existingIds.contains(peerId) {
                                    existingIds.insert(peerId)
                                    var participantCount: Int32?
                                    if let channel = peer as? TelegramChannel, case .group = channel.info {
                                        if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData {
                                            participantCount = cachedData.participantsSummary.memberCount
                                        }
                                    }

                                    updatedPeers.append(SelectivePrivacyPeer(peer: peer, participantCount: participantCount))
                                }
                            }
                            return updatedPeers
                        }
                    }
                    |> deliverOnMainQueue
                    |> mapToSignal { updatedPeers -> Signal<Void, NoError> in
                        peersPromise.set(.single(updatedPeers))

                        var updatedPeerDict: [PeerId: SelectivePrivacyPeer] = [:]
                        for peer in updatedPeers {
                            updatedPeerDict[peer.peer.id] = peer
                        }
                        updated(updatedPeerDict)

                        return .complete()
                }

                removePeerDisposable.set(applyPeers.start())
            }))
        }, openInfo: { [weak self] peer in
            if let navigation = self?.navigationController {
                PeerInfoController.push(navigation: navigation, context: context, peerId: peer.id)
            }
        })

        let previous:Atomic<[AppearanceWrapperEntry<SelectivePrivacyPeersEntry>]> = Atomic(value: [])

        let signal = combineLatest(statePromise.get() |> deliverOnMainQueue, peersPromise.get() |> deliverOnMainQueue, appearanceSignal)
            |> map { state, peers, appearance -> TableUpdateTransition in

                currentPeerIds = peers.map { $0.peer.id }

                let entries = selectivePrivacyPeersControllerEntries(state: state, peers: peers).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)

            } |> afterDisposed {
                actionsDisposable.dispose()
        }
        
        actionsDisposable.add(signal.start(next: { [weak self] transition in
            guard let `self` = self else { return }
            self.genericView.merge(with: transition)
            self.readyOnce()
            
        }))

    }

    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }

}
