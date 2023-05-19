
//
//  CoreExtension.swift
//  Telegram-Mac
//
//  Created by keepcoder on 06/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import Localization
import Postbox
import SwiftSignalKit
import TGUIKit
import ApiCredentials
import MtProtoKit
import TGPassportMRZ
import InAppSettings
import ColorPalette
import ThemeSettings
import Accelerate
import TGModernGrowingTextView

extension RenderedChannelParticipant {
    func withUpdatedBannedRights(_ info: ChannelParticipantBannedInfo) -> RenderedChannelParticipant {
        let updated: ChannelParticipant
        switch participant {
        case let.member(id, invitedAt, adminInfo, _, rank):
            updated = ChannelParticipant.member(id: id, invitedAt: invitedAt, adminInfo: adminInfo, banInfo: info, rank: rank)
        case let .creator(id, info, rank):
            updated = ChannelParticipant.creator(id: id, adminInfo: info, rank: rank)
        }
        return RenderedChannelParticipant(participant: updated, peer: peer, presences: presences)
    }
    
    func withUpdatedAdditionalPeers(_ additional:[PeerId:Peer]) -> RenderedChannelParticipant {
        return RenderedChannelParticipant(participant: participant, peer: peer, peers: peers + additional, presences: presences)
    }
    
    var isCreator: Bool {
        return participant.isCreator
    }
}

extension ChannelParticipant {
    var isCreator:Bool {
        switch self {
        case .creator:
            return true
        default:
            return false
        }
    }
}

extension TelegramChatAdminRightsFlags {
    var localizedString:String {
        switch self {
        case TelegramChatAdminRightsFlags.canAddAdmins:
            return strings().eventLogServicePromoteAddNewAdmins
        case TelegramChatAdminRightsFlags.canBanUsers:
            return strings().eventLogServicePromoteBanUsers
        case TelegramChatAdminRightsFlags.canChangeInfo:
            return strings().eventLogServicePromoteChangeInfo
        case TelegramChatAdminRightsFlags.canInviteUsers:
            return strings().eventLogServicePromoteAddUsers
        case TelegramChatAdminRightsFlags.canDeleteMessages:
            return strings().eventLogServicePromoteDeleteMessages
        case TelegramChatAdminRightsFlags.canEditMessages:
            return strings().eventLogServicePromoteEditMessages
        case TelegramChatAdminRightsFlags.canPinMessages:
            return strings().eventLogServicePromotePinMessages
        case TelegramChatAdminRightsFlags.canPostMessages:
            return strings().eventLogServicePromotePostMessages
        case TelegramChatAdminRightsFlags.canBeAnonymous:
            return strings().eventLogServicePromoteRemainAnonymous
        case TelegramChatAdminRightsFlags.canManageCalls:
            return strings().channelAdminLogCanManageCalls
        case TelegramChatAdminRightsFlags.canManageTopics:
            return strings().channelAdminLogCanManageTopics
        default:
            return "Undefined Promotion"
        }
    }
}

extension TelegramChatBannedRightsFlags {
    var localizedString:String {
        switch self {
        case TelegramChatBannedRightsFlags.banSendGifs:
            return strings().eventLogServiceDemoteSendGifs
        case TelegramChatBannedRightsFlags.banPinMessages:
            return strings().eventLogServiceDemotePinMessages
        case TelegramChatBannedRightsFlags.banAddMembers:
            return strings().eventLogServiceDemoteAddMembers
        case TelegramChatBannedRightsFlags.banSendPolls:
            return strings().eventLogServiceDemotePostPolls
        case TelegramChatBannedRightsFlags.banEmbedLinks:
            return strings().eventLogServiceDemoteEmbedLinks
        case TelegramChatBannedRightsFlags.banReadMessages:
            return ""
        case TelegramChatBannedRightsFlags.banSendGames:
            return strings().eventLogServiceDemoteEmbedLinks
        case TelegramChatBannedRightsFlags.banSendInline:
            return strings().eventLogServiceDemoteSendInline
        case TelegramChatBannedRightsFlags.banSendMedia:
            return strings().eventLogServiceDemoteSendMedia
        case TelegramChatBannedRightsFlags.banSendMessages:
            return strings().eventLogServiceDemoteSendMessages
        case TelegramChatBannedRightsFlags.banSendStickers:
            return strings().eventLogServiceDemoteSendStickers
        case TelegramChatBannedRightsFlags.banChangeInfo:
            return strings().eventLogServiceDemoteChangeInfo
        default:
            return ""
        }
    }
}
/*
 public struct TelegramChatBannedRightsFlags: OptionSet {
 public var rawValue: Int32
 
 public init(rawValue: Int32) {
 self.rawValue = rawValue
 }
 
 public init() {
 self.rawValue = 0
 }
 
 public static let banReadMessages = TelegramChatBannedRightsFlags(rawValue: 1 << 0)
 public static let banSendMessages = TelegramChatBannedRightsFlags(rawValue: 1 << 1)
 public static let banSendMedia = TelegramChatBannedRightsFlags(rawValue: 1 << 2)
 public static let banSendStickers = TelegramChatBannedRightsFlags(rawValue: 1 << 3)
 public static let banSendGifs = TelegramChatBannedRightsFlags(rawValue: 1 << 4)
 public static let banSendGames = TelegramChatBannedRightsFlags(rawValue: 1 << 5)
 public static let banSendInline = TelegramChatBannedRightsFlags(rawValue: 1 << 6)
 public static let banEmbedLinks = TelegramChatBannedRightsFlags(rawValue: 1 << 7)
 }
 */

extension TelegramChatBannedRights {
    var formattedUntilDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        //formatter.timeZone = NSTimeZone.local
        
        formatter.timeZone = NSTimeZone.local
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(untilDate)))
    }
}


func permissionText(from peer: Peer, for flags: TelegramChatBannedRightsFlags) -> String? {
    let bannedPermission: (Int32, Bool)?
    if let channel = peer as? TelegramChannel {
        bannedPermission = channel.hasBannedPermission(flags)
    } else if let group = peer as? TelegramGroup {
        if group.hasBannedPermission(flags) {
            bannedPermission = (Int32.max, false)
        } else {
            bannedPermission = nil
        }
    } else {
        bannedPermission = nil
    }
    
    if let (untilDate, personal) = bannedPermission {
        
        switch flags {
        case .banSendMessages:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendMessagesUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendMessagesForever
            } else {
                return strings().channelPersmissionDeniedSendMessagesDefaultRestrictedText
            }
        case .banSendStickers:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendStickersUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendStickersForever
            } else {
                return strings().channelPersmissionDeniedSendStickersDefaultRestrictedText
            }
        case .banSendGifs:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendGifsUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendGifsForever
            } else {
                return strings().channelPersmissionDeniedSendGifsDefaultRestrictedText
            }
        case .banSendMedia:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendMediaUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendMediaForever
            } else {
                return strings().channelPersmissionDeniedSendMediaDefaultRestrictedText
            }
        case .banSendPolls:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendPollUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendPollForever
            } else {
                return strings().channelPersmissionDeniedSendPollDefaultRestrictedText
            }
        case .banSendInline:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendInlineUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendInlineForever
            } else {
                return strings().channelPersmissionDeniedSendInlineDefaultRestrictedText
            }
        default:
            return nil
        }
        
        
    }
    
    return nil
}

extension RenderedPeer {
    convenience init(_ foundPeer: FoundPeer) {
        self.init(peerId: foundPeer.peer.id, peers: SimpleDictionary([foundPeer.peer.id : foundPeer.peer]), associatedMedia: [:])
    }
}

extension TelegramMediaFile {
    var videoSize:NSSize {
        for attr in attributes {
            if case let .Video(_,size, _) = attr {
                return size.size
            }
        }
        return NSZeroSize
    }
    
    var isStreamable: Bool {
        for attr in attributes {
            if case let .Video(_, _, flags) = attr {
                return flags.contains(.supportsStreaming)
            }
        }
        return true
    }
    
//    var streaming: MediaPlayerStreaming {
//        for attr in attributes {
//            if case let .Video(_, _, flags) = attr {
//                if flags.contains(.supportsStreaming) {
//                    return .earlierStart
//                } else {
//                    return .none
//                }
//            }
//        }
//        return .none
//    }
    
    
    var imageSize:NSSize {
        for attr in attributes {
            if case let .ImageSize(size) = attr {
                return size.size
            }
        }
        return NSZeroSize
    }
    
    var videoDuration:Int {
        for attr in attributes {
            if case let .Video(duration,_, _) = attr {
                return duration
            }
        }
        return 0
    }
    
    var isTheme: Bool {
        return mimeType == "application/x-tgtheme-macos"
    }
    
    func withUpdatedResource(_ resource: TelegramMediaResource) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes)
    }
    
    func withUpdatedFileId(_ fileId: MediaId) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: fileId, partialReference: self.partialReference, resource: self.resource, previewRepresentations: self.previewRepresentations, videoThumbnails: self.videoThumbnails, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes)
    }
}

extension ChatContextResult {
    var maybeId:Int64 {
        var t:String = ""
        var d:String = ""
        if let title = title {
            t = title
        }
        if let description = description {
            d = description
        }
        let maybe = id + type + t + d
        return Int64(maybe.hash)
    }
}


extension TelegramMediaFile {
    var elapsedSize: Int64 {
        if let size = size {
            return size
        }
        if let resource = resource as? LocalFileReferenceMediaResource, let size = resource.size {
            return Int64(size)
        }
        return 0
    }
}

extension Media {
    var isInteractiveMedia: Bool {
        if self is TelegramMediaImage {
            return true
        } else if let file = self as? TelegramMediaFile {
            return (file.isVideo && !file.isWebm) || (file.isAnimated && !file.mimeType.lowercased().hasSuffix("gif") && !file.isWebm)
        } else if let map = self as? TelegramMediaMap {
            return map.venue == nil
        } else if self is TelegramMediaDice {
            return false
        }
        return false
    }
    
    var canHaveCaption: Bool {
        if supposeToBeSticker {
            return false
        }
        if self is TelegramMediaImage {
            return true
        } else if let file = self as? TelegramMediaFile {
            if file.isInstantVideo || file.isAnimatedSticker || file.isStaticSticker || file.isVoice {
                return false
            } else {
                return true
            }
        }
        return false
    }
}

enum ChatListIndexRequest :Equatable {
    case Initial(Int, TableScrollState?)
    case Index(EngineChatList.Item.Index, TableScrollState?)
}


public extension PeerView {
    var isMuted:Bool {
        if let settings = self.notificationSettings as? TelegramPeerNotificationSettings {
            switch settings.muteState {
            case let .muted(until):
                return until > Int32(Date().timeIntervalSince1970)
            case .unmuted:
                return false
            case .default:
                return false
            }
        } else {
            return false
        }
    }
}

public extension TelegramPeerNotificationSettings {
    var isMuted:Bool {
        switch self.muteState {
        case let .muted(until):
            return until > Int32(Date().timeIntervalSince1970)
        case .unmuted:
            return false
        case .default:
            return false
        }
    }
}


public extension TelegramMediaFile {
    var stickerText:String? {
        for attr in attributes {
            if case let .Sticker(displayText, _, _) = attr {
                return displayText
            }
        }
        return nil
    }
    var customEmojiText:String? {
        for attr in attributes {
            if case let .CustomEmoji(_, alt, _) = attr {
                return alt
            }
        }
        return nil
    }
    
    var stickerReference:StickerPackReference? {
        for attr in attributes {
            if case let .Sticker(_, reference, _) = attr {
                return reference
            }
        }
        return nil
    }
    var emojiReference:StickerPackReference? {
        for attr in attributes {
            if case let .CustomEmoji(_, _, reference) = attr {
                return reference
            }
        }
        return nil
    }
    
    var maskData: StickerMaskCoords? {
        for attr in attributes {
            if case let .Sticker(_, _, mask) = attr {
                return mask
            }
        }
        return nil
    }
    
    var isEmojiAnimatedSticker: Bool {
        if let fileName = fileName {
            return fileName.hasPrefix("telegram-animoji") && fileName.hasSuffix("tgs") && isSticker
        }
        return false
    }
    
    var animatedEmojiFitzModifier: EmojiFitzModifier? {
        if isEmojiAnimatedSticker, let fitz = self.stickerText?.basicEmoji.1 {
            return EmojiFitzModifier(emoji: fitz)
        } else {
            return nil
        }
    }
    
    
    
