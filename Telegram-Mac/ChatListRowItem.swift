//
//  TGDialogRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import DateUtils
import SwiftSignalKit
import InAppSettings


class ChatListTags {
    
    struct Extender {
        var tag: ChatListTag
        var index: Int
    }
    var tags: [ChatListTag]
    var extender: Extender?
    
    var effective: [ChatListTag] {
        if let extender {
            return tags.prefix(upTo: extender.index) + [extender.tag]
        } else {
            return tags
        }
    }
    
    init(tags: [ChatListTag], extender: Extender? = nil) {
        self.tags = tags
        self.extender = extender
    }
}

struct ChatListTag {
    let text: TextViewLayout
    let selected: TextViewLayout
    let color: NSColor
    let selectedColor: NSColor
    
    var size: NSSize {
        return NSMakeSize(text.layoutSize.width + 4, text.layoutSize.height + 4)
    }
}

enum ChatListPinnedType {
    case some
    case last
    case none
    case ad(EngineChatList.AdditionalItem)
}


final class SelectChatListItemPresentation : Equatable {
    let selected:Set<ChatLocation>
    static func ==(lhs:SelectChatListItemPresentation, rhs:SelectChatListItemPresentation) -> Bool {
        return lhs.selected == rhs.selected
    }
    
    init(_ selected:Set<ChatLocation> = Set()) {
        self.selected = selected
    }
    
    func deselect(chatLocation:ChatLocation) -> SelectChatListItemPresentation {
        var chatLocations:Set<ChatLocation> = Set<ChatLocation>()
        chatLocations.formUnion(selected)
        let _ = chatLocations.remove(chatLocation)
        return SelectChatListItemPresentation(chatLocations)
    }
    
    func withToggledSelected(_ chatLocation: ChatLocation) -> SelectChatListItemPresentation {
        var chatLocations:Set<ChatLocation> = Set<ChatLocation>()
        chatLocations.formUnion(selected)
        if chatLocations.contains(chatLocation) {
            let _ = chatLocations.remove(chatLocation)
        } else {
            chatLocations.insert(chatLocation)
        }
        return SelectChatListItemPresentation(chatLocations)
    }
    
}

final class SelectChatListInteraction : InterfaceObserver {
    private(set) var presentation:SelectChatListItemPresentation = SelectChatListItemPresentation()
    
    func update(animated:Bool = true, _ f:(SelectChatListItemPresentation)->SelectChatListItemPresentation)->Void {
        let oldValue = self.presentation
        presentation = f(presentation)
        if oldValue != presentation {
            notifyObservers(value: presentation, oldValue:oldValue, animated:animated)
        }
    }
    
}

enum ChatListRowState : Equatable {
    case plain
    case deletable(onRemove:(ChatLocation)->Void, deletable:Bool)
    
