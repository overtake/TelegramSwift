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
        self.nameLayout = .init(.initialize(string: name, color: theme.colors.accent, font: .medium(.title)))
        self.leftLayout = .init(.initialize(string: strings().sharedFolderTitleAllChats, color: theme.colors.listGrayText, font: .normal(.text)))
        self.rightLayout = .init(.initialize(string: strings().sharedFolderTitlePersonal, color: theme.colors.listGrayText, font: .normal(.text)))

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
    var membersCount: [EnginePeer.Id: Int] = [:]

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
    
    struct Tuple : Equatable {
        let peer: PeerEquatable
        let selected: Bool
        let viewType: GeneralViewType
        let selectable: Bool
        let enabled: Bool
        let status: String
    }
    
    var toJoin: [Tuple] = []
    var joined: [Tuple] = []
    
    let _to_list = state.peers.filter { !state.alreadyMemberPeerIds.contains($0.peer.id) }
    let _already_list = state.peers.filter { state.alreadyMemberPeerIds.contains($0.peer.id) }

    for (i, peer) in _to_list.enumerated() {
        let status: String
        if let count = state.membersCount[peer.peer.id] {
            status = strings().peerStatusMemberCountable(count)
        } else {
            if peer.peer.isChannel {
                status = strings().peerStatusChannel
            } else if peer.peer.isForum {
                status = strings().peerStatusForum
            } else {
                status = strings().peerStatusGroup
            }
        }
        toJoin.append(.init(peer: peer, selected: state.selected.contains(peer.peer.id), viewType: bestGeneralViewType(_to_list, for: i), selectable: true, enabled: true, status: status))
    }
    for (i, peer) in _already_list.enumerated() {
        let status: String
        if let count = state.membersCount[peer.peer.id] {
            status = strings().peerStatusMemberCountable(count)
        } else {
            if peer.peer.isChannel {
                status = strings().peerStatusChannel
            } else if peer.peer.isForum {
                status = strings().peerStatusForum
            } else {
                status = strings().peerStatusGroup
            }
        }
        joined.append(.init(peer: peer, selected: true, viewType: bestGeneralViewType(_already_list, for: i), selectable: true, enabled: false, status: status))
    }
    
    
    let header: String
    switch arguments.content {
    case let .join(_, content):
        if state.isAlreadyInFolder {
            header = strings().sharedFolderStatusFullyAdded
        } else {
            if content.localFilterId != nil {
                let count = state.selected.count - joined.count
                header = strings().sharedFolderStatusAddChatsCountable(count, state.title)
            } else {
                header = strings().sharedFolderStatusAddNew
            }
        }
    case .joinChats:
        let count = state.selected.count - joined.count
        header = strings().sharedFolderStatusAddChatsCountable(count, state.title)
    case .remove:
        header = strings().sharedFolderStatusRemove(state.title)
    case .sharedLinks:
        header = strings().sharedFolderStatusLinks
    }
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(header, linkHandler: { _ in }), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .singleItem, fontSize: 13, centerViewAlignment: true, alignment: .center)))
    index += 1
    
   
    
    
    
    if !toJoin.isEmpty {
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1

        let info: String
        switch arguments.content {
        case .join:
            info = strings().sharedFolderListHeaderChatsToJoinCountable(toJoin.count) 
        case .joinChats:
            info = strings().sharedFolderListHeaderUpdatesCountable(toJoin.count)
        case .remove:
            info = strings().sharedFolderListHeaderQuitCountable(toJoin.count)
        case .sharedLinks:
            info = strings().sharedFolderListHeaderInviteLinks
        }
        
        let allSelected = toJoin.filter {
            $0.selected
        }.count == toJoin.count
        
        var rightItem = InputDataGeneralTextRightData(isLoading: false, text: nil)
        
        if toJoin.count > 1 {
            rightItem = .init(isLoading: false, text: .initialize(string: allSelected ? strings().sharedFolderDeselectAll : strings().sharedFolderSelectAll, color: theme.colors.accent, font: .normal(.short)), action: {
                for join in toJoin {
                    if allSelected {
                        if join.selected {
                            arguments.select.toggleSelection(join.peer.peer)
                        }
                    } else {
                        if !join.selected {
                           arguments.select.toggleSelection(join.peer.peer)
                       }
                    }
                }
                arguments.merge()
            }, update: arc4random())
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(info), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, rightItem: rightItem)))
        index += 1
        
        for item in toJoin {
            
            let interactionType: ShortPeerItemInteractionType
            if item.selectable {
                interactionType = .selectable(arguments.select, side: .left)
            } else {
                interactionType = .plain
            }
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, enabled: item.enabled, status: item.status, inset: NSEdgeInsets(left: 20, right: 20), interactionType: interactionType, viewType: item.viewType)
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

       
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain( strings().sharedFolderListHeaderAlreadyCountable(joined.count)), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        for item in joined {
            
            let interactionType: ShortPeerItemInteractionType
            if item.selectable {
                interactionType = .selectable(arguments.select, side: .left)
            } else {
                interactionType = .plain
            }
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, enabled: item.enabled, status: item.status, inset: NSEdgeInsets(left: 20, right: 20), interactionType: interactionType, viewType: item.viewType, disabledAction: {
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
        
        let text: String = strings().sharedFolderCreateLink
        
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
            info = strings().chatListFilterInviteLinkDescCountable(item.link.peerIds.count)

            
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
    case joinChats(updates: ChatFolderUpdates,content: ChatFolderLinkContents, filter: ChatListFilter)
    case remove(filter: ChatListFilter, peers: [Peer], default: [PeerId])
    case sharedLinks(filter: ChatListFilter, links:[ExportedChatFolderLink])
    var peers: [Peer] {
        switch self {
        case let .join(_, content), let .joinChats(_, content, _):
            return content.peers.map { $0._asPeer() }
        case let .remove(_, peers, _):
            return peers
        case .sharedLinks:
            return []
        }
    }
    var title: String {
        switch self {
        case let .join(_, content), let .joinChats(_, content, _):
            return content.title ?? ""
        case let .remove(filter, _, _):
            return filter.title
        case let .sharedLinks(filter, _):
            return filter.title
        }
    }
    var alreadyMemberPeerIds: Set<PeerId> {
        switch self {
        case let .join(_, content):
            return content.alreadyMemberPeerIds
        case let .joinChats(_, content, _):
            return Set(content.peers.filter { peer in
                if let peer = peer._asPeer() as? TelegramChannel {
                    return peer.participationStatus == .member
                } else {
                    return false
                }
            }.map { $0.id })
        case .remove, .sharedLinks:
            return []
        }
    }
    var localFilterId: Int32? {
        switch self {
        case let .join(_, content), let .joinChats(_, content, _):
            return content.localFilterId
        case let .remove(filter, _, _), let .sharedLinks(filter, _):
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
    switch content {
    case let .remove(_, _, `default`):
        for peer in peers {
            if `default`.contains(peer.peer.id) {
                selected.toggleSelection(peer.peer)
            }
        }
    default:
        for peer in peers {
            selected.toggleSelection(peer.peer)
        }
    }
    
    let participantCount = context.engine.data.get(EngineDataMap(peers.map { $0.peer.id }.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init(id:))))

    
    updateState { current in
        var current = current
        current.selected = selected.presentation.selected
        return current
    }
    
    actionsDisposable.add(participantCount.start(next: { participantCount in
        var memberCounts: [EnginePeer.Id: Int] = [:]
        for (id, count) in participantCount {
            if let count = count {
                memberCounts[id] = count
            }
        }
        updateState { current in
            var current = current
            current.membersCount = memberCounts
            return current
        }
    }))
    
    
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
            text = strings().sharedFolderAlertAlreadyMemberChannel
        } else {
            text = strings().sharedFolderAlertAlreadyMemberGroup
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
                    
                    let folderLimits = shareFolderPremiumLimits(context: context, current: filter, links: stateValue.with { $0.inviteLinks })
                                        
                    let canCreateLink: Signal<Bool, NoError> = context.account.postbox.transaction { transaction -> Bool in
                        var peers:[Peer] = []
                                                
                        for peerId in data.includePeers.peers {
                            if let peer = transaction.getPeer(peerId) {
                                peers.append(peer)
                            }
                        }
                        return !peers.filter { peerCanBeSharedInFolder($0) }.isEmpty
                    } |> deliverOnMainQueue
                    
                    _ = combineLatest(folderLimits, canCreateLink).start(next: { limits, canCreateLink in
                        if canCreateLink {
                            if limits.limitInvites || limits.limitFilters {
                                if limits.limitFilters {
                                    showPremiumLimit(context: context, type: .sharedFolders)
                                } else if limits.limitInvites {
                                    showPremiumLimit(context: context, type: .sharedInvites)
                                }
                                updateState { current in
                                    var current = current
                                    current.creatingLink = false
                                    return current
                                }
                                return
                            }
                            
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
                                case .sharedFolderLimitExceeded:
                                    showPremiumLimit(context: context, type: .sharedFolders)
                                case .tooManyChannels:
                                    showInactiveChannels(context: context, source: .join)
                                case .tooManyChannelsInAccount:
                                    showPremiumLimit(context: context, type: .channels)
                                case .someUserTooManyChannels:
                                    alert(for: context.window, info: strings().sharedFolderErrorSomeUserTooMany)
                                case .generic:
                                    alert(for: context.window, info: strings().unknownError)
                                }
                                
                                updateState { current in
                                    var current = current
                                    current.creatingLink = false
                                    return current
                                }
                            }))
                            
                        } else {
                            showModal(with: ShareCloudFolderController(context: context, filter: filter, link: nil, updated: updateLink), for: context.window)
                        }
                    })
                    
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
            verifyAlert_button(for: context.window, information: strings().chatListFilterInviteLinkDeleteConfirm, ok: strings().chatListFilterInviteLinkDelete, successHandler: { _ in
                
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
        modalInteractions = ModalInteractions(acceptTitle: strings().modalOK, accept: { [weak controller] in
            _ = controller?.returnKeyAction()
        }, singleButton: true)
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
                case .tooManyChannelsInAccount:
                    showPremiumLimit(context: context, type: .channels)
                case .generic:
                    alert(for: context.window, info: strings().unknownError)
                }
            }
            
            switch content {
            case let .join(slug, _):
                if !state.isAlreadyInFolder, !state.selected.isEmpty {
                    _ = showModalProgress(signal: context.engine.peers.joinChatFolderLink(slug: slug, peerIds: Array(state.selected)), for: context.window).start(next: { result in
                        var title: String? = nil
                        let text: String
                        if result.newChatCount != 0 {
                            title = strings().sharedFolderTooltipAddedTitle(result.title)
                            text = strings().sharedFolderTooltipAddedTextCountable(result.newChatCount)
                        } else {
                            text = strings().sharedFolderTooltipAddedTitle(result.title)
                        }
                        close?()
                        showModalText(for: context.window, text: text, title: title)
                        navigateToChatListFilter(result.folderId, context: context)
                        
                    }, error: processError)
                } else {
                    close?()
                }
            case let .joinChats(updates, _, filter):
                if state.hasSelectedToJoin {
                    let joinSignal = context.engine.peers.joinAvailableChatsInFolder(updates: updates, peerIds: Array(stateValue.with { $0.selected }))
                    _ = showModalProgress(signal: joinSignal, for: context.window).start(error: processError, completed: {
                        close?()
                        if stateValue.with({ $0.selected.count }) > 0 {
                            showModalText(for: context.window, text: strings().sharedFolderTooltipUpdatedTextCountable(stateValue.with { $0.selected.count }), title: strings().sharedFolderTooltipUpdatedTitle(filter.title))
                        }
                    })
                } else {
                    _ = context.engine.peers.hideChatFolderUpdates(folderId: filter.id).start()
                    close?()
                }
            case let .remove(filter, _, _):
                let invoke:()->Void = {
                    _ = context.engine.peers.leaveChatFolder(folderId: filter.id, removePeerIds: stateValue.with { Array($0.selected) }).start()
                    close?()
                }
                
                if filter.data?.hasSharedLinks == true {
                    verifyAlert_button(for: context.window, header: strings().sharedFolderConfirmDelete, information: strings().sharedFolderConfirmDeleteText, successHandler: { _ in
                        invoke()
                    })
                } else {
                    invoke()
                }
            case .sharedLinks:
                break
            }
        }))
    }
    
    controller.afterTransaction = { [weak modalInteractions, weak modalController] controller in
        modalInteractions?.updateDone { title in
            let state = stateValue.with { $0 }
            var enabled: Bool = true
            let string: String
            switch content {
            case .join:
                if state.hasSelectedToJoin {
                    if content.localFilterId == nil {
                        string = strings().sharedFolderDoneAddFolder
                    } else {
                        string = strings().sharedFolderDoneJoinChats
                    }
                } else if state.localFolderId == nil {
                    string = strings().sharedFolderDoneAddFolder
                } else {
                    string = strings().modalOK
                }
                if state.selected.isEmpty {
                    enabled = false
                }
            case .joinChats:
                if state.hasSelectedToJoin {
                    string = strings().sharedFolderDoneJoinChats
                } else {
                    string = strings().sharedFolderDoneDonNotJoinChats
                }
            case .remove:
                if state.selected.isEmpty {
                    string = strings().sharedFolderDoneRemoveFolder
                } else {
                    string = strings().sharedFolderDoneRemoveFolderAndChats
                }
            case .sharedLinks:
                string = ""
            }
            title.isEnabled = enabled
            title.set(text: string, for: .Normal)
        }
        let title: String
        switch content {
        case .join:
            title = strings().sharedFolderTitleAddFolder
        case .joinChats:
            title = strings().sharedFolderTitleAddChatsCountable(stateValue.with { $0.selected.count })
        case .remove:
            title = strings().sharedFolderTitleRemoveFolder
        case .sharedLinks:
            title = strings().sharedFolderTitleShareFolder
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
        switch error {
        case .generic:
            alert(for: context.window, info: strings().chatMessageFolderExpired)
        }
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
    
    let includePeers: Signal<[Peer], NoError> = context.engine.data.get(
        EngineDataList(filter.data!.includePeers.peers.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))) |> map {
            $0.compactMap { $0?._asPeer() }.filter { $0.isChannel || $0.isSupergroup || $0.isGroup }
        }
    
    let defaultPeers:Signal<[PeerId], NoError> = context.engine.peers.requestLeaveChatFolderSuggestions(folderId: filter.id)
    
    _ = showModalProgress(signal: combineLatest(includePeers, defaultPeers), for: context.window).start(next: { includePeers, defaultPeers in
        
        let invoke:()->Void = {
            _ = context.engine.peers.leaveChatFolder(folderId: filter.id, removePeerIds: []).start()
        }
        if defaultPeers.isEmpty {
            if filter.data?.hasSharedLinks == true {
                verifyAlert_button(for: context.window, header: strings().sharedFolderConfirmDelete, information: strings().sharedFolderConfirmDeleteText, successHandler: { _ in
                    invoke()
                })
            } else {
                verifyAlert_button(for: context.window, header: strings().chatListFilterConfirmRemoveHeader, information: strings().chatListFilterConfirmRemoveText, ok: strings().chatListFilterConfirmRemoveOK, successHandler: { _ in
                    invoke()
                })
            }
        } else {
            showModal(with: SharedFolderClosureController(context: context, content: .remove(filter: filter, peers: includePeers, default: defaultPeers)), for: context.window)
        }
    })
    
}