    var musicText:(String,String) {
        
        var audioTitle:String?
        var audioPerformer:String?
        
        let file = self
        for attribute in file.attributes {
            if case let .Audio(_, _, title, performer, _) = attribute {
                audioTitle = title
                audioPerformer = performer
                break
            }
        }
        
        if let audioTitle = audioTitle, let audioPerformer = audioPerformer {
            if audioTitle.isEmpty && audioPerformer.isEmpty {
                return (file.fileName ?? "", "")
            } else {
                return (audioTitle, audioPerformer)
            }
        } else {
            return (file.fileName ?? "", "")
        }

    }
}


public extension MessageHistoryView {
    func index(for messageId: MessageId) -> Int? {
        for i in 0 ..< entries.count {
            if entries[i].index.id == messageId {
                return i
            }
        }
        return nil
    }
    
}

extension MessageReaction.Reaction {
    func toUpdate(_ file: TelegramMediaFile? = nil) -> UpdateMessageReaction {
        switch self {
        case let .custom(fileId):
            return .custom(fileId: fileId, file: file)
        case let .builtin(emoji):
            return .builtin(emoji)
        }
    }
}


public extension Message {
    var replyMarkup:ReplyMarkupMessageAttribute? {
        for attr in attributes {
            if let attr = attr as? ReplyMarkupMessageAttribute {
                return attr
            }
        }
        return nil
    }
    
    var hasExtendedMedia: Bool {
        if let media = self.media.first as? TelegramMediaInvoice {
            return media.extendedMedia != nil
        }
        return false
    }
    
    var consumableContent: ConsumableContentMessageAttribute? {
        for attr in attributes {
            if let attr = attr as? ConsumableContentMessageAttribute {
                return attr
            }
        }
        return nil
    }
    
    var entities:[MessageTextEntity] {
        return self.textEntities?.entities ?? []
    }
    
    var audioTranscription:AudioTranscriptionMessageAttribute? {
        for attr in attributes {
            if let attr = attr as? AudioTranscriptionMessageAttribute {
                return attr
            }
        }
        return nil
    }
    
    var isImported: Bool {
        if let forwardInfo = self.forwardInfo, forwardInfo.flags.contains(.isImported) {
            return true
        }
        return false
    }
    var itHasRestrictedContent: Bool {
        #if APP_STORE || DEBUG
        for attr in attributes {
            if let attr = attr as? RestrictedContentMessageAttribute {
                for rule in attr.rules {
                    if rule.platform == "ios" || rule.platform == "macos" {
                        return true
                    }
                }
            }
        }
        #endif
       
        return false
    }
    func restrictedText(_ contentSettings: ContentSettings) -> String? {
        #if APP_STORE || DEBUG
        for attr in attributes {
            if let attr = attr as? RestrictedContentMessageAttribute {
                for rule in attr.rules {
                    if rule.platform == "ios" || rule.platform == "all" || contentSettings.addContentRestrictionReasons.contains(rule.platform) {
                        if !contentSettings.ignoreContentRestrictionReasons.contains(rule.reason) {
                            return rule.text
                        }
                    }
                }
            }
        }
        #endif
        return nil
    }
    
    var file: TelegramMediaFile? {
        if let file = self.effectiveMedia as? TelegramMediaFile {
            return file
        } else if let webpage = self.effectiveMedia as? TelegramMediaWebpage {
            switch webpage.content {
            case let .Loaded(content):
                return content.file
            default:
                break
            }
        }
        return nil
    }
    
    var textEntities: TextEntitiesMessageAttribute? {
        for attr in attributes {
            if let attr = attr as? TextEntitiesMessageAttribute {
                return attr
            }
        }
        return nil
    }
    
    var isAnonymousMessage: Bool {
        if let author = self.author as? TelegramChannel, sourceReference == nil, self.id.peerId == author.id {
            return true
        } else {
            return false
        }
    }
    
    var threadAttr: ReplyThreadMessageAttribute? {
        for attr in attributes {
            if let attr = attr as? ReplyThreadMessageAttribute {
                return attr
            }
        }
        return nil
    }
    
    var effectiveMedia: Media? {
        if let media = self.media.first as? TelegramMediaInvoice {
            if let extended = media.extendedMedia {
                switch extended {
                case let .full(media):
                    return media
                default:
                    break
                }
            }
        }
        return media.first
    }
    
    func newReactions(with reaction: UpdateMessageReaction) -> [UpdateMessageReaction] {
        var updated:[UpdateMessageReaction] = []
        if let reactions = self.effectiveReactions {
            
            let sorted = reactions.sorted(by: <)
            
            updated = sorted.compactMap { value in
                if value.isSelected {
                    switch value.value {
                    case let .builtin(emoji):
                        return .builtin(emoji)
                    case let .custom(fileId):
                        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                        let file = self.associatedMedia[mediaId] as? TelegramMediaFile
                        return .custom(fileId: fileId, file: file)
                    }
                }
                return nil
            }
            if let index = updated.firstIndex(where: { $0.reaction == reaction.reaction }) {
                updated.remove(at: index)
            } else {
                updated.append(reaction)
            }
        } else {
            updated.append(reaction)
        }
        return updated
    }
    
    func effectiveReactions(_ accountPeerId: PeerId) -> ReactionsMessageAttribute? {
        return mergedMessageReactions(attributes: self.attributes)
    }
    
    func isCrosspostFromChannel(account: Account) -> Bool {
        
        var sourceReference: SourceReferenceMessageAttribute?
        for attribute in self.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute {
                sourceReference = attribute
                break
            }
        }
        
        var isCrosspostFromChannel = false
        if let _ = sourceReference {
            if self.id.peerId != account.peerId {
                isCrosspostFromChannel = true
            }
        }

        return isCrosspostFromChannel
    }
    
    var channelViewsCount: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? ViewCountMessageAttribute {
                return Int32(attribute.count)
            }
        }
        return nil
    }
    
    var isScheduledMessage: Bool {
        return self.id.namespace == Namespaces.Message.ScheduledCloud || self.id.namespace == Namespaces.Message.ScheduledLocal
    }
    
    var wasScheduled: Bool {
        for attr in attributes {
            if attr is OutgoingScheduleInfoMessageAttribute {
                return true
            }
        }
        return self.flags.contains(.WasScheduled)
    }
    
    var isPublicPoll: Bool {
        if let media = self.effectiveMedia as? TelegramMediaPoll {
            return media.publicity == .public
        }
        return false
    }
    
    var isHasInlineKeyboard: Bool {
        return replyMarkup?.flags.contains(.inline) ?? false
    }
    
    func isIncoming(_ account: Account, _ isBubbled: Bool) -> Bool {
        if isBubbled, let peer = coreMessageMainPeer(self), peer.isChannel {
            return true
        }
        
        if id.peerId == account.peerId {
            if let _ = forwardInfo {
                return true
            }
            return false
        }
        return flags.contains(.Incoming)
    }
    
    func chatPeer(_ accountPeerId: PeerId) -> Peer? {
        var _peer: Peer?
        if let _ = adAttribute {
            return author
        }
        for attr in attributes {
            if let source = attr as? SourceReferenceMessageAttribute {
                if let info = forwardInfo {
                    if let peer = peers[source.messageId.peerId], peer is TelegramChannel, accountPeerId != id.peerId, repliesPeerId != id.peerId {
                        _peer = peer
                    } else {
                        _peer = info.author
                    }
                }
                break
            }
        }
        
        if let peer = coreMessageMainPeer(self) as? TelegramChannel, case .broadcast(_) = peer.info {
            _peer = peer
        } else if let author = effectiveAuthor, _peer == nil {
            if author is TelegramSecretChat {
                return coreMessageMainPeer(self)
            } else {
                _peer = author
            }
        }
        return _peer
    }
    
    var replyAttribute: ReplyMessageAttribute? {
        for attr in attributes {
            if let attr = attr as? ReplyMessageAttribute {
                return attr
            }
        }
        return nil
    }
    
    var editedAttribute: EditedMessageAttribute? {
        for attr in attributes {
            if let attr = attr as? EditedMessageAttribute, !attr.isHidden {
                return attr
            }
        }
        return nil
    }
    
    var autoremoveAttribute:AutoremoveTimeoutMessageAttribute? {
        for attr in attributes {
            if let attr = attr as? AutoremoveTimeoutMessageAttribute {
                return attr
            }
        }
        return nil
    }
    
    var hasInlineAttribute: Bool {
        for attribute in attributes {
            if let _ = attribute as? InlineBotMessageAttribute {
                return true
            }
        }
        return false
    }
    
    var inlinePeer:Peer? {
        for attribute in attributes {
            if let attribute = attribute as? InlineBotMessageAttribute, let peerId = attribute.peerId {
                return peers[peerId]
            }
        }
        if let peer = coreMessageMainPeer(self), peer.isBot {
            return peer
        }
        return nil
    }
    
    func withUpdatedStableId(_ stableId:UInt32) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, threadId: threadId, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds, associatedMedia: self.associatedMedia, associatedThreadInfo: self.associatedThreadInfo)
    }
    func withUpdatedId(_ messageId:MessageId) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: messageId, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, threadId: threadId, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds, associatedMedia: self.associatedMedia, associatedThreadInfo: self.associatedThreadInfo)
    }
    
    func withUpdatedGroupingKey(_ groupingKey:Int64?) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, threadId: threadId, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds, associatedMedia: self.associatedMedia, associatedThreadInfo: self.associatedThreadInfo)
    }
    
    func withUpdatedTimestamp(_ timestamp: Int32) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: threadId, timestamp: timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: self.text, attributes: self.attributes, media: self.media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds, associatedMedia: self.associatedMedia, associatedThreadInfo: self.associatedThreadInfo)
    }
    
    
    func withUpdatedText(_ text:String) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, threadId: threadId, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds, associatedMedia: self.associatedMedia, associatedThreadInfo: self.associatedThreadInfo)
    }
    
    func possibilityForwardTo(_ peer:Peer) -> Bool {
        if !peer.canSendMessage(false) {
            return false
        } else if let peer = peer as? TelegramChannel {
            if let media = media.first, !(media is TelegramMediaWebpage) {
                if let media = media as? TelegramMediaFile {
                    if media.isStaticSticker {
                        return !peer.hasBannedRights(.banSendStickers)
                    } else if media.isVideo && media.isAnimated {
                        return !peer.hasBannedRights(.banSendGifs)
                    }
                }
                return !peer.hasBannedRights(.banSendMedia)
            }
        }
        return true
    }
    
    convenience init(_ media: Media, stableId: UInt32, messageId: MessageId) {
        self.init(stableId: stableId, stableVersion: 0, id: messageId, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [media], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil)
    }
}



extension ChatLocation : Hashable {

    func hash(into hasher: inout Hasher) {
       
    }
   
}

extension AvailableReactions {
    var enabled: [AvailableReactions.Reaction] {
        return self.reactions.filter { $0.isEnabled }
    }
}

extension SuggestedLocalizationInfo {
    func localizedKey(_ key:String) -> String {
        for entry in extractedEntries {
            switch entry {
            case let.string(_key, _value):
                if _key == key {
                    return _value
                }
            default:
                break
            }
        }
        return NSLocalizedString(key, comment: "")
    }
}

public extension MessageId {
    var string: String  {
        return "_id_\(id)_\(peerId.id._internalGetInt64Value())"
    }
}


public extension ReplyMarkupMessageAttribute {
    var hasButtons:Bool {
        return !self.rows.isEmpty
    }
}

fileprivate let edit_limit_time:Int32 = 48*60*60

func canDeleteMessage(_ message:Message, account:Account, mode: ChatMode) -> Bool {
    
    if mode.threadId == message.id {
        return false
    }
    if message.adAttribute != nil {
        return false
    }
    
    if let channel = message.peers[message.id.peerId] as? TelegramChannel {
        if case .broadcast = channel.info {
            if !message.flags.contains(.Incoming) {
                return channel.hasPermission(.sendMessages)
            }
            return channel.hasPermission(.deleteAllMessages)
        }
        return channel.hasPermission(.deleteAllMessages) || !message.flags.contains(.Incoming)
    } else if message.peers[message.id.peerId] is TelegramSecretChat {
        return true
    } else {
        return true
    }
}

func uniquePeers(from peers:[Peer], defaultExculde:[PeerId] = []) -> [Peer] {
    var excludePeerIds:[PeerId:PeerId] = [:]
    for peerId in defaultExculde {
        excludePeerIds[peerId] = peerId
    }
    return peers.filter { peer -> Bool in
        let first = excludePeerIds[peer.id] == nil
        excludePeerIds[peer.id] = peer.id
        return first
    }
}

