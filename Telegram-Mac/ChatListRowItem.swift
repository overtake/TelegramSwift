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
import SyncCore
import SwiftSignalKit


enum ChatListPinnedType {
    case some
    case last
    case none
    case ad(AdditionalChatListItem)
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

    public private(set) var messages:[Message]
    
    var message: Message? {
        var effective: Message?
        
        let filtered = messages.filter { !$0.text.isEmpty }
        if filtered.count == 1 {
            effective = filtered[0]
        }

        if effective == nil {
            effective = messages.first
        }
        return effective
    }
    
    let context: AccountContext
    let peer:Peer?
    let renderedPeer:RenderedPeer?
    let groupId: PeerGroupId
    //let groupUnreadCounters: GroupReferenceUnreadCounters?
    let chatListIndex:ChatListIndex?
    var peerId:PeerId? {
        return renderedPeer?.peerId
    }
    
    let photo: AvatarNodeState
    
    var isGroup: Bool {
        return groupId != .root
    }
    
    private let requestSessionId:MetaDisposable = MetaDisposable()
    
    override var stableId: AnyHashable {
        return entryId
    }
    
    var entryId: UIChatListEntryId {
        if groupId != .root {
            return .groupId(groupId)
        } else if let index = chatListIndex {
            return .chatId(index.messageIndex.id.peerId, nil)
        } else {
            preconditionFailure()
        }
    }
    
    var chatLocation: ChatLocation? {
        if let index = chatListIndex {
            return ChatLocation.peer(index.messageIndex.id.peerId)
        }
        return nil
    }

    let mentionsCount: Int32?
    
    private var date:NSAttributedString?

    private var displayLayout:(TextNodeLayout, TextNode)?
    private var chatNameLayout:(TextNodeLayout, TextNode)?

    private var messageLayout:(TextNodeLayout, TextNode)?
    private var displaySelectedLayout:(TextNodeLayout, TextNode)?
    private var messageSelectedLayout:(TextNodeLayout, TextNode)?
    private var dateLayout:(TextNodeLayout, TextNode)?
    private var dateSelectedLayout:(TextNodeLayout, TextNode)?
    private var chatNameSelectedLayout:(TextNodeLayout, TextNode)?

    private var displayNode:TextNode = TextNode()
    private var messageNode:TextNode = TextNode()
    private var displaySelectedNode:TextNode = TextNode()
    private var messageSelectedNode:TextNode = TextNode()
    private var chatNameSelectedNode:TextNode = TextNode()
    private var chatNameNode:TextNode = TextNode()

    private var messageText:NSAttributedString?
    private let titleText:NSAttributedString?
    private var chatTitleAttributed: NSAttributedString?
    
    private(set) var peerNotificationSettings:PeerNotificationSettings?
    private(set) var readState:CombinedPeerReadState?
    
    private var badgeNode:BadgeNode? = nil
    private var badgeSelectedNode:BadgeNode? = nil
    
    private var additionalBadgeNode:BadgeNode? = nil
    private var additionalBadgeSelectedNode:BadgeNode? = nil

    
    private var typingLayout:(TextNodeLayout, TextNode)?
    private var typingSelectedLayout:(TextNodeLayout, TextNode)?
    
    private let clearHistoryDisposable = MetaDisposable()
    private let deleteChatDisposable = MetaDisposable()

    private let _animateArchive:Atomic<Bool> = Atomic(value: false)
    
    var animateArchive:Bool {
        return _animateArchive.swap(false)
    }
    
    let filter: ChatListFilter?
    
