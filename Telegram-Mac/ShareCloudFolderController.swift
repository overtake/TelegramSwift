//
//  ShareCloudFolderController.swift
//  Telegram
//
//  Created by Mike Renoir on 17.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox



private final class Arguments {
    let context: AccountContext
    let select: SelectPeerInteraction
    let copy:(String)->Void
    let share:(String)->Void
    let revoke:()->Void
    let delete:()->Void
    let cantSelect:(Peer)->Void
    init(context: AccountContext, select: SelectPeerInteraction, copy:@escaping(String)->Void, share:@escaping(String)->Void, revoke:@escaping()->Void, delete: @escaping()->Void, cantSelect:@escaping(Peer)->Void) {
        self.context = context
        self.select = select
        self.copy = copy
        self.share = share
        self.revoke = revoke
        self.delete = delete
        self.cantSelect = cantSelect
    }
}

func peerCanBeSharedInFolder(_ peer: Peer, filter: ChatListFilter? = nil) -> Bool {
    if let filter = filter, let data = filter.data {
        if !data.includePeers.peers.contains(peer.id) {
            return false
        }
    }
    if peer.isChannel || peer.isSupergroup {
        return peer.addressName != nil || peer.groupAccess.canCreateInviteLink
    }
    return false
}

private struct State : Equatable {
    var filter: ChatListFilter
    var link: ExportedChatFolderLink?
    var peers: [PeerEquatable] = []
    var selected: Set<PeerId> = Set()
    
    var isEmpty: Bool {
        return peers.filter {
            peerCanBeSharedInFolder($0.peer, filter: filter)
        }.isEmpty
    }
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_link = InputDataIdentifier("_id_link")
private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let name: String = state.filter.title
    