func canForwardMessage(_ message:Message, chatInteraction: ChatInteraction) -> Bool {
        
    if message.peers[message.id.peerId] is TelegramSecretChat {
        return false
    }
    
    if message.flags.contains(.Failed) || message.flags.contains(.Unsent) {
        return false
    }
    if message.isScheduledMessage {
        return false
    }
    if message.adAttribute != nil {
        return false
    }
    
    if message.effectiveMedia is TelegramMediaAction {
        return false
    }
    
    if let peer = message.peers[message.id.peerId] as? TelegramGroup {
        if peer.flags.contains(.copyProtectionEnabled) {
            return false
        }
    }
    if let peer = message.peers[message.id.peerId] as? TelegramChannel {
        if peer.flags.contains(.copyProtectionEnabled) {
            return false
        }
    }
    
    if let peer = message.peers[message.id.peerId] as? TelegramUser {
        if peer.isUser, let timer = message.autoremoveAttribute {
            if !chatInteraction.hasSetDestructiveTimer {
                return false
            } else if timer.timeout <= 60 {
                return false;
            }
        }
    }
    
    return true
}

public struct ChatAvailableMessageActionOptions: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let deleteLocally = ChatAvailableMessageActionOptions(rawValue: 1 << 0)
    public static let deleteGlobally = ChatAvailableMessageActionOptions(rawValue: 1 << 1)
    public static let unsendPersonal = ChatAvailableMessageActionOptions(rawValue: 1 << 7)
}



func canDeleteForEveryoneMessage(_ message:Message, context: AccountContext) -> Bool {
    if message.peers[message.id.peerId] is TelegramChannel || message.peers[message.id.peerId] is TelegramSecretChat {
        return false
    } else if message.peers[message.id.peerId] is TelegramUser || message.peers[message.id.peerId] is TelegramGroup {
        if message.id.peerId == repliesPeerId {
            return false
        }
        if context.limitConfiguration.canRemoveIncomingMessagesInPrivateChats && message.peers[message.id.peerId] is TelegramUser {
            
            if message.effectiveMedia is TelegramMediaDice, message.peers[message.id.peerId] is TelegramUser {
                if Int(message.timestamp) + 24 * 60 * 60 > context.timestamp {
                    return false
                }
            }
            
            return true
        }
        if let peer = message.peers[message.id.peerId] as? TelegramGroup {
            switch peer.role {
            case .creator, .admin:
                return true
            default:
                if Int(context.limitConfiguration.maxMessageEditingInterval) + Int(message.timestamp) > Int(Date().timeIntervalSince1970) {
                    if context.account.peerId == message.effectiveAuthor?.id {
                        return !(message.effectiveMedia is TelegramMediaAction)
                    }
                }
                return false
            }
            
        } else if Int(context.limitConfiguration.maxMessageEditingInterval) + Int(message.timestamp) > Int(Date().timeIntervalSince1970) {
            if context.account.peerId == message.author?.id {
                return !(message.effectiveMedia is TelegramMediaAction)
            }
        }
    }
    return false
}

func mustDeleteForEveryoneMessage(_ message:Message) -> Bool {
    if message.peers[message.id.peerId] is TelegramChannel || message.peers[message.id.peerId] is TelegramSecretChat {
        return true
    }
    return false
}

func canReplyMessage(_ message: Message, peerId: PeerId, mode: ChatMode, threadData: MessageHistoryThreadData? = nil) -> Bool {
    if let peer = coreMessageMainPeer(message) {
        if message.isScheduledMessage {
            return false
        }
        if peerId == message.id.peerId, !message.flags.contains(.Unsent) && !message.flags.contains(.Failed) && (message.id.namespace != Namespaces.Message.Local || message.id.peerId.namespace == Namespaces.Peer.SecretChat) {
            
            switch mode {
            case .history:
                return peer.canSendMessage(false, threadData: threadData)
            case .scheduled:
                return false
            case let .thread(data, mode):
                switch mode {
                case .comments:
                    if message.id == data.messageId {
                        return false
                    }
                    return peer.canSendMessage(true, threadData: threadData)
                case .replies:
                    return peer.canSendMessage(true, threadData: threadData)
                case .topic:
                    return peer.canSendMessage(true, threadData: threadData)
                }
            case .pinned:
                return false
            }
        }
    }
    return false
}

func canEditMessage(_ message:Message, chatInteraction: ChatInteraction, context: AccountContext, ignorePoll: Bool = false) -> Bool {
    if message.forwardInfo != nil {
        return false
    }
    
    if message.flags.contains(.Unsent) || message.flags.contains(.Failed) || message.id.namespace == Namespaces.Message.Local {
        return false
    }
    
    if message.peers[message.id.peerId] is TelegramSecretChat {
        return false
    }
    
    if let media = message.effectiveMedia {
        if let file = media as? TelegramMediaFile {
            if file.isStaticSticker || (file.isAnimatedSticker && !file.isEmojiAnimatedSticker) {
                return false
            }
            if file.isInstantVideo {
                return false
            }
//            if file.isVoice {
//                return false
//            }
        }
        if media is TelegramMediaContact {
            return false
        }
        if media is TelegramMediaAction {
            return false
        }
        if media is TelegramMediaMap {
            return false
        }
        if media is TelegramMediaPoll, !ignorePoll {
            return false
        }
        if media is TelegramMediaDice {
            return false
        }
    }
    
    for attr in message.attributes {
        if attr is InlineBotMessageAttribute {
            return false
        } else if attr is AutoremoveTimeoutMessageAttribute {
            if !chatInteraction.hasSetDestructiveTimer {
                return false
            }
        }
    }
    
    var timeInCondition = Int(message.timestamp) + Int(context.limitConfiguration.maxMessageEditingInterval) > context.account.network.getApproximateRemoteTimestamp()
    
    if let peer = coreMessageMainPeer(message) as? TelegramChannel {
        if case .broadcast = peer.info {
            if message.isScheduledMessage {
                return peer.hasPermission(.sendMessages) || peer.hasPermission(.editAllMessages)
            }
            if peer.hasPermission(.pinMessages) {
                timeInCondition = true
            }
            if peer.hasPermission(.editAllMessages) {
                return timeInCondition
            } else if peer.hasPermission(.sendMessages) {
                return timeInCondition && message.author?.id == chatInteraction.context.peerId
            }
            return false
        } else if case .group = peer.info {
            if !message.flags.contains(.Incoming) {
                if peer.hasPermission(.pinMessages) {
                    return true
                }
                return timeInCondition
            }
        }
    }
    
    if message.id.peerId == context.account.peerId {
        return true
    }
    
    
    if message.flags.contains(.Incoming) {
        return false
    }
    
    
    if Int(message.timestamp) + Int(context.limitConfiguration.maxMessageEditingInterval) < context.account.network.getApproximateRemoteTimestamp() {
        return false
    }
    
    
    
    return !message.flags.contains(.Unsent) && !message.flags.contains(.Failed)
}




func canPinMessage(_ message:Message, for peer:Peer, account:Account) -> Bool {
    return false
}

func canReportMessage(_ message: Message, _ account: Account) -> Bool {
    if message.isScheduledMessage || message.flags.contains(.Failed) || message.flags.contains(.Sending) {
        return false
    }
    if let peer = coreMessageMainPeer(message), message.author?.id != account.peerId {
        return peer.isChannel || peer.isGroup || peer.isSupergroup || (message.chatPeer(account.peerId)?.isBot == true)
    } else {
        return false
    }
}


func mustManageDeleteMessages(_ messages:[Message], for peer:Peer, account: Account) -> Bool {
    
    if let peer = peer as? TelegramChannel, peer.isSupergroup, peer.hasPermission(.deleteAllMessages) {
        let peerId:PeerId? = messages[0].author?.id
        if account.peerId != peerId {
            for message in messages {
                if peerId != message.author?.id || !message.flags.contains(.Incoming) {
                    return false
                }
            }
            return true
        }
    }
    
    return false
}

extension Media {
    var isGraphicFile:Bool {
        if let media = self as? TelegramMediaFile {
            return media.mimeType.hasPrefix("image") && (media.mimeType.contains("png") || media.mimeType.contains("jpg") || media.mimeType.contains("jpeg") || media.mimeType.contains("tiff") || media.mimeType.contains("heic"))
        }
        return false
    }
    
    var isWebm: Bool {
        if let media = self as? TelegramMediaFile {
            return media.mimeType == "video/webm"
        }
        return false
    }
    
    var probablySticker: Bool {
        guard let file = self as? TelegramMediaFile else {
            return false
        }
        if file.isAnimatedSticker {
            return true
        }
        if file.isStaticSticker {
            return true
        }
        if file.isVideoSticker {
            return true
        }
        if file.mimeType == "image/webp" {
            return true
        }
        return false
    }
    
    var isVideoFile:Bool {
        if let media = self as? TelegramMediaFile {
            return media.mimeType.hasPrefix("video/mp4") || media.mimeType.hasPrefix("video/mov") || media.mimeType.hasPrefix("video/avi")
        }
        return false
    }
    var isMusicFile: Bool {
        if let media = self as? TelegramMediaFile {
            for attr in media.attributes {
                switch attr {
                case let .Audio(isVoice, _, _, _, _):
                    return !isVoice
                default:
                    return false
                }
            }
        }
        return false
    }
    
    var supposeToBeSticker:Bool {
        if let media = self as? TelegramMediaFile {
            if media.mimeType.hasPrefix("image/webp") {
                return true
            }
        }
        return false
    }
}

extension AddressNameFormatError {
    var description:String {
        switch self {
        case .startsWithUnderscore:
            return strings().errorUsernameUnderscopeStart
        case .endsWithUnderscore:
            return strings().errorUsernameUnderscopeEnd
        case .startsWithDigit:
            return strings().errorUsernameNumberStart
        case .invalidCharacters:
            return strings().errorUsernameInvalid
        case .tooShort:
            return strings().errorUsernameMinimumLength
        }
    }
}

extension AddressNameAvailability {

    func description(for username: String) -> String {
        switch self {
        case .available:
            return strings().usernameSettingsAvailable(username)
        case .invalid:
            return strings().errorUsernameInvalid
        case .taken:
            return strings().errorUsernameAlreadyTaken
        }
    }
}

func <(lhs:RenderedChannelParticipant, rhs: RenderedChannelParticipant) -> Bool {
    let lhsInvitedAt: Int32
    let rhsInvitedAt: Int32
    
    switch lhs.participant {
    case .creator:
        lhsInvitedAt = Int32.min
    case .member(_, let invitedAt, _, _, _):
        lhsInvitedAt = invitedAt
    }
    switch rhs.participant {
    case .creator:
        rhsInvitedAt = Int32.min
    case .member(_, let invitedAt, _, _, _):
        rhsInvitedAt = invitedAt
    }
    return lhsInvitedAt < rhsInvitedAt
}


extension TelegramGroup {
    var canPinMessage: Bool {
        return !hasBannedRights(.banPinMessages)
    }
}

extension Peer {
    var isUser:Bool {
        return self is TelegramUser
    }
    var isSecretChat:Bool {
        return self is TelegramSecretChat
    }
    var isGroup:Bool {
        return self is TelegramGroup
    }
    var canManageDestructTimer: Bool {
        if self is TelegramSecretChat {
            return true
        }
        if self.isUser && !self.isBot {
            return true
        }
        if let peer = self as? TelegramChannel {
            if let adminRights = peer.adminRights, adminRights.rights.contains(.canDeleteMessages) {
                return true
            } else if peer.groupAccess.isCreator {
                return true
            }
            return false
        }
        if let peer = self as? TelegramGroup {
            switch peer.role {
            case .admin, .creator:
                return true
            default:
                break
            }
        }
        return false
    }

    var canClearHistory: Bool {
        if self.isGroup || self.isUser || (self.isSupergroup && self.addressName == nil) {
            if let peer = self as? TelegramChannel, peer.flags.contains(.hasGeo) {} else {
                return true
            }
        }
        if self is TelegramSecretChat {
            return true
        }
        return false
    }
    
    func isRestrictedChannel(_ contentSettings: ContentSettings) -> Bool {
        if let peer = self as? TelegramChannel {
            if let restrictionInfo = peer.restrictionInfo {
                for rule in restrictionInfo.rules {
                    #if APP_STORE
                    if rule.platform == "ios" || rule.platform == "all" {
                        return !contentSettings.ignoreContentRestrictionReasons.contains(rule.reason)
                    }
                    #endif
                }
            }
        }
        return false
    }
    
