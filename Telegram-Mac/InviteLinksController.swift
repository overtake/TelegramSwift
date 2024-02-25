//
//  InviteLinksController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

import TelegramCore
import Postbox



struct _ExportedInvitation : Equatable {
    var link: String
    var title: String?
    var isPermanent: Bool
    var requestApproval: Bool
    var isRevoked: Bool
    var adminId: PeerId
    var date: Int32
    var startDate: Int32?
    var expireDate: Int32?
    var usageLimit: Int32?
    var count: Int32?
    var requestedCount: Int32?
    
    var invitation: ExportedInvitation {
        return .link(link: link, title: title, isPermanent: isPermanent, requestApproval: requestApproval, isRevoked: isRevoked, adminId: adminId, date: date, startDate: startDate, expireDate: expireDate, usageLimit: usageLimit, count: count, requestedCount: requestedCount)
    }
    
    static func initialize(_ inivitation: ExportedInvitation) -> _ExportedInvitation? {
        switch inivitation {
        case .link(let link, let title, let isPermanent, let requestApproval, let isRevoked, let adminId, let date, let startDate, let expireDate, let usageLimit, let count, let requestedCount):
            return .init(link: link, title: title, isPermanent: isPermanent, requestApproval: requestApproval, isRevoked: isRevoked, adminId: adminId, date: date, startDate: startDate, expireDate: expireDate, usageLimit: usageLimit, count: count, requestedCount: requestedCount)
        case .publicJoinRequest:
            return nil
        }
    }
}

extension _ExportedInvitation {
    var isExpired: Bool {
        if let expiryDate = expireDate {
            if expiryDate < Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                return true
            }
        }
        return false
    }
    var isLimitReached: Bool {
        if let usageLimit = usageLimit, let count = count {
            if usageLimit == count {
                return true
            }
        }
        return false
    }
    
    func withUpdatedIsRevoked(_ isRevoked: Bool) -> _ExportedInvitation {
        return _ExportedInvitation(link: self.link, title: self.title, isPermanent: self.isPermanent, requestApproval: self.requestApproval, isRevoked: isRevoked, adminId: self.adminId, date: self.date, startDate: self.startDate, expireDate: self.expireDate, usageLimit: self.usageLimit, count: self.count, requestedCount: self.requestedCount)
    }
}
extension ExportedInvitation {
    var _invitation: _ExportedInvitation? {
        return _ExportedInvitation.initialize(self)
    }
}

final class InviteLinkPeerManager {
    
    struct State : Equatable {
        
        var list: [_ExportedInvitation]?
        var next: _ExportedInvitation?
        var creators:[ExportedInvitationCreator]?
        var totalCount: Int32
        var activeLoaded: Bool
        var revokedList: [_ExportedInvitation]?
        var nextRevoked: _ExportedInvitation?
        var totalRevokedCount: Int32
        var revokedLoaded: Bool
        var effectiveCount: Int32 {
            return totalCount + (self.creators?.reduce(0, { current, value in
                return current + value.count
            }) ?? 0)
        }

        static var `default`: State {
            return State(list: nil, next: nil, creators: nil, totalCount: 0, activeLoaded: false, revokedList: nil, nextRevoked: nil, totalRevokedCount: 0, revokedLoaded: false)
        }
    }
    
    let context: AccountContext
    let peerId: PeerId
    let adminId: PeerId?
    private let listDisposable = DisposableDict<Bool>()
    private let loadCreatorsDisposable = MetaDisposable()
    private let stateValue: Atomic<State> = Atomic(value: State.default)
    private let statePromise = ValuePromise(State.default, ignoreRepeated: true)
    private func updateState(_ f: (State) -> State) {
        statePromise.set(stateValue.modify (f))
    }
    
    var state: Signal<State, NoError> {
        return self.statePromise.get()
    }
    
    deinit {
        listDisposable.dispose()
        loadCreatorsDisposable.dispose()
        updateAdminsDisposable.dispose()
    }
    
