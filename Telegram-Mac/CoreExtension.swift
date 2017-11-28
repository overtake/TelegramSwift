
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
            } else if case .group(_) = channel.info  {
                return !channel.hasBannedRights(.banSendMessages)
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
            return user.name.isEmpty ? tr(.peerDeletedUser) : user.name
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
                return tr(.peerDeletedUser)
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
                let name = tr(.peerDeletedUser)
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
            return tr(.eventLogServicePromoteAddNewAdmins)
        case TelegramChannelAdminRightsFlags.canBanUsers:
            return tr(.eventLogServicePromoteBanUsers)
        case TelegramChannelAdminRightsFlags.canChangeInfo:
            return tr(.eventLogServicePromoteChangeInfo)
        case TelegramChannelAdminRightsFlags.canInviteUsers:
            return tr(.eventLogServicePromoteAddUsers)
        case TelegramChannelAdminRightsFlags.canChangeInviteLink:
            return tr(.eventLogServicePromoteInviteViaLink)
        case TelegramChannelAdminRightsFlags.canDeleteMessages:
            return tr(.eventLogServicePromoteDeleteMessages)
        case TelegramChannelAdminRightsFlags.canEditMessages:
            return tr(.eventLogServicePromoteEditMessages)
        case TelegramChannelAdminRightsFlags.canPinMessages:
            return tr(.eventLogServicePromotePinMessages)
        case TelegramChannelAdminRightsFlags.canPostMessages:
            return tr(.eventLogServicePromotePostMessages)
        default:
            return "Undefined Promotion"
        }
    }
}

extension TelegramChannelBannedRightsFlags {
    var localizedString:String {
        switch self {
        case TelegramChannelBannedRightsFlags.banSendGifs:
            return tr(.eventLogServiceDemoteSendStickers)
        case TelegramChannelBannedRightsFlags.banEmbedLinks:
            return tr(.eventLogServiceDemoteEmbedLinks)
        case TelegramChannelBannedRightsFlags.banReadMessages:
            return ""
        case TelegramChannelBannedRightsFlags.banSendGames:
            return tr(.eventLogServiceDemoteEmbedLinks)
        case TelegramChannelBannedRightsFlags.banSendInline:
            return tr(.eventLogServiceDemoteSendInline)
        case TelegramChannelBannedRightsFlags.banSendMedia:
            return tr(.eventLogServiceDemoteSendMedia)
        case TelegramChannelBannedRightsFlags.banSendMessages:
            return tr(.eventLogServiceDemoteSendMessages)
        case TelegramChannelBannedRightsFlags.banSendStickers:
            return tr(.eventLogServiceDemoteSendStickers)
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
        formatter.locale = Locale(identifier: appCurrentLanguage.languageCode)
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(untilDate)))
    }
}

func alertForMediaRestriction(_ peer:Peer) {
    if let peer = peer as? TelegramChannel, let bannedRights = peer.bannedRights {
        alert(for: mainWindow, info: bannedRights.untilDate != .max ? tr(.channelPersmissionDeniedSendMediaUntil(bannedRights.formattedUntilDate)) : tr(.channelPersmissionDeniedSendMediaForever))
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
        if let resource = resource as? LocalFileReferenceMediaResource {
            return Int(resource.sizeValue ?? 0)
        }
        return 0
    }
}

enum ChatListIndexRequest :Equatable {
    case Initial(Int, TableScrollState?)
    case Index(ChatListIndex)
}

func ==(lhs:ChatListIndexRequest, rhs:ChatListIndexRequest) -> Bool {
    switch lhs {
    case let .Initial(lhsCount, _):
        if case let .Initial(rhsCount, _) = rhs {
            return rhsCount == lhsCount
        }
        
    case let .Index(lhsIndex):
        if case let .Index(rhsIndex) = rhs {
            return lhsIndex == rhsIndex
        }
    }
    
    return false
}

