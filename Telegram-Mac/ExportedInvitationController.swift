//
//  ExportedInvitationController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TGUIKit

private final class ExportInvitationArguments {
    let context: PeerInvitationImportersContext
    let accountContext: AccountContext
    let copyLink: (String)->Void
    let shareLink: (String)->Void
    let openProfile:(PeerId)->Void
    init(context: PeerInvitationImportersContext, accountContext: AccountContext, copyLink: @escaping(String)->Void, shareLink: @escaping(String)->Void, openProfile:@escaping(PeerId)->Void) {
        self.context = context
        self.accountContext = accountContext
        self.copyLink = copyLink
        self.shareLink = shareLink
        self.openProfile = openProfile
    }
}

private struct ExportInvitationState : Equatable {
    
}

private let _id_link = InputDataIdentifier("_id_link")
private func _id_admin(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_admin_\(peerId.toInt64())")
}
private func _id_peer(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(peerId.toInt64())")
}
private func entries(_ state: PeerInvitationImportersState, admin: Peer?, invitation: ExportedInvitation, arguments: ExportInvitationArguments) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_link, equatable: InputDataEquatable(invitation), item: { initialSize, stableId in
        return ExportedInvitationRowItem(initialSize, stableId: stableId, context: arguments.accountContext, exportedLink: invitation, lastPeers: [], viewType: .singleItem, mode: .short, menuItems: {
            return .single([ContextMenuItem(L10n.exportedInvitationContextCopy, handler: {
                arguments.copyLink(invitation.link)
            })])
        }, share: arguments.shareLink, copyLink: arguments.copyLink)
    }))
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = appAppearance.locale
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    
    
    if let admin = admin {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.exportedInvitationLinkCreatedBy), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_admin(admin.id), equatable: InputDataEquatable(PeerEquatable(admin)), item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: admin, account: arguments.accountContext.account, stableId: stableId, height: 48, photoSize: NSMakeSize(36, 36), status: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(invitation.date))), inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: .singleItem, action: { [weak arguments] in
                arguments?.openProfile(admin.id)
            })
        }))
    }
    
    let importers = state.importers.filter { $0.peer.peer != nil }
  
    if !importers.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.exportedInvitationPeopleJoinedCountable(Int(state.count))), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for importer in state.importers {
            struct Tuple : Equatable {
                let importer: PeerInvitationImportersState.Importer
                let viewType: GeneralViewType
            }
            
            let tuple = Tuple(importer: importer, viewType: bestGeneralViewType(state.importers, for: importer))
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(importer.peer.peerId), equatable: InputDataEquatable(tuple), item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: tuple.importer.peer.peer!, account: arguments.accountContext.account, stableId: stableId, height: 48, photoSize: NSMakeSize(36, 36), status: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(importer.date))), inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: tuple.viewType, action: {
                    arguments.openProfile(tuple.importer.peer.peerId)
                }, contextMenuItems: {
                    let items = [ContextMenuItem(L10n.exportedInvitationContextOpenProfile, handler: {
                        arguments.openProfile(tuple.importer.peer.peerId)
                    })]
                    
                    return .single(items)
                })
            }))
        }
    }

    if state.count == 0, !invitation.isExpired, !invitation.isRevoked, let usageCount = invitation.usageLimit, invitation.count == nil {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_join_count"), equatable: nil, item: { initialSize, stableId in
            return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: L10n.inviteLinkEmptyJoinDescCountable(Int(usageCount)), font: .normal(.text))
        }))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ExportedInvitationController(invitation: ExportedInvitation, accountContext: AccountContext, context: PeerInvitationImportersContext) -> InputDataModalController {
    
    
    var getController:(()->InputDataController?)? = nil
    var getModalController:(()->InputDataModalController?)? = nil

    let arguments = ExportInvitationArguments(context: context, accountContext: accountContext, copyLink: { link in
        getController?()?.show(toaster: ControllerToaster(text: L10n.shareLinkCopied))
        copyToClipboard(link)
    }, shareLink: { link in
        showModal(with: ShareModalController(ShareLinkObject(accountContext, link: link)), for: accountContext.window)
    }, openProfile: { peerId in
        getModalController?()?.close()
        accountContext.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: accountContext, peerId: peerId))
    })
    
    let dataSignal = combineLatest(queue: prepareQueue, context.state, accountContext.account.postbox.transaction { $0.getPeer(invitation.adminId) }) |> deliverOnPrepareQueue |> map { state, admin in
        return entries(state, admin: admin, invitation: invitation, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    

    let controller = InputDataController(dataSignal: dataSignal, title: L10n.exportedInvitationTitle)
    
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
            subtitle = L10n.exportedInvitationStatusRevoked
        } else {
            if let expireDate = invitation.expireDate {
                if expireDate > Int32(Date().timeIntervalSince1970) {
                    let left = Int(expireDate) - Int(Date().timeIntervalSince1970)
                    if left <= Int(Int32.secondsInDay) {
                        let minutes = left / 60 % 60
                        let seconds = left % 60
                        let hours = left / 60 / 60
                        let string = String(format: "%@:%@:%@", hours < 10 ? "0\(hours)" : "\(hours)", minutes < 10 ? "0\(minutes)" : "\(minutes)", seconds < 10 ? "0\(seconds)" : "\(seconds)")
                        subtitle = L10n.inviteLinkStickerTimeLeft(string)
                    } else {
                        subtitle = L10n.inviteLinkStickerTimeLeft(autoremoveLocalized(left))
                    }
                } else {
                    subtitle = L10n.exportedInvitationStatusExpired
                }
            }
        }
        return subtitle
    }


   
    controller.centerModalHeader = ModalHeaderData(title: L10n.exportedInvitationTitle, subtitle: getSubtitle())
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.updateDatas = { data in
       
        return .none
    }
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.exportedInvitationDone, accept: { [weak controller] in
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
    
    controller.didLoaded = { [weak context] controller, _ in
        controller.tableView.setScrollHandler { [weak context] position in
            switch position.direction {
            case .bottom:
                context?.loadMore()
            default:
                break
            }
        }
    }

    let timer = SwiftSignalKit.Timer.init(timeout: 1, repeat: true, completion: { [weak modalController, weak controller] in
        if let modalController = modalController {
            controller?.centerModalHeader = ModalHeaderData(title: L10n.exportedInvitationTitle, subtitle: getSubtitle())
            modalController.updateLocalizationAndTheme(theme: theme)
        }
    }, queue: .mainQueue())

    timer.start()

    controller.contextOject = timer
    
    return modalController
}
