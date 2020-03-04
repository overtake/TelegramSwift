
//
//  CoreExtension.swift
//  Telegram-Mac
//
//  Created by keepcoder on 06/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TGUIKit
import SyncCore
import MtProtoKit


extension RenderedChannelParticipant {
    func withUpdatedBannedRights(_ info: ChannelParticipantBannedInfo) -> RenderedChannelParticipant {
        let updated: ChannelParticipant
        switch participant {
        case let.member(id, invitedAt, adminInfo, _, rank):
            updated = ChannelParticipant.member(id: id, invitedAt: invitedAt, adminInfo: adminInfo, banInfo: info, rank: rank)
        case let .creator(id, rank):
            updated = ChannelParticipant.creator(id: id, rank: rank)
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
            //EventLog.Service.Restriction.AddNewAdmins
        case TelegramChatAdminRightsFlags.canAddAdmins:
            return tr(L10n.eventLogServicePromoteAddNewAdmins)
        case TelegramChatAdminRightsFlags.canBanUsers:
            return tr(L10n.eventLogServicePromoteBanUsers)
        case TelegramChatAdminRightsFlags.canChangeInfo:
            return tr(L10n.eventLogServicePromoteChangeInfo)
        case TelegramChatAdminRightsFlags.canInviteUsers:
            return tr(L10n.eventLogServicePromoteAddUsers)
        case TelegramChatAdminRightsFlags.canDeleteMessages:
            return tr(L10n.eventLogServicePromoteDeleteMessages)
        case TelegramChatAdminRightsFlags.canEditMessages:
            return tr(L10n.eventLogServicePromoteEditMessages)
        case TelegramChatAdminRightsFlags.canPinMessages:
            return tr(L10n.eventLogServicePromotePinMessages)
        case TelegramChatAdminRightsFlags.canPostMessages:
            return tr(L10n.eventLogServicePromotePostMessages)
        default:
            return "Undefined Promotion"
        }
    }
}

extension TelegramChatBannedRightsFlags {
    var localizedString:String {
        switch self {
        case TelegramChatBannedRightsFlags.banSendGifs:
            return L10n.eventLogServiceDemoteSendGifs
        case TelegramChatBannedRightsFlags.banPinMessages:
            return L10n.eventLogServiceDemotePinMessages
        case TelegramChatBannedRightsFlags.banAddMembers:
            return L10n.eventLogServiceDemoteAddMembers
        case TelegramChatBannedRightsFlags.banSendPolls:
            return L10n.eventLogServiceDemotePostPolls
        case TelegramChatBannedRightsFlags.banEmbedLinks:
            return L10n.eventLogServiceDemoteEmbedLinks
        case TelegramChatBannedRightsFlags.banReadMessages:
            return ""
        case TelegramChatBannedRightsFlags.banSendGames:
            return L10n.eventLogServiceDemoteEmbedLinks
        case TelegramChatBannedRightsFlags.banSendInline:
            return L10n.eventLogServiceDemoteSendInline
        case TelegramChatBannedRightsFlags.banSendMedia:
            return L10n.eventLogServiceDemoteSendMedia
        case TelegramChatBannedRightsFlags.banSendMessages:
            return L10n.eventLogServiceDemoteSendMessages
        case TelegramChatBannedRightsFlags.banSendStickers:
            return L10n.eventLogServiceDemoteSendStickers
        case TelegramChatBannedRightsFlags.banChangeInfo:
            return L10n.eventLogServiceDemoteChangeInfo
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
                return L10n.channelPersmissionDeniedSendMessagesUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return L10n.channelPersmissionDeniedSendMessagesForever
            } else {
                return L10n.channelPersmissionDeniedSendMessagesDefaultRestrictedText
            }
        case .banSendStickers:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return L10n.channelPersmissionDeniedSendStickersUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return L10n.channelPersmissionDeniedSendStickersForever
            } else {
                return L10n.channelPersmissionDeniedSendStickersDefaultRestrictedText
            }
        case .banSendGifs:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return L10n.channelPersmissionDeniedSendGifsUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return L10n.channelPersmissionDeniedSendGifsForever
            } else {
                return L10n.channelPersmissionDeniedSendGifsDefaultRestrictedText
            }
        case .banSendMedia:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return L10n.channelPersmissionDeniedSendMediaUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return L10n.channelPersmissionDeniedSendMediaForever
            } else {
                return L10n.channelPersmissionDeniedSendMediaDefaultRestrictedText
            }
        case .banSendPolls:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return L10n.channelPersmissionDeniedSendPollUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return L10n.channelPersmissionDeniedSendPollForever
            } else {
                return L10n.channelPersmissionDeniedSendPollDefaultRestrictedText
            }
        case .banSendInline:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return L10n.channelPersmissionDeniedSendInlineUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return L10n.channelPersmissionDeniedSendInlineForever
            } else {
                return L10n.channelPersmissionDeniedSendInlineDefaultRestrictedText
            }
        default:
            return nil
        }
        
        
    }
    
    return nil
}

