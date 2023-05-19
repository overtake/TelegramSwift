//
//  TextUtils.swift
//  TelegramMac
//
//  Created by keepcoder on 04/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import TGCurrencyFormatter
import Postbox
import TGUIKit
import SwiftSignalKit
import CurrencyFormat

enum MessageTextMediaViewType {
    case emoji
    case text
    case none
}

func pullText(from message:Message, mediaViewType: MessageTextMediaViewType = .emoji, messagesCount: Int = 1) -> NSString {
    var messageText: String = message.text
    for attr in message.attributes {
        if let attr = attr as? TextEntitiesMessageAttribute {
            for entity in attr.entities {
                switch entity.type {
                case .Spoiler:
                    messageText = messageText.spoiler(NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound))
                default:
                    break
                }
            }
        }
    }
    
    for media in message.media {
        switch media {
        case _ as TelegramMediaImage:
            
            if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let timer = message.autoremoveAttribute, timer.timeout < 60 {
                messageText = strings().chatListServiceDestructingPhoto
            } else {
                if !message.text.isEmpty {
                    switch mediaViewType {
                    case .emoji:
                        messageText = ("🖼 " + messageText)
                    case .text:
                        break
                    case .none:
                        break
                    }
                } else {
                    messageText = strings().chatListPhoto1Countable(messagesCount)
                }
            }
        case let dice as TelegramMediaDice:
            messageText = dice.emoji
        case let fileMedia as TelegramMediaFile:
            if fileMedia.probablySticker {
                messageText = strings().chatListSticker(fileMedia.stickerText ?? "")
            } else if fileMedia.isVoice {
                if !message.text.isEmpty {
                    messageText = ("🎤" + " " + messageText)
                } else {
                    messageText = strings().chatListVoice
                }
            } else if fileMedia.isInstantVideo {
                messageText = strings().chatListInstantVideo
            } else if fileMedia.isVideo {
                
                if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let timer = message.autoremoveAttribute, timer.timeout < 60 {
                    messageText = strings().chatListServiceDestructingVideo
                } else {
                    if fileMedia.isAnimated {
                        if !messageText.isEmpty {
                             messageText = (strings().chatListGIF + ", " + messageText)
                        } else {
                            messageText = strings().chatListGIF
                        }
                    } else {
                        if !message.text.isEmpty {
                            switch mediaViewType {
                            case .emoji:
                                messageText = ("📹 " + messageText)
                            case .text:
                                break
                            case .none:
                                break
                            }
                        } else {
                            messageText = strings().chatListVideo1Countable(messagesCount)
                        }
                    }
                }
                
                
            } else if fileMedia.isMusic  {
                messageText = ("🎵 " + fileMedia.musicText.0 + " - " + fileMedia.musicText.1)
            } else {
                if !message.text.isEmpty {
                    switch mediaViewType {
                    case .emoji:
                        messageText = ("📎 " + messageText)
                    case .text:
                        break
                    case .none:
                        break
                    }
                } else {
                    messageText = fileMedia.fileName ?? "File"
                }
            }
        case _ as TelegramMediaMap:
            messageText = strings().chatListMap
        case _ as TelegramMediaContact:
            messageText = strings().chatListContact
        case let game as TelegramMediaGame:
            messageText = "🎮 \(game.title)"
        case let invoice as TelegramMediaInvoice:
            messageText = invoice.title
        case let poll as TelegramMediaPoll:
            messageText = "📊 \(poll.text)"
        case let webpage as TelegramMediaWebpage:
            if case let .Loaded(content) = webpage.content {
                if let _ = content.image {
                    switch mediaViewType {
                    case .emoji:
                        messageText = ("🖼 " + messageText)
                    case .text:
                        break
                    case .none:
                        break
                    }
                } else if let file = content.file {
                    if (file.isVideo && !file.isInstantVideo)  {
                        switch mediaViewType {
                        case .emoji:
                            messageText = ("🖼 " + messageText)
                        case .text:
                            break
                        case .none:
                            break
                        }
                    } else if file.isGraphicFile {
                        switch mediaViewType {
                        case .emoji:
                            messageText = ("📹 " + messageText)
                        case .text:
                            break
                        case .none:
                            break
                        }
                    }
                }
            }
        default:
            break
        }
    }
    return messageText.nsstring
    
}