    private let updateAdminsDisposable = MetaDisposable()
    init(context: AccountContext, peerId: PeerId, adminId: PeerId? = nil) {
        self.context = context
        self.peerId = peerId
        self.adminId = adminId
        self.loadNext()
        self.loadNext(true)
        if adminId == nil {
            self.loadCreators()
            let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.admins(peerId: peerId, updated: { [weak self] _ in
                self?.loadCreators()
            })
            updateAdminsDisposable.set(disposable)
        }
        
    }
    
    func createPeerExportedInvitation(title: String?, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Bool? = nil) -> Signal<_ExportedInvitation?, NoError> {
        let context = self.context
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            let signal = context.engine.peers.createPeerExportedInvitation(peerId: peerId, title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded) |> deliverOnMainQueue
            let disposable = signal.start(next: { [weak self] value in
                self?.updateState { state in
                    var state = state
                    state.list = state.list ?? []
                    if let value = value?._invitation {
                        state.list?.insert(value, at: 0)
                        state.totalCount += 1
                    }
                    return state
                }
                
                subscriber.putNext(value?._invitation)
                subscriber.putCompletion()
            })
            return disposable
        }
    }
    
    func editPeerExportedInvitation(link: _ExportedInvitation, title: String?, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Bool? = nil) -> Signal<NoValue, EditPeerExportedInvitationError> {
        let context = self.context
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            let signal = context.engine.peers.editPeerExportedInvitation(peerId: peerId, link: link.link, title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded)
            let disposable = signal.start(next: { [weak self] value in
                self?.updateState { state in
                    var state = state
                    state.list = state.list ?? []
                    if let value = value?._invitation, let index = state.list?.firstIndex(where: { $0.link == value.link }) {
                        state.list?[index] = value
                    }
                    return state
                }
                subscriber.putCompletion()
            }, error: { error in
                subscriber.putError(error)
            })
            return disposable
        }
    }

    func revokePeerExportedInvitation(link: _ExportedInvitation) -> Signal<NoValue, RevokePeerExportedInvitationError> {
        let context = self.context
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            
            let signal: Signal<RevokeExportedInvitationResult?, RevokePeerExportedInvitationError>
            signal = context.engine.peers.revokePeerExportedInvitation(peerId: peerId, link: link.link)
            let disposable = signal.start(next: { [weak self] value in
                self?.updateState { state in
                    var state = state
                    state.list = state.list ?? []
                    if let value = value {
                        switch value {
                        case let .update(link):
                            if let link = link._invitation {
                                state.revokedList = state.revokedList ?? []
                                state.list!.removeAll(where: { $0.link == link.link})
                                state.revokedList?.append(link)
                                state.revokedList?.sort(by: { $0.date < $1.date })
                                state.totalCount -= 1
                            }
                        case let .replace(link, new):
                            if let link = link._invitation, let new = new._invitation {
                                let link = link.withUpdatedIsRevoked(true)
                                state.revokedList = state.revokedList ?? []
                                state.list!.removeAll(where: { $0.link == link.link})
                                state.list!.insert(new, at: 0)
                                state.revokedList?.insert(link, at: 0)
                                state.revokedList?.sort(by: { $0.date > $1.date })
                            }
                        }

                    }
                    
                    return state
                }
                subscriber.putCompletion()
            }, error: { error in
                subscriber.putError(error)
            })
            return disposable
        }
    }

    func deletePeerExportedInvitation(link: _ExportedInvitation) -> Signal<Never, DeletePeerExportedInvitationError> {
        let context = self.context
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            let signal = context.engine.peers.deletePeerExportedInvitation(peerId: peerId, link: link.link)
            let disposable = signal.start(error: { error in
                subscriber.putError(error)
            }, completed: { [weak self] in
                self?.updateState { state in
                    var state = state
                    state.revokedList = state.revokedList ?? []
                    state.revokedList?.removeAll(where: { $0.link == link.link })
                    state.totalRevokedCount -= 1
                    return state
                }
                subscriber.putCompletion()
            })
            return disposable
        }
    }
    
    func deleteAllRevokedPeerExportedInvitations() -> Signal<Never, NoError> {
        let context = self.context
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            let signal = context.engine.peers.deleteAllRevokedPeerExportedInvitations(peerId: peerId, adminId: self?.adminId ?? context.peerId)
            let disposable = signal.start(completed: {
                self?.updateState { state in
                    var state = state
                    state.revokedList?.removeAll()
                    state.totalRevokedCount = 0
                    state.nextRevoked = nil
                    state.revokedLoaded = true
                    return state
                }
                subscriber.putCompletion()
            })
            return disposable
        }
    }

    func loadCreators() {
        let signal = context.engine.peers.peerExportedInvitationsCreators(peerId: peerId) |> deliverOnMainQueue
        loadCreatorsDisposable.set(signal.start(next: { [weak self] creators in
            self?.updateState { state in
                var state = state
                state.creators = creators
                return state
            }
        }))
    }

    
    func loadNext(_ forceLoadRevoked: Bool = false) {
        
        let revoked = forceLoadRevoked ? true : stateValue.with { $0.activeLoaded }
        
        if stateValue.with({ revoked ? !$0.revokedLoaded : !$0.activeLoaded }) {
            let offsetLink: _ExportedInvitation? = stateValue.with { state in
                if revoked {
                    return state.nextRevoked
                } else {
                    return state.next
                }
            }
            
            let signal = context.engine.peers.direct_peerExportedInvitations(peerId: peerId, revoked: revoked, adminId: self.adminId, offsetLink: offsetLink?.invitation) |> deliverOnMainQueue
            self.listDisposable.set(signal.start(next: { [weak self] list in
                self?.updateState { state in
                    var state = state
                    if revoked {
                        state.revokedList = (state.revokedList ?? []) + (list?.list?.compactMap { $0._invitation } ?? [])
                        state.totalRevokedCount = list?.totalCount ?? 0
                        state.revokedLoaded = state.revokedList?.count == Int(state.totalRevokedCount)
                        state.nextRevoked = state.revokedList?.last
                    } else {
                        state.list = (state.list ?? []) + (list?.list?.compactMap { $0._invitation } ?? [])
                        state.totalCount = list?.totalCount ?? 0
                        state.activeLoaded = state.list?.count == Int(state.totalCount)
                        state.next = state.list?.last
                    }
                    return state
                }
            }), forKey: revoked)
        }
        
    }
    
    private struct CachedKey : Hashable {
        let string: String
        let requested: Bool
    }
    private var cachedImporters:[CachedKey : PeerInvitationImportersContext] = [:]
    
    func importer(for link: _ExportedInvitation) -> (joined: PeerInvitationImportersContext, requested: PeerInvitationImportersContext) {
        let joined = self.cachedImporters[.init(string: link.link, requested: false)]
        let requested = self.cachedImporters[.init(string: link.link, requested: true)]

        if let requested = requested, let joined = joined {
            return (joined: joined, requested: requested)
        } else {
            let joined = context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .invite(invite: link.invitation, requested: false))
            let requested = context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .invite(invite: link.invitation, requested: true))
            self.cachedImporters[.init(string: link.link, requested: false)] = joined
            self.cachedImporters[.init(string: link.link, requested: true)] = requested
            return (joined: joined, requested: requested)
        }
    }
}