    var restrictionText:String? {
        if let peer = self as? TelegramChannel {
            if let restrictionInfo = peer.restrictionInfo {
                for rule in restrictionInfo.rules {
                    if rule.platform == "ios" || rule.platform == "all" {
                        return rule.text
                    }
                }
            }
        }
        return nil
    }
    
    var botInfo: BotUserInfo? {
        if let peer = self as? TelegramUser {
            return peer.botInfo
        }
        return nil
    }
    
    var isSupergroup:Bool {
        if let peer = self as? TelegramChannel {
            switch peer.info {
            case .group:
                return true
            default:
                return false
            }
        }
        return false
    }
    var isBot:Bool {
        if let user = self as? TelegramUser {
            return user.botInfo != nil
        }
        return false
    }

    var canCall:Bool {
        return isUser && !isBot && ((self as! TelegramUser).phone != "42777") && ((self as! TelegramUser).phone != "42470") && ((self as! TelegramUser).phone != "4240004")
    }
    var isChannel:Bool {
        if let peer = self as? TelegramChannel {
            switch peer.info {
            case .broadcast:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    var isAdmin: Bool {
        if let peer = self as? TelegramChannel {
            return peer.adminRights != nil || peer.flags.contains(.isCreator)
        }
        return false
    }
    
    var isGigagroup:Bool {
        if let peer = self as? TelegramChannel {
            return peer.flags.contains(.isGigagroup)
        }
        return false
    }
}



public enum AddressNameAvailabilityState : Equatable {
    case none(username: String?)
    case success(username: String?)
    case progress(username: String?)
    case fail(username: String?, formatError: AddressNameFormatError?, availability: AddressNameAvailability)
    
    public var username:String? {
        switch self {
        case let .none(username:username):
            return username
        case let .success(username:username):
            return username
        case let .progress(username:username):
            return username
        case let .fail(fail):
            return fail.username
        }
    }
}

public func ==(lhs:AddressNameAvailabilityState, rhs:AddressNameAvailabilityState) -> Bool {
    switch lhs {
    case let .none(username:lhsName):
        if case let .none(username:rhsName) = rhs, lhsName == rhsName {
            return true
        }
        return false
    case let .success(username:lhsName):
        if case let .success(username:rhsName) = rhs, lhsName == rhsName {
            return true
        }
        return false
    case let .progress(username:lhsName):
        if case let .progress(username:rhsName) = rhs, lhsName == rhsName {
            return true
        }
        return false
    case let .fail(lhsData):
        if case let .fail(rhsData) = rhs, lhsData.formatError == rhsData.formatError && lhsData.username == rhsData.username && lhsData.availability == rhsData.availability {
            return true
        }
        return false
    }
}

extension Signal {
    
    public static func next(_ value: T) -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putNext(value)
            
            return EmptyDisposable
        }
    }
}

extension SentSecureValueType {
    var rawValue: String {
        switch self {
        case .email:
            return strings().secureIdRequestPermissionEmail
        case .phone:
            return strings().secureIdRequestPermissionPhone
        case .passport:
            return strings().secureIdRequestPermissionPassport
        case .address:
            return strings().secureIdRequestPermissionResidentialAddress
        case .personalDetails:
            return strings().secureIdRequestPermissionPersonalDetails
        case .driversLicense:
            return strings().secureIdRequestPermissionDriversLicense
        case .utilityBill:
            return strings().secureIdRequestPermissionUtilityBill
        case .rentalAgreement:
            return strings().secureIdRequestPermissionTenancyAgreement
        case .idCard:
            return strings().secureIdRequestPermissionIDCard
        case .bankStatement:
            return strings().secureIdRequestPermissionBankStatement
        case .internalPassport:
            return strings().secureIdRequestPermissionInternalPassport
        case .passportRegistration:
            return strings().secureIdRequestPermissionPassportRegistration
        case .temporaryRegistration:
            return strings().secureIdRequestPermissionTemporaryRegistration
        }
    }
}
extension TwoStepVerificationPendingEmail : Equatable {
    public static func == (lhs: TwoStepVerificationPendingEmail, rhs: TwoStepVerificationPendingEmail) -> Bool {
        return lhs.codeLength == rhs.codeLength && lhs.pattern == rhs.pattern
    }
    
    
}

extension UpdateTwoStepVerificationPasswordResult : Equatable {
    public static func ==(lhs: UpdateTwoStepVerificationPasswordResult, rhs: UpdateTwoStepVerificationPasswordResult) -> Bool {
        switch lhs {
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        case let .password(password, lhsPendingEmailPattern):
            if case .password(password, let rhsPendingEmailPattern) = rhs {
                return lhsPendingEmailPattern == rhsPendingEmailPattern
            } else {
                return false
            }
        }
    }
}



extension SecureIdGender {
    static func gender(from mrz: TGPassportMRZ) -> SecureIdGender {
        switch mrz.gender.lowercased() {
        case "f":
            return .female
        default:
            return .male
        }
    }
}

extension SecureIdRequestedFormField {
    var isIdentityField: Bool {
        switch self {
        case let .just(field):
            switch field {
            case .idCard, .passport, .driversLicense, .internalPassport:
                return true
            default:
                return false
            }
        case let .oneOf(fields):
            switch fields[0] {
            case .idCard, .passport, .driversLicense, .internalPassport:
                return true
            default:
                return false
            }
        }
    }
    
    var valueKey: SecureIdValueKey? {
        switch self {
        case let .just(field):
            return field.valueKey
        default:
            return nil
        }
    }
    
    var fieldValue: SecureIdRequestedFormFieldValue? {
        switch self {
        case let .just(field):
            return field
        default:
            return nil
        }
    }
    
    var isAddressField: Bool {
        switch self {
        case let .just(field):
            switch field {
            case .utilityBill, .bankStatement, .rentalAgreement, .passportRegistration, .temporaryRegistration:
                return true
            default:
                return false
            }
        case let .oneOf(fields):
            switch fields[0] {
            case .utilityBill, .bankStatement, .rentalAgreement, .passportRegistration, .temporaryRegistration:
                return true
            default:
                return false
            }
        }
    }
}

extension SecureIdForm {
    func searchContext(for field: SecureIdRequestedFormFieldValue) -> SecureIdValueWithContext? {
         let index = values.index(where: { context -> Bool in
            switch context.value {
            case .address:
                if case .address = field {
                    return true
                } else {
                    return false
                }
            case .bankStatement:
                if case .bankStatement = field {
                    return true
                } else {
                    return false
                }
            case .driversLicense:
                if case .driversLicense = field {
                    return true
                } else {
                    return false
                }
            case .idCard:
                if case .idCard = field {
                    return true
                } else {
                    return false
                }
            case .passport:
                if case .passport = field {
                    return true
                } else {
                    return false
                }
            case .personalDetails:
                if case .personalDetails = field {
                    return true
                } else {
                    return false
                }
            case .rentalAgreement:
                if case .rentalAgreement = field {
                    return true
                } else {
                    return false
                }
            case .utilityBill:
                if case .utilityBill = field {
                    return true
                } else {
                    return false
                }
            case .phone:
                if case .phone = field {
                    return true
                } else {
                    return false
                }
            case .email:
                if case .email = field {
                    return true
                } else {
                    return false
                }
            case .internalPassport:
                if case .internalPassport = field {
                    return true
                } else {
                    return false
                }
            case .passportRegistration:
                if case .passportRegistration = field {
                    return true
                } else {
                    return false
                }
            case .temporaryRegistration:
                if case .temporaryRegistration = field {
                    return true
                } else {
                    return false
                }
            }
        })
        if let index = index {
            return values[index]
        } else {
            return nil
        }
    }
    

}

extension SecureIdValue {
    func isSame(of value: SecureIdValue) -> Bool {
        switch self {
        case .address:
            if case .address = value {
                return true
            } else {
                return false
            }
        case .bankStatement:
            if case .bankStatement = value {
                return true
            } else {
                return false
            }
        case .driversLicense:
            if case .driversLicense = value {
                return true
            } else {
                return false
            }
        case .idCard:
            if case .idCard = value {
                return true
            } else {
                return false
            }
        case .passport:
            if case .passport = value {
                return true
            } else {
                return false
            }
        case .personalDetails:
            if case .personalDetails = value {
                return true
            } else {
                return false
            }
        case .rentalAgreement:
            if case .rentalAgreement = value {
                return true
            } else {
                return false
            }
        case .utilityBill:
            if case .utilityBill = value {
                return true
            } else {
                return false
            }
        case .phone:
            if case .phone = value {
                return true
            } else {
                return false
            }
        case .email:
            if case .email = value {
                return true
            } else {
                return false
            }
        case .internalPassport(_):
            if case .internalPassport = value {
                return true
            } else {
                return false
            }
        case .passportRegistration(_):
            if case .passportRegistration = value {
                return true
            } else {
                return false
            }
        case .temporaryRegistration(_):
            if case .temporaryRegistration = value {
                return true
            } else {
                return false
            }
        }
    }
    func isSame(of value: SecureIdValueKey) -> Bool {
        return self.key == value
    }
    
    
    
    var secureIdValueAccessContext: SecureIdValueAccessContext? {
        switch self {
        case .email:
            return generateSecureIdValueEmptyAccessContext()
        case .phone:
            return generateSecureIdValueEmptyAccessContext()
        default:
            return generateSecureIdValueAccessContext()
        }
    }
    
    
    var addressValue: SecureIdAddressValue? {
        switch self {
        case let .address(value):
            return value
        default:
            return nil
        }
    }
    
    var identifier: String? {
        switch self {
        case let .passport(value):
            return value.identifier
        case let .driversLicense(value):
            return value.identifier
        case let .idCard(value):
            return value.identifier
        case let .internalPassport(value):
            return value.identifier
        default:
            return nil
        }
    }
    
    var personalDetails: SecureIdPersonalDetailsValue? {
        switch self {
        case let .personalDetails(value):
            return value
        default:
            return nil
        }
    }
    
    var selfieVerificationDocument: SecureIdVerificationDocumentReference? {
        switch self {
        case let .idCard(value):
            return value.selfieDocument
        case let .passport(value):
            return value.selfieDocument
        case let .driversLicense(value):
            return value.selfieDocument
        case let .internalPassport(value):
            return value.selfieDocument
        default:
            return nil
        }
    }
    
    var verificationDocuments: [SecureIdVerificationDocumentReference]? {
        switch self {
        case let .bankStatement(value):
            return value.verificationDocuments
        case let .rentalAgreement(value):
            return value.verificationDocuments
        case let .utilityBill(value):
            return value.verificationDocuments
        case let .passportRegistration(value):
            return value.verificationDocuments
        case let .temporaryRegistration(value):
            return value.verificationDocuments
        default:
            return nil
        }
    }
    
    var translations: [SecureIdVerificationDocumentReference]? {
        switch self {
        case let .passport(value):
            return value.translations
        case let .idCard(value):
            return value.translations
        case let .driversLicense(value):
            return value.translations
        case let .internalPassport(value):
            return value.translations
        case let .utilityBill(value):
            return value.translations
        case let .rentalAgreement(value):
            return value.translations
        case let .temporaryRegistration(value):
            return value.translations
        case let .passportRegistration(value):
            return value.translations
        case let .bankStatement(value):
            return value.translations
        default:
            return nil
        }
    }
    
    var frontSideVerificationDocument: SecureIdVerificationDocumentReference? {
        switch self {
        case let .idCard(value):
            return value.frontSideDocument
        case let .passport(value):
            return value.frontSideDocument
        case let .driversLicense(value):
            return value.frontSideDocument
        case let .internalPassport(value):
            return value.frontSideDocument
        default:
            return nil
        }
    }
    
    var backSideVerificationDocument: SecureIdVerificationDocumentReference? {
        switch self {
        case let .idCard(value):
            return value.backSideDocument
        case let .driversLicense(value):
            return value.backSideDocument
        default:
            return nil
        }
    }
    
    var hasBacksideDocument: Bool {
        switch self {
        case .idCard:
            return true
        case .driversLicense:
            return true
        default:
            return false
        }
    }
    
    var passportValue: SecureIdPassportValue? {
        switch self {
        case let .passport(value):
            return value
        default:
            return nil
        }
    }
    
    var phoneValue: SecureIdPhoneValue? {
        switch self {
        case let .phone(value):
            return value
        default:
            return nil
        }
    }
    var emailValue: SecureIdEmailValue? {
        switch self {
        case let .email(value):
            return value
        default:
            return nil
        }
    }
    
    var requestFieldType: SecureIdRequestedFormFieldValue {
        return key.requestFieldType
    }
    