func chatListText(account:Account, for message:Message?, messagesCount: Int = 1, renderedPeer:RenderedPeer? = nil, draft:EngineChatList.Draft? = nil, folder: Bool = false, applyUserName: Bool = false, isPremium: Bool = false, isReplied: Bool = false) -> NSAttributedString {
    
    
    if let draft = draft, !draft.text.isEmpty {
        let mutableAttributedText = NSMutableAttributedString()
        _ = mutableAttributedText.append(string: "\(strings().chatListDraft) ", color: theme.colors.redUI, font: .normal(.text))
        
        let textAttr = NSMutableAttributedString()
        _ = textAttr.append(string: draft.text, color: theme.chatList.grayTextColor, font: .normal(.text))
        
        InlineStickerItem.apply(to: textAttr, associatedMedia: [:], entities:  draft.entities, isPremium: isPremium, ignoreSpoiler: true)

        mutableAttributedText.append(textAttr)
        
        mutableAttributedText.setSelected(color: theme.colors.underSelectedColor, range: mutableAttributedText.range)
        
        return mutableAttributedText
    }
        
    if let renderedPeer = renderedPeer {
        if let peer = renderedPeer.peers[renderedPeer.peerId] as? TelegramSecretChat {
            let subAttr = NSMutableAttributedString()
            switch peer.embeddedState {
            case .terminated:
                _ = subAttr.append(string: strings().chatListSecretChatTerminated, color: theme.chatList.grayTextColor, font: .normal(.text))
            case .handshake:
            _ = subAttr.append(string: strings().chatListSecretChatExKeys, color: theme.chatList.grayTextColor, font: .normal(.text))
            case .active:
                if message == nil {
                    let title:String = renderedPeer.chatMainPeer?.displayTitle ?? strings().peerDeletedUser
                    switch peer.role {
                    case .creator:
                        _ = subAttr.append(string: strings().chatListSecretChatJoined(title), color: theme.chatList.grayTextColor, font: .normal(.text))
                    case .participant:
                        _ = subAttr.append(string: strings().chatListSecretChatCreated(title), color: theme.chatList.grayTextColor, font: .normal(.text))
                    }
                    
                }
            }
            subAttr.setSelected(color: theme.colors.underSelectedColor, range: subAttr.range)
            if subAttr.length > 0 {
                return subAttr
            }
        }
    }

    if let message = message {
    
        
           
        
        if message.text.isEmpty && message.media.isEmpty {
            let attr = NSMutableAttributedString()
            _ = attr.append(string: strings().chatListUnsupportedMessage, color: theme.chatList.grayTextColor, font: .normal(.text))
            attr.setSelected(color: theme.colors.underSelectedColor, range: attr.range)
            return attr
        }
        
        let peer = coreMessageMainPeer(message)
        
        
        var mediaViewType: MessageTextMediaViewType = .emoji
        if !message.containsSecretMedia {
            for media in message.media {
                if let _ = media as? TelegramMediaImage {
                    mediaViewType = .text
                } else if let file = media as? TelegramMediaFile {
                    if (file.isVideo && !file.isInstantVideo) || file.isGraphicFile {
                        mediaViewType = .text
                    }
                } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                    if let _ = content.image {
                        mediaViewType = .text
                    } else if let file = content.file {
                        if (file.isVideo && !file.isInstantVideo) || file.isGraphicFile {
                            mediaViewType = .text
                        }
                    }
                }
            }
        }
        
        let messageText: NSString = pullText(from: message, mediaViewType: mediaViewType, messagesCount: messagesCount)
        let attributedText: NSMutableAttributedString = NSMutableAttributedString()

        
        if messageText.length > 0 {
            
            if !isReplied {
                if folder, let peer = peer {
                    _ = attributedText.append(string: peer.displayTitle + "\r", color: theme.chatList.peerTextColor, font: .normal(.text))
                }
                if let author = message.author as? TelegramChannel, let peer = peer, peer.isGroup || peer.isSupergroup, applyUserName {
                    var peerText: String = (!message.flags.contains(.Incoming) ? "\(strings().chatListYou)" : author.displayTitle)
                    
                    peerText += (folder ? ": " : "\r")
                    _ = attributedText.append(string: peerText, color: theme.chatList.peerTextColor, font: .normal(.text))
                } else if let author = message.author as? TelegramUser, let peer = peer, peer as? TelegramUser == nil, !peer.isChannel, applyUserName {
                    var peerText: String = (author.id == account.peerId ? "\(strings().chatListYou)" : author.displayTitle)
                    
                    peerText += (folder ? ": " : "\r")
                    _ = attributedText.append(string: peerText, color: theme.chatList.peerTextColor, font: .normal(.text))
                    _ = attributedText.append(string: messageText as String, color: theme.chatList.grayTextColor, font: .normal(.text))
                } else {
                    _ = attributedText.append(string: messageText as String, color: theme.chatList.grayTextColor, font: .normal(.text))
                }
            } else {
                _ = attributedText.append(string: messageText as String, color: theme.chatList.grayTextColor, font: .normal(.text))
            }
            
            attributedText.setSelected(color: theme.colors.underSelectedColor, range: attributedText.range)
           
        } else if message.effectiveMedia is TelegramMediaAction {
            let service = serviceMessageText(message, account:account, isReplied: isReplied)
            _ = attributedText.append(string: service.0, color: theme.chatList.grayTextColor, font: .normal(.text))
            attributedText.detectBoldColorInString(with: .normal(.text))
            attributedText.setSelected(color: theme.colors.underSelectedColor, range: attributedText.range)
            
            InlineStickerItem.apply(to: attributedText, associatedMedia: service.2, entities: service.1, isPremium: isPremium)
            
        } else if let media = message.effectiveMedia as? TelegramMediaExpiredContent {
            let text:String
            switch media.data {
            case .image:
                text = strings().serviceMessageExpiredPhoto
            case .file:
                text = strings().serviceMessageExpiredVideo
            }
            _ = attributedText.append(string: text, color: theme.chatList.grayTextColor, font: .normal(.text))
            attributedText.setSelected(color: theme.colors.underSelectedColor,range: attributedText.range)
        }
        
        var effective: Message = message
        if !(message.effectiveMedia is TelegramMediaAction) {
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                    if let action = message.effectiveMedia as? TelegramMediaAction {
                        switch action.action {
                        case .pinnedMessageUpdated:
                            effective = message
                        default:
                            break
                        }
                    }
                }
            }
        }
        if !applyUserName {
            let range = attributedText.string.nsstring.range(of: effective.text)
            if range.location != NSNotFound {
                InlineStickerItem.apply(to: attributedText, associatedMedia: effective.associatedMedia, entities:  effective.entities, isPremium: isPremium, ignoreSpoiler: true, offset: range.location)
            }
            return attributedText.trimNewLinesToSpace
        } else {
            return attributedText
        }
        

    }
    return NSAttributedString()
}