extension RenderedPeer {
    convenience init(_ foundPeer: FoundPeer) {
        self.init(peerId: foundPeer.peer.id, peers: SimpleDictionary([foundPeer.peer.id : foundPeer.peer]))
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
        return TelegramMediaFile(fileId: self.fileId, partialReference: self.partialReference, resource: resource, previewRepresentations: self.previewRepresentations, immediateThumbnailData: self.immediateThumbnailData, mimeType: self.mimeType, size: self.size, attributes: self.attributes)
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
    var elapsedSize:Int {
        if let size = size {
            return size
        }
        if let resource = resource as? LocalFileReferenceMediaResource, let size = resource.size {
            return Int(size)
        }
        return 0
    }
}

extension Media {
    var isInteractiveMedia: Bool {
        if self is TelegramMediaImage {
            return true
        } else if let file = self as? TelegramMediaFile {
            return file.isVideo || (file.isAnimated && !file.mimeType.lowercased().hasSuffix("gif"))
        } else if let map = self as? TelegramMediaMap {
            return map.venue == nil
        } else if self is TelegramMediaDice {
            return false
        }
        return false
    }
    
    var canHaveCaption: Bool {
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
    case Index(ChatListIndex, TableScrollState?)
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
    
    var stickerReference:StickerPackReference? {
        for attr in attributes {
            if case let .Sticker(_, reference, _) = attr {
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


public extension Message {
    var replyMarkup:ReplyMarkupMessageAttribute? {
        for attr in attributes {
            if let attr = attr as? ReplyMarkupMessageAttribute {
                return attr
            }
        }
        return nil
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
        if let media = self.media.first as? TelegramMediaPoll {
            return media.publicity == .public
        }
        return false
    }
    
    var isHasInlineKeyboard: Bool {
        return replyMarkup?.flags.contains(.inline) ?? false
    }
    
    func isIncoming(_ account: Account, _ isBubbled: Bool) -> Bool {
        if isBubbled, let peer = chatPeer(account.peerId), peer.isChannel {
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
        for attr in attributes {
            if let source = attr as? SourceReferenceMessageAttribute {
                if let info = forwardInfo {
                    if let peer = peers[source.messageId.peerId], peer is TelegramChannel, accountPeerId != id.peerId {
                        _peer = peer
                    } else {
                        _peer = info.author
                    }
                }
                break
            }
        }
        
        if let peer = messageMainPeer(self) as? TelegramChannel, case .broadcast(_) = peer.info {
            _peer = peer
        } else if let author = effectiveAuthor, _peer == nil {
            if author is TelegramSecretChat {
                return messageMainPeer(self)
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
        if let peer = messageMainPeer(self), peer.isBot {
            return peer
        }
        return nil
    }
    
    func withUpdatedStableId(_ stableId:UInt32) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds)
    }
    func withUpdatedId(_ messageId:MessageId) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: messageId, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds)
    }
    
    func withUpdatedGroupingKey(_ groupingKey:Int64?) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds)
    }
    
    public func withUpdatedTimestamp(_ timestamp: Int32) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, timestamp: timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: self.text, attributes: self.attributes, media: self.media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    
    func withUpdatedText(_ text:String) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds)
    }
    
    func possibilityForwardTo(_ peer:Peer) -> Bool {
        if !peer.canSendMessage {
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
        self.init(stableId: stableId, stableVersion: 0, id: messageId, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [media], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [])
    }
}

extension ChatLocation {
    var unreadMessageCountsItem: UnreadMessageCountsItem {
        switch self {
        case let .peer(peerId):
            return .peer(peerId)
        }
    }
    