public extension PeerView {
    var isMuted:Bool {
        if let settings = self.notificationSettings as? TelegramPeerNotificationSettings {
            switch settings.muteState {
            case .muted:
                return true
            case .unmuted:
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
    
    var inlinePeer:Peer? {
        for attribute in attributes {
            if let attribute = attribute as? InlineBotMessageAttribute {
                return peers[attribute.peerId]
            }
        }
        return author
    }
    
    func withUpdatedStableId(_ stableId:UInt32) -> Message {
        return Message(stableId: stableId, stableVersion: stableVersion, id: id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, forwardInfo: forwardInfo, author: author, text: text, attributes: attributes, media: media, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds)
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
        self.init(stableId: stableId, stableVersion: 0, id: messageId, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 0, flags: [], tags: [], globalTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [media], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [])
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
        }
        if media is TelegramMediaAction {
            return false
        }
    }
    
    if let peer = messageMainPeer(message) as? TelegramChannel {
        if case .broadcast = peer.info {
            if peer.hasAdminRights(.canEditMessages) {
                return message.timestamp + edit_limit_time > Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            } else if !peer.hasAdminRights(.canPostMessages) {
                return false
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
    
    return true
}



func canPinMessage(_ message:Message, for peer:Peer, account:Account) -> Bool {
    return false
}


func mustManageDeleteMessages(_ messages:[Message], for peer:Peer, account: Account) -> Bool {
    if peer.isSupergroup, peer.groupAccess.canManageGroup {
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
            return media.mimeType.hasPrefix("image")
        }
        return false
    }
}

extension AddressNameFormatError {
    var description:String {
        switch self {
        case .startsWithUnderscore:
            return tr(.errorUsernameUnderscopeStart)
        case .endsWithUnderscore:
            return tr(.errorUsernameUnderscopeEnd)
        case .startsWithDigit:
            return tr(.errorUsernameNumberStart)
        case .invalidCharacters:
            return tr(.errorUsernameInvalid)
        case .tooShort:
            return tr(.errorUsernameMinimumLength)
        }
    }
}

extension AddressNameAvailability {
    var description:String {
        switch self {
        case .available:
            return "available"
        case .invalid:
            return tr(.errorUsernameInvalid)
        case .taken:
            return tr(.errorUsernameAlreadyTaken)
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


func removeChatInteractively(account:Account, peerId:PeerId) -> Signal<Bool, Void> {
    return account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue |> mapToSignal { peer -> Signal<Bool, Void> in
        let text:String
        if let peer = peer as? TelegramChannel {
            switch peer.info {
            case .broadcast:
                if peer.flags.contains(.isCreator) {
                    text = tr(.confirmDeleteAdminedChannel)
                } else {
                    text = tr(.peerInfoConfirmLeaveChannel)
                }
            case .group:
                text = tr(.peerInfoConfirmLeaveGroup)
            }
        } else if let peer = peer as? TelegramGroup {
            text = tr(.peerInfoConfirmDeleteChat(peer.title))
        } else {
            text = tr(.confirmDeleteChatUser)
        }
        
        return confirmSignal(for: mainWindow, header: appName, information: text) |> mapToSignal { result -> Signal<Bool, Void> in
            if result {
                return removePeerChat(postbox: account.postbox, peerId: peerId, reportChatSpam: false) |> map {_ in return true}
            }
            return .single(false)
        }
    }

}

func applyExternalProxy(_ proxy:ProxySettings, postbox:Postbox, network: Network) {
    var textInfo = tr(.proxyForceEnableTextIP(proxy.host)) + "\n" + tr(.proxyForceEnableTextPort(Int(proxy.port)))
    if let user = proxy.username {
        textInfo += "\n" + tr(.proxyForceEnableTextUsername(user))
    }
    if let pass = proxy.password {
        textInfo += "\n" + tr(.proxyForceEnableTextPassword(pass))
    }
    textInfo += "\n\n" + tr(.proxyForceEnableText)
    
    _ = (confirmSignal(for: mainWindow, header: tr(.proxyForceEnableHeader), information: textInfo)
        |> filter {$0} |> map {_ in} |> mapToSignal {
            return applyProxySettings(postbox: postbox, network: network, settings: proxy)
    }).start()
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