func serviceMessageText(_ message:Message, account:Account, isReplied: Bool = false) -> (String, [MessageTextEntity], [MediaId : Media]) {
    
    var authorName:String = ""
    if let displayTitle = message.author?.displayTitle {
        if message.author?.id == account.peerId {
            authorName = strings().chatServiceYou
        } else {
            authorName = displayTitle
        }
    }
    
    
    var text: String = ""
    var entities: [MessageTextEntity] = []
    var media: [MediaId : Media] = [:]
    
    if let media = message.effectiveMedia as? TelegramMediaExpiredContent {
        switch media.data {
        case .image:
            text = strings().chatListPhoto
        case .file:
            text = strings().chatListVideo
        }
        return (text, [], [:])
    }
   
    
    let authorId:PeerId? = message.author?.id
    
    if let action = message.effectiveMedia as? TelegramMediaAction, let peer = coreMessageMainPeer(message) {
        switch action.action {
        case let .addedMembers(peerIds: peerIds):
            if peerIds.first == authorId {
                text = strings().chatServiceGroupAddedSelf(authorName)
            } else {
                text = strings().chatServiceGroupAddedMembers1(authorName, peerDebugDisplayTitles(peerIds, message.peers))
            }
        case .phoneNumberRequest:
            text = "phone number request"
        case .channelMigratedFromGroup:
            text = ""
        case let .groupCreated(title: title):
            if peer.isChannel {
                text = strings().chatServiceChannelCreated
            } else {
                text = strings().chatServiceGroupCreated1(authorName, title)
            }
        case .groupMigratedToChannel:
            text = ""
        case .historyCleared:
            text = ""
        case .historyScreenshot:
            text = strings().chatServiceGroupTookScreenshot(authorName)
        case let .joinedByLink(inviter: peerId):
            if peerId == authorId {
                text = strings().chatServiceGroupJoinedByLink(strings().chatServiceYou)
            } else {
                text = strings().chatServiceGroupJoinedByLink(authorName)
            }
        case let .messageAutoremoveTimeoutUpdated(seconds):
            if seconds > 0 {
                text = strings().chatServiceSecretChatSetTimer1(authorName, autoremoveLocalized(Int(seconds)))
            } else {
                text = strings().chatServiceSecretChatDisabledTimer1(authorName)
            }
        case let .photoUpdated(image: image):
            if let image = image {
                if image.videoRepresentations.isEmpty {
                    text = peer.isChannel ? strings().chatServiceChannelUpdatedPhoto : strings().chatServiceGroupUpdatedPhoto(authorName)
                } else {
                    text = peer.isChannel ? strings().chatServiceChannelUpdatedVideo : strings().chatServiceGroupUpdatedVideo(authorName)
                }
            } else {
                text = peer.isChannel ? strings().chatServiceChannelRemovedPhoto : strings().chatServiceGroupRemovedPhoto(authorName)
            }
        case .pinnedMessageUpdated:
            if !isReplied {
                var authorName:String = ""
                if let displayTitle = message.author?.displayTitle {
                    authorName = displayTitle
                    if account.peerId == message.author?.id {
                        authorName = strings().chatServiceYou
                    }
                }
                
                var replyMessageText = ""
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        replyMessageText = pullText(from: message) as String
                    }
                }
                text = strings().chatServiceGroupUpdatedPinnedMessage1(authorName, replyMessageText.prefixWithDots(15))
            } else {
                text = strings().chatServicePinnedMessage
            }
            
        case let .removedMembers(peerIds: peerIds):
            if peerIds.first == authorId {
                text = strings().chatServiceGroupRemovedSelf(authorName)
            } else {
                text = strings().chatServiceGroupRemovedMembers1(authorName, peerCompactDisplayTitles(peerIds, message.peers))
            }

        case let .titleUpdated(title: title):
            text = peer.isChannel ? strings().chatServiceChannelUpdatedTitle(title) : strings().chatServiceGroupUpdatedTitle1(authorName, title)
        case let .phoneCall(callId: _, discardReason: reason, duration: duration, isVideo):
            
            if let duration = duration, duration > 0 {
                if message.author?.id == account.peerId {
                    text = isVideo ? strings().chatListServiceVideoCallOutgoing(.stringForShortCallDurationSeconds(for: duration)) : strings().chatListServiceCallOutgoing(.stringForShortCallDurationSeconds(for: duration))
                } else {
                    text = isVideo ? strings().chatListServiceVideoCallIncoming(.stringForShortCallDurationSeconds(for: duration)) : strings().chatListServiceCallIncoming(.stringForShortCallDurationSeconds(for: duration))
                }
            }
            
            if let reason = reason {
                let outgoing = !message.flags.contains(.Incoming)
                
                switch reason {
                case .busy:
                    text = outgoing ? (isVideo ? strings().chatListServiceVideoCallCancelled : strings().chatListServiceCallCancelled) : (isVideo ? strings().chatListServiceVideoCallMissed : strings().chatListServiceCallMissed)
                case .disconnect:
                    text = isVideo ? strings().chatListServiceVideoCallMissed : strings().chatListServiceCallMissed
                case .hangup:
                    text = outgoing ? (isVideo ? strings().chatListServiceVideoCallCancelled : strings().chatListServiceCallCancelled) : (isVideo ? strings().chatListServiceVideoCallMissed : strings().chatListServiceCallMissed)
                case .missed:
                    text = outgoing ? (isVideo ? strings().chatListServiceVideoCallCancelled : strings().chatListServiceCallCancelled) : (isVideo ? strings().chatListServiceVideoCallMissed : strings().chatListServiceCallMissed)
                }
            }
        case let .gameScore(gameId: _, score: score):
            var gameName:String = ""
            for attr in message.attributes {
                if let attr = attr as? ReplyMessageAttribute {
                    if let message = message.associatedMessages[attr.messageId], let gameMedia = message.effectiveMedia as? TelegramMediaGame {
                        gameName = gameMedia.name
                    }
                }
            }
            text = strings().chatListServiceGameScored1Countable(Int(score), gameName)
            if let peer = coreMessageMainPeer(message) {
                if peer.isGroup || peer.isSupergroup {
                    text = (message.author?.compactDisplayTitle ?? "") + " " + text
                }
            }
        case let .paymentSent(currency, totalAmount, _,  _, _):
            text = strings().chatListServicePaymentSent(TGCurrencyFormatter.shared().formatAmount(totalAmount, currency: currency))
        case .unknown:
            break
        case .customText(let value, _):
            text = value
        case let .botDomainAccessGranted(domain):
            text = strings().chatServiceBotPermissionAllowed(domain)
        case let .botSentSecureValues(types):
            let permissions = types.map({$0.rawValue}).joined(separator: ", ")
            text = strings().chatServiceSecureIdAccessGranted(peer.displayTitle, permissions)
        case .peerJoined:
            text = strings().chatServicePeerJoinedTelegram(authorName)
        case let .geoProximityReached(fromId, toId, distance):
            let distanceString = stringForDistance(distance: Double(distance))
            if toId == account.peerId {
                text = strings().notificationProximityReachedYou1(message.peers[fromId]?.displayTitle ?? "", distanceString)
            } else if fromId == account.peerId {
                text = strings().notificationProximityYouReached1(message.peers[toId]?.displayTitle ?? "", distanceString)
            } else {
                text = strings().notificationProximityReached1(message.peers[fromId]?.displayTitle ?? "", distanceString, message.peers[toId]?.displayTitle ?? "")
            }
        case let .groupPhoneCall(_, _, scheduledDate, duration):
            if let duration = duration {
                if peer.isChannel {
                    text = strings().chatServiceVoiceChatFinishedChannel1(autoremoveLocalized(Int(duration)))
                } else if authorId == account.peerId {
                    text = strings().chatServiceVoiceChatFinishedYou(autoremoveLocalized(Int(duration)))
                } else {
                    text = strings().chatServiceVoiceChatFinished(authorName, autoremoveLocalized(Int(duration)))
                }
            } else {
                if peer.isChannel {
                    if let scheduledDate = scheduledDate {
                        text = strings().chatListServiceVoiceChatScheduledChannel1(stringForMediumDate(timestamp: scheduledDate))
                    } else {
                        text = strings().chatListServiceVoiceChatStartedChannel1
                    }
                } else if authorId == account.peerId {
                    if let scheduledDate = scheduledDate {
                        text = strings().chatListServiceVoiceChatScheduledYou(stringForMediumDate(timestamp: scheduledDate))
                    } else {
                        text = strings().chatListServiceVoiceChatStartedYou
                    }
                } else {
                    if let scheduledDate = scheduledDate {
                        text = strings().chatListServiceVoiceChatScheduled(authorName, stringForMediumDate(timestamp: scheduledDate))
                    } else {
                        text = strings().chatListServiceVoiceChatStarted(authorName)
                    }
                }
            }
        case  let .inviteToGroupPhoneCall(_, _, peerIds):
            
            var list = ""
            for peerId in peerIds {
                if let peer = message.peers[peerId] {
                    list += peer.displayTitle
                    if peerId != peerIds.last {
                        list += ", "
                    }
                }
            }
            
            if authorId == account.peerId {
                text = strings().chatListServiceVoiceChatInvitationByYou(list)
            } else if peerIds.first == account.peerId {
                text = strings().chatListServiceVoiceChatInvitationForYou(authorName)
            } else {
                text = strings().chatListServiceVoiceChatInvitation(authorName, list)
            }
        case let .setChatTheme(emoji):
            if authorId == account.peerId {
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
        case .joinedByRequest:
            if authorId == account.peerId {
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
        case let .webViewData(data):
            text = strings().chatServiceWebData(data)
        case let .giftPremium(currency, amount, _):
            if authorId == account.peerId {
                text = strings().chatServicePremiumGiftSentYou(formatCurrencyAmount(amount, currency: currency))
            } else {
                text = strings().chatServicePremiumGiftSent(authorName, formatCurrencyAmount(amount, currency: currency))
            }
        case let .topicEdited(components):
            var fileId: Int64?
            if components.count == 1 {
                let component = components[0]
                switch component {
                case let .title(title):
                    if authorId == account.peerId {
                        text = strings().chatServiceGroupTopicEditedYouTitle(title)
                    } else {
                        text = strings().chatServiceGroupTopicEditedTitle(authorName, title)
                    }
                case let .iconFileId(iconFileId):
                    fileId = iconFileId
                    if let iconFileId = iconFileId {
                        if authorId == account.peerId {
                            text = strings().chatServiceGroupTopicEditedYouIcon("~~\(iconFileId)~~")
                        } else {
                            text = strings().chatServiceGroupTopicEditedIcon(authorName, "~~\(iconFileId)~~")
                        }
                    } else {
                        if authorId == account.peerId {
                            text = strings().chatServiceGroupTopicEditedYouIconRemoved
                        } else {
                            text = strings().chatServiceGroupTopicEditedIconRemoved(authorName)
                        }
                    }
                case let .isClosed(closed):
                    if authorId == account.peerId {
                        if closed {
                            text = strings().chatServiceGroupTopicEditedYouPaused
                        } else {
                            text = strings().chatServiceGroupTopicEditedYouResumed
                        }
                    } else {
                        if closed {
                            text = strings().chatServiceGroupTopicEditedPaused(authorName)
                        } else {
                            text = strings().chatServiceGroupTopicEditedResumed(authorName)
                        }
                    }
                }
            } else {
                var title: String = ""
                var iconFileId: Int64?
                for component in components {
                    switch component {
                    case let .title(value):
                        title = value.prefixWithDots(30)
                    case let .iconFileId(value):
                        iconFileId = value
                    case .isClosed:
                        break
                    }
                }
                if let fileId = fileId {
                    if authorId == account.peerId {
                        text = strings().chatServiceGroupTopicEditedYouMixed("~~\(fileId)~~", title)
                    } else {
                        text = strings().chatServiceGroupTopicEditedMixed(authorName, "~~\(fileId)~~", title)
                    }
                } else {
                    if authorId == account.peerId {
                        text = strings().chatServiceGroupTopicEditedYouTitle(title)
                    } else {
                        text = strings().chatServiceGroupTopicEditedTitle(authorName, title)
                    }
                }
            }
            let range = text.nsstring.range(of: "~~\(fileId ?? 0)~~")
            if range.location != NSNotFound, let fileId = fileId {
                entities.append(.init(range: range.lowerBound ..< range.upperBound, type: .CustomEmoji(stickerPack: nil, fileId: fileId)))
            }
        case let .topicCreated(title, _, iconFileId):
            let iconText: String?
            if let iconFileId = iconFileId {
                iconText = "~~\(iconFileId)~~"
            } else {
                iconText = nil
            }
            if let iconText = iconText {
                text = strings().chatServiceGroupTopicCreatedIcon(iconText, title)
            } else {
                text = strings().chatServiceGroupTopicCreated(title)
            }
            if let iconText = iconText, let iconFileId = iconFileId {
                let range = text.nsstring.range(of: iconText)
                if range.location != NSNotFound {
                    entities.append(.init(range: range.lowerBound ..< range.upperBound, type: .CustomEmoji(stickerPack: nil, fileId: iconFileId)))
                }
            }
            
            
        }
    }
    return (text, entities, media)
}