    var postboxViewKey: PostboxViewKey {
        switch self {
        case let .peer(peerId):
            return .peer(peerId: peerId, components: [])
        }
    }
    
    var pinnedItemId: PinnedItemId {
        switch self {
        case let .peer(peerId):
            return .peer(peerId)
        }
    }
    
    var peerId: PeerId {
        switch self {
        case let .peer(peerId):
            return peerId
        }
    }
}

extension ChatLocation : Hashable {
    public var hashValue: Int {
        switch self {
        case let .peer(peerId):
            return peerId.hashValue
        }
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
    func toInt64() -> Int64 {
        return (Int64(id) << 32) | Int64(peerId.id)
    }
}


public extension ReplyMarkupMessageAttribute {
    var hasButtons:Bool {
        return !self.rows.isEmpty
    }
}

fileprivate let edit_limit_time:Int32 = 48*60*60

func canDeleteMessage(_ message:Message, account:Account) -> Bool {
    
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

func canForwardMessage(_ message:Message, account:Account) -> Bool {
    
    if message.peers[message.id.peerId] is TelegramSecretChat {
        return false
    }
    
    if message.flags.contains(.Failed) || message.flags.contains(.Unsent) {
        return false
    }
    if message.isScheduledMessage {
        return false
    }
    
    if message.media.first is TelegramMediaAction {
        return false
    }
    if let peer = message.peers[message.id.peerId] as? TelegramUser {
        if peer.isUser, let _ = message.autoremoveAttribute {
            return false
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
        if context.limitConfiguration.canRemoveIncomingMessagesInPrivateChats && message.peers[message.id.peerId] is TelegramUser {
            return true
        }
        if let peer = message.peers[message.id.peerId] as? TelegramGroup {
            switch peer.role {
            case .creator, .admin:
                return true
            default:
                if Int(context.limitConfiguration.maxMessageEditingInterval) + Int(message.timestamp) > Int(Date().timeIntervalSince1970) {
                    if context.account.peerId == message.effectiveAuthor?.id {
                        return !(message.media.first is TelegramMediaAction)
                    }
                }
                return false
            }
            
        } else if Int(context.limitConfiguration.maxMessageEditingInterval) + Int(message.timestamp) > Int(Date().timeIntervalSince1970) {
            if context.account.peerId == message.author?.id {
                return !(message.media.first is TelegramMediaAction)
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

func canReplyMessage(_ message: Message, peerId: PeerId) -> Bool {
    if let peer = messageMainPeer(message) {
        if message.isScheduledMessage {
            return false
        }
        if peer.canSendMessage, peerId == message.id.peerId, !message.flags.contains(.Unsent) && !message.flags.contains(.Failed) && (message.id.namespace != Namespaces.Message.Local || message.id.peerId.namespace == Namespaces.Peer.SecretChat) {
            return true
        }
    }
    return false
}

func canEditMessage(_ message:Message, context: AccountContext) -> Bool {
    if message.forwardInfo != nil {
        return false
    }
    
    if message.flags.contains(.Unsent) || message.flags.contains(.Failed) || message.id.namespace == Namespaces.Message.Local {
        return false
    }
    
    if message.peers[message.id.peerId] is TelegramSecretChat {
        return false
    }
    
    if let media = message.media.first {
        if let file = media as? TelegramMediaFile {
            if file.isStaticSticker || (file.isAnimatedSticker && !file.isEmojiAnimatedSticker) {
                return false
            }
            if file.isInstantVideo {
                return false
            }
            if file.isVoice {
                return false
            }
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
        if media is TelegramMediaPoll {
            return false
        }
    }
    
    for attr in message.attributes {
        if attr is InlineBotMessageAttribute {
            return false
        } else if attr is AutoremoveTimeoutMessageAttribute {
            return false
        }
    }
    
    if let peer = messageMainPeer(message) as? TelegramChannel {
        if case .broadcast = peer.info {
            return (peer.hasPermission(.sendMessages) || peer.hasPermission(.editAllMessages)) && Int(message.timestamp) + Int(context.limitConfiguration.maxMessageEditingInterval) > Int(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        } else if case .group = peer.info {
            if !message.flags.contains(.Incoming) {
                if peer.hasPermission(.pinMessages) {
                    return true
                }
                return Int(message.timestamp) + Int(context.limitConfiguration.maxMessageEditingInterval) > Int(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            }
        }
    }
    
    if message.id.peerId == context.account.peerId {
        return true
    }
    
    
    if message.flags.contains(.Incoming) {
        return false
    }
    
    
    if Int(message.timestamp) + Int(context.limitConfiguration.maxMessageEditingInterval) < Int(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
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
    if let peer = messageMainPeer(message), message.author?.id != account.peerId {
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
                if peerId != message.author?.id {
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
            return media.mimeType.hasPrefix("image") && (media.mimeType.contains("png") || media.mimeType.contains("jpg") || media.mimeType.contains("jpeg") || media.mimeType.contains("tiff"))
        }
        return false
    }
    var isVideoFile:Bool {
        if let media = self as? TelegramMediaFile {
            return media.mimeType.hasPrefix("video/mp4") || media.mimeType.hasPrefix("video/mov") || media.mimeType.hasPrefix("video/avi")
        }
        return false
    }
}

extension AddressNameFormatError {
    var description:String {
        switch self {
        case .startsWithUnderscore:
            return tr(L10n.errorUsernameUnderscopeStart)
        case .endsWithUnderscore:
            return tr(L10n.errorUsernameUnderscopeEnd)
        case .startsWithDigit:
            return tr(L10n.errorUsernameNumberStart)
        case .invalidCharacters:
            return tr(L10n.errorUsernameInvalid)
        case .tooShort:
            return tr(L10n.errorUsernameMinimumLength)
        }
    }
}

extension AddressNameAvailability {

    func description(for username: String) -> String {
        switch self {
        case .available:
            return L10n.usernameSettingsAvailable(username)
        case .invalid:
            return L10n.errorUsernameInvalid
        case .taken:
            return L10n.errorUsernameAlreadyTaken
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
            return L10n.secureIdRequestPermissionEmail
        case .phone:
            return L10n.secureIdRequestPermissionPhone
        case .passport:
            return L10n.secureIdRequestPermissionPassport
        case .address:
            return L10n.secureIdRequestPermissionResidentialAddress
        case .personalDetails:
            return L10n.secureIdRequestPermissionPersonalDetails
        case .driversLicense:
            return L10n.secureIdRequestPermissionDriversLicense
        case .utilityBill:
            return L10n.secureIdRequestPermissionUtilityBill
        case .rentalAgreement:
            return L10n.secureIdRequestPermissionTenancyAgreement
        case .idCard:
            return L10n.secureIdRequestPermissionIDCard
        case .bankStatement:
            return L10n.secureIdRequestPermissionBankStatement
        case .internalPassport:
            return L10n.secureIdRequestPermissionInternalPassport
        case .passportRegistration:
            return L10n.secureIdRequestPermissionPassportRegistration
        case .temporaryRegistration:
            return L10n.secureIdRequestPermissionTemporaryRegistration
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
            return L10n.secureIdRequestPermissionEmail
        case .phone:
            return L10n.secureIdRequestPermissionPhone
        case .address:
            return L10n.secureIdRequestPermissionResidentialAddress
        case .utilityBill:
            return L10n.secureIdRequestPermissionUtilityBill
        case .bankStatement:
            return L10n.secureIdRequestPermissionBankStatement
        case .rentalAgreement:
            return L10n.secureIdRequestPermissionTenancyAgreement
        case .passport:
            return L10n.secureIdRequestPermissionPassport
        case .idCard:
            return L10n.secureIdRequestPermissionIDCard
        case .driversLicense:
            return L10n.secureIdRequestPermissionDriversLicense
        case .personalDetails:
            return L10n.secureIdRequestPermissionPersonalDetails
        case .internalPassport:
            return L10n.secureIdRequestPermissionInternalPassport
        case .passportRegistration:
            return L10n.secureIdRequestPermissionPassportRegistration
        case .temporaryRegistration:
            return L10n.secureIdRequestPermissionTemporaryRegistration
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
            return L10n.secureIdUploadFront
        case .driversLicense:
            return L10n.secureIdUploadFront
        default:
            return L10n.secureIdUploadMain
        }
    }
    var uploadBackTitleText: String {
        switch self {
        case .idCard:
            return L10n.secureIdUploadReverse
        case .driversLicense:
            return L10n.secureIdUploadReverse
        default:
            return L10n.secureIdUploadMain
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
            return L10n.secureIdRequestPermissionEmailEmpty
        case .phone:
            return L10n.secureIdRequestPermissionPhoneEmpty
        case .utilityBill:
            return L10n.secureIdEmptyDescriptionUtilityBill
        case .bankStatement:
            return L10n.secureIdEmptyDescriptionBankStatement
        case .rentalAgreement:
            return L10n.secureIdEmptyDescriptionTenancyAgreement
        case .passportRegistration:
            return L10n.secureIdEmptyDescriptionPassportRegistration
        case .temporaryRegistration:
            return L10n.secureIdEmptyDescriptionTemporaryRegistration
        case .passport:
            return L10n.secureIdEmptyDescriptionPassport
        case .driversLicense:
            return L10n.secureIdEmptyDescriptionDriversLicense
        case .idCard:
            return L10n.secureIdEmptyDescriptionIdentityCard
        case .internalPassport:
            return L10n.secureIdEmptyDescriptionInternalPassport
        case .personalDetails:
            return L10n.secureIdEmptyDescriptionPersonalDetails
        case .address:
            return L10n.secureIdEmptyDescriptionAddress
        }
    }
    
    var descAdd: String {
        switch self {
        case .email:
            return ""
        case .phone:
            return ""
        case .address:
            return L10n.secureIdAddResidentialAddress
        case .utilityBill:
            return L10n.secureIdAddUtilityBill
        case .bankStatement:
            return L10n.secureIdAddBankStatement
        case .rentalAgreement:
            return L10n.secureIdAddTenancyAgreement
        case .passport:
            return L10n.secureIdAddPassport
        case .idCard:
            return L10n.secureIdAddID
        case .driversLicense:
            return L10n.secureIdAddDriverLicense
        case .personalDetails:
            return L10n.secureIdAddPersonalDetails
        case .internalPassport:
            return L10n.secureIdAddInternalPassport
        case .passportRegistration:
            return L10n.secureIdAddPassportRegistration
        case .temporaryRegistration:
            return L10n.secureIdAddTemporaryRegistration
        }
    }
    
    var descEdit: String {
        switch self {
        case .email:
            return ""
        case .phone:
            return ""
        case .address:
            return L10n.secureIdEditResidentialAddress
        case .utilityBill:
            return L10n.secureIdEditUtilityBill
        case .bankStatement:
            return L10n.secureIdEditBankStatement
        case .rentalAgreement:
            return L10n.secureIdEditTenancyAgreement
        case .passport:
            return L10n.secureIdEditPassport
        case .idCard:
            return L10n.secureIdEditID
        case .driversLicense:
            return L10n.secureIdEditDriverLicense
        case .personalDetails:
            return L10n.secureIdEditPersonalDetails
        case .internalPassport:
            return L10n.secureIdEditInternalPassport
        case .passportRegistration:
            return L10n.secureIdEditPassportRegistration
        case .temporaryRegistration:
            return L10n.secureIdEditTemporaryRegistration
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


func removeChatInteractively(context: AccountContext, peerId:PeerId, userId: PeerId? = nil, deleteGroup: Bool = false) -> Signal<Bool, NoError> {
    return context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue |> mapToSignal { peer -> Signal<Bool, NoError> in
        let text:String
        var okTitle: String? = nil
        if let peer = peer as? TelegramChannel {
            switch peer.info {
            case .broadcast:
                if peer.flags.contains(.isCreator) && deleteGroup {
                    text = L10n.confirmDeleteAdminedChannel
                    okTitle = L10n.confirmDelete
                } else {
                    text = L10n.peerInfoConfirmLeaveChannel
                }
            case .group:
                if deleteGroup && peer.flags.contains(.isCreator) {
                    text = L10n.peerInfoConfirmDeleteGroupConfirmation
                    okTitle = L10n.confirmDelete
                } else {
                    text = L10n.confirmLeaveGroup
                    okTitle = L10n.peerInfoConfirmLeave
                }
            }
        } else if let peer = peer as? TelegramGroup {
            text = L10n.peerInfoConfirmDeleteChat(peer.title)
            okTitle = L10n.confirmDelete
        } else {
            text = L10n.peerInfoConfirmDeleteUserChat
            okTitle = L10n.confirmDelete
        }
        
        
        let type: ChatUndoActionType
        
        if let peer = peer as? TelegramChannel {
            switch peer.info {
            case .broadcast:
                if peer.flags.contains(.isCreator) && deleteGroup {
                    type = .deleteChannel
                } else {
                    type = .leftChannel
                }
            case .group:
                if peer.flags.contains(.isCreator) && deleteGroup {
                    type = .deleteChat
                } else {
                    type = .leftChat
                }
            }
        } else {
            type = .deleteChat
        }
        
        var thridTitle: String? = nil
        
        var canRemoveGlobally: Bool = false
        if peerId.namespace == Namespaces.Peer.CloudUser && peerId != context.account.peerId && !peer.isBot {
            if context.limitConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
                canRemoveGlobally = true
            }
        }
        
        if canRemoveGlobally {
            thridTitle = L10n.chatMessageDeleteForMeAndPerson(peer.displayTitle)
        } else if peer.isBot {
            thridTitle = L10n.peerInfoStopBot
        }

        
        return modernConfirmSignal(for: mainWindow, account: context.account, peerId: userId ?? peerId, information: text, okTitle: okTitle ?? L10n.alertOK, thridTitle: thridTitle, thridAutoOn: false) |> mapToSignal { result -> Signal<Bool, NoError> in
            
            context.sharedContext.bindings.mainController().chatList.addUndoAction(ChatUndoAction(peerId: peerId, type: type, action: { status in
                switch status {
                case .success:
                    context.chatUndoManager.removePeerChat(account: context.account, peerId: peerId, type: type, reportChatSpam: false, deleteGloballyIfPossible: deleteGroup || result == .thrid)
                    if peer.isBot && result == .thrid {
                        _ = context.blockedPeersContext.add(peerId: peerId).start()
                    }
                default:
                    break
                }
            }))
                        
            return .single(true)
        }
    }

}

func applyExternalProxy(_ server:ProxyServerSettings, accountManager: AccountManager) {
    var textInfo = L10n.proxyForceEnableTextIP(server.host) + "\n" + L10n.proxyForceEnableTextPort(Int(server.port))
    switch server.connection {
    case let .socks5(username, password):
        if let user = username {
            textInfo += "\n" + L10n.proxyForceEnableTextUsername(user)
        }
        if let pass = password {
            textInfo += "\n" + L10n.proxyForceEnableTextPassword(pass)
        }
    case let .mtp(secret):
        textInfo += "\n" + L10n.proxyForceEnableTextSecret(MTProxySecret.parseData(secret)?.serializeToString() ?? "")
    }
   
    textInfo += "\n\n" + L10n.proxyForceEnableText
   
    if case .mtp = server.connection {
        textInfo += "\n\n" + L10n.proxyForceEnableMTPDesc
    }
    
    modernConfirm(for: mainWindow, account: nil, peerId: nil, header: L10n.proxyForceEnableHeader1, information: textInfo, okTitle: L10n.proxyForceEnableOK, thridTitle: L10n.proxyForceEnableEnable, successHandler: { result in
        _ = updateProxySettingsInteractively(accountManager: accountManager, { current -> ProxySettings in
            
            var current = current.withAddedServer(server)
            if result == .thrid {
                current = current.withUpdatedActiveServer(server).withUpdatedEnabled(true)
            }
            return current
        }).start()
    })
    
//    _ = (confirmSignal(for: mainWindow, header: tr(L10n.proxyForceEnableHeader), information: textInfo, okTitle: L10n.proxyForceEnableConnect)
//        |> filter {$0} |> map {_ in} |> mapToSignal {
//            return updateProxySettingsInteractively(postbox: postbox, network: network, { current -> ProxySettings in
//                return current.withAddedServer(server).withUpdatedActiveServer(server).withUpdatedEnabled(true)
//            })
//    }).start()
}


extension SecureIdGender {
    var stringValue: String {
        switch self {
        case .female:
            return L10n.secureIdGenderFemale
        case .male:
            return L10n.secureIdGenderMale
        }
    }
}

extension SecureIdDate {
    var stringValue: String {
        return "\(day).\(month).\(year)"
    }
}



func clearCache(_ path: String, excludes: [(partial: String, complete: String)]) -> Signal<Void, NoError> {
    return Signal { subscriber -> Disposable in
        
        let fileManager = FileManager.default
        var enumerator = fileManager.enumerator(atPath: path + "/")
        
        while let file = enumerator?.nextObject() as? String {
            if file != "cache" {
                if excludes.filter ({ file.contains($0.partial.nsstring.lastPathComponent) || file.contains($0.complete.nsstring.lastPathComponent) }).isEmpty {
                    unlink(path + "/" + file)
                }
            }
        }
        
        var p = path.nsstring.substring(to: path.nsstring.range(of: path.nsstring.lastPathComponent).location)
        p = p.nsstring.substring(to: p.nsstring.range(of: p.nsstring.lastPathComponent).location) + "cached/"
        
        enumerator = fileManager.enumerator(atPath: p)
        
        while let file = enumerator?.nextObject() as? String {
            
            
            if excludes.filter ({ file.contains($0.partial) || file.contains($0.complete) }).isEmpty {
                unlink(p + file)
            }
            //try? fileManager.removeItem(atPath: p + file)
        }
        
        subscriber.putNext(Void())
        subscriber.putCompletion()
        return EmptyDisposable
    } |> runOn(resourcesQueue)
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
        
        let wallpapers = "~/Library/Group Containers/\(ApiEnvironment.group)/Wallpapers/".nsstring.expandingTildeInPath
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: wallpapers), withIntermediateDirectories: true, attributes: nil)
        
        let out = wallpapers + "/" + resource.id.uniqueId + "\(settings.stringValue)" + ".jpg"
        
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
        if let top = self.color {
            value += "ctop\(top)"
        }
        if let top = self.bottomColor {
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
   
    return "~/Library/Group Containers/\(ApiEnvironment.group)/Wallpapers/".nsstring.expandingTildeInPath + "/" + resource.id.uniqueId + "\(settings.stringValue)" + ".jpg"
}


func canCollagesFromUrl(_ urls:[URL]) -> Bool {
    var canCollage: Bool = urls.count > 1 && urls.count <= 10
    if canCollage {
        for url in urls {
            let mime = MIMEType(url.path)
            let attrs = Sender.fileAttributes(for: mime, path: url.path, isMedia: true)
            let isGif = attrs.contains(where: { attr -> Bool in
                switch attr {
                case .Animated:
                    return true
                default:
                    return false
                }
            })
            if mime.hasPrefix("image"), let image = NSImage(contentsOf: url) {
                if image.size.width / 10 > image.size.height || image.size.height < 40 {
                    canCollage = false
                    break
                }
            }
            if (!photoExts.contains(url.pathExtension.lowercased()) && !videoExts.contains(url.pathExtension.lowercased())) || isGif {
                canCollage = false
                break
            }
        }
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
            let size = Int32(media.size ?? 0)
            
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
        
        if let peer = messageMainPeer(message) {
            if let _ = message.media.first as? TelegramMediaImage {
                return ability(categories.photo, peer)
            } else if let media = message.media.first as? TelegramMediaFile {
                return checkFile(media, peer, categories)
            } else if let media = message.media.first as? TelegramMediaWebpage {
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
            } else if let media = message.media.first as? TelegramMediaGame {
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

func proxySettings(accountManager: AccountManager) -> Signal<ProxySettings, NoError>  {
    return accountManager.sharedData(keys: [SharedDataKeys.proxySettings]) |> map { view in
        return view.entries[SharedDataKeys.proxySettings] as? ProxySettings ?? ProxySettings.defaultSettings
    }
}

public extension ProxySettings {
    public func withUpdatedActiveServer(_ activeServer: ProxyServerSettings?) -> ProxySettings {
        return ProxySettings(enabled: self.enabled, servers: servers, activeServer: activeServer, useForCalls: self.useForCalls)
    }
    
    public func withUpdatedEnabled(_ enabled: Bool) -> ProxySettings {
        return ProxySettings(enabled: enabled, servers: self.servers, activeServer: self.activeServer, useForCalls: self.useForCalls)
    }
    
    public func withAddedServer(_ proxy: ProxyServerSettings) -> ProxySettings {
        var servers = self.servers
        if servers.first(where: {$0 == proxy}) == nil {
            servers.append(proxy)
        }
        return ProxySettings(enabled: self.enabled, servers: servers, activeServer: self.activeServer, useForCalls: self.useForCalls)
    }
    
    public func withUpdatedServer(_ current: ProxyServerSettings, with updated: ProxyServerSettings) -> ProxySettings {
        var servers = self.servers
        if let index = servers.index(where: {$0 == current}) {
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
    
    public func withUpdatedUseForCalls(_ enable: Bool) -> ProxySettings {
        return ProxySettings(enabled: self.enabled, servers: servers, activeServer: self.activeServer, useForCalls: enable)
    }
    
    public func withRemovedServer(_ proxy: ProxyServerSettings) -> ProxySettings {
        var servers = self.servers
        var activeServer = self.activeServer
        var enabled: Bool = self.enabled
        if let index = servers.index(where: {$0 == proxy}) {
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
        return TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(100, 100), resource: document.resource)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
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
    
    _ = showModalProgress(signal: webpagePreview(account: context.account, url: dest.url + language) |> deliverOnMainQueue, for: context.window).start(next: { webpage in
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


extension MessageIndex {
    func withUpdatedTimestamp(_ timestamp: Int32) -> MessageIndex {
        return MessageIndex(id: self.id, timestamp: timestamp)
    }
    init(_ message: Message) {
        self.init(id: message.id, timestamp: message.timestamp)
    }
    
}

func requestAudioPermission() -> Signal<Bool, NoError> {
    if #available(OSX 10.14, *) {
        return Signal { subscriber in
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            var cancelled: Bool = false
            switch status {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio, completionHandler: { completed in
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
            }
            return ActionDisposable {
                cancelled = true
            }
        }
    } else {
        return .single(true)
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
        }
    } else {
        return .single(true)
    }
}

enum SystemSettingsCategory : String {
    case microphone = "Privacy_Microphone"
    case none = ""
}

func openSystemSettings(_ category: SystemSettingsCategory) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(category.rawValue)") {
        NSWorkspace.shared.open(url)
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
    return sharedContext.baseSettings.bigEmoji && message.media.isEmpty && message.replyMarkup == nil && message.text.count <= 3 && message.text.containsOnlyEmoji
}



struct PeerEquatable: Equatable {
    let peer: Peer
    init(peer: Peer) {
        self.peer = peer
    }
    init(_ peer: Peer) {
        self.peer = peer
    }
    static func ==(lhs: PeerEquatable, rhs: PeerEquatable) -> Bool {
        return lhs.peer.isEqual(rhs.peer)
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
            newUrl = newUrl.replacingOccurrences(of: parsed, with: "\(timecode)", options: .caseInsensitive, range: range.lowerBound ..< newUrl.endIndex)
        } else {
            if url.contains("?") {
                newUrl = self.url + "&t=\(timecode)"
            } else {
                newUrl = self.url + "?t=\(timecode)"
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
        case .night:
            return darkPalette
        case .tinted:
            return nightAccentPalette
        }
    }
}
extension TelegramThemeSettings {
    var palette: ColorPalette {
        return baseTheme.palette.withAccentColor(accent)
    }
    
    var accent: PaletteAccentColor {
        var messages: (top: NSColor, bottom: NSColor)?
        if let message = self.messageColors {
            let top = NSColor(argb: UInt32(bitPattern: message.top))
            let bottom = NSColor(argb: UInt32(bitPattern: message.bottom))
            messages = (top: top, bottom: bottom)
        } else {
            messages = nil
        }
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
        return "\(self.accentColor)-\(self.baseTheme)-\(String(describing: self.messageColors?.top))-\(String(describing: self.messageColors?.bottom))-\(wString)"
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
        case let .gradient(top, bottom, settings):
            t = .gradient(top, bottom, settings.rotation)
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
        case let .gradient(top, bottom, rotation):
            return .gradient(top, bottom, WallpaperSettings(rotation: rotation))
        default:
            break
        }
        return nil
    }
}

//