private final class InviteLinksArguments {
    let context: AccountContext
    let shareLink: (String)->Void
    let copyLink: (String)->Void
    let revokeLink: (_ExportedInvitation)->Void
    let editLink:(_ExportedInvitation)->Void
    let deleteLink:(_ExportedInvitation)->Void
    let deleteAll:()->Void
    let newLink:()->Void
    let open:(_ExportedInvitation)->Void
    let openAdminLinks:(ExportedInvitationCreator)->Void
    init(context: AccountContext, shareLink: @escaping(String)->Void, copyLink: @escaping(String)->Void, revokeLink: @escaping(_ExportedInvitation)->Void, editLink:@escaping(_ExportedInvitation)->Void, newLink:@escaping()->Void, deleteLink:@escaping(_ExportedInvitation)->Void, deleteAll:@escaping()->Void, open:@escaping(_ExportedInvitation)->Void, openAdminLinks: @escaping(ExportedInvitationCreator)->Void) {
        self.context = context
        self.shareLink = shareLink
        self.copyLink = copyLink
        self.revokeLink = revokeLink
        self.editLink = editLink
        self.newLink = newLink
        self.deleteLink = deleteLink
        self.deleteAll = deleteAll
        self.open = open
        self.openAdminLinks = openAdminLinks
    }
}