    var expiryDate: SecureIdDate? {
        switch self {
        case let .idCard(value):
            return value.expiryDate
        case let .passport(value):
            return value.expiryDate
        case let .driversLicense(value):
            return value.expiryDate
        default:
            return nil
        }
    }
}

extension SecureIdValueKey {
    var requestFieldType: SecureIdRequestedFormFieldValue {
        switch self {
        case .address:
            return .address
        case .bankStatement:
            return .bankStatement(translation: true)
        case .driversLicense:
            return .driversLicense(selfie: true, translation: true)
        case .email:
            return .email
        case .idCard:
            return .idCard(selfie: true, translation: true)
        case .internalPassport:
            return .internalPassport(selfie: true, translation: true)
        case .passport:
            return .passport(selfie: true, translation: true)
        case .passportRegistration:
            return .passportRegistration(translation: true)
        case .personalDetails:
            return .personalDetails(nativeName: true)
        case .phone:
            return .phone
        case .rentalAgreement:
            return .rentalAgreement(translation: true)
        case .temporaryRegistration:
            return .temporaryRegistration(translation: true)
        case .utilityBill:
            return .utilityBill(translation: true)
        }
    }
}


extension SecureIdRequestedFormFieldValue {
    var rawValue: String {
        switch self {
        case .email:
            return strings().secureIdRequestPermissionEmail
        case .phone:
            return strings().secureIdRequestPermissionPhone
        case .address:
            return strings().secureIdRequestPermissionResidentialAddress
        case .utilityBill:
            return strings().secureIdRequestPermissionUtilityBill
        case .bankStatement:
            return strings().secureIdRequestPermissionBankStatement
        case .rentalAgreement:
            return strings().secureIdRequestPermissionTenancyAgreement
        case .passport:
            return strings().secureIdRequestPermissionPassport
        case .idCard:
            return strings().secureIdRequestPermissionIDCard
        case .driversLicense:
            return strings().secureIdRequestPermissionDriversLicense
        case .personalDetails:
            return strings().secureIdRequestPermissionPersonalDetails
        case .internalPassport:
            return strings().secureIdRequestPermissionInternalPassport
        case .passportRegistration:
            return strings().secureIdRequestPermissionPassportRegistration
        case .temporaryRegistration:
            return strings().secureIdRequestPermissionTemporaryRegistration
        }
    }
    
    func isKindOf(_ fieldValue: SecureIdRequestedFormFieldValue) -> Bool {
        switch self {
        case .email:
            if case .email = fieldValue {
                return true
            } else {
                return false
            }
        case .phone:
            if case .phone = fieldValue {
                return true
            } else {
                return false
            }
        case .address:
            if case .address = fieldValue {
                return true
            } else {
                return false
            }
        case .utilityBill:
            if case .utilityBill = fieldValue {
                return true
            } else {
                return false
            }
        case .bankStatement:
            if case .bankStatement = fieldValue {
                return true
            } else {
                return false
            }
        case .rentalAgreement:
            if case .rentalAgreement = fieldValue {
                return true
            } else {
                return false
            }
        case .passport:
            if case .passport = fieldValue {
                return true
            } else {
                return false
            }
        case .idCard:
            if case .idCard = fieldValue {
                return true
            } else {
                return false
            }
        case .driversLicense:
            if case .driversLicense = fieldValue {
                return true
            } else {
                return false
            }
        case .personalDetails:
            if case .personalDetails = fieldValue {
                return true
            } else {
                return false
            }
        case .internalPassport:
            if case .internalPassport = fieldValue {
                return true
            } else {
                return false
            }
        case .passportRegistration:
            if case .passportRegistration = fieldValue {
                return true
            } else {
                return false
            }
        case .temporaryRegistration:
            if case .temporaryRegistration = fieldValue {
                return true
            } else {
                return false
            }
        }
    }
    
    var uploadFrontTitleText: String {
        switch self {
        case .idCard:
            return strings().secureIdUploadFront
        case .driversLicense:
            return strings().secureIdUploadFront
        default:
            return strings().secureIdUploadMain
        }
    }
    var uploadBackTitleText: String {
        switch self {
        case .idCard:
            return strings().secureIdUploadReverse
        case .driversLicense:
            return strings().secureIdUploadReverse
        default:
            return strings().secureIdUploadMain
        }
    }
    
    var hasBacksideDocument: Bool {
        switch self {
        case .idCard:
            return true
        case .driversLicense:
            return true
        default:
            return false
        }
    }
    
    var hasSelfie: Bool {
        switch self {
        case let .passport(selfie, _), let .idCard(selfie, _), let .driversLicense(selfie, _), let .internalPassport(selfie, _):
            return selfie
        default:
            return false
        }
    }
    
    var hasTranslation: Bool {
        switch self {
        case let .passport(_, translation), let .idCard(_, translation), let .driversLicense(_, translation), let .internalPassport(_, translation):
            return translation
        case let .utilityBill(translation), let .rentalAgreement(translation), let .bankStatement(translation), let .passportRegistration(translation), let .temporaryRegistration(translation):
            return translation
        default:
            return false
        }
    }
    
    var emptyDescription: String {
        switch self {
        case .email:
            return strings().secureIdRequestPermissionEmailEmpty
        case .phone:
            return strings().secureIdRequestPermissionPhoneEmpty
        case .utilityBill:
            return strings().secureIdEmptyDescriptionUtilityBill
        case .bankStatement:
            return strings().secureIdEmptyDescriptionBankStatement
        case .rentalAgreement:
            return strings().secureIdEmptyDescriptionTenancyAgreement
        case .passportRegistration:
            return strings().secureIdEmptyDescriptionPassportRegistration
        case .temporaryRegistration:
            return strings().secureIdEmptyDescriptionTemporaryRegistration
        case .passport:
            return strings().secureIdEmptyDescriptionPassport
        case .driversLicense:
            return strings().secureIdEmptyDescriptionDriversLicense
        case .idCard:
            return strings().secureIdEmptyDescriptionIdentityCard
        case .internalPassport:
            return strings().secureIdEmptyDescriptionInternalPassport
        case .personalDetails:
            return strings().secureIdEmptyDescriptionPersonalDetails
        case .address:
            return strings().secureIdEmptyDescriptionAddress
        }
    }
    
    var descAdd: String {
        switch self {
        case .email:
            return ""
        case .phone:
            return ""
        case .address:
            return strings().secureIdAddResidentialAddress
        case .utilityBill:
            return strings().secureIdAddUtilityBill
        case .bankStatement:
            return strings().secureIdAddBankStatement
        case .rentalAgreement:
            return strings().secureIdAddTenancyAgreement
        case .passport:
            return strings().secureIdAddPassport
        case .idCard:
            return strings().secureIdAddID
        case .driversLicense:
            return strings().secureIdAddDriverLicense
        case .personalDetails:
            return strings().secureIdAddPersonalDetails
        case .internalPassport:
            return strings().secureIdAddInternalPassport
        case .passportRegistration:
            return strings().secureIdAddPassportRegistration
        case .temporaryRegistration:
            return strings().secureIdAddTemporaryRegistration
        }
    }
    
    var descEdit: String {
        switch self {
        case .email:
            return ""
        case .phone:
            return ""
        case .address:
            return strings().secureIdEditResidentialAddress
        case .utilityBill:
            return strings().secureIdEditUtilityBill
        case .bankStatement:
            return strings().secureIdEditBankStatement
        case .rentalAgreement:
            return strings().secureIdEditTenancyAgreement
        case .passport:
            return strings().secureIdEditPassport
        case .idCard:
            return strings().secureIdEditID
        case .driversLicense:
            return strings().secureIdEditDriverLicense
        case .personalDetails:
            return strings().secureIdEditPersonalDetails
        case .internalPassport:
            return strings().secureIdEditInternalPassport
        case .passportRegistration:
            return strings().secureIdEditPassportRegistration
        case .temporaryRegistration:
            return strings().secureIdEditTemporaryRegistration
        }
    }
}

var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
   // formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}

extension SecureIdRequestedFormFieldValue  {
    var valueKey: SecureIdValueKey {
        switch self {
        case .address:
            return .address
        case .bankStatement:
            return .bankStatement
        case .driversLicense:
            return .driversLicense
        case .email:
            return .email
        case .idCard:
            return .idCard
        case .passport:
            return .passport
        case .personalDetails:
            return .personalDetails
        case .phone:
            return .phone
        case .rentalAgreement:
            return .rentalAgreement
        case .utilityBill:
            return .utilityBill
        case .internalPassport:
            return .internalPassport
        case .passportRegistration:
            return .passportRegistration
        case .temporaryRegistration:
            return .temporaryRegistration
        }
    }
    
    var primary: SecureIdRequestedFormFieldValue {
        if SecureIdRequestedFormField.just(self).isIdentityField {
            return .personalDetails(nativeName: true)
        }
        if SecureIdRequestedFormField.just(self).isAddressField {
            return .address
        }
        return self
    }
    
    func isEqualToMRZ(_ mrz: TGPassportMRZ) -> Bool {
        switch mrz.documentType.lowercased() {
        case "p":
            if case .passport = self {
                return true
            } else {
                return false
            }
        default:
            return false
        }
    }
    
}



extension InputDataValue {
    var secureIdDate: SecureIdDate? {
        switch self {
        case let .date(day, month, year):
            if let day = day, let month = month, let year = year {
                return SecureIdDate(day: day, month: month, year: year)
            }
            
            return nil
        default:
            return nil
        }
    }
}

extension SecureIdDate {
    var inputDataValue: InputDataValue {
        return .date(day, month, year)
    }
}


public func peerCompactDisplayTitles(_ peerIds: [PeerId], _ dict: SimpleDictionary<PeerId, Peer>) -> String {
    var names:String = ""
    for peerId in peerIds {
        if let peer = dict[peerId] {
            names += peer.compactDisplayTitle
            if peerId != peerIds.last {
                names += ", "
            }
        }
    }
    return names
}

func mediaResource(from media:Media?) -> TelegramMediaResource? {
    if let media = media as? TelegramMediaFile {
        return media.resource
    } else if let media = media as? TelegramMediaImage {
        return largestImageRepresentation(media.representations)?.resource
    }
    return nil
}

func mediaResourceMIMEType(from media:Media?) -> String? {
    if let media = media as? TelegramMediaFile {
        return media.mimeType
    } else if media is TelegramMediaImage {
        return "image/jpeg"
    }
    return nil
}

func mediaResourceName(from media:Media?, ext:String?) -> String {
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let ext = ext ?? ".file"
    if let media = media as? TelegramMediaFile {
        return media.fileName ?? "FILE " + dateFormatter.string(from: Date()) + "." + ext
    } else if media is TelegramMediaImage {
        return "IMAGE " + dateFormatter.string(from: Date())  + "." + ext
    }
    return "FILE " + dateFormatter.string(from: Date())  + "." + ext
}


func removeChatInteractively(context: AccountContext, peerId:PeerId, threadId: Int64? = nil, userId: PeerId? = nil, deleteGroup: Bool = false) -> Signal<Bool, NoError> {
    return context.account.postbox.peerView(id: peerId)
        |> take(1)
        |> map { peerViewMainPeer($0) }
        |> filter { $0 != nil }
        |> map { $0! }
        |> deliverOnMainQueue
        |> mapToSignal { peer -> Signal<Bool, NoError> in
        
        
            let text:String
            var okTitle: String? = nil
            var thridTitle: String? = nil
            var canRemoveGlobally: Bool = false

            if let _ = threadId {
                okTitle = strings().confirmDelete
                text = strings().chatContextDeleteTopic
            } else {
                if let peer = peer as? TelegramChannel {
                    switch peer.info {
                    case .broadcast:
                        if peer.flags.contains(.isCreator) && deleteGroup {
                            text = strings().confirmDeleteAdminedChannel
                            okTitle = strings().confirmDelete
                        } else {
                            text = strings().peerInfoConfirmLeaveChannel
                        }
                    case .group:
                        if deleteGroup && peer.flags.contains(.isCreator) {
                            text = strings().peerInfoConfirmDeleteGroupConfirmation
                            okTitle = strings().confirmDelete
                        } else {
                            text = strings().confirmLeaveGroup
                            okTitle = strings().peerInfoConfirmLeave
                        }
                    }
                } else if let peer = peer as? TelegramGroup {
                    text = strings().peerInfoConfirmDeleteChat(peer.title)
                    okTitle = strings().confirmDelete
                } else {
                    text = strings().peerInfoConfirmDeleteUserChat
                    okTitle = strings().confirmDelete
                }
                
                if peerId.namespace == Namespaces.Peer.CloudUser && peerId != context.account.peerId && !peer.isBot {
                    if context.limitConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
                        canRemoveGlobally = true
                    }
                }
                if peerId.namespace == Namespaces.Peer.SecretChat {
                    canRemoveGlobally = false
                }
                
                if canRemoveGlobally {
                    thridTitle = strings().chatMessageDeleteForMeAndPerson(peer.displayTitle)
                } else if peer.isBot {
                    thridTitle = strings().peerInfoStopBot
                }
                    
                if peer.groupAccess.isCreator, deleteGroup {
                    canRemoveGlobally = true
                    thridTitle = strings().deleteChatDeleteGroupForAll
                }
            }
            
            

            
            return combineLatest(modernConfirmSignal(for: context.window, account: context.account, peerId: userId ?? peerId, information: text, okTitle: okTitle ?? strings().alertOK, thridTitle: thridTitle, thridAutoOn: false), context.globalPeerHandler.get() |> take(1)) |> map { result, location -> Bool in
                
                if let threadId = threadId {
                    _ = context.engine.peers.removeForumChannelThread(id: peerId, threadId: threadId).start()
                } else {
                    _ = context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: canRemoveGlobally).start()
                    if peer.isBot && result == .thrid {
                        _ = context.blockedPeersContext.add(peerId: peerId).start()
                    }
                }
               
                switch location {
                case let .peer(id):
                    if id == peerId {
                        context.bindings.rootNavigation().close()
                    }
                case let .thread(data):
                    if threadId == nil {
                        if data.messageId.peerId == peerId {
                            context.bindings.rootNavigation().close()
                        }
                    } else {
                        if makeMessageThreadId(data.messageId) == threadId {
                            context.bindings.rootNavigation().close()
                        }
                    }
                case .none:
                    break
                }
                
                return true
            }
    }

}

