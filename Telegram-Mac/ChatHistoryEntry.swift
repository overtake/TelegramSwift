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
import InAppSettings

enum ChatHistoryEntryId : Hashable {
    case message(Message)
    case groupedPhotos(groupInfo: MessageGroupInfo)
    case unread
    case date(MessageIndex)
    case undefined
    case empty(MessageIndex)
    case maybeId(AnyHashable)
    case mediaId(AnyHashable, Message)
    case commentsHeader
    case repliesHeader
    case topThreadInset
    case userInfo
    case topicSeparator(MessageIndex)
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
        case let .mediaId(id, entryId):
            if case .mediaId(id, entryId) = rhs {
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
        case let .empty(index):
            if case .empty(index) = rhs {
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
        case .userInfo:
            if case .userInfo = rhs {
                return true
            } else {
                return false
            }
        case let .topicSeparator(index):
            if case .topicSeparator(index) = rhs {
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
        case .empty:
            return UInt64(10) << 40
        case .mediaId:
            return UInt64(11) << 40
        case .userInfo:
            return UInt64(12) << 40
        case .topicSeparator:
            return UInt64(13) << 40
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
    let updatingMedia: ChatUpdatingMessageMedia?
    let chatTheme: TelegramPresentationTheme?
    let reactions: AvailableReactions?
    let animatedEmojiStickers: [String: StickerPackItem]
    let transribeState:TranscribeAudioState?
    let eventLog: AdminLogEvent?
    let isRevealed: Bool?
    let translate: ChatLiveTranslateContext.State.Result?
    var replyTranslate: ChatLiveTranslateContext.State.Result?
    let storyReadMaxId: Int32?
    let authorStoryStats: PeerStoryStats?
    let cachedData: CachedDataEquatable?
    let recommendedChannels: RecommendedChannels?
    let automaticDownload: AutomaticMediaDownloadSettings
    let savedMessageTags: SavedMessageTags?
    let codeSyntaxData: [CodeSyntaxKey : CodeSyntaxResult]
    let messageEffect: AvailableMessageEffects.MessageEffect?
    let factCheckRevealed: Bool
    let quoteRevealed: Set<Int>
    let monoforumState: MonoforumUIState?
    let canHighlightLinks: Bool
    init(pollStateData: ChatPollStateData = ChatPollStateData(), highlightFoundText: HighlightFoundText? = nil, isThreadLoading: Bool = false, updatingMedia: ChatUpdatingMessageMedia? = nil, chatTheme: TelegramPresentationTheme? = nil, reactions: AvailableReactions? = nil, animatedEmojiStickers: [String: StickerPackItem] = [:], transribeState:TranscribeAudioState? = nil, eventLog: AdminLogEvent? = nil, isRevealed: Bool? = nil, translate: ChatLiveTranslateContext.State.Result? = nil, replyTranslate: ChatLiveTranslateContext.State.Result? = nil, storyReadMaxId: Int32? = nil, authorStoryStats: PeerStoryStats? = nil, cachedData: CachedDataEquatable? = nil, recommendedChannels: RecommendedChannels? = nil, automaticDownload: AutomaticMediaDownloadSettings = .defaultSettings, savedMessageTags: SavedMessageTags? = nil, codeSyntaxData: [CodeSyntaxKey : CodeSyntaxResult] = [:], messageEffect: AvailableMessageEffects.MessageEffect? = nil, factCheckRevealed: Bool = false, quoteRevealed: Set<Int> = Set(), monoforumState: MonoforumUIState? = nil, canHighlightLinks: Bool = true) {
        self.pollStateData = pollStateData
        self.highlightFoundText = highlightFoundText
        self.isThreadLoading = isThreadLoading
        self.updatingMedia = updatingMedia
        self.chatTheme = chatTheme
        self.reactions = reactions
        self.animatedEmojiStickers = animatedEmojiStickers
        self.transribeState = transribeState
        self.eventLog = eventLog
        self.isRevealed = isRevealed
        self.translate = translate
        self.replyTranslate = replyTranslate
        self.storyReadMaxId = storyReadMaxId
        self.authorStoryStats = authorStoryStats
        self.cachedData = cachedData
        self.recommendedChannels = recommendedChannels
        self.automaticDownload = automaticDownload
        self.savedMessageTags = savedMessageTags
        self.codeSyntaxData = codeSyntaxData
        self.messageEffect = messageEffect
        self.factCheckRevealed = factCheckRevealed
        self.quoteRevealed = quoteRevealed
        self.monoforumState = monoforumState
        self.canHighlightLinks = canHighlightLinks
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

struct ChatHistoryEntryData : Equatable {
    let location: MessageHistoryEntryLocation?
    let additionData: MessageEntryAdditionalData
    let autoPlay: AutoplayMediaPreferences?
    let isFakeMessage: Bool
    init(_ location: MessageHistoryEntryLocation? = nil, _ additionData: MessageEntryAdditionalData = .init(), _ autoPlay: AutoplayMediaPreferences? = nil, isFakeMessage: Bool = false) {
        self.location = location
        self.additionData = additionData
        self.autoPlay = autoPlay
        self.isFakeMessage = isFakeMessage
    }
    static func ==(lhs: ChatHistoryEntryData, rhs: ChatHistoryEntryData) -> Bool {
        return lhs.location == rhs.location && lhs.additionData == rhs.additionData && lhs.autoPlay == rhs.autoPlay && lhs.isFakeMessage == rhs.isFakeMessage
    }
}

enum ChatHistoryEntry: Identifiable, Comparable {
    
    
    enum TopicType : Equatable {
        case peer(EnginePeer)
        case topic(Int64, Message.AssociatedThreadInfo)
    }
    
    case MessageEntry(Message, MessageIndex, Bool, ChatItemRenderType, ChatItemType, ForwardItemType?, ChatHistoryEntryData)
    case groupedPhotos([ChatHistoryEntry], groupInfo: MessageGroupInfo)
    case UnreadEntry(MessageIndex, ChatItemRenderType, TelegramPresentationTheme, ChatHistoryEntryData)
    case DateEntry(MessageIndex, ChatItemRenderType, TelegramPresentationTheme, ChatHistoryEntryData)
    case bottom(TelegramPresentationTheme)
    case empty(MessageIndex, TelegramPresentationTheme)
    case commentsHeader(Bool, MessageIndex, ChatItemRenderType)
    case repliesHeader(Bool, MessageIndex, ChatItemRenderType)
    case topThreadInset(CGFloat, MessageIndex, ChatItemRenderType)
    case userInfo(PeerStatusSettings, EnginePeer, GroupsInCommonState?, MessageIndex, ChatItemRenderType, TelegramPresentationTheme)
    case topicSeparator(MessageIndex, TopicType, ChatItemRenderType, ChatHistoryEntryData)
    var message:Message? {
        switch self {
        case let .MessageEntry(message,_, _,_,_,_,_):
            return message
        case let .groupedPhotos(entries, _):
            return nil
        default:
            return nil
        }
    }
    
    var firstMessage:Message? {
        switch self {
        case let .MessageEntry(message,_, _,_,_,_,_):
            return message
        case let .groupedPhotos(entries, _):
            return entries.first?.message
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
        case let .DateEntry(_, renderType, _, _):
            return renderType
        case .UnreadEntry(_, let renderType, _, _):
            return renderType
        case .bottom:
            return .list
        case .empty:
            return .list
        case let .commentsHeader(_, _, renderType):
            return renderType
        case let .repliesHeader(_, _, renderType):
            return renderType
        case let .topThreadInset(_, _, renderType):
            return renderType
        case let .userInfo(_, _ , _, _, renderType, _):
            return renderType
        case let .topicSeparator(_, _, renderType, _):
            return renderType
        }
    }
    var itemType: ChatItemType? {
        switch self {
        case let .MessageEntry(_, _, _, _, itemType, _, _):
            return itemType
        default:
            return nil
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
    
    var isFakeMessage:Bool {
        switch self {
        case let .MessageEntry(_,_,_,_,_,_,data):
            return data.isFakeMessage
        case let .groupedPhotos(entries, groupInfo: _):
            return entries.first?.isFakeMessage ?? false
        case .topicSeparator:
            return true
        default:
            return false
        }
    }
    
    func additionalData(_ messageId: MessageId) -> MessageEntryAdditionalData {
        switch self {
        case let .MessageEntry(_,_,_,_,_,_,data):
            return data.additionData
        case let .groupedPhotos(entries,_):
            return entries.first(where: { $0.message?.id == messageId})?.additionalData ?? MessageEntryAdditionalData()
        case let .DateEntry(_, _, theme, data):
            return data.additionData//MessageEntryAdditionalData(chatTheme: theme)
        case let .topicSeparator(_, _, _, data):
            return data.additionData
        case let .UnreadEntry(_, _, _, data):
            return data.additionData
        default:
            return MessageEntryAdditionalData()
        }
    }
    
    var additionalData: MessageEntryAdditionalData {
        switch self {
        case let .MessageEntry(_,_,_,_,_,_,data):
            return data.additionData
        case let .groupedPhotos(entries,_):
            return entries.first?.additionalData ?? MessageEntryAdditionalData()
        case let .DateEntry(_, _, theme, additionalData):
            return additionalData.additionData
        case let .topicSeparator(_, _, _, data):
            return data.additionData
        case let .UnreadEntry(_, _, _, data):
            return data.additionData
        default:
            return MessageEntryAdditionalData()
        }
    }
    var isRevealed: Bool {
        switch self {
        case let .MessageEntry(_,_,_,_,_,_,data):
            return data.additionData.isRevealed ?? false
        case let .groupedPhotos(entries,_):
            return entries.contains(where: { $0.isRevealed == true })
        default:
            return true
        }
    }
    
    var stableId: ChatHistoryEntryId {
        switch self {
        case let .MessageEntry(message, _, _, _, _, _, _):
            return .message(message)
        case .groupedPhotos(_, let info):
            return .groupedPhotos(groupInfo: info)
        case let .DateEntry(index, _, _, _):
            return .date(index)
        case .UnreadEntry:
            return .unread
        case .bottom:
            return .undefined
        case let .empty(index, _):
            return .empty(index)
        case .commentsHeader:
            return .commentsHeader
        case .repliesHeader:
            return .repliesHeader
        case .topThreadInset:
            return .topThreadInset
        case let .topicSeparator(index, _, _, _):
            return .topicSeparator(index)
        case .userInfo:
            return .userInfo
        }
    }
    
    var index: MessageIndex {
        switch self {
        case let .MessageEntry(_,index, _, _, _, _,_):
            return index
        case let .groupedPhotos(entries, _):
            return entries.last!.index
        case let .UnreadEntry(index, _, _, _):
            return index
        case let .DateEntry(index, _, _, _):
            return index
        case .bottom:
            return MessageIndex.absoluteUpperBound()
        case let .commentsHeader(_, index, _):
            return index
        case let .repliesHeader(_, index, _):
            return index
        case let .topThreadInset(_, index, _):
            return index
        case let .empty(index, _):
            return index
        case let .userInfo(_, _, _, index, _, _):
            return index
        case let .topicSeparator(index, _, _, _):
            return index
        }
    }
    
    
    var scrollIndex: MessageIndex {
        switch self {
        case let .MessageEntry(message, _, _, _, _, _, _):
            return MessageIndex(message)
        case let .groupedPhotos(entries, _):
            return entries.last!.index
        case let .UnreadEntry(index, _, _, _):
            return index
        case let .DateEntry(index, _, _, _):
            return index
        case .bottom:
            return MessageIndex.absoluteUpperBound()
        case let .commentsHeader(_, index, _):
            return index
        case let .repliesHeader(_, index, _):
            return index
        case let .topThreadInset(_, index, _):
            return index
        case let .empty(index, _):
            return index
        case let .userInfo(_, _, _, index, _, _):
            return index
        case let .topicSeparator(index, _, _, _):
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
    func withUpdatedMessageMedia(_ media: Media) -> ChatHistoryEntry {
        switch self {
        case let .MessageEntry(values):
            return .MessageEntry(values.0.withUpdatedMedia([media]), values.1, values.2, values.3, values.4, values.5, values.6)
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
    case let .UnreadEntry(index, renderType, theme, data):
        switch rhs {
        case .UnreadEntry(index, renderType, theme, data):
            return true
        default:
            return false
        }
    case let .DateEntry(index, renderType, theme, data):
        switch rhs {
        case .DateEntry(index, renderType, theme, data):
            return true
        default:
            return false
        }
    case let .bottom(lhsTheme):
        switch rhs {
        case let .bottom(rhsTheme):
            return lhsTheme == rhsTheme
        default:
            return false
        }
    case let .empty(lhsIndex, lhsTheme):
        switch rhs {
        case let .empty(rhsIndex, rhsTheme):
            return lhsTheme == rhsTheme && lhsIndex == rhsIndex
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
    case let .userInfo(value, peer, groups, index, theme, type):
        switch rhs {
        case .userInfo(value, peer, groups, index, theme, type):
            return true
        default:
            return false
        }
    case let .topicSeparator(index, peer, type, data):
        switch rhs {
        case .topicSeparator(index, peer, type, data):
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
        if lhs.isFakeMessage && !rhs.isFakeMessage {
            return true
        } else if !lhs.isFakeMessage && rhs.isFakeMessage {
            return false
        }
        return lhs.stableId.stableIndex < rhs.stableId.stableIndex
    } else {
        return lhsIndex < rhsIndex
    }
}

private var index = 0

func messageEntries(_ messagesEntries: [MessageHistoryEntry], location: ChatLocation? = nil, maxReadIndex:MessageIndex? = nil, includeHoles: Bool = true, dayGrouping: Bool = false, renderType: ChatItemRenderType = .list, includeBottom:Bool = false, timeDifference: TimeInterval = 0, ranks:CachedChannelAdminRanks? = nil, pollAnswersLoading: [MessageId : ChatPollStateData] = [:], threadLoading: MessageId? = nil, groupingPhotos: Bool = false, autoplayMedia: AutoplayMediaPreferences? = nil, searchState: SearchMessagesResultState? = nil, animatedEmojiStickers: [String: StickerPackItem] = [:], topFixedMessages: [Message]? = nil, customChannelDiscussionReadState: MessageId? = nil, customThreadOutgoingReadState: MessageId? = nil, addRepliesHeader: Bool = false, addTopThreadInset: CGFloat? = nil, updatingMedia: [MessageId: ChatUpdatingMessageMedia] = [:], adMessage:Message? = nil, dynamicAdMessages: [Message] = [], chatTheme: TelegramPresentationTheme = theme, reactions: AvailableReactions? = nil, transribeState: [MessageId : TranscribeAudioState] = [:], topicCreatorId: PeerId? = nil, mediaRevealed: Set<MessageId> = Set(), translate: ChatLiveTranslateContext.State? = nil, storyState: PeerExpiringStoryListContext.State? = nil, peerStoryStats: [PeerId : PeerStoryStats] = [:], cachedData: CachedPeerData? = nil, peer: Peer? = nil, holeLater: Bool = false, holeEarlier: Bool = false, recommendedChannels: RecommendedChannels? = nil, includeJoin: Bool = false, earlierId: MessageIndex? = nil, laterId: MessageIndex? = nil, automaticDownload: AutomaticMediaDownloadSettings = .defaultSettings, savedMessageTags: SavedMessageTags? = nil, contentSettings: ContentSettings? = nil, codeSyntaxData: [CodeSyntaxKey : CodeSyntaxResult] = [:], messageEffects: AvailableMessageEffects? = nil, factCheckRevealed: Set<MessageId> = Set(), quoteRevealed: Set<QuoteMessageIndex> = Set(), peerStatus: PeerStatusSettings? = nil, commonGroups: GroupsInCommonState? = nil, monoforumState: MonoforumUIState? = nil, accountPeerId: PeerId? = nil, contentConfig: ContentSettingsConfiguration = .default) -> [ChatHistoryEntry] {
    var entries: [ChatHistoryEntry] = []
    
    var groupedPhotos:[ChatHistoryEntry] = []
    var groupInfo: MessageGroupInfo?
        
    var messagesEntries = messagesEntries
    var topMessageIndex: Int? = nil
    if let topMessages = topFixedMessages, !topMessages.isEmpty {
        messagesEntries.insert(contentsOf: topMessages.map { MessageHistoryEntry(message: $0, isRead: true, location: nil, monthLocation: nil, attributes: .init(authorIsContact: false))}, at: 0)
        topMessageIndex = topMessages.count - 1
    }
    
    if let _ = peer?.restrictionText(contentSettings) {
        return []
    }
    
    
    var joinMessage: Message?
    if let channelPeer = peer {
        if case let .peer(peerId) = location, case let cachedData = cachedData as? CachedChannelData, let invitedOn = cachedData?.invitedOn, includeJoin {
            joinMessage = Message(
                stableId: UInt32.max - 1000,
                stableVersion: 0,
                id: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: 0),
                globallyUniqueId: nil,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: invitedOn,
                flags: [.Incoming],
                tags: [],
                globalTags: [],
                localTags: [],
                customTags: [],
                forwardInfo: nil,
                author: channelPeer,
                text: "",
                attributes: [],
                media: [TelegramMediaAction(action: .joinedByRequest)],
                peers: SimpleDictionary<PeerId, Peer>([channelPeer.id : channelPeer]),
                associatedMessages: SimpleDictionary<MessageId, Message>(),
                associatedMessageIds: [],
                associatedMedia: [:],
                associatedThreadInfo: nil,
                associatedStories: [:]
            )
        } else if let peer = channelPeer as? TelegramChannel, case .broadcast = peer.info, case .member = peer.participationStatus, includeJoin {
            joinMessage = Message(
                stableId: UInt32.max - 1000,
                stableVersion: 0,
                id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Local, id: 0),
                globallyUniqueId: nil,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: peer.creationDate,
                flags: [.Incoming],
                tags: [],
                globalTags: [],
                localTags: [], 
                customTags: [],
                forwardInfo: nil,
                author: channelPeer,
                text: "",
                attributes: [],
                media: [TelegramMediaAction(action: .joinedChannel)],
                peers: SimpleDictionary<PeerId, Peer>([channelPeer.id : channelPeer]),
                associatedMessages: SimpleDictionary<MessageId, Message>(),
                associatedMessageIds: [],
                associatedMedia: [:],
                associatedThreadInfo: nil,
                associatedStories: [:]
            )
        }
    }
    
    
    messagesEntries = messagesEntries.filter { entry in
        if topicCreatorId != nil {
            if let action = entry.message.media.first as? TelegramMediaAction {
                switch action.action {
                case .topicCreated:
                    return false
                default:
                    return true
                }
            }
        } else if let action = entry.message.media.first as? TelegramMediaAction, let replyAttribute = entry.message.replyAttribute {
            switch action.action {
            case .todoAppendTasks, .todoCompletions:
                return entry.message.associatedMessages[replyAttribute.messageId] != nil
            default:
                break
            }
        }
        return true
    }
    
    let insertPendingProccessing:(ChatHistoryEntry)->Void = { entry in
        if let message = entry.firstMessage, message.pendingProcessingAttribute != nil {
            let action = TelegramMediaAction(action: .customText(text: strings().chatVideoProccessingService, entities: [], additionalAttributes: nil))
            let service = message.withUpdatedMedia([action]).withUpdatedStableId(message.stableId + UInt32(Int32.max))
            
            
            entries.append(.MessageEntry(service, MessageIndex(service), false, renderType, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(isFakeMessage: true)))
        }
    }
    
    let insertPaidMessage:(ChatHistoryEntry)->Void = { entry in
        if let message = entry.firstMessage, let attr = message.paidStarsAttribute {
            
            let count: Int
            switch entry {
            case let .groupedPhotos(values, _):
                count = values.count
            case .MessageEntry:
                count = 1
            default:
                count = 0
            }
            
            let text: String
            let price = Int(attr.stars.value) * count
            if let author = message.author, message.peers[message.id.peerId]?.isUser == true {
                if count == 1 {
                    if author.id == message.id.peerId {
                        text = strings().notificationPaidMessage(author.compactDisplayTitle, strings().starListItemCountCountable(Int(price)))
                    } else {
                        text = strings().notificationPaidMessageYou(strings().starListItemCountCountable(Int(price)))
                    }
                } else {
                    let messageText = strings().notificationPaidMessagesCountable(count)
                    if author.id == message.id.peerId {
                        text = strings().notificationPaidMessageMany(author.compactDisplayTitle, strings().starListItemCountCountable(Int(price)), messageText)
                    } else {
                        text = strings().notificationPaidMessageYouMany(strings().starListItemCountCountable(Int(price)), messageText)
                    }
                }
            } else {
                text = ""
            }
            
            if !text.isEmpty {
                let action = TelegramMediaAction(action: .customText(text: text, entities: [], additionalAttributes: nil))
                let service = message.withUpdatedMedia([action]).withUpdatedStableId(message.stableId + UInt32(Int32.max))
                entries.append(.MessageEntry(service, MessageIndex(service), false, renderType, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(isFakeMessage: true)))
            }
        }
    }
    
    let insertTopicSeparator:(ChatHistoryEntry, MessageHistoryEntry?, MessageHistoryEntry?)->Void = { entry, prev, next in
        if let message = entry.firstMessage, let _ = monoforumState {
            let nextId = next?.message.threadId
            if let nextId, nextId != message.threadId, location?.threadId == nil {
                let nextPeerId = PeerId(nextId)
                let peer = next?.message.peers[nextPeerId]
                if let next {
                    let type: ChatHistoryEntry.TopicType?
                    if let peer {
                        type = .peer(.init(peer))
                    } else if let info = next.message.associatedThreadInfo {
                        type = .topic(nextId, info)
                    } else {
                        type = nil
                    }
                    if let type {
                        entries.append(.topicSeparator(MessageIndex(next.message), type, renderType, ChatHistoryEntryData(nil, entry.additionalData)))
                    }
                }
            }
        }
    }
    
    let insertSuggestPostHeader:(ChatHistoryEntry)->Void = { entry in
        if let message = entry.firstMessage, let attr = message.suggestPostAttribute {
            
            let action = TelegramMediaAction(action: .customText(text: "post_suggest:\(attr.amount?.amount.value ?? 0):\(attr.timestamp ?? 0):\(attr.amount?.currency.stringValue ?? XTR)", entities: [], additionalAttributes: nil))
            let service = message.withUpdatedMedia([action]).withUpdatedStableId(message.stableId + UInt32(Int32.max)).withUpdatedTimestamp(message.timestamp - 1)
            entries.append(.MessageEntry(service, MessageIndex(service), false, renderType, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, entry.additionalData, isFakeMessage: true)))

        }
    }
    
    
    for (i, entry) in messagesEntries.enumerated() {
        var message = entry.message
        
    
        if message.media.isEmpty {
            if message.text.length <= 7 {
                
                let customRange: [(NSRange, Int64)] = message.textEntities?.entities.compactMap { entity in
                    if case let .CustomEmoji(_, fileId) = entity.type {
                        let range = NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound)
                        return (range, fileId)
                    }
                    return nil
                } ?? []
                
                
                let original = message.text.withoutColorizer
                let unmodified = original.withoutColorizer.emojiUnmodified
                
                let fullCustom = customRange.first(where: { $0.0.intersection(NSMakeRange(0, message.text.length)) != nil })
                
                if original.isSingleEmoji, let custom = fullCustom {
                    let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: custom.1)

                    if let file = message.associatedMedia[mediaId] as? TelegramMediaFile {
                        var file = file
                        var attributes = file.attributes
                        attributes.append(.FileName(fileName: "telegram-animoji.tgs"))
                        attributes.append(.Sticker(displayText: original, packReference: nil, maskData: nil))
                        
                        file = file.withUpdatedAttributes(attributes)
                        message = message.withUpdatedMedia([file])
                            .withUpdatedText(original)
                    }
                }
                
                if original.isSingleEmoji, let item = animatedEmojiStickers[unmodified] {
                    if fullCustom == nil {
                        var file = item.file._parse()
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
                        if let peer = coreMessageMainPeer(message) as? TelegramChannel {
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
        }
        
        if let updating = updatingMedia[message.id] {
            message = message.withUpdatedText(updating.text)
            var attributes = message.attributes
            if let entities = updating.entities, let index = attributes.firstIndex(where: { $0 is TextEntitiesMessageAttribute }) {
                attributes[index] = entities
            }
            message = message.withUpdatedAttributes(attributes)
            inner: switch updating.media {
            case let .update(media):
                message = message.withUpdatedMedia([media.media])
            default:
                break inner
            }
        }
        
        
        var disableEntry = false
        if let action = message.extendedMedia as? TelegramMediaAction {
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
        
        
        let rawRank = ranks?.ranks.first(where: { $0.key == message.author?.id })?.value
        var rank:String? = nil
        if let rawRank = rawRank {
            switch rawRank {
            case .admin:
                rank = strings().chatAdminBadge
            case .owner:
                rank = strings().chatOwnerBadge
            case let .custom(string):
                rank = string
            }
        } else if let topicCreatorId = topicCreatorId {
            if message.author?.id == topicCreatorId {
                rank = strings().chatTopicBadge
            }
        }
        
        var itemType:ChatItemType = .Full(rank: rank, header: .normal)
        var fwdType:ForwardItemType? = nil
        
        if message.itHasRestrictedContent, message.restrictedText(contentSettings, contentConfig: contentConfig) != nil {
            message = message.withUpdatedMedia([]).withUpdatedText(" ")
        }
                
        if renderType == .list {
            if let prev = prev {
                var actionShortAccess: Bool = true
                if let action = prev.message.extendedMedia as? TelegramMediaAction {
                    switch action.action {
                    case .phoneCall:
                        actionShortAccess = true
                    default:
                        actionShortAccess = false
                    }
                }
                
                if message.author?.id == prev.message.author?.id, (message.timestamp - prev.message.timestamp) < simpleDif, actionShortAccess, let peer = message.peers[message.id.peerId] {
                    if let peer = peer as? TelegramChannel, case .broadcast(_) = peer.info {
                        itemType = .Full(rank: rank, header: .normal)
                    } else {
                        var canShort:Bool = (message.media.isEmpty || message.anyMedia?.isInteractiveMedia == false) || message.forwardInfo == nil || renderType == .list
                        
                        
                        
//                        attrsLoop: for attr in message.attributes {
//                            let contains = allowAttributes.contains(where: { type(of: attr) == $0 })
//                            if !contains {
//                                canShort = false
//                                break attrsLoop
//                            }
//                        }
                        if message.threadId != prev.message.threadId {
                           // canShort = false
                        }
                        itemType = !canShort ? .Full(rank: rank, header: .normal) : .Short(rank: rank, header: .normal)
                        
                    }
                } else {
                    itemType = .Full(rank: rank, header: .normal)
                }
            } else {
                itemType = .Full(rank: rank, header: .normal)
            }
        } else {
            
            let isSameGroup:(Message, Message) -> Bool = { lhs, rhs in
                var accept = abs(lhs.timestamp - rhs.timestamp) < simpleDif
                accept = accept && chatDateId(for: lhs.timestamp) == chatDateId(for: rhs.timestamp)
                accept = accept && lhs.author?.id == rhs.author?.id
                if let maxReadIndex = maxReadIndex {
                    if maxReadIndex >= rhs.index && maxReadIndex < lhs.index {
                        accept = false
                    } else if maxReadIndex < rhs.index && maxReadIndex >= lhs.index {
                        accept = false
                    }
                }
                if lhs.extendedMedia is TelegramMediaAction {
                    accept = false
                }
                if rhs.extendedMedia is TelegramMediaAction {
                    accept = false
                }
                if lhs.isAnonymousMessage {
                    accept = false
                }
                if rhs.isAnonymousMessage {
                    accept = false
                }
                if let peer = lhs.peers[lhs.id.peerId], peer.isForum {
                    if lhs.threadId != rhs.threadId {
                        accept = false
                    }
                }
                return accept
            }
            
            if let next = next {
                if isSameGroup(message, next.message) {
                    if let prev = prev {
                        itemType = .Short(rank: rank, header: isSameGroup(message, prev.message) ? .short : .normal)
                    } else {
                        itemType = .Short(rank: rank, header: .normal)
                    }
                } else {
                    if let prev = prev {
                        let shouldGroup = isSameGroup(message, prev.message)
                        itemType = .Full(rank: rank, header: shouldGroup ? .short : .normal)
                    } else {
                        itemType = .Full(rank: rank, header:  .normal)
                    }
                }
            } else {
                if let prev = prev {
                    let shouldGroup = isSameGroup(message, prev.message)
                    itemType = .Full(rank: rank, header: shouldGroup ? .short : .normal)
                } else {
                    itemType = .Full(rank: rank, header: .normal)
                }
            }
        }
        
        
        
        
        if message.forwardInfo != nil, !message.isImported {
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
        
        if let forwardType = fwdType, forwardType == .ShortHeader || forwardType == .FullHeader, renderType != .bubble {
            itemType = .Full(rank: rank, header: .normal)
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
        
        
        if let searchState = searchState, !message.text.isEmpty, searchState.containsMessage(message) {
            highlightFoundText = HighlightFoundText(query: searchState.query, isMessage: true)
        }
        
        let pollData = pollAnswersLoading[message.id] ?? ChatPollStateData()
        
        var messageTranslate: ChatLiveTranslateContext.State.Result?
        var replyTranslate: ChatLiveTranslateContext.State.Result?
        if let translate = translate {
            messageTranslate = translate.result[.Key(id: message.id, toLang: translate.to)]
            if let reply = message.replyAttribute, let replyMessage = message.associatedMessages[reply.messageId] {
                replyTranslate = translate.result[.init(id: replyMessage.id, toLang: translate.to)]
            } else {
                replyTranslate = nil
            }
            if translate.canTranslate, translate.translate {
                if let _ = message.translationAttribute(toLang: translate.to) {
                    messageTranslate = .complete(toLang: translate.to)
                }
                if let reply = message.replyAttribute, let replyMessage = message.associatedMessages[reply.messageId] {
                    if let _ = replyMessage.translationAttribute(toLang: translate.to) {
                        replyTranslate = .complete(toLang: translate.to)
                    }
                }
            }
        }
        
        let messageEffect: AvailableMessageEffects.MessageEffect?
        if let effectAttribute = message.effectAttribute {
            messageEffect = messageEffects?.messageEffects.first(where: { $0.id == effectAttribute.id })
        } else {
            messageEffect = nil
        }
        
        let quoteRevealed = Set(quoteRevealed.filter( { $0.messageId == message.id }).map { $0.index })
        
        additionalData = MessageEntryAdditionalData(pollStateData: pollData, highlightFoundText: highlightFoundText, isThreadLoading: threadLoading == message.id, updatingMedia: updatingMedia[message.id], chatTheme: chatTheme, reactions: reactions, animatedEmojiStickers: animatedEmojiStickers, transribeState: transribeState[message.id], isRevealed: mediaRevealed.contains(message.id), translate: messageTranslate, replyTranslate: replyTranslate, storyReadMaxId: storyState?.maxReadId, authorStoryStats: message.author.flatMap { peerStoryStats[$0.id] }, cachedData: .init(cachedData), automaticDownload: automaticDownload, savedMessageTags: savedMessageTags, codeSyntaxData: codeSyntaxData.filter { $0.key.messageId == message.id }, messageEffect: messageEffect, factCheckRevealed: factCheckRevealed.contains(message.id), quoteRevealed: quoteRevealed, monoforumState: monoforumState, canHighlightLinks: peerStatus?.contains(.canReport) == true ? false : true)
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
                groupedPhotos.append(entry.withUpdatedItemType(itemType))
            } else if groupInfo == key {
                groupedPhotos.append(entry.withUpdatedItemType(itemType))
            } else {
                if groupedPhotos.count > 0 {
                    if let groupInfo = groupInfo {
                        if groupedPhotos.count > 1 {
                            let entry: ChatHistoryEntry = .groupedPhotos(groupedPhotos, groupInfo: groupInfo)
                            entries.append(entry)
                            insertPendingProccessing(entry)
                            insertPaidMessage(entry)
                            insertTopicSeparator(entry, prev, next)
                            insertSuggestPostHeader(entry)
                        } else if let single = groupedPhotos.first {
                            entries.append(single)
                            insertPendingProccessing(single)
                            insertPaidMessage(single)
                            insertTopicSeparator(single, prev, next)
                            insertSuggestPostHeader(single)
                        }
                    }
                    groupedPhotos.removeAll()
                }
                
                groupInfo = key
                groupedPhotos.append(entry.withUpdatedItemType(itemType))
            }
        } else {
            entries.append(entry)
            insertPendingProccessing(entry)
            insertPaidMessage(entry)
            insertSuggestPostHeader(entry)
            insertTopicSeparator(entry, prev, next)
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
            entries.append(.DateEntry(index, renderType, chatTheme, .init(nil, additionalData)))
        }
        
       
        
        if let next = next, dayGrouping {
            let timestamp = Int32(min(TimeInterval(message.timestamp) - timeDifference, TimeInterval(Int32.max)))
            let nextTimestamp = Int32(min(TimeInterval(next.message.timestamp) - timeDifference, TimeInterval(Int32.max)))

            let dateId = chatDateId(for: timestamp)
            let nextDateId = chatDateId(for: nextTimestamp)
            
            
            if dateId != nextDateId {
                let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: Namespaces.Message.Local, id: INT_MAX), timestamp: Int32(nextDateId))
                entries.append(.DateEntry(index, renderType, chatTheme, .init(nil, additionalData)))
            }
        }
        if let topMessageIndex = topMessageIndex, topMessageIndex == i {
            let timestamp = Int32(min(TimeInterval(message.timestamp) - timeDifference, TimeInterval(Int32.max)))

            entries.append(.commentsHeader(i == messagesEntries.count - 1, MessageIndex(id: message.id, timestamp: timestamp).peerLocalSuccessor(), renderType))
        }
    }
    
    if let lowerTimestamp = messagesEntries.last?.message.timestamp, let upperTimestamp = messagesEntries.first?.message.timestamp {
        if let joinMessage = joinMessage {
            var insertAtPosition: Int?
            if joinMessage.timestamp >= lowerTimestamp && laterId == nil {
                insertAtPosition = entries.count
            } else if joinMessage.timestamp < lowerTimestamp && joinMessage.timestamp > upperTimestamp {
                for i in 0 ..< entries.count {
                    if let timestamp = entries[i].message?.timestamp, timestamp > joinMessage.timestamp {
                        insertAtPosition = i
                        break
                    }
                }
            }
            if let insertAtPosition = insertAtPosition {
                entries.append(.MessageEntry(joinMessage, MessageIndex(joinMessage), true, renderType, .Full(rank: nil, header: .normal), nil, .init(nil, .init(recommendedChannels: recommendedChannels), autoplayMedia)))
            }
        }
    }

    var hasUnread = false
    if let maxReadIndex = maxReadIndex {
        let timestamp = Int32(min(TimeInterval(maxReadIndex.timestamp) - timeDifference, TimeInterval(Int32.max)))
        entries.append(.UnreadEntry(maxReadIndex.withUpdatedTimestamp(timestamp), renderType, chatTheme, .init(nil, .init(chatTheme: chatTheme, monoforumState: monoforumState))))
        hasUnread = true
    }
    
    
    
    if includeBottom {
        entries.append(.bottom(chatTheme))
    }
    
    if !groupedPhotos.isEmpty, let key = groupInfo {
        if groupedPhotos.count == 1 {
            entries.append(groupedPhotos[0])
            insertPendingProccessing(groupedPhotos[0])
            insertPaidMessage(groupedPhotos[0])
            insertSuggestPostHeader(groupedPhotos[0])
            insertTopicSeparator(groupedPhotos[0], messagesEntries.count >= 2 ? messagesEntries[messagesEntries.count - 2] : nil, nil)
        } else {
            let entry: ChatHistoryEntry = .groupedPhotos(groupedPhotos, groupInfo: key)
            entries.append(entry)
            insertPendingProccessing(entry)
            insertPaidMessage(entry)
            insertSuggestPostHeader(entry)
            insertTopicSeparator(entry, messagesEntries.count >= 2 ? messagesEntries[messagesEntries.count - 2] : nil, nil)
        }
    }
    
    if addRepliesHeader {
        entries.insert(.repliesHeader(true, MessageIndex.absoluteLowerBound().globalSuccessor(), renderType), at: 0)
    }
    if let addTopThreadInset = addTopThreadInset {
        entries.insert(.topThreadInset(addTopThreadInset, MessageIndex.absoluteLowerBound(), renderType), at: 0)
    }
    
    if let monoforumState, monoforumState == .horizontal {
        entries.insert(.topThreadInset(40, MessageIndex.absoluteLowerBound(), renderType), at: 0)
    }

  
    if !dynamicAdMessages.isEmpty {
        for message in dynamicAdMessages {
            entries.append(.MessageEntry(message, MessageIndex(message), true, renderType, .Full(rank: nil, header: .normal), nil, .init(nil, .init(), autoplayMedia)))
        }
    }
    
    if let peerStatus, peerStatus.phoneCountry != nil, let message = messagesEntries.first, let peer = message.message.peers[message.message.id.peerId] {
        entries.append(.userInfo(peerStatus, .init(peer), commonGroups, MessageIndex.absoluteLowerBound(), renderType, chatTheme))
    }

    
    if let lastMessage = entries.last(where: { $0.message != nil })?.message {
        var nextAdMessageId: Int32 = 1
        
        let fixedAdMessageStableId: UInt32 = UInt32.max - 5000

        if adMessage != nil {
            entries.append(.empty(MessageIndex(id: .init(peerId: lastMessage.id.peerId, namespace: lastMessage.id.namespace, id: Int32.max - 150), timestamp: Int32.max - 150), chatTheme))
            nextAdMessageId += 1
        }
        if let message = adMessage {
            let updatedMessage = Message(
                stableId: fixedAdMessageStableId,
                stableVersion: message.stableVersion,
                id: MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: nextAdMessageId),
                globallyUniqueId: nil,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: (Int32.max - 100) + nextAdMessageId,
                flags: message.flags,
                tags: message.tags,
                globalTags: message.globalTags,
                localTags: message.localTags,
                customTags: message.customTags,
                forwardInfo: message.forwardInfo,
                author: message.author,
                text: message.text,
                attributes: message.attributes,
                media: message.media,
                peers: message.peers,
                associatedMessages: message.associatedMessages,
                associatedMessageIds: message.associatedMessageIds,
                associatedMedia: [:],
                associatedThreadInfo: message.associatedThreadInfo,
                associatedStories: message.associatedStories
            )
            nextAdMessageId += 1
            
            let timestamp = Int32(min(TimeInterval(updatedMessage.timestamp) - timeDifference, TimeInterval(Int32.max)))
            entries.append(.MessageEntry(updatedMessage, MessageIndex(updatedMessage.withUpdatedTimestamp(timestamp)), true, renderType, .Full(rank: nil, header: .normal), nil, .init(nil, .init(), autoplayMedia)))
            
        }
    }
    
    var sorted = entries.sorted()

    
    if hasUnread, sorted.count >= 2 {
        if  case .UnreadEntry = sorted[sorted.count - 2] {
            sorted.remove(at: sorted.count - 2)
        }
    }
    

    return sorted
}

