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
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account:Account, _ entry: ChatHistoryEntry) {
        let message:Message = entry.message!

        let authorId:PeerId? = message.author?.id
        var authorName:String = ""
        if let displayTitle = message.author?.displayTitle {
            authorName = displayTitle
            if account.peerId == message.author?.id {
                authorName = tr(.chatServiceYou)
            }
        }
        let attributedString:NSMutableAttributedString = NSMutableAttributedString()
        if let media = message.media[0] as? TelegramMediaAction {
           
            if let peer = messageMainPeer(message) {
               
                switch media.action {
                case let .groupCreated(title: title):
                    if !peer.isChannel {
                        let _ =  attributedString.append(string: tr(.chatServiceGroupCreated(authorName, title)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                        
                        if let authorId = authorId {
                            let range = attributedString.string.nsstring.range(of: authorName)
                            if account.peerId != authorId {
                                attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                            }
                            attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(.custom(theme.fontSize)), range: range)
                        }
                    } else {
                        let _ =  attributedString.append(string: tr(.chatServiceChannelCreated), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                    }
                    
                    
                case let .addedMembers(peerIds):
                    if peerIds.first == authorId {
                        let _ =  attributedString.append(string: tr(.chatServiceGroupAddedSelf(authorName)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                    } else {
                        let _ =  attributedString.append(string: tr(.chatServiceGroupAddedMembers(authorName, "")), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                        for peerId in peerIds {
                            
                            if let peer = message.peers[peerId] {
                                let range = attributedString.append(string: peer.displayTitle, color: theme.colors.link, font: .medium(.custom(theme.fontSize)))
                                attributedString.add(link:inAppLink.peerInfo(peerId:peerId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                                if peerId != peerIds.last {
                                    _ = attributedString.append(string: ", ", color: theme.colors.grayText, font: .normal(.custom(theme.fontSize)))
                                }
                                
                            }
                        }
                    }
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        if account.peerId != authorId {
                            attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                        }
                        attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(.custom(theme.fontSize)), range: range)
                        
                    }
                    
                case let .removedMembers(peerIds):
                    if peerIds.first == message.author?.id {
                        let _ =  attributedString.append(string: tr(.chatServiceGroupRemovedSelf(authorName)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                    } else {
                        let _ =  attributedString.append(string: tr(.chatServiceGroupRemovedMembers(authorName, "")), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                        for peerId in peerIds {
                            
                            if let peer = message.peers[peerId] {
                                let range = attributedString.append(string: peer.displayTitle, color: theme.colors.link, font: .medium(.custom(theme.fontSize)))
                                attributedString.add(link:inAppLink.peerInfo(peerId:peerId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                                if peerId != peerIds.last {
                                    _ = attributedString.append(string: ", ", color: theme.colors.grayText, font: .normal(.custom(theme.fontSize)))
                                }
                                
                            }
                        }
                    }
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        if account.peerId != authorId {
                            attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                        }
                        attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(.custom(theme.fontSize)), range: range)
                        
                    }
                    
                case let .photoUpdated(image):
                    if let _ = image {
                        let _ =  attributedString.append(string: peer.isChannel ? tr(.chatServiceChannelUpdatedPhoto) : tr(.chatServiceGroupUpdatedPhoto(authorName)), color: theme.colors.grayText, font: .normal(.custom(theme.fontSize)))
                        let size = NSMakeSize(70, 70)
                        imageArguments = TransformImageArguments(corners: ImageCorners(radius: size.width / 2), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
                    } else {
                        let _ =  attributedString.append(string: peer.isChannel ? tr(.chatServiceChannelRemovedPhoto) : tr(.chatServiceGroupRemovedPhoto(authorName)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                        
                    }
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        if account.peerId != authorId {
                            attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                        }
                        attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(.custom(theme.fontSize)), range: range)
                        
                    }
                    self.image = image
                    
                    
                case let .titleUpdated(title):
                    let _ =  attributedString.append(string: peer.isChannel ? tr(.chatServiceChannelUpdatedTitle(title)) : tr(.chatServiceGroupUpdatedTitle(authorName, title)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                case .customText(let text):
                    let _ = attributedString.append(string: text, color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                case .pinnedMessageUpdated:
                    var replyMessageText = ""
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                            replyMessageText = pullText(from: message) as String
                        }
                    }
                    var cutted = replyMessageText.prefix(30)
                    if cutted.length != replyMessageText.length {
                        cutted += "..."
                    }
                    let _ =  attributedString.append(string: tr(.chatServiceGroupUpdatedPinnedMessage(authorName, cutted)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                        attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(.custom(theme.fontSize)), range: range)
                    }
                    
                case .joinedByLink:
                    let _ =  attributedString.append(string: tr(.chatServiceGroupJoinedByLink(authorName)), color: theme.colors.grayText, font: .normal(.custom(theme.fontSize)))
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        if account.peerId != authorId {
                            attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                        }
                        attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(.custom(theme.fontSize)), range: range)
                        
                    }
                    
                case .channelMigratedFromGroup, .groupMigratedToChannel:
                    let _ =  attributedString.append(string: tr(.chatServiceGroupMigratedToSupergroup), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                case let .messageAutoremoveTimeoutUpdated(seconds):
                    
                    if let authorId = authorId {
                        if authorId == account.peerId {
                            if seconds > 0 {
                                let _ =  attributedString.append(string: tr(.chatServiceSecretChatSetTimerSelf(autoremoveLocalized(Int(seconds)))), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                            } else {
                                let _ =  attributedString.append(string: tr(.chatServiceSecretChatDisabledTimerSelf), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                            }
                        } else {
                            if seconds > 0 {
                                let _ =  attributedString.append(string: tr(.chatServiceSecretChatSetTimer(authorName, autoremoveLocalized(Int(seconds)))), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                            } else {
                                let _ =  attributedString.append(string: tr(.chatServiceSecretChatDisabledTimer(authorName)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                            }
                            let range = attributedString.string.nsstring.range(of: authorName)
                            attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                            attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(.custom(theme.fontSize)), range: range)
                        }
                    }
                case .historyScreenshot:
                    let _ =  attributedString.append(string: tr(.chatServiceGroupTookScreenshot(authorName)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        if account.peerId != authorId {
                            attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                        }
                        attributedString.addAttribute(NSAttributedStringKey.font, value: NSFont.medium(.custom(theme.fontSize)), range: range)
                        
                    }
                case let .phoneCall(callId: _, discardReason: reason, duration: duration):
                    if let reason = reason {
                        switch reason {
                        case .busy:
                            _ = attributedString.append(string: tr(.chatListServiceCallCancelled), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                        case .disconnect:
                            _ = attributedString.append(string: tr(.chatListServiceCallDisconnected), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                        case .hangup:
                            if let duration = duration {
                                if message.author?.id == account.peerId {
                                    _ = attributedString.append(string: tr(.chatListServiceCallOutgoing(.durationTransformed(elapsed: Int(duration)))), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                                } else {
                                    _ = attributedString.append(string: tr(.chatListServiceCallIncoming(.durationTransformed(elapsed: Int(duration)))), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                                }
                            }
                        case .missed:
                            _ = attributedString.append(string: tr(.chatListServiceCallMissed), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                        }
                    } else if let duration = duration {
                        if authorId == account.peerId {
                            _ = attributedString.append(string: tr(.chatListServiceCallOutgoing(.durationTransformed(elapsed: Int(duration)))), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                        } else {
                            _ = attributedString.append(string: tr(.chatListServiceCallIncoming(.durationTransformed(elapsed: Int(duration)))), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
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
                    
                    if authorId == account.peerId {
                        _ = attributedString.append(string: authorName, color: theme.colors.grayText, font: NSFont.medium(.custom(theme.fontSize)))
                        _ = attributedString.append(string: " ")
                    } else if let authorId = authorId {
                        let range = attributedString.append(string: authorName, color: theme.colors.link, font: NSFont.medium(.custom(theme.fontSize)))
                        attributedString.add(link:inAppLink.peerInfo(peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                        _ = attributedString.append(string: " ")
                    }
                    _ = attributedString.append(string: tr(.chatListServiceGameScored(Int(score), gameName)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
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
                        _ = attributedString.append(string: tr(.chatServicePaymentSent(TGCurrencyFormatter.shared().formatAmount(totalAmount, currency: currency), peer.displayTitle, media.title)), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                        attributedString.detectBoldColorInString(with: NSFont.medium(.custom(theme.fontSize)))
                    } else {
                        _ = attributedString.append(string: tr(.chatServicePaymentSent("", "", "")), color: theme.colors.grayText, font: NSFont.normal(.custom(theme.fontSize)))
                    }
                default:
                    
                    break
                }
            }
        } else if let media = message.media[0] as? TelegramMediaExpiredContent {
            let text:String
            switch media.data {
            case .image:
                text = tr(.serviceMessageExpiredPhoto)
            case .file:
                if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                    text = tr(.serviceMessageExpiredFile)
                } else {
                    text = tr(.serviceMessageExpiredVideo)
                }
            }
            _ = attributedString.append(string: text, color: theme.colors.grayText, font: .normal(.custom(theme.fontSize)))
        } else if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let _ = message.autoremoveAttribute {
            let isPhoto: Bool = message.media.first is TelegramMediaImage
            if authorId == account.peerId {
                _ = attributedString.append(string: isPhoto ? tr(.serviceMessageDesturctingPhotoYou(authorName)) : tr(.serviceMessageDesturctingVideoYou(authorName)), color: theme.colors.grayText, font: .normal(.custom(theme.fontSize)))
            } else if let _ = authorId {
                _ = attributedString.append(string:  isPhoto ? tr(.serviceMessageDesturctingPhoto(authorName)) : tr(.serviceMessageDesturctingVideo(authorName)), color: theme.colors.grayText, font: .normal(.custom(theme.fontSize)))
            }
        }
        
        
        text = TextViewLayout(attributedString, truncationType: .end, cutout: nil, alignment: .center)
        text.interactions = globalLinkExecutor
        super.init(initialSize, chatInteraction, entry)
        self.account = account
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        return NSZeroSize
    }
    
    override var height: CGFloat {
        var height:CGFloat = text.layoutSize.height + 12
        if let imageArguments = imageArguments {
            height += imageArguments.imageSize.height + 6
        }
        return height
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        text.measure(width: width - 40)
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
                    items.append(ContextMenuItem(tr(.messageContextReply1), handler: {
                        chatInteraction.setupReplyMessage(message.id)
                    }))
                }
                if canDeleteMessage(message, account: account) {
                    items.append(ContextMenuItem(tr(.messageContextDelete), handler: {
                        chatInteraction.deleteMessages([message.id])
                    }))
                }
            }
        }
        
        return .single(items)
    }

}