    static func ==(lhs: ChatListRowState, rhs: ChatListRowState) -> Bool {
        switch lhs {
        case .plain:
            if case .plain = rhs {
                return true
            } else {
                return false
            }
        case .deletable(_, let deletable):
            if case .deletable(_, deletable) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}


class ChatListRowItem: TableRowItem {

    struct Badge {
        let dynamicValue: DynamicCounterTextView.Value
        let backgroundColor: NSColor
        let size: NSSize
        init(dynamicValue: DynamicCounterTextView.Value, backgroundColor: NSColor, size: NSSize) {
            self.dynamicValue = dynamicValue
            self.backgroundColor = backgroundColor
            var mapped = NSMakeSize(max(CGFloat(dynamicValue.values.count) * 10 - 10 + 7, size.width + 8), size.height + 7)
            mapped = NSMakeSize(max(mapped.height,mapped.width), mapped.height)
            self.size = mapped
        }
    }
        
    private var messages:[Message]
    var message: Message? {
        return messages.first(where: { !$0.text.isEmpty }) ?? messages.first
    }
    
    let context: AccountContext
    let peer:Peer?
    let renderedPeer:EngineRenderedPeer?
    let groupId: EngineChatList.Group
    let forumTopicData: EngineChatList.ForumTopicData?
    let forumTopicItems:[EngineChatList.ForumTopicData]
    var hasForumIcon: Bool {
        if chatNameLayout != nil, forumTopicNameLayout != nil {
            if forumTopicData != nil {
                return true
            } else if let peer = peer, peer.isForum, titleMode == .forumInfo, case .topic = mode {
                return true
            }
        }
        return false
    }
    
    var isPaidSubscriptionChannel: Bool {
        return (peer as? TelegramChannel)?.subscriptionUntilDate != nil
    }
    
    let chatListIndex:ChatListIndex?
    var peerId:PeerId? {
        switch mode {
        case .savedMessages:
            return context.peerId
        default:
            return renderedPeer?.peerId
        }
    }
    
    let photo: AvatarNodeState
    
    var isGroup: Bool {
        return groupId != .root
    }
    
    
    override var stableId: AnyHashable {
        switch _stableId {
        case let .chatId(id, peerId, _):
            return UIChatListEntryId.chatId(id, peerId, -1)
        default:
            return _stableId
        }
    }
    
    private var _stableId: UIChatListEntryId
    var entryId: UIChatListEntryId {
        return _stableId
    }
    
    var lastThreadId: Int64? {
        if let item = forumTopicItems.first, item.isUnread {
            return item.id
        }
        return nil
    }
    
    var isForum: Bool {
        if let peer = peer, peer.isForum && !peer.displayForumAsTabs {
            return true
        }
        return false
    }
    var isTopic: Bool {
        switch self.mode {
        case .topic:
            return true
        case .chat, .savedMessages:
            return false
        }
    }
    
    var chatLocation: ChatLocation? {
        if let index = chatListIndex {
            return ChatLocation.peer(index.messageIndex.id.peerId)
        }
        return nil
    }

    let mentionsCount: Int32?
    let reactionsCount: Int32?

    private var date:NSAttributedString?

    private var displayLayout:TextViewLayout?
    private var displaySelectedLayout:TextViewLayout?
    
    private var dateLayout:TextViewLayout?
    private var dateSelectedLayout:TextViewLayout?


    private var messageLayout:TextViewLayout?
    private var messageSelectedLayout:TextViewLayout?
    
    private(set) var topicsLayout: ChatListTopicNameAndTextLayout?
    
    private var chatNameLayout:TextViewLayout?
    private var chatNameSelectedLayout:TextViewLayout?

    private var forumTopicNameLayout:TextViewLayout?
    private var forumTopicNameSelectedLayout:TextViewLayout?

            
    private(set) var peerNotificationSettings:PeerNotificationSettings?
    private(set) var readState:EnginePeerReadCounters?
    
    
    
    private var badgeNode:BadgeNode? = nil
    private var badgeSelectedNode:BadgeNode? = nil
    
    private var shortBadgeNode:BadgeNode? = nil
    private var shortBadgeSelectedNode:BadgeNode? = nil


    private let _animateArchive:Atomic<Bool> = Atomic(value: false)
    
    var animateArchive:Bool {
        return _animateArchive.swap(false)
    }
    
    let filter: ChatListFilter
    let splitState: SplitViewState
    
    var isCollapsed: Bool {
        if let hideStatus = hideStatus {
            switch hideStatus {
            case .collapsed:
                return context.layout != .minimisize
            default:
                return false
            }
        }
        return false
    }
    
    
    var canDeleteTopic: Bool {
        if isTopic, let peer = peer as? TelegramChannel, peer.isAdmin {
            if peer.hasPermission(.manageTopics) {
                return true
            }
        }
        return false
    }
    
    var hasRevealState: Bool {
        return canArchive || (groupId != .root && !isCollapsed)
    }
    
    var canArchive: Bool {
        if groupId != .root {
            return false
        }
        if mode.savedMessages {
            return false
        }
        if context.peerId == peerId {
            return false
        }
        if case .ad = pinnedType {
            return false
        }
        if self.peer?.id == servicePeerId {
            return false
        }
        if self.peer?.id == verifyCodePeerId {
            return false
        }
        return true
    }
    
    let associatedGroupId: EngineChatList.Group
    
    let isMuted:Bool
    
    var hasUnread: Bool {
        return ctxBadgeNode != nil
    }
    
    let isVerified: Bool
    let isPremium: Bool
    let isScam: Bool
    let isFake: Bool

    
    private(set) var photos: [TelegramPeerPhoto] = []
    private let peerPhotosDisposable = MetaDisposable()

    
    var isOutMessage:Bool {
        if let message = message {
            return !message.flags.contains(.Incoming) && message.id.peerId != context.peerId
        }
        return false
    }
    var isRead:Bool {
        switch mode {
        case let .topic(_, data):
            if let message = message {
                if data.maxOutgoingReadId >= message.id.id {
                    return true
                }
            }
        default:
            if let peer = peer as? TelegramUser {
                if let _ = peer.botInfo {
                    return !peer.flags.contains(.isSupport)
                }
                if peer.id == context.peerId {
                    return true
                }
            }
            if let peer = peer as? TelegramChannel {
                if case .broadcast = peer.info {
                    return true
                }
            }
            if isForum, let message = message {
                for topic in forumTopicItems.prefix(1) {
                    if topic.maxOutgoingReadMessageId <= message.id {
                        return true
                    }
                }
                
            }
            if let readState = readState {
                if let message = message {
                    return readState.isOutgoingMessageIndexRead(MessageIndex(message))
                }
            }
        }
        
        
        return false
    }
    
    
    var isUnreadMarked: Bool {
        if let readState = readState {
            return readState.markedUnread
        }
        return false
    }
    
    var isSecret:Bool {
        if let renderedPeer = renderedPeer {
            return renderedPeer.peers[renderedPeer.peerId]?._asPeer() is TelegramSecretChat
        } else {
            return false
        }
    }
    
    var isSending:Bool {
        if let message = message {
            return message.flags.contains(.Unsent)
        }
        return false
    }
    
    var isFailed: Bool {
        return self.hasFailed
    }
    
    var isSavedMessage: Bool {
        return peer?.id == context.peerId
    }
    var isAnonynousSavedMessage: Bool {
        return peer?.id.isAnonymousSavedMessages == true
    }
    var isRepliesChat: Bool {
        return peer?.id == repliesPeerId
    }
    
    override var identifier: String {
        if hideStatus == .collapsed {
            return super.identifier + "collapsed"
        } else if hideStatus == .normal {
            return super.identifier + "normal"
        }
        return super.identifier
    }
    
    let hasDraft:Bool
    let hideContent: Bool
    private let hasFailed: Bool
    let pinnedType:ChatListPinnedType
    let activities: [PeerListState.InputActivities.Activity]
    
    var toolTip: String? {
        return messageLayout?.attributedString.string
    }
    
    private(set) var isOnline: Bool?
    
    private(set) var hasActiveGroupCall: Bool = false
    
    private var presenceManager:PeerPresenceStatusManager?
    
    let hideStatus: ItemHideStatus?
    
    private var groupItems:[EngineChatList.GroupItem.Item] = []
    
    private var textLeftCutout: CGFloat = 0.0
    let contentImageSize = CGSize(width: 16, height: 16)
    let contentImageSpacing: CGFloat = 2.0
    let contentImageTrailingSpace: CGFloat = 5.0
    private(set) var contentImageSpecs: [(message: Message, media: Media, size: CGSize)] = []


    let isArchiveItem: Bool
    
    init(_ initialSize:NSSize, context: AccountContext, stableId: UIChatListEntryId, pinnedType: ChatListPinnedType, groupId: EngineChatList.Group, groupItems: [EngineChatList.GroupItem.Item], messages: [Message], unreadCount: Int, activities: [PeerListState.InputActivities.Activity] = [], animateGroup: Bool = false, hideStatus: ItemHideStatus = .normal, hasFailed: Bool = false, filter: ChatListFilter = .allChats, appearMode: PeerListState.AppearMode = .normal, hideContent: Bool = false, getHideProgress:(()->CGFloat?)? = nil, openStory: @escaping(StoryInitialIndex?, Bool, Bool)->Void = { _, _, _ in }, storyState: EngineStorySubscriptions? = nil, isContact: Bool = false) {
        self.groupId = groupId
        self.peer = nil
        self.mode = .chat
        self.messages = messages
        self.chatListIndex = nil
        self.activities = activities
        self.context = context
        self.mentionsCount = nil
        self.reactionsCount = nil
        self.selectedForum = nil
        self.story = nil
        self.displayAsTopics = false
        self.openStory = openStory
        self.storyState = storyState
        self._stableId = stableId
        self.pinnedType = pinnedType
        self.splitState = context.layout
        self.renderedPeer = nil
        self.forumTopicData = nil
        self.forumTopicItems = []
        self.associatedGroupId = .root
        self.appearMode = appearMode
        self.isMuted = false
        self.isContact = false
        self.isOnline = nil
        self.getHideProgress = getHideProgress
        self.hideStatus = hideStatus
        self.autoremoveTimeout = nil
        self.groupItems = groupItems
        self.isVerified = false
        self.isPremium = false
        self.isScam = false
        self.hideContent = hideContent
        self.isFake = false
        self.openMiniApp = nil
        self.openMiniAppSelected = nil
        self.monoforumMessages = nil
        self.monoforumMessagesSelected = nil
        self.filter = filter
        self.hasFailed = hasFailed
        self.isArchiveItem = true
        self.folders = nil
        self.tags = nil
        self.canPreviewChat = false
        if let storyState = storyState, storyState.items.count > 0 {
            let unseenCount: Int = storyState.items.reduce(0, {
                $0 + ($1.unseenCount > 0 ? 1 : 0)
            })
            self.avatarStoryIndicator = .init(stats: .init(totalCount: storyState.items.count, unseenCount: unseenCount, hasUnseenCloseFriends: false), presentation: theme)
        } else {
            self.avatarStoryIndicator = nil
        }
                
        let titleText:NSMutableAttributedString = NSMutableAttributedString()
        let _ = titleText.append(string: strings().chatListArchivedChats, color: theme.chatList.textColor, font: .medium(.title))
        titleText.setSelected(color: theme.colors.underSelectedColor ,range: titleText.range)
        
        self.displayLayout = TextViewLayout(titleText, maximumNumberOfLines: 1)
        
        let selected = titleText.mutableCopy() as! NSMutableAttributedString
        if let color = selected.attribute(.selectedColor, at: 0, effectiveRange: nil) {
            selected.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: selected.range)
            self.displaySelectedLayout = TextViewLayout(selected, mayItems: false)
        }
        
        hasDraft = false
        
    

        
        if let message = messages.first {
            let date:NSMutableAttributedString = NSMutableAttributedString()
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= context.timeDifference
            let range = date.append(string: DateUtils.string(forMessageListDate: Int32(time)), color: theme.colors.grayText, font: .normal(.short))
            date.setSelected(color: theme.colors.underSelectedColor,range: range)
            self.date = date.copy() as? NSAttributedString
            
            self.dateLayout = TextViewLayout(date, mayItems: false)
            self.dateLayout?.measure(width: .greatestFiniteMagnitude)
            
            let selectedDate = date.mutableCopy() as! NSMutableAttributedString
            if let color = selectedDate.attribute(.selectedColor, at: 0, effectiveRange: nil) {
                selectedDate.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: selectedDate.range)
                self.dateSelectedLayout = TextViewLayout(selectedDate, mayItems: false)
                self.dateSelectedLayout?.measure(width: .greatestFiniteMagnitude)
            }
            
        }
        
        
        let mutedCount = unreadCount
        
        self.highlightText = nil
        self.draft = nil
        
        photo = .ArchivedChats
        self.titleMode = .normal
        super.init(initialSize)
        
        if case .hidden(true) = hideStatus {
            hideItem(animated: false, reload: false)
        }
        
        
        _ = _animateArchive.swap(animateGroup)
        
        if mutedCount > 0  {
            badgeNode = BadgeNode(.initialize(string: "\(mutedCount)", color: theme.chatList.badgeTextColor, font: .medium(.small)), theme.chatList.badgeMutedBackgroundColor)
            badgeSelectedNode = BadgeNode(.initialize(string: "\(mutedCount)", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
            
            shortBadgeNode = BadgeNode(.initialize(string: "\(mutedCount)", color: theme.chatList.badgeTextColor, font: .medium(.small)), theme.chatList.badgeMutedBackgroundColor)
            shortBadgeSelectedNode = BadgeNode(.initialize(string: "\(mutedCount)", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)

        }
        
        var messageText: NSAttributedString
        if groupItems.count == 1 {
            messageText = chatListText(account: context.account, for: message, messagesCount: 1, folder: true)
        } else {
            let textString = NSMutableAttributedString(string: "")
            var isFirst = true
            var wasRead: Bool = false
            for item in groupItems {
                if let chatMainPeer = item.peer.chatMainPeer?._asPeer() {
                    let peerTitle = chatMainPeer.compactDisplayTitle
                    if !peerTitle.isEmpty {
                        if isFirst {
                            isFirst = false
                        } else {
                            textString.append(.initialize(string: ", ", color: !wasRead ? theme.chatList.textColor : theme.chatList.grayTextColor, font: .normal(.text)))
                        }
                        textString.append(.initialize(string: peerTitle, color: item.isUnread ? theme.chatList.textColor : theme.chatList.grayTextColor, font: .normal(.text)))
                        wasRead = !item.isUnread
                    }
                }
            }
            messageText = textString
        }
        
        if messageText.string.isEmpty, let storyState = storyState, storyState.items.count > 0 {
            messageText = .initialize(string: strings().chatListArchiveStoryCountCountable(storyState.items.count), color: theme.chatList.grayTextColor, font: .normal(.text))
        }
        
        if let messageText = messageText.trimmed.mutableCopy() as? NSMutableAttributedString, !messageText.string
            .isEmpty {
            self.messageLayout = .init(messageText, maximumNumberOfLines: 2)
            let selectedText:NSMutableAttributedString = messageText.mutableCopy() as! NSMutableAttributedString
            if let color = selectedText.attribute(.selectedColor, at: 0, effectiveRange: nil) {
                selectedText.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: selectedText.range)
                
                
                self.messageSelectedLayout = .init(selectedText, maximumNumberOfLines: 2)
            }
        }

        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    private let highlightText: String?
    
    private let draft:EngineChatList.Draft?
    
    enum Mode {
        case chat
        case savedMessages(Int64)
        case topic(Int64, MessageHistoryThreadData)
        
        var savedMessages: Bool {
            switch self {
            case .savedMessages:
                return true
            default:
                return false
            }
        }
        
        var threadId: Int64? {
            switch self {
            case let .topic(threadId, _):
                return threadId
            case let .savedMessages(threadId):
                return threadId
            default:
                return nil
            }
        }
        var threadData: MessageHistoryThreadData? {
            switch self {
            case let .topic(_, data):
                return data
            default:
                return nil
            }
        }
        var isGeneralTopic: Bool {
            return threadId == 1
        }
    }
    enum TitleMode {
        case normal
        case forumInfo
    }
    
    let mode: Mode
    let titleMode: TitleMode
    let appearMode: PeerListState.AppearMode
    let getHideProgress:(()->CGFloat?)?
    let selectedForum: PeerId?
    let autoremoveTimeout: Int32?
    let isContact: Bool
    
    
    let story: EngineChatList.StoryStats?
    let storyState: EngineStorySubscriptions?
    let avatarStoryIndicator: AvatarStoryIndicatorComponent?
    
    let openStory:(StoryInitialIndex?, Bool, Bool)->Void


    

    var isSelectedForum: Bool {
        if let selectedForum = selectedForum, isForum {
            if selectedForum == peerId {
                return true
            }
        }
        return false
    }
    
    let displayAsTopics: Bool
    let folders: FilterData?
    
    
    let tags: ChatListTags?
    
    let canPreviewChat: Bool
    
    let openMiniApp: TextViewLayout?
    let openMiniAppSelected: TextViewLayout?
    
    let monoforumMessages: TextViewLayout?
    let monoforumMessagesSelected: TextViewLayout?


    init(_ initialSize:NSSize, context: AccountContext, stableId: UIChatListEntryId, mode: Mode, messages: [Message], index: ChatListIndex? = nil, readState:EnginePeerReadCounters? = nil, draft:EngineChatList.Draft? = nil, pinnedType:ChatListPinnedType = .none, renderedPeer:EngineRenderedPeer, peerPresence: EnginePeer.Presence? = nil, forumTopicData: EngineChatList.ForumTopicData? = nil, forumTopicItems:[EngineChatList.ForumTopicData] = [], activities: [PeerListState.InputActivities.Activity] = [], highlightText: String? = nil, associatedGroupId: EngineChatList.Group = .root, isMuted:Bool = false, hasFailed: Bool = false, hasUnreadMentions: Bool = false, hasUnreadReactions: Bool = false, showBadge: Bool = true, filter: ChatListFilter = .allChats, hideStatus: ItemHideStatus? = nil, titleMode: TitleMode = .normal, appearMode: PeerListState.AppearMode = .normal, hideContent: Bool = false, getHideProgress:(()->CGFloat?)? = nil, selectedForum: PeerId? = nil, autoremoveTimeout: Int32? = nil, story: EngineChatList.StoryStats? = nil, openStory: @escaping(StoryInitialIndex?, Bool, Bool)->Void = { _, _, _ in }, storyState: EngineStorySubscriptions? = nil, isContact: Bool = false, displayAsTopics: Bool = false, folders: FilterData? = nil, canPreviewChat: Bool = false) {
        
        
        if !forumTopicItems.isEmpty {
            var bp = 0
            bp += 1
        }
        
        var draft = draft
        
        if let peer = renderedPeer.chatMainPeer?._asPeer() as? TelegramChannel {
            if !peer.hasPermission(.sendSomething) {
                draft = nil
            }
        }
        
        if let value = draft {
            if value.text.isEmpty {
                draft = nil
            }
        }
        
        if let peerPresence = peerPresence?._asPresence(), context.peerId != renderedPeer.peerId, renderedPeer.peerId != servicePeerId {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            let relative = relativeUserPresenceStatus(peerPresence, timeDifference: context.timeDifference, relativeTo: Int32(timestamp))
            switch relative {
            case .online:
                self.isOnline = true
            default:
                self.isOnline = false
            }
        } else {
            self.isOnline = nil
        }
        
        if let peer = renderedPeer.chatMainPeer?._asPeer() as? TelegramChannel, peer.flags.contains(.hasActiveVoiceChat) {
            self.hasActiveGroupCall = mode.threadId == nil
        }
        
        self.mode = mode
        self.titleMode = titleMode
        self.chatListIndex = index
        self.renderedPeer = renderedPeer
        self.context = context
        self.story = story
        self.openStory = openStory
        self.messages = messages
        self.activities = activities
        self.pinnedType = pinnedType
        self.splitState = context.layout
        self.hideStatus = hideStatus
        self.autoremoveTimeout = autoremoveTimeout
        self.getHideProgress = getHideProgress
        self.forumTopicData = forumTopicData
        self.forumTopicItems = forumTopicItems
        self.selectedForum = selectedForum
        self.storyState = storyState
        self.hasDraft = draft != nil
        self.draft = draft
        self.peer = renderedPeer.chatMainPeer?._asPeer()
        self.groupId = .root
        self.hasFailed = hasFailed
        self.filter = filter
        self.isArchiveItem = false
        self.displayAsTopics = displayAsTopics
        self.hideContent = hideContent
        self.appearMode = appearMode
        self.associatedGroupId = associatedGroupId
        self.highlightText = highlightText
        self._stableId = stableId
        self.isContact = isContact
        self.folders = folders
        self.canPreviewChat = canPreviewChat
        
        
        if let peer, let botInfo = peer.botInfo, botInfo.flags.contains(.hasWebApp), readState == nil || readState?.count == 0, splitState != .minimisize {
            self.openMiniApp = .init(.initialize(string: strings().chatListOpenMiniApp, color: theme.colors.underSelectedColor, font: .medium(.text)), alignment: .center)
            self.openMiniApp?.measure(width: .greatestFiniteMagnitude)
            
            self.openMiniAppSelected = .init(.initialize(string: strings().chatListOpenMiniApp, color: theme.colors.accentSelect, font: .medium(.text)), alignment: .center)
            self.openMiniAppSelected?.measure(width: .greatestFiniteMagnitude)
        } else {
            self.openMiniApp = nil
            self.openMiniAppSelected = nil
        }
        
        if let peer = peer, peer.isMonoForum {
            self.monoforumMessages = .init(.initialize(string: strings().chatListMonoforumHolder, color: theme.colors.grayText, font: .normal(.small)), alignment: .center)
            self.monoforumMessagesSelected = .init(.initialize(string: strings().chatListMonoforumHolder, color: theme.colors.accentSelect, font: .normal(.small)), alignment: .center)
            
            self.monoforumMessages?.measure(width: .greatestFiniteMagnitude)
            self.monoforumMessagesSelected?.measure(width: .greatestFiniteMagnitude)

        } else {
            self.monoforumMessages = nil
            self.monoforumMessagesSelected = nil
        }
        
        if let folders, folders.showTags, let peer, splitState != .minimisize, mode.threadData == nil {
            var tags: [ChatListTag] = []
            var filtered: [ChatListFilter] = []
            for tab in folders.tabs {
                if tab != filter {
                    if tab.contains(peer, groupId: groupId._asGroup(), isRemovedFromTotalUnreadCount: isMuted, isUnread: readState?.count != 0, isContact: isContact) {
                        filtered.append(tab)
                    }
                }
            }
            for tab in filtered {
                let color: NSColor?
                if let dataColor = tab.data?.color {
                    let index = Int(dataColor.rawValue)
                    color = theme.colors.peerColors(index % 7).bottom
                } else {
                    color = nil
                }
                if let color = color {
                    
                    let attr = NSMutableAttributedString()
                    attr.append(string: tab.title.uppercased(), color: color, font: .bold(10))
                    InlineStickerItem.apply(to: attr, associatedMedia: [:], entities: tab.entities, isPremium: context.isPremium, playPolicy: tab.enableAnimations ? nil : .framesCount(1))

                    
                    let attrSelected = NSMutableAttributedString()
                    attrSelected.append(string: tab.title.uppercased(), color: theme.colors.accentSelect, font: .bold(10))
                    InlineStickerItem.apply(to: attrSelected, associatedMedia: [:], entities: tab.entities, isPremium: context.isPremium)

                    
                    let text = TextViewLayout(attr)
                    text.measure(width: .greatestFiniteMagnitude)
                    
                    let textSelected = TextViewLayout(attrSelected)
                    textSelected.measure(width: .greatestFiniteMagnitude)

                    tags.append(.init(text: text, selected: textSelected, color: color.withAlphaComponent(0.1), selectedColor: theme.colors.underSelectedColor))
                }
            }
            if !tags.isEmpty {
                self.tags = .init(tags: tags, extender: nil)
            } else {
                self.tags = nil
            }
        } else {
            self.tags = nil
        }
        
        if let peer = peer {
            self.isVerified = peer.isVerified
            self.isPremium = peer.isPremium && peer.id != context.peerId
            self.isScam = peer.isScam
            self.isFake = peer.isFake
        } else {
            self.isVerified = false
            self.isScam = false
            self.isFake = false
            self.isPremium = false
        }
        
       
        self.isMuted = isMuted
        self.readState = readState
        
        if let story = story, peer?.id != context.peerId {
            self.avatarStoryIndicator = .init(stats: story, presentation: theme, isRoundedRect: peer?.isForum == true)
        } else {
            self.avatarStoryIndicator = nil
        }
        
        
        let titleText:NSMutableAttributedString = NSMutableAttributedString()
        let isTopic: Bool
        switch mode {
        case .chat, .savedMessages:
            let text: String?
            if case .savedMessages = mode, peer?.id == context.peerId {
                text = strings().peerMyNotes
            } else if peer?.id == context.peerId {
                text = strings().peerSavedMessages
            } else {
                if let peer = peer, peer.isMonoForum {
                    text = renderedPeer.chatOrMonoforumMainPeer?._asPeer().displayTitle
                } else {
                    text = peer?.displayTitle
                }
            }
            let _ = titleText.append(string: text, color: renderedPeer.peers[renderedPeer.peerId]?._asPeer() is TelegramSecretChat ? theme.chatList.secretChatTextColor : theme.chatList.textColor, font: .medium(.title))
            isTopic = false
        case let .topic(_, data):
            let _ = titleText.append(string: data.info.title, color: theme.chatList.textColor, font: .medium(.title))
            isTopic = true
        }
        titleText.setSelected(color: theme.colors.underSelectedColor ,range: titleText.range)
        
        self.displayLayout = TextViewLayout(titleText, maximumNumberOfLines: 1)
        
        let selected = titleText.mutableCopy() as! NSMutableAttributedString
        if !selected.string.isEmpty, let color = selected.attribute(.selectedColor, at: 0, effectiveRange: nil) {
            selected.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: selected.range)
            self.displaySelectedLayout = TextViewLayout(selected, maximumNumberOfLines: 1)
        } else {
            self.displaySelectedLayout = TextViewLayout(selected, maximumNumberOfLines: 1)
        }
                
        if !forumTopicItems.isEmpty, let message = messages.first, tags == nil {
            self.topicsLayout = .init(context, message: message, items: forumTopicItems, draft: draft)
        }
    
        
        if case let .ad(item) = pinnedType {
            let sponsored:NSMutableAttributedString = NSMutableAttributedString()
            let range: NSRange
            switch item.promoInfo.content {
            case let .psa(type, _):
                range = sponsored.append(string: localizedPsa("psa.chatlist", type: type), color: theme.colors.grayText, font: .normal(.short))
            case .proxy:
                range = sponsored.append(string: strings().chatListSponsoredChannel, color: theme.colors.grayText, font: .normal(.short))
            }
            sponsored.setSelected(color: theme.colors.underSelectedColor, range: range)
            self.date = sponsored
            
            self.dateLayout = TextViewLayout(sponsored, mayItems: false)
            self.dateLayout?.measure(width: .greatestFiniteMagnitude)
            
            let selectedDate = sponsored.mutableCopy() as! NSMutableAttributedString
            if let color = selectedDate.attribute(.selectedColor, at: 0, effectiveRange: nil) {
                selectedDate.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: selectedDate.range)
                self.dateSelectedLayout = TextViewLayout(selectedDate, mayItems: false)
                self.dateSelectedLayout?.measure(width: .greatestFiniteMagnitude)
            }
            
        } else if let message = messages.first {
            let date:NSMutableAttributedString = NSMutableAttributedString()
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= context.timeDifference
            let range = date.append(string: DateUtils.string(forMessageListDate: Int32(time)), color: theme.colors.grayText, font: .normal(.short))
            date.setSelected(color: theme.colors.underSelectedColor, range: range)
            self.date = date.copy() as? NSAttributedString
            
            self.dateLayout = TextViewLayout(date, mayItems: false)
            self.dateLayout?.measure(width: .greatestFiniteMagnitude)
            
            let selectedDate = date.mutableCopy() as! NSMutableAttributedString
            if let color = selectedDate.attribute(.selectedColor, at: 0, effectiveRange: nil) {
                selectedDate.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: selectedDate.range)
                self.dateSelectedLayout = TextViewLayout(selectedDate, mayItems: false)
                self.dateSelectedLayout?.measure(width: .greatestFiniteMagnitude)
            }
                      
            if forumTopicItems.isEmpty || tags != nil {
                var author: Peer?
                if message.isImported, let info = message.forwardInfo {
                    if let peer = info.author {
                        author = peer
                    } else if let signature = info.authorSignature {
                        author = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, firstName: signature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                    }
                } else {
                    author = message.author
                }
                if let author = author, let peer = peer, peer as? TelegramUser == nil, !peer.isChannel, draft == nil {
                    if !(message.extendedMedia is TelegramMediaAction) {
                        var peerText: String = (author.id == context.account.peerId ? "\(strings().chatListYou)" : author.displayTitle)
                        
                        let topicNameAttributed = NSMutableAttributedString()

                        if let forumTopicData = forumTopicData, peer.isForum {
                            _ = topicNameAttributed.append(string: forumTopicData.title, color: theme.chatList.peerTextColor, font: .normal(.text))
                        } else if peer.isForum, titleMode == .forumInfo, case let .topic(_, data) = mode {
                            peerText = author.compactDisplayTitle
                            _ = topicNameAttributed.append(string: data.info.title, color: theme.chatList.peerTextColor, font: .normal(.text))
                        }

                        if !topicNameAttributed.string.isEmpty {
                            self.forumTopicNameLayout = .init(topicNameAttributed, maximumNumberOfLines: 1)
                            
                            let selectedText:NSMutableAttributedString = topicNameAttributed.mutableCopy() as! NSMutableAttributedString
                            selectedText.addAttribute(.foregroundColor, value: theme.colors.underSelectedColor, range: selectedText.range)

                            self.forumTopicNameSelectedLayout = .init(selectedText, maximumNumberOfLines: 1)
                        }
                        
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: peerText, color: theme.chatList.peerTextColor, font: .normal(.text))
                        
                        if author.id != context.account.peerId, !isTopic {
                            attr.insert(.embeddedAvatar(.init(author)), at: 0)
                        }
                        attr.setSelected(color: theme.colors.underSelectedColor, range: attr.range)

                        if !attr.string.isEmpty {
                            self.chatNameLayout = .init(attr, maximumNumberOfLines: 1)
                            
                            let selectedText:NSMutableAttributedString = attr.mutableCopy() as! NSMutableAttributedString
                            if let color = selectedText.attribute(.selectedColor, at: 0, effectiveRange: nil) {
                                selectedText.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: selectedText.range)
                            }
                            self.chatNameSelectedLayout = .init(selectedText, maximumNumberOfLines: 1)
                        }
                    }
                }
                
                let isSecret: Bool
                isSecret = renderedPeer.peers[renderedPeer.peerId]?._asPeer() is TelegramSecretChat
                
                var contentImageSpecs = self.contentImageSpecs
                let contentImageSize = self.contentImageSize
                
                if draft == nil, !isSecret, forumTopicItems.isEmpty {
                    var index: Int32 = 0
                    let insert:(Message, Media, Bool)->Void = { message, media, increment in
                        var message = message
                        if increment {
                            message = message.withUpdatedId(.init(peerId: message.id.peerId, namespace: message.id.namespace, id: message.id.id + index))
                        }
                        if let image = media as? TelegramMediaImage {
                            if let _ = largestImageRepresentation(image.representations) {
                                let fitSize = contentImageSize
                                contentImageSpecs.append((message, image, fitSize))
                            }
                        } else if let file = media as? TelegramMediaFile {
                            if file.isVideo, !file.isInstantVideo, let _ = file.dimensions, !file.probablySticker {
                                let fitSize = contentImageSize
                                contentImageSpecs.append((message, file, fitSize))
                            }
                        }
                        index += 1
                    }
                    
                    for message in messages {
                        inner: for media in message.media {
                            if let media = media as? TelegramMediaPaidContent {
                                for extended in media.extendedMedia {
                                    switch extended {
                                    case let .preview(dimensions, immediateThumbnailData, _):
                                        if let immediateThumbnailData, let dimensions {
                                            insert(message, TelegramMediaImage(dimension: dimensions, immediateThumbnailData: immediateThumbnailData), true)
                                        }
                                    case let .full(media):
                                        insert(message, media, true)
                                    }
                                }
                            } else if !message.containsSecretMedia && !message.isMediaSpoilered {
                                insert(message, media, false)
                            }
                        }
                    }
                    self.contentImageSpecs = contentImageSpecs
                }
            }
        }
        
        contentImageSpecs = Array(contentImageSpecs.prefix(3))
        
        for i in 0 ..< contentImageSpecs.count {
            if i != 0 {
                textLeftCutout += contentImageSpacing
            }
            textLeftCutout += contentImageSpecs[i].size.width
            if i == contentImageSpecs.count - 1 {
                textLeftCutout += contentImageTrailingSpace
            }
        }
        if let _ = messages.first(where: { $0.storyAttribute != nil }) {
            textLeftCutout += 20
        }

        if hasUnreadMentions {
            self.mentionsCount = 1
        } else {
            self.mentionsCount = nil
        }
       
        if hasUnreadReactions {
            self.reactionsCount = 1
        } else {
            self.reactionsCount = nil
        }
        
        let isEmpty: Bool
        
        switch mode {
        case .topic:
            isEmpty = titleMode == .normal
        case .chat, .savedMessages:
            isEmpty = false
        }
        
        if let peer = peer, peer.id != context.peerId && peer.id != repliesPeerId, !peer.id.isAnonymousSavedMessages, !isEmpty {
            if peer.isMonoForum, let photoPeer = renderedPeer.chatOrMonoforumMainPeer?._asPeer() {
                self.photo = .PeerAvatar(peer, peer.displayLetters, photoPeer.smallProfileImage, photoPeer.nameColor, nil, nil, peer.groupAccess.canManageDirect, nil)
            } else {
                self.photo = .PeerAvatar(peer, peer.displayLetters, peer.smallProfileImage, peer.nameColor, nil, nil, peer.isForumOrMonoForum, nil)
            }
        } else {
            self.photo = .Empty
        }
        
        super.init(initialSize)
        
        if case .hidden(true) = hideStatus {
            hideItem(animated: false, reload: false)
        }
        
        if showBadge {
            
            let isMuted = isMuted || (readState?.isMuted ?? false)
            
            if let unreadCount = readState?.count, unreadCount > 0, mentionsCount == nil || (unreadCount > 1 || mentionsCount! != unreadCount)  {

                badgeNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
                badgeSelectedNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
                
                shortBadgeNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
                shortBadgeSelectedNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)

            } else if isUnreadMarked && mentionsCount == nil {
                badgeNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
                badgeSelectedNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
                
                shortBadgeNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
                shortBadgeSelectedNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)

            }
        }
       
        
      
        if let _ = self.isOnline, let presence = peerPresence?._asPresence() {
            presenceManager = PeerPresenceStatusManager(update: { [weak self] in
                self?.isOnline = false
                self?.redraw(animated: true)
            })
            presenceManager?.reset(presence: presence, timeDifference: Int32(context.timeDifference))
        }
        
        if forumTopicItems.isEmpty || tags != nil {
            var messageText: NSAttributedString?
            var textCutout: TextViewCutout?
            if case let .ad(promo) = pinnedType, message == nil {
                switch promo.promoInfo.content {
                case let .psa(_, message):
                    if let message = message {
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: message, color: theme.colors.grayText, font: .normal(.text))
                        attr.setSelected(color: theme.colors.underSelectedColor, range: attr.range)
                        messageText = attr
                    }
                default:
                    break
                }
            } else {
                messageText = chatListText(account: context.account, for: message, messagesCount: messages.count, renderedPeer: renderedPeer, draft: draft, folder: false, applyUserName: false, isPremium: context.isPremium)
                if !textLeftCutout.isZero {
                    textCutout = TextViewCutout(topLeft: CGSize(width: textLeftCutout, height: 14))
                }
            }
            if let messageText = messageText?.trimmed, !messageText.string.isEmpty {
                self.messageLayout = .init(messageText, maximumNumberOfLines: chatNameLayout != nil || tags != nil ? 1 : 2, cutout: textCutout)
                
                let selectedText:NSMutableAttributedString = messageText.mutableCopy() as! NSMutableAttributedString
                if let color = selectedText.attribute(.selectedColor, at: 0, effectiveRange: nil) {
                    selectedText.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: selectedText.range)
                }
                self.messageSelectedLayout = .init(selectedText, maximumNumberOfLines: chatNameLayout != nil || tags != nil ? 1 : 2, cutout: textCutout)
            }
        }
        
        _ = makeSize(initialSize.width, oldWidth: 0)
        
        
        if let peer = peer, peer.isPremium, peer.id != context.peerId, peer.hasVideo, !isLite(.animations) {
            self.photos = syncPeerPhotos(peerId: peer.id).map { $0.value }
            let signal = peerPhotos(context: context, peerId: peer.id, force: false) |> deliverOnMainQueue
            peerPhotosDisposable.set(signal.start(next: { [weak self] photos in
                let photos = photos.map { $0.value }
                if self?.photos != photos {
                    self?.photos = photos
                    DispatchQueue.main.async {
                        self?.noteHeightOfRow(animated: true)
                    }
                }
            }))
        }
    }
    
    let margin:CGFloat = 9
    
    
    var isPinned: Bool {
        switch pinnedType {
        case .some:
            return true
        case .last:
            return true
        default:
            return false
        }
    }
    var isClosedTopic: Bool {
        switch self.mode {
        case let .topic(_, threadData):
            return threadData.isClosed
        case .chat, .savedMessages:
            return false
        }
    }
    
    var badgeMuted: Bool {
        let isMuted = isMuted || (readState?.isMuted ?? false)

        return isMuted
    }
    
    var isLastPinned: Bool {
        switch pinnedType {
        case .last:
            return true
        default:
            return false
        }
    }
    
    
    var isFixedItem: Bool {
        switch pinnedType {
        case .some, .ad, .last:
            return true
        default:
            return false
        }
    }

    var canResortPinned: Bool {
        switch mode {
        case .topic:
            if let peer = self.peer as? TelegramChannel {
                return peer.hasPermission(.pinMessages)
            } else {
                return false
            }
        default:
            return true
        }
    }


    var isAd: Bool {
        switch pinnedType {
        case .ad:
            return true
        default:
            return false
        }
    }
    
    var badIcon: CGImage {
        return isScam ? theme.icons.scam : theme.icons.fake
    }
    var badHighlightIcon: CGImage {
        return isScam ? theme.icons.scamActive : theme.icons.fakeActive
    }
    var titleWidth:CGFloat {
        var dateSize:CGFloat = 0
        if let dateLayout = dateLayout {
            dateSize = dateLayout.layoutSize.width
        }
        
        let peer = self.renderedPeer?.chatOrMonoforumMainPeer?._asPeer() ?? self.peer
        
        var offset: CGFloat = 0
        if let peer = peer, peer.id != context.peerId, let controlSize = PremiumStatusControl.controlSize(peer, false, left: false) {
            offset += controlSize.width + 4
        }
        if let peer = peer, peer.id != context.peerId, let controlSize = PremiumStatusControl.controlSize(peer, false, left: true) {
            offset += controlSize.width + 4
        }
        if isMuted {
            offset += theme.icons.dialogMuteImage.backingSize.width + 4
        }
        if isSecret {
            offset += 10
        }
        
        if let ctxMonoforumMessages {
            offset += ctxMonoforumMessages.layoutSize.width + 10
        }
        
        offset += (leftInset - 20)
        
        if appearMode == .short {
            offset += 20
        }

        if isClosedTopic {
            offset += 10
        }
        offset += 5
        return max(200, size.width) - margin * 3 - dateSize - (isOutMessage ? isRead ? 20 : 12 : 0) - offset
    }
    
    var chatNameWidth:CGFloat {
        var w:CGFloat = 0
        if let badgeNode = badgeNode {
            w += badgeNode.size.width + 5
        }
        if let _ = mentionsCount {
            w += 24
        }
        if let _ = reactionsCount {
            w += 24
        }
        w += (leftInset - 20)
        
        if let topicsLayout = forumTopicNameLayout, let _ = tags {
            w += topicsLayout.layoutSize.width + 5
            w += 40
        }
        if let _ = tags, !contentImageSpecs.isEmpty {
            w += CGFloat(contentImageSpecs.count) * 16
            w += 40
        }

        return max(200, size.width) - margin * 3 - w - (isOutMessage ? isRead ? 20 : 12 : 0)
    }
    
    var messageWidth:CGFloat {
        var w: CGFloat = 0
        if let badgeNode = badgeNode {
            w += badgeNode.size.width + 5
        }
        if let _ = mentionsCount {
            w += 24
        }
        if let _ = reactionsCount {
            w += 24
        }
        if isPinned && badgeNode == nil {
            w += 20
        }
        
        if let openMiniApp {
            w += openMiniApp.layoutSize.width + 20
        }
        
        w += (leftInset - 20)
        
        if let chatNameLayout = chatNameLayout, let _ = tags {
            w += chatNameLayout.layoutSize.width + 5
        }
        if let topicsLayout = forumTopicNameLayout, let _ = tags {
            w += topicsLayout.layoutSize.width + 5
        }
        if let _ = tags, !contentImageSpecs.isEmpty {
            w += CGFloat(contentImageSpecs.count) * 16
        }
        
        return (max(200, size.width) - margin * 3) - w - (chatNameLayout != nil ? textLeftCutout : 0)
    }
    
    var inputActivityWidth: CGFloat {
        var w: CGFloat = 0
        if let badgeNode = badgeNode {
            w += badgeNode.size.width + 5
        }
        if let _ = mentionsCount {
            w += 24
        }
        if let _ = reactionsCount {
            w += 24
        }
        if isPinned && badgeNode == nil {
            w += 20
        }
        w += (leftInset - 20)
        
        return (max(200, size.width) - margin * 3) - w - (chatNameLayout != nil ? textLeftCutout : 0)
    }
    
    var leftInset:CGFloat {
        switch mode {
        case .chat, .savedMessages:
            return 50 + (10 * 2.0)
        case .topic:
            if titleMode == .forumInfo {
                return 50 + (10 * 2.0)
            } else {
                if appearMode == .short {
                    return 35
                } else {
                    return 30 + (10 * 2.0)
                }
            }
        }
    }
    
    var shouldHideContent: Bool {
        return hideContent || context.layout == .minimisize
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        

        displayLayout?.measure(width: titleWidth)
        displaySelectedLayout?.measure(width: titleWidth)

        
        if let forumTopicNameLayout = forumTopicNameLayout, let chatNameLayout = self.chatNameLayout {
            var width = chatNameWidth / 2 - 20
            chatNameLayout.measure(width: width)
            chatNameSelectedLayout?.measure(width: width)
            
            width = chatNameWidth - chatNameLayout.layoutSize.width - 20
            forumTopicNameLayout.measure(width: width)
            forumTopicNameSelectedLayout?.measure(width: width)
        } else {
            chatNameLayout?.measure(width: chatNameWidth)
            chatNameSelectedLayout?.measure(width: chatNameWidth)
        }
        

        messageLayout?.measure(width: messageWidth)
        messageSelectedLayout?.measure(width: messageWidth)
        

        self.topicsLayout?.measure(messageWidth)
   
        
        if let tags = self.tags {
            var maxX: CGFloat = 0
            let prevExtender = tags.extender
            tags.extender = nil
            for i in 0 ..< tags.tags.count {
                maxX += tags.tags[i].size.width + 3
                if maxX + 20 > chatNameWidth - 20 {
                    if prevExtender?.index != i  {
                        let color = theme.colors.grayIcon
                        let text = TextViewLayout(.initialize(string: "+\(tags.tags.count - i)", color: color, font: .bold(10)))
                        let selectedText = TextViewLayout(.initialize(string: "+\(tags.tags.count - i)", color: theme.colors.accentSelect, font: .bold(10)))
                        
                        text.measure(width: .greatestFiniteMagnitude)
                        selectedText.measure(width: .greatestFiniteMagnitude)
                        let tag = ChatListTag(text: text, selected: selectedText, color: color.withAlphaComponent(0.1), selectedColor: theme.colors.underSelectedColor)
                        tags.extender = .init(tag: tag, index: i)
                    } else {
                        tags.extender = prevExtender
                    }
                    
                    break
                }
            }
        }
        
        return result
    }
    
    func openWebApp() {
        if let peer = peer {
            BrowserStateContext.get(context).open(tab: .mainapp(bot: .init(peer), source: .generic))
        }
    }
    
    
    func openPeerStory() {
        if let peerId = peerId {
            let table = self.table
            self.openStory(.init(peerId: peerId, id: nil, messageId: nil, takeControl: { [weak table] peerId, _, storyId in
                var view: NSView?
                table?.enumerateItems(with: { item in
                    if let item = item as? ChatListRowItem, item.peerId == peerId {
                        view = item.takeStoryControl()
                    }
                    return view == nil
                })
                return view
            }, setProgress: { [weak self] signal in
                self?.setStoryProgress(signal)
            }), true, false)
        } else if let storyState = self.storyState, !storyState.items.isEmpty {
            let table = self.table
            self.openStory(.init(peerId: storyState.items[0].peer.id, id: nil, messageId: nil, takeControl: { [weak table] peerId, _, storyId in
                var view: NSView?
                table?.enumerateItems(with: { item in
                    if let item = item as? ChatListRowItem, item.peerId == nil {
                        view = item.takeStoryControl()
                    }
                    return view == nil
                })
                return view
            }, setProgress: { [weak self] signal in
                self?.setStoryProgress(signal)
            }), false, true)
        }
    }
    private func takeStoryControl() -> NSView? {
        (self.view as? ChatListRowView)?.takeStoryControl()
    }
    private func setStoryProgress(_ signal:Signal<Never, NoError>)  {
        (self.view as? ChatListRowView)?.setStoryProgress(signal)
    }
    
    var markAsUnread: Bool {
        return !isSecret && !isUnreadMarked && badgeNode == nil && mentionsCount == nil && !self.mode.savedMessages
    }
    
    func collapseOrExpandArchive() {
        ChatListRowItem.collapseOrExpandArchive(context: context)
    }
    
    static func collapseOrExpandArchive(context: AccountContext) {
        context.bindings.mainController().chatList.collapseOrExpandArchive()
    }
    
    static func toggleHideArchive(context: AccountContext) {
        context.bindings.mainController().chatList.toggleHideArchive()
    }
    
    func toggleHideArchive() {
        ChatListRowItem.toggleHideArchive(context: context)
    }

    func toggleUnread() {
        if let peerId = peerId {
            switch mode {
            case .chat:
                _ = context.engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: nil).start()
            case .topic:
                break
            case .savedMessages:
                break
            }
        }
    }
    
    func toggleMuted() {
        let peerId = renderedPeer?.chatMainPeer?.id ?? peerId
        if let peerId = peerId {
            ChatListRowItem.toggleMuted(context: context, peerId: peerId, isMuted: isMuted, threadId: self.mode.threadId)
        }
    }
    func delete() {
        if let peerId = peerId {
            let signal = removeChatInteractively(context: context, peerId: peerId, threadId: self.mode.threadId, userId: peer?.id)
            _ = signal.start()
        }
    }
    
    static func toggleMuted(context: AccountContext, peerId: PeerId, isMuted: Bool, threadId: Int64?) {
        if isMuted {
            _ = context.engine.peers.togglePeerMuted(peerId: peerId, threadId: threadId).start()
        } else {
            var options:[ModalOptionSet] = []
            
            options.append(ModalOptionSet(title: strings().chatListMute1Hour, selected: false, editable: true))
            options.append(ModalOptionSet(title: strings().chatListMute4Hours, selected: false, editable: true))
            options.append(ModalOptionSet(title: strings().chatListMute8Hours, selected: false, editable: true))
            options.append(ModalOptionSet(title: strings().chatListMute1Day, selected: false, editable: true))
            options.append(ModalOptionSet(title: strings().chatListMute3Days, selected: false, editable: true))
            options.append(ModalOptionSet(title: strings().chatListMuteForever, selected: true, editable: true))
            
            let intervals:[Int32] = [60 * 60, 60 * 60 * 4, 60 * 60 * 8, 60 * 60 * 24, 60 * 60 * 24 * 3, Int32.max]
            
            showModal(with: ModalOptionSetController(context: context, options: options, selectOne: true, actionText: (strings().chatInputMute, theme.colors.accent), title: strings().peerInfoNotifications, result: { result in
                
                for (i, option) in result.enumerated() {
                    inner: switch option {
                    case .selected:
                        _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: intervals[i]).start()
                        break
                    default:
                        break inner
                    }
                }
                
            }), for: context.window)
        }
    }
    
    func togglePinned() {
        if let peerId = peerId {
            ChatListRowItem.togglePinned(context: context, peerId: peerId, isPinned: self.isPinned, mode: self.mode, filter: filter, associatedGroupId: associatedGroupId)
        }
    }
    
    static func togglePinned(context: AccountContext, peerId: PeerId, isPinned: Bool, mode: ChatListRowItem.Mode, filter: ChatListFilter, associatedGroupId: EngineChatList.Group) {
        
        
        switch mode {
        case let .topic(threadId, _):
            let signal = context.engine.peers.toggleForumChannelTopicPinned(id: peerId, threadId: threadId) |> deliverOnMainQueue
            _ = signal.start(error: { error in
                switch error {
                case let .limitReached(count):
                    alert(for: context.window, info: strings().chatListContextPinErrorTopicsCountable(count))
                default:
                    alert(for: context.window, info: strings().unknownError)
                }
            })
        case .savedMessages:
            let signal = context.engine.peers.toggleForumChannelTopicPinned(id: context.peerId, threadId: peerId.toInt64()) |> deliverOnMainQueue
            _ = signal.start(error: { error in
                switch error {
                case let .limitReached(count):
                    alert(for: context.window, info: strings().chatListContextPinErrorTopicsCountable(count))
                default:
                    alert(for: context.window, info: strings().unknownError)
                }
            })
        case .chat:
            let location: TogglePeerChatPinnedLocation
            let itemId: PinnedItemId = .peer(peerId)
            if case .filter = filter {
                location = .filter(filter.id)
            } else {
                location = .group(associatedGroupId._asGroup())
            }
            let context = context
            
            _ = (context.engine.peers.toggleItemPinned(location: location, itemId: itemId) |> deliverOnMainQueue).start(next: { result in
                switch result {
                case .limitExceeded:
                    if context.isPremium {
                        verifyAlert_button(for: context.window, information: strings().chatListContextPinErrorNew2, ok: strings().alertOK, cancel: "", option: strings().chatListContextPinErrorNewSetupFolders, successHandler: { result in
                            switch result {
                            case .thrid:
                                context.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
                            default:
                                break
                            }
                        })

                    } else {
                        if case .filter = filter {
                            showPremiumLimit(context: context, type: .pinInFolders(.group(filter.id)))
                        } else {
                            if case .archive = associatedGroupId {
                                showPremiumLimit(context: context, type: .pinInArchive)
                            } else {
                                showPremiumLimit(context: context, type: .pin)
                            }
                        }
                    }
                default:
                    break
                }
            })
        }
    }
    
    func toggleArchive(unarchive: Bool = false) {
        ChatListRowItem.toggleArchive(context: context, associatedGroupId: unarchive ? .archive : associatedGroupId, peerId: peerId)
    }
    
    static func toggleArchive(context: AccountContext, associatedGroupId: EngineChatList.Group?, peerId: PeerId?) {
        if let peerId = peerId {
            switch associatedGroupId {
            case .root:
                context.bindings.mainController().chatList.setAnimateGroupNextTransition(EngineChatList.Group.archive)
                _ = context.engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: .archive).start()
            default:
                _ = context.engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: .root).start()
            }
            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 2.0).start()
        }
    }
    
    static func toggleTopic(context: AccountContext, peerId: PeerId, threadId: Int64, isClosed: Bool) {
        _ = context.engine.peers.setForumChannelTopicClosed(id: peerId, threadId: threadId, isClosed: !isClosed).start()
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {

        
        guard !context.isFrozen else {
            return .complete()
        }
        
        let message = self.message
        let context = self.context
        let peerId = self.peerId
        let effectivePeerId = self.renderedPeer?.chatMainPeer?.id ?? self.peerId
        let peer = self.peer
        let filter = self.filter
        let isMuted = self.isMuted
        let associatedGroupId = self.associatedGroupId
        let isAd = self.isAd
        let renderedPeer = self.renderedPeer
        let canArchive = self.canArchive
        let groupId = self.groupId
        let markAsUnread = self.markAsUnread
        let isPinned = self.isPinned
        let hideStatus = hideStatus
        let isSecret = self.isSecret
        let isUnread = badgeNode != nil || mentionsCount != nil || isUnreadMarked
        let threadId = self.mode.threadId
        let mode = self.mode
        let isClosedTopic = self.isClosedTopic
        let isForum = self.isForum
        let entryId = self.entryId
       
        let deleteChat:()->Void = {
            if let peerId = peerId {
                let signal = removeChatInteractively(context: context, peerId: peerId, threadId: threadId, userId: peer?.id)
                _ = signal.start()
            }
        }
        
        let togglePin:()->Void = {
            if let peerId = peerId {
                ChatListRowItem.togglePinned(context: context, peerId: peerId, isPinned: isPinned, mode: mode, filter: filter, associatedGroupId: associatedGroupId)
            }
        }
        
        let previewChat:()->Void = {
            if let peerId = peerId {
                ChatListRowItem.previewChat(peerId: peerId, context: context)
            }
        }
        
        let toggleArchive:(Bool)->Void = { unarchive in
            if let peerId = peerId {
                ChatListRowItem.toggleArchive(context: context, associatedGroupId: unarchive ? .archive : associatedGroupId, peerId: peerId)
            }
        }
        
        let toggleMute:()->Void = {
            if let peerId = effectivePeerId {
                ChatListRowItem.toggleMuted(context: context, peerId: peerId, isMuted: isMuted, threadId: threadId)
            }
        }
        let toggleTopic:()->Void = {
            if let peerId = peerId, let threadId = threadId {
                ChatListRowItem.toggleTopic(context: context, peerId: peerId, threadId: threadId, isClosed: isClosedTopic)
            }
        }
        
        if case let .topic(_, data) = self.mode, let peer = peer as? TelegramChannel, let threadId = threadId {
            
            var items:[ContextMenuItem] = []
            
            if isUnread {
                items.append(ContextMenuItem(strings().chatListContextMaskAsRead, handler: {
                    _ = context.engine.messages.markForumThreadAsRead(peerId: peer.id, threadId: threadId).start()
                }, itemImage: MenuAnimation.menu_read.value))
            }
            
            if peer.hasPermission(.pinMessages) {
                items.append(ContextMenuItem(!isPinned ? strings().chatListContextPin : strings().chatListContextUnpin, handler: togglePin, itemImage: !isPinned ? MenuAnimation.menu_pin.value : MenuAnimation.menu_unpin.value))
            }

            
            items.append(ContextMenuItem(isMuted ? strings().chatListContextUnmute : strings().chatListContextMute, handler: toggleMute, itemImage: isMuted ? MenuAnimation.menu_unmuted.value : MenuAnimation.menu_mute.value))
                        
            if threadId == 1, peer.hasPermission(.manageTopics), let peerId = peerId {
                items.append(ContextMenuItem(data.isHidden ? strings().chatListContextUnhideGeneral : strings().chatListContextHideGeneral, handler: {
                    
                    _ = context.engine.peers.setForumChannelTopicHidden(id: peerId, threadId: threadId, isHidden: !data.isHidden).start()
                    
                }, itemImage: !data.isHidden ? MenuAnimation.menu_hide.value : MenuAnimation.menu_show.value))

            }
            
            if data.isOwnedByMe || peer.isAdmin {
                items.append(ContextMenuItem(!isClosedTopic ? strings().chatListContextPause : strings().chatListContextStart, handler: toggleTopic, itemImage: !isClosedTopic ? MenuAnimation.menu_pause.value : MenuAnimation.menu_play.value))
                
                items.append(ContextSeparatorItem())
                items.append(ContextMenuItem(strings().chatListContextDelete, handler: deleteChat, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
            }
            
           
 
            
            return .single(items)
        }
        
        let cachedData:Signal<CachedPeerData?, NoError>
        if let peerId = peerId {
            cachedData = getCachedDataView(peerId: peerId, postbox: context.account.postbox)
        } else {
            cachedData = .single(nil)
        }
        
        let soundsDataSignal = combineLatest(queue: .mainQueue(), appNotificationSettings(accountManager: context.sharedContext.accountManager), context.engine.peers.notificationSoundList(), context.account.postbox.transaction { transaction -> TelegramPeerNotificationSettings? in
            if let peerId = peerId {
                return transaction.getPeerNotificationSettings(id: peerId) as? TelegramPeerNotificationSettings
            } else {
                return nil
            }
        })
        
        

        return combineLatest(queue: .mainQueue(), chatListFilterPreferences(engine: context.engine), cachedData, soundsDataSignal, context.engine.messages.chatList(group: .archive, count: 1000) |> take(1), context.engine.data.get(TelegramEngine.EngineData.Item.Peer.DisplaySavedChatsAsTopics())) |> take(1) |> map { filters, cachedData, soundsData, archived, displaySavedChatsAsTopics -> [ContextMenuItem] in
            
            var items:[ContextMenuItem] = []
            
            let canDeleteForAll: Bool?
            if let cachedData = cachedData as? CachedChannelData {
                canDeleteForAll = cachedData.flags.contains(.canDeleteHistory)
            } else {
                canDeleteForAll = nil
            }
            
            var zeroGroup: [ContextMenuItem] = []
            var firstGroup:[ContextMenuItem] = []
            var secondGroup:[ContextMenuItem] = []
            var thirdGroup:[ContextMenuItem] = []

            if let mainPeer = peer, let peerId = peerId, let peer = renderedPeer?.peers[peerId] {
                
                
                if peerId == context.peerId, case .chat = mode {
                    zeroGroup.append(ContextMenuItem(strings().chatSavedMessagesViewAsMessages, handler: {
                        context.engine.peers.updateSavedMessagesViewAsTopics(value: false)
                    }, itemImage: !displaySavedChatsAsTopics ? MenuAnimation.menu_check_selected.value : nil))
                    
                    zeroGroup.append(ContextMenuItem(strings().chatSavedMessagesViewAsChats, handler: {
                        context.engine.peers.updateSavedMessagesViewAsTopics(value: true)
                    }, itemImage: displaySavedChatsAsTopics ? MenuAnimation.menu_check_selected.value : nil))
                }
                                    
                if !isAd && groupId == .root {
                    firstGroup.append(ContextMenuItem(!isPinned ? strings().chatListContextPin : strings().chatListContextUnpin, handler: togglePin, itemImage: !isPinned ? MenuAnimation.menu_pin.value : MenuAnimation.menu_unpin.value))
                }
                
                
                
                
                if groupId == .root, (canArchive || associatedGroupId != .root) {
                    
                    let isArchived = archived.items.contains(where: { $0.renderedPeer.peerId == peerId })

                    
                    secondGroup.append(ContextMenuItem(associatedGroupId == .root && !isArchived ? strings().chatListSwipingArchive : strings().chatListSwipingUnarchive, handler: {
                        toggleArchive(isArchived)
                    }, itemImage: associatedGroupId == .root && !isArchived ? MenuAnimation.menu_archive.value : MenuAnimation.menu_unarchive.value))
                }
                
                if context.peerId != peer.id, !isAd, !mode.savedMessages {
                    let muteItem = ContextMenuItem(isMuted ? strings().chatListContextUnmute : strings().chatListContextMute, handler: toggleMute, itemImage: isMuted ? MenuAnimation.menu_unmuted.value : MenuAnimation.menu_mute.value)
                    
                    let sound: ContextMenuItem = ContextMenuItem(strings().chatListContextSound, handler: {
                        
                    }, itemImage: MenuAnimation.menu_music.value)
                    
                    let soundList = ContextMenu()
                    
                    
                    let selectedSound: PeerMessageSound
                    if let peerNotificationSettings = soundsData.2 {
                        selectedSound = peerNotificationSettings.messageSound
                    } else {
                        selectedSound = .default
                    }
                    
                    let playSound:(PeerMessageSound) -> Void = { tone in
                        let effectiveTone: PeerMessageSound
                        if tone == .default {
                            effectiveTone = soundsData.0.tone
                        } else {
                            effectiveTone = tone
                        }
                        
                        if effectiveTone != .default && effectiveTone != .none {
                            let path = fileNameForNotificationSound(postbox: context.account.postbox, sound: effectiveTone, defaultSound: nil, list: soundsData.1?.sounds)
                            
                            _ = path.start(next: { resource in
                                if let resource = resource {
                                    let path = resourcePath(context.account.postbox, resource)
                                    SoundEffectPlay.play(postbox: context.account.postbox, path: path)
                                }
                            })
                        }
                    }
                    
                    let updateSound:(PeerMessageSound)->Void = { tone in
                        playSound(tone)
                        _ = context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: threadId, sound: tone).start()

                    }
                    
                    soundList.addItem(ContextMenuItem(localizedPeerNotificationSoundString(sound: .default, default: nil, list: nil), handler: {
                        updateSound(.default)
                    }, hover: {
                        playSound(.default)
                    }, state: selectedSound == .default ? .on : nil))
                    
                    soundList.addItem(ContextMenuItem(localizedPeerNotificationSoundString(sound: .none, default: nil, list: nil), handler: {
                        updateSound(.none)
                    }, hover: {
                        playSound(.none)
                    }, state: selectedSound == .none ? .on : nil))
                    soundList.addItem(ContextSeparatorItem())
                    
                    
                    
                    if let sounds = soundsData.1 {
                        for sound in sounds.sounds {
                            let tone: PeerMessageSound = .cloud(fileId: sound.file.fileId.id)
                            soundList.addItem(ContextMenuItem(localizedPeerNotificationSoundString(sound: .cloud(fileId: sound.file.fileId.id), default: nil, list: sounds.sounds), handler: {
                                updateSound(tone)
                            }, hover: {
                                playSound(tone)
                            }, state: selectedSound == .cloud(fileId: sound.file.fileId.id) ? .on : nil))
                        }
                        if !sounds.sounds.isEmpty {
                            soundList.addItem(ContextSeparatorItem())
                        }
                    }
                    
                 
                    for i in 0 ..< 12 {
                        let sound: PeerMessageSound = .bundledModern(id: Int32(i))
                        soundList.addItem(ContextMenuItem(localizedPeerNotificationSoundString(sound: sound, default: nil, list: soundsData.1?.sounds), handler: {
                            updateSound(sound)
                        }, hover: {
                            playSound(sound)
                        }, state: selectedSound == sound ? .on : nil))
                    }
                    soundList.addItem(ContextSeparatorItem())
                    for i in 0 ..< 8 {
                        let sound: PeerMessageSound = .bundledClassic(id: Int32(i))
                        soundList.addItem(ContextMenuItem(localizedPeerNotificationSoundString(sound: sound, default: nil, list: soundsData.1?.sounds), handler: {
                            updateSound(sound)
                        }, hover: {
                            playSound(sound)
                        }, state: selectedSound == sound ? .on : nil))
                    }
                    
                    
                    sound.submenu = soundList
                    
                    
                    if !isMuted, let peerId = effectivePeerId {
                        let submenu = ContextMenu()
                        submenu.addItem(ContextMenuItem(strings().chatListMute1Hour, handler: {
                            _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: 60 * 60 * 1).start()
                        }, itemImage: MenuAnimation.menu_mute_for_1_hour.value))
                        
                        submenu.addItem(ContextMenuItem(strings().chatListMute8Hours, handler: {
                            _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: 60 * 60 * 8).start()
                        }, itemImage: MenuAnimation.menu_mute_for_1_hour.value))
                        
                        submenu.addItem(ContextMenuItem(strings().chatListMute3Days, handler: {
                            _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: 60 * 60 * 24 * 3).start()
                        }, itemImage: MenuAnimation.menu_mute_for_2_days.value))
                        
                        submenu.addItem(ContextSeparatorItem())
                        
                        submenu.addItem(ContextMenuItem(strings().chatListMuteUntil, handler: {
                            showModal(with: DateSelectorModalController(context: context, mode: .date(title: strings().chatListMuteUntilTitle, doneTitle: strings().chatListMuteUntilOK), selectedAt: { date in
                                _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: Int32(date.timeIntervalSince1970 - Date().timeIntervalSince1970)).start()
                            }), for: context.window)
                        }, itemImage: MenuAnimation.menu_schedule_message.value))
                        
                        submenu.addItem(ContextMenuItem(strings().chatListMuteForever, handler: {
                            _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: Int32.max).start()
                        }, itemImage: MenuAnimation.menu_mute.value))

                        
                        submenu.addItem(ContextSeparatorItem())
                        submenu.addItem(sound)
                        
                        muteItem.submenu = submenu
                    } else {
                         let submenu = ContextMenu()
                         submenu.addItem(sound)
                         muteItem.submenu = submenu
                     }
                     
                     
                    
                    firstGroup.append(muteItem)
                }
                
                if mainPeer is TelegramUser, !mode.savedMessages {
                    thirdGroup.append(ContextMenuItem(strings().chatListContextClearHistory, handler: {
                        clearHistory(context: context, peer: peer._asPeer(), mainPeer: mainPeer, canDeleteForAll: canDeleteForAll)
                    }, itemImage: MenuAnimation.menu_clear_history.value))
                    thirdGroup.append(ContextMenuItem(strings().chatListContextDeleteChat, handler: deleteChat, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                }
                
                if !isSecret {
                    if markAsUnread {
                        firstGroup.append(ContextMenuItem(strings().chatListContextMaskAsUnread, handler: {
                            _ = context.engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: true).start()
                        }, itemImage: MenuAnimation.menu_unread.value))
                        
                    } else if isUnread {
                        firstGroup.append(ContextMenuItem(strings().chatListContextMaskAsRead, handler: {
                            _ = context.engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: false).start()
                            _ = clearPeerUnseenPersonalMessagesInteractively(account: context.account, peerId: peerId, threadId: nil).start()
                        }, itemImage: MenuAnimation.menu_read.value))
                    }
                }
                
                if isAd {
                    firstGroup.append(ContextMenuItem(strings().chatListContextHidePromo, handler: {
                        context.bindings.mainController().chatList.hidePromoItem(peerId)
                    }, itemImage: MenuAnimation.menu_archive.value))
                }
                if let peer = peer._asPeer() as? TelegramGroup, !isAd, !mode.savedMessages {
                    thirdGroup.append(ContextMenuItem(strings().chatListContextClearHistory, handler: {
                        clearHistory(context: context, peer: peer, mainPeer: mainPeer, canDeleteForAll: canDeleteForAll)
                    }, itemImage: MenuAnimation.menu_delete.value))
                    thirdGroup.append(ContextMenuItem(strings().chatListContextDeleteAndExit, handler: deleteChat, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                } else if let peer = peer._asPeer() as? TelegramChannel, !isAd, !peer.flags.contains(.hasGeo), !mode.savedMessages {
                    
                    if case .broadcast = peer.info {
                        thirdGroup.append(ContextMenuItem(strings().chatListContextLeaveChannel, handler: deleteChat, itemMode: .destruct, itemImage: MenuAnimation.menu_leave.value))
                    } else if !isAd {
                        if peer.addressName == nil {
                            thirdGroup.append(ContextMenuItem(strings().chatListContextClearHistory, handler: {
                                clearHistory(context: context, peer: peer, mainPeer: mainPeer, canDeleteForAll: canDeleteForAll)
                            }, itemImage: MenuAnimation.menu_clear_history.value))
                        } 
                        thirdGroup.append(ContextMenuItem(strings().chatListContextLeaveGroup, handler: deleteChat, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    }
                }
                
            } else {
                if !isAd, groupId == .root {
                    firstGroup.append(ContextMenuItem(!isPinned ? strings().chatListContextPin : strings().chatListContextUnpin, handler: togglePin, itemImage: isPinned ? MenuAnimation.menu_unpin.value : MenuAnimation.menu_pin.value))
                }
            }
            
            if mode.savedMessages {
                thirdGroup.append(ContextSeparatorItem())
                thirdGroup.append(ContextMenuItem(strings().chatListContextDelete, handler: deleteChat, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
            }
            
            if groupId != .root, context.layout != .minimisize, let hideStatus = hideStatus, !mode.savedMessages {
                switch hideStatus {
                case .collapsed:
                    firstGroup.append(ContextMenuItem(strings().chatListRevealActionExpand, handler: {
                        ChatListRowItem.collapseOrExpandArchive(context: context)
                    }, itemImage: MenuAnimation.menu_expand.value))
                default:
                    firstGroup.append(ContextMenuItem(strings().chatListRevealActionCollapse, handler: {
                        ChatListRowItem.collapseOrExpandArchive(context: context)
                    }, itemImage: MenuAnimation.menu_collapse.value))
                }
            }
            
            if peerId != nil {
                firstGroup.append(ContextMenuItem(strings().chatListContextPreview, handler: {
                    previewChat()
                }, itemImage: MenuAnimation.menu_eye.value))
            }
            
            var submenu: [ContextMenuItem] = []
            if let peerId = peerId, peerId.namespace != Namespaces.Peer.SecretChat, !mode.savedMessages {
                for item in filters.list {
                    inner: switch item {
                    case .allChats:
                        break inner;
                    case let .filter(_, _, _, data):
                        
                        let attr = NSMutableAttributedString()
                        attr.append(string: item.title, color: theme.colors.text, font: .normal(.text))
                        InlineStickerItem.apply(to: attr, associatedMedia: [:], entities: item.entities, isPremium: true, playPolicy: item.enableAnimations ? nil : .framesCount(1))

                        
                        let menuItem = ContextMenuItem(item.title, handler: {
                            
                            let limit = context.isPremium ? context.premiumLimits.dialog_filters_chats_limit_premium : context.premiumLimits.dialog_filters_chats_limit_default
                            
                            let isEnabled = data.includePeers.peers.contains(peerId) || data.includePeers.peers.count < limit
                            if isEnabled {
                                _ = context.engine.peers.updateChatListFiltersInteractively({ list in
                                    var list = list
                                    for (i, folder) in list.enumerated() {
                                        if folder.id == item.id, var folderData = folder.data {
                                            if data.includePeers.peers.contains(peerId) {
                                                var peers = folderData.includePeers.peers
                                                peers.removeAll(where: { $0 == peerId })
                                                folderData.includePeers.setPeers(peers)
                                            } else {
                                                folderData.includePeers.setPeers(folderData.includePeers.peers + [peerId])
                                            }
                                            list[i] = list[i].withUpdatedData(folderData)
                                        }
                                    }
                                    return list
                                }).start()
                            } else {
                                if context.isPremium {
                                    alert(for: context.window, info: strings().chatListFilterIncludeLimitReached)
                                } else {
                                    showPremiumLimit(context: context, type: .chatInFolders)
                                }
                            }
                           
                        }, state: data.includePeers.peers.contains(peerId) ? .on : nil, itemImage: FolderIcon(item).emoticon.drawable.value, attributedTitle: attr, customTextView: {
                            let layout = TextViewLayout(attr)
                            layout.measure(width: .greatestFiniteMagnitude)

                            let textView = InteractiveTextView()
                            textView.userInteractionEnabled = false
                            textView.textView.isSelectable = false
                            textView.set(text: layout, context: context)
                            return textView
                        })
                        submenu.append(menuItem)
                        menuItem.isEnabled = !data.includePeers.peers.contains(peerId) || data.includePeers.peers.count > 1
                    }
                }
            }
            
            if !submenu.isEmpty {
                let item = ContextMenuItem(strings().chatListFilterAddToFolder, itemImage: MenuAnimation.menu_add_to_folder.value)
                let menu = ContextMenu()
                for item in submenu {
                    menu.addItem(item)
                }
                item.submenu = menu
                secondGroup.append(item)
            }
            
            let blocks:[[ContextMenuItem]] = [zeroGroup, firstGroup,
                                              secondGroup,
                                              thirdGroup].filter { !$0.isEmpty }
            
            for (i, block) in blocks.enumerated() {
                if i == 0 {
                    items.append(contentsOf: block)
                } else {
                    items.append(ContextSeparatorItem())
                    items.append(contentsOf: block)
                }
            }
            return items
        }
    }
    
    var ctxDisplayLayout:TextViewLayout? {
        if isActiveSelected {
            return displaySelectedLayout
        }
        return displayLayout
    }
    
    var ctxOpenMiniApp: TextViewLayout? {
        if isActiveSelected {
            return openMiniAppSelected
        }
        return openMiniApp
    }
    
    var ctxMonoforumMessages: TextViewLayout? {
        if isActiveSelected {
            return monoforumMessagesSelected
        }
        return monoforumMessages
    }
    
    var isActiveSelected: Bool {
        return isSelected && context.layout != .single && !(isForum && !isTopic)
    }
    
    var isReplyToStory: Bool {
        if self.messages.first(where: { $0.storyAttribute != nil }) != nil {
            if isForum && !isTopic {
                return false
            }
            return true
        }
        return false
    }
    
    var ctxChatNameLayout:TextViewLayout? {
        if isActiveSelected {
            return chatNameSelectedLayout
        }
        return chatNameLayout
    }
    
    var ctxForumTopicNameLayout:TextViewLayout? {
        if isActiveSelected {
            return forumTopicNameSelectedLayout
        }
        return forumTopicNameLayout
    }
    
    
    var ctxMessageText:TextViewLayout? {
        if self.activities.isEmpty {
            if isActiveSelected {
                return messageSelectedLayout
            }
            return messageLayout
        }
        return nil
    }
    
    var ctxDateLayout:TextViewLayout? {
        if hasDraft {
            return nil
        }
        if isActiveSelected {
            return dateSelectedLayout
        }
        return dateLayout
    }
    
    var ctxBadgeNode:BadgeNode? {
        if isActiveSelected {
            return badgeSelectedNode
        }
        return badgeNode
    }
    
    var ctxShortBadgeNode:BadgeNode? {
        if isActiveSelected {
            return shortBadgeSelectedNode
        }
        return shortBadgeNode
    }
    
//    var ctxBadge: Badge? {
//        if isSelected && context.layout != .single {
//            return badgeSelected
//        }
//        return badge
//    }
    
    
    override var instantlyResize: Bool {
        return true
    }

    deinit {
    }
    
    override func viewClass() -> AnyClass {
        return ChatListRowView.self
    }
  
    override var height: CGFloat {
        if let hideStatus = hideStatus {
            switch hideStatus {
            case .collapsed:
                return width == 70 ? 70 : 30
            default:
                break
            }
        }
        if shouldHideContent {
            return 70
        }
        
        switch mode {
        case .chat, .savedMessages:
            return 70
        case .topic:
            return 53 + (displayLayout?.layoutSize.height ?? 17)
        }
    }
    
    func previewChat() {
        guard let peerId = peerId else {
            return
        }
        if let peer = self.peer, !peer.hasSensitiveContent(platform: "ios") {
            ChatListRowItem.previewChat(peerId: peerId, context: context)
        }
    }
    
    static func previewChat(peerId: PeerId, context: AccountContext) {
        let controller = ChatController(context: context, chatLocation: .peer(peerId), mode: .preview)
        let navigation:NavigationViewController = NavigationViewController(controller, context.window)
        navigation._frameRect = NSMakeRect(0, 0, 400, 500)
        
        showModal(with: navigation, for: context.window)
    }
    
}
