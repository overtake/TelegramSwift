//
//  PeerUtils.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SwiftSignalKit
import Postbox


let prod_repliesPeerId: PeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1271266957))
let test_repliesPeerId: PeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(708513))


var repliesPeerId: PeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1271266957))


extension ChatListFilterPeerCategories {
   
    static let excludeRead = ChatListFilterPeerCategories(rawValue: 1 << 6)
    static let excludeMuted = ChatListFilterPeerCategories(rawValue: 1 << 7)
    static let excludeArchived = ChatListFilterPeerCategories(rawValue: 1 << 8)
    
    static let existingChats = ChatListFilterPeerCategories(rawValue: 1 << 9)
    static let newChats = ChatListFilterPeerCategories(rawValue: 1 << 10)

    
    static let Namespace: Int32 = 7
}


final class TelegramStoryRepostPeerObject : Peer {
    
    var timeoutAttribute: UInt32?
    
    var id: PeerId
    
    var indexName: PeerIndexNameRepresentation
    
    var associatedPeerId: PeerId?
    var associatedMediaIds: [MediaId]?
    var notificationSettingsPeerId: PeerId?
    
    func isEqual(_ other: Peer) -> Bool {
        if let _ = other as? TelegramStoryRepostPeerObject {
            return true
        }
        return false
    }
    
    
    init() {
        self.id = PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(1000)))
        self.indexName = .title(title: "", addressNames: [""])
        self.notificationSettingsPeerId = nil
    }
    
    var displayTitle: String? {
        return strings().peerReportStory
    }
    
    var icon: EmptyAvatartType? {
        return .icon(colors: theme.colors.peerColors(4), icon: NSImage(named: "Icon_StoryRepost")!.precomposed(), iconSize: NSMakeSize(36, 36), cornerRadius: nil)
    }
    
    
    init(decoder: PostboxDecoder) {
        self.id = PeerId(0)
        self.indexName = .title(title: "", addressNames: [""])
        self.notificationSettingsPeerId = nil
    }
    func encode(_ encoder: PostboxEncoder) {
        
    }
}



final class TelegramFilterCategory : Peer {
    
    var timeoutAttribute: UInt32? 
    
    var id: PeerId
    
    var indexName: PeerIndexNameRepresentation
    
    var associatedPeerId: PeerId?
    var associatedMediaIds: [MediaId]?
    var notificationSettingsPeerId: PeerId?
    