private struct InviteLinksState : Equatable {
    var permanent: _ExportedInvitation?
    var permanentImporterState: PeerInvitationImportersState?
    var list: [_ExportedInvitation]?
    var revokedList: [_ExportedInvitation]?
    var creators:[ExportedInvitationCreator]?
    var isAdmin: Bool
    var totalCount: Int
    var peer: PeerEquatable?
    var adminPeer: PeerEquatable?
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_permanent = InputDataIdentifier("_id_permanent")
private let _id_add_link = InputDataIdentifier("_id_add_link")
private let _id_loading = InputDataIdentifier("_id_loading")
private let _id_delete_all = InputDataIdentifier("_id_delete_all")
private func _id_links(_ links:[_ExportedInvitation]) -> InputDataIdentifier {
    return InputDataIdentifier("active_" + links.reduce("", { current, value in
        return current + value.link
    }))
}
private func _id_links_revoked(_ links:[_ExportedInvitation]) -> InputDataIdentifier {
    return InputDataIdentifier("revoked_" + links.reduce("", { current, value in
        return current + value.link
    }))
}
private func _id_creator(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_creator_\(peerId.toInt64())")
}

private func entries(_ state: InviteLinksState, arguments: InviteLinksArguments) -> [InputDataEntry] {
    
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    if !state.isAdmin {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
            let text:String = state.peer?.peer.isChannel == true ? strings().manageLinksHeaderChannelDesc :  strings().manageLinksHeaderGroupDesc
            return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.invitations, text: .initialize(string: text, color: theme.colors.listGrayText, font: .normal(.text)))
        }))
        index += 1

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }

   // if !state.isAdmin || state.peer?.peer.addressName == nil {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().manageLinksInviteLink), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        var peers = state.permanentImporterState?.importers.map { $0.peer } ?? []
        peers = Array(peers.prefix(3))

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_permanent, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
            return ExportedInvitationRowItem(initialSize, stableId: stableId, context: arguments.context, exportedLink: state.permanent, publicAddress: state.isAdmin ? nil : state.peer?.peer.addressName, lastPeers: peers, viewType: .singleItem, menuItems: {

                var items:[ContextMenuItem] = []
                if let permanent = state.permanent {
                    items.append(ContextMenuItem(strings().manageLinksContextCopy, handler: {
                        arguments.copyLink(permanent.link)
                    }, itemImage: MenuAnimation.menu_copy.value))
                    if state.adminPeer?.peer.isBot == true {
                        
                    } else {
                        if !items.isEmpty {
                            items.append(ContextSeparatorItem())
                        }
                        items.append(ContextMenuItem(strings().manageLinksContextRevoke, handler: {
                            arguments.revokeLink(permanent)
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    }
                    
                } else if let addressName = state.peer?.peer.addressName {
                    items.append(ContextMenuItem(strings().manageLinksContextCopy, handler: {
                        arguments.copyLink(addressName)
                    }, itemImage: MenuAnimation.menu_copy.value))
                }

                return .single(items)
            }, share: arguments.shareLink, open: arguments.open, copyLink: arguments.copyLink)
        }))

        if state.isAdmin, let peer = state.peer, let adminPeer = state.adminPeer {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().manageLinksAdminPermanentDesc(adminPeer.peer.displayTitle, peer.peer.displayTitle)), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
            index += 1
        }

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
 //   }

    

    if !state.isAdmin || (state.list != nil && !state.list!.isEmpty) {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().manageLinksAdditionLinks), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
    }

    struct Tuple : Equatable {
        let link: _ExportedInvitation
        let viewType: GeneralViewType
    }

    let viewType: GeneralViewType = state.list == nil || !state.list!.isEmpty ? .firstItem : .singleItem
    if !state.isAdmin {
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_add_link, equatable: InputDataEquatable(viewType), comparable: nil, item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().manageLinksCreateNew, nameStyle: blueActionButton, type: .none, viewType: viewType, action: arguments.newLink, drawCustomSeparator: true, thumb: GeneralThumbAdditional(thumb: theme.icons.proxyAddProxy, textInset: 43, thumbInset: 0))
        }))
        index += 1

        
