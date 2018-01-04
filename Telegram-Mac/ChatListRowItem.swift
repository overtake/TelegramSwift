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
}

class ChatListRowItem: TableRowItem {

    public private(set) var message:Message?
    
    var account:Account
    var peer:Peer?
    let renderedPeer:RenderedPeer
    var peerId:PeerId {
        return renderedPeer.peerId
    }
    
    private let requestSessionId:MetaDisposable = MetaDisposable()
    
    override var stableId: AnyHashable {
        return renderedPeer.peerId
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
        if let peerNotificationSettings = peerNotificationSettings as? TelegramPeerNotificationSettings {
            if case .muted(_) = peerNotificationSettings.muteState {
                return true
            }
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
    
    let hasDraft:Bool
    
    let pinnedType:ChatListPinnedType
    

    init(_ initialSize:NSSize,  account:Account,  message: Message?,  readState:CombinedPeerReadState? = nil,  notificationSettings:PeerNotificationSettings? = nil, embeddedState:PeerChatListEmbeddedInterfaceState? = nil, pinnedType:ChatListPinnedType = .none, renderedPeer:RenderedPeer, summaryInfo: ChatListMessageTagSummaryInfo = ChatListMessageTagSummaryInfo()) {
        
        self.renderedPeer = renderedPeer
        self.account = account
        self.message = message
        self.pinnedType = pinnedType
        self.hasDraft = embeddedState != nil
        self.peer = renderedPeer.chatMainPeer
        
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
        self.messageText = chatListText(account: account, for: message, renderedPeer: renderedPeer, embeddedState:embeddedState)
        
        
        if let message = message {
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
        
        super.init(initialSize)
        
        if let unreadCount = readState?.count, unreadCount > 0, mentionsCount == nil || (unreadCount > 1 || mentionsCount! != unreadCount)  {
            
            badgeNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
            badgeSelectedNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
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
        return (max(300, size.width) - 50 - margin * 4) - (pinnedType != .none ? 20 : 0) - (mentionsCount != nil ? 24 : 0)
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
        
        if let peer = peer {
            var items:[ContextMenuItem] = []
            
            let deleteChat = {[weak self] in
                if let strongSelf = self {
                    let signal = removeChatInteractively(account: strongSelf.account, peerId: strongSelf.peerId) |> filter {$0} |> mapToSignal { _ -> Signal<PeerId?, Void> in
                        return globalPeerHandler.get() |> take(1)
                    } |> deliverOnMainQueue
                    
                    strongSelf.deleteChatDisposable.set(signal.start(next: { [weak self] peerId in
                        if peerId == self?.peerId {
                            self?.account.context.mainNavigation?.close()
                        }
                    }))
                }
            }
            
            let clearHistory = { [weak self] in
                if let strongSelf = self {
                    confirm(for: mainWindow, information: tr(L10n.confirmDeleteChatUser), swapColors: true, successHandler: { _ in
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
                    _ = (togglePeerChatPinned(postbox: strongSelf.account.postbox, peerId: strongSelf.peerId) |> deliverOnMainQueue).start(next: { result in
                        
                        switch result {
                        case .limitExceeded:
                            alert(for: mainWindow, info: tr(L10n.chatListContextPinError))
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
                    confirm(for: mainWindow, information: tr(L10n.confirmLeaveGroup), swapColors: true, successHandler: { _ in
                        strongSelf.deleteChatDisposable.set(leftGroup(account: strongSelf.account, peerId: strongSelf.peerId).start())
                    })
                }
            }
            
            let rGroup = { [weak self] in
                if let strongSelf = self {
                    _ = returnGroup(account: strongSelf.account, peerId: strongSelf.peerId).start()
                }
            }
            
            items.append(ContextMenuItem(pinnedType == .none ? tr(L10n.chatListContextPin) : tr(L10n.chatListContextUnpin), handler: togglePin))
            
            if account.peerId != peer.id {
                items.append(ContextMenuItem(isMuted ? tr(L10n.chatListContextUnmute) : tr(L10n.chatListContextMute), handler: toggleMute))
            }
            
            if peer is TelegramUser {
                if peer.canCall && peer.id != account.peerId {
                    items.append(ContextMenuItem(tr(L10n.chatListContextCall), handler: call))
                }
                items.append(ContextMenuItem(tr(L10n.chatListContextClearHistory), handler: clearHistory))
                items.append(ContextMenuItem(tr(L10n.chatListContextDeleteChat), handler: deleteChat))
            }

            if let peer = peer as? TelegramGroup {
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
            } else if let peer = peer as? TelegramChannel {
                
                if case .broadcast = peer.info {
                    items.append(ContextMenuItem(tr(L10n.chatListContextLeaveChannel), handler: deleteChat))
                } else {
                    if peer.addressName == nil {
                        items.append(ContextMenuItem(tr(L10n.chatListContextClearHistory), handler: clearHistory))
                    }
                    items.append(ContextMenuItem(tr(L10n.chatListContextLeaveGroup), handler: deleteChat))
                }
            }
            
            return .single(items)
            
        }
        return .single([])
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