func applyExternalProxy(_ server:ProxyServerSettings, accountManager: AccountManager<TelegramAccountManagerTypes>) {
    var textInfo = strings().proxyForceEnableTextIP(server.host) + "\n" + strings().proxyForceEnableTextPort(Int(server.port))
    switch server.connection {
    case let .socks5(username, password):
        if let user = username {
            textInfo += "\n" + strings().proxyForceEnableTextUsername(user)
        }
        if let pass = password {
            textInfo += "\n" + strings().proxyForceEnableTextPassword(pass)
        }
    case let .mtp(secret):
        textInfo += "\n" + strings().proxyForceEnableTextSecret(MTProxySecret.parseData(secret)?.serializeToString() ?? "")
    }
   
    textInfo += "\n\n" + strings().proxyForceEnableText
   
    if case .mtp = server.connection {
        textInfo += "\n\n" + strings().proxyForceEnableMTPDesc
    }
    
    modernConfirm(for: mainWindow, account: nil, peerId: nil, header: strings().proxyForceEnableHeader1, information: textInfo, okTitle: strings().proxyForceEnableOK, thridTitle: strings().proxyForceEnableEnable, successHandler: { result in
        _ = updateProxySettingsInteractively(accountManager: accountManager, { current -> ProxySettings in
            
            var current = current.withAddedServer(server)
            if result == .thrid {
                current = current.withUpdatedActiveServer(server).withUpdatedEnabled(true)
            }
            return current
        }).start()
    })
}


extension SecureIdGender {
    var stringValue: String {
        switch self {
        case .female:
            return strings().secureIdGenderFemale
        case .male:
            return strings().secureIdGenderMale
        }
    }
}

extension SecureIdDate {
    var stringValue: String {
        return "\(day).\(month).\(year)"
    }
}



func moveWallpaperToCache(postbox: Postbox, resource: TelegramMediaResource, reference: WallpaperReference?, settings: WallpaperSettings, isPattern: Bool) -> Signal<String, NoError> {
    let resourceData: Signal<MediaResourceData, NoError>
    if isPattern {
        resourceData = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedPatternWallpaperMaskRepresentation(size: nil, settings: settings), complete: true)
    } else if settings.blur {
        resourceData = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedBlurredWallpaperRepresentation(), complete: true)
    } else {
        resourceData = postbox.mediaBox.resourceData(resource)
    }
    
   
    return combineLatest(fetchedMediaResource(mediaBox: postbox.mediaBox, reference: MediaResourceReference.wallpaper(wallpaper: reference, resource: resource), reportResultStatus: true) |> `catch` { _ in return .complete() }, resourceData) |> mapToSignal { _, data in
        if data.complete {
            return moveWallpaperToCache(postbox: postbox, path: data.path, resource: resource, settings: settings)
        } else {
            return .complete()
        }
    }
}

func moveWallpaperToCache(postbox: Postbox, wallpaper: Wallpaper) -> Signal<Wallpaper, NoError> {
    switch wallpaper {
    case let .image(reps, settings):
        return moveWallpaperToCache(postbox: postbox, resource: largestImageRepresentation(reps)!.resource, reference: nil, settings: settings, isPattern: false) |> map { _ in return wallpaper}
    case let .custom(representation, blurred):
        return moveWallpaperToCache(postbox: postbox, resource: representation.resource, reference: nil, settings: WallpaperSettings(blur: blurred), isPattern: false) |> map { _ in return wallpaper}
    case let .file(slug, file, settings, isPattern):
        return moveWallpaperToCache(postbox: postbox, resource: file.resource, reference: .slug(slug), settings: settings, isPattern: isPattern) |> map { _ in return wallpaper}
    default:
       return .single(wallpaper)
    }
}

func moveWallpaperToCache(postbox: Postbox, path: String, resource: TelegramMediaResource, settings: WallpaperSettings) -> Signal<String, NoError> {
    return Signal { subscriber in
        
        let wallpapers = ApiEnvironment.containerURL!.appendingPathComponent("Wallpapers").path
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: wallpapers), withIntermediateDirectories: true, attributes: nil)
        
        let out = wallpapers + "/" + resource.id.stringRepresentation + "\(settings.stringValue)" + ".png"
        
        if !FileManager.default.fileExists(atPath: out) {
            try? FileManager.default.removeItem(atPath: out)
            try? FileManager.default.copyItem(atPath: path, toPath: out)
        }
        subscriber.putNext(out)
        
        subscriber.putCompletion()
        return EmptyDisposable
        
    }
}

extension WallpaperSettings {
    var stringValue: String {
        var value: String = ""
        if let top = self.colors.first {
            value += "ctop\(top)"
        }
        if let top = self.colors.last, self.colors.count == 2 {
            value += "cbottom\(top)"
        }
        if let rotation = self.rotation {
            value += "rotation\(rotation)"
        }
        if self.blur {
            value += "blur"
        }
        return value
    }
}

func wallpaperPath(_ resource: TelegramMediaResource, settings: WallpaperSettings) -> String {
    return ApiEnvironment.containerURL!.appendingPathComponent("Wallpapers").path + "/" + resource.id.stringRepresentation + "\(settings.stringValue)" + ".png"
}


func canCollagesFromUrl(_ urls:[URL]) -> Bool {
    var canCollage: Bool = urls.count > 1 && urls.count <= 10
    
    var musicCount: Int = 0
    var voiceCount: Int = 0
    var gifCount: Int = 0
    if canCollage {
        for url in urls {
            let mime = MIMEType(url.path)
            let attrs = Sender.fileAttributes(for: mime, path: url.path, isMedia: true, inCollage: true)
            let isGif = attrs.contains(where: { attr -> Bool in
                switch attr {
                case .Animated:
                    return true
                default:
                    return false
                }
            })
            let isMusic = attrs.contains(where: { attr -> Bool in
                switch attr {
                case let .Audio(isVoice, _, _, _, _):
                    return !isVoice
                default:
                    return false
                }
            })
            let isVoice = attrs.contains(where: { attr -> Bool in
                switch attr {
                case let .Audio(isVoice, _, _, _, _):
                    return isVoice
                default:
                    return false
                }
            })
            if mime == "image/webp" {
                return false
            }
            if isMusic {
                musicCount += 1
            }
            if isVoice {
                voiceCount += 1
            }
            if isGif {
                gifCount += 1
            }
        }
    }
    
    if musicCount > 0 {
        if musicCount == urls.count {
            return true
        } else {
            return false
        }
    }
    if voiceCount > 0 {
        return false
    }
    if gifCount > 0 {
        return false
    }
    return canCollage
}

extension AutomaticMediaDownloadSettings {
    
    func isDownloable(_ message: Message) -> Bool {
        
        if !automaticDownload {
            return false
        }
        
        
        func ability(_ category: AutomaticMediaDownloadCategoryPeers, _ peer: Peer) -> Bool {
            if peer.isGroup || peer.isSupergroup {
                return category.groupChats
            } else if peer.isChannel {
                return category.channels
            } else {
                return category.privateChats
            }
        }
        
        func checkFile(_ media: TelegramMediaFile, _ peer: Peer, _ categories: AutomaticMediaDownloadCategories) -> Bool {
            let size = Int64(media.size ?? 0)
            
            let dangerExts = "action app bin command csh osx workflow terminal url caction mpkg pkg xhtm webarchive"
            
            if let ext = media.fileName?.nsstring.pathExtension.lowercased(), dangerExts.components(separatedBy: " ").contains(ext) {
                return false
            }
            
            switch true {
            case media.isInstantVideo:
                return ability(categories.video, peer) && size <= (categories.video.fileSize ?? INT32_MAX)
            case media.isVideo && media.isAnimated:
                return ability(categories.video, peer) && size <= (categories.video.fileSize ?? INT32_MAX)
            case media.isVideo:
                return ability(categories.video, peer) && size <= (categories.video.fileSize ?? INT32_MAX)
            case media.isVoice:
                return size <= 1 * 1024 * 1024
            default:
                return ability(categories.files, peer) && size <= (categories.files.fileSize ?? INT32_MAX)
            }
        }
        
        if let peer = coreMessageMainPeer(message) {
            if let _ = message.effectiveMedia as? TelegramMediaImage {
                return ability(categories.photo, peer)
            } else if let media = message.effectiveMedia as? TelegramMediaFile {
                return checkFile(media, peer, categories)
            } else if let media = message.effectiveMedia as? TelegramMediaWebpage {
                switch media.content {
                case let .Loaded(content):
                    if content.type == "telegram_background" {
                         return ability(categories.photo, peer)
                    }
                    if let file = content.file {
                        return checkFile(file, peer, categories)
                    } else if let _ = content.image {
                        return ability(categories.photo, peer)
                    }
                default:
                    break
                }
            } else if let media = message.effectiveMedia as? TelegramMediaGame {
                if let file = media.file {
                    return checkFile(file, peer, categories)
                } else if let _ = media.image {
                    return ability(categories.photo, peer)
                }
            }
        }
        
        return false
    }
}


func fileExtenstion(_ file: TelegramMediaFile) -> String {
    return fileExt(file.mimeType) ?? file.fileName?.nsstring.pathExtension ?? ""
}

func proxySettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<ProxySettings, NoError>  {
    return accountManager.sharedData(keys: [SharedDataKeys.proxySettings]) |> map { view in
        return view.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) ?? ProxySettings.defaultSettings
    }
}

extension ProxySettings {
    func withUpdatedActiveServer(_ activeServer: ProxyServerSettings?) -> ProxySettings {
        return ProxySettings(enabled: self.enabled, servers: servers, activeServer: activeServer, useForCalls: self.useForCalls)
    }
    
    func withUpdatedEnabled(_ enabled: Bool) -> ProxySettings {
        return ProxySettings(enabled: enabled, servers: self.servers, activeServer: self.activeServer, useForCalls: self.useForCalls)
    }
    
    func withAddedServer(_ proxy: ProxyServerSettings) -> ProxySettings {
        var servers = self.servers
        if servers.first(where: {$0 == proxy}) == nil {
            servers.append(proxy)
        }
        return ProxySettings(enabled: self.enabled, servers: servers, activeServer: self.activeServer, useForCalls: self.useForCalls)
    }
    
    func withUpdatedServer(_ current: ProxyServerSettings, with updated: ProxyServerSettings) -> ProxySettings {
        var servers = self.servers
        if let index = servers.firstIndex(where: {$0 == current}) {
            servers[index] = updated
        } else {
            servers.append(updated)
        }
        var activeServer = self.activeServer
        if activeServer == current {
            activeServer = updated
        }
        return ProxySettings(enabled: self.enabled, servers: servers, activeServer: activeServer, useForCalls: self.useForCalls)
    }
    