    var isCollapsed: Bool {
        if let archiveStatus = archiveStatus {
            switch archiveStatus {
            case .collapsed:
                return context.sharedContext.layout != .minimisize
            default:
                return false
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
        if context.peerId == peerId {
            return false
        }
        if case .ad = pinnedType {
            return false
        }
        let supportId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000)
        if self.peer?.id == supportId {
            return false
        }
        
        return true
    }
    
    let associatedGroupId: PeerGroupId
    
    let isMuted:Bool
    
    var hasUnread: Bool {
        return ctxBadgeNode != nil
    }
    
    let isVerified: Bool
    let isScam: Bool

    
    var isOutMessage:Bool {
        if let message = message {
            if message.text.isEmpty, let _ = message.media.first as? TelegramMediaAction {
                return false
            }
            return !message.flags.contains(.Incoming) && message.id.peerId != context.peerId
        }
        return false
    }
    var isRead:Bool {
        if let peer = peer as? TelegramUser {
            if let _ = peer.botInfo {
                return true
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
        
        if let readState = readState {
            if let message = message {
                return readState.isOutgoingMessageIndexRead(MessageIndex(message))
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
            return renderedPeer.peers[renderedPeer.peerId] is TelegramSecretChat
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
    
    
    
    let hasDraft:Bool
    private let hasFailed: Bool
    let pinnedType:ChatListPinnedType
    let activities: [ChatListInputActivity]
    
    var toolTip: String? {
        return messageText?.string
    }
    
    private(set) var isOnline: Bool?
    private var presenceManager:PeerPresenceStatusManager?
    
    let archiveStatus: HiddenArchiveStatus?
    
    private var groupLatestPeers:[ChatListGroupReferencePeer] = []
    
    private var textLeftCutout: CGFloat = 0.0
    let contentImageSize = CGSize(width: 16, height: 16)
    let contentImageSpacing: CGFloat = 2.0
    let contentImageTrailingSpace: CGFloat = 5.0
    private(set) var contentImageSpecs: [(message: Message, media: Media, size: CGSize)] = []


    
    init(_ initialSize:NSSize, context: AccountContext, pinnedType: ChatListPinnedType, groupId: PeerGroupId, peers: [ChatListGroupReferencePeer], messages: [Message], unreadState: PeerGroupUnreadCountersCombinedSummary, unreadCountDisplayCategory: TotalUnreadCountDisplayCategory, activities: [ChatListInputActivity] = [], animateGroup: Bool = false, archiveStatus: HiddenArchiveStatus = .normal, hasFailed: Bool = false, filter: ChatListFilter? = nil) {
        self.groupId = groupId
        self.peer = nil
        self.messages = messages
        self.chatListIndex = nil
        self.activities = activities
        self.context = context
        self.mentionsCount = nil
        self.pinnedType = pinnedType
        self.renderedPeer = nil
        self.associatedGroupId = .root
        self.isMuted = false
        self.isOnline = nil
        self.archiveStatus = archiveStatus
        self.groupLatestPeers = peers
        self.isVerified = false
        self.isScam = false
        self.filter = filter
        self.hasFailed = hasFailed
        let titleText:NSMutableAttributedString = NSMutableAttributedString()
        let _ = titleText.append(string: L10n.chatListArchivedChats, color: theme.chatList.textColor, font: .medium(.title))
        titleText.setSelected(color: theme.colors.underSelectedColor ,range: titleText.range)
        
        
        var message: Message?
        
        let filtered = messages.filter { !$0.text.isEmpty }
        if filtered.count == 1 {
            message = filtered[0]
        }
        if message == nil {
            message = messages.first
        }
        
        self.titleText = titleText
        if peers.count == 1 {
            self.messageText = chatListText(account: context.account, for: message, folder: true)
        } else {
            let textString = NSMutableAttributedString(string: "")
            var isFirst = true
            for peer in peers {
                if let chatMainPeer = peer.peer.chatMainPeer {
                    let peerTitle = chatMainPeer.compactDisplayTitle
                    if !peerTitle.isEmpty {
                        if isFirst {
                            isFirst = false
                        } else {
                            textString.append(.initialize(string: ", ", color: theme.chatList.textColor, font: .normal(.text)))
                        }
                        textString.append(.initialize(string: peerTitle, color: peer.isUnread ? theme.chatList.textColor : theme.chatList.grayTextColor, font: .normal(.text)))
                    }
                }
            }
            self.messageText = textString
        }
        hasDraft = false
        
    

        
        if let message = message {
            let date:NSMutableAttributedString = NSMutableAttributedString()
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= context.timeDifference
            let range = date.append(string: DateUtils.string(forMessageListDate: Int32(time)), color: theme.colors.grayText, font: .normal(.short))
            date.setSelected(color: theme.colors.underSelectedColor,range: range)
            self.date = date.copy() as? NSAttributedString
            
            dateLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, false, .left)
            dateSelectedLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, true, .left)
        }
        
        
        let mutedCount = unreadState.count(countingCategory: unreadCountDisplayCategory == .chats ? .chats : .messages, mutedCategory: .all)
        
        self.highlightText = nil
        self.embeddedState = nil
        
        photo = .ArchivedChats
        
        super.init(initialSize)
        
        if case .hidden(true) = archiveStatus {
            hideItem(animated: false, reload: false)
        }
        
        
        _ = _animateArchive.swap(animateGroup)
        
        if mutedCount > 0  {
            badgeNode = BadgeNode(.initialize(string: "\(mutedCount)", color: theme.chatList.badgeTextColor, font: .medium(.small)), theme.chatList.badgeMutedBackgroundColor)
            badgeSelectedNode = BadgeNode(.initialize(string: "\(mutedCount)", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
        }
        
        
        //theme.chatList.badgeBackgroundColor
        
        

        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    private let highlightText: String?
    private let embeddedState:PeerChatListEmbeddedInterfaceState?
    
    init(_ initialSize:NSSize,  context: AccountContext,  messages: [Message], index: ChatListIndex? = nil,  readState:CombinedPeerReadState? = nil,  isMuted:Bool = false, embeddedState:PeerChatListEmbeddedInterfaceState? = nil, pinnedType:ChatListPinnedType = .none, renderedPeer:RenderedPeer, peerPresence: PeerPresence? = nil, summaryInfo: ChatListMessageTagSummaryInfo = ChatListMessageTagSummaryInfo(), activities: [ChatListInputActivity] = [], highlightText: String? = nil, associatedGroupId: PeerGroupId = .root, hasFailed: Bool = false, showBadge: Bool = true, filter: ChatListFilter? = nil) {
        
        
        var embeddedState = embeddedState
        
        if let peer = renderedPeer.chatMainPeer as? TelegramChannel {
            if !peer.hasPermission(.sendMessages) {
                embeddedState = nil
            }
        }
        let supportId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000)

        if let peerPresence = peerPresence as? TelegramUserPresence, context.peerId != renderedPeer.peerId, renderedPeer.peerId != supportId {
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
        
      
        var message: Message?
        
        let filtered = messages.filter { !$0.text.isEmpty }
        if filtered.count == 1 {
            message = filtered[0]
        }
        if message == nil {
            message = messages.first
        }
        
        self.chatListIndex = index
        self.renderedPeer = renderedPeer
        self.context = context
        self.messages = messages
        self.activities = activities
        self.pinnedType = pinnedType
        self.archiveStatus = nil
        self.hasDraft = embeddedState != nil
        self.embeddedState = embeddedState
        self.peer = renderedPeer.chatMainPeer
        self.groupId = .root
        self.hasFailed = hasFailed
        self.filter = filter
        self.associatedGroupId = associatedGroupId
        self.highlightText = highlightText
        if let peer = peer {
            self.isVerified = peer.isVerified
            self.isScam = peer.isScam
        } else {
            self.isVerified = false
            self.isScam = false
        }
        
       
        self.isMuted = isMuted
        self.readState = readState
        
        
        let titleText:NSMutableAttributedString = NSMutableAttributedString()
        let _ = titleText.append(string: peer?.id == context.peerId ? L10n.peerSavedMessages : peer?.displayTitle, color: renderedPeer.peers[renderedPeer.peerId] is TelegramSecretChat ? theme.chatList.secretChatTextColor : theme.chatList.textColor, font: .medium(.title))
        titleText.setSelected(color: theme.colors.underSelectedColor ,range: titleText.range)

        self.titleText = titleText
    
        
        if case let .ad(item) = pinnedType, let promo = item as? PromoChatListItem {
            let sponsored:NSMutableAttributedString = NSMutableAttributedString()
            let range: NSRange
            switch promo.kind {
            case let .psa(type, _):
                range = sponsored.append(string: localizedPsa("psa.chatlist", type: type), color: theme.colors.grayText, font: .normal(.short))
            case .proxy:
                range = sponsored.append(string: L10n.chatListSponsoredChannel, color: theme.colors.grayText, font: .normal(.short))
            }
            sponsored.setSelected(color: theme.colors.underSelectedColor, range: range)
            self.date = sponsored
            dateLayout = TextNode.layoutText(maybeNode: nil,  sponsored, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, false, .left)
            dateSelectedLayout = TextNode.layoutText(maybeNode: nil,  sponsored, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, true, .left)
        } else if let message = message {
            let date:NSMutableAttributedString = NSMutableAttributedString()
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= context.timeDifference
            let range = date.append(string: DateUtils.string(forMessageListDate: Int32(time)), color: theme.colors.grayText, font: .normal(.short))
            date.setSelected(color: theme.colors.underSelectedColor, range: range)
            self.date = date.copy() as? NSAttributedString
            
            dateLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, false, .left)
            dateSelectedLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, true, .left)
            
            
            if let author = message.author as? TelegramUser, let peer = peer, peer as? TelegramUser == nil, !peer.isChannel, embeddedState == nil {
                let peerText: String = (author.id == context.account.peerId ? "\(L10n.chatListYou)" : author.displayTitle)
                
                let attr = NSMutableAttributedString()
                _ = attr.append(string: peerText, color: theme.chatList.peerTextColor, font: .normal(.text))
                attr.setSelected(color: theme.colors.underSelectedColor, range: attr.range)
                
                self.chatTitleAttributed = attr
            }
            
            let contentImageFillSize = CGSize(width: 8.0, height: contentImageSize.height)
            _ = contentImageFillSize
            if embeddedState == nil, false {
                for message in messages {
                    inner: for media in message.media {
                        if !message.containsSecretMedia {
                            if let image = media as? TelegramMediaImage {
                                if let _ = largestImageRepresentation(image.representations) {
                                    //let imageSize = largest.dimensions.cgSize
                                    //let fitSize = imageSize.aspectFilled(contentImageFillSize)
                                    let fitSize = contentImageSize
                                    contentImageSpecs.append((message, image, fitSize))
                                }
                                break inner
                            } else if let file = media as? TelegramMediaFile {
                                if file.isVideo, !file.isInstantVideo, let _ = file.dimensions {
                                    //let imageSize = dimensions.cgSize
                                    //let fitSize = imageSize.aspectFilled(contentImageFillSize)
                                    let fitSize = contentImageSize
                                    contentImageSpecs.append((message, file, fitSize))
                                }
                                break inner
                            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                let imageTypes = ["photo", "video", "embed", "gif", "document", "telegram_album"]
                                if let image = content.image, let type = content.type, imageTypes.contains(type) {
                                    if let _ = largestImageRepresentation(image.representations) {
                                        //let imageSize = largest.dimensions.cgSize
                                        let fitSize = contentImageSize
                                        contentImageSpecs.append((message, image, fitSize))
                                    }
                                    break inner
                                } else if let file = content.file {
                                    if file.isVideo, !file.isInstantVideo, let _ = file.dimensions {
                                        //let imageSize = dimensions.cgSize
                                        let fitSize = contentImageSize
                                        contentImageSpecs.append((message, file, fitSize))
                                    }
                                    break inner
                                }
                            }
                        }
                    }
                }
            }
            }
            
        
        for i in 0 ..< contentImageSpecs.count {
            if i != 0 {
                textLeftCutout += contentImageSpacing
            }
            textLeftCutout += contentImageSpecs[i].size.width
            if i == contentImageSpecs.count - 1 {
                textLeftCutout += contentImageTrailingSpace
            }
        }

        
        
        let tagSummaryCount = summaryInfo.tagSummaryCount ?? 0
        let actionsSummaryCount = summaryInfo.actionsSummaryCount ?? 0
        let totalMentionCount = tagSummaryCount - actionsSummaryCount
        if totalMentionCount > 0 {
            self.mentionsCount = totalMentionCount
        } else {
            self.mentionsCount = nil
        }
        
        if let peer = peer, peer.id != context.peerId {
            self.photo = .PeerAvatar(peer, peer.displayLetters, peer.smallProfileImage, nil)
        } else {
            self.photo = .Empty
        }
        
        super.init(initialSize)
        
        if showBadge {
            if let unreadCount = readState?.count, unreadCount > 0, mentionsCount == nil || (unreadCount > 1 || mentionsCount! != unreadCount)  {
                badgeNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
                badgeSelectedNode = BadgeNode(.initialize(string: "\(unreadCount)", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
            } else if isUnreadMarked && mentionsCount == nil {
                badgeNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeTextColor, font: .medium(.small)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
                badgeSelectedNode = BadgeNode(.initialize(string: " ", color: theme.chatList.badgeSelectedTextColor, font: .medium(.small)), theme.chatList.badgeSelectedBackgroundColor)
            }
        }
       
        
      
        if let _ = self.isOnline, let presence = peerPresence as? TelegramUserPresence {
            presenceManager = PeerPresenceStatusManager(update: { [weak self] in
                self?.isOnline = false
                self?.redraw(animated: true)
            })
            
            presenceManager?.reset(presence: presence, timeDifference: Int32(context.timeDifference))
        }
        
        _ = makeSize(initialSize.width, oldWidth: 0)
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
    
//    var contentDimensions: NSSize? {
//        var dimensions: CGSize?
//        if let contentImageMedia = contentImageMedia as? TelegramMediaImage {
//            dimensions = largestRepresentationForPhoto(contentImageMedia)?.dimensions.size
//        } else if let contentImageMedia = contentImageMedia as? TelegramMediaFile {
//            dimensions = contentImageMedia.dimensions?.size
//        }
//        return dimensions
//    }
    
    var isAd: Bool {
        switch pinnedType {
        case .ad:
            return true
        default:
            return false
        }
    }
    
    var titleWidth:CGFloat {
        var dateSize:CGFloat = 0
        if let dateLayout = dateLayout {
            dateSize = dateLayout.0.size.width
        }
        
        return max(300, size.width) - 50 - margin * 4 - dateSize - (isMuted ? theme.icons.dialogMuteImage.backingSize.width + 4 : 0) - (isOutMessage ? isRead ? 14 : 8 : 0) - (isVerified ? 20 : 0) - (isSecret ? 10 : 0) - (isScam ? theme.icons.scam.backingSize.width : 0)
    }
    var messageWidth:CGFloat {
        if let badgeNode = badgeNode {
            return (max(300, size.width) - 50 - margin * 3) - (badgeNode.size.width + 5) - (mentionsCount != nil ? 30 : 0) - (additionalBadgeNode != nil ? additionalBadgeNode!.size.width + 15 : 0) - (chatTitleAttributed != nil ? textLeftCutout : 0)
        }
        
        return (max(300, size.width) - 50 - margin * 4) - (isPinned ? 20 : 0) - (mentionsCount != nil ? 24 : 0) - (additionalBadgeNode != nil ? additionalBadgeNode!.size.width + 15 : 0) - (chatTitleAttributed != nil ? textLeftCutout : 0)
    }
    
    let leftInset:CGFloat = 50 + (10 * 2.0);
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        
        if self.groupId == .root {
            var text: NSAttributedString?
            if case let .ad(promo) = pinnedType, message == nil {
                if let promo = promo as? PromoChatListItem {
                    switch promo.kind {
                    case let .psa(_, message):
                        if let message = message {
                            let attr = NSMutableAttributedString()
                            _ = attr.append(string: message, color: theme.colors.grayText, font: .normal(.text))
                            attr.setSelected(color: theme.colors.underSelectedColor, range: attr.range)
                            text = attr
                        }
                    default:
                        break
                    }
                }
            }
            if text == nil {
                var messageText = chatListText(account: context.account, for: message, renderedPeer: renderedPeer, embeddedState: embeddedState)
                if let query = highlightText, let copy = messageText.mutableCopy() as? NSMutableAttributedString, let range = rangeOfSearch(query, in: copy.string) {
                    if copy.range.contains(range.min) && copy.range.contains(range.max - 1), copy.range != range {
                        copy.addAttribute(.foregroundColor, value: theme.colors.text, range: range)
                        copy.addAttribute(.font, value: NSFont.medium(.text), range: range)
                        messageText = copy
                    }
                }
                text = messageText
            }
            self.messageText = text!
        }
        
       
        
        if displayLayout == nil || !displayLayout!.0.isPerfectSized || self.oldWidth > width {
            displayLayout = TextNode.layoutText(maybeNode: displayNode,  titleText, nil, 1, .end, NSMakeSize(titleWidth, size.height), nil, false, .left)
        }
        
        if displaySelectedLayout == nil || !displaySelectedLayout!.0.isPerfectSized || self.oldWidth > width {
            displaySelectedLayout = TextNode.layoutText(maybeNode: displaySelectedNode,  titleText, nil, 1, .end, NSMakeSize(titleWidth, size.height), nil, true, .left)
        }
        
        if chatNameLayout == nil || !chatNameLayout!.0.isPerfectSized || self.oldWidth > width, let chatTitleAttributed = chatTitleAttributed {
            chatNameLayout = TextNode.layoutText(maybeNode: chatNameNode, chatTitleAttributed, nil, 1, .end, NSMakeSize(titleWidth, size.height), nil, false, .left)
        }
        
        if chatNameSelectedLayout == nil || !chatNameSelectedLayout!.0.isPerfectSized || self.oldWidth > width, let chatTitleAttributed = chatTitleAttributed {
            chatNameSelectedLayout = TextNode.layoutText(maybeNode: chatNameSelectedNode, chatTitleAttributed, nil, 1, .end, NSMakeSize(titleWidth, size.height), nil, true, .left)
        }
        
        var textCutout: TextNodeCutout?
        if !textLeftCutout.isZero {
            textCutout = TextNodeCutout(position: .TopLeft, size: CGSize(width: textLeftCutout, height: 14))
        }

        
        if messageLayout == nil || !messageLayout!.0.isPerfectSized || self.oldWidth > width {
            messageLayout = TextNode.layoutText(maybeNode: messageNode,  messageText, nil, chatTitleAttributed != nil ? 1 : 2, .end, NSMakeSize(messageWidth, size.height), textCutout, false, .left, 1)
        }
        if messageSelectedLayout == nil || !messageSelectedLayout!.0.isPerfectSized || self.oldWidth > width {
            messageSelectedLayout = TextNode.layoutText(maybeNode: messageSelectedNode,  messageText, nil, chatTitleAttributed != nil ? 1 : 2, .end, NSMakeSize(messageWidth, size.height), textCutout, true, .left, 1)
        }
        return result
    }
    
    
    var markAsUnread: Bool {
        return !isSecret && !isUnreadMarked && badgeNode == nil && mentionsCount == nil
    }
    
    func collapseOrExpandArchive() {
        context.sharedContext.bindings.mainController().chatList.collapseOrExpandArchive()
    }
    func hidePromoItem(_ peerId: PeerId) {
        context.sharedContext.bindings.mainController().chatList.hidePromoItem(peerId)
    }
    
    func toggleHideArchive() {
        context.sharedContext.bindings.mainController().chatList.toggleHideArchive()
    }

    func toggleUnread() {
        if let peerId = peerId {
            _ = togglePeerUnreadMarkInteractively(postbox: context.account.postbox, viewTracker: context.account.viewTracker, peerId: peerId).start()
        }
    }
    func toggleMuted() {
        let context = self.context
        if let peerId = peerId {
            if isMuted {
                _ = togglePeerMuted(account: context.account, peerId: peerId).start()
            } else {
                var options:[ModalOptionSet] = []
                
                options.append(ModalOptionSet(title: L10n.chatListMute1Hour, selected: false, editable: true))
                options.append(ModalOptionSet(title: L10n.chatListMute4Hours, selected: false, editable: true))
                options.append(ModalOptionSet(title: L10n.chatListMute8Hours, selected: false, editable: true))
                options.append(ModalOptionSet(title: L10n.chatListMute1Day, selected: false, editable: true))
                options.append(ModalOptionSet(title: L10n.chatListMute3Days, selected: false, editable: true))
                options.append(ModalOptionSet(title: L10n.chatListMuteForever, selected: true, editable: true))
                
                var intervals:[Int32] = [60 * 60, 60 * 60 * 4, 60 * 60 * 8, 60 * 60 * 24, 60 * 60 * 24 * 3, Int32.max]
                
                showModal(with: ModalOptionSetController(context: context, options: options, selectOne: true, actionText: (L10n.chatInputMute, theme.colors.accent), title: L10n.peerInfoNotifications, result: { result in
                    
                    for (i, option) in result.enumerated() {
                        inner: switch option {
                        case .selected:
                            _ = updatePeerMuteSetting(account: context.account, peerId: peerId, muteInterval: intervals[i]).start()
                            break
                        default:
                            break inner
                        }
                    }
                    
                }), for: context.window)
            }
            
            
        }
    }
    
    func togglePinned() {
        if let chatLocation = chatLocation {
            let location: TogglePeerChatPinnedLocation
            
            if let filter = self.filter {
                location = .filter(filter.id)
            } else {
                location = .group(self.associatedGroupId)
            }
            let context = self.context
            
            _ = (toggleItemPinned(postbox: context.account.postbox, location: location, itemId: chatLocation.pinnedItemId) |> deliverOnMainQueue).start(next: { result in
                switch result {
                case .limitExceeded:
                    confirm(for: context.window, information: L10n.chatListContextPinErrorNew2, okTitle: L10n.alertOK, cancelTitle: "", thridTitle: L10n.chatListContextPinErrorNewSetupFolders, successHandler: { result in
                        
                        switch result {
                        case .thrid:
                            context.sharedContext.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
                        default:
                            break
                        }
                        
                    })
                    //alert(for: mainWindow, info: L10n.chatListContextPinErrorNew2)
                default:
                    break
                }
            })
        }
        
    }
    
    func toggleArchive() {
        if let peerId = peerId {
            switch associatedGroupId {
            case .root:
                let postbox = context.account.postbox
                context.sharedContext.bindings.mainController().chatList.setAnimateGroupNextTransition(Namespaces.PeerGroup.archive)
                 context.sharedContext.bindings.mainController().chatList.addUndoAction(ChatUndoAction(peerId: peerId, type: .archiveChat, action: { status in
                    switch status {
                    case .cancelled:
                        break
                        //_ = updatePeerGroupIdInteractively(postbox: postbox, peerId: peerId, groupId: .root).start()
                    case .success:
                        _ = updatePeerGroupIdInteractively(postbox: postbox, peerId: peerId, groupId: Namespaces.PeerGroup.archive).start()
                    default:
                        break
                    }
                 }))
            default:
                 _ = updatePeerGroupIdInteractively(postbox: context.account.postbox, peerId: peerId, groupId: .root).start()
            }
        }
    }
    
    func delete() {
        if let peerId = peerId {
            let signal = removeChatInteractively(context: context, peerId: peerId, userId: peer?.id)
            _ = signal.start()
        }
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items:[ContextMenuItem] = []

        let context = self.context
        let peerId = self.peerId
        
        if let peer = peer {
            
            let deleteChat:()->Void = { [weak self] in
                self?.delete()
            }
            
            
            guard let peerId = self.peerId else {
                return .single([])
            }
            
            let clearHistory = { [weak self] in
                if let strongSelf = self, let peer = strongSelf.peer {
                    
                    var thridTitle: String? = nil
                    
                    var canRemoveGlobally: Bool = false
                    if peerId.namespace == Namespaces.Peer.CloudUser && peerId != context.account.peerId && !peer.isBot {
                        if context.limitConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
                            canRemoveGlobally = true
                        }
                    }
                    
                    if canRemoveGlobally {
                        thridTitle = L10n.chatMessageDeleteForMeAndPerson(peer.displayTitle)
                    }
                    
                    modernConfirm(for: mainWindow, account: strongSelf.context.account, peerId: strongSelf.peer?.id, information: strongSelf.peer is TelegramUser ? strongSelf.peerId == context.peerId ? L10n.peerInfoConfirmClearHistorySavedMesssages : canRemoveGlobally ? L10n.peerInfoConfirmClearHistoryUserBothSides : L10n.peerInfoConfirmClearHistoryUser : L10n.peerInfoConfirmClearHistoryGroup, okTitle: L10n.peerInfoConfirmClear, thridTitle: thridTitle, thridAutoOn: false, successHandler: { result in
                        
                        context.sharedContext.bindings.mainController().chatList.addUndoAction(ChatUndoAction(peerId: peerId, type: .clearHistory, action: { status in
                            switch status {
                            case .success:
                                context.chatUndoManager.clearHistoryInteractively(postbox: context.account.postbox, peerId: peerId, type: result == .thrid ? .forEveryone : .forLocalPeer)
                                break
                            default:
                                break
                            }
                        }))
                   })
                }
            }
            
            let call = { [weak self] in
                if let peerId = self?.peer?.id, let context = self?.context {
                    self?.requestSessionId.set((phoneCall(account: context.account, sharedContext: context.sharedContext, peerId: peerId) |> deliverOnMainQueue).start(next: { result in
                        applyUIPCallResult(context.sharedContext, result)
                    }))
                }
            }
            
            let togglePin:()->Void = { [weak self] in
               self?.togglePinned()
            }
            
            let toggleArchive:()->Void = { [weak self] in
                self?.toggleArchive()
            }
            
            let toggleMute:()->Void = { [weak self] in
                self?.toggleMuted()
            }
            
            let leaveGroup = {
                modernConfirm(for: mainWindow, account: context.account, peerId: peerId, information: L10n.confirmLeaveGroup, okTitle: L10n.peerInfoConfirmLeave, successHandler: { _ in
                    _ = leftGroup(account: context.account, peerId: peerId).start()
                })
            }
            
            let rGroup = {
                _ = returnGroup(account: context.account, peerId: peerId).start()
            }
            
            if !isAd && groupId == .root {
                items.append(ContextMenuItem(!isPinned ? tr(L10n.chatListContextPin) : tr(L10n.chatListContextUnpin), handler: togglePin))
            }
            
            if groupId == .root, (canArchive || associatedGroupId != .root), filter == nil {
                items.append(ContextMenuItem(associatedGroupId == .root ? L10n.chatListSwipingArchive : L10n.chatListSwipingUnarchive, handler: toggleArchive))
            }
            
            if context.peerId != peer.id, !isAd {
                items.append(ContextMenuItem(isMuted ? tr(L10n.chatListContextUnmute) : tr(L10n.chatListContextMute), handler: toggleMute))
            }
            
            if peer is TelegramUser {
                if peer.canCall && peer.id != context.peerId {
                    items.append(ContextMenuItem(tr(L10n.chatListContextCall), handler: call))
                }
                items.append(ContextMenuItem(L10n.chatListContextClearHistory, handler: clearHistory))
                items.append(ContextMenuItem(L10n.chatListContextDeleteChat, handler: deleteChat))
            }
            
            if !isSecret {
                if markAsUnread {
                    items.append(ContextMenuItem(tr(L10n.chatListContextMaskAsUnread), handler: { [weak self] in
                        guard let `self` = self else {return}
                        _ = togglePeerUnreadMarkInteractively(postbox: self.context.account.postbox, viewTracker: self.context.account.viewTracker, peerId: peerId).start()
                        
                    }))
                    
                } else if badgeNode != nil || mentionsCount != nil || isUnreadMarked {
                    items.append(ContextMenuItem(tr(L10n.chatListContextMaskAsRead), handler: { [weak self] in
                        guard let `self` = self else {return}
                        _ = togglePeerUnreadMarkInteractively(postbox: self.context.account.postbox, viewTracker: self.context.account.viewTracker, peerId: peerId).start()
                    }))
                }
            }
            
            if isAd {
                items.append(ContextMenuItem(tr(L10n.chatListContextHidePromo), handler: { [weak self] in
                    guard let `self` = self, let peerId = self.peerId else {return}
                    self.hidePromoItem(peerId)
                }))
            }
           

            if let peer = peer as? TelegramGroup, !isAd {
                items.append(ContextMenuItem(tr(L10n.chatListContextClearHistory), handler: clearHistory))
                switch peer.membership {
                case .Member:
                    items.append(ContextMenuItem(L10n.chatListContextLeaveGroup, handler: leaveGroup))
                case .Left:
                    items.append(ContextMenuItem(L10n.chatListContextReturnGroup, handler: rGroup))
                default:
                    break
                }
                items.append(ContextMenuItem(L10n.chatListContextDeleteAndExit, handler: deleteChat))
            } else if let peer = peer as? TelegramChannel, !isAd, !peer.flags.contains(.hasGeo) {
                
                if case .broadcast = peer.info {
                     items.append(ContextMenuItem(L10n.chatListContextLeaveChannel, handler: deleteChat))
                } else if !isAd {
                    if peer.addressName == nil {
                        items.append(ContextMenuItem(L10n.chatListContextClearHistory, handler: clearHistory))
                    }
                    items.append(ContextMenuItem(L10n.chatListContextLeaveGroup, handler: deleteChat))
                }
            }
            
        } else {
            if !isAd, groupId == .root {
                items.append(ContextMenuItem(!isPinned ? tr(L10n.chatListContextPin) : tr(L10n.chatListContextUnpin), handler: { [weak self] in
                    self?.togglePinned()
                }))
            }
        }
        
        if groupId != .root, context.sharedContext.layout != .minimisize, let archiveStatus = archiveStatus {
            switch archiveStatus {
            case .collapsed:
                items.append(ContextMenuItem(L10n.chatListRevealActionExpand , handler: { [weak self] in
                    self?.collapseOrExpandArchive()
                }))
            default:
                items.append(ContextMenuItem(L10n.chatListRevealActionCollapse, handler: { [weak self] in
                    self?.collapseOrExpandArchive()
                }))
            }
            
        }
        
        let filter = self.filter

        return .single(items) |> mapToSignal { items in
            return chatListFilterPreferences(postbox: context.account.postbox) |> deliverOnMainQueue |> take(1) |> map { filters -> [ContextMenuItem] in
                
                var items = items
                
                var submenu: [ContextMenuItem] = []
                
                
                
                if let peerId = peerId, peerId.namespace != Namespaces.Peer.SecretChat {
                    for item in filters.list {
                        
                        submenu.append(ContextMenuItem(item.title, handler: {
                            _ = updateChatListFiltersInteractively(postbox: context.account.postbox, { list in
                                var list = list
                                for (i, folder) in list.enumerated() {
                                    var folder = folder
                                    if folder.id == item.id {
                                        if item.data.includePeers.peers.contains(peerId) {
                                            var peers = folder.data.includePeers.peers
                                            peers.removeAll(where: { $0 == peerId })
                                            folder.data.includePeers.setPeers(peers)
                                        } else {
                                            folder.data.includePeers.setPeers(folder.data.includePeers.peers + [peerId])
                                        }
                                        list[i] = folder

                                    }
                                }
                                return list
                            }).start()
                        }, state: item.data.includePeers.peers.contains(peerId) ? NSControl.StateValue.on : nil))
                    }
                }
                
                if !submenu.isEmpty {
                    items.append(ContextSeparatorItem())
                    let item = ContextMenuItem(L10n.chatListFilterAddToFolder)
                    let menu = NSMenu()
                    for item in submenu {
                        menu.addItem(item)
                    }
                    item.submenu = menu
                    items.append(item)
                }
                
                return items
            }
        }
    }
    
    var ctxDisplayLayout:(TextNodeLayout, TextNode)? {
        if isSelected && context.sharedContext.layout != .single {
            return displaySelectedLayout
        }
        return displayLayout
    }
    
    var ctxChatNameLayout:(TextNodeLayout, TextNode)? {
        if isSelected && context.sharedContext.layout != .single {
            return chatNameSelectedLayout
        }
        return chatNameLayout
    }
    
    var ctxMessageLayout:(TextNodeLayout, TextNode)? {
        if isSelected && context.sharedContext.layout != .single {
            if let typingSelectedLayout = typingSelectedLayout {
                return typingSelectedLayout
            }
            return messageSelectedLayout
        }
        if let typingLayout = typingLayout {
            return typingLayout
        }
        return messageLayout
    }
    var ctxDateLayout:(TextNodeLayout, TextNode)? {
        if isSelected && context.sharedContext.layout != .single {
            return dateSelectedLayout
        }
        return dateLayout
    }
    
    var ctxBadgeNode:BadgeNode? {
        if isSelected && context.sharedContext.layout != .single {
            return badgeSelectedNode
        }
        return badgeNode
    }
    
    var ctxAdditionalBadgeNode:BadgeNode? {
        if isSelected && context.sharedContext.layout != .single {
            return additionalBadgeSelectedNode
        }
        return additionalBadgeNode
    }
    
    
    override var instantlyResize: Bool {
        return true
    }

    deinit {
        clearHistoryDisposable.dispose()
        deleteChatDisposable.dispose()
        requestSessionId.dispose()
    }
    
    override func viewClass() -> AnyClass {
        return ChatListRowView.self
    }
  
    override var height: CGFloat {
        if let archiveStatus = archiveStatus, context.sharedContext.layout != .minimisize {
            switch archiveStatus {
            case .collapsed:
                return 30
            default:
                return 70
            }
        }
        return 70
    }
    
}
