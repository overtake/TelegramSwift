//
//  ChatServiceItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 06/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import TGCurrencyFormatter
import Postbox
import SwiftSignalKit
import InAppSettings

class ChatServiceItem: ChatRowItem {
    
    static var photoSize = NSMakeSize(200, 200)

    let text:TextViewLayout
    private(set) var imageArguments:TransformImageArguments?
    private(set) var image:TelegramMediaImage?
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ entry: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        let message:Message = entry.message!
        
        
        
        let linkColor: NSColor = theme.controllerBackgroundMode.hasWallpaper ? theme.chatServiceItemTextColor : entry.renderType == .bubble ? theme.chat.linkColor(true, entry.renderType == .bubble) : theme.colors.link
        let grayTextColor: NSColor = theme.chatServiceItemTextColor

        let authorId:PeerId? = message.author?.id
        var authorName:String = ""
        if let displayTitle = message.author?.displayTitle {
            authorName = displayTitle
        }
        
        let isIncoming: Bool = message.isIncoming(context.account, entry.renderType == .bubble)

        
        let nameColor:(PeerId) -> NSColor = { peerId in
            
            if theme.controllerBackgroundMode.hasWallpaper {
                return theme.chatServiceItemTextColor
            }
            let mainPeer = coreMessageMainPeer(message)
            
            if mainPeer is TelegramChannel || mainPeer is TelegramGroup {
                if let peer = mainPeer as? TelegramChannel, case .broadcast(_) = peer.info {
                    return theme.chat.linkColor(isIncoming, entry.renderType == .bubble)
                } else if context.peerId != peerId {
                    let value = abs(Int(peerId.id._internalGetInt64Value()) % 7)
                    return theme.chat.peerName(value)
                }
            }
            return theme.chat.linkColor(isIncoming, false)
        }
        
        
        let attributedString:NSMutableAttributedString = NSMutableAttributedString()
        if let media = message.media[0] as? TelegramMediaAction {
           
            if let peer = coreMessageMainPeer(message) {
               
                switch media.action {
                case let .groupCreated(title: title):
                    if !peer.isChannel {
                        let _ =  attributedString.append(string: strings().chatServiceGroupCreated1(authorName, title), color: grayTextColor, font: .normal(theme.fontSize))
                        
                        if let authorId = authorId {
                            let range = attributedString.string.nsstring.range(of: authorName)
                            attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                            attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                        }
                    } else {
                        let _ =  attributedString.append(string: strings().chatServiceChannelCreated, color: grayTextColor, font: .normal(theme.fontSize))
                    }
                    
                    
                case let .addedMembers(peerIds):
                    if peerIds.first == authorId {
                        let _ =  attributedString.append(string: strings().chatServiceGroupAddedSelf(authorName), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    } else {
                        let _ =  attributedString.append(string: strings().chatServiceGroupAddedMembers1(authorName, ""), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        for peerId in peerIds {
                            
                            if let peer = message.peers[peerId] {
                                let range = attributedString.append(string: peer.displayTitle, color: nameColor(peer.id), font: .medium(theme.fontSize))
                                attributedString.add(link:inAppLink.peerInfo(link: "", peerId:peerId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(peerId))
                                if peerId != peerIds.last {
                                    _ = attributedString.append(string: ", ", color: grayTextColor, font: .normal(theme.fontSize))
                                }
                                
                            }
                        }
                    }
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                    
                case let .removedMembers(peerIds):
                    if peerIds.first == message.author?.id {
                        let _ =  attributedString.append(string: strings().chatServiceGroupRemovedSelf(authorName), color: grayTextColor, font: .normal(theme.fontSize))
                    } else {
                        let _ =  attributedString.append(string: strings().chatServiceGroupRemovedMembers1(authorName, ""), color: grayTextColor, font: .normal(theme.fontSize))
                        for peerId in peerIds {
                            
                            if let peer = message.peers[peerId] {
                                let range = attributedString.append(string: peer.displayTitle, color: nameColor(peerId), font: .medium(theme.fontSize))
                                attributedString.add(link:inAppLink.peerInfo(link: "", peerId:peerId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(peer.id))
                                if peerId != peerIds.last {
                                    _ = attributedString.append(string: ", ", color: grayTextColor, font: .normal(theme.fontSize))
                                }
                                
                            }
                        }
                    }
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                    
                case let .photoUpdated(image):
                    if let image = image {
                        
                        let text: String
                        if image.videoRepresentations.isEmpty {
                            text = peer.isChannel ? strings().chatServiceChannelUpdatedPhoto : strings().chatServiceGroupUpdatedPhoto(authorName)
                        } else {
                            text = peer.isChannel ? strings().chatServiceChannelUpdatedVideo : strings().chatServiceGroupUpdatedVideo(authorName)
                        }
                        
                        let _ =  attributedString.append(string: text, color: grayTextColor, font: .normal(theme.fontSize))
                        let size = ChatServiceItem.photoSize
                        imageArguments = TransformImageArguments(corners: ImageCorners(radius: 10), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
                    } else {
                        let _ =  attributedString.append(string: peer.isChannel ? strings().chatServiceChannelRemovedPhoto : strings().chatServiceGroupRemovedPhoto(authorName), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        
                    }
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                    self.image = image
                    
                    
                case let .titleUpdated(title):
                    let _ =  attributedString.append(string: peer.isChannel ? strings().chatServiceChannelUpdatedTitle(title) : strings().chatServiceGroupUpdatedTitle1(authorName, title), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    
                    if let authorId = authorId {
                        
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                case .customText(let text, _):
                    let _ = attributedString.append(string: text, color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case .pinnedMessageUpdated:
                    var replyMessageText = ""
                    var pinnedId: MessageId?
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                            replyMessageText = message.restrictedText(context.contentSettings) ?? pullText(from: message) as String
                            pinnedId = attribute.messageId
                        }
                    }
                    let cutted = replyMessageText.prefixWithDots(30)
                    _ = attributedString.append(string: strings().chatServiceGroupUpdatedPinnedMessage1(authorName, cutted), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    let pinnedRange = attributedString.string.nsstring.range(of: cutted)
                    if pinnedRange.location != NSNotFound {
                        attributedString.add(link: inAppLink.callback("", { [weak chatInteraction] _ in
                            if let pinnedId = pinnedId {
                                chatInteraction?.focusMessageId(nil, pinnedId, .CenterEmpty)
                            }
                        }), for: pinnedRange, color: grayTextColor)
                        attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.medium(theme.fontSize), range: pinnedRange)
                    }
                   
                    
                    
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.medium(theme.fontSize), range: range)

                    }
                    
                case .joinedByLink:
                    let _ =  attributedString.append(string: strings().chatServiceGroupJoinedByLink(authorName), color: grayTextColor, font: .normal(theme.fontSize))
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                    
                case .channelMigratedFromGroup, .groupMigratedToChannel:
                    let _ =  attributedString.append(string: strings().chatServiceGroupMigratedToSupergroup, color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case let .messageAutoremoveTimeoutUpdated(seconds):
                    
                    if let authorId = authorId {
                        if authorId == context.peerId {
                            if seconds > 0 {
                                let _ =  attributedString.append(string: strings().chatServiceSecretChatSetTimerSelf1(autoremoveLocalized(Int(seconds))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                            } else {
                                let _ =  attributedString.append(string: strings().chatServiceSecretChatDisabledTimerSelf1, color: grayTextColor, font: NSFont.normal(theme.fontSize))
                            }
                        } else {
                            if let peer = coreMessageMainPeer(message) {
                                if peer.isGroup || peer.isSupergroup {
                                    if seconds > 0 {
                                        let _ =  attributedString.append(string: strings().chatServiceGroupSetTimer(autoremoveLocalized(Int(seconds))), color: grayTextColor, font: .normal(theme.fontSize))
                                    } else {
                                        let _ =  attributedString.append(string: strings().chatServiceGroupDisabledTimer, color: grayTextColor, font: .normal(theme.fontSize))
                                    }
                                } else if peer.isChannel {
                                    if seconds > 0 {
                                        let _ =  attributedString.append(string: strings().chatServiceChannelSetTimer(autoremoveLocalized(Int(seconds))), color: grayTextColor, font: .normal(theme.fontSize))
                                    } else {
                                        let _ =  attributedString.append(string: strings().chatServiceChannelDisabledTimer, color: grayTextColor, font: .normal(theme.fontSize))
                                    }
                                } else {
                                    if seconds > 0 {
                                        let _ =  attributedString.append(string: strings().chatServiceSecretChatSetTimer1(authorName, autoremoveLocalized(Int(seconds))), color: grayTextColor, font: .normal(theme.fontSize))
                                    } else {
                                        let _ =  attributedString.append(string: strings().chatServiceSecretChatDisabledTimer1(authorName), color: grayTextColor, font: .normal(theme.fontSize))
                                    }
                                }
                                let range = attributedString.string.nsstring.range(of: authorName)
                                attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                                attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.medium(theme.fontSize), range: range)
                            }

                        }
                    }
                case .historyScreenshot:
                    let _ =  attributedString.append(string: strings().chatServiceGroupTookScreenshot(authorName), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                case let .phoneCall(callId: _, discardReason: reason, duration: duration, _):
                    if let reason = reason {
                        switch reason {
                        case .busy:
                            _ = attributedString.append(string: strings().chatListServiceCallCancelled, color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        case .disconnect:
                            _ = attributedString.append(string: strings().chatListServiceCallMissed, color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        case .hangup:
                            if let duration = duration {
                                if message.author?.id == context.peerId {
                                    _ = attributedString.append(string: strings().chatListServiceCallOutgoing(.durationTransformed(elapsed: Int(duration))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                                } else {
                                    _ = attributedString.append(string: strings().chatListServiceCallIncoming(.durationTransformed(elapsed: Int(duration))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                                }
                            }
                        case .missed:
                            _ = attributedString.append(string: strings().chatListServiceCallMissed, color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        }
                    } else if let duration = duration {
                        if authorId == context.peerId {
                            _ = attributedString.append(string: strings().chatListServiceCallOutgoing(.durationTransformed(elapsed: Int(duration))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        } else {
                            _ = attributedString.append(string: strings().chatListServiceCallIncoming(.durationTransformed(elapsed: Int(duration))), color: grayTextColor, font: NSFont.normal(theme.fontSize))
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
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        _ = attributedString.append(string: " ")
                    }
                    _ = attributedString.append(string: strings().chatListServiceGameScored1Countable(Int(score), gameName), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case let .paymentSent(currency, totalAmount):
                    var paymentMessage:Message?
                    for attr in message.attributes {
                        if let attr = attr as? ReplyMessageAttribute {
                            if let message = message.associatedMessages[attr.messageId] {
                                paymentMessage = message
                            }
                        }
                    }
                    
                    if let paymentMessage = paymentMessage, let media = paymentMessage.media.first as? TelegramMediaInvoice, let peer = paymentMessage.peers[paymentMessage.id.peerId] {
                        _ = attributedString.append(string: strings().chatServicePaymentSent1(TGCurrencyFormatter.shared().formatAmount(totalAmount, currency: currency), peer.displayTitle, media.title), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                        attributedString.detectBoldColorInString(with: .medium(theme.fontSize))
                        
                        attributedString.add(link:inAppLink.callback("", { _ in
                            showModal(with: PaymentsReceiptController(context: context, messageId: message.id, message: paymentMessage), for: context.window)
                        }), for: attributedString.range, color: grayTextColor)
                        
                    } else {
                        _ = attributedString.append(string: strings().chatServicePaymentSent1("", "", ""), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    }
                case let .botDomainAccessGranted(domain):
                    _ = attributedString.append(string: strings().chatServiceBotPermissionAllowed(domain), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case let .botSentSecureValues(types):
                    let permissions = types.map({$0.rawValue}).joined(separator: ", ")
                     _ = attributedString.append(string: strings().chatServiceSecureIdAccessGranted(peer.displayTitle, permissions), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                case .peerJoined:
                    let _ =  attributedString.append(string: strings().chatServicePeerJoinedTelegram(authorName), color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                    }
                case let .geoProximityReached(fromId, toId, distance):
                    let distanceString = stringForDistance(distance: Double(distance))
                    let text: String
                    if fromId == context.peerId {
                        text = strings().notificationProximityYouReached1(distanceString, message.peers[toId]?.displayTitle ?? "")
                    } else if toId == context.peerId {
                        text = strings().notificationProximityReachedYou1(message.peers[fromId]?.displayTitle ?? "", distanceString)
                    } else {
                        text = strings().notificationProximityReached1(message.peers[fromId]?.displayTitle ?? "", distanceString, message.peers[toId]?.displayTitle ?? "")
                    }
                    let _ = attributedString.append(string: text, color: grayTextColor, font: NSFont.normal(theme.fontSize))

                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        if range.location != NSNotFound {
                            attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                            attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                        }
                    }
                    if let peer = message.peers[toId], !peer.displayTitle.isEmpty {
                        let range = attributedString.string.nsstring.range(of: peer.displayTitle)
                        if range.location != NSNotFound {
                            attributedString.add(link:inAppLink.peerInfo(link: "", peerId: peer.id, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(peer.id))
                            attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                        }
                    }
                    if let peer = message.peers[fromId], !peer.displayTitle.isEmpty {
                        let range = attributedString.string.nsstring.range(of: peer.displayTitle)
                        if range.location != NSNotFound {
                            attributedString.add(link:inAppLink.peerInfo(link: "", peerId: peer.id, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(peer.id))
                            attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                        }
                    }
                case let .groupPhoneCall(callId, accessHash, scheduleDate, duration):
                    let text: String
                    if let duration = duration {
                        if peer.isChannel {
                            text = strings().chatServiceVoiceChatFinishedChannel(autoremoveLocalized(Int(duration)))
                        } else if authorId == context.peerId {
                            text = strings().chatServiceVoiceChatFinishedYou(autoremoveLocalized(Int(duration)))
                        } else {
                            text = strings().chatServiceVoiceChatFinished(authorName, autoremoveLocalized(Int(duration)))
                        }
                        let _ = attributedString.append(string: text, color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    } else {
                        if peer.isChannel {
                            if let scheduled = scheduleDate {
                                text = strings().chatServiceVoiceChatScheduledChannel(stringForMediumDate(timestamp: scheduled))
                            } else {
                                text = strings().chatServiceVoiceChatStartedChannel
                            }
                        } else if authorId == context.peerId {
                            if let scheduled = scheduleDate {
                                text = strings().chatServiceVoiceChatScheduledYou(stringForMediumDate(timestamp: scheduled))
                            } else {
                                text = strings().chatServiceVoiceChatStartedYou
                            }
                        } else {
                            if let scheduled = scheduleDate {
                                text = strings().chatServiceVoiceChatScheduled(authorName, stringForMediumDate(timestamp: scheduled))
                            } else {
                                text = strings().chatServiceVoiceChatStarted(authorName)
                            }
                        }
                        let parsed = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes.init(body: MarkdownAttributeSet(font: .normal(theme.fontSize), textColor: grayTextColor), bold: MarkdownAttributeSet(font: .medium(theme.fontSize), textColor: grayTextColor), link: MarkdownAttributeSet(font: .medium(theme.fontSize), textColor: linkColor), linkAttribute: { [weak chatInteraction] link in
                            return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                                chatInteraction?.joinGroupCall(CachedChannelData.ActiveCall(id: callId, accessHash: accessHash, title: nil, scheduleTimestamp: scheduleDate, subscribedToScheduled: false), nil)
                            }))
                        }))
                        attributedString.append(parsed)
                    }
                    
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        if range.location != NSNotFound {
                            attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                            attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                        }
                    }
                case let .setChatTheme(emoji):
                    let text: String
                    
                    if message.author?.id == context.peerId {
                        if emoji.isEmpty {
                            text = strings().chatServiceDisabledThemeYou
                        } else {
                            text = strings().chatServiceUpdateThemeYou(emoji)
                        }
                    } else {
                        if emoji.isEmpty {
                            text = strings().chatServiceDisabledTheme(authorName)
                        } else {
                            text = strings().chatServiceUpdateTheme(authorName, emoji)
                        }
                    }
                    
                    let parsed = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes.init(body: MarkdownAttributeSet(font: .normal(theme.fontSize), textColor: grayTextColor), bold: MarkdownAttributeSet(font: .medium(theme.fontSize), textColor: grayTextColor), link: MarkdownAttributeSet(font: .medium(theme.fontSize), textColor: linkColor), linkAttribute: { link in
                        return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                            
                        }))
                    }))
                    attributedString.append(parsed)

                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        if range.location != NSNotFound {
                            attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                            attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                        }
                    }
                    
                    if !emoji.isEmpty {
                        let range = attributedString.string.nsstring.range(of: emoji)
                        if range.location != NSNotFound {
                            attributedString.add(link:inAppLink.callback("", { [weak chatInteraction] _ in
                                chatInteraction?.setupChatThemes()
                            }), for: range, color: linkColor)
                        }
                    }

                    
                case let .inviteToGroupPhoneCall(callId, accessHash, peerIds):
                    let text: String
                    
                    let list = NSMutableAttributedString()
                    for peerId in peerIds {
                        
                        if let peer = message.peers[peerId] {
                            let range = list.append(string: peer.displayTitle, color: nameColor(peerId), font: .medium(theme.fontSize))
                            list.add(link:inAppLink.peerInfo(link: "", peerId:peerId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(peer.id))
                            if peerId != peerIds.last {
                                _ = list.append(string: ", ", color: grayTextColor, font: .normal(theme.fontSize))
                            }
                        }
                    }
                    
                    if message.author?.id == context.peerId {
                        text = strings().chatServiceVoiceChatInvitationByYou("%mark%")
                    } else if peerIds.first == context.peerId {
                        text = strings().chatServiceVoiceChatInvitationForYou(authorName)
                    } else {
                        text = strings().chatServiceVoiceChatInvitation(authorName, "%mark%")
                    }
                    
                    let parsed = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes.init(body: MarkdownAttributeSet(font: .normal(theme.fontSize), textColor: grayTextColor), bold: MarkdownAttributeSet(font: .medium(theme.fontSize), textColor: grayTextColor), link: MarkdownAttributeSet(font: .medium(theme.fontSize), textColor: linkColor), linkAttribute: { [weak chatInteraction] link in
                        return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                            chatInteraction?.joinGroupCall(CachedChannelData.ActiveCall(id: callId, accessHash: accessHash, title: nil, scheduleTimestamp: nil, subscribedToScheduled: false), nil)
                        }))
                    }))
                    attributedString.append(parsed)
                    
                    let markRange = attributedString.string.nsstring.range(of: "%mark%")
                    if markRange.location != NSNotFound {
                        attributedString.replaceCharacters(in: markRange, with: list)
                    }

                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        if range.location != NSNotFound {
                            attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                            attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                        }
                    }
                case .joinedByRequest:
                    let text: String
                    if authorId == context.peerId {
                        if message.peers[message.id.peerId]?.isChannel == true {
                            text = strings().chatServiceJoinedChannelByRequest
                        } else {
                            text = strings().chatServiceJoinedGroupByRequest
                        }
                    } else {
                        if message.peers[message.id.peerId]?.isChannel == true {
                            text = strings().chatServiceUserJoinedChannelByRequest(authorName)
                        } else {
                            text = strings().chatServiceUserJoinedGroupByRequest(authorName)
                        }
                    }
                    let _ =  attributedString.append(string: text, color: grayTextColor, font: NSFont.normal(theme.fontSize))
                    
                    if let authorId = authorId {
                        let range = attributedString.string.nsstring.range(of: authorName)
                        attributedString.add(link:inAppLink.peerInfo(link: "", peerId:authorId, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: nameColor(authorId))
                        attributedString.addAttribute(.font, value: NSFont.medium(theme.fontSize), range: range)
                    }

                default:
                    break
                }
            }
        } else if let media = message.media[0] as? TelegramMediaExpiredContent {
            let text:String
            switch media.data {
            case .image:
                text = strings().serviceMessageExpiredPhoto
            case .file:
                if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                    text = strings().serviceMessageExpiredVideo
                } else {
                    text = strings().serviceMessageExpiredVideo
                }
            }
            _ = attributedString.append(string: text, color: grayTextColor, font: .normal(theme.fontSize))
        } else if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let _ = message.autoremoveAttribute {
            let isPhoto: Bool = message.media.first is TelegramMediaImage
            if authorId == context.peerId {
                _ = attributedString.append(string: isPhoto ? strings().serviceMessageDesturctingPhotoYou(authorName) : strings().serviceMessageDesturctingVideoYou(authorName), color: grayTextColor, font: .normal(theme.fontSize))
            } else if let _ = authorId {
                _ = attributedString.append(string:  isPhoto ? strings().serviceMessageDesturctingPhoto(authorName) : strings().serviceMessageDesturctingVideo(authorName), color: grayTextColor, font: .normal(theme.fontSize))
            }
        }
        
        
        text = TextViewLayout(attributedString, truncationType: .end, cutout: nil, alignment: .center)
        text.mayItems = false
        text.interactions = globalLinkExecutor
        super.init(initialSize, chatInteraction, entry, downloadSettings, theme: theme)
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        return NSZeroSize
    }
    
    override var isBubbled: Bool {
        return presentation.wallpaper.wallpaper != .none
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
            if presentation.shouldBlurService {
                text.generateAutoBlock(backgroundColor: presentation.chatServiceItemColor.withAlphaComponent(1))
            } else {
                text.generateAutoBlock(backgroundColor: presentation.chatServiceItemColor)
            }
        }
        return true
    }
    
    override func viewClass() -> AnyClass {
        return ChatServiceRowView.self
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        
        var items:[ContextMenuItem] = []
        let chatInteraction = self.chatInteraction
        if chatInteraction.presentation.state != .selecting {
            
            if let message = message, let peer = coreMessageMainPeer(message) {
                if !message.containsSecretMedia, canReplyMessage(message, peerId: peer.id, mode: chatInteraction.mode) {
                    items.append(ContextMenuItem(strings().messageContextReply1, handler: {
                        chatInteraction.setupReplyMessage(message.id)
                    }))
                }
                if canDeleteMessage(message, account: context.account, mode: chatInteraction.mode) {
                    items.append(ContextMenuItem(strings().messageContextDelete, handler: {
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
    
    private var photoVideoView: MediaPlayerView?
    private var photoVideoPlayer: MediaPlayer?
    
    required init(frame frameRect: NSRect) {
        textView = TextView()
        textView.isSelectable = false
        //textView.userInteractionEnabled = false
        //do not enable
       // textView.isEventLess = true
        super.init(frame: frameRect)
        //layerContentsRedrawPolicy = .onSetNeedsDisplay
        addSubview(textView)


        textView.set(handler: { [weak self] control in
            if let item = self?.item as? ChatServiceItem {
                if let message = item.message, let action = message.media.first as? TelegramMediaAction {
                    switch action.action {
                    case let .messageAutoremoveTimeoutUpdated(timeout):
                        if let peer = item.chatInteraction.peer {
                            if peer.canManageDestructTimer, timeout > 0 {
                                item.chatInteraction.showDeleterSetup(control)
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }, for: .Click)
    }
    
    override var backdorColor: NSColor {
        if let item = item as? ChatServiceItem {
            return item.isBubbled ? .clear : item.presentation.chatBackground
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
                self.photoVideoView?.centerX(y:textView.frame.maxY + (item.isBubbled ? 0 : 6))
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
    
    
    @objc func updatePlayerIfNeeded() {
        let accept = window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect) && !self.isDynamicContentLocked
        if let photoVideoPlayer = photoVideoPlayer {
            if accept {
                photoVideoPlayer.play()
            } else {
                photoVideoPlayer.pause()
            }
        }
    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        photoVideoPlayer?.seek(timestamp: 0)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: item?.table?.clipView)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.frameDidChangeNotification, object: item?.table?.view)
        } else {
            removeNotificationListeners()
        }
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        removeNotificationListeners()
    }
    
    
    override func mouseUp(with event: NSEvent) {
        if let imageView = imageView, imageView._mouseInside() {
            if let item = self.item as? ChatServiceItem {
                showPhotosGallery(context: item.context, peerId: item.chatInteraction.peerId, firstStableId: item.stableId, item.table, nil)
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
        textView.disableBackgroundDrawing = true

        guard let item = item as? ChatServiceItem else {
            return
        }
        
        if item.presentation.shouldBlurService {
            textView.blurBackground = item.presentation.blurServiceColor
            textView.backgroundColor = .clear
        } else {
            textView.blurBackground = nil
            textView.backgroundColor = .clear
        }

        var interactiveTextView: Bool = false

        if let message = item.message, let action = message.media.first as? TelegramMediaAction {
            switch action.action {
            case let .messageAutoremoveTimeoutUpdated(timeout):
                if let peer = item.chatInteraction.peer {
                    interactiveTextView = peer.canManageDestructTimer && timeout > 0
                }
            default:
                break
            }
        }
        textView.scaleOnClick = interactiveTextView


        if let arguments = item.imageArguments {


            if let image = item.image {
                if imageView == nil {
                    self.imageView = TransformImageView()
                    self.addSubview(imageView!)
                }
                imageView?.setSignal(signal: cachedMedia(media: image, arguments: arguments, scale: backingScaleFactor))
                imageView?.setSignal( chatMessagePhoto(account: item.context.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message!), media: image), toRepresentationSize:NSMakeSize(300, 300), scale: backingScaleFactor, autoFetchFullSize: true), cacheImage: { [weak image] result in
                    if let media = image {
                        cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: nil)
                    }
                })
                
                
                imageView?.set(arguments: arguments)
                
                
                if let video = image.videoRepresentations.last {
                    if self.photoVideoView == nil {
                        self.photoVideoView = MediaPlayerView()
                        self.photoVideoView!.layer?.cornerRadius = 10
                        self.addSubview(self.photoVideoView!)
                        self.photoVideoView!.isEventLess = true
                    }
                    self.photoVideoView!.frame = NSMakeRect(0, 0, ChatServiceItem.photoSize.width, ChatServiceItem.photoSize.height)
                    
                    let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [])
                    
                    let mediaPlayer = MediaPlayer(postbox: item.context.account.postbox, reference: MediaResourceReference.standalone(resource: file.resource), streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: true)
                    
                    mediaPlayer.actionAtEnd = .loop(nil)
                    self.photoVideoPlayer = mediaPlayer
                    mediaPlayer.play()
                    
                    if let seekTo = video.startTimestamp {
                        mediaPlayer.seek(timestamp: seekTo)
                    }
                    mediaPlayer.attachPlayerView(self.photoVideoView!)
                    
                } else {
                    self.photoVideoView?.removeFromSuperview()
                    self.photoVideoView = nil
                }
                
            } else {
                imageView?.removeFromSuperview()
                imageView = nil
            }
        } else {
            imageView?.removeFromSuperview()
            imageView = nil
        }
        self.needsLayout = true
        updateListeners()
    }
    
}
