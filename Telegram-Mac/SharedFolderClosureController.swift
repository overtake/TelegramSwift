//
//  JoinCloudFolderController.swift
//  Telegram
//
//  Created by Mike Renoir on 16.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore

private final class JoinCloudFolderHeaderItem : GeneralRowItem {
    let nameLayout: TextViewLayout
    let leftLayout: TextViewLayout
    let rightLayout: TextViewLayout
    
    let badgeNode: BadgeNode?
    init(initialSize: NSSize, stableId: AnyHashable, name: String, count: String?) {
        
        if let count = count {
            self.badgeNode = .init(.initialize(string: count, color: theme.colors.underSelectedColor, font: .medium(.short)), theme.colors.accent)
        } else {
            self.badgeNode = nil
        }
        //TODOLANG
        self.nameLayout = .init(.initialize(string: name, color: theme.colors.accent, font: .medium(.title)))
        self.leftLayout = .init(.initialize(string: "All Chats", color: theme.colors.listGrayText, font: .normal(.text)))
        self.rightLayout = .init(.initialize(string: "Personal", color: theme.colors.listGrayText, font: .normal(.text)))

        super.init(initialSize, stableId: stableId)
        
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        nameLayout.measure(width: initialSize.width / 2.5)
        leftLayout.measure(width: .greatestFiniteMagnitude)
        rightLayout.measure(width: .greatestFiniteMagnitude)

        return true
    }
    
    override var height: CGFloat {
        return 36
    }
    
    override func viewClass() -> AnyClass {
        return JoinCloudFolderHeaderView.self
    }
}

private final class JoinCloudFolderHeaderView : TableRowView {
    private let nameView = TextView()
    private let leftView = TextView()
    private let rightView = TextView()
    
    private let leftShadow = ShadowView()
    private let rightShadow = ShadowView()

    private let nameContainer = View()
    
    private let lineView = View()
    
    private var badgeView: View?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        leftView.userInteractionEnabled = false
        rightView.userInteractionEnabled = false
        nameView.userInteractionEnabled = false

        leftView.isSelectable = false
        rightView.isSelectable = false
        nameView.isSelectable = false

        
        addSubview(leftView)
        addSubview(rightView)

        addSubview(leftShadow)
        addSubview(rightShadow)
        
        nameContainer.addSubview(nameView)
        nameContainer.addSubview(lineView)
        addSubview(nameContainer)
        
        nameContainer.layer?.masksToBounds = false
        
        lineView.layer?.cornerRadius = 3
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? JoinCloudFolderHeaderItem else {
            return
        }
        var nameSize: CGFloat = nameView.frame.width
        if let badge = item.badgeNode {
            nameSize = nameSize + 5 + badge.size.width
        }
        transition.updateFrame(view: nameContainer, frame: focus(NSMakeSize(nameSize, frame.height)))
        
        transition.updateFrame(view: nameView, frame: nameView.centerFrameY())
        
        if let view = self.badgeView {
            transition.updateFrame(view: view, frame: view.centerFrameY(x: nameView.frame.width + 5))
        }
        transition.updateFrame(view: lineView, frame: NSMakeRect(0, nameContainer.frame.height - 3, nameContainer.frame.width, 6))
        
        transition.updateFrame(view: rightView, frame: rightView.centerFrameY(x: nameContainer.frame.maxX + 20))
        transition.updateFrame(view: leftView, frame: leftView.centerFrameY(x: nameContainer.frame.minX - leftView.frame.width - 20))
        
