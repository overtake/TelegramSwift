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
    case commentsHeader
    case repliesHeader
    case topThreadInset
    func hash(into hasher: inout Hasher) {
        
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
        case .commentsHeader:
            if case .commentsHeader = rhs {
                return true
            } else {
                return false
            }
        case .repliesHeader:
            if case .repliesHeader = rhs {
                return true
            } else {
                return false
            }
        case .topThreadInset:
            if case .topThreadInset = rhs {
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
        case .commentsHeader:
            return UInt64(7) << 40
        case .repliesHeader:
            return UInt64(8) << 40
        case .topThreadInset:
            return UInt64(9) << 40
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
    let isThreadLoading: Bool
    init(pollStateData: ChatPollStateData = ChatPollStateData(), highlightFoundText: HighlightFoundText? = nil, isThreadLoading: Bool = false) {
        self.pollStateData = pollStateData
        self.highlightFoundText = highlightFoundText
        self.isThreadLoading = isThreadLoading
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
    case commentsHeader(Bool, MessageIndex, ChatItemRenderType)
    case repliesHeader(Bool, MessageIndex, ChatItemRenderType)
    case topThreadInset(CGFloat, MessageIndex, ChatItemRenderType)
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
        case let .commentsHeader(_, _, renderType):
            return renderType
        case let .repliesHeader(_, _, renderType):
            return renderType
        case let .topThreadInset(_, _, renderType):
            return renderType
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
        case .commentsHeader:
            return .commentsHeader
        case .repliesHeader:
            return .repliesHeader
        case .topThreadInset:
            return .topThreadInset
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
        case let .commentsHeader(_, index, _):
            return index
        case let .repliesHeader(_, index, _):
            return index
        case let .topThreadInset(_, index, _):
            return index
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
        case let .commentsHeader(_, index, _):
            return index
        case let .repliesHeader(_, index, _):
            return index
        case let .topThreadInset(_, index, _):
            return index
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
    
    if lhsMessage.attributes.count != rhsMessage.attributes.count {
        return false
    }
    
    for (_, lhsAttr) in lhsMessage.attributes.enumerated() {
        if let lhsAttr = lhsAttr as? ReplyThreadMessageAttribute {
            let rhsAttr = rhsMessage.attributes.compactMap { $0 as? ReplyThreadMessageAttribute }.first
            if let rhsAttr = rhsAttr {
                if lhsAttr.count != rhsAttr.count {
                    return false
                }
                if lhsAttr.latestUsers != rhsAttr.latestUsers {
                    return false
                }
                if lhsAttr.maxMessageId != rhsAttr.maxMessageId {
                    return false
                }
                if lhsAttr.maxReadMessageId != rhsAttr.maxReadMessageId {
                    return false
                }
            } else {
                return false
            }
        }
        if let lhsAttr = lhsAttr as? ViewCountMessageAttribute {
            let rhsAttr = rhsMessage.attributes.compactMap { $0 as? ViewCountMessageAttribute }.first
            if let rhsAttr = rhsAttr {
                if lhsAttr.count != rhsAttr.count {
                    return false
                }
            } else {
                return false
            }
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
    case let .commentsHeader(empty, index, type):
        switch rhs {
        case .commentsHeader(empty, index, type):
            return true
        default:
            return false
        }
    case let .repliesHeader(empty, index, type):
        switch rhs {
        case .repliesHeader(empty, index, type):
            return true
        default:
            return false
        }
    case let .topThreadInset(value, index, type):
        switch rhs {
        case .topThreadInset(value, index, type):
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


func messageEntries(_ messagesEntries: [MessageHistoryEntry], maxReadIndex:MessageIndex? = nil, includeHoles: Bool = true, dayGrouping: Bool = false, renderType: ChatItemRenderType = .list, includeBottom:Bool = false, timeDifference: TimeInterval = 0, ranks:CachedChannelAdminRanks? = nil, pollAnswersLoading: [MessageId : ChatPollStateData] = [:], threadLoading: MessageId? = nil, groupingPhotos: Bool = false, autoplayMedia: AutoplayMediaPreferences? = nil, searchState: SearchMessagesResultState? = nil, animatedEmojiStickers: [String: StickerPackItem] = [:], topFixedMessages: [Message]? = nil, customChannelDiscussionReadState: MessageId? = nil, customThreadOutgoingReadState: MessageId? = nil, addRepliesHeader: Bool = false, addTopThreadInset: CGFloat? = nil) -> [ChatHistoryEntry] {
    var entries: [ChatHistoryEntry] = []

    
    var groupedPhotos:[ChatHistoryEntry] = []
    var groupInfo: MessageGroupInfo?
    
    var messagesEntries = messagesEntries
    var topMessageIndex: Int? = nil
    if let topMessages = topFixedMessages, !topMessages.isEmpty {
        messagesEntries.insert(contentsOf: topMessages.map { MessageHistoryEntry(message: $0, isRead: true, location: nil, monthLocation: nil, attributes: .init(authorIsContact: false))}, at: 0)
        topMessageIndex = topMessages.count - 1
    }
    
    for (i, entry) in messagesEntries.enumerated() {
        var message = entry.message
        
        
        
        if message.media.isEmpty {
            if message.text.length <= 7 {
                let original = message.text.fixed
                let unmodified = original.emojiUnmodified
                if original.isSingleEmoji, let item = animatedEmojiStickers[unmodified] {
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
                        
                        let allowAttributes:[MessageAttribute.Type] = [ReplyThreadMessageAttribute.self, OutgoingMessageInfoAttribute.self, TextEntitiesMessageAttribute.self, EditedMessageAttribute.self, ForwardSourceInfoAttribute.self, ViewCountMessageAttribute.self, ConsumableContentMessageAttribute.self, NotificationInfoMessageAttribute.self, ChannelMessageStateVersionAttribute.self, AutoremoveTimeoutMessageAttribute.self]
                        
                        attrsLoop: for attr in message.attributes {
                            let contains = allowAttributes.contains(where: { type(of: attr) == $0 })
                            if !contains {
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
            if let next = next, !message.isAnonymousMessage {
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
            additionalData = MessageEntryAdditionalData(pollStateData: data, highlightFoundText: highlightFoundText, isThreadLoading: threadLoading == message.id)
        } else {
            additionalData = MessageEntryAdditionalData(pollStateData: ChatPollStateData(), highlightFoundText: highlightFoundText, isThreadLoading: threadLoading == message.id)
        }
        let data = ChatHistoryEntryData(entry.location, additionalData, autoplayMedia)
        
        
        let timestamp = Int32(min(TimeInterval(message.timestamp) - timeDifference, TimeInterval(Int32.max)))
        
        
        var isRead = entry.isRead
        if !message.flags.contains(.Incoming) {
            var k = i
            loop: while k < messagesEntries.count - 1 {
                let next = messagesEntries[k + 1]
                if next.message.flags.contains(.Incoming) {
                    isRead = true
                    break loop
                }
                k += 1
            }
        }
        
        if let customThreadOutgoingReadState = customThreadOutgoingReadState {
            isRead = customThreadOutgoingReadState >= message.id
        }
        
        if let customChannelDiscussionReadState = customChannelDiscussionReadState {
            attibuteLoop: for i in 0 ..< message.attributes.count {
                if let attribute = message.attributes[i] as? ReplyThreadMessageAttribute {
                    if let maxReadMessageId = attribute.maxReadMessageId {
                        if maxReadMessageId < customChannelDiscussionReadState.id {
                            var attributes = message.attributes
                            attributes[i] = ReplyThreadMessageAttribute(count: attribute.count, latestUsers: attribute.latestUsers, commentsPeerId: attribute.commentsPeerId, maxMessageId: attribute.maxMessageId, maxReadMessageId: customChannelDiscussionReadState.id)
                            message = message.withUpdatedAttributes(attributes)
                        }
                    }
                    break attibuteLoop
                }
            }
        }

        
        
        let entry: ChatHistoryEntry = .MessageEntry(message, MessageIndex(message.withUpdatedTimestamp(timestamp)), isRead, renderType, itemType, fwdType, data)
        
        if let key = message.groupInfo, groupingPhotos, message.id.peerId.namespace == Namespaces.Peer.SecretChat || !message.containsSecretMedia, !message.media.isEmpty {
            if groupInfo == nil {
                groupInfo = key
                groupedPhotos.append(entry.withUpdatedItemType(.Full(rank: rank)))
            } else if groupInfo == key {
                groupedPhotos.append(entry.withUpdatedItemType(.Full(rank: rank)))
            } else {
                if groupedPhotos.count > 0 {
                    if let groupInfo = groupInfo {
                        if groupedPhotos.count > 1 {
                            entries.append(.groupedPhotos(groupedPhotos, groupInfo: groupInfo))
                        } else {
                            entries.append(groupedPhotos[0])
                        }
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
            let timestamp = Int32(min(TimeInterval(message.timestamp) - timeDifference, TimeInterval(Int32.max)))

            let dateId = chatDateId(for: timestamp)
            let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: Namespaces.Message.Local, id: 0), timestamp: Int32(dateId))
            entries.append(.DateEntry(index, renderType))
        }
        
        if let next = next, dayGrouping {
            let timestamp = Int32(min(TimeInterval(message.timestamp) - timeDifference, TimeInterval(Int32.max)))
            let nextTimestamp = Int32(min(TimeInterval(next.message.timestamp) - timeDifference, TimeInterval(Int32.max)))

            let dateId = chatDateId(for: timestamp)
            let nextDateId = chatDateId(for: nextTimestamp)
            
            
            if dateId != nextDateId {
                let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: Namespaces.Message.Local, id: INT_MAX), timestamp: Int32(nextDateId))
                entries.append(.DateEntry(index, renderType))
            }
        }
        if let topMessageIndex = topMessageIndex, topMessageIndex == i {
            let timestamp = Int32(min(TimeInterval(message.timestamp) - timeDifference, TimeInterval(Int32.max)))

            entries.append(.commentsHeader(i == messagesEntries.count - 1, MessageIndex(id: message.id, timestamp: timestamp).successor(), renderType))
        }
    }
    
    
    
    var hasUnread = false
    if let maxReadIndex = maxReadIndex {
        let timestamp = Int32(min(TimeInterval(maxReadIndex.timestamp) - timeDifference, TimeInterval(Int32.max)))
        entries.append(.UnreadEntry(maxReadIndex.withUpdatedTimestamp(timestamp), renderType))
        hasUnread = true
    }
    
    
    
    if includeBottom {
        entries.append(.bottom)
    }
    
    if !groupedPhotos.isEmpty, let key = groupInfo {
        if groupedPhotos.count == 1 {
            entries.append(groupedPhotos[0])
        } else {
            entries.append(.groupedPhotos(groupedPhotos, groupInfo: key))
        }
    }
    
    if addRepliesHeader {
        entries.insert(.repliesHeader(true, MessageIndex.absoluteLowerBound().successor(), renderType), at: 0)
    }
    if let addTopThreadInset = addTopThreadInset {
        entries.insert(.topThreadInset(addTopThreadInset, MessageIndex.absoluteLowerBound(), renderType), at: 0)
    }
    
    var sorted = entries.sorted()

    if hasUnread, sorted.count >= 2 {
        if  case .UnreadEntry = sorted[sorted.count - 2] {
            sorted.remove(at: sorted.count - 2)
        }
    }

    return sorted
}