    func withUpdatedUseForCalls(_ enable: Bool) -> ProxySettings {
        return ProxySettings(enabled: self.enabled, servers: servers, activeServer: self.activeServer, useForCalls: enable)
    }
    
    func withRemovedServer(_ proxy: ProxyServerSettings) -> ProxySettings {
        var servers = self.servers
        var activeServer = self.activeServer
        var enabled: Bool = self.enabled
        if let index = servers.firstIndex(where: {$0 == proxy}) {
            _ = servers.remove(at: index)
        }
        if proxy == activeServer {
            activeServer = nil
            enabled = false
        }
        return ProxySettings(enabled: enabled, servers: servers, activeServer: activeServer, useForCalls: self.useForCalls)
    }
}

extension ProxyServerSettings {
    var link: String {
        let prefix: String
        switch self.connection {
        case .mtp:
            prefix = "proxy"
        case .socks5:
            prefix = "socks"
        }
        var link = "tg://\(prefix)?server=\(self.host)&port=\(self.port)"
        switch self.connection {
        case let .mtp(secret):
            link += "&secret=\((secret as NSData).hexString)"
        case let .socks5(username, password):
            if let username = username {
                link += "&user=\(username)"
            }
            if let password = password {
                link += "&pass=\(password)"
            }
        }
        return link
    }
    
    var isEmpty: Bool {
        if host.isEmpty {
            return true
        }
        if port == 0 {
            return true
        }
        switch self.connection {
        case let .mtp(secret):
            if secret.isEmpty {
                return true
            }
        default:
            break
        }
        return false
    }
}


struct SecureIdDocumentValue {
    let document: SecureIdVerificationDocument
    let stableId: AnyHashable
    let context: SecureIdAccessContext
    init(document: SecureIdVerificationDocument, context: SecureIdAccessContext, stableId: AnyHashable) {
        self.document = document
        self.stableId = stableId
        self.context = context
    }
    var image: TelegramMediaImage {
        return TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(100, 100), resource: document.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
    }
}

enum FaqDestination {
    case telegram
    case ton
    case walletTOS
    var url:String {
        switch self {
        case .telegram:
            return "https://telegram.org/faq/"
        case .ton:
            return "https://telegram.org/faq/gram_wallet/"
        case .walletTOS:
            return "https://telegram.org/tos/wallet/"
        }
    }
}

func openFaq(context: AccountContext, dest: FaqDestination = .telegram) {
    let language = appCurrentLanguage.languageCode[appCurrentLanguage.languageCode.index(appCurrentLanguage.languageCode.endIndex, offsetBy: -2) ..< appCurrentLanguage.languageCode.endIndex]
    
    _ = showModalProgress(signal: webpagePreview(account: context.account, url: dest.url) |> deliverOnMainQueue, for: context.window).start(next: { webpage in
        if let webpage = webpage {
            showInstantPage(InstantPageViewController(context, webPage: webpage, message: nil))
        } else {
            execute(inapp: .external(link: dest.url + language, true))
        }
    })
}

func isNotEmptyStrings(_ strings: [String?]) -> String {
    for string in strings {
        if let string = string, !string.isEmpty {
            return string
        }
    }
    return ""
}


extension TelegramMediaImage {
    var isLocalResource: Bool {
        if let resource = representations.last?.resource {
            if resource is LocalFileMediaResource {
                return true
            }
            if resource is LocalFileReferenceMediaResource {
                return true
            }
        }
        return false
    }
}

extension TelegramMediaFile {
    var isLocalResource: Bool {
        if resource is LocalFileMediaResource {
            return true
        }
        if resource is LocalFileReferenceMediaResource {
            return true
        }
        return false
    }
    var premiumEffect: TelegramMediaFile.VideoThumbnail? {
        if let resource = self.videoThumbnails.first(where: { thumbnail in
            if let resource = thumbnail.resource as? CloudDocumentSizeMediaResource, resource.sizeSpec == "f" {
                return true
            } else {
                return false
            }
        }) {
            return resource
        }
        return nil
    }

}

extension MessageIndex {
    func withUpdatedTimestamp(_ timestamp: Int32) -> MessageIndex {
        return MessageIndex(id: self.id, timestamp: timestamp)
    }
    init(_ message: Message) {
        self.init(id: message.id, timestamp: message.timestamp)
    }
    
}

func requestMicrophonePermission() -> Signal<Bool, NoError> {
    return requestMediaPermission(.audio)
}
func requestCameraPermission() -> Signal<Bool, NoError> {
    return requestMediaPermission(.video)
}
func requestScreenCapturPermission() -> Signal<Bool, NoError> {
    return Signal { subscriber in
        subscriber.putNext(requestScreenCaptureAccess())
        subscriber.putCompletion()
        return EmptyDisposable
    } |> runOn(.mainQueue())
}

func screenCaptureAvailable() -> Bool {
    let stream = CGDisplayStream(dispatchQueueDisplay: CGMainDisplayID(), outputWidth: 1, outputHeight: 1, pixelFormat: Int32(kCVPixelFormatType_32BGRA), properties: nil, queue: DispatchQueue.main, handler: { _, _, _, _ in
    })
    let result = stream != nil
    return result
}

func requestScreenCaptureAccess() -> Bool {
    if #available(OSX 11.0, *) {
        if !CGPreflightScreenCaptureAccess() {
            return CGRequestScreenCaptureAccess()
        } else {
            return true
        }
    } else {
        return screenCaptureAvailable()
    }
}


func requestMediaPermission(_ type: AVFoundation.AVMediaType) -> Signal<Bool, NoError> {
    if #available(OSX 10.14, *) {
        return Signal { subscriber in
            let status = AVCaptureDevice.authorizationStatus(for: type)
            var cancelled: Bool = false
            switch status {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: type, completionHandler: { completed in
                    if !cancelled {
                        subscriber.putNext(completed)
                        subscriber.putCompletion()
                    }
                })
            case .authorized:
                subscriber.putNext(true)
                subscriber.putCompletion()
            case .denied:
                subscriber.putNext(false)
                subscriber.putCompletion()
            case .restricted:
                subscriber.putNext(false)
                subscriber.putCompletion()
            @unknown default:
                subscriber.putNext(false)
                subscriber.putCompletion()
            }
            return ActionDisposable {
                cancelled = true
            }
        } |> runOn(.concurrentDefaultQueue()) |> deliverOnMainQueue
    } else {
        return .single(true)
    }
}

enum SystemSettingsCategory : String {
    case microphone = "Privacy_Microphone"
    case camera = "Privacy_Camera"
    case storage = "Storage"
    case sharing = "Privacy_ScreenCapture"
    case accessibility = "Privacy_Accessibility"
    case notifications = "Notifications"
    case none = ""
}

func openSystemSettings(_ category: SystemSettingsCategory) {
    switch category {
    case .storage:
        //if let url = URL(string: "/System/Applications/Utilities/System%20Information.app") {
            NSWorkspace.shared.launchApplication("/System/Applications/Utilities/System Information.app")
           // [[NSWorkspace sharedWorkspace] launchApplication:@"/Applications/Safari.app"];
       // }
    case .microphone, .camera, .sharing:
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(category.rawValue)") {
            NSWorkspace.shared.open(url)
        }
    case .notifications:
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    default:
        break
    }
}

extension MessageHistoryAnchorIndex {
    func withSubstractedTimestamp(_ timestamp: Int32) -> MessageHistoryAnchorIndex {
        switch self {
        case let .message(index):
            return MessageHistoryAnchorIndex.message(MessageIndex(id: index.id, timestamp: index.timestamp - timestamp))
        default:
            return self
        }
    }
}


extension ChatContextResultCollection {
    func withAdditionalCollection(_ collection: ChatContextResultCollection) -> ChatContextResultCollection {
        return ChatContextResultCollection(botId: collection.botId, peerId: collection.peerId, query: collection.query, geoPoint: collection.geoPoint, queryId: collection.queryId, nextOffset: collection.nextOffset, presentation: collection.presentation, switchPeer: collection.switchPeer, results: self.results + collection.results, cacheTimeout: collection.cacheTimeout)
    }
}

extension LocalFileReferenceMediaResource : Equatable {
    public static func ==(lhs: LocalFileReferenceMediaResource, rhs: LocalFileReferenceMediaResource) -> Bool {
        return lhs.isEqual(to: rhs)
    }
}


public func removeFile(at path: String) {
    try? FileManager.default.removeItem(atPath: path)
}


extension FileManager {
    
    func modificationDateForFileAtPath(path:String) -> NSDate? {
        guard let attributes = try? self.attributesOfItem(atPath: path) else { return nil }
        return attributes[.modificationDate] as? NSDate
    }
    
    func creationDateForFileAtPath(path:String) -> NSDate? {
        guard let attributes = try? self.attributesOfItem(atPath: path) else { return nil }
        return attributes[.creationDate] as? NSDate
    }
    
    
}


extension MessageForwardInfo {
    var authorTitle: String {
        return author?.displayTitle ?? authorSignature ?? ""
    }
}


func bigEmojiMessage(_ sharedContext: SharedAccountContext, message: Message) -> Bool {
    let text = message.text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
    return sharedContext.baseSettings.bigEmoji && message.media.isEmpty && message.replyMarkup == nil && text.containsOnlyEmoji
}



struct PeerEquatable: Equatable {
    let peer: Peer
    init(peer: Peer) {
        self.peer = peer
    }
    init(_ peer: Peer) {
        self.peer = peer
    }
    init?(_ peer: Peer?) {
        if let peer = peer {
            self.peer = peer
        } else {
            return nil
        }
    }
    static func ==(lhs: PeerEquatable, rhs: PeerEquatable) -> Bool {
        return lhs.peer.isEqual(rhs.peer)
    }
}

struct CachedDataEquatable: Equatable {
    let data: CachedPeerData
    init?(data: CachedPeerData?) {
        if let data = data {
            self.data = data
        } else {
            return nil
        }
    }
    init?(_ data: CachedPeerData?) {
        self.init(data: data)
    }
    static func ==(lhs: CachedDataEquatable, rhs: CachedDataEquatable) -> Bool {
        return lhs.data.isEqual(to: rhs.data)
    }
}


extension CGImage {
    var cvPixelBuffer: CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer? = nil
        let options: [NSObject: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey: false,
            ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, options as CFDictionary, &pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue)
        context?.draw(self, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }
}


private let emojis: [String: (String, CGFloat)] = [
    "👍": ("thumbs_up_1", 450.0),
    "👍🏻": ("thumbs_up_2", 450.0),
    "👍🏼": ("thumbs_up_3", 450.0),
    "👍🏽": ("thumbs_up_4", 450.0),
    "👍🏾": ("thumbs_up_5", 450.0),
    "👍🏿": ("thumbs_up_6", 450.0),
    "😂": ("lol", 350.0),
    "😒": ("meh", 350.0),
    "❤️": ("heart", 350.0),
    "♥️": ("heart", 350.0),
    "🥳": ("celeb", 430.0),
    "😳": ("confused", 350.0)
]
func animatedEmojiResource(emoji: String) -> (LocalBundleResource, CGFloat)? {
    if let (name, size) = emojis[emoji] {
        return (LocalBundleResource(name: name, ext: "tgs"), size)
    } else {
        return nil
    }
}


extension TelegramMediaWebpageLoadedContent {
    func withUpdatedYoutubeTimecode(_ timecode: Double) -> TelegramMediaWebpageLoadedContent {
        var newUrl = self.url
        if let range = self.url.range(of: "t=") {
            let substr = String(newUrl[range.upperBound...])
            var parsed: String = ""
            for char in substr {
                if "0987654321".contains(char) {
                    parsed += String(char)
                } else {
                    break
                }
            }
            newUrl = newUrl.replacingOccurrences(of: parsed, with: "\(Int(timecode))", options: .caseInsensitive, range: range.lowerBound ..< newUrl.endIndex)
        } else {
            if url.contains("?") {
                newUrl = self.url + "&t=\(Int(timecode))"
            } else {
                newUrl = self.url + "?t=\(Int(timecode))"
            }
        }
        return TelegramMediaWebpageLoadedContent(url: newUrl, displayUrl: self.displayUrl, hash: self.hash, type: self.type, websiteName: self.websiteName, title: self.title, text: self.text, embedUrl: self.embedUrl, embedType: self.embedType, embedSize: self.embedSize, duration: self.duration, author: self.author, image: self.image, file: self.file, attributes: self.attributes, instantPage: self.instantPage)
    }
    func withUpdatedFile(_ file: TelegramMediaFile) -> TelegramMediaWebpageLoadedContent {
        return TelegramMediaWebpageLoadedContent(url: self.url, displayUrl: self.displayUrl, hash: self.hash, type: self.type, websiteName: self.websiteName, title: self.title, text: self.text, embedUrl: self.embedUrl, embedType: self.embedType, embedSize: self.embedSize, duration: self.duration, author: self.author, image: self.image, file: file, attributes: self.attributes, instantPage: self.instantPage)
    }
    
