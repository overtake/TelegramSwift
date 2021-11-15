//
//  ExportedInvitationController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import SwiftSignalKit
import Postbox
import TGUIKit

private final class ExportInvitationArguments {
    let context: (joined: PeerInvitationImportersContext, requested: PeerInvitationImportersContext)
    let accountContext: AccountContext
    let copyLink: (String)->Void
    let shareLink: (String)->Void
    let openProfile:(PeerId)->Void
    let revokeLink: (ExportedInvitation)->Void
    let editLink:(ExportedInvitation)->Void
    init(context: (joined: PeerInvitationImportersContext, requested: PeerInvitationImportersContext), accountContext: AccountContext, copyLink: @escaping(String)->Void, shareLink: @escaping(String)->Void, openProfile:@escaping(PeerId)->Void, revokeLink: @escaping(ExportedInvitation)->Void, editLink: @escaping(ExportedInvitation)->Void) {
        self.context = context
        self.accountContext = accountContext
        self.copyLink = copyLink
        self.shareLink = shareLink
        self.openProfile = openProfile
        self.revokeLink = revokeLink
        self.editLink = editLink
    }
}

private struct State : Equatable {
    var requestedState: PeerInvitationImportersState?
    var joinedState: PeerInvitationImportersState?
}

private let _id_link = InputDataIdentifier("_id_link")
private func _id_admin(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_admin_\(peerId.toInt64())")
}
private func _id_peer(_ peerId: PeerId, joined: Bool) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(peerId.toInt64())_\(joined)")
}
private func entries(_ state: State, admin: Peer?, invitation: ExportedInvitation, arguments: ExportInvitationArguments) -> [InputDataEntry] {
    
    let joinedState: PeerInvitationImportersState? = state.joinedState
    let requestedState: PeerInvitationImportersState? = state.requestedState
    
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_link, equatable: InputDataEquatable(invitation), comparable: nil, item: { initialSize, stableId in
        return ExportedInvitationRowItem(initialSize, stableId: stableId, context: arguments.accountContext, exportedLink: invitation, lastPeers: [], viewType: .singleItem, mode: .short, menuItems: {

            var items:[ContextMenuItem] = []

            items.append(ContextMenuItem(strings().exportedInvitationContextCopy, handler: {
                arguments.copyLink(invitation.link)
            }))

            if !invitation.isRevoked {
                if !invitation.isExpired {
                    items.append(ContextMenuItem(strings().manageLinksContextShare, handler: {
                        arguments.shareLink(invitation.link)
                    }))
                }
                if !invitation.isPermanent {
                    items.append(ContextMenuItem(strings().manageLinksContextEdit, handler: {
                        arguments.editLink(invitation)
                    }))
                }
               
                if admin?.isBot == true {
                    
                } else {
                    items.append(ContextMenuItem(strings().manageLinksContextRevoke, handler: {
                        arguments.revokeLink(invitation)
                    }))
                }
            }
            return .single(items)
        }, share: arguments.shareLink, copyLink: arguments.copyLink)
    }))
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = appAppearance.locale
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    
    
    if let admin = admin {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().exportedInvitationLinkCreatedBy), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_admin(admin.id), equatable: InputDataEquatable(PeerEquatable(admin)), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: admin, account: arguments.accountContext.account, stableId: stableId, height: 48, photoSize: NSMakeSize(36, 36), status: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(invitation.date))), inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: .singleItem)
        }))
    }
    
    if let requestedState = requestedState {
        let importers = requestedState.importers.filter { $0.peer.peer != nil }
      
        if !importers.isEmpty {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().exportedInvitationPeopleRequestedCountable(Int(requestedState.count))), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            for importer in requestedState.importers {
                struct Tuple : Equatable {
                    let importer: PeerInvitationImportersState.Importer
                    let viewType: GeneralViewType
                }
                
                let tuple = Tuple(importer: importer, viewType: bestGeneralViewType(requestedState.importers, for: importer))
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(importer.peer.peerId, joined: false), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: tuple.importer.peer.peer!, account: arguments.accountContext.account, stableId: stableId, height: 48, photoSize: NSMakeSize(36, 36), status: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(importer.date))), inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: tuple.viewType, action: {
                        arguments.openProfile(tuple.importer.peer.peerId)
                    }, contextMenuItems: {
                        let items = [ContextMenuItem(strings().exportedInvitationContextOpenProfile, handler: {
                            arguments.openProfile(tuple.importer.peer.peerId)
                        })]
                        
                        return .single(items)
                    })
                }))
            }
        }
    }

    
    if let joinedState = joinedState {
        let importers = joinedState.importers.filter { $0.peer.peer != nil }
      
        if !importers.isEmpty {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().exportedInvitationPeopleJoinedCountable(Int(joinedState.count))), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            for importer in joinedState.importers {
                struct Tuple : Equatable {
                    let importer: PeerInvitationImportersState.Importer
                    let viewType: GeneralViewType
                }
                
                let tuple = Tuple(importer: importer, viewType: bestGeneralViewType(joinedState.importers, for: importer))
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(importer.peer.peerId, joined: true), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: tuple.importer.peer.peer!, account: arguments.accountContext.account, stableId: stableId, height: 48, photoSize: NSMakeSize(36, 36), status: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(importer.date))), inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: tuple.viewType, action: {
                        arguments.openProfile(tuple.importer.peer.peerId)
                    }, contextMenuItems: {
                        let items = [ContextMenuItem(strings().exportedInvitationContextOpenProfile, handler: {
                            arguments.openProfile(tuple.importer.peer.peerId)
                        })]
                        
                        return .single(items)
                    })
                }))
            }
        }

        if joinedState.count == 0, !invitation.isExpired, !invitation.isRevoked, let usageCount = invitation.usageLimit, invitation.count == nil {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_join_count"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: strings().inviteLinkEmptyJoinDescCountable(Int(usageCount)), font: .normal(.text))
            }))
        }

    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ExportedInvitationController(invitation: ExportedInvitation, peerId: PeerId, accountContext: AccountContext, manager: InviteLinkPeerManager, context: (joined: PeerInvitationImportersContext, requested: PeerInvitationImportersContext)) -> InputDataModalController {
    
    let actionsDisposable = DisposableSet()
    
    var getController:(()->InputDataController?)? = nil
    var getModalController:(()->InputDataModalController?)? = nil

    let arguments = ExportInvitationArguments(context: context, accountContext: accountContext, copyLink: { link in
        getController?()?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
        copyToClipboard(link)
    }, shareLink: { link in
        showModal(with: ShareModalController(ShareLinkObject(accountContext, link: link)), for: accountContext.window)
    }, openProfile: { peerId in
        getModalController?()?.close()
        accountContext.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: accountContext, peerId: peerId))
    }, revokeLink: { [weak manager] link in
        confirm(for: accountContext.window, header: strings().channelRevokeLinkConfirmHeader, information: strings().channelRevokeLinkConfirmText, okTitle: strings().channelRevokeLinkConfirmOK, cancelTitle: strings().modalCancel, successHandler: { _ in
            if let manager = manager {
                _ = showModalProgress(signal: manager.revokePeerExportedInvitation(link: link), for: accountContext.window).start()
                getModalController?()?.close()
            }
        })
    }, editLink: { [weak manager] link in
        getModalController?()?.close()
        showModal(with: ClosureInviteLinkController(context: accountContext, peerId: peerId, mode: .edit(link), save: { [weak manager] updated in
            let signal = manager?.editPeerExportedInvitation(link: link, title: updated.title, expireDate: updated.date == .max ? 0 : updated.date + Int32(Date().timeIntervalSince1970), usageLimit: updated.count == .max ? 0 : updated.count)
            if let signal = signal {
                _ = showModalProgress(signal: signal, for: accountContext.window).start()
            }
        }), for: accountContext.window)
    })
    
    let initialState = State()
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    actionsDisposable.add(combineLatest(context.joined.state, context.requested.state).start(next: { joined, requested in
        updateState { current in
            var current = current
            current.requestedState = requested
            current.joinedState = joined
            return current
        }
    }))
    
    let dataSignal = combineLatest(queue: prepareQueue, statePromise.get(), accountContext.account.postbox.transaction { $0.getPeer(invitation.adminId) }) |> deliverOnPrepareQueue |> map { state, admin in
        return entries(state, admin: admin, invitation: invitation, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    

    
    let controller = InputDataController(dataSignal: dataSignal, title: invitation.title ?? strings().exportedInvitationTitle)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        getModalController?()?.close()
    })
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = appAppearance.locale
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short


    let getSubtitle:()->String? = {
        var subtitle: String? = nil
        if invitation.isRevoked {
            subtitle = strings().exportedInvitationStatusRevoked
        } else {
            if let expireDate = invitation.expireDate {
                if expireDate > Int32(Date().timeIntervalSince1970) {
                    let left = Int(expireDate) - Int(Date().timeIntervalSince1970)
                    if left <= Int(Int32.secondsInDay) {
                        let minutes = left / 60 % 60
                        let seconds = left % 60
                        let hours = left / 60 / 60
                        let string = String(format: "%@:%@:%@", hours < 10 ? "0\(hours)" : "\(hours)", minutes < 10 ? "0\(minutes)" : "\(minutes)", seconds < 10 ? "0\(seconds)" : "\(seconds)")
                        subtitle = strings().inviteLinkStickerTimeLeft(string)
                    } else {
                        subtitle = strings().inviteLinkStickerTimeLeft(autoremoveLocalized(left))
                    }
                } else {
                    subtitle = strings().exportedInvitationStatusExpired
                }
            }
        }
        return subtitle
    }


   
    controller.centerModalHeader = ModalHeaderData(title: invitation.title ?? strings().exportedInvitationTitle, subtitle: getSubtitle())
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.updateDatas = { data in
       
        return .none
    }
    controller.onDeinit = {
        actionsDisposable.dispose()
        updateState { current in
            var current = current
            current.joinedState = nil
            current.requestedState = nil
            return current
        }
    }
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().exportedInvitationDone, accept: { [weak controller] in
          controller?.validateInputValues()
    }, drawBorder: true, singleButton: true)
    
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in
        f()
    }, size: NSMakeSize(340, 350))
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    controller.validateData = { data in
        return .success(.custom {
            getModalController?()?.close()
        })
    }
    let joined = context.joined
    let requested = context.requested
    
    controller.didLoaded = { [weak requested, weak joined] controller, _ in
        controller.tableView.setScrollHandler { [weak joined, weak requested] position in
            switch position.direction {
            case .bottom:
                let state = stateValue.with { $0 }
                if let requestedState = state.requestedState {
                    if requestedState.canLoadMore {
                        requested?.loadMore()
                        break
                    }
                }
                if let joinedState = state.joinedState {
                    if joinedState.canLoadMore {
                        joined?.loadMore()
                        break
                    }
                }
            default:
                break
            }
        }
    }

    let timer = SwiftSignalKit.Timer(timeout: 1, repeat: true, completion: { [weak modalController, weak controller] in
        if let modalController = modalController {
            controller?.centerModalHeader = ModalHeaderData(title: invitation.title ?? strings().exportedInvitationTitle, subtitle: getSubtitle())
            modalController.updateLocalizationAndTheme(theme: theme)
        }
    }, queue: .mainQueue())

    timer.start()

    controller.contextObject = timer
    
    return modalController
}