        transition.updateFrame(view: leftShadow, frame: leftView.frame)
        transition.updateFrame(view: rightShadow, frame: rightView.frame)
        
    }
    
 
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? JoinCloudFolderHeaderItem else {
            return
        }
        
        rightView.update(item.rightLayout)
        leftView.update(item.leftLayout)
        nameView.update(item.nameLayout)
        
        if let badge = item.badgeNode {
            let current: View
            if let view = self.badgeView {
                current = view
            } else {
                current = View(frame: CGRect(origin: CGPoint.init(x: nameView.frame.maxX + 5, y: floorToScreenPixels(backingScaleFactor, (frame.height - badge.size.height) / 2)), size: badge.size))
                self.badgeView = current
                nameContainer.addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.setFrameSize(badge.size)
            badge.view = current
            badge.setNeedDisplay()
        } else if let view = self.badgeView {
            performSubviewRemoval(view, animated: animated, scale: true)
            self.badgeView = nil
        }
        
        rightShadow.direction = .horizontal(true)
        leftShadow.direction = .horizontal(false)
        
        leftShadow.shadowBackground = theme.colors.listBackground
        rightShadow.shadowBackground = theme.colors.listBackground

        lineView.backgroundColor = theme.colors.accent

    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class Arguments {
    let context: AccountContext
    let select: SelectPeerInteraction
    let alreadyError:(Peer)->Void
    let content: JoinCloudFolderMode
    let merge:()->Void
    let shareFolder:(ExportedChatFolderLink?)->Void
    let copy:(String)->Void
    let deleteLink:(ExportedChatFolderLink)->Void
    init(context: AccountContext, content: JoinCloudFolderMode, select: SelectPeerInteraction, alreadyError: @escaping(Peer)->Void, merge:@escaping()->Void, shareFolder:@escaping(ExportedChatFolderLink?)->Void, copy: @escaping(String)->Void, deleteLink:@escaping(ExportedChatFolderLink)->Void) {
        self.context = context
        self.content = content
        self.select = select
        self.alreadyError = alreadyError
        self.shareFolder = shareFolder
        self.copy = copy
        self.deleteLink = deleteLink
        self.merge = merge
    }
}

private struct State : Equatable {
    var title: String
    var peers: [PeerEquatable] = []
    var selected: Set<PeerId> = Set()
    var alreadyMemberPeerIds: Set<EnginePeer.Id>
    var localFolderId: Int32?
    var inviteLinks:[ExportedChatFolderLink]?
    var linkSaving: String? = nil
    var creatingLink: Bool = false
    var hasSelectedToJoin: Bool {
        let to_join = peers
            .filter { !alreadyMemberPeerIds.contains($0.peer.id) }
            .filter { selected.contains($0.peer.id) }
        
        return !to_join.isEmpty
    }
    var isAlreadyInFolder: Bool {
        return !hasSelectedToJoin && localFolderId != nil
    }
}

private let _id_header = InputDataIdentifier("_id_header")
private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}
private let _id_share_invite = InputDataIdentifier("_id_share_invite")
private func _id_invite_link(_ string: String) -> InputDataIdentifier {
    return InputDataIdentifier("_id_invite_link\(string)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    //header
    
    let selectedCount: String?
    switch arguments.content {
    case .join:
        selectedCount = state.selected.count > 0 ? "\(state.selected.count)" : nil
    case .joinChats:
        selectedCount = state.selected.count > 0 ? "+\(state.selected.count)" : nil
    case .remove:
        selectedCount = nil
    case .sharedLinks:
        selectedCount = nil
    }
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return JoinCloudFolderHeaderItem(initialSize: initialSize, stableId: stableId, name: state.title, count: selectedCount)
    }))
    index += 1
    
    
    let header: String
    switch arguments.content {
    case .join:
        if state.isAlreadyInFolder {
            header = "You have already added this folder and its chats."
        } else {
            header = "Do you want to add **\(state.selected.count)** chats to your folder **\(state.title)**?"
        }
    case .joinChats:
        header = "Do you want to add **\(state.selected.count)** chats to your folder **\(state.title)**?"
    case .remove:
        header = "Do you want to quit the chats you joined when adding the folder \(state.title)?"
    case .sharedLinks:
        header = "Create more links to set up different access levels for different people."
    }
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(header, linkHandler: { _ in }), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .singleItem, fontSize: 13, centerViewAlignment: true, alignment: .center)))
    index += 1
    
   
    
    struct Tuple : Equatable {
        let peer: PeerEquatable
        let selected: Bool
        let viewType: GeneralViewType
        let selectable: Bool
        let enabled: Bool
    }
    
    var toJoin: [Tuple] = []
    var joined: [Tuple] = []
    
    let _to_list = state.peers.filter { !state.alreadyMemberPeerIds.contains($0.peer.id) }
    let _already_list = state.peers.filter { state.alreadyMemberPeerIds.contains($0.peer.id) }

    for (i, peer) in _to_list.enumerated() {
        toJoin.append(.init(peer: peer, selected: state.selected.contains(peer.peer.id), viewType: bestGeneralViewType(_to_list, for: i), selectable: true, enabled: true))
    }
    for (i, peer) in _already_list.enumerated() {
        joined.append(.init(peer: peer, selected: true, viewType: bestGeneralViewType(_already_list, for: i), selectable: true, enabled: false))
    }
    
    
    if !toJoin.isEmpty {
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1

        let info: String
        switch arguments.content {
        case .join:
            info = "\(toJoin.count) CHATS TO JOIN"
        case .joinChats:
            info = "\(toJoin.count) CHATS IN FOLDER TO JOIN"
        case .remove:
            info = "\(toJoin.count) CHATS TO QUIT"
        case .sharedLinks:
            info = "INVITE LINKS"
        }
        
        let allSelected = toJoin.filter {
            $0.selected
        }.count == toJoin.count
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(info), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, rightItem: .init(isLoading: false, text: .initialize(string: allSelected ? "DESELECT ALL" : "SELECT ALL", color: theme.colors.accent, font: .normal(.short)), action: {
            for join in toJoin {
                if join.selected, allSelected {
                    arguments.select.toggleSelection(join.peer.peer)
                } else if !allSelected, !join.selected {
                    arguments.select.toggleSelection(join.peer.peer)
                }
            }
            arguments.merge()
        }, update: arc4random()))))
        index += 1
        
        for item in toJoin {
            
            let interactionType: ShortPeerItemInteractionType
            if item.selectable {
                interactionType = .selectable(arguments.select, side: .left)
            } else {
                interactionType = .plain
            }
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, enabled: item.enabled, status: item.peer.peer.isChannel ? strings().peerStatusChannel : strings().peerStatusGroup, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, viewType: item.viewType)
            }))
            index += 1
        }
    }
    
    
    if !joined.isEmpty {
        if toJoin.isEmpty {
            entries.append(.sectionId(sectionId, type: .customModern(10)))
        } else {
            entries.append(.sectionId(sectionId, type: .normal))
        }
        sectionId += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("\(joined.count) CHATS ALREADY JOINED"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for item in joined {
            
            let interactionType: ShortPeerItemInteractionType
            if item.selectable {
                interactionType = .selectable(arguments.select, side: .left)
            } else {
                interactionType = .plain
            }
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, enabled: item.enabled, status: item.peer.peer.isChannel ? strings().peerStatusChannel : strings().peerStatusGroup, inset: NSEdgeInsets(left: 30, right: 30), interactionType: interactionType, viewType: item.viewType, disabledAction: {
                    arguments.alreadyError(item.peer.peer)
                })
            }))
            index += 1
        }
    }
    if let links = state.inviteLinks {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterInviteLinkHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        
        let viewType: GeneralViewType
        
        if let invite = state.inviteLinks, !invite.isEmpty {
            viewType = .firstItem
        } else if state.inviteLinks == nil {
            viewType = .firstItem
        } else {
            viewType = .singleItem
        }
        
        let text: String = "Create Share Link"
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_share_invite, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, nameStyle: blueActionButton, type: state.creatingLink ? .loading : .none, viewType: viewType, action: {
                arguments.shareFolder(nil)
            }, thumb: GeneralThumbAdditional(thumb: theme.icons.group_invite_via_link, textInset: 52, thumbInset: 4))
        }))
        index += 0
        
        struct Tuple : Equatable {
            let link:ExportedChatFolderLink
            let viewType: GeneralViewType
            let saving: Bool
        }
        var items: [Tuple] = []
        for (i, link) in links.enumerated() {
            items.append(.init(link: link, viewType: bestGeneralViewTypeAfterFirst(links, for: i), saving: state.linkSaving == link.link))
        }
        
        for item in items {
            
            let info: String
            if item.link.isRevoked {
                info = strings().chatListFilterInviteLinkRevoked
            } else {
                info = strings().chatListFilterInviteLinkDescCountable(item.link.peerIds.count)
            }
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_invite_link(item.link.slug), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, name: item.link.title.isEmpty ? item.link.link : item.link.title, description: info, type: item.saving ? .loading : .none, viewType: item.viewType, action: {
                    arguments.shareFolder(item.link)
                }, thumb: GeneralThumbAdditional(thumb: item.link.isRevoked ? theme.icons.folder_invite_link_revoked : theme.icons.folder_invite_link, textInset: 52, thumbInset: 4), menuItems: {
                    var items: [ContextMenuItem] = []
                    
                    items.append(ContextMenuItem(strings().contextCopy, handler: {
                        arguments.copy(item.link.link)
                    }, itemImage: MenuAnimation.menu_copy.value))
                                 
                    items.append(ContextSeparatorItem())
                    
                    items.append(ContextMenuItem(strings().chatListFilterInviteLinkDelete, handler: {
                        arguments.deleteLink(item.link)
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))

                    
                    return items
                })
            }))
            index += 0
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().chatListFilterInviteLinkInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1

    }

   
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum JoinCloudFolderMode {
    case join(slug: String, content: ChatFolderLinkContents)
    case joinChats(updates: ChatFolderUpdates,content: ChatFolderLinkContents)
    case remove(filter: ChatListFilter, peers: [Peer])
    case sharedLinks(filter: ChatListFilter, links:[ExportedChatFolderLink])
    var peers: [Peer] {
        switch self {
        case let .join(_, content), let .joinChats(_, content):
            return content.peers.map { $0._asPeer() }
        case let .remove(_, peers):
            return peers
        case .sharedLinks:
            return []
        }
    }
    var title: String {
        switch self {
        case let .join(_, content), let .joinChats(_, content):
            return content.title ?? ""
        case let .remove(filter, _):
            return filter.title
        case let .sharedLinks(filter, _):
            return filter.title
        }
    }
    var alreadyMemberPeerIds: Set<PeerId> {
        switch self {
        case let .join(_, content), let .joinChats(_, content):
            return content.alreadyMemberPeerIds
        case .remove, .sharedLinks:
            return []
        }
    }
    var localFilterId: Int32? {
        switch self {
        case let .join(_, content), let .joinChats(_, content):
            return content.localFilterId
        case let .remove(filter, _), let .sharedLinks(filter, _):
            return filter.id
        }
    }
    var inviteLinks: [ExportedChatFolderLink]? {
        switch self {
        case let  .sharedLinks(_, links):
            return links
        default:
            return nil
        }
    }
}

