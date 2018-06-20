//
//  TGDialogRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


enum ChatListPinnedType {
    case some
    case last
    case none
    case ad
}


final class SelectChatListItemPresentation : Equatable {
    let selected:Set<ChatLocation>
    static func ==(lhs:SelectChatListItemPresentation, rhs:SelectChatListItemPresentation) -> Bool {
        return lhs.selected == rhs.selected
    }
    
    init(_ selected:Set<ChatLocation> = Set()) {
        self.selected = selected
    }
    
    func deselect(chatLocation:ChatLocation) -> SelectChatListItemPresentation {
        var chatLocations:Set<ChatLocation> = Set<ChatLocation>()
        chatLocations.formUnion(selected)
        let _ = chatLocations.remove(chatLocation)
        return SelectChatListItemPresentation(chatLocations)
    }
    
    func withToggledSelected(_ chatLocation: ChatLocation) -> SelectChatListItemPresentation {
        var chatLocations:Set<ChatLocation> = Set<ChatLocation>()
        chatLocations.formUnion(selected)
        if chatLocations.contains(chatLocation) {
            let _ = chatLocations.remove(chatLocation)
        } else {
            chatLocations.insert(chatLocation)
        }
        return SelectChatListItemPresentation(chatLocations)
    }
    
}

final class SelectChatListInteraction : InterfaceObserver {
    private(set) var presentation:SelectChatListItemPresentation = SelectChatListItemPresentation()
    
    func update(animated:Bool = true, _ f:(SelectChatListItemPresentation)->SelectChatListItemPresentation)->Void {
        let oldValue = self.presentation
        presentation = f(presentation)
        if oldValue != presentation {
            notifyObservers(value: presentation, oldValue:oldValue, animated:animated)
        }
    }
    
}

enum ChatListRowState : Equatable {
    case plain
    case deletable(onRemove:(ChatLocation)->Void, deletable:Bool)
    
