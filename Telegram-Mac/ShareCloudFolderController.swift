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
    let delete:()->Void
    let cantSelect:(Peer)->Void
    let nameLink: ()->Void
    init(context: AccountContext, select: SelectPeerInteraction, copy:@escaping(String)->Void, share:@escaping(String)->Void, delete: @escaping()->Void, cantSelect:@escaping(Peer)->Void, nameLink: @escaping()->Void) {
        self.context = context
        self.select = select
        self.copy = copy
        self.share = share
        self.delete = delete
        self.cantSelect = cantSelect
        self.nameLink = nameLink
    }
}

func peerCanBeSharedInFolder(_ peer: Peer, filter: ChatListFilter? = nil) -> Bool {
    if let filter = filter, let data = filter.data {
//        if !data.includePeers.peers.contains(peer.id) {
//            return false
//        }
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
                    
                    items.append(ContextMenuItem("Name Link", handler: {
                        arguments.nameLink()
                    }, itemImage: MenuAnimation.menu_edit.value))
                                 
                    items.append(ContextSeparatorItem())
                    
                    items.append(ContextMenuItem("Delete", handler: arguments.delete, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    
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

func ShareCloudFolderController(context: AccountContext, filter: ChatListFilter, link: ExportedChatFolderLink?, updated:@escaping(ExportedChatFolderLink, ExportedChatFolderLink?)->Void) -> InputDataModalController {

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
    
    var initialSelected: Set<PeerId> = Set()
    
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
            
            for peer in access {
                if let link = link {
                    if link.peerIds.contains(peer.peer.id) {
                        selected?.toggleSelection(peer.peer)
                    }
                } else {
                    selected?.toggleSelection(peer.peer)
                }
            }
            
            initialSelected = selected?.presentation.selected ?? []
            
            updateState { current in
                var current = current
                current.peers = peers
                current.selected = initialSelected
                return current
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
    }, delete: {
        if let link = stateValue.with ({ $0.link }) {
            confirm(for: context.window, information: strings().chatListFilterInviteLinkDeleteConfirm, okTitle: strings().chatListFilterInviteLinkDelete, successHandler: { _ in
                let signal = context.engine.peers.deleteChatFolderLink(filterId: filter.id, link: link)
                _ = showModalProgress(signal: signal, for: context.window).start()
                updated(link, nil)
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
    }, nameLink: {
        showModal(with: TextInputController(context: context, title: "Link Name", placeholder: "Link Name", initialText: stateValue.with { $0.link?.title ?? "" }, limit: 32, callback: { name in
            updateState { current in
                var current = current
                current.link?.title = name
                return current
            }
        }), for: context.window)
    })

    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: link?.title ?? filter.title)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: { [weak controller] in
        controller?.validateInputValues()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: link != nil ? modalInteractions : nil, closeHandler: { f in
        if let link = link {
            let state = stateValue.with { $0 }
            if (link != state.link) || (initialSelected != state.selected) {
                confirm(for: context.window, information: "You have changed the settings of this folder. Discard changes?", okTitle: "Discard", successHandler: { _ in
                    f()
                })
            } else {
                f()
            }
        } else {
            f()
        }
    })
       
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.validateData = { data in
        let state = stateValue.with { $0 }
        if let current = state.link {
            if state.selected.isEmpty {
                arguments.delete()
            } else {
                if state.selected != Set(current.peerIds) || link?.title != current.title {
                    _ = showModalProgress(signal: context.engine.peers.editChatFolderLink(filterId: state.filter.id, link: current, title: current.title, peerIds: Array(state.selected), revoke: false), for: context.window).start(next: { upd in
                        updated(current, upd)
                        showSuccess(window: context.window)
                    }, error: { error in
                        alert(for: context.window, info: strings().unknownError)
                    })
                }
                close?()
            }
        }
        return .none

    }
    
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    getController = { [weak controller] in
        return controller
    }
    
    
    controller.afterTransaction = { [weak modalInteractions, weak modalController] controller in
        modalInteractions?.updateDone { title in
            title.set(color: stateValue.with { $0.selected.isEmpty } ? theme.colors.redUI : theme.colors.accent, for: .Normal)
            title.set(text: stateValue.with { $0.selected.isEmpty } ? "Delete" : "Done", for: .Normal)
        }
        if let title = stateValue.with({ $0.link?.title }) {
            controller.centerModalHeader = .init(title: title)
            modalController?.updateLocalizationAndTheme(theme: theme)
        }
    }
    
        
    return modalController
}


/*
 
 */