struct PeerStatusStringTheme {
    let titleFont:NSFont
    let titleColor:NSColor
    let statusFont:NSFont
    let statusColor:NSColor
    let highlightColor:NSColor
    let highlightIfActivity:Bool
    init(titleFont:NSFont = .normal(.title), titleColor:NSColor = theme.colors.text, statusFont:NSFont = .normal(.short), statusColor:NSColor = theme.colors.grayText, highlightColor:NSColor = theme.colors.accent, highlightIfActivity:Bool = true) {
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.statusFont = statusFont
        self.statusColor = statusColor
        self.highlightColor = highlightColor
        self.highlightIfActivity = highlightIfActivity
    }
}

struct PeerStatusStringResult : Equatable {
    let title:NSAttributedString
    let status:NSAttributedString
    let presence:TelegramUserPresence?
    init(_ title:NSAttributedString, _ status:NSAttributedString, presence:TelegramUserPresence? = nil) {
        self.title = title
        self.status = status
        self.presence = presence
    }
    
    func withUpdatedTitle(_ string: String) -> PeerStatusStringResult {
        let title = self.title.mutableCopy() as! NSMutableAttributedString
        title.replaceCharacters(in: title.range, with: string)
        return PeerStatusStringResult(title, self.status, presence: self.presence)
    }
    
