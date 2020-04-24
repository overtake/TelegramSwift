//
//  ChatHistoryEntry.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import MtProtoKit

enum ChatHistoryEntryId : Hashable {
    case message(Message)
    case groupedPhotos(groupInfo: MessageGroupInfo)
    case unread
    case date(MessageIndex)
    case undefined
    case maybeId(AnyHashable)
    var hashValue: Int {
        switch self {
        case .message(let message):
            return message.stableId.hashValue
        case .unread:
            return 2 << 1
        case .date(let index):
            return index.hashValue
        case .groupedPhotos(let info):
            return Int(info.stableId)
        case .undefined:
            return 3 << 1
        case .maybeId(let id):
            return id.hashValue
        }
    }
    
    static func ==(lhs:ChatHistoryEntryId, rhs: ChatHistoryEntryId) -> Bool {
        switch lhs {
        case .message(let lhsMessage):
            if case .message(let rhsMessage) = rhs {
                return lhsMessage.stableId == rhsMessage.stableId
            } else {
                return false
            }
        case let .groupedPhotos(groupingKey):
            if case .groupedPhotos(groupingKey) = rhs {
                return true
            } else {
                return false
            }
        case .unread:
            if case .unread = rhs {
                return true
            } else {
                return false
            }
        case .date(let index):
            if case .date(index) = rhs {
                return true
            } else {
                return false
            }
        case .maybeId(let id):
            if case .maybeId(id) = rhs {
                return true
            } else {
                return false
            }
        case .undefined:
            if case .undefined = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var stableIndex: UInt64 {
        switch self {
        case .message:
            return UInt64(1) << 40
        case .groupedPhotos:
            return UInt64(2) << 40
        case .unread:
             return UInt64(3) << 40
        case .date:
            return UInt64(4) << 40
        case .undefined:
            return UInt64(5) << 40
        case .maybeId:
            return UInt64(6) << 40
        }
    }

}

struct ChatPollStateData : Equatable {
    let identifiers: [Data]
    let isLoading: Bool
    init(identifiers: [Data] = [], isLoading: Bool = false) {
        self.identifiers = identifiers
        self.isLoading = isLoading
    }
}

struct MessageEntryAdditionalData : Equatable {
    let pollStateData: ChatPollStateData
    let highlightFoundText: HighlightFoundText?
    init(pollStateData: ChatPollStateData = ChatPollStateData(), highlightFoundText: HighlightFoundText? = nil) {
        self.pollStateData = pollStateData
        self.highlightFoundText = highlightFoundText
    }
}

struct HighlightFoundText : Equatable {
    let query: String
    let isMessage: Bool
    init(query: String, isMessage: Bool) {
        self.query = query
        self.isMessage = isMessage
    }
}

final class ChatHistoryEntryData : Equatable {
    let location: MessageHistoryEntryLocation?
    let additionData: MessageEntryAdditionalData
    let autoPlay: AutoplayMediaPreferences?
    init(_ location: MessageHistoryEntryLocation?, _ additionData: MessageEntryAdditionalData, _ autoPlay: AutoplayMediaPreferences?) {
        self.location = location
        self.additionData = additionData
        self.autoPlay = autoPlay
    }
    static func ==(lhs: ChatHistoryEntryData, rhs: ChatHistoryEntryData) -> Bool {
        return lhs.location == rhs.location && lhs.additionData == rhs.additionData && lhs.autoPlay == rhs.autoPlay
    }
}

enum ChatHistoryEntry: Identifiable, Comparable {
    case MessageEntry(Message, MessageIndex, Bool, ChatItemRenderType, ChatItemType, ForwardItemType?, ChatHistoryEntryData)
    case groupedPhotos([ChatHistoryEntry], groupInfo: MessageGroupInfo)
    case UnreadEntry(MessageIndex, ChatItemRenderType)
    case DateEntry(MessageIndex, ChatItemRenderType)
    case bottom
    var message:Message? {
        switch self {
        case let .MessageEntry(message,_, _,_,_,_,_):
            return message
        default:
          return nil
        }
    }
    
    var autoplayMedia: AutoplayMediaPreferences {
        switch self {
        case let .MessageEntry(_,_,_,_,_,_,data):
            return data.autoPlay ?? AutoplayMediaPreferences.defaultSettings
        case let .groupedPhotos(entries, _):
            return entries.first?.autoplayMedia ?? AutoplayMediaPreferences.defaultSettings
        default:
            return AutoplayMediaPreferences.defaultSettings
        }
    }
    
    var renderType: ChatItemRenderType {
        switch self {
        case let .MessageEntry(_,_,_, renderType,_,_,_):
            return renderType
        case .groupedPhotos(let entries, _):
            return entries.first!.renderType
        case let .DateEntry(_, renderType):
            return renderType
        case .UnreadEntry(_, let renderType):
            return renderType
        case .bottom:
            return .list
        }
    }
    
    var location:MessageHistoryEntryLocation? {
        switch self {
        case let .MessageEntry(_,_,_,_,_,_,data):
            return data.location
        default:
            return nil
        }
    }
    
    
    var additionalData: MessageEntryAdditionalData {
        switch self {
        case let .MessageEntry(_,_,_,_,_,_,data):
            return data.additionData
        default:
            return MessageEntryAdditionalData()
        }
    }
    
    var stableId: ChatHistoryEntryId {
        switch self {
        case let .MessageEntry(message, _, _, _, _, _, _):
            return .message(message)
        case .groupedPhotos(_, let info):
            return .groupedPhotos(groupInfo: info)
        case let .DateEntry(index, _):
            return .date(index)
        case .UnreadEntry:
            return .unread
        case .bottom:
            return .undefined
        }
    }
    
    var index: MessageIndex {
        switch self {
        case let .MessageEntry(_,index, _, _, _, _,_):
            return index
        case let .groupedPhotos(entries, _):
            return entries.last!.index
        case let .UnreadEntry(index, _):
            return index
        case let .DateEntry(index, _):
            return index
        case .bottom:
            return MessageIndex.absoluteUpperBound()
        }
    }
    
    
    var scrollIndex: MessageIndex {
        switch self {
        case let .MessageEntry(message, _, _, _, _, _, _):
            return MessageIndex(message)
        case let .groupedPhotos(entries, _):
            return entries.last!.index
        case let .UnreadEntry(index, _):
            return index
        case let .DateEntry(index, _):
            return index
        case .bottom:
            return MessageIndex.absoluteUpperBound()
        }
    }
    
    func withUpdatedItemType(_ itemType: ChatItemType) -> ChatHistoryEntry {
        switch self {
        case let .MessageEntry(values):
            return .MessageEntry(values.0, values.1, values.2, values.3, itemType, values.5, values.6)
        default:
            return self
        }
    }

}

func isEqualMessageList(lhs:[Message], rhs:[Message]) -> Bool {
    if lhs.count != rhs.count {
        return false 
    } else {
        for (i, message) in lhs.enumerated() {
            if !isEqualMessages(message, rhs[i]) {
                return false
            }
        }
    }
    return true
}

func isEqualMessages(_ lhsMessage: Message, _ rhsMessage: Message) -> Bool {
    
    
    if MessageIndex(lhsMessage) != MessageIndex(rhsMessage) || lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
    }
    if lhsMessage.flags != rhsMessage.flags {
        return false
    }
    
    if lhsMessage.media.count != rhsMessage.media.count {
        return false
    }
    for i in 0 ..< lhsMessage.media.count {
        if !lhsMessage.media[i].isEqual(to: rhsMessage.media[i]) {
            return false
        }
    }
    
    if lhsMessage.associatedMessages.count != rhsMessage.associatedMessages.count {
        return false
    } else {
        for (messageId, lhsAssociatedMessage) in lhsMessage.associatedMessages {
            if let rhsAssociatedMessage = rhsMessage.associatedMessages[messageId] {
                if lhsAssociatedMessage.stableVersion != rhsAssociatedMessage.stableVersion {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    if lhsMessage.peers.count != rhsMessage.peers.count {
        return false
    } else {
        for (lhsPeerId, lhsPeer) in lhsMessage.peers {
            if let rhsPeer = rhsMessage.peers[lhsPeerId] {
                if rhsPeer.displayTitle != lhsPeer.displayTitle {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    return true
}

func ==(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
    switch lhs {
    case let .MessageEntry(message, index, read, renderType, type, fwdType, data):
        switch rhs {
        case .MessageEntry(message, index, read, renderType, type, fwdType, data):
            return true
        default:
            return false
        }
    case let .groupedPhotos(lhsEntries, lhsGroupingKey):
        if case let .groupedPhotos(rhsEntries, rhsGroupingKey) = rhs {
            if lhsEntries.count != rhsEntries.count {
                return false
            } else {
                for i in 0 ..< lhsEntries.count {
                    if lhsEntries[i] != rhsEntries[i] {
                        return false
                    }
                }
                return lhsGroupingKey == rhsGroupingKey
            }
        } else {
            return false
        }
    case let .UnreadEntry(lhsIndex):
        switch rhs {
        case let .UnreadEntry(rhsIndex) where lhsIndex == rhsIndex:
            return true
        default:
            return false
        }
    case let .DateEntry(lhsIndex):
        switch rhs {
        case let .DateEntry(rhsIndex) where lhsIndex == rhsIndex:
            return true
        default:
            return false
        }
    case .bottom:
        switch rhs {
        case .bottom:
            return true
        default:
            return false
        }
    }
    
}

func <(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
    let lhsIndex = lhs.index
    let rhsIndex = rhs.index
    if lhsIndex == rhsIndex {
        return lhs.stableId.stableIndex < rhs.stableId.stableIndex
    } else {
        return lhsIndex < rhsIndex
    }
}


func messageEntries(_ messagesEntries: [MessageHistoryEntry], maxReadIndex:MessageIndex? = nil, includeHoles: Bool = true, dayGrouping: Bool = false, renderType: ChatItemRenderType = .list, includeBottom:Bool = false, timeDifference: TimeInterval = 0, ranks:CachedChannelAdminRanks? = nil, pollAnswersLoading: [MessageId : ChatPollStateData] = [:], groupingPhotos: Bool = false, autoplayMedia: AutoplayMediaPreferences? = nil, searchState: SearchMessagesResultState? = nil, animatedEmojiStickers: [String: StickerPackItem] = [:]) -> [ChatHistoryEntry] {
    var entries: [ChatHistoryEntry] = []

    
    var groupedPhotos:[ChatHistoryEntry] = []
    var groupInfo: MessageGroupInfo?
    
    
    for (i, entry) in messagesEntries.enumerated() {
        var message = entry.message
        if message.media.isEmpty, let server = proxySettings(from: message.text).0 {
            var textInfo = ""
            let name: String
            switch server.connection {
            case let .socks5(username, password):
                if let user = username {
                    textInfo += (!textInfo.isEmpty ? "\n" : "") + L10n.proxyForceEnableTextUsername(user)
                }
                if let pass = password {
                    textInfo += (!textInfo.isEmpty ? "\n" : "") + L10n.proxyForceEnableTextPassword(pass)
                }
                name = L10n.chatMessageSocks5Config
            case let .mtp(secret):
                textInfo += (!textInfo.isEmpty ? "\n" : "") + L10n.proxyForceEnableTextSecret(MTProxySecret.parseData(secret)?.serializeToString() ?? "")
                name = L10n.chatMessageMTProxyConfig
            }
            
            let media = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(url: message.text, displayUrl: "", hash: 0, type: "proxy", websiteName: name, title: L10n.proxyForceEnableTextIP(server.host) + "\n" + L10n.proxyForceEnableTextPort(Int(server.port)), text: textInfo, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, image: nil, file: nil, attributes: [], instantPage: nil)))
            message = message.withUpdatedMedia([media]).withUpdatedText("")
        }
        
        
        if message.media.isEmpty {
            if message.text.length <= 6 {
                let original = message.text.fixed
                let unmodified = original.emojiUnmodified
                if let item = animatedEmojiStickers[unmodified] {
                    var file = item.file
                    var attributes = file.attributes
                    attributes.removeAll { attr in
                        if case .FileName = attr {
                            return true
                        } else {
                            return false
                        }
                    }
                    attributes = attributes.map { attribute -> TelegramMediaFileAttribute in
                        switch attribute {
                        case let .Sticker(_, packReference, maskData):
                            return .Sticker(displayText: original, packReference: packReference, maskData: maskData)
                        default:
                            return attribute
                        }
                    }
                    var disableStickers: Bool = false
                    if let peer = messageMainPeer(message) as? TelegramChannel {
                        if permissionText(from: peer, for: [.banSendGifs, .banSendStickers]) != nil {
                            disableStickers = true
                        }
                    }
                    if !disableStickers {
                        attributes.append(.FileName(fileName: "telegram-animoji.tgs"))
                        file = file.withUpdatedAttributes(attributes)
                        message = message.withUpdatedMedia([file])
                    }
                }
            }
        }
        
        
        var disableEntry = false
        if let action = message.media.first as? TelegramMediaAction {
            switch action.action {
            case .historyCleared:
                disableEntry = true
            case .groupMigratedToChannel:
                disableEntry = true
            case .channelMigratedFromGroup:
                disableEntry = true
            case .peerJoined:
                disableEntry = false
            default:
                break
            }
        }
        
        if disableEntry {
            continue
        }
        
        
        
        var prev:MessageHistoryEntry? = nil
        var next:MessageHistoryEntry? = nil
        
        if i > 0 {
            loop: for k in stride(from: i - 1, to: -1, by: -1) {
                let current = messagesEntries[k]
                if let groupInfo = message.groupInfo {
                    if current.message.groupInfo == groupInfo {
                        continue loop
                    } else {
                        prev = current
                        break loop
                    }
                } else {
                    prev = current
                    break loop
                }
            }
            
        }
        if i < messagesEntries.count - 1 {
            loop: for k in i + 1 ..< messagesEntries.count {
                let current = messagesEntries[k]
                if let groupInfo = message.groupInfo {
                    if current.message.groupInfo == groupInfo {
                        continue loop
                    } else {
                        next = current
                        break loop
                    }
                } else {
                    next = current
                    break loop
                }
            }
        }
        
        
        let rawRank = ranks?.ranks[message.author?.id ?? PeerId(0)]
        var rank:String? = nil
        if let rawRank = rawRank {
            switch rawRank {
            case .admin:
                rank = L10n.chatAdminBadge
            case .owner:
                rank = L10n.chatOwnerBadge
            case let .custom(string):
                rank = string
            }
        }
        
        var itemType:ChatItemType = .Full(rank: rank)
        var fwdType:ForwardItemType? = nil
        
        
        if renderType == .list {
            if let prev = prev {
                var actionShortAccess: Bool = true
                if let action = prev.message.media.first as? TelegramMediaAction {
                    switch action.action {
                    case .phoneCall:
                        actionShortAccess = true
                    default:
                        actionShortAccess = false
                    }
                }
                
                if message.author?.id == prev.message.author?.id, (message.timestamp - prev.message.timestamp) < simpleDif, actionShortAccess, let peer = message.peers[message.id.peerId] {
                    if let peer = peer as? TelegramChannel, case .broadcast(_) = peer.info {
                        itemType = .Full(rank: rank)
                    } else {
                        var canShort:Bool = (message.media.isEmpty || message.media.first?.isInteractiveMedia == false) || message.forwardInfo == nil || renderType == .list
                        attrsLoop: for attr in message.attributes {
                            if !(attr is OutgoingMessageInfoAttribute) && !(attr is TextEntitiesMessageAttribute) && !(attr is EditedMessageAttribute) && !(attr is ForwardSourceInfoAttribute) && !(attr is ViewCountMessageAttribute) && !(attr is ConsumableContentMessageAttribute) && !(attr is NotificationInfoMessageAttribute) && !(attr is ChannelMessageStateVersionAttribute) && !(attr is AutoremoveTimeoutMessageAttribute) {
                                canShort = false
                                break attrsLoop
                            }
                        }
                        itemType = !canShort ? .Full(rank: rank) : .Short
                        
                    }
                } else {
                    itemType = .Full(rank: rank)
                }
            } else {
                itemType = .Full(rank: rank)
            }
        } else {
            if let next = next {
                if message.author?.id == next.message.author?.id, let peer = message.peers[message.id.peerId] {
                    if peer.isChannel || ((peer.isGroup || peer.isSupergroup) && message.flags.contains(.Incoming)) {
                        itemType = .Full(rank: rank)
                    } else {
                        itemType = message.inlinePeer == nil ? .Short : .Full(rank: rank)
                    }
                } else {
                    itemType = .Full(rank: rank)
                }
            } else {
                itemType = .Full(rank: rank)
            }
        }
        
        
        
        
        if message.forwardInfo != nil {
            if case .Short = itemType {
                if let prev = prev {
                    if prev.message.forwardInfo != nil, message.timestamp - prev.message.timestamp < simpleDif  {
                        fwdType = .Inside
                        if let next = next  {
                            if message.author?.id != next.message.author?.id || next.message.timestamp - message.timestamp > simpleDif || next.message.forwardInfo == nil {
                                fwdType = .Bottom
                            }
                        } else {
                            fwdType = .Bottom
                        }
                    } else {
                        fwdType = .ShortHeader
                    }
                }
            } else {
                fwdType = .ShortHeader
            }
        }
        
        if let forwardType = fwdType, forwardType == .ShortHeader || forwardType == .FullHeader  {
            itemType = .Full(rank: rank)
            if forwardType == .ShortHeader {
                if let next = next  {
                    if next.message.forwardInfo != nil && (message.author?.id == next.message.author?.id || next.message.timestamp - message.timestamp < simpleDif) {
                        fwdType = .FullHeader
                    }
                    
                }
            }
        }
        
        let additionalData: MessageEntryAdditionalData
        var highlightFoundText: HighlightFoundText? = nil
        
        
        if let searchState = searchState, !message.text.isEmpty {
            highlightFoundText = HighlightFoundText(query: searchState.query, isMessage: searchState.containsMessage(message))
        }
        
        
        if let data = pollAnswersLoading[message.id] {
            additionalData = MessageEntryAdditionalData(pollStateData: data, highlightFoundText: highlightFoundText)
        } else {
            additionalData = MessageEntryAdditionalData(pollStateData: ChatPollStateData(), highlightFoundText: highlightFoundText)
        }
        let data = ChatHistoryEntryData(entry.location, additionalData, autoplayMedia)
        let entry: ChatHistoryEntry = .MessageEntry(message, MessageIndex(message.withUpdatedTimestamp(message.timestamp - Int32(timeDifference))), entry.isRead, renderType, itemType, fwdType, data)
        
        if let key = message.groupInfo, groupingPhotos, message.id.peerId.namespace == Namespaces.Peer.SecretChat || !message.containsSecretMedia, !message.media.isEmpty {
            if groupInfo == nil {
                groupInfo = key
                groupedPhotos.append(entry.withUpdatedItemType(.Full(rank: rank)))
            } else if groupInfo == key {
                groupedPhotos.append(entry.withUpdatedItemType(.Full(rank: rank)))
            } else {
                if groupedPhotos.count > 0 {
                    if let groupInfo = groupInfo {
                        entries.append(.groupedPhotos(groupedPhotos, groupInfo: groupInfo))
                    }
                    groupedPhotos.removeAll()
                }
                
                groupInfo = key
                groupedPhotos.append(entry.withUpdatedItemType(.Full(rank: rank)))
            }
        } else {
            entries.append(entry)
        }
        
        prev = nil
        next = nil
        
        if i > 0 {
            prev = messagesEntries[i - 1]
        }
        if i < messagesEntries.count - 1 {
            next = messagesEntries[i + 1]
        }
        
        if prev == nil && dayGrouping {
            let dateId = chatDateId(for: message.timestamp - Int32(timeDifference))
            let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: Namespaces.Message.Local, id: 0), timestamp: Int32(dateId))
            entries.append(.DateEntry(index, renderType))
        }
        
        if let next = next, dayGrouping {
            let dateId = chatDateId(for: message.timestamp - Int32(timeDifference))
            let nextDateId = chatDateId(for: next.message.timestamp - Int32(timeDifference))
            
            
            if dateId != nextDateId {
                let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: Namespaces.Message.Local, id: INT_MAX), timestamp: Int32(nextDateId))
                entries.append(.DateEntry(index, renderType))
            }
        }
    }
    
    
    var hasUnread = false
    if let maxReadIndex = maxReadIndex {
        entries.append(.UnreadEntry(maxReadIndex.withUpdatedTimestamp(maxReadIndex.timestamp - Int32(timeDifference)), renderType))
        hasUnread = true
    }
    
    
    if includeBottom {
        entries.append(.bottom)
    }
    
    if !groupedPhotos.isEmpty, let key = groupInfo {
        entries.append(.groupedPhotos(groupedPhotos, groupInfo: key))
    }
    var sorted = entries.sorted()

    if hasUnread, sorted.count >= 2 {
        if  case .UnreadEntry = sorted[sorted.count - 2] {
            sorted.remove(at: sorted.count - 2)
        }
    }

    return sorted
}