    static func ==(lhs: ChatListRowState, rhs: ChatListRowState) -> Bool {
        switch lhs {
        case .plain:
            if case .plain = rhs {
                return true
            } else {
                return false
            }
        case .deletable(_, let deletable):
            if case .deletable(_, deletable) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}



class ChatListRowItem: TableRowItem {

    public private(set) var message:Message?
    
    let account:Account
    let peer:Peer?
    let renderedPeer:RenderedPeer
    let groupId: PeerGroupId?
    let groupUnreadCounters: GroupReferenceUnreadCounters?
    let peers:[Peer]
    var peerId:PeerId {
        return renderedPeer.peerId
    }
    
    let photo: AvatarNodeState
    
    var isGroup: Bool {
        return groupId != nil
    }
    
    private let requestSessionId:MetaDisposable = MetaDisposable()
    
    override var stableId: AnyHashable {
        return chatLocation
    }
    
    var chatLocation: ChatLocation {
        if let groupId = groupId {
            return ChatLocation.group(groupId)
        }
        return ChatLocation.peer(renderedPeer.peerId)
    }

    let mentionsCount: Int32?
    
    private var date:NSAttributedString?

    private var displayLayout:(TextNodeLayout, TextNode)?
    private var messageLayout:(TextNodeLayout, TextNode)?
    private var displaySelectedLayout:(TextNodeLayout, TextNode)?
    private var messageSelectedLayout:(TextNodeLayout, TextNode)?
    private var dateLayout:(TextNodeLayout, TextNode)?
    private var dateSelectedLayout:(TextNodeLayout, TextNode)?
    
    private var displayNode:TextNode = TextNode()
    private var messageNode:TextNode = TextNode()
    private var displaySelectedNode:TextNode = TextNode()
    private var messageSelectedNode:TextNode = TextNode()
    
    private let messageText:NSAttributedString?
    private let titleText:NSAttributedString?
    
    
    private(set) var peerNotificationSettings:PeerNotificationSettings?
    private(set) var readState:CombinedPeerReadState?
    
    private var badgeNode:BadgeNode? = nil
    private var badgeSelectedNode:BadgeNode? = nil
    
    private var typingLayout:(TextNodeLayout, TextNode)?
    private var typingSelectedLayout:(TextNodeLayout, TextNode)?
    
    private let clearHistoryDisposable = MetaDisposable()
    private let deleteChatDisposable = MetaDisposable()

    
    var isMuted:Bool {
        if pinnedType == .ad {
            return false
        }
        if let peerNotificationSettings = peerNotificationSettings as? TelegramPeerNotificationSettings {
            if case .muted(_) = peerNotificationSettings.muteState {
                return true
            }
        }
        if let groupUnreadCounters = groupUnreadCounters {
            if groupUnreadCounters.unreadCount > 0 {
                return false
            }
            return true
        }
        return false
    }
    
    let isVerified: Bool
    
    
    var isOutMessage:Bool {
        if let message = message {
            return !message.flags.contains(.Incoming) && message.id.peerId != account.peerId
        }
        return false
    }
    var isRead:Bool {
        if let peer = peer as? TelegramUser {
            if let _ = peer.botInfo {
                return true
            }
            if peer.id == account.peerId {
                return true
            }
        }
        if let peer = peer as? TelegramChannel {
            if case .broadcast = peer.info {
                return true
            }
        }
        
        if let readState = readState {
            if let message = message {
                return readState.isOutgoingMessageIndexRead(MessageIndex(message))
            }
        }
        
        return false
    }
    
    
    var isUnreadMarked: Bool {
        if let readState = readState {
            return readState.markedUnread
        }
        return false
    }
    
    var isSecret:Bool {
        return renderedPeer.peers[renderedPeer.peerId] is TelegramSecretChat
    }
    
    var isSending:Bool {
        if let message = message {
            return message.flags.contains(.Unsent)
        }
        return false
    }
    
    var isFailed: Bool {
        if let message = message {
            return message.flags.contains(.Failed)
        }
        return false
    }
    
    var isSavedMessage: Bool {
        return peer?.id == account.peerId
    }
    
    let hasDraft:Bool
    
    let pinnedType:ChatListPinnedType
    let state: ChatListRowState
    
    init(_ initialSize:NSSize, account:Account, pinnedType: ChatListPinnedType, groupId: PeerGroupId, message: Message?, peers: [Peer], unreadCounters: GroupReferenceUnreadCounters, state: ChatListRowState = .plain) {
        self.groupId = groupId
        self.peers = peers
        self.peer = nil
        self.message = message
        self.state = state
        self.account = account
        self.groupUnreadCounters = unreadCounters
        self.mentionsCount = nil
        self.pinnedType = pinnedType
        self.renderedPeer = RenderedPeer(peerId: peers[0].id, peers: SimpleDictionary(peers.reduce([:], { current, peer in
            var current = current
            current[peer.id] = peer
            return current
        })))
        isVerified = false
        
        let titleText:NSMutableAttributedString = NSMutableAttributedString()
        let _ = titleText.append(string: L10n.chatListTitleFeed, color: theme.chatList.textColor, font: .medium(.title))
        titleText.setSelected(color: .white ,range: titleText.range)
        
        self.titleText = titleText
        self.messageText = chatListText(account: account, location: .group(groupId), for: message, renderedPeer: nil, embeddedState: nil)
        hasDraft = false
        
        
        if case .ad = pinnedType {
            let sponsored:NSMutableAttributedString = NSMutableAttributedString()
            _ = sponsored.append(string: L10n.chatListSponsoredChannel, color: theme.colors.grayText, font: .normal(.short))
            self.date = sponsored
            dateLayout = TextNode.layoutText(maybeNode: nil,  sponsored, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, false, .left)
            dateSelectedLayout = TextNode.layoutText(maybeNode: nil,  sponsored, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, true, .left)

        } else if let message = message {
            let date:NSMutableAttributedString = NSMutableAttributedString()
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= account.context.timeDifference
            let range = date.append(string: DateUtils.string(forMessageListDate: Int32(time)), color: theme.colors.grayText, font: .normal(.short))
            date.setSelected(color: .white,range: range)
            self.date = date.copy() as? NSAttributedString
            
            dateLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, false, .left)
            dateSelectedLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, true, .left)
        }
        
        photo = .GroupAvatar(peers)
        
        
        super.init(initialSize)
        if unreadCounters.unreadCount + unreadCounters.unreadMutedCount > 0 {
            let totalCount = unreadCounters.unreadCount + unreadCounters.unreadMutedCount
            badgeNode = BadgeNode(.initialize(string: "\(totalCount)", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
            badgeSelectedNode = BadgeNode(.initialize(string: "\(totalCount)", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
        } else if isUnreadMarked {
            badgeNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
            badgeSelectedNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
        }
        
        _ = makeSize(initialSize.width, oldWidth: 0)
    }

    init(_ initialSize:NSSize,  account:Account,  message: Message?,  readState:CombinedPeerReadState? = nil,  notificationSettings:PeerNotificationSettings? = nil, embeddedState:PeerChatListEmbeddedInterfaceState? = nil, pinnedType:ChatListPinnedType = .none, renderedPeer:RenderedPeer, summaryInfo: ChatListMessageTagSummaryInfo = ChatListMessageTagSummaryInfo(), state: ChatListRowState = .plain) {
        
        self.renderedPeer = renderedPeer
        self.account = account
        self.message = message
        self.state = state
        self.pinnedType = pinnedType
        self.hasDraft = embeddedState != nil
        self.peer = renderedPeer.chatMainPeer
        self.peers = renderedPeer.peers.map({$0.1})
        groupId = nil
        groupUnreadCounters = nil
        if let peer = peer {
            isVerified = peer.isVerified
        } else {
            isVerified = false
        }
       
        self.peerNotificationSettings = notificationSettings
        self.readState = readState
        
        
        let titleText:NSMutableAttributedString = NSMutableAttributedString()
        let _ = titleText.append(string: peer?.id == account.peerId ? tr(L10n.peerSavedMessages) : peer?.displayTitle, color: renderedPeer.peers[renderedPeer.peerId] is TelegramSecretChat ? theme.chatList.secretChatTextColor : theme.chatList.textColor, font: .medium(.title))
        titleText.setSelected(color: .white ,range: titleText.range)

        self.titleText = titleText
        self.messageText = chatListText(account: account, location: .peer(renderedPeer.peerId), for: message, renderedPeer: renderedPeer, embeddedState:embeddedState)
        
        
        if case .ad = pinnedType {
            let sponsored:NSMutableAttributedString = NSMutableAttributedString()
            let range = sponsored.append(string: L10n.chatListSponsoredChannel, color: theme.colors.grayText, font: .normal(.short))
            sponsored.setSelected(color: .white,range: range)
            self.date = sponsored
            dateLayout = TextNode.layoutText(maybeNode: nil,  sponsored, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, false, .left)
            dateSelectedLayout = TextNode.layoutText(maybeNode: nil,  sponsored, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, true, .left)
            
        } else if let message = message {
            let date:NSMutableAttributedString = NSMutableAttributedString()
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= account.context.timeDifference
            let range = date.append(string: DateUtils.string(forMessageListDate: Int32(time)), color: theme.colors.grayText, font: .normal(.short))
            date.setSelected(color: .white,range: range)
            self.date = date.copy() as? NSAttributedString
            
            dateLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, false, .left)
            dateSelectedLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, true, .left)
        }
        
        
        let tagSummaryCount = summaryInfo.tagSummaryCount ?? 0
        let actionsSummaryCount = summaryInfo.actionsSummaryCount ?? 0
        let totalMentionCount = tagSummaryCount - actionsSummaryCount
        if totalMentionCount > 0 {
            self.mentionsCount = totalMentionCount
        } else {
            self.mentionsCount = nil
        }
        
        if let peer = peer, peer.id != account.peerId {
            self.photo = .PeerAvatar(peer.id, peer.displayLetters, peer.smallProfileImage)
        } else {
            self.photo = .Empty
        }
        
        super.init(initialSize)
        
        if let unreadCount = readState?.count, unreadCount > 0, mentionsCount == nil || (unreadCount > 1 || mentionsCount! != unreadCount)  {
            
            badgeNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
            badgeSelectedNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
        } else if isUnreadMarked {
            badgeNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
            badgeSelectedNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
        }
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    let margin:CGFloat = 9
    
    var titleWidth:CGFloat {
        var dateSize:CGFloat = 0
        if let dateLayout = dateLayout {
            dateSize = dateLayout.0.size.width
        }
        
        return max(300, size.width) - 50 - margin * 4 - dateSize - (isMuted ? theme.icons.dialogMuteImage.backingSize.width + 4 : 0) - (isOutMessage ? isRead ? 14 : 8 : 0) - (isVerified ? 10 : 0) - (isSecret ? 10 : 0)
    }
    var messageWidth:CGFloat {
        if let badgeNode = badgeNode {
            return (max(300, size.width) - 50 - margin * 3) - badgeNode.size.width - 5 - (mentionsCount != nil ? 24 : 0)
        }
        
        return (max(300, size.width) - 50 - margin * 4) - (pinnedType != .none ? 20 : 0) - (mentionsCount != nil ? 24 : 0) - (state == .plain ? 0 : 40)
    }
    
    let leftInset:CGFloat = 50 + (10 * 2.0);
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        if self.oldWidth == 0 || self.oldWidth != width {
            
            if displayLayout == nil || !displayLayout!.0.isPerfectSized || self.oldWidth > width {
                displayLayout = TextNode.layoutText(maybeNode: displayNode,  titleText, nil, 1, .end, NSMakeSize(titleWidth, size.height), nil, false, .left)
            }
            if messageLayout == nil || !messageLayout!.0.isPerfectSized || self.oldWidth > width {
                messageLayout = TextNode.layoutText(maybeNode: messageNode,  messageText, nil, 2, .end, NSMakeSize(messageWidth, size.height), nil, false, .left)
            }
            if displaySelectedLayout == nil || !displaySelectedLayout!.0.isPerfectSized || self.oldWidth > width {
                displaySelectedLayout = TextNode.layoutText(maybeNode: displaySelectedNode,  titleText, nil, 1, .end, NSMakeSize(titleWidth, size.height), nil, true, .left)
            }
            if messageSelectedLayout == nil || !messageSelectedLayout!.0.isPerfectSized || self.oldWidth > width {
                messageSelectedLayout = TextNode.layoutText(maybeNode: messageSelectedNode,  messageText, nil, 2, .end, NSMakeSize(messageWidth, size.height), nil, true, .left)
            }
        }
        return super.makeSize(width, oldWidth: oldWidth)
    }
    

    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        var items:[ContextMenuItem] = []

        if let peer = peer {
            
            let deleteChat = {[weak self] in
                if let strongSelf = self {
                    let signal = removeChatInteractively(account: strongSelf.account, peerId: strongSelf.peerId, userId: strongSelf.peer?.id) |> filter {$0} |> mapToSignal { _ -> Signal<ChatLocation?, Void> in
                        return globalPeerHandler.get() |> take(1)
                    } |> deliverOnMainQueue
                    
                    strongSelf.deleteChatDisposable.set(signal.start(next: { [weak self] location in
                        if location == self?.chatLocation {
                            self?.account.context.mainNavigation?.close()
                        }
                    }))
                }
            }
            
            let clearHistory = { [weak self] in
                if let strongSelf = self {
                    modernConfirm(for: mainWindow, account: strongSelf.account, peerId: strongSelf.peer?.id, accessory: theme.icons.confirmDeleteChatAccessory, information: tr(L10n.confirmDeleteChatUser), successHandler: { _ in
                        strongSelf.clearHistoryDisposable.set(clearHistoryInteractively(postbox: strongSelf.account.postbox, peerId: strongSelf.peerId).start())
                   })
                }
            }
            
            let call = { [weak self] in
                if let peerId = self?.peer?.id, let account = self?.account {
                    self?.requestSessionId.set((phoneCall(account, peerId: peerId) |> deliverOnMainQueue).start(next: { result in
                        applyUIPCallResult(account, result)
                    }))
                }
            }
            
            let togglePin = {[weak self] in
                if let strongSelf = self {
                    
                    _ = (toggleItemPinned(postbox: strongSelf.account.postbox, itemId: strongSelf.chatLocation.pinnedItemId) |> deliverOnMainQueue).start(next: { result in
                        
                        switch result {
                        case .limitExceeded:
                            alert(for: mainWindow, info: L10n.chatListContextPinErrorNew)
                        default:
                            break
                        }
                    })
                }
            }
            
            let toggleMute = {[weak self] in
                if let strongSelf = self {
                    _ = togglePeerMuted(account: strongSelf.account, peerId: strongSelf.peerId).start()
                }
            }
            
            let leaveGroup = { [weak self] in
                if let strongSelf = self {
                    confirm(for: mainWindow, information: tr(L10n.confirmLeaveGroup), successHandler: { _ in
                        strongSelf.deleteChatDisposable.set(leftGroup(account: strongSelf.account, peerId: strongSelf.peerId).start())
                    })
                }
            }
            
            let rGroup = { [weak self] in
                if let strongSelf = self {
                    _ = returnGroup(account: strongSelf.account, peerId: strongSelf.peerId).start()
                }
            }
            
            if pinnedType != .ad {
                items.append(ContextMenuItem(pinnedType == .none ? tr(L10n.chatListContextPin) : tr(L10n.chatListContextUnpin), handler: togglePin))
            }
            
            if account.peerId != peer.id, pinnedType != .ad {
                items.append(ContextMenuItem(isMuted ? tr(L10n.chatListContextUnmute) : tr(L10n.chatListContextMute), handler: toggleMute))
            }
            
            if peer is TelegramUser {
                if peer.canCall && peer.id != account.peerId {
                    items.append(ContextMenuItem(tr(L10n.chatListContextCall), handler: call))
                }
                items.append(ContextMenuItem(tr(L10n.chatListContextClearHistory), handler: clearHistory))
                items.append(ContextMenuItem(tr(L10n.chatListContextDeleteChat), handler: deleteChat))
            }
            
            if !isUnreadMarked && badgeNode == nil && mentionsCount == nil {
                items.append(ContextMenuItem(tr(L10n.chatListContextMaskAsUnread), handler: { [weak self] in
                    guard let `self` = self else {return}
                    _ = togglePeerUnreadMarkInteractively(postbox: self.account.postbox, viewTracker: self.account.viewTracker, peerId: self.peerId).start()
                    
                }))
                
            } else if badgeNode != nil || mentionsCount != nil || isUnreadMarked {
                items.append(ContextMenuItem(tr(L10n.chatListContextMaskAsRead), handler: { [weak self] in
                    guard let `self` = self else {return}
                    _ = togglePeerUnreadMarkInteractively(postbox: self.account.postbox, viewTracker: self.account.viewTracker, peerId: self.peerId).start()
                }))
            }

            if let peer = peer as? TelegramGroup, pinnedType != .ad {
                items.append(ContextMenuItem(tr(L10n.chatListContextClearHistory), handler: clearHistory))
                switch peer.membership {
                case .Member:
                    items.append(ContextMenuItem(tr(L10n.chatListContextLeaveGroup), handler: leaveGroup))
                case .Left:
                    items.append(ContextMenuItem(tr(L10n.chatListContextReturnGroup), handler: rGroup))
                default:
                    break
                }
                items.append(ContextMenuItem(tr(L10n.chatListContextDeleteAndExit), handler: deleteChat))
            } else if let peer = peer as? TelegramChannel, pinnedType != .ad {
                
                if case .broadcast = peer.info {
                    
                    items.append(ContextMenuItem(tr(L10n.chatListContextLeaveChannel), handler: deleteChat))

                } else if pinnedType != .ad {
                    if peer.addressName == nil {
                        items.append(ContextMenuItem(tr(L10n.chatListContextClearHistory), handler: clearHistory))
                    }
                    items.append(ContextMenuItem(tr(L10n.chatListContextLeaveGroup), handler: deleteChat))
                }
            }
            
        } else {
            let togglePin = {[weak self] in
                if let strongSelf = self {
                    
                    _ = (toggleItemPinned(postbox: strongSelf.account.postbox, itemId: strongSelf.chatLocation.pinnedItemId) |> deliverOnMainQueue).start(next: { result in
                        
                        switch result {
                        case .limitExceeded:
                            alert(for: mainWindow, info: L10n.chatListContextPinErrorNew)
                        default:
                            break
                        }
                    })
                }
            }
            if pinnedType != .ad {
                items.append(ContextMenuItem(pinnedType == .none ? tr(L10n.chatListContextPin) : tr(L10n.chatListContextUnpin), handler: togglePin))
            }
            
        }
        return .single(items)
    }
    
    var ctxDisplayLayout:(TextNodeLayout, TextNode)? {
        if isSelected && account.context.layout != .single {
            return displaySelectedLayout
        }
        return displayLayout
    }
    var ctxMessageLayout:(TextNodeLayout, TextNode)? {
        if isSelected && account.context.layout != .single {
            if let typingSelectedLayout = typingSelectedLayout {
                return typingSelectedLayout
            }
            return messageSelectedLayout
        }
        if let typingLayout = typingLayout {
            return typingLayout
        }
        return messageLayout
    }
    var ctxDateLayout:(TextNodeLayout, TextNode)? {
        if isSelected && account.context.layout != .single {
            return dateSelectedLayout
        }
        return dateLayout
    }
    
    var ctxBadgeNode:BadgeNode? {
        if isSelected && account.context.layout != .single {
            return badgeSelectedNode
        }
        return badgeNode
    }
    
    override var instantlyResize: Bool {
        return true
    }

    deinit {
        clearHistoryDisposable.dispose()
        deleteChatDisposable.dispose()
        requestSessionId.dispose()
    }
    
    override func viewClass() -> AnyClass {
        return ChatListRowView.self
    }
  
    override var height: CGFloat {
        return 66;
    }
    
}