    func withUpdatedStatus(_ string: String) -> PeerStatusStringResult {
        let status = self.status.mutableCopy() as! NSMutableAttributedString
        status.replaceCharacters(in: status.range, with: string)
        return PeerStatusStringResult(self.title, status, presence: self.presence)
    }
}

func ==(lhs: PeerStatusStringResult, rhs: PeerStatusStringResult) -> Bool {
    if !lhs.title.isEqual(to: rhs.title) {
        return false
    }
    if !lhs.status.isEqual(to: rhs.status) {
        return false
    }
    if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence, !lhsPresence.isEqual(to: rhsPresence) {
        return false
    } else if (lhs.presence != nil) != (rhs.presence != nil)  {
        return false
    }
    return true
}

func stringStatus(for peerView:PeerView, context: AccountContext, theme:PeerStatusStringTheme = PeerStatusStringTheme(), onlineMemberCount: Int32? = nil, expanded: Bool = false) -> PeerStatusStringResult {
    if let peer = peerViewMainPeer(peerView) {
        let title:NSAttributedString = .initialize(string: peer.displayTitle, color: theme.titleColor, font: theme.titleFont)
        if let user = peer as? TelegramUser {
            if user.phone == "42777" || user.phone == "42470" || user.phone == "4240004" {
                return PeerStatusStringResult(title, .initialize(string: strings().peerServiceNotifications,  color: theme.statusColor, font: theme.statusFont))
            }
            if user.id == repliesPeerId {
                return PeerStatusStringResult(title, .initialize(string: strings().peerRepliesNotifications,  color: theme.statusColor, font: theme.statusFont))
            } else if user.flags.contains(.isSupport) {
                return PeerStatusStringResult(title, .initialize(string: strings().presenceSupport,  color: theme.statusColor, font: theme.statusFont))
            } else if let _ = user.botInfo {
                return PeerStatusStringResult(title, .initialize(string: strings().presenceBot,  color: theme.statusColor, font: theme.statusFont))
            } else if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                let (string, activity, _) = stringAndActivityForUserPresence(presence, timeDifference: context.timeDifference, relativeTo: Int32(timestamp), expanded: expanded)
                
                return PeerStatusStringResult(title, .initialize(string: string, color: activity && theme.highlightIfActivity ? theme.highlightColor : theme.statusColor, font: theme.statusFont), presence: presence)

            } else {
                return PeerStatusStringResult(title, .initialize(string: strings().peerStatusRecently, color: theme.statusColor, font: theme.statusFont))
            }
        } else if let group = peer as? TelegramGroup {
            var onlineCount = 0
            if let cachedGroupData = peerView.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                for participant in participants.participants {
                    if let presence = peerView.peerPresences[participant.peerId] as? TelegramUserPresence {
                        let relativeStatus = relativeUserPresenceStatus(presence, timeDifference: context.timeDifference, relativeTo: Int32(timestamp))
                        switch relativeStatus {
                        case .online:
                            onlineCount += 1
                        default:
                            break
                        }
                    }
                }
            }
            if onlineCount > 1 {
                let string = NSMutableAttributedString()
                
                let _ = string.append(string: "\(strings().peerStatusMemberCountable(group.participantCount).replacingOccurrences(of: "\(group.participantCount)", with: group.participantCount.formattedWithSeparator)), ", color: theme.statusColor, font: theme.statusFont)
                let _ = string.append(string: strings().peerStatusMemberOnlineCountable(onlineCount), color: theme.statusColor, font: theme.statusFont)
                return PeerStatusStringResult(title, string)
            } else {
                let string = NSAttributedString.initialize(string: strings().peerStatusMemberCountable(group.participantCount).replacingOccurrences(of: "\(group.participantCount)", with: group.participantCount.formattedWithSeparator), color: theme.statusColor, font: theme.statusFont)
                return PeerStatusStringResult(title, string)
            }
        } else if let channel = peer as? TelegramChannel {
            
            let onlineCount: Int = Int(onlineMemberCount ?? 0)
            if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
            
                
                let membersLocalized: String
                if channel.isChannel {
                    membersLocalized = strings().peerStatusSubscribersCountable(Int(memberCount))
                } else {
                    if memberCount > 0 {
                        membersLocalized = strings().peerStatusMemberCountable(Int(memberCount))
                    } else {
                        membersLocalized = strings().peerStatusGroup
                    }
                }
                
                let countString = membersLocalized.replacingOccurrences(of: "\(memberCount)", with: memberCount.formattedWithSeparator)
                if onlineCount > 1, case .group = channel.info {
                    let string = NSMutableAttributedString()
                    let _ = string.append(string: "\(countString), ", color: theme.statusColor, font: theme.statusFont)
                    let _ = string.append(string: strings().peerStatusMemberOnlineCountable(onlineCount), color: theme.statusColor, font: theme.statusFont)
                    return PeerStatusStringResult(title, string)
                } else {
                    
                    let string = NSAttributedString.initialize(string: countString, color: theme.statusColor, font: theme.statusFont)
                    return PeerStatusStringResult(title, string)
                }
                
            } else {
                switch channel.info {
                case .group:
                    let string = NSAttributedString.initialize(string: strings().peerStatusGroup, color: theme.statusColor, font: theme.statusFont)
                    return PeerStatusStringResult(title, string)

                case .broadcast:
                    let string = NSAttributedString.initialize(string: strings().peerStatusChannel, color: theme.statusColor, font: theme.statusFont)
                    return PeerStatusStringResult(title, string)
                }
            }
        }
        
    }
    return PeerStatusStringResult(NSAttributedString(), NSAttributedString())
}