    func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramFilterCategory {
            return other.category == self.category
        }
        return false
    }
    
    let category: ChatListFilterPeerCategories
    
    init(category: ChatListFilterPeerCategories) {
        self.id = PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(category.rawValue)))
        self.indexName = .title(title: "", addressNames: [""])
        self.notificationSettingsPeerId = nil
        self.category = category
    }
    
    var displayTitle: String? {
        if category == .contacts {
            return strings().chatListFilterContacts
        }
        if category == .nonContacts {
            return strings().chatListFilterNonContacts
        }
        if category == .groups {
            return strings().chatListFilterGroups
        }
        if category == .channels {
            return strings().chatListFilterChannels
        }
        if category == .bots {
            return strings().chatListFilterBots
        }
        if category == .excludeRead {
            return strings().chatListFilterReadChats
        }
        if category == .excludeMuted {
            return strings().chatListFilterMutedChats
        }
        if category == .excludeArchived {
            return strings().chatListFilterArchive
        }
        if category == .existingChats {
            return strings().chatListFilterExistingChats
        }
        if category == .newChats {
            return strings().chatListFilterNewChats
        }
        return nil
    }
    
    var icon: EmptyAvatartType? {
        if category == .contacts {
            return .icon(colors: theme.colors.peerColors(5), icon: theme.icons.chat_filter_private_chats_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .nonContacts {
            return .icon(colors: theme.colors.peerColors(1), icon: theme.icons.chat_filter_non_contacts_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .groups {
            return .icon(colors: theme.colors.peerColors(2), icon: theme.icons.chat_filter_large_groups_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .channels {
            return .icon(colors: theme.colors.peerColors(0), icon: theme.icons.chat_filter_channels_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .bots {
            return .icon(colors: theme.colors.peerColors(6), icon: theme.icons.chat_filter_bots_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .excludeMuted {
            return .icon(colors: theme.colors.peerColors(0), icon: theme.icons.chat_filter_muted_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .excludeRead {
            return .icon(colors: theme.colors.peerColors(3), icon: theme.icons.chat_filter_read_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .excludeArchived {
            return .icon(colors: theme.colors.peerColors(5), icon: theme.icons.chat_filter_archive_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .newChats {
            return .icon(colors: theme.colors.peerColors(2), icon: theme.icons.chat_filter_new_chats, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .existingChats {
            return .icon(colors: theme.colors.peerColors(2), icon: theme.icons.chat_filter_existing_chats, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        return nil
    }
    
    
    init(decoder: PostboxDecoder) {
        self.id = PeerId(0)
        self.indexName = .title(title: "", addressNames: [""])
        self.notificationSettingsPeerId = nil
        self.category = []
    }
    func encode(_ encoder: PostboxEncoder) {
        
    }
}

extension CachedPeerData {
    var photo: TelegramMediaImage? {
        if let data = self as? CachedUserData {
            switch data.photo {
            case let .known(image):
                return image
            default:
                return nil
            }
        }
        if let data = self as? CachedChannelData {
            return data.photo
        }
        if let data = self as? CachedGroupData {
            return data.photo
        }
        return nil
    }
    var personalPhoto: TelegramMediaImage? {
        if let data = self as? CachedUserData {
            switch data.personalPhoto {
            case let .known(image):
                return image
            default:
                return nil
            }
        }
        return nil
    }
    var fallbackPhoto: TelegramMediaImage? {
        if let data = self as? CachedUserData {
            switch data.fallbackPhoto {
            case let .known(image):
                return image
            default:
                return nil
            }
        }
        return nil
    }
}

let internal_allPossibleGroupPermissionList: [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] = [
    (.banSendText, .banMembers),
    (.banSendMedia, .banMembers),
    (.banSendPhotos, .banMembers),
    (.banSendVideos, .banMembers),
    (.banSendGifs, .banMembers),
    (.banSendMusic, .banMembers),
    (.banSendFiles, .banMembers),
    (.banSendVoice, .banMembers),
    (.banSendInstantVideos, .banMembers),
    (.banEmbedLinks, .banMembers),
    (.banSendPolls, .banMembers),
    (.banAddMembers, .banMembers),
    (.banPinMessages, .pinMessages),
    (.banManageTopics, .manageTopics),
    (.banChangeInfo, .changeInfo)
]



public func allGroupPermissionList(peer: Peer) -> [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] {
    if let channel = peer as? TelegramChannel, channel.flags.contains(.isForum) {
        return [
            (.banSendText, .banMembers),
            (.banSendMedia, .banMembers),
            (.banAddMembers, .banMembers),
            (.banPinMessages, .pinMessages),
            (.banManageTopics, .manageTopics),
            (.banChangeInfo, .changeInfo)
        ]
    } else {
        return [
            (.banSendText, .banMembers),
            (.banSendMedia, .banMembers),
            (.banAddMembers, .banMembers),
            (.banPinMessages, .pinMessages),
            (.banChangeInfo, .changeInfo)
        ]
    }
}

func banSendMediaSubList() -> [(TelegramChatBannedRightsFlags, TelegramChannelPermission)] {
    return [
        (.banSendPhotos, .banMembers),
        (.banSendVideos, .banMembers),
        (.banSendGifs, .banMembers),
        (.banSendMusic, .banMembers),
        (.banSendFiles, .banMembers),
        (.banSendVoice, .banMembers),
        (.banSendInstantVideos, .banMembers),
        (.banEmbedLinks, .banMembers),
        (.banSendPolls, .banMembers),
    ]
}



let publicGroupRestrictedPermissions: TelegramChatBannedRightsFlags = [
    .banPinMessages,
    .banChangeInfo
]



func checkMediaPermission(_ media: Media, for peer: Peer?) -> String? {
    guard let peer = peer else {
        return nil
    }
    switch media {
    case _ as TelegramMediaPoll:
        return permissionText(from: peer, for: .banSendPolls)
    case _ as TelegramMediaImage:
        return permissionText(from: peer, for: .banSendPhotos)
    case let file as TelegramMediaFile:
        if file.isAnimated && file.isVideo {
            return permissionText(from: peer, for: .banSendGifs)
        } else if file.isStaticSticker {
            return permissionText(from: peer, for: .banSendStickers)
        } else if file.isMusic {
            return permissionText(from: peer, for: .banSendMusic)
        } else if file.isVoice {
            return permissionText(from: peer, for: .banSendVoice)
        } else if file.isInstantVideo {
            return permissionText(from: peer, for: .banSendInstantVideos)
        } else if file.isVideo {
            return permissionText(from: peer, for: .banSendVideos)
        } else {
            return permissionText(from: peer, for: .banSendFiles)
        }
    case _ as TelegramMediaGame:
        return permissionText(from: peer, for: .banSendGames)
    default:
        return nil
    }
}

func permissionText(from peer: Peer?, for flags: TelegramChatBannedRightsFlags, cachedData: CachedPeerData? = nil) -> String? {
    guard let peer = peer else {
        return nil
    }
    var bannedPermission: (Int32, Bool)?
    
    if let cachedData = cachedData as? CachedChannelData, !peer.isAdmin {
        if let boostsToUnrestrict = cachedData.boostsToUnrestrict {
            let appliedBoosts = cachedData.appliedBoosts ?? 0
            if boostsToUnrestrict <= appliedBoosts {
                return nil
            }
        }
    }
    
    let get:(TelegramChatBannedRightsFlags) -> (Int32, Bool)? = { flags in
        if let channel = peer as? TelegramChannel {
            return channel.hasBannedPermission(flags)
        } else if let group = peer as? TelegramGroup {
            if group.hasBannedPermission(flags) {
                return (Int32.max, false)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    bannedPermission = get(flags)
    if bannedPermission == nil, banSendMediaSubList().contains(where: { $0.0 == flags }) {
        bannedPermission = get(.banSendMedia)
    }
    
    if let (untilDate, personal) = bannedPermission {
        
        switch flags {
        case .banSendText:
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
        case .banSendVoice:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendVoiceUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendVoiceForever
            } else {
                return strings().channelPersmissionDeniedSendVoiceDefaultRestrictedText
            }
        case .banSendInstantVideos:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendInstantVideoUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendInstantVideoForever
            } else {
                return strings().channelPersmissionDeniedSendInstantVideoDefaultRestrictedText
            }
        case .banSendVideos:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendVideoUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendVideoForever
            } else {
                return strings().channelPersmissionDeniedSendVideoDefaultRestrictedText
            }
        case .banSendPhotos:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendPhotoUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendPhotoForever
            } else {
                return strings().channelPersmissionDeniedSendPhotoDefaultRestrictedText
            }
        case .banSendFiles:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendFileUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendFileForever
            } else {
                return strings().channelPersmissionDeniedSendFileDefaultRestrictedText
            }
        case .banSendMusic:
            if personal && untilDate != 0 && untilDate != Int32.max {
                return strings().channelPersmissionDeniedSendMusicUntil(stringForFullDate(timestamp: untilDate))
            } else if personal {
                return strings().channelPersmissionDeniedSendMusicForever
            } else {
                return strings().channelPersmissionDeniedSendMusicDefaultRestrictedText
            }
        default:
            return nil
        }
        
        
    }
    
    return nil
}


extension Peer {
    
    func hasBannedRights(_ flags: TelegramChatBannedRightsFlags) -> Bool {
        if let peer = self as? TelegramChannel {
            if let _ = peer.hasBannedPermission(flags) {
                return true
            }
        } else if let peer = self as? TelegramGroup {
            return peer.hasBannedPermission(flags)
        }
        return false
    }
    
    var webUrlRestricted: Bool {
        return hasBannedRights([.banEmbedLinks])
    }
    
    
    var hasVideo: Bool {
        if let image = self.profileImageRepresentations.first {
            return image.hasVideo
        }
        return false
    }
    
    func canSendMessage(_ isThreadMode: Bool = false, media: Media? = nil, threadData: MessageHistoryThreadData? = nil, cachedData: CachedPeerData? = nil) -> Bool {
        if self.id == repliesPeerId {
            return false
        }
        if let channel = self as? TelegramChannel {
            if case .broadcast(_) = channel.info {
                if let media = media, channel.hasPermission(.sendSomething) {
                    return checkMediaPermission(media, for: channel) == nil
                } else {
                    return channel.hasPermission(.sendText)
                }
            } else if case .group = channel.info {
                
                if let data = threadData {
                    if data.isClosed, channel.adminRights == nil && !channel.flags.contains(.isCreator) && !data.isOwnedByMe {
                        return false
                    }
                }
                
                if let cachedData = cachedData as? CachedChannelData, let boostsToUnrestrict = cachedData.boostsToUnrestrict {
                    let appliedBoosts = cachedData.appliedBoosts ?? 0
                    if boostsToUnrestrict <= appliedBoosts {
                        return true
                    }
                }
                
                switch channel.participationStatus {
                case .member:
                    if let media = media, channel.hasPermission(.sendSomething) {
                        return checkMediaPermission(media, for: channel) == nil
                    } else {
                        return channel.hasPermission(.sendText)
                    }
                case .left:
                    if isThreadMode {
                        if let media = media, channel.hasPermission(.sendSomething) {
                            return checkMediaPermission(media, for: channel) == nil
                        } else {
                            return channel.hasPermission(.sendText)
                        }
                    }
                    return false
                case .kicked:
                    return false
                }
            }
        } else if let group = self as? TelegramGroup {
            return group.membership == .Member && !group.hasBannedPermission(.banSendText)
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
            return peer.addressName
        } else if let peer = self as? TelegramGroup {
            return peer.addressName
        } else if let peer = self as? TelegramUser {
            return peer.addressName
        }
        return nil
    }
    
    var emptyAvatar: EmptyAvatartType? {
        if let peer = self as? TelegramFilterCategory {
            return peer.icon
        }
        if let peer = self as? TelegramStoryRepostPeerObject {
            return peer.icon
        }
        return nil
    }
    
    public var displayTitle: String {
        switch self {
        case let user as TelegramUser:
            if user.id.isAnonymousSavedMessages {
                return strings().chatListAuthorHidden
            }
            if user.firstName == nil && user.lastName == nil {
                return strings().peerDeletedUser
            } else {
                var name: String = ""
                if let firstName = user.firstName {
                    name += firstName
                }
                if let lastName = user.lastName {
                    if user.firstName != nil {
                        name += " "
                    }
                    name += lastName
                }
                if name.isEmpty {
                    if let phone = user.phone {
                        if !phone.isEmpty {
                            name = phone
                        }
                    }
                }
                if name.isEmpty {
                    return " "
                }
                return name
            }
        case let group as TelegramGroup:
            if group.title.isEmpty {
                return " "
            }
            return group.title
        case let channel as TelegramChannel:
            if channel.title.isEmpty {
                return " "
            }
            return channel.title
        case let filter as TelegramFilterCategory:
            let folder = filter.displayTitle ?? ""
            if folder.isEmpty {
                return " "
            }
            return folder
        case let repost as TelegramStoryRepostPeerObject:
            return repost.displayTitle ?? ""
        default:
            return " "
        }
    }
    
    var rawDisplayTitle: String {
        switch self {
        case let user as TelegramUser:
            if user.firstName == nil && user.lastName == nil {
                return ""
            } else {
                var name: String = ""
                if let firstName = user.firstName {
                    name += firstName
                }
                if let lastName = user.lastName {
                    if user.firstName != nil {
                        name += " "
                    }
                    name += lastName
                }
                return name
            }
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
            if user.id.isAnonymousSavedMessages {
                return strings().chatListAuthorHidden
            }
            if let firstName = user.firstName {
                if !firstName.isEmpty {
                    return firstName
                }
            }
            if let lastName = user.lastName {
                if !lastName.isEmpty {
                    return lastName
                }
            }
            if let phone = user.phone {
                if !phone.isEmpty {
                    return phone
                }
            }
            if user.firstName == nil, user.lastName == nil {
                return strings().peerDeletedUser
            }
            return " "
        default:
            return displayTitle
        }
    }
    
    public var displayLetters: [String] {
        switch self {
        case let user as TelegramUser:
            if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty && !lastName.isEmpty {
                return [firstName[firstName.startIndex ..< firstName.index(after: firstName.startIndex)].uppercased(), lastName[lastName.startIndex ..< lastName.index(after: lastName.startIndex)].uppercased()]
            } else if let firstName = user.firstName, !firstName.isEmpty {
                return [firstName[firstName.startIndex ..< firstName.index(after: firstName.startIndex)].uppercased()]
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return [lastName[lastName.startIndex ..< lastName.index(after: lastName.startIndex)].uppercased()]
            } else {
                let name = strings().peerDeletedUser
                if !name.isEmpty {
                    return [name[name.startIndex ..< name.index(after: name.startIndex)].uppercased()]
                }
            }
            
            return []
        case let group as TelegramGroup:
            if !group.title.isEmpty {
                return [group.title[group.title.startIndex ..< group.title.index(after: group.title.startIndex)].uppercased()]
            } else {
                return []
            }
        case let channel as TelegramChannel:
            if !channel.title.isEmpty {
                return [channel.title[channel.title.startIndex ..< channel.title.index(after: channel.title.startIndex)].uppercased()]
            } else {
                return []
            }
        default:
            return []
        }
    }

    
    
    var isPremium: Bool {
        if let peer = self as? TelegramUser {
            return peer.flags.contains(.isPremium)
        } else {
            return false
        }
    }
    
    var isForum: Bool {
        if let channel = self as? TelegramChannel {
            return channel.flags.contains(.isForum)
        } else {
            return false
        }
    }
    
    
}

extension PeerId {
    static func _optionalInternalFromInt64Value(_ id: Int64) -> PeerId.Id? {
        let peerId = PeerId.Id._internalFromInt64Value(id)
        if id < 0 {
            if let _ = Int32(exactly: id) {
                return peerId
            } else {
                return nil
            }
        }
        return peerId
    }
}


func getPeerView(peerId: PeerId, postbox: Postbox) -> Signal<Peer?, NoError> {
    return postbox.combinedView(keys: [.basicPeer(peerId)]) |> map { view in
        return (view.views[.basicPeer(peerId)] as? BasicPeerView)?.peer
    }
}
func getCachedDataView(peerId: PeerId, postbox: Postbox) -> Signal<CachedPeerData?, NoError> {
    return postbox.combinedView(keys: [.cachedPeerData(peerId: peerId)]) |> map { view in
        return (view.views[.cachedPeerData(peerId: peerId)] as? CachedPeerDataView)?.cachedPeerData
    }
}
struct StoryInitialIndex {
    let peerId: PeerId
    let id: Int32?
    let messageId: MessageId?
    let takeControl:((PeerId, MessageId?, Int32?)->NSView?)?
    let setProgress:((Signal<Never, NoError>)->Void)?
    init(peerId: PeerId, id: Int32?, messageId: MessageId?, takeControl: ((PeerId, MessageId?, Int32?) -> NSView?)?, setProgress: ((Signal<Never, NoError>) -> Void)? = nil) {
        self.peerId = peerId
        self.id = id
        self.messageId = messageId
        self.takeControl = takeControl
        self.setProgress = setProgress
    }
}
