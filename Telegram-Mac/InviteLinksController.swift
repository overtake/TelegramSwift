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
import SyncCore
import TelegramCore
import Postbox
import TelegramApi





extension ExportedInvitation {
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
    
    func withUpdatedIsRevoked(_ isRevoked: Bool) -> ExportedInvitation {
        return ExportedInvitation(link: self.link, isPermanent: self.isPermanent, isRevoked: isRevoked, adminId: self.adminId, date: self.date, startDate: self.startDate, expireDate: self.expireDate, usageLimit: self.usageLimit, count: self.count)
    }
}

final class InviteLinkPeerManager {
    
    struct State : Equatable {
        
        var list: [ExportedInvitation]?
        var next: ExportedInvitation?
        var totalCount: Int32
        var activeLoaded: Bool
        var revokedList: [ExportedInvitation]?
        var nextRevoked: ExportedInvitation?
        var totalRevokedCount: Int32
        var revokedLoaded: Bool
        static var `default`: State {
            return State(list: nil, next: nil, totalCount: 0, activeLoaded: false, revokedList: nil, nextRevoked: nil, totalRevokedCount: 0, revokedLoaded: false)
        }
    }
    
    let context: AccountContext
    let peerId: PeerId
    
    private let listDisposable = DisposableDict<Bool>()
        
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
    }
    
    init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
        self.loadNext()
    }
    
    func createPeerExportedInvitation(expireDate: Int32?, usageLimit: Int32?) -> Signal<NoValue, NoError> {
        let account = self.context.account
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            let signal = TelegramCore.createPeerExportedInvitation(account: account, peerId: peerId, expireDate: expireDate, usageLimit: usageLimit) |> deliverOnMainQueue
            let disposable = signal.start(next: { [weak self] value in
                self?.updateState { state in
                    var state = state
                    state.list = state.list ?? []
                    if let value = value {
                        state.list?.insert(value, at: 0)
                        state.totalCount += 1
                    }
                    return state
                }
                subscriber.putCompletion()
            })
            return disposable
        }
    }
    
    func editPeerExportedInvitation(link: ExportedInvitation, expireDate: Int32?, usageLimit: Int32?) -> Signal<NoValue, EditPeerExportedInvitationError> {
        let account = self.context.account
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            let signal = TelegramCore.editPeerExportedInvitation(account: account, peerId: peerId, link: link.link, expireDate: expireDate, usageLimit: usageLimit)
            let disposable = signal.start(next: { [weak self] value in
                self?.updateState { state in
                    var state = state
                    state.list = state.list ?? []
                    if let value = value, let index = state.list?.firstIndex(where: { $0.link == value.link }) {
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

    func revokePeerExportedInvitation(link: ExportedInvitation) -> Signal<NoValue, RevokePeerExportedInvitationError> {
        let account = self.context.account
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            
            let signal: Signal<ExportedInvitation?, RevokePeerExportedInvitationError>
            if !link.isPermanent {
                signal = TelegramCore.revokePeerExportedInvitation(account: account, peerId: peerId, link: link.link)
            } else {
                signal = revokePersistentPeerExportedInvitation(account: account, peerId: peerId) |> mapError { _ in .generic }
            }
            let disposable = signal.start(next: { [weak self] value in
                self?.updateState { state in
                    var state = state
                    state.list = state.list ?? []
                    if let _ = value {
                        state.revokedList = state.revokedList ?? []
                        state.list!.removeAll(where: { $0.link == link.link})
                        state.revokedList?.append(link.withUpdatedIsRevoked(true))
                        state.revokedList?.sort(by: { $0.date < $1.date })
                        state.totalCount -= 1
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

    func deletePeerExportedInvitation(link: ExportedInvitation) -> Signal<Never, DeletePeerExportedInvitationError> {
        let account = self.context.account
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            let signal = TelegramCore.deletePeerExportedInvitation(account: account, peerId: peerId, link: link.link)
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
        let account = self.context.account
        let peerId = self.peerId
        return Signal { [weak self] subscriber in
            let signal = TelegramCore.deleteAllRevokedPeerExportedInvitations(account: account, peerId: peerId)
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


    
    func loadNext() {
        
        let revoked = stateValue.with { $0.activeLoaded }
        
        if stateValue.with({ revoked ? !$0.revokedLoaded : !$0.activeLoaded }) {
            
            let offsetLink: ExportedInvitation? = stateValue.with { state in
                if revoked {
                    return state.nextRevoked
                } else {
                    return state.next
                }
            }
            
            let signal = TelegramCore.peerExportedInvitations(account: context.account, peerId: peerId, revoked: revoked, offsetLink: offsetLink) |> deliverOnMainQueue
            self.listDisposable.set(signal.start(next: { [weak self] list in
                self?.updateState { state in
                    var state = state
                    if revoked {
                        state.revokedList = (state.revokedList ?? []) + (list?.list ?? [])
                        state.totalRevokedCount = list?.totalCount ?? 0
                        state.revokedLoaded = state.revokedList?.count == Int(state.totalRevokedCount)
                        state.nextRevoked = state.revokedList?.last
                    } else {
                        state.list = (state.list ?? []) + (list?.list ?? [])
                        state.totalCount = list?.totalCount ?? 0
                        state.activeLoaded = state.list?.count == Int(state.totalCount)
                        state.next = state.list?.last
                    }
                    return state
                }
            }), forKey: revoked)
        }
        
    }
    
    private var cachedImporters:[String : PeerInvitationImportersContext] = [:]
    
    func importer(for link: ExportedInvitation) -> PeerInvitationImportersContext {
        let cached = self.cachedImporters[link.link]
        
        if let cached = cached {
            return cached
        } else {
            let value = PeerInvitationImportersContext(account: context.account, peerId: peerId, invite: link)
            cachedImporters[link.link] = value
            return value
        }
    }
}


private final class InviteLinksArguments {
    let context: AccountContext
    let shareLink: (String)->Void
    let copyLink: (String)->Void
    let revokeLink: (ExportedInvitation)->Void
    let editLink:(ExportedInvitation)->Void
    let deleteLink:(ExportedInvitation)->Void
    let deleteAll:()->Void
    let newLink:()->Void
    let open:(ExportedInvitation)->Void
    init(context: AccountContext, shareLink: @escaping(String)->Void, copyLink: @escaping(String)->Void, revokeLink: @escaping(ExportedInvitation)->Void, editLink:@escaping(ExportedInvitation)->Void, newLink:@escaping()->Void, deleteLink:@escaping(ExportedInvitation)->Void, deleteAll:@escaping()->Void, open:@escaping(ExportedInvitation)->Void) {
        self.context = context
        self.shareLink = shareLink
        self.copyLink = copyLink
        self.revokeLink = revokeLink
        self.editLink = editLink
        self.newLink = newLink
        self.deleteLink = deleteLink
        self.deleteAll = deleteAll
        self.open = open
    }
}

private struct InviteLinksState : Equatable {
    var permanent: ExportedInvitation?
    var permanentImporterState: PeerInvitationImportersState?
    var list: [ExportedInvitation]?
    var revokedList: [ExportedInvitation]?
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_permanent = InputDataIdentifier("_id_permanent")
private let _id_add_link = InputDataIdentifier("_id_add_link")
private let _id_loading = InputDataIdentifier("_id_loading")
private let _id_delete_all = InputDataIdentifier("_id_delete_all")
private func _id_links(_ links:[ExportedInvitation]) -> InputDataIdentifier {
    return InputDataIdentifier("active_" + links.reduce("", { current, value in
        return current + value.link
    }))
}
private func _id_links_revoked(_ links:[ExportedInvitation]) -> InputDataIdentifier {
    return InputDataIdentifier("revoked_" + links.reduce("", { current, value in
        return current + value.link
    }))
}

private func entries(_ state: InviteLinksState, arguments: InviteLinksArguments) -> [InputDataEntry] {
    
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, item: { initialSize, stableId in
        let text:String = L10n.manageLinksHeaderDesc
        return AnimtedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.invitations, text: .initialize(string: text, color: theme.colors.listGrayText, font: .normal(.text)))
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.manageLinksPermanent), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    var peers = state.permanentImporterState?.importers.map { $0.peer } ?? []
    peers = Array(peers.prefix(3))
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_permanent, equatable: InputDataEquatable(state), item: { initialSize, stableId in
        return ExportedInvitationRowItem(initialSize, stableId: stableId, context: arguments.context, exportedLink: state.permanent, lastPeers: peers, viewType: .singleItem, menuItems: {
            
            var items:[ContextMenuItem] = []
            if let permanent = state.permanent {
                items.append(ContextMenuItem(L10n.manageLinksContextCopy, handler: {
                    arguments.copyLink(permanent.link)
                }))
                items.append(ContextMenuItem(L10n.manageLinksContextRevoke, handler: {
                    arguments.revokeLink(permanent)
                }))
            }
            
            return .single(items)
        }, share: arguments.shareLink)
    }))
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.manageLinksAdditionLinks), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    
    let viewType: GeneralViewType = state.list == nil || !state.list!.isEmpty ? .firstItem : .singleItem
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_link, data: .init(name: L10n.manageLinksCreateNew, color: theme.colors.accent, icon: theme.icons.proxyAddProxy, type: .none, viewType: viewType, enabled: true, action: arguments.newLink, disableBorder: true)))
    index += 1
    if let list = state.list {
        let chunks = list.chunks(2)
        struct Tuple : Equatable {
            let links:[ExportedInvitation]
            let viewType: GeneralViewType
        }
        for (i, chunk) in chunks.enumerated() {
            
            var viewType: GeneralViewType = bestGeneralViewType(chunks, for: i)
            var topInset: CGFloat = 5
            if i == 0 {
                if chunks.count == 1 {
                    viewType = .lastItem
                } else {
                    viewType = .innerItem
                }
                topInset = 1
            }
            viewType = viewType.withUpdatedInsets(NSEdgeInsets(top: viewType.position == .first || viewType.position == .single ? 10 : topInset, left: 10, bottom: viewType.position == .last || viewType.position == .single ? 10 : 5, right: 10))

            let tuple = Tuple(links: chunk, viewType: viewType)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_links(chunk), equatable: InputDataEquatable(tuple), item: { initialSize, stableId in
                return InviteLinkRowItem(initialSize, stableId: stableId, viewType: tuple.viewType, links: tuple.links, action: arguments.open, menuItems: { link in
                    
                    var items:[ContextMenuItem] = []
                    items.append(ContextMenuItem.init(L10n.manageLinksContextCopy, handler: {
                        arguments.copyLink(link.link)
                    }))
                    if !link.isRevoked {
                        if !link.isExpired {
                            items.append(ContextMenuItem(L10n.manageLinksContextShare, handler: {
                                arguments.shareLink(link.link)
                            }))
                        }
                        
                        items.append(ContextMenuItem.init(L10n.manageLinksContextEdit, handler: {
                            arguments.editLink(link)
                        }))
                        items.append(ContextMenuItem(L10n.manageLinksContextRevoke, handler: {
                            arguments.revokeLink(link)
                        }))
                    }
                    
                    return .single(items)
                })
            }))
            index += 1
        }
        
        if let list = state.revokedList, list.count > 0 {
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.manageLinksRevokedLinks), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1

            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_delete_all, data: .init(name: L10n.manageLinksDeleteAll, color: theme.colors.redUI, icon: nil, type: .none, viewType: .firstItem, enabled: true, action: arguments.deleteAll, disableBorder: true)))
            index += 1
            
            let chunks = list.chunks(2)
            struct Tuple : Equatable {
                let links:[ExportedInvitation]
                let viewType: GeneralViewType
            }
            for (i, chunk) in chunks.enumerated() {
                
                var viewType: GeneralViewType = bestGeneralViewType(chunks, for: i)
                var topInset: CGFloat = 5
                if i == 0 {
                    if chunks.count == 1 {
                        viewType = .lastItem
                    } else {
                        viewType = .innerItem
                    }
                    topInset = 1
                }
                viewType = viewType.withUpdatedInsets(NSEdgeInsets(top: viewType.position == .first || viewType.position == .single ? 10 : topInset, left: 10, bottom: viewType.position == .last || viewType.position == .single ? 10 : 5, right: 10))
                
                let tuple = Tuple(links: chunk, viewType: viewType)
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_links_revoked(chunk), equatable: InputDataEquatable(tuple), item: { initialSize, stableId in
                    return InviteLinkRowItem(initialSize, stableId: stableId, viewType: tuple.viewType, links: tuple.links, action: arguments.open, menuItems: { link in
                        
                        var items:[ContextMenuItem] = []
                        items.append(ContextMenuItem(L10n.manageLinksDelete, handler: {
                            arguments.deleteLink(link)
                        }))
                        return .single(items)
                    })
                }))
                index += 1
            }
            
        }
        
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .lastItem)
        }))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func InviteLinksController(context: AccountContext, peerId: PeerId, manager: InviteLinkPeerManager?) -> InputDataController {

    
    let initialState = InviteLinksState(permanent: nil, permanentImporterState: nil, list: nil)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InviteLinksState) -> InviteLinksState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    let manager = manager ?? InviteLinkPeerManager(context: context, peerId: peerId)
    var getController:(()->ViewController?)? = nil
    
    let arguments = InviteLinksArguments(context: context, shareLink: { link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
    }, copyLink: { link in
        getController?()?.show(toaster: ControllerToaster(text: L10n.shareLinkCopied))
        copyToClipboard(link)
    }, revokeLink: { [weak manager] link in
        confirm(for: context.window, header: L10n.channelRevokeLinkConfirmHeader, information: L10n.channelRevokeLinkConfirmText, okTitle: L10n.channelRevokeLinkConfirmOK, cancelTitle: L10n.modalCancel, successHandler: { _ in
            if let manager = manager {
                _ = showModalProgress(signal: manager.revokePeerExportedInvitation(link: link), for: context.window).start()
            }
        })
    }, editLink: { [weak manager] link in
        showModal(with: ClosureInviteLinkController(context: context, peerId: peerId, mode: .edit(link), save: { [weak manager] updated in
            let signal = manager?.editPeerExportedInvitation(link: link, expireDate: updated.date == .max ? nil : updated.date + Int32(Date().timeIntervalSince1970), usageLimit: updated.count == .max ? nil : updated.count)
            if let signal = signal {
                _ = showModalProgress(signal: signal, for: context.window).start()
            }
        }), for: context.window)
    }, newLink: { [weak manager] in
        showModal(with: ClosureInviteLinkController(context: context, peerId: peerId, mode: .new, save: { [weak manager] link in
            let signal = manager?.createPeerExportedInvitation(expireDate: link.date == .max ? nil : link.date + Int32(Date().timeIntervalSince1970), usageLimit: link.count == .max ? nil : link.count)
            if let signal = signal {
                _ = showModalProgress(signal: signal, for: context.window).start()
            }
        }), for: context.window)
    }, deleteLink: { [weak manager] link in
        if let manager = manager {
            _ = showModalProgress(signal: manager.deletePeerExportedInvitation(link: link), for: context.window).start()
        }
    }, deleteAll: { [weak manager] in
        confirm(for: context.window, header: L10n.manageLinksDeleteAll, information: L10n.manageLinksDeleteAllConfirm, okTitle: L10n.manageLinksDeleteAll, cancelTitle: L10n.modalCancel, successHandler: { [weak manager] _ in
            if let manager = manager {
                _ = showModalProgress(signal: manager.deleteAllRevokedPeerExportedInvitations(), for: context.window).start()
            }
        })
        
    }, open: { [weak manager] invitation in
        if let manager = manager {
            showModal(with: ExportedInvitationController(invitation: invitation, accountContext: context, context: manager.importer(for: invitation)), for: context.window)
        }
    })
    
    let peerView = context.account.viewTracker.peerView(peerId)

    let permanentLink = peerView |> map {
        ($0.cachedData as? CachedChannelData)?.exportedInvitation ?? ($0.cachedData as? CachedGroupData)?.exportedInvitation
    }
    
    let actionsDisposable = DisposableSet()
    
    context.account.viewTracker.forceUpdateCachedPeerData(peerId: peerId)
    
    let importers: Signal<PeerInvitationImportersState?, NoError> = permanentLink |> deliverOnMainQueue |> mapToSignal { [weak manager] permanent in
        if let permanent = permanent {
            if let state = manager?.importer(for: permanent).state {
                return state |> map(Optional.init)
            } else {
                return .single(nil)
            }
        } else {
            return .single(nil)
        }
    }
        
    actionsDisposable.add(combineLatest(permanentLink, manager.state, importers).start(next: { permanent, state, permanentImporterState in
        updateState { current in
            var current = current
            current.permanent = permanent
            current.permanentImporterState = permanentImporterState
            current.list = state.list?.filter({ $0.link != permanent?.link })
            current.revokedList = state.revokedList
            return current
        }
    }))
    
    let signal = statePromise.get() |> map {
        return InputDataSignalValue(entries: entries($0, arguments: arguments), animated: true)
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.manageLinksTitle, removeAfterDisappear: false, hasDone: false)
        
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    
    controller.didLoaded = { [weak manager] controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                manager?.loadNext()
            default:
                break
            }
        }
    }
    
    controller.contextOject = manager
    
    
    getController = { [weak controller] in
        return controller
    }
        
    return controller
    
}