func autoremoveLocalized(_ ttl: Int, roundToCeil: Bool = false) -> String {
    var localized: String = ""
     if ttl <= 59 {
        localized = strings().timerSecondsCountable(ttl)
    } else if ttl <= 3599 {
        localized = strings().timerMinutesCountable(ttl / 60)
    } else if ttl <= 86399 {
        localized = strings().timerHoursCountable(ttl / 60 / 60)
    } else if ttl <= 604799 {
        if roundToCeil {
            localized = strings().timerDaysCountable(Int(ceil(Float(ttl) / 60 / 60 / 24)))
        } else {
            localized = strings().timerDaysCountable(ttl / 60 / 60 / 24)
        }
    } else {
        if roundToCeil {
            localized = strings().timerWeeksCountable(Int(ceil(Float(ttl) / 60 / 60 / 24 / 7)))
        } else {
            let weeks = ttl / 60 / 60 / 24 / 7
            if weeks >= 4 {
                localized = strings().timerMonthsCountable(weeks / 4)
            } else {
                localized = strings().timerWeeksCountable(weeks)
            }
        }
    }
    return localized
}

public func shortTimeIntervalString(value: Int32) -> String {
    if value < 60 {
        return strings().messageTimerShortSeconds("\(max(1, value))")
    } else if value < 60 * 60 {
        return strings().messageTimerShortMinutes("\(max(1, value / 60))")
    } else if value < 60 * 60 * 24 {
        return strings().messageTimerShortHours("\(max(1, value / (60 * 60)))")
    } else if value <= 60 * 60 * 24 * 7 {
        return strings().messageTimerShortDays("\(max(1, value / (60 * 60 * 24)))")
    } else {
        let weeks = max(1, value / (60 * 60 * 24 * 7))
        if weeks < 4 {
            return strings().messageTimerShortWeeks("\(weeks)")
        } else {
            return strings().messageTimerShortMonths("\(weeks / 4)")
        }
    }
}


