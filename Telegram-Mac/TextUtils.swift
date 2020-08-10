//
//  TextUtils.swift
//  TelegramMac
//
//  Created by keepcoder on 04/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import TGUIKit
import SwiftSignalKit

enum MessageTextMediaViewType {
    case emoji
    case text
    case none
}

func pullText(from message:Message, mediaViewType: MessageTextMediaViewType = .emoji, messagesCount: Int = 1) -> NSString {
    var messageText: NSString = message.text.fixed.nsstring
    for media in message.media {
        switch media {
        case _ as TelegramMediaImage:
            
            if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let _ = message.autoremoveAttribute {
                messageText = tr(L10n.chatListServiceDestructingPhoto).nsstring
            } else {
                messageText = L10n.chatListPhotoCountable(messagesCount).nsstring
                if !message.text.isEmpty {
                    switch mediaViewType {
                    case .emoji:
                        messageText = ("🖼 " + message.text.fixed).nsstring
                    case .text:
                        messageText = message.text.fixed.nsstring
                    case .none:
                        break
                    }
                }
            }
        case let dice as TelegramMediaDice:
            messageText = dice.emoji.nsstring
        case let fileMedia as TelegramMediaFile:
            if fileMedia.isStaticSticker || fileMedia.isAnimatedSticker {
                messageText = L10n.chatListSticker(fileMedia.stickerText?.fixed ?? "").nsstring
            } else if fileMedia.isVoice {
                messageText = L10n.chatListVoice.nsstring
            } else if fileMedia.isMusic  {
                messageText = ("🎵 " + fileMedia.musicText.0 + " - " + fileMedia.musicText.1).nsstring
            } else if fileMedia.isInstantVideo {
                messageText = tr(L10n.chatListInstantVideo).nsstring
            } else if fileMedia.isVideo {
                
                if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let _ = message.autoremoveAttribute {
                    messageText = tr(L10n.chatListServiceDestructingVideo).nsstring
                } else {
                    if fileMedia.isAnimated {
                        messageText = L10n.chatListGIF.nsstring
                        if !message.text.fixed.isEmpty {
                             messageText = (L10n.chatListGIF + ", " + message.text.fixed).nsstring
                        }
                    } else {
                        messageText = L10n.chatListVideoCountable(messagesCount).nsstring
                        if !message.text.fixed.isEmpty {
                            switch mediaViewType {
                            case .emoji:
                                messageText = ("📹 " + message.text.fixed).nsstring
                            case .text:
                                messageText = message.text.fixed.nsstring
                            case .none:
                                break
                            }
                        }
                    }
                }
                
                
            } else {
                messageText = fileMedia.fileName?.fixed.nsstring ?? "File"
                if !message.text.isEmpty {
                    switch mediaViewType {
                    case .emoji:
                        messageText = ("📎 " + message.text.fixed).nsstring
                    case .text:
                        messageText = message.text.fixed.nsstring
                    case .none:
                        break
                    }
                }
            }
        case _ as TelegramMediaMap:
            messageText = tr(L10n.chatListMap).nsstring
        case _ as TelegramMediaContact:
            messageText = tr(L10n.chatListContact).nsstring
        case let game as TelegramMediaGame:
            messageText = "🎮 \(game.title)".nsstring
        case let invoice as TelegramMediaInvoice:
            messageText = invoice.title.nsstring
        case let poll as TelegramMediaPoll:
            messageText = "📊 \(poll.text)".nsstring
        case let webpage as TelegramMediaWebpage:
            if case let .Loaded(content) = webpage.content {
                if let _ = content.image {
                    switch mediaViewType {
                    case .emoji:
                        messageText = ("🖼 " + message.text.fixed).nsstring
                    case .text:
                        messageText = message.text.fixed.nsstring
                    case .none:
                        break
                    }
                } else if let file = content.file {
                    if (file.isVideo && !file.isInstantVideo)  {
                        switch mediaViewType {
                        case .emoji:
                            messageText = ("🖼 " + message.text.fixed).nsstring
                        case .text:
                            messageText = message.text.fixed.nsstring
                        case .none:
                            break
                        }
                    } else if file.isGraphicFile {
                        switch mediaViewType {
                        case .emoji:
                            messageText = ("📹 " + message.text.fixed).nsstring
                        case .text:
                            messageText = message.text.fixed.nsstring
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
    return messageText.replacingOccurrences(of: "\n", with: " ").nsstring.replacingOccurrences(of: "\r", with: " ").trimmed.nsstring
    
}

func chatListText(account:Account, for message:Message?, messagesCount: Int = 1, renderedPeer:RenderedPeer? = nil, embeddedState:PeerChatListEmbeddedInterfaceState? = nil, folder: Bool = false, applyUserName: Bool = false) -> NSAttributedString {
    
    if let embeddedState = embeddedState as? ChatEmbeddedInterfaceState {
        let mutableAttributedText = NSMutableAttributedString()
        _ = mutableAttributedText.append(string: L10n.chatListDraft, color: theme.colors.redUI, font: .normal(.text))
        _ = mutableAttributedText.append(string: " \(embeddedState.text.fullTrimmed.replacingOccurrences(of: "\n", with: " "))", color: theme.chatList.grayTextColor, font: .normal(.text))
        mutableAttributedText.setSelected(color: theme.colors.underSelectedColor, range: mutableAttributedText.range)
        return mutableAttributedText
    }
    
    if let renderedPeer = renderedPeer {
        if let peer = renderedPeer.peers[renderedPeer.peerId] as? TelegramSecretChat {
            let subAttr = NSMutableAttributedString()
            switch peer.embeddedState {
            case .terminated:
                _ = subAttr.append(string: L10n.chatListSecretChatTerminated, color: theme.chatList.grayTextColor, font: .normal(.text))
            case .handshake:
            _ = subAttr.append(string: L10n.chatListSecretChatExKeys, color: theme.chatList.grayTextColor, font: .normal(.text))
            case .active:
                if message == nil {
                    let title:String = renderedPeer.chatMainPeer?.displayTitle ?? L10n.peerDeletedUser
                    switch peer.role {
                    case .creator:
                        _ = subAttr.append(string: L10n.chatListSecretChatJoined(title), color: theme.chatList.grayTextColor, font: .normal(.text))
                    case .participant:
                        _ = subAttr.append(string: L10n.chatListSecretChatCreated(title), color: theme.chatList.grayTextColor, font: .normal(.text))
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
            _ = attr.append(string: L10n.chatListUnsupportedMessage, color: theme.chatList.grayTextColor, font: .normal(.text))
            attr.setSelected(color: theme.colors.underSelectedColor, range: attr.range)
            return attr
        }
        
        let peer = messageMainPeer(message)
        
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
            
            if folder, let peer = peer {
                _ = attributedText.append(string: peer.displayTitle + "\n", color: theme.chatList.peerTextColor, font: .normal(.text))
            }
            
            if let author = message.author as? TelegramUser, let peer = peer, peer as? TelegramUser == nil, !peer.isChannel, applyUserName {
                var peerText: String = (author.id == account.peerId ? "\(L10n.chatListYou)" : author.displayTitle)
                
                peerText += (folder ? ": " : "\n")
                _ = attributedText.append(string: peerText, color: theme.chatList.peerTextColor, font: .normal(.text))
                _ = attributedText.append(string: messageText as String, color: theme.chatList.grayTextColor, font: .normal(.text))
            } else {
                _ = attributedText.append(string: messageText as String, color: theme.chatList.grayTextColor, font: .normal(.text))
            }
            
            attributedText.setSelected(color: theme.colors.underSelectedColor, range: attributedText.range)
        } else if message.media.first is TelegramMediaAction {
            _ = attributedText.append(string: serviceMessageText(message, account:account), color: theme.chatList.grayTextColor, font: .normal(.text))
            attributedText.setSelected(color: theme.colors.underSelectedColor, range: attributedText.range)
        } else if let media = message.media.first as? TelegramMediaExpiredContent {
            let text:String
            switch media.data {
            case .image:
                text = L10n.serviceMessageExpiredPhoto
            case .file:
                text = L10n.serviceMessageExpiredVideo
            }
            _ = attributedText.append(string: text, color: theme.chatList.grayTextColor, font: .normal(.text))
            attributedText.setSelected(color: theme.colors.underSelectedColor,range: attributedText.range)
        }
        
        return attributedText

    }
    return NSAttributedString()
}

func serviceMessageText(_ message:Message, account:Account, isReplied: Bool = false) -> String {
    
    var authorName:String = ""
    if let displayTitle = message.author?.displayTitle {
        if message.author?.id == account.peerId {
            authorName = tr(L10n.chatServiceYou)
        } else {
            authorName = displayTitle
        }
    }
    
    if let media = message.media.first as? TelegramMediaExpiredContent {
        switch media.data {
        case .image:
            return L10n.chatListPhoto
        case .file:
            return L10n.chatListVideo
        }
    }
   
    
    let authorId:PeerId? = message.author?.id
    
    if let action = message.media.first as? TelegramMediaAction, let peer = messageMainPeer(message) {
        switch action.action {
        case let .addedMembers(peerIds: peerIds):
            if peerIds.first == authorId {
                return L10n.chatServiceGroupAddedSelf(authorName)
            } else {
                return L10n.chatServiceGroupAddedMembers(authorName, peerDebugDisplayTitles(peerIds, message.peers))
            }
        case .phoneNumberRequest:
            return "phone number request"
        case .channelMigratedFromGroup:
            return ""
        case let .groupCreated(title: title):
            if peer.isChannel {
                return L10n.chatServiceChannelCreated
            } else {
                return L10n.chatServiceGroupCreated(authorName, title)
            }
        case .groupMigratedToChannel:
            return ""
        case .historyCleared:
            return ""
        case .historyScreenshot:
            return L10n.chatServiceGroupTookScreenshot(authorName)
        case let .joinedByLink(inviter: peerId):
            if peerId == authorId {
                return L10n.chatServiceGroupJoinedByLink(tr(L10n.chatServiceYou))
            } else {
                return L10n.chatServiceGroupJoinedByLink(authorName)
            }
        case let .messageAutoremoveTimeoutUpdated(seconds):
            if seconds > 0 {
                return L10n.chatServiceSecretChatSetTimer(authorName, autoremoveLocalized(Int(seconds)))
            } else {
                return L10n.chatServiceSecretChatDisabledTimer(authorName)
            }
        case let .photoUpdated(image: image):
            if let image = image {
                let text: String
                if image.videoRepresentations.isEmpty {
                    text = peer.isChannel ? L10n.chatServiceChannelUpdatedPhoto : L10n.chatServiceGroupUpdatedPhoto(authorName)
                } else {
                    text = peer.isChannel ? L10n.chatServiceChannelUpdatedVideo : L10n.chatServiceGroupUpdatedVideo(authorName)
                }
                return text
            } else {
                return peer.isChannel ? L10n.chatServiceChannelRemovedPhoto : L10n.chatServiceGroupRemovedPhoto(authorName)
            }
        case .pinnedMessageUpdated:
            if !isReplied {
                var authorName:String = ""
                if let displayTitle = message.author?.displayTitle {
                    authorName = displayTitle
                    if account.peerId == message.author?.id {
                        authorName = tr(L10n.chatServiceYou)
                    }
                }
                
                var replyMessageText = ""
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                        replyMessageText = pullText(from: message) as String
                    }
                }
                return L10n.chatServiceGroupUpdatedPinnedMessage(authorName, replyMessageText.prefixWithDots(15))
            } else {
                return L10n.chatServicePinnedMessage
            }
            
        case let .removedMembers(peerIds: peerIds):
            if peerIds.first == authorId {
                return L10n.chatServiceGroupRemovedSelf(authorName)
            } else {
                return L10n.chatServiceGroupRemovedMembers(authorName, peerCompactDisplayTitles(peerIds, message.peers))
            }

        case let .titleUpdated(title: title):
            return peer.isChannel ? L10n.chatServiceChannelUpdatedTitle(title) : L10n.chatServiceGroupUpdatedTitle(authorName, title)
        case let .phoneCall(callId: _, discardReason: reason, duration: duration, isVideo):
            
            if let duration = duration, duration > 0 {
                if message.author?.id == account.peerId {
                    return isVideo ? L10n.chatListServiceVideoCallOutgoing(.stringForShortCallDurationSeconds(for: duration)) : L10n.chatListServiceCallOutgoing(.stringForShortCallDurationSeconds(for: duration))
                } else {
                    return isVideo ? L10n.chatListServiceVideoCallIncoming(.stringForShortCallDurationSeconds(for: duration)) : L10n.chatListServiceCallIncoming(.stringForShortCallDurationSeconds(for: duration))
                }
            }
            
            if let reason = reason {
                let outgoing = !message.flags.contains(.Incoming)
                
                switch reason {
                case .busy:
                    return outgoing ? (isVideo ? L10n.chatListServiceVideoCallCancelled : L10n.chatListServiceCallCancelled) : (isVideo ? L10n.chatListServiceVideoCallMissed : L10n.chatListServiceCallMissed)
                case .disconnect:
                    return isVideo ? L10n.chatListServiceVideoCallMissed : L10n.chatListServiceCallMissed
                case .hangup:
                    return outgoing ? (isVideo ? L10n.chatListServiceVideoCallCancelled : L10n.chatListServiceCallCancelled) : (isVideo ? L10n.chatListServiceVideoCallMissed : L10n.chatListServiceCallMissed)
                case .missed:
                    return outgoing ? (isVideo ? L10n.chatListServiceVideoCallCancelled : L10n.chatListServiceCallCancelled) : (isVideo ? L10n.chatListServiceVideoCallMissed : L10n.chatListServiceCallMissed)
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
            var text = L10n.chatListServiceGameScored1Countable(Int(score), gameName)
            if let peer = messageMainPeer(message) {
                if peer.isGroup || peer.isSupergroup {
                    text = (message.author?.compactDisplayTitle ?? "") + " " + text
                }
            }
            return text
        case let .paymentSent(currency, totalAmount):
            return L10n.chatListServicePaymentSent(TGCurrencyFormatter.shared().formatAmount(totalAmount, currency: currency))
        case .unknown:
            break
        case .customText(let text, _):
            return text
        case let .botDomainAccessGranted(domain):
            return L10n.chatServiceBotPermissionAllowed(domain)
        case let .botSentSecureValues(types):
            let permissions = types.map({$0.rawValue}).joined(separator: ", ")
            return L10n.chatServiceSecureIdAccessGranted(peer.displayTitle, permissions)
        case .peerJoined:
            return L10n.chatServicePeerJoinedTelegram(authorName)
        }
    }
    
    return tr(L10n.chatMessageUnsupported)
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
        return PeerStatusStringResult(title, self.status, presence: presence)
    }
    
    func withUpdatedStatus(_ status: String) -> PeerStatusStringResult {
        let status = self.status.mutableCopy() as! NSMutableAttributedString
        status.replaceCharacters(in: status.range, with: status)
        return PeerStatusStringResult(self.title, status, presence: presence)
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
                return PeerStatusStringResult(title, .initialize(string: L10n.peerServiceNotifications,  color: theme.statusColor, font: theme.statusFont))
            }
            if user.flags.contains(.isSupport) {
                return PeerStatusStringResult(title, .initialize(string: L10n.presenceSupport,  color: theme.statusColor, font: theme.statusFont))
            } else if let _ = user.botInfo {
                return PeerStatusStringResult(title, .initialize(string: L10n.presenceBot,  color: theme.statusColor, font: theme.statusFont))
            } else if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                let (string, activity, _) = stringAndActivityForUserPresence(presence, timeDifference: context.timeDifference, relativeTo: Int32(timestamp), expanded: expanded)
                
                return PeerStatusStringResult(title, .initialize(string: string, color: activity && theme.highlightIfActivity ? theme.highlightColor : theme.statusColor, font: theme.statusFont), presence: presence)

            } else {
                return PeerStatusStringResult(title, .initialize(string: L10n.peerStatusRecently, color: theme.statusColor, font: theme.statusFont))
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
                
                let _ = string.append(string: "\(L10n.peerStatusMemberCountable(group.participantCount).replacingOccurrences(of: "\(group.participantCount)", with: group.participantCount.formattedWithSeparator)), ", color: theme.statusColor, font: theme.statusFont)
                let _ = string.append(string: L10n.peerStatusMemberOnlineCountable(onlineCount), color: theme.statusColor, font: theme.statusFont)
                return PeerStatusStringResult(title, string)
            } else {
                let string = NSAttributedString.initialize(string: L10n.peerStatusMemberCountable(group.participantCount).replacingOccurrences(of: "\(group.participantCount)", with: group.participantCount.formattedWithSeparator), color: theme.statusColor, font: theme.statusFont)
                return PeerStatusStringResult(title, string)
            }
        } else if let channel = peer as? TelegramChannel {
            
            let onlineCount: Int = Int(onlineMemberCount ?? 0)
            if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
            
                
                let membersLocalized: String
                if channel.isChannel {
                    membersLocalized = L10n.peerStatusSubscribersCountable(Int(memberCount))
                } else {
                    membersLocalized = L10n.peerStatusMemberCountable(Int(memberCount))
                }
                
                let countString = membersLocalized.replacingOccurrences(of: "\(memberCount)", with: memberCount.formattedWithSeparator)
                if onlineCount > 1, case .group = channel.info {
                    let string = NSMutableAttributedString()
                    let _ = string.append(string: "\(countString), ", color: theme.statusColor, font: theme.statusFont)
                    let _ = string.append(string: L10n.peerStatusMemberOnlineCountable(onlineCount), color: theme.statusColor, font: theme.statusFont)
                    return PeerStatusStringResult(title, string)
                } else {
                    
                    let string = NSAttributedString.initialize(string: countString, color: theme.statusColor, font: theme.statusFont)
                    return PeerStatusStringResult(title, string)
                }
                
            } else {
                switch channel.info {
                case .group:
                    let string = NSAttributedString.initialize(string: L10n.peerStatusGroup, color: theme.statusColor, font: theme.statusFont)
                    return PeerStatusStringResult(title, string)

                case .broadcast:
                    let string = NSAttributedString.initialize(string: L10n.peerStatusChannel, color: theme.statusColor, font: theme.statusFont)
                    return PeerStatusStringResult(title, string)
                }
            }
        }
        
    }
    return PeerStatusStringResult(NSAttributedString(), NSAttributedString())
}

 func autoremoveLocalized(_ ttl: Int) -> String {
    var localized: String = ""
     if ttl <= 59 {
        localized = L10n.timerSecondsCountable(ttl)
    } else if ttl <= 3599 {
        localized = L10n.timerMinutesCountable(ttl / 60)
    } else if ttl <= 86399 {
        localized = L10n.timerHoursCountable(ttl / 60 / 60)
    } else if ttl <= 604799 {
        localized = L10n.timerDaysCountable(ttl / 60 / 60 / 24)
    } else {
        localized = L10n.timerWeeksCountable(ttl / 60 / 60 / 24 / 7)
    }
    return localized
}

public func shortTimeIntervalString(value: Int32) -> String {
    if value < 60 {
        return L10n.messageTimerShortSeconds("\(max(1, value))")
    } else if value < 60 * 60 {
        return L10n.messageTimerShortMinutes("\(max(1, value / 60))")
    } else if value < 60 * 60 * 24 {
        return L10n.messageTimerShortHours("\(max(1, value / (60 * 60)))")
    } else if value < 60 * 60 * 24 * 7 {
        return L10n.messageTimerShortDays("\(max(1, value / (60 * 60 * 24)))")
    } else {
        return L10n.messageTimerShortWeeks("\(max(1, value / (60 * 60 * 24 * 7)))")
    }
}


func slowModeTooltipText(_ timeout: Int32) -> String {
    let minutes = timeout / 60
    let seconds = timeout % 60
    return L10n.channelSlowModeToolTip(minutes < 10 ? "0\(minutes)" : "\(minutes)", seconds < 10 ? "0\(seconds)" : "\(seconds)")
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
        return tr(L10n.timerSecondsCountable(value))
    } else if value < 60 * 60 {
        return tr(L10n.timerMinutesCountable(max(1, value / 60)))
    } else if value < 60 * 60 * 24 {
        return tr(L10n.timerHoursCountable(max(1, value / (60 * 60))))
    } else if value < 60 * 60 * 24 * 7 {
        return tr(L10n.timerDaysCountable(max(1, value / (60 * 60 * 24))))
    } else if value < 60 * 60 * 24 * 30 {
        return tr(L10n.timerWeeksCountable(max(1, value / (60 * 60 * 24 * 7))))
    } else if value < 60 * 60 * 24 * 360 {
        return tr(L10n.timerMonthsCountable(max(1, value / (60 * 60 * 24 * 30))))
    } else {
        return tr(L10n.timerYearsCountable(max(1, value / (60 * 60 * 24 * 365))))
    }
}