func SharedFolderClosureController(context: AccountContext, content: JoinCloudFolderMode) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let peers: [PeerEquatable] = content.peers.compactMap { .init($0) }

    let initialState = State(title: content.title, peers: peers, selected: Set(peers.map { $0.peer.id }), alreadyMemberPeerIds: content.alreadyMemberPeerIds, localFolderId: content.localFilterId, inviteLinks: content.inviteLinks)
    
    var close:(()->Void)? = nil
    var getController:(()->InputDataController?)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    

    let selected = SelectPeerInteraction()
    
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
    
    for peer in peers {
        selected.toggleSelection(peer.peer)
    }
    
    let updateLink:(ExportedChatFolderLink, ExportedChatFolderLink?)->Void = { link, updated in
        updateState { current in
            var current = current
            current.creatingLink = false
            if let index = current.inviteLinks?.firstIndex(where: { $0.link == link.link }) {
                current.inviteLinks?.remove(at: index)
                if let updated = updated {
                    current.inviteLinks?.insert(updated, at: index)
                }
            }
            return current
        }
    }

    let arguments = Arguments(context: context, content: content, select: selected, alreadyError: { peer in
        let text: String
        if peer.isChannel {
            text = "You are already a member of this group."
        } else {
            text = "You are already a member of this channel."
        }
        showModalText(for: context.window, text: text)
    }, merge: {
        updateState { current in
            var current = current
            current.selected = selected.presentation.selected
            return current
        }
    }, shareFolder: { link in
        switch content {
        case let .sharedLinks(filter, _):
            if let data = filter.data {
                if let link = link {
                    showModal(with: ShareCloudFolderController(context: context, filter: filter, link: link, updated: updateLink), for: context.window)
                } else {
                    let makeUrl = context.engine.peers.exportChatFolder(filterId: filter.id, title: "", peerIds: data.includePeers.peers) |> deliverOnMainQueue
                    actionsDisposable.add(makeUrl.start(next: { link in
                        updateState { current in
                            var current = current
                            current.creatingLink = false
                            current.inviteLinks?.append(link)
                            return current
                        }
                        showModal(with: ShareCloudFolderController(context: context, filter: filter, link: link, updated: updateLink), for: context.window)
                    }, error: { error in
                        switch error {
                        case .limitExceeded:
                            showPremiumLimit(context: context, type: .sharedInvites)
                        default:
                            alert(for: context.window, info: strings().unknownError)
                        }
                        
                        updateState { current in
                            var current = current
                            current.creatingLink = false
                            return current
                        }
                    }))
                }
            }
        default:
            break
        }
    }, copy: { link in
        getController?()?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
        copyToClipboard(link)
    }, deleteLink: { link in
        if let filterId = content.localFilterId {
            confirm(for: context.window, information: strings().chatListFilterInviteLinkDeleteConfirm, okTitle: strings().chatListFilterInviteLinkDelete, successHandler: { _ in
                
                var index: Int? = nil
                updateState { current in
                    var current = current
                    index = current.inviteLinks?.firstIndex(of: link)
                    if let index = index {
                        current.inviteLinks?.remove(at: index)
                    }
                    return current
                }
                let signal = context.engine.peers.deleteChatFolderLink(filterId: filterId, link: link) |> deliverOnMainQueue
                
                actionsDisposable.add(signal.start(error: { error in
                    alert(for: context.window, info: strings().unknownError)
                    updateState { current in
                        var current = current
                        if let index = index {
                            current.inviteLinks?.insert(link, at: index)
                        }
                        return current
                    }
                }))
            })
        }
    })

    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    

    
    let controller = InputDataController(dataSignal: signal, title: "title")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    let modalInteractions: ModalInteractions?
    switch content {
    case .sharedLinks:
        modalInteractions = nil
    default:
        modalInteractions = ModalInteractions(acceptTitle: "", accept: { [weak controller] in
            _ = controller?.returnKeyAction()
        }, drawBorder: true, height: 50, singleButton: true)
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.validateData = { _ in
        return .fail(.doSomething(next: { _ in
            let state = stateValue.with { $0 }
            
            let processError: (JoinChatFolderLinkError)->Void = { error in
                switch error {
                case .dialogFilterLimitExceeded:
                    showPremiumLimit(context: context, type: .folders)
                case .sharedFolderLimitExceeded:
                    showPremiumLimit(context: context, type: .sharedFolders)
                case .tooManyChannels:
                    showInactiveChannels(context: context, source: .join)
                case .generic:
                    alert(for: context.window, info: strings().unknownError)
                }
            }
            
            switch content {
            case let .join(slug, _):
                if !state.isAlreadyInFolder {
                    _ = showModalProgress(signal: context.engine.peers.joinChatFolderLink(slug: slug, peerIds: Array(state.selected)), for: context.window).start(error: processError, completed: {
                        close?()
                        showModalText(for: context.window, text: "Added!")
                        
                    })
                } else {
                    close?()
                }
            case let .joinChats(updates, _):
                let joinSignal = context.engine.peers.joinAvailableChatsInFolder(updates: updates, peerIds: Array(stateValue.with { $0.selected }))
                _ = showModalProgress(signal: joinSignal, for: context.window).start(error: processError, completed: {
                    close?()
                    showModalText(for: context.window, text: "Joined!")
                })

            case let .remove(filter, _):
                _ = context.engine.peers.leaveChatFolder(folderId: filter.id, removePeerIds: stateValue.with { Array($0.selected) }).start()
                close?()
            case .sharedLinks:
                break
            }
        }))
    }
    
    controller.afterTransaction = { [weak modalInteractions, weak modalController] controller in
        modalInteractions?.updateDone { title in
            let state = stateValue.with { $0 }
            title.isEnabled = true
            let string: String
            switch content {
            case .join:
                if state.hasSelectedToJoin {
                    string = "Add Folder And Chats"
                } else if state.localFolderId == nil {
                    string = "Add Folder"
                } else {
                    string = "OK"
                }
            case .joinChats:
                if state.hasSelectedToJoin {
                    string = "Join Chats"
                } else {
                    string = "Do Not Join Any Chats"
                }
            case .remove:
                if state.selected.isEmpty {
                    string = "Remove Folder"
                } else {
                    string = "Remove Folder and Chats"
                }
            case .sharedLinks:
                string = ""
            }
            
            title.set(text: string, for: .Normal)
        }
        let title: String
        switch content {
        case .join:
            title = "Add Folder"
        case .joinChats:
            title = "Add \(stateValue.with { $0.selected.count }) chats"
        case .remove:
            title = "Remove Folder"
        case .sharedLinks:
            title = "Share Folder"
        }
        controller.centerModalHeader = .init(title: title)
        modalController?.updateLocalizationAndTheme(theme: theme)
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    getController = { [weak controller] in
        return controller
    }
    
    return modalController
}







func loadAndShowSharedFolder(context: AccountContext, slug: String) -> Void {
    _ = showModalProgress(signal: context.engine.peers.checkChatFolderLink(slug: slug), for: context.window).start(next: { content in
        showModal(with: SharedFolderClosureController(context: context, content: .join(slug: slug, content: content)), for: context.window)
    }, error: { error in
        alert(for: context.window, info: strings().unknownError)
    })
}

func shareSharedFolder(context: AccountContext, filter: ChatListFilter) -> Void {
    let signal = showModalProgress(signal: context.engine.peers.getExportedChatFolderLinks(id: filter.id), for: context.window)
    
    _ = signal.start(next: { links in
        if let links = links {
            showModal(with: SharedFolderClosureController(context: context, content: .sharedLinks(filter: filter, links: links)), for: context.window)
        }
    })
}

func deleteSharedFolder(context: AccountContext, filter: ChatListFilter) -> Void {
    let peers = showModalProgress(signal: context.engine.peers.requestLeaveChatFolderSuggestions(folderId: filter.id), for: context.window) |> mapToSignal { peerIds in
       return context.account.postbox.transaction { transaction in
            var peers: [Peer] = []
           for peerId in peerIds {
               if let peer = transaction.getPeer(peerId) {
                   peers.append(peer)
               }
           }
            return peers
        }
    } |> deliverOnMainQueue
    
    _ = peers.start(next: { peers in
        if peers.isEmpty {
            confirm(for: context.window, header: strings().chatListFilterConfirmRemoveHeader, information: strings().chatListFilterConfirmRemoveText, okTitle: strings().chatListFilterConfirmRemoveOK, successHandler: { _ in
                _ = context.engine.peers.leaveChatFolder(folderId: filter.id, removePeerIds: []).start()
            })
        } else {
            showModal(with: SharedFolderClosureController(context: context, content: .remove(filter: filter, peers: peers)), for: context.window)
        }
    })
    
}