//        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_link, data: .init(name: strings().manageLinksCreateNew, color: theme.colors.accent, icon: theme.icons.proxyAddProxy, type: .none, viewType: viewType, enabled: true, action: arguments.newLink)))
//        index += 1
    }
    if let list = state.list {
        if !list.isEmpty {
            for (i, link) in list.enumerated() {
                var viewType: GeneralViewType = bestGeneralViewType(list, for: i)
                if i == 0, !state.isAdmin {
                    if list.count == 1 {
                        viewType = .lastItem
                    } else {
                        viewType = .innerItem
                    }
                }

                let tuple = Tuple(link: link, viewType: viewType)

                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_links([link]), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                    return InviteLinkRowItem(initialSize, stableId: stableId, viewType: tuple.viewType, link: tuple.link, action: arguments.open, menuItems: { link in

                        var items:[ContextMenuItem] = []
                        items.append(ContextMenuItem(strings().manageLinksContextCopy, handler: {
                            arguments.copyLink(link.link)
                        }, itemImage: MenuAnimation.menu_copy.value))
                        if !link.isRevoked {
                            if !link.isExpired {
                                items.append(ContextMenuItem(strings().manageLinksContextShare, handler: {
                                    arguments.shareLink(link.link)
                                }, itemImage: MenuAnimation.menu_share.value))
                            }
                            if !link.isPermanent {
                                items.append(ContextMenuItem(strings().manageLinksContextEdit, handler: {
                                    arguments.editLink(link)
                                }, itemImage: MenuAnimation.menu_edit.value))
                            }
                           
                            if state.adminPeer?.peer.isBot == true {
                                
                            } else {
                                if !items.isEmpty {
                                    items.append(ContextSeparatorItem())
                                }
                                items.append(ContextMenuItem(strings().manageLinksContextRevoke, handler: {
                                    arguments.revokeLink(link)
                                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                            }
                        }

                        return .single(items)
                    })
                }))
                index += 1
            }
        } else {
            if !state.isAdmin {
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().manageLinksEmptyDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
                index += 1
            }
        }

        
        if let list = state.revokedList, list.count > 0 {
            
            if state.list?.isEmpty == false || !state.isAdmin {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
            }
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().manageLinksRevokedLinks), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1

          // if !state.isAdmin {
                entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_delete_all, data: .init(name: strings().manageLinksDeleteAll, color: theme.colors.redUI, icon: nil, type: .none, viewType: .firstItem, enabled: true, action: arguments.deleteAll)))
                index += 1
         //   }

            
            for (i, link) in list.enumerated() {
                
                var viewType: GeneralViewType = bestGeneralViewType(list, for: i)
                if i == 0 {
                    if list.count == 1 {
                        viewType = .lastItem
                    } else {
                        viewType = .innerItem
                    }
                }

                let tuple = Tuple(link: link, viewType: viewType)
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_links_revoked([link]), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                    return InviteLinkRowItem(initialSize, stableId: stableId, viewType: tuple.viewType, link: tuple.link, action: arguments.open, menuItems: { link in
                        var items:[ContextMenuItem] = []
                        items.append(ContextMenuItem(strings().manageLinksDelete, handler: {
                            arguments.deleteLink(link)
                        }))
                        return .single(items)
                    })
                }))
                index += 1
            }
            
        }
        
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: !state.isAdmin ? .lastItem : .singleItem)
        }))
        index += 1
    }
    


    if let creators = state.creators, !creators.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1


        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().manageLinksOtherAdmins), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        let creators = creators.filter { $0.peer.peer != nil }
        for (i, creator) in creators.enumerated() {

            let viewType = bestGeneralViewType(creators, for: i)

            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_creator(creator.peer.peerId), equatable: InputDataEquatable(creator), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: creator.peer.peer!, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 50, photoSize: NSMakeSize(36, 36), status: strings().manageLinksTitleCountCountable(Int(creator.count)), inset: NSEdgeInsets(left: 20, right: 20), viewType: viewType, action: {
                    arguments.openAdminLinks(creator)
                })
            }))
        }
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func InviteLinksController(context: AccountContext, peerId: PeerId, manager: InviteLinkPeerManager?) -> InputDataController {

    
    let initialState = InviteLinksState(permanent: nil, permanentImporterState: nil, list: nil, creators: nil, isAdmin: manager?.adminId != nil, totalCount: 0)
    
    let statePromise = ValuePromise<InviteLinksState>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InviteLinksState) -> InviteLinksState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    let manager = manager ?? InviteLinkPeerManager(context: context, peerId: peerId)
    var getController:(()->ViewController?)? = nil
    
    let arguments = InviteLinksArguments(context: context, shareLink: { link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
    }, copyLink: { link in
        getController?()?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
        copyToClipboard(link)
    }, revokeLink: { [weak manager] link in
        verifyAlert_button(for: context.window, header: strings().channelRevokeLinkConfirmHeader, information: strings().channelRevokeLinkConfirmText, ok: strings().channelRevokeLinkConfirmOK, cancel: strings().modalCancel, successHandler: { _ in
            if let manager = manager {
                _ = showModalProgress(signal: manager.revokePeerExportedInvitation(link: link), for: context.window).start(completed:{
                    _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
                })
            }
        })
    }, editLink: { [weak manager] link in
        showModal(with: ClosureInviteLinkController(context: context, peerId: peerId, mode: .edit(link), save: { [weak manager] updated in
            let signal = manager?.editPeerExportedInvitation(link: link, title: updated.title, expireDate: updated.date == .max ? nil : updated.date + Int32(Date().timeIntervalSince1970), usageLimit: updated.count == .max ? nil : updated.count, requestNeeded: updated.requestApproval)
            if let signal = signal {
                _ = showModalProgress(signal: signal, for: context.window).start(completed:{
                    _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
                })
            }
        }), for: context.window)
    }, newLink: { [weak manager] in
        showModal(with: ClosureInviteLinkController(context: context, peerId: peerId, mode: .new, save: { [weak manager] link in
            let signal = manager?.createPeerExportedInvitation(title: link.title, expireDate: link.date == .max ? nil : link.date + Int32(Date().timeIntervalSince1970), usageLimit: link.count == .max ? nil : link.count, requestNeeded: link.requestApproval)
            if let signal = signal {
                _ = showModalProgress(signal: signal, for: context.window).start(next: { invitation in
                    if let invitation = invitation {
                        copyToClipboard(invitation.link)
                        showModalText(for: context.window, text: strings().inviteLinkCreateCopied)
                    }
                })
            }
        }), for: context.window)
    }, deleteLink: { [weak manager] link in
        if let manager = manager {
            _ = showModalProgress(signal: manager.deletePeerExportedInvitation(link: link), for: context.window).start(completed:{
                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
            })
        }
    }, deleteAll: { [weak manager] in
        verifyAlert_button(for: context.window, header: strings().manageLinksDeleteAll, information: strings().manageLinksDeleteAllConfirm, ok: strings().manageLinksDeleteAll, cancel: strings().modalCancel, successHandler: { [weak manager] _ in
            if let manager = manager {
                _ = showModalProgress(signal: manager.deleteAllRevokedPeerExportedInvitations(), for: context.window).start(completed:{
                    _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
                })
            }
        })
        
    }, open: { [weak manager] invitation in
        if let manager = manager {
            showModal(with: ExportedInvitationController(invitation: invitation, peerId: peerId, accountContext: context, manager: manager, context: manager.importer(for: invitation)), for: context.window)
        }
    }, openAdminLinks: { creator in
        let manager = InviteLinkPeerManager(context: context, peerId: peerId, adminId: creator.peer.peerId)
        getController?()?.navigationController?.push(InviteLinksController(context: context, peerId: peerId, manager: manager))
    })
        
    let actionsDisposable = DisposableSet()


    let importers: Signal<(PeerInvitationImportersState?, InviteLinkPeerManager.State), NoError> = manager.state |> deliverOnMainQueue |> mapToSignal { [weak manager] state in
        if let permanent = state.list?.first(where: { $0.isPermanent }) {
            if let importer = manager?.importer(for: permanent).joined {
                return importer.state |> map(Optional.init) |> map { ($0, state) }
            } else {
                return .single((nil, state))
            }
        } else {
            return .single((nil, state))
        }
    }

    var peers: [Signal<PeerEquatable, NoError>] = []

    peers.append(context.account.postbox.loadedPeerWithId(peerId) |> map { PeerEquatable($0) })

    if let adminId = manager.adminId {
        peers.append(context.account.postbox.loadedPeerWithId(adminId) |> map { PeerEquatable($0) })
    }

    actionsDisposable.add(combineLatest(manager.state, importers, combineLatest(peers)).start(next: { state, permanentImporterState, peers in
        updateState { current in
            var current = current
            current.peer = peers.first
            if peers.count == 2 {
                current.adminPeer = peers.last
            }
            if current.peer?.peer.addressName != nil && !current.isAdmin {
                current.permanent = nil
            } else {
                current.permanent = state.list?.first(where: { $0.isPermanent })
            }
            current.permanentImporterState = permanentImporterState.0
            current.list = state.list?.filter({ $0.link != current.permanent?.link })
            current.revokedList = state.revokedList
            current.creators = state.creators
            current.totalCount = Int(state.totalCount)



            return current
        }
    }))
    
    let signal = statePromise.get() |> map {
        return InputDataSignalValue(entries: entries($0, arguments: arguments), animated: true)
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().manageLinksTitleNew, removeAfterDisappear: false, hasDone: false)
        
    controller.onDeinit = {
        actionsDisposable.dispose()
    }


    controller.getTitle = {
        let peer = stateValue.with { $0.adminPeer?.peer }
        if let peer = peer {
            return peer.displayTitle
        } else {
            return strings().manageLinksTitleNew
        }
    }
    controller.getStatus = {
        let isAdmin = stateValue.with { $0.isAdmin }
        if isAdmin {
            return strings().manageLinksTitleCountCountable(stateValue.with { $0.totalCount })
        } else {
            return nil
        }
    }
    
    controller.didLoad = { [weak manager] controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                manager?.loadNext()
            default:
                break
            }
        }
    }

    controller.afterTransaction = { controller in
        controller.requestUpdateCenterBar()
    }

    controller.contextObject = manager
    
    
    getController = { [weak controller] in
        return controller
    }
        
    return controller
    
}