    let titleText: String
    if !state.isEmpty {
        titleText = "Anyone with this link can add **\(name)** folder and the \(state.selected.count) chats selected below."
    } else {
        titleText = "There are no chats in this folder that you can share with others."
    }
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        let attr: NSMutableAttributedString = .init()
        attr.append(string: titleText, color: theme.colors.listGrayText, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.new_folder, text: attr, stickerSize: NSMakeSize(80, 80))
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    if let link = state.link {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("INVITE LINK"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_link, equatable: .init(link), comparable: nil, item: { initialSize, stableId in
            return ExportedInvitationRowItem(initialSize, stableId: stableId, context: arguments.context, exportedLink: _ExportedInvitation.initialize(.link(link: link.link, title: link.title, isPermanent: true, requestApproval: false, isRevoked: false, adminId: arguments.context.peerId, date: 0, startDate: 0, expireDate: nil, usageLimit: nil, count: nil, requestedCount: nil)), lastPeers: [], viewType: .singleItem, mode: .normal(hasUsage: false), menuItems: {

                var items:[ContextMenuItem] = []
                
                if let link = state.link {
                    items.append(ContextMenuItem(strings().contextCopy, handler: {
                        arguments.copy(link.link)
                    }, itemImage: MenuAnimation.menu_copy.value))
                                 
//                    items.append(ContextMenuItem("Name Link", handler: {
//                      //  arguments.copy(link.link)
//                    }, itemImage: MenuAnimation.menu_create_group.value))
                    
                    items.append(ContextSeparatorItem())
                    
                    if link.isRevoked {
                        items.append(ContextMenuItem("Restore", handler: arguments.revoke, itemMode: .normal, itemImage: MenuAnimation.menu_reset.value))
                    } else {
                        items.append(ContextMenuItem("Revoke", handler: arguments.revoke, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    }
                    
                }
                
                return .single(items)
            }, share: arguments.share, copyLink: arguments.copy)
        }))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }

    
    let headerText: String
    let infoText: String
    if state.isEmpty {
        headerText = "THESE CHATS CANNOT BE SHARED";
        infoText = "You can only share groups and channels in which you are allowed to create invite links."
    } else {
        headerText = "\(state.selected.count) CHATS SELECTED"
        infoText = "Select groups and channels that you want everyone who adds the folder via invite link to join."
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(headerText), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    struct Tuple : Equatable {
        let peer: PeerEquatable
        let selected: Bool
        let viewType: GeneralViewType
        let selectable: Bool
        let enabled: Bool
    }
    
    var items: [Tuple] = []
    
    for (i, peer) in state.peers.enumerated() {
        items.append(.init(peer: peer, selected: state.selected.contains(peer.peer.id), viewType: bestGeneralViewType(state.peers, for: i), selectable: true, enabled: peerCanBeSharedInFolder(peer.peer, filter: state.filter)))
    }
    
    for item in items {
        
        let interactionType: ShortPeerItemInteractionType
        if item.selectable {
            interactionType = .selectable(arguments.select, side: .left)
        } else {
            interactionType = .plain
        }
        
        let text: String
        if item.enabled {
            if item.peer.peer.isChannel {
                text = strings().peerStatusChannel
            } else if item.peer.peer.isForum {
                text = strings().peerStatusForum
            } else {
                text = strings().peerStatusGroup
            }
        } else {
            if let data = state.filter.data, !data.includePeers.peers.contains(item.peer.peer.id) {
                text = "This chat is no longer part of folder"
            } else if item.peer.peer.isBot {
                text = "you can't share bots"
            } else if item.peer.peer.isUser {
                text = "you can't share private chats"
            } else {
                text = "you can't invite others here"
            }
        }
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, enabled: item.enabled, status: text, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, viewType: item.viewType, disabledAction: {
                arguments.cantSelect(item.peer.peer)
            })
        }))
        index += 1
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(infoText), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
   
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func ShareCloudFolderController(context: AccountContext, filter: ChatListFilter, link: ExportedChatFolderLink?, updated:@escaping(ExportedChatFolderLink)->Void) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    var close:(()->Void)? = nil
    var getController:(()->InputDataController?)? = nil
    
    let initialState = State(filter: filter, link: link, peers: [], selected: [])
    let selected = SelectPeerInteraction()
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    
    
    if let data = filter.data {
        let peers = context.account.postbox.transaction { transaction in
            var peers:[PeerEquatable] = []
            
            let peerIds = ((link?.peerIds ?? []) + data.includePeers.peers).uniqueElements
            
            for peerId in peerIds {
                if let peer = transaction.getPeer(peerId) {
                    peers.append(.init(peer))
                }
            }
            return peers
        } |> deliverOnMainQueue
        actionsDisposable.add(peers.start(next: { [weak selected] peers in
            
            let access = peers.filter {
                peerCanBeSharedInFolder($0.peer, filter: filter)
            }
            let cantInvite = peers.filter {
                !peerCanBeSharedInFolder($0.peer, filter: filter)
            }
            
            let peers = access + cantInvite
            
            updateState { current in
                var current = current
                current.peers = peers
                current.selected = Set(access.map { $0.peer.id })
                return current
            }
            for peer in access {
                if let link = link {
                    if link.peerIds.contains(peer.peer.id) {
                        selected?.toggleSelection(peer.peer)
                    }
                } else {
                    selected?.toggleSelection(peer.peer)
                }
            }

        }))
    }
    

    
    selected.action = { peerId, _ in
        let peer = stateValue.with { $0.peers.first(where: { $0.peer.id == peerId }) }?.peer
        if let peer = peer {
            selected.update({
                $0.withToggledSelected(peerId, peer: peer)
            })
        }
        updateState { current in
            var current = current
            current.selected = selected.presentation.selected
            return current
        }
    }
    
    
    let arguments = Arguments(context: context, select: selected, copy: { link in
        getController?()?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
        copyToClipboard(link)
    }, share: { link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
    }, revoke: {
        if let link = stateValue.with ({ $0.link }) {
            _ = showModalProgress(signal: context.engine.peers.editChatFolderLink(filterId: filter.id, link: link, title: nil, peerIds: nil, revoke: !link.isRevoked), for: context.window).start(next: { link in
                updated(link)
                updateState { current in
                    var current = current
                    current.link = link
                    return current
                }
                showSuccess(window: context.window)
            })
        }
    }, delete: {
        if let link = stateValue.with ({ $0.link }) {
            confirm(for: context.window, information: "Are you sure you want to delete this link?", okTitle: "Revoke", successHandler: { _ in
                let signal = context.engine.peers.deleteChatFolderLink(filterId: filter.id, link: link)
                _ = showModalProgress(signal: signal, for: context.window).start()
                close?()
            })
        }
    }, cantSelect: { peer in
        let text: String
        if let data = filter.data, !data.includePeers.peers.contains(peer.id) {
            text = "This chat is no longer part of folder. Please add it to folder first.";
        } else if peer.isUser {
            text = "You can't share private chat.";
        } else if peer.isBot {
            text = "You can't share bot.";
        } else if peer.isChannel {
            text = "You don't have the admin rights to share invite links to this channel."
        } else {
            text = "You don't have the admin rights to share invite links to this group chat."
        }
        showModalText(for: context.window, text: text)
    })

    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Share Folder")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: { [weak controller] in
        controller?.validateInputValues()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: link != nil ? modalInteractions : nil)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.validateData = { data in
        let state = stateValue.with { $0 }
        if let link = state.link {
            if state.selected != Set(link.peerIds) {
                _ = showModalProgress(signal: context.engine.peers.editChatFolderLink(filterId: state.filter.id, link: link, title: link.title, peerIds: Array(state.selected), revoke: false), for: context.window).start(next: { link in
                    updated(link)
                    showSuccess(window: context.window)
                }, error: { error in
                    alert(for: context.window, info: strings().unknownError)
                })
            }
        }
        close?()
        return .none

    }
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    getController = { [weak controller] in
        return controller
    }
    
   // context.engine.peers.exportChatFolder(filterId: <#T##Int32#>, title: <#T##String#>, peerIds: <#T##[PeerId]#>)
    
    return modalController
}


/*
 
 */



