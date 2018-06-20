
//
//  CoreExtension.swift
//  Telegram-Mac
//
//  Created by keepcoder on 06/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit
extension Peer {
    
    var mediaRestricted:Bool {
        if let peer = self as? TelegramChannel {
            if peer.hasBannedRights(.banSendMedia) {
                return true
            }
        }
        return false
    }
    
    var stickersRestricted: Bool {
        if let peer = self as? TelegramChannel {
            if peer.hasBannedRights([.banSendStickers, .banSendGifs]) {
                return true
            }
        }
        return false
    }
    
    var inlineRestricted: Bool {
        if let peer = self as? TelegramChannel {
            if peer.hasBannedRights([.banSendInline]) {
                return true
            }
        }
        return false
    }
    
    var webUrlRestricted: Bool {
        if let peer = self as? TelegramChannel {
            if peer.hasBannedRights([.banEmbedLinks]) {
                return true
            }
        }
        return false
    }
    
    
    var canSendMessage: Bool {
        if let channel = self as? TelegramChannel {
            if case .broadcast(_) = channel.info {
                return channel.hasAdminRights(.canPostMessages)
            } else if case .group = channel.info  {
                switch channel.participationStatus {
                case .member:
                    return !channel.hasBannedRights(.banSendMessages)
                default:
                    return false
                }
            }
        } else if let group = self as? TelegramGroup {
            return group.membership == .Member
        } else if let secret = self as? TelegramSecretChat {
            switch secret.embeddedState {
            case .terminated:
                return false
            case .handshake:
                return false
            default:
                return true
            }
        }
        
        return true
    }
    
    var username:String? {
        if let peer = self as? TelegramChannel {
            return peer.username
        } else if let peer = self as? TelegramGroup {
            return peer.username
        } else if let peer = self as? TelegramUser {
            return peer.username
        }
        return nil
    }
    
    public var displayTitle: String {
        switch self {
        case let user as TelegramUser:
            return user.name.isEmpty ? tr(L10n.peerDeletedUser) : user.name
        case let group as TelegramGroup:
            return group.title
        case let channel as TelegramChannel:
            return channel.title
        default:
            return ""
        }
    }
    
    public var compactDisplayTitle: String {
        switch self {
        case let user as TelegramUser:
            if let firstName = user.firstName {
                return firstName
            } else if let lastName = user.lastName {
                return lastName
            } else {
                return tr(L10n.peerDeletedUser)
            }
        case let group as TelegramGroup:
            return group.title
        case let channel as TelegramChannel:
            return channel.title
        default:
            return ""
        }
    }