func slowModeTooltipText(_ timeout: Int32) -> String {
    let minutes = timeout / 60
    let seconds = timeout % 60
    return strings().channelSlowModeToolTip(minutes < 10 ? "0\(minutes)" : "\(minutes)", seconds < 10 ? "0\(seconds)" : "\(seconds)")
}
func showSlowModeTimeoutTooltip(_ slowMode: SlowMode, for view: NSView) {
    if let errorText = slowMode.errorText {
        if let validUntil = slowMode.validUntil {
            tooltip(for: view, text: errorText, updateText: { f in
                var timer:SwiftSignalKit.Timer?
                timer = SwiftSignalKit.Timer(timeout: 0.1, repeat: true, completion: {
                    
                    let timeout = (validUntil - Int32(Date().timeIntervalSince1970))
                    
                    var result: Bool = false
                    if timeout > 0 {
                        result = f(slowModeTooltipText(timeout))
                    }
                    if !result {
                        timer?.invalidate()
                        timer = nil
                    }
                    
                }, queue: .mainQueue())
                
                timer?.start()
            })
        } else {
            tooltip(for: view, text: errorText)
        }
        
    }
}

let preCharacter = "`"
let codeCharacter = "```"
func parseTextEntities(_ message:String) -> (String, [MessageTextEntity]) {
    var entities:[MessageTextEntity] = []
    var message = message
   // let regex = Regex("`")
    
    
//    let pattern = "(`([\\w]+)`)"
//    let regex = try! NSRegularExpression(pattern: pattern, options: [])
//    let matches = regex.matches(in: message, options: [], range: NSRange(location: 0, length: message.characters.count))
//
//    for match in matches {
//        for n in 0 ..< match.numberOfRanges {
//            let range = match.rangeAt(n)
//            var bp:Int = 0
//            bp += 1
//        }
//    }
//    
//    let converted = regex.stringByReplacingMatches(in: message, options: .anchored, range: NSRange(location: 0, length: message.characters.count), withTemplate: "$2")
    
//    var currentIndex:String.Index? = nil
//    while true {
//        
//        if let startRange = message.range(of: preCharacter) {
//            if let endRange = message.range(of: preCharacter, options: .caseInsensitive, range: startRange.upperBound ..< message.endIndex, locale: nil)  {
//                
//                let text = message.substring(with: startRange.lowerBound ..< endRange.upperBound)
//                var bp:Int = 0
//                bp += 1
//                entities.append(.init(range: <#T##Range<Int>#>, type: <#T##MessageTextEntityType#>))
//                
//            }
//            //if let endIndex =
//        }
//        break
//    }
    return (message, entities)
    
}

