//
//  ChatServiceItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 06/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
class ChatServiceItem: ChatRowItem {

    let text:TextViewLayout
    private(set) var imageArguments:TransformImageArguments?
    private(set) var image:TelegramMediaImage?
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account:Account, _ entry: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        let message:Message = entry.message!
        
        
        let linkColor: NSColor = entry.renderType == .bubble ? theme.chat.linkColor(true, entry.renderType == .bubble) : theme.colors.link
        let grayTextColor: NSColor = entry.renderType == .bubble ? theme.chat.grayText(true, entry.renderType == .bubble) : theme.colors.grayText

        let authorId:PeerId? = message.author?.id
        var authorName:String = ""
        if let displayTitle = message.author?.displayTitle {
            authorName = displayTitle
        }
        let attributedString:NSMutableAttributedString = NSMutableAttributedString()
        if let media = message.media[0] as? TelegramMediaAction {
           
            if let peer = messageMainPeer(message) {
               
                switch media.action {
                case let .groupCreated(title: title):
                    if !peer.isChannel {
                        let _ =  attributedString.append(string: tr(L10n.chatServiceGroupCreated(authorName, title)), color: grayTextColor, font: .normal(theme.fontSize))
                        
                        if let authorId = authorId {
                            let range = attributedString.string.nsstring.range(of: authorName)
                            attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                            attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                        }
                    } else {
                        let _ =  attributedString.append(string: tr(L10n.chatServiceChannelCreated), color: grayTextColor, font: .normal(theme.fontSize))
                    }
                    
                    
                case let .addedMembers(peerIds):
                    if peerIds.first == authorId {
                        let _ =  attributedString.append(string: tr(L10n.chatServiceGroupAddedSelf(authorName)), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    } else {
                        let _ =  attributedString.append(string: tr(L10n.chatServiceGroupAddedMembers(authorName, "")), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        for peerId in peerIds {
                            
                            if let peer = message.peers[peerId] {
                                let range = attributedString.append(string: peer.displayTitle, color: linkColor, font: .medium(theme.fontSize))
                                attributedString.add(link:inAppLink.peerInfo(peerId:peerId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                                if peerId != peerIds.last {
                                    _ = attributedString.append(string: ", ", color: grayTextColor, font: .normal(theme.fontSize))
                                }
                                
                            }
                        }
                    }
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                        attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                    
                case let .removedMembers(peerIds):
                    if peerIds.first == message.author?.id {
                        let _ =  attributedString.append(string: tr(L10n.chatServiceGroupRemovedSelf(authorName)), color: grayTextColor, font: .normal(theme.fontSize))
                    } else {
                        let _ =  attributedString.append(string: tr(L10n.chatServiceGroupRemovedMembers(authorName, "")), color: grayTextColor, font: .normal(theme.fontSize))
                        for peerId in peerIds {
                            
                            if let peer = message.peers[peerId] {
                                let range = attributedString.append(string: peer.displayTitle, color: linkColor, font: .medium(theme.fontSize))
                                attributedString.add(link:inAppLink.peerInfo(peerId:peerId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                                if peerId != peerIds.last {
                                    _ = attributedString.append(string: ", ", color: grayTextColor, font: .normal(theme.fontSize))
                                }
                                
                            }
                        }
                    }
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                        attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                    
                case let .photoUpdated(image):
                    if let _ = image {
                        let _ =  attributedString.append(string: peer.isChannel ? tr(L10n.chatServiceChannelUpdatedPhoto) : tr(L10n.chatServiceGroupUpdatedPhoto(authorName)), color: grayTextColor, font: .normal(theme.fontSize))
                        let size = NSMakeSize(70, 70)
                        imageArguments = TransformImageArguments(corners: ImageCorners(radius: size.width / 2), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
                    } else {
                        let _ =  attributedString.append(string: peer.isChannel ? tr(L10n.chatServiceChannelRemovedPhoto) : tr(L10n.chatServiceGroupRemovedPhoto(authorName)), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        
                    }
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                        attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                    self.image = image
                    
                    
                case let .titleUpdated(title):
                    let _ =  attributedString.append(string: peer.isChannel ? tr(L10n.chatServiceChannelUpdatedTitle(title)) : tr(L10n.chatServiceGroupUpdatedTitle(authorName, title)), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case .customText(let text, _):
                    let _ = attributedString.append(string: text, color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case .pinnedMessageUpdated:
                    var replyMessageText = ""
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                            replyMessageText = pullText(from: message) as String
                        }
                    }
                    let cutted = replyMessageText.prefixWithDots(30)
                    let _ =  attributedString.append(string: tr(L10n.chatServiceGroupUpdatedPinnedMessage(authorName, cutted)), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                        attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                    
                case .joinedByLink:
                    let _ =  attributedString.append(string: tr(L10n.chatServiceGroupJoinedByLink(authorName)), color: grayTextColor, font: .normal(theme.fontSize))
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                        attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                    
                case .channelMigratedFromGroup, .groupMigratedToChannel:
                    let _ =  attributedString.append(string: tr(L10n.chatServiceGroupMigratedToSupergroup), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case let .messageAutoremoveTimeoutUpdated(seconds):
                    
                    if let authorId = authorId {
                        if authorId == account.peerId {
                            if seconds > 0 {
                                let _ =  attributedString.append(string: tr(L10n.chatServiceSecretChatSetTimerSelf(autoremoveLocalized(Int(seconds)))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                            } else {
                                let _ =  attributedString.append(string: tr(L10n.chatServiceSecretChatDisabledTimerSelf), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                            }
                        } else {
                            if seconds > 0 {
                                let _ =  attributedString.append(string: tr(L10n.chatServiceSecretChatSetTimer(authorName, autoremoveLocalized(Int(seconds)))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                            } else {
                                let _ =  attributedString.append(string: tr(L10n.chatServiceSecretChatDisabledTimer(authorName)), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                            }
                            let range = attributedString.string.nsstring.range(of: authorName)
                            attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                            attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(theme.fontSize), range: range)
                        }
                    }
                case .historyScreenshot:
                    let _ =  attributedString.append(string: tr(L10n.chatServiceGroupTookScreenshot(authorName)), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                        attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                case let .phoneCall(callId: _, discardReason: reason, duration: duration):
                    if let reason = reason {
                        switch reason {
                        case .busy:
                            _ = attributedString.append(string: tr(L10n.chatListServiceCallCancelled), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        case .disconnect:
                            _ = attributedString.append(string: tr(L10n.chatListServiceCallMissed), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        case .hangup:
                            if let duration = duration {
                                if message.author?.id == account.peerId {
                                    _ = attributedString.append(string: tr(L10n.chatListServiceCallOutgoing(.durationTransformed(elapsed: Int(duration)))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                                } else {
                                    _ = attributedString.append(string: tr(L10n.chatListServiceCallIncoming(.durationTransformed(elapsed: Int(duration)))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                                }
                            }
                        case .missed:
                            _ = attributedString.append(string: tr(L10n.chatListServiceCallMissed), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        }
                    } else if let duration = duration {
                        if authorId == account.peerId {
                            _ = attributedString.append(string: tr(L10n.chatListServiceCallOutgoing(.durationTransformed(elapsed: Int(duration)))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        } else {
                            _ = attributedString.append(string: tr(L10n.chatListServiceCallIncoming(.durationTransformed(elapsed: Int(duration)))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        }
                    }
                case let .gameScore(gameId: _, score: score):
                    
                    var gameName:String = ""
                    for attr in message.attributes {
                        if let attr = attr as? ReplyMessageAttribute {
                            if let message = message.associatedMessages[attr.messageId], let gameMedia = message.media.first as? TelegramMediaGame {
                                gameName = gameMedia.name
                            }
                        }
                    }
                    
                    if let authorId = authorId {
                        let range = attributedString.append(string: authorName, color: linkColor, font: NSFont.medium(theme.fontSize))
                        attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: linkColor)
                        _ = attributedString.append(string: " ")
                    }
                    _ = attributedString.append(string: tr(L10n.chatListServiceGameScored1Countable(Int(score), gameName)), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case let .paymentSent(currency, totalAmount):
                    var paymentMessage:Message?
                    for attr in message.attributes {
                        if let attr = attr as? ReplyMessageAttribute {
                            if let message = message.associatedMessages[attr.messageId] {
                                paymentMessage = message
                            }
                        }
                    }
                    
                    if let message = paymentMessage, let media = message.media.first as? TelegramMediaInvoice, let peer = messageMainPeer(message) {
                        _ = attributedString.append(string: tr(L10n.chatServicePaymentSent(TGCurrencyFormatter.shared().formatAmount(totalAmount, currency: currency), peer.displayTitle, media.title)), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        attributedString.detectBoldColorInString(with: .medium(theme.fontSize))
                    } else {
                        _ = attributedString.append(string: tr(L10n.chatServicePaymentSent("", "", "")), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    }
                case let .botDomainAccessGranted(domain):
                    _ = attributedString.append(string: L10n.chatServiceBotPermissionAllowed(domain), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case let .botSentSecureValues(types):
                    let permissions = types.map({$0.rawValue}).joined(separator: ", ")
                     _ = attributedString.append(string: L10n.chatServiceSecureIdAccessGranted(peer.displayTitle, permissions), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                default:
                    break
                }
            }
        } else if let media = message.media[0] as? TelegramMediaExpiredContent {
            let text:String
            switch media.data {
            case .image:
                text = tr(L10n.serviceMessageExpiredPhoto)
            case .file:
                if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                    text = tr(L10n.serviceMessageExpiredFile)
                } else {
                    text = tr(L10n.serviceMessageExpiredVideo)
                }
            }
            _ = attributedString.append(string: text, color: grayTextColor, font: .normal(theme.fontSize))
        } else if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let _ = message.autoremoveAttribute {
            let isPhoto: Bool = message.media.first is TelegramMediaImage
            if authorId == account.peerId {
                _ = attributedString.append(string: isPhoto ? tr(L10n.serviceMessageDesturctingPhotoYou(authorName)) : tr(L10n.serviceMessageDesturctingVideoYou(authorName)), color: grayTextColor, font: .normal(theme.fontSize))
            } else if let _ = authorId {
                _ = attributedString.append(string:  isPhoto ? tr(L10n.serviceMessageDesturctingPhoto(authorName)) : tr(L10n.serviceMessageDesturctingVideo(authorName)), color: grayTextColor, font: .normal(theme.fontSize))
            }
        }
        
        
        text = TextViewLayout(attributedString, truncationType: .end, cutout: nil, alignment: .center)
        
        text.interactions = globalLinkExecutor
        super.init(initialSize, chatInteraction, entry, downloadSettings)
        self.account = account
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        return NSZeroSize
    }
    
    override var isBubbled: Bool {
        return theme.wallpaper != .none
    }
    
    override var height: CGFloat {
        var height:CGFloat = text.layoutSize.height + (isBubbled ? 0 : 12)
        if let imageArguments = imageArguments {
            height += imageArguments.imageSize.height + (isBubbled ? 9 : 6)
        }
        return height
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        text.measure(width: width - 40)
        if isBubbled {
            text.generateAutoBlock(backgroundColor: theme.colors.chatDateActive)
        }
        return true
    }
    
    override func viewClass() -> AnyClass {
        return ChatServiceRowView.self
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        
        var items:[ContextMenuItem] = []
        let chatInteraction = self.chatInteraction
        if chatInteraction.presentation.state != .selecting {
            
            if let message = message, let peer = messageMainPeer(message) {
                if peer.canSendMessage, !message.containsSecretMedia {
                    items.append(ContextMenuItem(tr(L10n.messageContextReply1), handler: {
                        chatInteraction.setupReplyMessage(message.id)
                    }))
                }
                if canDeleteMessage(message, account: account) {
                    items.append(ContextMenuItem(tr(L10n.messageContextDelete), handler: {
                        chatInteraction.deleteMessages([message.id])
                    }))
                }
            }
        }
        
        return .single(items)
    }

}

class ChatServiceRowView: TableRowView {
    
    private var textView:TextView
    private var imageView:TransformImageView?
    required init(frame frameRect: NSRect) {
        textView = TextView()
        textView.isSelectable = false
        //textView.userInteractionEnabled = false
        textView.isEventLess = true
        super.init(frame: frameRect)
        addSubview(textView)
    }
    
    override var backdorColor: NSColor {
        if let item = item as? ChatServiceItem {
            return item.isBubbled ? .clear : theme.colors.background
        } else {
            return .clear
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        if let item = item as? ChatServiceItem {
            textView.update(item.text)
            textView.centerX(y:6)
            if let imageArguments = item.imageArguments {
                imageView?.setFrameSize(imageArguments.imageSize)
                imageView?.centerX(y:textView.frame.maxY + (item.isBubbled ? 0 : 6))
                self.imageView?.set(arguments: imageArguments)
            }
            
        }
    }
    
    
    override func doubleClick(in location: NSPoint) {
        if let item = self.item as? ChatRowItem, item.chatInteraction.presentation.state == .normal {
            if self.hitTest(location) == nil || self.hitTest(location) == self {
                item.chatInteraction.setupReplyMessage(item.message?.id)
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if let imageView = imageView, imageView._mouseInside() {
            if let item = self.item as? ChatServiceItem {
                showPhotosGallery(account: item.account, peerId: item.chatInteraction.peerId, firstStableId: item.stableId, item.table, nil)
            }
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool) -> NSView {
        return imageView ?? self
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated:animated)
        
        
        if let item = item as? ChatServiceItem {
            if let image = item.image {
                if imageView == nil {
                    self.imageView = TransformImageView()
                    self.addSubview(imageView!)
                }
                imageView?.setSignal( chatMessagePhoto(account: item.account, photo: image, toRepresentationSize:NSMakeSize(100,100), scale: backingScaleFactor))
            } else {
                imageView?.removeFromSuperview()
                imageView = nil
            }
            textView.backgroundColor = backdorColor
            self.needsLayout = true
        }
    }
    
}