    public var displayLetters: [String] {
        switch self {
        case let user as TelegramUser:
            if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty && !lastName.isEmpty {
                return [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased(), lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
            } else if let firstName = user.firstName, !firstName.isEmpty {
                return [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased()]
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return [lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
            } else {
                let name = tr(L10n.peerDeletedUser)
                if !name.isEmpty {
                    return [name.substring(to: name.index(after: name.startIndex)).uppercased()]
                }
            }
            
            return []
        case let group as TelegramGroup:
            if group.title.startIndex != group.title.endIndex {
                return [group.title.substring(to: group.title.index(after: group.title.startIndex)).uppercased()]
            } else {
                return []
            }
        case let channel as TelegramChannel:
            if channel.title.startIndex != channel.title.endIndex {
                return [channel.title.substring(to: channel.title.index(after: channel.title.startIndex)).uppercased()]
            } else {
                return []
            }
        default:
            return []
        }
    }

    var isVerified: Bool {
        if let peer = self as? TelegramUser {
            return peer.flags.contains(.isVerified)
        } else if let peer = self as? TelegramChannel {
            return peer.flags.contains(.isVerified)
        } else {
            return false
        }
    }
    
}

extension AdminLogEventsFlags {
    
    /*
     "ChannelEventFilter.NewRestrictions" = "New Restrictions";
     "ChannelEventFilter.NewAdmins" = "New Admins";
     "ChannelEventFilter.NewMembers" = "New Members";
     "ChannelEventFilter.GroupInfo" = "Group Info";
     "ChannelEventFilter.DeletedMessages" = "Deleted Messages";
     "ChannelEventFilter.EditedMessages" = "Edited Messages";
     "ChannelEventFilter.PinnedMessages" = "Pinned Messages";
     "ChannelEventFilter.LeavingMembers" = "Leaving Members";
 */
    
    
}

extension RenderedChannelParticipant {
    func withUpdatedBannedRights(_ info: ChannelParticipantBannedInfo) -> RenderedChannelParticipant {
        let updated: ChannelParticipant
        switch participant {
        case let.member(id, invitedAt, adminInfo, _):
            updated = ChannelParticipant.member(id: id, invitedAt: invitedAt, adminInfo: adminInfo, banInfo: info)
        case let.creator(id):
            updated = ChannelParticipant.creator(id: id)
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

extension TelegramChannelAdminRightsFlags {
    var localizedString:String {
        switch self {
            //EventLog.Service.Restriction.AddNewAdmins
        case TelegramChannelAdminRightsFlags.canAddAdmins:
            return tr(L10n.eventLogServicePromoteAddNewAdmins)
        case TelegramChannelAdminRightsFlags.canBanUsers:
            return tr(L10n.eventLogServicePromoteBanUsers)
        case TelegramChannelAdminRightsFlags.canChangeInfo:
            return tr(L10n.eventLogServicePromoteChangeInfo)
        case TelegramChannelAdminRightsFlags.canInviteUsers:
            return tr(L10n.eventLogServicePromoteAddUsers)
        case TelegramChannelAdminRightsFlags.canChangeInviteLink:
            return tr(L10n.eventLogServicePromoteInviteViaLink)
        case TelegramChannelAdminRightsFlags.canDeleteMessages:
            return tr(L10n.eventLogServicePromoteDeleteMessages)
        case TelegramChannelAdminRightsFlags.canEditMessages:
            return tr(L10n.eventLogServicePromoteEditMessages)
        case TelegramChannelAdminRightsFlags.canPinMessages:
            return tr(L10n.eventLogServicePromotePinMessages)
        case TelegramChannelAdminRightsFlags.canPostMessages:
            return tr(L10n.eventLogServicePromotePostMessages)
        default:
            return "Undefined Promotion"
        }
    }
}

extension TelegramChannelBannedRightsFlags {
    var localizedString:String {
        switch self {
        case TelegramChannelBannedRightsFlags.banSendGifs:
            return tr(L10n.eventLogServiceDemoteSendStickers)
        case TelegramChannelBannedRightsFlags.banEmbedLinks:
            return tr(L10n.eventLogServiceDemoteEmbedLinks)
        case TelegramChannelBannedRightsFlags.banReadMessages:
            return ""
        case TelegramChannelBannedRightsFlags.banSendGames:
            return tr(L10n.eventLogServiceDemoteEmbedLinks)
        case TelegramChannelBannedRightsFlags.banSendInline:
            return tr(L10n.eventLogServiceDemoteSendInline)
        case TelegramChannelBannedRightsFlags.banSendMedia:
            return tr(L10n.eventLogServiceDemoteSendMedia)
        case TelegramChannelBannedRightsFlags.banSendMessages:
            return tr(L10n.eventLogServiceDemoteSendMessages)
        case TelegramChannelBannedRightsFlags.banSendStickers:
            return tr(L10n.eventLogServiceDemoteSendStickers)
        default:
            return ""
        }
    }
}
/*
 public struct TelegramChannelBannedRightsFlags: OptionSet {
 public var rawValue: Int32
 
 public init(rawValue: Int32) {
 self.rawValue = rawValue
 }
 
 public init() {
 self.rawValue = 0
 }
 
 public static let banReadMessages = TelegramChannelBannedRightsFlags(rawValue: 1 << 0)
 public static let banSendMessages = TelegramChannelBannedRightsFlags(rawValue: 1 << 1)
 public static let banSendMedia = TelegramChannelBannedRightsFlags(rawValue: 1 << 2)
 public static let banSendStickers = TelegramChannelBannedRightsFlags(rawValue: 1 << 3)
 public static let banSendGifs = TelegramChannelBannedRightsFlags(rawValue: 1 << 4)
 public static let banSendGames = TelegramChannelBannedRightsFlags(rawValue: 1 << 5)
 public static let banSendInline = TelegramChannelBannedRightsFlags(rawValue: 1 << 6)
 public static let banEmbedLinks = TelegramChannelBannedRightsFlags(rawValue: 1 << 7)
 }
 */

extension TelegramChannelBannedRights {
    var formattedUntilDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        //formatter.timeZone = NSTimeZone.local
        
        formatter.timeZone = NSTimeZone.local
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(untilDate)))
    }
}

func alertForMediaRestriction(_ peer:Peer) {
    if let peer = peer as? TelegramChannel, let bannedRights = peer.bannedRights {
        alert(for: mainWindow, info: bannedRights.untilDate != .max ? tr(L10n.channelPersmissionDeniedSendMediaUntil(bannedRights.formattedUntilDate)) : tr(L10n.channelPersmissionDeniedSendMediaForever))
    }
}


extension TelegramMediaFile {
    var videoSize:NSSize {
        for attr in attributes {
            if case let .Video(_,size, _) = attr {
                return size
            }
        }
        return NSZeroSize
    }
    
    var imageSize:NSSize {
        for attr in attributes {
            if case let .ImageSize(size) = attr {
                return size
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

extension Account {
    var context:TelegramApplicationContext {
        return self.applicationContext as! TelegramApplicationContext
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
            return file.isVideo || file.isAnimated
        } else if let map = self as? TelegramMediaMap {
            return map.venue == nil
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
            case .muted:
                return true
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
        case .muted:
            return true
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

public extension MessageHistoryEntry {
    var location:MessageHistoryEntryLocation? {
        switch self {
        case let .MessageEntry(_, _, location, _):
            return location
        case let .HoleEntry(_, location):
            return location
        }
    }
    
    var message:Message? {
        switch self {
        case let .MessageEntry(message, _, _, _):
            return message
        default:
            return nil
        }
    }
}

public extension MessageHistoryView {
    func index(for messageId: MessageId) -> Int? {
        for i in 0 ..< entries.count {
            switch entries[i] {
            case let .MessageEntry(lhsMessage,_, _, _):
                if lhsMessage.id == messageId {
                    return i
                }
            default:
                break
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
    
    var isHasInlineKeyboard: Bool {
        return replyMarkup?.flags.contains(.inline) ?? false
    }
    
    func isIncoming(_ account: Account, _ isBubbled: Bool) -> Bool {
        if isBubbled, let peer = chatPeer, peer.isChannel {
            return true
        }
        
        if id.peerId == account.peerId {
            if let forward = forwardInfo {
                return true
            }
            return false
        }
        return flags.contains(.Incoming)
    }
    
    var chatPeer: Peer? {
        var _peer: Peer?
        for attr in attributes {
            if let _ = attr as? SourceReferenceMessageAttribute {
                if let info = forwardInfo {
                    _peer = info.author
                }
                break
            }
        }
        
        if let peer = messageMainPeer(self) as? TelegramChannel, case .broadcast(_) = peer.info {
            _peer = peer
        } else if let author = author, _peer == nil {
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
    
    
    func withUpdatedText(_ text:String) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds)
    }
    
    func possibilityForwardTo(_ peer:Peer) -> Bool {
        if !peer.canSendMessage {
            return false
        } else if let peer = peer as? TelegramChannel {
            if let media = media.first, !(media is TelegramMediaWebpage) {
                if let media = media as? TelegramMediaFile {
                    if media.isSticker {
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
        case let .group(groupId):
            return .group(groupId)
        case let .peer(peerId):
            return .peer(peerId)
        }
    }
    
    var postboxViewKey: PostboxViewKey {
        switch self {
        case let .peer(peerId):
            return .peer(peerId: peerId)
        case let .group(groupId):
            return .chatListTopPeers(groupId: groupId)
        }
    }
    
    var pinnedItemId: PinnedItemId {
        switch self {
        case let .peer(peerId):
            return .peer(peerId)
        case let .group(groupId):
            return .group(groupId)
        }
    }
    
    var peerId: PeerId? {
        switch self {
        case .group:
            return nil
        case let .peer(peerId):
            return peerId
        }
    }
    var groupId: PeerGroupId? {
        switch self {
        case let .group(groupId):
            return groupId
        case .peer:
            return nil
        }
    }
}

extension ChatLocation : Hashable {
    public var hashValue: Int {
        switch self {
        case let .group(groupId):
            return groupId.hashValue
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
                return channel.hasAdminRights(.canPostMessages)
            }
            return channel.hasAdminRights(.canDeleteMessages)
        }
        return channel.hasAdminRights(.canDeleteMessages) || !message.flags.contains(.Incoming)
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

func canDeleteForEveryoneMessage(_ message:Message, account:Account) -> Bool {
    if message.peers[message.id.peerId] is TelegramChannel || message.peers[message.id.peerId] is TelegramSecretChat {
        return false
    } else if message.peers[message.id.peerId] is TelegramUser || message.peers[message.id.peerId] is TelegramGroup {
        if message.author?.id == account.peerId && edit_limit_time + message.timestamp > Int32(Date().timeIntervalSince1970) {
            if account.peerId != messageMainPeer(message)?.id {
                return !(message.media.first is TelegramMediaAction)
            }
        } else if let peer = message.peers[message.id.peerId] as? TelegramGroup {
            switch peer.role {
            case .creator, .admin:
                return true
            default:
                return false
            }
            
        }
    }
    return false
}

func canReplyMessage(_ message: Message, peerId: PeerId) -> Bool {
    if let peer = messageMainPeer(message) {
        if peer.canSendMessage, peerId == message.id.peerId, !message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
            return true
        }
    }
    return false
}

func canEditMessage(_ message:Message, account:Account) -> Bool {
    if message.forwardInfo != nil {
        return false
    }
    
    if message.flags.contains(.Unsent) || message.flags.contains(.Failed) {
        return false
    }
    
    if message.peers[message.id.peerId] is TelegramSecretChat {
        return false
    }
    
    if let media = message.media.first {
        if let file = media as? TelegramMediaFile {
            if file.isSticker {
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
    }
    
    for attr in message.attributes {
        if attr is InlineBotMessageAttribute {
            return false
        } else if attr is AutoremoveTimeoutMessageAttribute {
            return false
        }
    }
    
    if let peer = messageMainPeer(message) as? TelegramChannel {
        if case .broadcast = peer.info,  !peer.hasAdminRights(.canPostMessages) {
            return false
        } else if case .group = peer.info {
            if peer.hasAdminRights(.canPinMessages) {
                return !message.flags.contains(.Incoming)
            } else if peer.hasAdminRights(.canEditMessages) {
                return message.timestamp + edit_limit_time > Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            }
        }
    }
    
    if message.id.peerId == account.peerId {
        return true
    }
    
    
    if message.flags.contains(.Incoming) {
        return false
    }
    
    
    if message.timestamp + edit_limit_time < Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
        return false
    }
    
 
    
    return !message.flags.contains(.Unsent) && !message.flags.contains(.Failed)
}



func canPinMessage(_ message:Message, for peer:Peer, account:Account) -> Bool {
    return false
}

func canReportMessage(_ message: Message, _ account: Account) -> Bool {
    if let peer = messageMainPeer(message), message.author?.id != account.peerId {
        return peer.isChannel || peer.isGroup || peer.isSupergroup || (message.chatPeer?.isBot == true)
    } else {
        return false
    }
}


func mustManageDeleteMessages(_ messages:[Message], for peer:Peer, account: Account) -> Bool {
    
    if peer.isSupergroup, peer.groupAccess.canManageGroup {
        let peerId:PeerId? = messages[0].author?.id
        if account.peerId != peerId {
            for message in messages {
                if peerId != message.author?.id || message.media.first is TelegramMediaAction {
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
            return media.mimeType.hasPrefix("image")
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
            return tr(L10n.errorUsernameInvalid)
        case .taken:
            return tr(L10n.errorUsernameAlreadyTaken)
        }
    }
}

func <(lhs:RenderedChannelParticipant, rhs: RenderedChannelParticipant) -> Bool {
    let lhsInvitedAt: Int32
    let rhsInvitedAt: Int32
    
    switch lhs.participant {
    case .creator:
        lhsInvitedAt = Int32.min
    case .member(_, let invitedAt, _, _):
        lhsInvitedAt = invitedAt
    }
    switch rhs.participant {
    case .creator:
        rhsInvitedAt = Int32.min
    case .member(_, let invitedAt, _, _):
        rhsInvitedAt = invitedAt
    }
    return lhsInvitedAt < rhsInvitedAt
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
    
    var isRestrictedChannel: Bool {
        if let peer = self as? TelegramChannel {
            if let restrictionInfo = peer.restrictionInfo {
                #if APP_STORE
                    let reason = restrictionInfo.reason.components(separatedBy: ":")
                    
                    if reason.count == 2 {
                        let platform = reason[0]
                        if platform.hasSuffix("ios") || platform.hasSuffix("macos") || platform.hasSuffix("all") {
                            return true
                        }
                    }
                #endif
            }
        }
        return false
    }
    
    var restrictionText:String? {
        if let peer = self as? TelegramChannel {
            if let restrictionInfo = peer.restrictionInfo {
                let reason = restrictionInfo.reason.components(separatedBy: ":")
                
                if reason.count == 2 {
                    return reason[1]
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
            return L10n.secureIdRequestPermissionAddress
        case .personalDetails:
            return L10n.secureIdRequestPermissionPersonalDetails
        case .driversLicense:
            return L10n.secureIdRequestPermissionDriversLicense
        case .utilityBill:
            return L10n.secureIdRequestPermissionUtilityBill
        case .rentalAgreement:
            return L10n.secureIdRequestPermissionRentalAgreement
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

extension SecureIdForm {
    func searchContext(for field: SecureIdRequestedFormField) -> SecureIdValueWithContext? {
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
    
    var requestFieldType: SecureIdRequestedFormField {
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
    var requestFieldType: SecureIdRequestedFormField {
        switch self {
        case .address:
            return .address
        case .bankStatement:
            return .bankStatement
        case .driversLicense:
            return .driversLicense(selfie: true)
        case .email:
            return .email
        case .idCard:
            return .idCard(selfie: true)
        case .internalPassport:
            return .internalPassport(selfie: true)
        case .passport:
            return .passport(selfie: true)
        case .passportRegistration:
            return .passportRegistration
        case .personalDetails:
            return .personalDetails
        case .phone:
            return .phone
        case .rentalAgreement:
            return .rentalAgreement
        case .temporaryRegistration:
            return .temporaryRegistration
        case .utilityBill:
            return .utilityBill
        }
    }
}


extension SecureIdRequestedFormField {
    var rawValue: String {
        switch self {
        case .email:
            return L10n.secureIdRequestPermissionEmail
        case .phone:
            return L10n.secureIdRequestPermissionPhone
        case .address:
            return L10n.secureIdRequestPermissionAddress
        case .utilityBill:
            return L10n.secureIdRequestPermissionUtilityBill
        case .bankStatement:
            return L10n.secureIdRequestPermissionBankStatement
        case .rentalAgreement:
            return L10n.secureIdRequestPermissionRentalAgreement
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
        case let .passport(selfie), let .idCard(selfie), let .driversLicense(selfie), let .internalPassport(selfie):
            return selfie
        default:
            return false
        }
    }
    
    var rawDescription: String {
        switch self {
        case .email:
            return L10n.secureIdRequestPermissionEmailEmpty
        case .phone:
            return L10n.secureIdRequestPermissionPhoneEmpty
        case .address:
            return L10n.secureIdRequestPermissionAddressEmpty
        default:
            return L10n.secureIdRequestPermissionIdentityEmpty
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
            return L10n.secureIdAddRentalAgreement
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
            return L10n.secureIdEditRentalAgreement
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
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}

extension SecureIdRequestedFormField  {
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
        return false
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


func removeChatInteractively(account:Account, peerId:PeerId, userId: PeerId? = nil) -> Signal<Bool, Void> {
    return account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue |> mapToSignal { peer -> Signal<Bool, Void> in
        let text:String
        var okTitle: String? = nil
        var accessory: CGImage? = nil
        if let peer = peer as? TelegramChannel {
            switch peer.info {
            case .broadcast:
                if peer.flags.contains(.isCreator) {
                    text = tr(L10n.confirmDeleteAdminedChannel)
                    okTitle = tr(L10n.confirmDelete)
                    accessory = theme.icons.confirmDeleteChatAccessory
                } else {
                    text = tr(L10n.peerInfoConfirmLeaveChannel)
                }
            case .group:
                text = L10n.confirmLeaveGroup
            }
        } else if let peer = peer as? TelegramGroup {
            text = tr(L10n.peerInfoConfirmDeleteChat(peer.title))
            okTitle = tr(L10n.confirmDelete)
            accessory = theme.icons.confirmDeleteChatAccessory
        } else {
            text = tr(L10n.confirmDeleteChatUser)
            okTitle = tr(L10n.confirmDelete)
            accessory = theme.icons.confirmDeleteChatAccessory
        }
        
        
        
        return modernConfirmSignal(for: mainWindow, account: account, peerId: userId ?? peerId, accessory: accessory, information: text, okTitle: okTitle ?? L10n.alertOK) |> mapToSignal { result -> Signal<Bool, Void> in
            if result {
                return removePeerChat(postbox: account.postbox, peerId: peerId, reportChatSpam: false) |> map {_ in return true}
            } else {
                return .complete()
            }
        }
    }

}

func applyExternalProxy(_ server:ProxyServerSettings, postbox:Postbox, network: Network) {
    var textInfo = tr(L10n.proxyForceEnableTextIP(server.host)) + "\n" + tr(L10n.proxyForceEnableTextPort(Int(server.port)))
    switch server.connection {
    case let .socks5(username, password):
        if let user = username {
            textInfo += "\n" + L10n.proxyForceEnableTextUsername(user)
        }
        if let pass = password {
            textInfo += "\n" + L10n.proxyForceEnableTextPassword(pass)
        }
    case let .mtp(secret):
        textInfo += "\n" + L10n.proxyForceEnableTextSecret((secret as NSData).hexString)
    }
   
    textInfo += "\n\n" + tr(L10n.proxyForceEnableText)
   
    if case .mtp = server.connection {
        textInfo += "\n\n" + L10n.proxyForceEnableMTPDesc
    }
    
    modernConfirm(for: mainWindow, account: nil, peerId: nil, accessory: theme.icons.confirmAppAccessoryIcon, header: L10n.proxyForceEnableHeader1, information: textInfo, okTitle: L10n.proxyForceEnableOK, thridTitle: L10n.proxyForceEnableEnable, successHandler: { result in
        _ = updateProxySettingsInteractively(postbox: postbox, network: network, { current -> ProxySettings in
            
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

extension PostboxAccessChallengeData {
    var timeout:Int32? {
        switch self {
        case .none:
            return nil
        case let .numericalPassword(_, timeout, _), let .plaintextPassword(_, timeout, _):
            return timeout
        }
    }
}

func clearCache(_ path: String) -> Signal<Void, Void> {
    return Signal { subscriber -> Disposable in
        
        let fileManager = FileManager.default
        var enumerator = fileManager.enumerator(atPath: path + "/")
        
        while let file = enumerator?.nextObject() as? String {
            if file != "cache" {
                unlink(path + "/" + file)
            }
        }
        
        var p = path.nsstring.substring(to: path.nsstring.range(of: path.nsstring.lastPathComponent).location)
        p = p.nsstring.substring(to: p.nsstring.range(of: p.nsstring.lastPathComponent).location) + "cached/"
        
        enumerator = fileManager.enumerator(atPath: p)
        
        while let file = enumerator?.nextObject() as? String {
            unlink(p + file)
            //try? fileManager.removeItem(atPath: p + file)
        }
        
        subscriber.putNext(Void())
        subscriber.putCompletion()
        return EmptyDisposable
    } |> runOn(resourcesQueue)
}

func moveWallpaperToCache(postbox: Postbox, _ resource: TelegramMediaResource) -> Signal<String, Void> {
    if let path = postbox.mediaBox.completedResourcePath(resource) {
        return moveWallpaperToCache(postbox: postbox, path)
    } else {
        return .complete()
    }
}

func moveWallpaperToCache(postbox: Postbox, _ path: String, randomName: Bool = false) -> Signal<String, Void> {
    return Signal { subscriber in
        
        let wallpapers = "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/Wallpapers/".nsstring.expandingTildeInPath
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: wallpapers), withIntermediateDirectories: true, attributes: nil)
        
        let out = wallpapers + "/" + (randomName ? "\(arc4random64())" : path.nsstring.lastPathComponent) + ".jpg"
        
        try? FileManager.default.copyItem(atPath: path, toPath: out)
        subscriber.putNext(out)
        
        subscriber.putCompletion()
        return EmptyDisposable
        
    }
}

func canCollagesFromUrl(_ urls:[URL]) -> Bool {
    var canCollage: Bool = urls.count > 1 && urls.count <= 10
    if canCollage {
        for url in urls {
            let mime = MIMEType(url.path.nsstring.pathExtension)
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
            switch true {
            case media.isInstantVideo:
                return ability(categories.instantVideo, peer) && size <= (categories.instantVideo.fileSize ?? INT32_MAX)
            case media.isVideo && media.isAnimated:
                return ability(categories.gif, peer) && size <= (categories.gif.fileSize ?? INT32_MAX)
            case media.isVideo:
                return ability(categories.video, peer) && size <= (categories.video.fileSize ?? INT32_MAX)
            case media.isVoice:
                return ability(categories.voice, peer) && size <= (categories.voice.fileSize ?? INT32_MAX)
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

func wallpaperPath(_ resource: TelegramMediaResource) -> String {
    return "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/Wallpapers/".nsstring.expandingTildeInPath + "/" + resource.id.uniqueId + ".jpg"
}

func fileExtenstion(_ file: TelegramMediaFile) -> String {
    return fileExt(file.mimeType) ?? file.fileName?.nsstring.pathExtension ?? ""
}

func proxySettingsSignal(_ postbox: Postbox) -> Signal<ProxySettings, Void>  {
    return postbox.preferencesView(keys: [PreferencesKeys.proxySettings]) |> map { view in
        return view.values[PreferencesKeys.proxySettings] as? ProxySettings ?? ProxySettings.defaultSettings
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
}

extension RequestEditMessageMedia : Equatable {
    public static func ==(lhs: RequestEditMessageMedia, rhs: RequestEditMessageMedia) -> Bool {
        switch lhs {
        case .keep:
            if case .keep = rhs {
                return true
            } else {
                return false
            }
        case let .update(lhsMedia):
            if case let .update(rhsMedia) = rhs {
                if lhsMedia.isEqual(rhsMedia) {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        }
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
        return TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: NSMakeSize(100, 100), resource: document.resource)], reference: nil)
    }
}

func openFaq(account: Account) {
    let language = appCurrentLanguage.languageCode[appCurrentLanguage.languageCode.index(appCurrentLanguage.languageCode.endIndex, offsetBy: -2) ..< appCurrentLanguage.languageCode.endIndex]
    
    _ = showModalProgress(signal: webpagePreview(account: account, url: "https://telegram.org/faq/" + language) |> deliverOnMainQueue, for: mainWindow).start(next: { webpage in
        if let webpage = webpage {
            showInstantPage(InstantPageViewController(account, webPage: webpage, message: nil))
        } else {
            execute(inapp: .external(link: "https://telegram.org/faq/" + language, true))
        }
    })
}