func timeIntervalString( _ value: Int) -> String {
    if value < 60 {
        return strings().timerSecondsCountable(value)
    } else if value < 60 * 60 {
        return strings().timerMinutesCountable(max(1, value / 60))
    } else if value < 60 * 60 * 24 {
        return strings().timerHoursCountable(max(1, value / (60 * 60)))
    } else if value < 60 * 60 * 24 * 7 {
        return strings().timerDaysCountable(max(1, value / (60 * 60 * 24)))
    } else if value < 60 * 60 * 24 * 30 {
        return strings().timerWeeksCountable(max(1, value / (60 * 60 * 24 * 7)))
    } else if value < 60 * 60 * 24 * 360 {
        return strings().timerMonthsCountable(max(1, value / (60 * 60 * 24 * 30)))
    } else {
        return strings().timerYearsCountable(max(1, value / (60 * 60 * 24 * 365)))
    }
}



func timerText(_ durationValue: Int, addminus: Bool = true) -> String {
    
    let duration = abs(durationValue)
    let days = Int(duration) / (3600 * 24)
    let hours = (Int(duration) - (days * 3600 * 24)) / 3600
    let minutes = Int(duration) / 60 % 60
    let seconds = Int(duration) % 60
    
    
    
    var formatted: String
    if days >= 1 {
        formatted = timeIntervalString(duration)
    } else if days != 0 {
        formatted = String(format:"%d:%02i:%02i:%02i", days, hours, minutes, seconds)
    } else if hours != 0 {
        formatted = String(format:"%02i:%02i:%02i", hours, minutes, seconds)
    } else {
        formatted = String(format:"%02i:%02i", minutes, seconds)
    }
    if addminus {
        return durationValue < 0 ? "-" + formatted : formatted
    } else {
        return formatted
    }
}