    var isCrossplatformTheme: Bool {
        for attr in attributes {
            switch attr {
            case let .theme(theme):
                var hasFile: Bool = false
                for file in theme.files {
                    if file.mimeType == "application/x-tgtheme-macos", !file.previewRepresentations.isEmpty {
                        hasFile = true
                    }
                }
                if let _ = theme.settings, !hasFile {
                    return true
                }
            default:
                break
            }
        }
        return false
    }
    
    var crossplatformPalette: ColorPalette? {
        for attr in attributes {
            switch attr {
            case let .theme(theme):
                return theme.settings?.palette
            default:
                break
            }
        }
        return nil
    }
    var crossplatformWallpaper: Wallpaper? {
        for attr in attributes {
            switch attr {
            case let .theme(theme):
                return theme.settings?.background?.uiWallpaper
            default:
                break
            }
        }
        return nil
    }
    
    var themeSettings: TelegramThemeSettings? {
        for attr in attributes {
            switch attr {
            case let .theme(theme):
                return theme.settings
            default:
                break
            }
        }
        return nil
    }
}

extension TelegramBaseTheme {
    var palette: ColorPalette {
        switch self {
        case .classic:
            return dayClassicPalette
        case .day:
            return whitePalette
        case .night, .tinted:
            return nightAccentPalette
        }
    }
}


extension TelegramThemeSettings {
    var palette: ColorPalette {
        return baseTheme.palette.withAccentColor(accent)
    }
    
    var accent: PaletteAccentColor {
        let messages = self.messageColors.map { NSColor(rgb: UInt32(bitPattern: $0)) }
        return PaletteAccentColor(NSColor(rgb: UInt32(bitPattern: self.accentColor)), messages)
    }
    
    var background: TelegramWallpaper? {
        if let wallpaper = self.wallpaper {
            return wallpaper
        } else {
            if self.baseTheme == .classic {
                return .builtin(WallpaperSettings())
            }
        }
        return nil
    }
    
    var desc: String {
        let wString: String
        if let wallpaper = self.wallpaper {
            wString = "\(wallpaper)"
        } else {
            wString = ""
        }
        let colors = messageColors.map { "\($0)" }.split(separator: "-").joined()
        return "\(self.accentColor)-\(self.baseTheme)-\(colors)-\(wString)"
    }
}

extension TelegramWallpaper {
    var uiWallpaper: Wallpaper {
        let t: Wallpaper
        switch self {
        case .builtin:
            t = .builtin
        case let .color(color):
            t = .color(color)
        case let .file(values):
            t = .file(slug: values.slug, file: values.file, settings: values.settings, isPattern: values.isPattern)
        case let .gradient(gradient):
            t = .gradient(gradient.id, gradient.colors, gradient.settings.rotation)
        case let .image(reps, settings):
            t = .image(reps, settings: settings)
        }
        return t
    }
}

extension Wallpaper {
    var cloudWallpaper: TelegramWallpaper? {
        switch self {
        case .builtin:
            return .builtin(WallpaperSettings())
        case let .color(color):
            return .color(color)
        case let .gradient(id, colors, rotation):
            return .gradient(.init(id: id, colors: colors, settings: WallpaperSettings(rotation: rotation)))
        default:
            break
        }
        return nil
    }
}

//
extension CachedChannelData.LinkedDiscussionPeerId {
    var peerId: PeerId? {
        switch self {
        case let .known(peerId):
            return peerId
        case .unknown:
            return nil
        }
    }
}


func permanentExportedInvitation(context: AccountContext, peerId: PeerId) -> Signal<ExportedInvitation?, NoError> {
    return context.account.postbox.transaction { transaction -> ExportedInvitation? in
        let cachedData = transaction.getPeerCachedData(peerId: peerId)
        if let cachedData = cachedData as? CachedChannelData {
            return cachedData.exportedInvitation
        }
        if let cachedData = cachedData as? CachedGroupData {
            return cachedData.exportedInvitation
        }
        return nil
    } |> mapToSignal { invitation in
        if invitation == nil {
            return context.engine.peers.revokePersistentPeerExportedInvitation(peerId: peerId)
        } else {
            return .single(invitation)
        }
    }
}




extension CachedPeerAutoremoveTimeout {
    var timeout: CachedPeerAutoremoveTimeout.Value? {
        switch self {
        case let .known(timeout):
            return timeout
        case .unknown:
            return nil
        }
    }

}



func clearHistory(context: AccountContext, peer: Peer, mainPeer: Peer, canDeleteForAll: Bool? = nil) {
    var thridTitle: String? = nil
    var canRemoveGlobally: Bool = canDeleteForAll ?? false
    if peer.id.namespace == Namespaces.Peer.CloudUser && peer.id != context.account.peerId && !peer.isBot {
        if context.limitConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
            canRemoveGlobally = true
        }
    }
    if canRemoveGlobally {
        if let peer = peer as? TelegramUser {
            thridTitle = strings().chatMessageDeleteForMeAndPerson(peer.displayTitle)
        } else {
            thridTitle = strings().chatMessageDeleteForAll
        }
    }
    
    
    let information = mainPeer is TelegramUser || mainPeer is TelegramSecretChat ? peer.id == context.peerId ? strings().peerInfoConfirmClearHistorySavedMesssages : canRemoveGlobally || peer.id.namespace == Namespaces.Peer.SecretChat ? strings().peerInfoConfirmClearHistoryUserBothSides : strings().peerInfoConfirmClearHistoryUser : strings().peerInfoConfirmClearHistoryGroup
    
    modernConfirm(for: context.window, account: context.account, peerId: mainPeer.id, information:information , okTitle: strings().peerInfoConfirmClear, thridTitle: thridTitle, thridAutoOn: false, successHandler: { result in
        _ = context.engine.messages.clearHistoryInteractively(peerId: peer.id, threadId: nil, type: result == .thrid ? .forEveryone : .forLocalPeer).start()
    })
}


func coreMessageMainPeer(_ message: Message) -> Peer? {
    return messageMainPeer(.init(message))?._asPeer()
}

func showProtectedCopyAlert(_ message: Message, for window: Window) {
    if let peer = message.peers[message.id.peerId] {
        let text: String
        if peer.isGroup || peer.isSupergroup {
            text = strings().copyRestrictedGroup
        } else {
            text = strings().copyRestrictedChannel
        }
        showModalText(for: window, text: text)
    }
}

func showProtectedCopyAlert(_ peer: Peer, for window: Window) {
    let text: String
    if peer.isGroup || peer.isSupergroup {
        text = strings().copyRestrictedGroup
    } else {
        text = strings().copyRestrictedChannel
    }
    showModalText(for: window, text: text)
}

extension Peer {
    var isCopyProtected: Bool {
        if let peer = self as? TelegramGroup {
            return peer.flags.contains(.copyProtectionEnabled) && !peer.groupAccess.isCreator
        } else if let peer = self as? TelegramChannel {
            return peer.flags.contains(.copyProtectionEnabled) && !(peer.adminRights != nil || peer.groupAccess.isCreator)
        } else {
            return false
        }
    }
    var emojiStatus: PeerEmojiStatus? {
        if let peer = self as? TelegramUser {
            return peer.emojiStatus
        }
        return nil
    }
    
}




extension ChatListFilter {
    var icon: CGImage {
        
        if let data = self.data {
            if data.categories == .all && data.excludeMuted && !data.excludeRead {
                return theme.icons.chat_filter_unmuted
            } else if data.categories == .all && !data.excludeMuted && data.excludeRead {
                return theme.icons.chat_filter_unread
            } else if data.categories == .groups {
                return theme.icons.chat_filter_groups
            } else if data.categories == .channels {
                return theme.icons.chat_filter_channels
            } else if data.categories == .contacts {
                return theme.icons.chat_filter_private_chats
            } else if data.categories == .nonContacts {
                return theme.icons.chat_filter_non_contacts
            } else if data.categories == .bots {
                return theme.icons.chat_filter_bots
            }
        }
        return theme.icons.chat_filter_custom
    }
}


extension SoftwareVideoSource {
    func preview(size: NSSize, backingScale: Int) -> CGImage? {
        let frameAndLoop = self.readFrame(maxPts: nil)
        if frameAndLoop.0 == nil {
            return nil
        }
        
        guard let frame = frameAndLoop.0 else {
            return nil
        }
        
        let s:(w: Int, h: Int) = (w: Int(size.width) * backingScale, h: Int(size.height) * backingScale)
        
        let destBytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)
        let bufferSize = s.h * DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: s.w)

        let memoryData = malloc(bufferSize)!
        let bytes = memoryData.assumingMemoryBound(to: UInt8.self)
        
        let imageBuffer = CMSampleBufferGetImageBuffer(frame.sampleBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)
        let srcData = CVPixelBufferGetBaseAddress(imageBuffer!)
        
        var sourceBuffer = vImage_Buffer(data: srcData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
        var destBuffer = vImage_Buffer(data: bytes, height: vImagePixelCount(s.h), width: vImagePixelCount(s.w), rowBytes: destBytesPerRow)
                   
        let _ = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, vImage_Flags(kvImageDoNotTile))
        
        CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return generateImagePixel(size, scale: CGFloat(backingScale), pixelGenerator: { (_, pixelData, bytesPerRow) in
            memcpy(pixelData, bytes, bufferSize)
        })
    }
}


func installAttachMenuBot(context: AccountContext, peer: Peer, completion: @escaping(Bool)->Void) {
    confirm(for: context.window, information: strings().webAppAttachConfirm(peer.displayTitle), okTitle: strings().webAppAttachConfirmOK, successHandler: { _ in
        _ = showModalProgress(signal: context.engine.messages.addBotToAttachMenu(botId: peer.id), for: context.window).start(next: { value in
            if value {
                showModalText(for: context.window, text: strings().webAppAttachSuccess(peer.displayTitle))
                completion(value)
            }
        })
    })
}


extension NSAttributedString {
    static func makeAnimated(_ file: TelegramMediaFile, text: String, info: ItemCollectionId? = nil, fromRect: NSRect? = nil) -> NSAttributedString {
        let attach = NSMutableAttributedString()
        _ = attach.append(string: text)
        attach.addAttribute(.init(rawValue: TGAnimatedEmojiAttributeName), value: TGTextAttachment(identifier: "\(arc4random())", fileId: file.fileId.id, file: file, text: text, info: info, from: fromRect ?? .zero), range: NSMakeRange(0, text.length))
        return attach
    }
    static func makeEmojiHolder(_ emoji: String, fromRect: NSRect?) -> NSAttributedString {
        let attach = NSMutableAttributedString()
        _ = attach.append(string: emoji)
        if let fromRect = fromRect, FastSettings.animateInputEmoji {
            let tag = TGInputTextEmojiHolder(uniqueId: arc4random64(), emoji: emoji, rect: fromRect, attribute: TGInputTextAttribute(name: NSAttributedString.Key.foregroundColor.rawValue, value: NSColor.clear))
            attach.addAttribute(.init(rawValue: TGEmojiHolderAttributeName), value: tag, range: NSMakeRange(0, emoji.length))
        }
        return attach
    }
}


extension String {
    var isSavedMessagesText: Bool {
        let query = self.lowercased()
        if Telegram.strings().peerSavedMessages.lowercased().hasPrefix(query) {
            return true
        }
        if NSLocalizedString("Peer.SavedMessages", comment: "nil").hasPrefix(query.lowercased()) {
            return true
        }
        return false
    }
}


func joinChannel(context: AccountContext, peerId: PeerId) {
    _ = showModalProgress(signal: context.engine.peers.joinChannel(peerId: peerId, hash: nil) |> deliverOnMainQueue, for: context.window).start(error: { error in
        let text: String
        switch error {
        case .generic:
            text = strings().unknownError
        case .tooMuchJoined:
            showInactiveChannels(context: context, source: .join)
            return
        case .tooMuchUsers:
            text = strings().groupUsersTooMuchError
        case .inviteRequestSent:
            showModalText(for: context.window, text: strings().chatSendJoinRequestInfo, title: strings().chatSendJoinRequestTitle)
            return
        }
        alert(for: context.window, info: text)
    }, completed: {
        _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
    })
}
