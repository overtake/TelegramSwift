//
//  ChatRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import ObjcUtils
import Postbox
import SwiftSignalKit
import DateUtils
import InAppSettings
import ColorPalette

private let forwardKeyString = ":##"

struct ChatFloatingPhoto {
    var point: NSPoint
    var items:[ChatRowItem]
    var photoView: NSView?
    var isAnchor: Bool
}

let simpleDif:Int32 = 10 * 60
let forwardDif:Int32 = 10 * 60

func makeChatItems(items:[(Int,TableRowItem)], maxHeight:CGFloat? = nil) -> [(Int,TableRowItem)] {
    var mapped:[(Int,TableRowItem)] = []
    var currentHeight:CGFloat = 0
    for (idx,item) in items {
        let _ = item.makeSize(item.width)
        currentHeight += item.height
        mapped.append((idx, item))
        if let maxHeight = maxHeight {
            if maxHeight < currentHeight {
                break
            }
        }
     }
    return mapped
}





enum ForwardItemType {
    case FullHeader;
    case ShortHeader;
    case Inside;
    case Bottom;
}

enum ChatItemType : Equatable {
    
    enum Header {
        case normal
        case short
    }
    
    case Full(rank: String?, header: Header)
    case Short(rank: String?, header: Header)
}

enum ChatItemRenderType {
    case bubble
    case list
}



class ChatRowItem: TableRowItem {
    
    override var canBeAnchor: Bool {
        return !self.entry.isFakeMessage
    }
    
    class RowCaption {
        var id: UInt32
        var offset: NSPoint
        var layout: FoldingTextLayout
        var isLoading: Bool
        var message: Message
        var contentInset: CGFloat
        init(message: Message, id: UInt32, offset: NSPoint, layout: FoldingTextLayout, isLoading: Bool, contentInset: CGFloat) {
            self.id = id
            self.message = message
            self.offset = offset
            self.layout = layout
            self.isLoading = isLoading
            self.contentInset = contentInset
        }
        
        var invertedSize: CGFloat {
            return offset.y + layout.size.height + contentInset * 2
        }
        var invertedOffset: CGFloat {
            return offset.y + layout.size.height + contentInset
        }
        
        func isSame(to other: RowCaption) -> Bool {
            return self.message.id == other.message.id && self.id == other.id && self.layout.string == other.layout.string
        }
        
        func withUpdatedOffset(_ offset: CGFloat) -> RowCaption {
            return RowCaption(message: self.message, id: self.id, offset: .init(x: 0, y: offset), layout: self.layout, isLoading: self.isLoading, contentInset: self.contentInset)
        }
    }
    
    var invertMedia: Bool {
        if let media = self.message?.media.first as? TelegramMediaFile, !media.isInteractiveMedia {
            return false
        } else {
            return (self.message?.invertMedia ?? false) && !captionLayouts.isEmpty
        }
    }
    
    var isAdRow: Bool {
        return message?.adAttribute != nil
    }
    
    private(set) var chatInteraction:ChatInteraction
    
    let context: AccountContext
    private(set) var peer:Peer?
    private(set) var entry:ChatHistoryEntry
    private(set) var message:Message?
    
    var monoforumState: MonoforumUIState? {
        return entry.additionalData.monoforumState
    }
    
    private var updateCountDownTimer: SwiftSignalKit.Timer?
    var updateTooltip:((String)->Void)? = nil
    var firstMessage: Message? {
        return messages.first
    }
    var lastMessage: Message? {
        return messages.last
    }
    
    var messages: [Message] {
        if let message = message {
            return [message]
        }
        return []
    }
    
    private(set) var itemType:ChatItemType = .Full(rank: nil, header: .normal)
    
    var isFullItemType: Bool {
        if case .Full = itemType {
            return true
        } else {
            return false
        }
    }

    //right view
    private(set) var date:TextViewLayout?
    private(set) var channelViews:TextViewLayout?
    private(set) var replyCount:TextViewLayout?
    private(set) var postAuthor:TextViewLayout?
    private(set) var editedLabel:TextViewLayout?
    private(set) var paidMessage:TextViewLayout?

    private(set) var messageEffect: AvailableMessageEffects.MessageEffect?
   
    private(set) var fullDate:String?
    private(set) var originalFullDate:String?
    private(set) var forwardHid: String?
    private(set) var nameHide: String?
    
    var nameColor: NSColor {
        if let peer = self.peer, let message = message {
            var nameColor:NSColor = presentation.chat.linkColor(isIncoming, entry.renderType == .bubble)
            
            if let _nameColor = peer.nameColor {
                nameColor = context.peerNameColors.get(_nameColor).main
            }
  
            if message.forwardInfo?.psaType != nil, entry.renderType == .list {
                nameColor = presentation.colors.greenUI
            }
            
            if message.adAttribute != nil, let author = message.author {
                nameColor = context.peerNameColors.get(author.nameColor ?? .blue).main
            }
            return nameColor
        }
        return presentation.chat.linkColor(isIncoming, entry.renderType == .bubble)
    }
    
    var forwardNameColor: NSColor {
        if let peer = self.peer, let message = message {
            var nameColor:NSColor = presentation.chat.linkColor(isIncoming, entry.renderType == .bubble)
            
            if let _nameColor = peer.nameColor {
                nameColor = context.peerNameColors.get(_nameColor).main
            }
  
            if message.forwardInfo?.psaType != nil, entry.renderType == .list {
                nameColor = presentation.colors.greenUI
            }
            
            if message.adAttribute != nil, let author = message.author {
                nameColor = context.peerNameColors.get(author.nameColor ?? .blue).main
            }
            return nameColor
        }
        return presentation.chat.linkColor(isIncoming, entry.renderType == .bubble)
    }


	var forwardType:ForwardItemType? {
        didSet {
            
        }
    }
    
    
    var sending: Bool {
        return message?.flags.contains(.Unsent) ?? false
    }

    private var forwardHeaderNode:TextNode?
    private(set) var forwardHeader: TextViewLayout?
    private(set) var forwardNameLayout: TextViewLayout?
    private(set) var forwardPhotoPlaceRange: NSRange?
    
    var captionLayouts:[RowCaption] = []
    private(set) var authorText:TextViewLayout?
    private(set) var adminBadge:TextViewLayout?
    
    private(set) var boostBadge:TextViewLayout?

    

    var replyModel:ChatAccessoryModel?
    
    var replyMarkupModel:ReplyMarkupNode?

    var messageIndex:MessageIndex? {
        if let message = message {
            return MessageIndex(message)
        }
        return nil
    }
    
    var topInset:CGFloat   {
        return 2
    }
    var defaultContentTopOffset:CGFloat {
        if isBubbled {
            return 10
        } else {
            return 6
        }
    }
    
    var rightInset:CGFloat {
        if isBubbled {
            return 15
        } else {
            return chatInteraction.presentation.selectionState != nil ? 42.0 : 20.0
        }
    }
    var leftInset:CGFloat {
        var inset: CGFloat = 20
        if let monoforum = entry.additionalData.monoforumState {
            if case .vertical = monoforum {
                if isIncoming || !isBubbled {
                    inset += 80
                }
            }
        }
        return inset
    }

    
    var _defaultHeight:CGFloat {
        return self.contentOffset.y + defaultContentTopOffset
    }
    
    var _contentSize:NSSize = NSZeroSize
    var previousBlockWidth:CGFloat = 0;

    var bubbleDefaultInnerInset: CGFloat {
        return bubbleContentInset * 2 + additionBubbleInset
    }
    
    var layoutReplyToContent: Bool {
        return false
    }
    
    var max_reply_size_width: CGFloat {
        if isBubbleFullFilled {
            return contentSize.width - bubbleContentInset * 2
        } else {
            return bubbleFrame.width - bubbleDefaultInnerInset
        }
    }
    
    var min_block_width: CGFloat {
        return 450
    }
    
    var blockWidth:CGFloat {
        
        var widthForContent: CGFloat = 0
        
        if isBubbled {
            
            var tempWidth: CGFloat = width - self.contentOffset.x - bubbleDefaultInnerInset - (20 + 10 + additionBubbleInset) - 20
            
            if isSharable || hasSource {
                tempWidth -= 35
            }
            if isLikable {
                tempWidth -= 35
            }
            widthForContent = min(tempWidth, min_block_width)
            
            
        } else {
            if case .Full = itemType {
                let additionWidth:CGFloat = date?.layoutSize.width ?? 20
                widthForContent = min(800, width) - self.contentOffset.x - 44 - additionWidth
            } else {
                widthForContent = min(800, width) - self.contentOffset.x - rightSize.width - 44
            }
        }
        
        if forwardType != nil {
            widthForContent -= leftContentInset
        }
        
        if let monoforumState = entry.additionalData.monoforumState {
            if case .vertical = monoforumState {
                if self is ChatServiceItem {
                    widthForContent -= 80
                } else if !isIncoming, isBubbled {
                    widthForContent -= 80
                }
            }
        }
        return widthForContent
    }
    
    private(set) var rightFrames: ChatRightView.Frames?
    private var rightHeight: CGFloat {
        var height:CGFloat = 16
        if isStateOverlayLayout {
            height = 16
        }
        return height
    }
    public var rightSize:NSSize {
        if let _ = message?.adAttribute {
            return .zero
        }
//        if let _ = chatInteraction.mode.customChatContents {
//            return .zero
//        }
        if let frames = rightFrames {
            return NSMakeSize(frames.width, rightHeight)
        } else {
            return .zero
        }
    }
    
    var stateOverlayAdditionCorner: CGFloat {
        return isStateOverlayLayout ? 5 : 0
    }
    
    var contentSize:NSSize {
        return _contentSize
    }
    
    var realContentSize: NSSize {
        return _contentSize
    }
    
    var isSticker: Bool {
        let file = message?.anyMedia as? TelegramMediaFile
        return file?.isStaticSticker == true || file?.isAnimatedSticker == true  || file?.isVideoSticker == true
    }
    

    override var height: CGFloat  {
        var height:CGFloat = self.contentSize.height + _defaultHeight
        
        guard let message = self.message else {
            return height
        }
        
        if !isBubbled, case .Full = self.itemType, self is ChatMessageItem {
            height += 2
        }
        
        if !captionLayouts.isEmpty {
            let captionHeight: CGFloat = captionLayouts.reduce(0, { $0 + $1.layout.size.height }) + defaultContentInnerInset * CGFloat(captionLayouts.count)
            if let item = self as? ChatGroupedItem {
                switch item.layoutType {
                case .photoOrVideo:
                    height += captionHeight
                case .files:
                    break
                }
            } else {
                height += captionHeight
            }
        }
        if let replyMarkupModel = replyMarkupModel {
            height += replyMarkupModel.size.height + defaultReplyMarkupInset
        }
        
        if isBubbled {
            if let additional = additionalLineForDateInBubbleState {
                height += additional
            }
   
            if replyModel?.isSideAccessory == true {
                height = max(48, height)
            }
        }
        if let _ = commentsBubbleData {
            height += ChatRowItem.channelCommentsBubbleHeight
        }
        
        if let reactions = self.reactionsLayout {
            height += defaultReactionsInset
            height += reactions.size.height
            
            if invertMedia, commentsBubbleData != nil {
                height += defaultContentInnerInset
            }
        }
        
        if let factCheckLayout {
            height += factCheckLayout.size.height
            height += defaultContentInnerInset
            if captionLayouts.isEmpty && message.text.isEmpty, message.media.first?.isInteractiveMedia == true {
                height += defaultContentInnerInset + 4
            }
        }
        
//        if isBubbled, let _ = replyMarkupModel, replyModel != nil {
//            height += 4
//        }
        
        if contentSize.height == 0 {
            if replyModel != nil {
                height += defaultContentTopOffset
            }
        }
        
        return max(rightSize.height + 8, height)
    }
    
    var defaultReplyMarkupInset: CGFloat {
        return  (isBubbled ? 4 : defaultContentInnerInset)
    }
    
    var defaultReactionsInset: CGFloat {
        if isBubbled {
            if isBubbleFullFilled {
                if captionLayouts.isEmpty {
                    return defaultReplyMarkupInset
                }
            } else {
                return defaultContentInnerInset
            }
        }
        return defaultContentInnerInset
    }
    private var _id: String?
    override var identifier: String {
        if let id = _id {
            return id
        }
        let id: String = super.identifier
        _id = id
        return id
    }
    
    var defaultContentInnerInset: CGFloat {
        return ChatRowItem.defaultContentInnerInset
    }
    
    static var defaultContentInnerInset: CGFloat {
        return 7
    }
    
    var elementsContentInset: CGFloat {
        return 0
    }
    
    var replyOffset:CGFloat {
        var top:CGFloat = defaultContentTopOffset
        if isBubbled && (authorText != nil || forwardNameLayout != nil) {
            top -= topInset
        } else if isBubbled {
            top += topInset + 1
        }
        if let author = authorText {
            top += author.layoutSize.height + defaultContentInnerInset
        }
        if let author = forwardNameLayout {
            top += author.layoutSize.height + defaultContentInnerInset - 2
            
            if !isBubbled, let header = forwardHeader {
                top += header.layoutSize.height
            }
        }
        
        if let value = topicLinkLayout {
            top += value.size.height + defaultContentInnerInset
        }
       
        return top
    }
    
    var topicLinkOffset:CGFloat {
        var offset = self.replyOffset
        
        if let value = topicLinkLayout {
            offset -= (value.size.height + defaultContentInnerInset)
        }
        return offset
    }
    
    var isBubbleFullFilled: Bool {
        return false
    }
    
    var fixedContentSize: Bool {
        return false
    }
    
    var canBlur: Bool {
        if context.isLite(.blur) {
            return false
        }
        
        return true
    }
    var shouldBlurService: Bool {
        if !canBlur {
            return false
        }
        if presentation.shouldBlurService, isStateOverlayLayout {
            return true
        } else if isStateOverlayLayout {
            if let message = message, let media = message.anyMedia {
                return isBubbled && media.isInteractiveMedia && captionLayouts.isEmpty
            } else {
                return false
            }
        }
        return false
    }
    
    var isStateOverlayLayout: Bool {
        if let message = message, let media = message.anyMedia {
            if isSticker {
                return isBubbled
            }
            if let media = media as? TelegramMediaFile, media.isInstantVideo {
                if let data = entry.additionalData.transribeState {
                    switch data {
                    case .loading, .revealed:
                        return false
                    default:
                        break
                    }
                }
            }
            if media is TelegramMediaDice {
                return isBubbled
            }
            
            
            if let attr = message.factCheckAttribute, case .Loaded = attr.content {
                return false
            }
            
            
            if let message = effectiveCommentMessage, message.hasComments && message.hasReactions && message.invertMedia {
                return false
            }
            
            
            if let media = message.media.first as? TelegramMediaStory, let story = message.associatedStories[media.storyId]?.get(Stories.StoredItem.self) {
                switch story {
                case let .item(item):
                    if !item.text.isEmpty {
                        return false
                    }
                case .placeholder:
                    break
                }
            }
            
            if let media = media as? TelegramMediaMap {
                if let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                    var time:TimeInterval = Date().timeIntervalSince1970
                    if liveBroadcastingTimeout == .max {
                        return false
                    } else {
                        time -= context.timeDifference
                        if Int(time) < Int(message.timestamp) + Int(liveBroadcastingTimeout) {
                            return false
                        }
                    }
                   
                }
                return media.venue == nil
            }
            return isBubbled && media.isInteractiveMedia && (captionLayouts.isEmpty || invertMedia)
        }
        return false
    }
    
    private(set) var isForceRightLine: Bool = false
    
    var forwardHeaderInset:NSPoint {
        
        var top:CGFloat = defaultContentTopOffset + 1
        
        
        
        if !isBubbled, forwardHeader == nil {
           // top -= topInset
        } else if isBubbled {
            top -= 1
          //  top -= topInset
        }
        
        if let author = authorText {
            top += author.layoutSize.height
        }
        
        return NSMakePoint(defLeftInset, top)
    }
    
    var forwardNameInset:NSPoint {
        var top:CGFloat = forwardHeaderInset.y
        
        if let header = forwardHeader, !isBubbled {
            top += (header.layoutSize.height + defaultContentInnerInset)
        }
        
        return NSMakePoint(self.contentOffset.x, top)
    }
    
    var gameInset: NSPoint {
        return NSMakePoint(contentOffset.x - 10, contentOffset.y)
    }
    
    var defLeftInset:CGFloat {
        var inset: CGFloat = leftInset
        if isBubbled {
            if hasPhoto {
                inset += 36
            } else if self.isIncoming, let message = message {
                if let peer = message.peers[message.id.peerId] {
                    if peer.isGroup || peer.isSupergroup {
                        inset += 36
                    }
                }
            }
        } else {
            inset += 36 + 10
        }
        
        
        return inset
    }
    
    var hasPhoto: Bool {
        if let _ = message?.adAttribute {
            return false
        }
        if message?.id.peerId == verifyCodePeerId {
            return true
        }
        if case .searchHashtag = chatInteraction.mode.customChatContents?.kind {
            return true
        }
        if !isBubbled {
            if case .Full = itemType {
                return true
            } else {
                return false
            }
        } else {
            if let message = message, let peer = message.peers[message.id.peerId] {
                if chatInteraction.chatLocation.threadMsgId == effectiveCommentMessage?.id {
                    return false
                }
                if (isIncoming && message.id.peerId == context.peerId) {
                    return true
                }
                if message.id.peerId == repliesPeerId && message.author?.id != context.peerId {
                    return true
                }
                if !peer.isUser && !peer.isSecretChat && !peer.isChannel && isIncoming {
                    return true
                }
                if message.author != nil, let peer = message.peers[message.id.peerId] as? TelegramChannel {
                    switch peer.info {
                    case let .broadcast(info):
                        return info.flags.contains(.messagesShouldHaveProfiles)
                    default:
                        break
                    }
                }
            }
        }
        if chatInteraction.isGlobalSearchMessage {
            return true
        }
        return false
    }
    
    var isInstantVideo: Bool {
        return self is ChatVideoMessageItem
    }
    
    var contentOffset:NSPoint {
        
        var left:CGFloat = defLeftInset
        
        var top:CGFloat = defaultContentTopOffset
        
        if message?.adAttribute != nil {
            top = 4
        }
//        
//        if !isBubbled, message?.adAttribute != nil {
//            if !hasPhoto {
//                left -= (36 + 10)
//            }
//        }
        
        if let author = authorText {
            top += author.layoutSize.height
            if !isBubbled {
                top += topInset
            }
        }
        
        if let value = topicLinkLayout {
            top += value.size.height + defaultContentInnerInset
            if authorText == nil {
                top -= 3
            }
        }
        
        if let replyModel = replyModel {
            var apply: Bool = true
            if isBubbled {
                if !hasBubble {
                    apply = false
                }
            }
            if apply {
                top += max(34, replyModel.size.height) //+ ((!isBubbleFullFilled && isBubbled && self is ChatMediaItem) ? 0 : 8)
                
                top += defaultContentInnerInset + 1
                 
//                if (authorText != nil) && self is ChatMessageItem {
//                    top += topInset
//                    //top -= defaultContentInnerInset
//                }
//                else if hasBubble && self is ChatMessageItem {
//                    top -= topInset
//                }
            }
        }
        
        if let forwardNameLayout = forwardNameLayout, !isBubbled || !isInstantVideo  {
            top += forwardNameLayout.layoutSize.height
            //if !isBubbled {
               // top += 2
            //}
        }
        
        if let forwardType = forwardType, !isBubbled {
            if forwardType == .FullHeader || forwardType == .ShortHeader {
                if let forwardHeader = forwardHeader {
                    top += forwardHeader.layoutSize.height + defaultContentInnerInset
                } else {
                    top += bubbleDefaultInnerInset
                }
            }
        }
        
        if isBubbled, let item = self as? ChatMessageItem {
            if item.webpageAboveContent {
                top += topInset
            }
        }
        
        
        if forwardNameLayout != nil {
            left += leftContentInset
        }
        
       
        return NSMakePoint(left, top)
    }
    
    var leftContentInset: CGFloat {
        return 10
    }
    
    private(set) var isRead:Bool = false
    
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? ChatRowItem {
            return self.entry == object.entry
        }
        return false
    }
    
    var hasSource: Bool {
        switch chatInteraction.mode {
        case .pinned:
            return true
        case .customChatContents:
            return false
        default:
            if let message = message {
                for attr in message.attributes {
                    if let attr = attr as? SourceReferenceMessageAttribute {
                        if authorIsChannel {
                            return true
                        }
                        return (chatInteraction.peerId == context.peerId && context.peerId != attr.messageId.peerId) || message.id.peerId == repliesPeerId
                    }
                }
            }
        }
        return false
    }
    
    var isSelectedMessage: Bool {
        if let message = message {
            return chatInteraction.presentation.isSelectedMessageId(message.id)
        }
        return false
    }
    
    override var isSelectable: Bool {
        return chatInteraction.chatLocation.threadMsgId != effectiveCommentMessage?.id && self.message?.adAttribute == nil
    }
    
    var disableInteractions: Bool {
        return false
    }
    
    
    func openReplyMessage() {
        if let message = message {
            if let replyAttribute = message.replyAttribute {
                if message.id.peerId == repliesPeerId, let threadMessageId = message.replyAttribute?.threadMessageId {
                    chatInteraction.openReplyThread(threadMessageId, false, true, .comments(origin: replyAttribute.messageId))
                } else {
                    chatInteraction.focusMessageId(message.id, .init(messageId: replyAttribute.messageId, string: replyAttribute.quote?.text), .CenterEmpty)
                }
            } else if let _ = message.quoteAttribute {
                let id = MessageId(peerId: .init(0), namespace: 0, id: 0)
                chatInteraction.focusMessageId(id, .init(messageId: id, string: nil), .CenterEmpty)
            }
        }
    }
    func openStory() {
        if let message = message {
            if let replyAttribute = message.storyAttribute {
                chatInteraction.openStory(message.id, replyAttribute.storyId)
            }
        }
    }
    
    func showExpiredStoryError() {
        showModalText(for: context.window, text: strings().chatReplyExpiredStoryError)
    }
    
    func gotoSourceMessage() {
        if let message = message {
            switch chatInteraction.mode {
            case .pinned:
                let navigation = chatInteraction.context.bindings.rootNavigation()
                let controller = navigation.previousController as? ChatController
                controller?.chatInteraction.focusPinnedMessageId(message.id)
                navigation.back()
            default:
                for attr in message.attributes {
                    if let attr = attr as? SourceReferenceMessageAttribute {
                        if message.id.peerId == repliesPeerId, let threadMessageId = message.replyAttribute?.threadMessageId {
                            chatInteraction.openReplyThread(threadMessageId, false, true, .comments(origin: attr.messageId))
                        } else {
                            switch chatInteraction.mode {
                            case .thread:
                                chatInteraction.focusMessageId(nil, .init(messageId: attr.messageId, string: nil), .CenterEmpty)
                            default:
                                chatInteraction.openInfo(attr.messageId.peerId, true, attr.messageId, nil)
                            }
                        }
                    }
                }
            }
            
        }
    }
    
    var isVideoOrBigEmoji: Bool {
        return self is ChatVideoMessageItem || (message != nil && bigEmojiMessage(context.sharedContext, message: message!))
    }
    
    func share() {
        if let message = message {
            showModal(with: ShareModalController(ShareMessageObject(context, message)), for: context.window)
        }
    }
    
    var authorIsChannel: Bool {
        guard let message = message else {
            return false
        }
        return ChatRowItem.authorIsChannel(message: message, account: context.account)
    }
    
    private static func authorIsChannel(message: Message, account: Account) -> Bool {
        
        let isCrosspostFromChannel = message.isCrosspostFromChannel(account: account)
        
        var sourceReference: SourceReferenceMessageAttribute?
        for attribute in message.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute {
                sourceReference = attribute
                break
            }
        }
        
        var authorIsChannel: Bool = false
        if let peer = message.peers[message.id.peerId] as? TelegramChannel {
            if case .broadcast = peer.info {
                
            } else {
                if isCrosspostFromChannel, let sourceReference = sourceReference, let _ = message.peers[sourceReference.messageId.peerId] as? TelegramChannel {
                    authorIsChannel = true
                }
            }
        } else {
            if isCrosspostFromChannel, let _ = message.forwardInfo?.source as? TelegramChannel {
                authorIsChannel = true
            }
        }
        
        
        return authorIsChannel
    }
    
    var isLikable: Bool {
        return false
    }
    
    var isLiked: Bool {
        return false
    }
    

    override func copyAndUpdate(animated: Bool) {
        DispatchQueue.main.async {
            if let table = self.table, self.index != -1 {
                let item = ChatRowItem.item(table.frame.size, from: self.entry, interaction: self.chatInteraction, theme: self.presentation)
                _ = item.makeSize(table.frame.width, oldWidth: 0)
                let transaction = TableUpdateTransition(deleted: [], inserted: [], updated: [(self.index, item)], animated: animated)
                table.merge(with: transaction)
            }
        }
    }
    
    var shareVisible: Bool {
        
        guard let message = message else {
            return false
        }
        if isSharable {
            if message.isScheduledMessage || message.flags.contains(.Sending) || message.flags.contains(.Failed) || message.flags.contains(.Unsent) {
                return false
            } else {
                return true
            }
        }
        return false
    }
    
    var canReact: Bool {
        if let message = firstMessage {
            
            if entry.isFakeMessage {
                return false
            }
            
            if chatInteraction.isPeerSavedMessages {
                return false
            }
            if message.id.namespace != Namespaces.Message.Cloud {
                return false
            }
            if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                return false
            }
            if isUnsent {
                return false
            }
            if isFailed {
                return false
            }
            if message.adAttribute != nil {
                return false
            }
            if unsupported {
                return false
            }
            if message.containsSecretMedia {
                return false
            }
            if let media = message.extendedMedia, let _ = media as? TelegramMediaAction {
                return message.flags.contains(.ReactionsArePossible)
            }
            if let media = message.extendedMedia as? TelegramMediaStory {
                if media.isMention {
                    return false
                }
            }
            return true
        }
        return false
    }
    
    var isSharable: Bool {
        var peers:[Peer] = []
        if let peer = peer {
            peers.append(peer)
        }
        if let peer = message?.author {
            peers.append(peer)
        }
        
        guard let message = message else {
            return false
        }
        if message.adAttribute != nil {
            return false
        }
        
        if chatInteraction.mode == .preview {
            return false
        }
        
        
        
        if message.isCopyProtected() {
            return false
        }
        
        if case .searchHashtag = chatInteraction.mode.customChatContents?.kind {
            return true
        }
        
        if authorIsChannel {
            return false
        }
        

        
        if let info = message.forwardInfo {
            if let author = info.author {
                peers.append(author)
            }
            
            if let peer = info.source {
                peers.append(peer)
            }
        }
        
        for peer in peers {
            if peer.addressName == "reviews_bot" || peer.addressName == "ReviewInsightsBot" {
                return true
            }
            if let peer = peer as? TelegramChannel {
                switch peer.info {
                case .broadcast:
                    return isIncoming && !chatInteraction.isLogInteraction
                default:
                    return false
                }
            }
            if let peer = peer as? TelegramUser {
                if peer.botInfo != nil {
                    if self is ChatMediaItem && !chatInteraction.isLogInteraction {
                        return true
                    } else if let item = self as? ChatMessageItem {
                        return item.webpageLayout != nil
                    }
                    return false
                }
            }
        }
        
        
        return false
    }
    
    private let _isScam: Bool
    private let _isFake: Bool
    
    private(set) var isForwardScam: Bool
    private(set) var isForwardFake: Bool

    var isFailed: Bool {
        for message in messages {
            if message.flags.contains(.Failed) {
                return true
            }
        }
        return false
    }
    
    var isPinned: Bool {
        for message in messages {
            if message.tags.contains(.pinned) {
                return true
            }
        }
        return false
    }
    
    let isIncoming: Bool
    
    var canHasFloatingPhoto: Bool {
        if chatInteraction.mode.isSavedMode {
            return false
        } else if chatInteraction.mode.isThreadMode, chatInteraction.chatLocation.threadMsgId == message?.id {
            return false
        } else {
            return isIncoming && self.hasPhoto
        }
    }
    
    var isUnsent: Bool {
        if entry.additionalData.updatingMedia != nil {
            return true
        }
        if let message = message {
            return message.flags.contains(.Unsent)
        }
        return false
    }
    
    var isEditMarkVisible: Bool {
        var peers:[Peer] = []
        if let peer = peer {
            peers.append(peer)
        }
        if let info = message?.forwardInfo?.author {
            peers.append(info)
        }
        
        for peer in peers {
            if let peer = peer as? TelegramUser {
                if peer.botInfo != nil {
                    return false
                }
            }
        }
        
        for message in messages {
            if message.isScheduledMessage {
                return false
            }
            for attr in message.attributes {
                if attr is InlineBotMessageAttribute {
                    return false
                }
            }
            for media in message.media {
                if media is TelegramMediaMap {
                    return false
                }
            }
            
            if message.isImported {
                return true
            }
            for attr in message.attributes {
                if let attr = attr as? EditedMessageAttribute {
                    return !chatInteraction.isLogInteraction && message.id.peerId != context.peerId && !attr.isHidden
                }
            }
        }
        
        return false
    }
    
    private static func canFillAuthorName(_ message: Message, chatInteraction: ChatInteraction, renderType: ChatItemRenderType, isIncoming: Bool, hasBubble: Bool) -> Bool {
        var canFillAuthorName: Bool = true
        var disable: Bool = false
        
        if message.adAttribute != nil {
            return false
        }
      
        switch chatInteraction.chatLocation {
        case .peer, .thread:
            if renderType == .bubble, let peer = coreMessageMainPeer(message) {
                canFillAuthorName = isIncoming && (peer.isGroup || peer.isSupergroup || message.id.peerId == chatInteraction.context.peerId || message.id.peerId == repliesPeerId || message.id.peerId == verifyCodePeerId || message.adAttribute != nil)
                
               
                if let _ = message.anyMedia as? TelegramMediaGiveaway {
                    disable = true
                }
                
                if let media = message.anyMedia {
                    canFillAuthorName = canFillAuthorName && !media.isInteractiveMedia && hasBubble && isIncoming
                } else if bigEmojiMessage(chatInteraction.context.sharedContext, message: message) {
                    canFillAuthorName = false
                    disable = true
                }
                if message.isAnonymousMessage, !isIncoming {
                    if let media = message.anyMedia as? TelegramMediaFile {
                        if media.isSticker || media.isAnimatedSticker {
                            disable = true
                        }
                    }
                    if !disable {
                        canFillAuthorName = true
                    }
                }
                if !isIncoming && message.author?.id != chatInteraction.context.peerId, message.globallyUniqueId != 0 {
                    if let media = message.anyMedia as? TelegramMediaFile {
                        if media.isSticker || media.isAnimatedSticker {
                            disable = true
                        }
                    }
                    if !disable {
                        canFillAuthorName = true
                    }
                }
                
                if let peer = message.peers[message.id.peerId] as? TelegramChannel, let _ = message.author {
                    switch peer.info {
                    case let .broadcast(info):
                        if info.flags.contains(.messagesShouldHaveProfiles) {
                            if !disable {
                                canFillAuthorName = true
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
        return canFillAuthorName
    }
    
    var canFillAuthorName: Bool {
        if let message = message {
            return ChatRowItem.canFillAuthorName(message, chatInteraction: chatInteraction, renderType: renderType, isIncoming: isIncoming, hasBubble: hasBubble)
        }
        return true
    }
    
    var isBubbled: Bool {
        return renderType == .bubble
    }
    
    var psaButton: NSAttributedString? {
        if let info = message?.forwardInfo?.psaType {
            let text = localizedPsa("psa.text", type: info)
            
            let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: .white), bold: MarkdownAttributeSet(font: .bold(.text), textColor: .white), link: MarkdownAttributeSet(font: .normal(.text), textColor: .link), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { url in
                    execute(inapp: .external(link: url, false))
                }))
            }))
            return attributedText
        }
        return nil
    }
    
    var isPsa: Bool {
        return message?.forwardInfo?.psaType != nil
    }
    
    var hasHeader: Bool {
        return !(hasBubble && authorText == nil && replyModel == nil && forwardNameLayout == nil)
    }
    
    var hasBubble: Bool 
    
    static func hasBubble(_ message: Message?, entry: ChatHistoryEntry, type: ChatItemType, sharedContext: SharedAccountContext) -> Bool {
        if let message = message, let media = message.anyMedia {
            
            
            if message.adAttribute != nil {
                return true
            }
            
            if let file = media as? TelegramMediaFile {
                if file.isStaticSticker {
                    return false
                }
                if file.isVideoSticker {
                    return false
                }
                if file.isAnimatedSticker {
                    return false
                }
                if file.isInstantVideo {
                    if let data = entry.additionalData.transribeState {
                        switch data {
                        case .loading, .revealed:
                            return true
                        default:
                            break
                        }
                    }
                    return false //!message.text.isEmpty || (message.replyAttribute != nil && !file.isInstantVideo) || (message.forwardInfo != nil && !file.isInstantVideo)
                }
            }
            if media is TelegramMediaDice {
                return false
            }
            
            for attr in message.attributes {
                if let _ = attr as? InlineBotMessageAttribute {
                    return true
                }
            }
            
            var peer: Peer?
            for attr in message.attributes {
                if let _ = attr as? SourceReferenceMessageAttribute {
                    if let info = message.forwardInfo {
                        peer = info.author
                    }
                    break
                }
            }
            
            if let _peer = coreMessageMainPeer(message) as? TelegramChannel, case let .broadcast(info) = _peer.info {
                if info.flags.contains(.hasDiscussionGroup) {
                    return true
                }
                peer = _peer
            } else if let author = message.effectiveAuthor, peer == nil {
                if author is TelegramSecretChat {
                    peer = coreMessageMainPeer(message)
                } else {
                    peer = author
                }
            }
            
//            if message.groupInfo != nil {
//                switch entry {
//                case .groupedPhotos(let entries, _):
//                    let prettyCount = entries.filter { $0.message?.anyMedia?.isInteractiveMedia ?? false }.count
//                    return !message.text.isEmpty || message.replyAttribute != nil || message.forwardInfo != nil || entries.count == 1 || prettyCount != entries.count
//                default:
//                    return true
//                }
//            }
        
        } else if let message = message {
            if entry.additionalData.eventLog != nil {
                return true
            }
            if message.adAttribute != nil {
                return true
            }
            return !bigEmojiMessage(sharedContext, message: message)
        }
        return true
    }
    
    var fillPhoto: Bool {
        if self.renderType != .bubble {
            return true
        } else if chatInteraction.isLogInteraction {
            return true
        } else if chatInteraction.mode.isSavedMode {
            return true
        }
        return false
    }
    
    let renderType: ChatItemRenderType
    var bubbleImage:(CGImage, NSEdgeInsets)? = nil
    var bubbleBorderImage:(CGImage, NSEdgeInsets)? = nil
    
    let downloadSettings: AutomaticMediaDownloadSettings
    
    let presentation: TelegramPresentationTheme


    
    private var _approximateSynchronousValue: Bool = false
    var approximateSynchronousValue: Bool {
        get {
            let result = _approximateSynchronousValue
            _approximateSynchronousValue = false
            return result
        }
    }
    
    private var _avatarSynchronousValue: Bool = false
    var avatarSynchronousValue: Bool {
        get {
            let result = _avatarSynchronousValue
            _avatarSynchronousValue = false
            return result
        }
    }
    
    static var channelCommentsBubbleHeight: CGFloat {
        return 42
    }
    static var channelCommentsHeight: CGFloat {
        return 16
    }
    
    var effectiveCommentMessage: Message? {
        switch entry {
        case let .MessageEntry(message, _, _, _, _, _, _):
            return message
        case let .groupedPhotos(entries, groupInfo: _):
            return entries.first?.message
        default:
            return nil
        }
    }
    
    var channelHasCommentButton: Bool {
        if chatInteraction.mode == .scheduled || chatInteraction.isLogInteraction {
            return false
        }
        if let message = effectiveCommentMessage, let peer = message.peers[message.id.peerId] as? TelegramChannel {
            switch peer.info {
            case let .broadcast(info):
                if info.flags.contains(.hasDiscussionGroup) {
                    if message.flags.contains(.Sending) || message.flags.contains(.Failed) || message.flags.contains(.Unsent) {
                        switch chatInteraction.presentation.discussionGroupId {
                        case .unknown:
                            return false
                        case .known:
                            return true
                        }
                    }
                    for attr in message.attributes {
                        if let attr = attr as? ReplyThreadMessageAttribute {
                            switch chatInteraction.presentation.discussionGroupId {
                            case .unknown:
                                return true
                            case let .known(peerId):
                                return attr.commentsPeerId == peerId
                            }
                        }
                    }
                    
                }
            default:
                break
            }
        }
        
        return false
    }
    
    private var _commentsBubbleData: ChannelCommentsRenderData?
    private var _commentsBubbleDataOverlay: ChannelCommentsRenderData?
    
    var commentsBubbleDataOverlay: ChannelCommentsRenderData? {
        if let commentsBubbleDataOverlay = _commentsBubbleDataOverlay {
            return commentsBubbleDataOverlay
        }
        
        if chatInteraction.isLogInteraction {
            return nil
        }
        if chatInteraction.mode == .preview {
            return nil
        }
        
        if !isStateOverlayLayout || hasBubble || !channelHasCommentButton {
            return nil
        }
        if let message = effectiveCommentMessage, let peer = message.peers[message.id.peerId] as? TelegramChannel {
            switch peer.info {
            case let .broadcast(info):
                if info.flags.contains(.hasDiscussionGroup) {
                    var count: Int32 = 0
                    var hasUnread: Bool = false
                    for attr in message.attributes {
                        if let attribute = attr as? ReplyThreadMessageAttribute {
                            count = attribute.count
                            if let maxMessageId = attribute.maxMessageId, let maxReadMessageId = attribute.maxReadMessageId {
                                hasUnread = maxReadMessageId < maxMessageId
                            }
                            break
                        }
                    }
                    let title: String = "\(Int(count).prettyRounded)"
                    let textColor = isBubbled && presentation.backgroundMode.hasWallpaper ? presentation.chatServiceItemTextColor : presentation.colors.accent
                    
                    var texts:[ChannelCommentsRenderData.Text] = []
                    if count > 0 {
                        texts.append(ChannelCommentsRenderData.Text.init(text: .initialize(string: title, color: textColor, font: .normal(.short)), animation: .numeric, index: 0))
                    }
                    
                    _commentsBubbleDataOverlay = ChannelCommentsRenderData(context: chatInteraction.context, message: message, hasUnread: hasUnread, title: texts, peers: [], drawBorder: true, isLoading: entry.additionalData.isThreadLoading, bubbleMode: renderType == .bubble, handler: { [weak self] in
                        self?.chatInteraction.openReplyThread(message.id, true, false, .comments(origin: message.id))
                    })
                }
            default:
                break
            }
        }
        return _commentsBubbleDataOverlay
    }
    
    var commentsBubbleData: ChannelCommentsRenderData? {
        if let commentsBubbleData = _commentsBubbleData {
            return commentsBubbleData
        }
        if chatInteraction.isLogInteraction {
            return nil
        }
        if !channelHasCommentButton {
            return nil
        }
        if chatInteraction.mode == .preview {
            return nil
        }
        
        if isStateOverlayLayout, let media = effectiveCommentMessage?.anyMedia, !media.isInteractiveMedia {
            return nil
        } else if (self is ChatVideoMessageItem) {
            return nil
        }
        if let message = effectiveCommentMessage, let peer = message.peers[message.id.peerId] as? TelegramChannel {
            
            if let messageItem = self as? ChatMessageItem, messageItem.containsBigEmoji  {
                return nil
            }
            
            switch peer.info {
            case let .broadcast(info):
                if info.flags.contains(.hasDiscussionGroup) {
                    
                    var latestPeers:[Peer] = []
                    var count: Int32 = 0
                    var hasUnread = false
                    for attr in message.attributes {
                        if let attribute = attr as? ReplyThreadMessageAttribute {
                            count = attribute.count
                            if let maxMessageId = attribute.maxMessageId {
                                if let maxReadMessageId = attribute.maxReadMessageId {
                                    hasUnread = maxReadMessageId < maxMessageId
                                } else {
                                    hasUnread = false
                                }
                            }
                            latestPeers = message.peers.filter { peerId, _ -> Bool in
                                return attribute.latestUsers.contains(peerId)
                            }.map { $0.1 }
                            break
                        }
                    }
                    
                    var title: [(String, ChannelCommentsRenderData.Text.Animation, Int)] = []
                    if count == 0 {
                        title = [(strings().channelCommentsLeaveComment, .crossFade, 0)]
                    } else {
                        var text = strings().channelCommentsCountCountable(Int(count))
                        let pretty = "\(Int(count).formattedWithSeparator)"
                        text = text.replacingOccurrences(of: "\(count)", with: pretty)
                        
                        let range = text.nsstring.range(of: pretty)
                        if range.location != NSNotFound {
                            title.append((text.nsstring.substring(to: range.location), .crossFade, 0))
                            var index: Int = 0
                            for _ in range.lowerBound ..< range.upperBound {
                                let symbol = text.nsstring.substring(with: NSMakeRange(range.location + index, 1))
                                title.append((symbol, .numeric, index + 1))
                                index += 1
                            }
                            title.append((text.nsstring.substring(from: range.upperBound), .crossFade, range.length + 1))
                        } else {
                            title.append((text, .crossFade, 0))
                        }
                    }
                    
                    title = title.filter { !$0.0.isEmpty }
                    
                    let texts:[ChannelCommentsRenderData.Text] = title.map {
                        return ChannelCommentsRenderData.Text(text: .initialize(string: $0.0, color: presentation.colors.accentIcon, font: .normal(.title)), animation: $0.1, index: $0.2)
                    }
                    
                    _commentsBubbleData = ChannelCommentsRenderData(context: chatInteraction.context, message: message, hasUnread: hasUnread, title: texts, peers: latestPeers, drawBorder: !isBubbleFullFilled || !captionLayouts.isEmpty, isLoading: entry.additionalData.isThreadLoading, bubbleMode: renderType == .bubble, handler: { [weak self] in
                        self?.chatInteraction.openReplyThread(message.id, true, false, .comments(origin: message.id))
                    })
                }
            default:
                break
            }
        }
        return _commentsBubbleData
    }
    
    
    private var _topicLinkLayout: TopicReplyItemLayout?
    var topicLinkLayout: TopicReplyItemLayout? {
        if let value = _topicLinkLayout {
            return value
        } else if let message = self.message, let threadInfo = message.associatedThreadInfo, chatInteraction.mode == .history, let peer = message.peers[message.id.peerId], peer.isForum, !peer.displayForumAsTabs {
            var ignore: Bool = false
            
            if renderType == .bubble {
                let header: ChatItemType.Header
                switch itemType {
                case let .Full(_, current):
                    header = current
                case let .Short(_, current):
                    header = current
                }
                switch header {
                case .short:
                    ignore = true
                default:
                    break
                }
            } else {
                switch itemType {
                case .Short:
                    ignore = true
                default:
                    break
                }
            }
            if !ignore {
                let value = TopicReplyItemLayout(context: context, message: message, isIncoming: isIncoming, isBubbled: isBubbled, threadData: threadInfo, maxiumLines: 2, isSideAccessory: isBubbled && !hasBubble)
                _topicLinkLayout = value
                return value
            }
        }
        return nil
    }

    
    private var _reactionsLayout: ChatReactionsLayout?
    var reactionsLayout: ChatReactionsLayout? {
        if let value = _reactionsLayout {
            return value
        } else if let message = self.messages.first {
            if chatInteraction.isLogInteraction {
                return nil
            }
            
            if entry.isFakeMessage {
                return nil
            }
            if chatInteraction.isPeerSavedMessages {
                return nil
            }
            if unsupported {
                return nil
            }
            let reactions = message.effectiveReactions(context.peerId, isTags: context.peerId == chatInteraction.peerId)
            let currentTag: MessageReaction.Reaction?
            if case let .customTag(buffer, _) = chatInteraction.presentation.searchMode.tag {
                currentTag = ReactionsMessageAttribute.reactionFromMessageTag(tag: buffer)
            } else {
                currentTag = nil
            }
            let context = self.context
            let chatInteraction = self.chatInteraction
            if let reactions = reactions, !reactions.reactions.isEmpty, let available = context.reactions.available {
                let layout = ChatReactionsLayout(context: chatInteraction.context, message: message, available: available, peerAllowed: chatInteraction.presentation.allowedReactions, savedMessageTags: entry.additionalData.savedMessageTags, engine: chatInteraction.context.reactions, theme: presentation, renderType: renderType, currentTag: currentTag, isIncoming: isIncoming, isOutOfBounds: isBubbleFullFilled && (self.captionLayouts.isEmpty || invertMedia) && (commentsBubbleData == nil || !invertMedia), hasWallpaper: presentation.hasWallpaper, stateOverlayTextColor: isStateOverlayLayout ? stateOverlayTextColor : (!hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, entry.renderType == .bubble)), openInfo: { peerId in
                    PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId, source: .reaction(message.id))
                }, runEffect: { [weak chatInteraction] value in
                    chatInteraction?.runReactionEffect(value, message.id)
                }, tagAction: { [weak chatInteraction] reaction in
                    if !context.isPremium {
                        prem(with: PremiumBoardingController(context: context, source: .saved_tags, openFeatures: true), for: context.window)
                    } else {
                        chatInteraction?.setLocationTag(.customTag(ReactionsMessageAttribute.messageTag(reaction: reaction), nil))
                    }
                }, starReact: {
                    showModal(with: Star_ReactionsController(context: context, message: message), for: context.window)
                })
                
                _reactionsLayout = layout
                return layout
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    private var _factCheckLayout: FactCheckMessageLayout?
    var factCheckLayout: FactCheckMessageLayout? {
        if let factCheckLayout = _factCheckLayout {
            return factCheckLayout
        } else if let message = message, let factCheck = message.factCheckAttribute {
            if case .Loaded = factCheck.content {
                _factCheckLayout = .init(message, factCheck: factCheck, context: context, presentation: wpPresentation, chatInteraction: chatInteraction, revealed: entry.additionalData.factCheckRevealed)
            }
        }
        return _factCheckLayout
    }
    
    var forceBackgroundColor: NSColor? = nil
    let wpPresentation: WPLayoutPresentation

    
    
    init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        self.entry = object
        self.context = chatInteraction.context
        self.presentation = theme
        self.chatInteraction = chatInteraction
        self.downloadSettings = object.additionalData.automaticDownload
        self._approximateSynchronousValue = Thread.isMainThread
        self._avatarSynchronousValue = Thread.isMainThread
        self.messageEffect = object.additionalData.messageEffect
        
        
        var message: Message?
        var isRead: Bool = true
        var itemType: ChatItemType = .Full(rank: nil, header: .normal)
        var fwdType: ForwardItemType? = nil
        var renderType:ChatItemRenderType = .list
        
        
        var object = object
        var captionMessage: Message? = object.message

        var hasGroupCaption: Bool = object.message?.text.isEmpty == false
        if case let .groupedPhotos(entries, _) = object {
            object = entries.filter({!$0.message!.media.isEmpty}).first!
            
            loop: for entry in entries {
                if let _ = captionMessage, !entry.message!.text.isEmpty {
                    captionMessage = nil
                    hasGroupCaption = false
                    break loop
                }
                if !entry.message!.text.isEmpty {
                    captionMessage = entry.message!
                    hasGroupCaption = true
                    break loop
                }
            }
            if captionMessage == nil {
                captionMessage = object.message!
            }
        }

        
        if case let .MessageEntry(_message, _, _isRead, _renderType, _itemType, _fwdType, _) = object {
            message = _message
            isRead = _isRead
            itemType = _itemType
            switch _itemType {
            case .Full:
                fwdType = .FullHeader
            default:
                fwdType = _fwdType
            }
            renderType = _renderType
        }
        
        let activity: PeerNameColors.Colors
        let pattern: Int64?
        let isIncoming: Bool
        if let message = object.firstMessage {
            activity = theme.chat.webPreviewActivity(context.peerNameColors, message: message, account: context.account, bubbled: entry.renderType == .bubble)
            pattern = theme.chat.webPreviewPattern(message)
            isIncoming = message.isIncoming(context.account, object.renderType == .bubble)
        } else {
            activity = .init(main: .clear)
            pattern = nil
            isIncoming = false
        }
        self.wpPresentation = WPLayoutPresentation(text: theme.chat.textColor(isIncoming, entry.renderType == .bubble), activity: activity, link: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), ivIcon: theme.chat.instantPageIcon(isIncoming, entry.renderType == .bubble, presentation: theme), renderType: entry.renderType, pattern: pattern)
        
       
        
        
        var hiddenFwdTooltip:(()->Void)? = nil
        
       
        
        
        
        var isStateOverlayLayout: Bool {
            
            if renderType == .bubble, let message = captionMessage, let media = message.anyMedia {
                if let file = media as? TelegramMediaFile {
                    if file.isStaticSticker || file.isAnimatedSticker || file.isVideoSticker  {
                        return renderType == .bubble
                    }
                    if file.isInstantVideo {
                        if let data = object.additionalData.transribeState {
                            switch data {
                            case .loading, .revealed:
                                return false
                            default:
                                break
                            }
                        }
                        return renderType == .bubble
                    }
                    
                }
                if media is TelegramMediaDice {
                    return renderType == .bubble
                }
                
                if let attr = message.factCheckAttribute, case .Loaded = attr.content {
                    return false
                }
                
                if message.hasComments && message.hasReactions && message.invertMedia {
                    return false
                }
                
                if let media = message.media.first as? TelegramMediaStory, let story = message.associatedStories[media.storyId]?.get(Stories.StoredItem.self) {
                    switch story {
                    case let .item(item):
                        if !item.text.isEmpty {
                            return false
                        }
                    case .placeholder:
                        break
                    }
                }
                
                if let media = media as? TelegramMediaMap {
                    if let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                        if liveBroadcastingTimeout == .max {
                            return false
                        } else {
                            var time:TimeInterval = Date().timeIntervalSince1970
                            time -= context.timeDifference
                            if Int(time) < Int(message.timestamp) + Int(liveBroadcastingTimeout) {
                                return false
                            }
                        }
                        
                    }
                    return media.venue == nil
                }
                return media.isInteractiveMedia && (!hasGroupCaption || message.invertMedia)
            } else if let message = message, bigEmojiMessage(context.sharedContext, message: message), renderType == .bubble {
                return true
            }
            return false
        }
        
        var stateOverlayTextColor: NSColor {
            if let media = message?.anyMedia, media.isInteractiveMedia || media is TelegramMediaMap {
                 return NSColor(0xffffff)
            } else {
                return theme.chatServiceItemTextColor
            }
        }
        
        if message?.id.peerId == context.peerId {
            itemType = .Full(rank: nil, header: .normal)
        }
        self.renderType = renderType
        self.message = message
        
        var isForwardScam: Bool = false
        var isScam = false
        var isForwardFake: Bool = false
        var isFake = false
        if let message = message, let peer = coreMessageMainPeer(message) {
            if peer.isGroup || peer.isSupergroup {
                if let author = message.forwardInfo?.author {
                    isForwardScam = author.isScam
                }
                if let author = message.author, case .Full = itemType {
                    isScam = author.isScam
                }
                if let author = message.forwardInfo?.author {
                    isForwardFake = author.isFake
                }
                if let author = message.author, case .Full = itemType {
                    isFake = author.isFake
                }
            }
        }
        
        self._isScam = isScam
        self.isForwardScam = isForwardScam
            
        self._isFake = isFake
        self.isForwardFake = isForwardFake
        
        if let message = message {
            let isBubbled = renderType == .bubble
            let hasBubble = ChatRowItem.hasBubble(captionMessage ?? message, entry: entry, type: itemType, sharedContext: context.sharedContext)
            self.hasBubble = isBubbled && hasBubble
            let isIncoming: Bool = message.isIncoming(context.account, renderType == .bubble)

            self.isIncoming = isIncoming

            
            if case .bubble = renderType , hasBubble{
                let isFull: Bool
                if case .Full = itemType {
                    switch entry {
                    case let .MessageEntry(message, _, _, _, _, _, _):
                        isFull = chatInteraction.chatLocation.threadMsgId != message.id
                    case let .groupedPhotos(entries, groupInfo: _):
                        isFull = chatInteraction.chatLocation.threadMsgId != entries.first?.message?.id
                    default:
                        isFull = true
                    }
                } else {
                    isFull = false
                }
                let icons = presentation.icons
                let neighbors: MessageBubbleImageNeighbors = isFull && !message.isHasInlineKeyboard ? .none : .both
                bubbleImage = isIncoming ? (neighbors == .none ? icons.chatBubble_none_incoming_withInset : icons.chatBubble_both_incoming_withInset) : (neighbors == .none ? icons.chatBubble_none_outgoing_withInset : icons.chatBubble_both_outgoing_withInset)
                if !isIncoming && theme.colors.bubbleBackground_outgoing.count > 1 {
                    bubbleBorderImage = nil
                } else {
                    bubbleBorderImage = isIncoming ? (neighbors == .none ? icons.chatBubbleBorder_none_incoming_withInset : icons.chatBubbleBorder_both_incoming_withInset) : (neighbors == .none ? icons.chatBubbleBorder_none_outgoing_withInset : icons.chatBubbleBorder_both_outgoing_withInset)
                }
            }
            
            self.itemType = itemType
            self.isRead = isRead
            
            if let info = message.forwardInfo, message.isImported {
                if let author = info.author {
                    self.peer = author
                } else if let signature = info.authorSignature {
                    
                    self.peer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, firstName: signature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                } else {
                    self.peer = message.chatPeer(context.peerId)
                }
            } else if let info = message.forwardInfo, chatInteraction.peerId == context.account.peerId || (object.renderType == .list && info.psaType != nil) {
                if info.author == nil, let signature = info.authorSignature {
                    self.peer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, firstName: signature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                } else if (object.renderType == .list && info.psaType != nil) {
                    self.peer = info.author ?? message.chatPeer(context.peerId)
                } else {
                    self.peer = message.chatPeer(context.peerId)
                }
            } else {
                self.peer = message.chatPeer(context.peerId)
            }
            
            var isHasSource: Bool = false
            
            for attr in message.attributes {
                if let _ = attr as? SourceReferenceMessageAttribute {
                    isHasSource = true
                    break
                }
            }
            
            if let peer = peer, peer.isChannel {
                for attr in message.attributes {
                    if let attr = attr as? AuthorSignatureMessageAttribute {
                        if !message.flags.contains(.Failed) {
                            let attr: NSAttributedString = .initialize(string: attr.signature.prefixWithDots(13), color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .normal(.small) : .normal(.short))
                            postAuthor = TextViewLayout(attr, maximumNumberOfLines: 1)
                            
                            postAuthor?.measure(width: .greatestFiniteMagnitude)
                        }
                        break
                    }
                }
            }
            if let peer = peer, peer.isSupergroup, message.isAnonymousMessage {
                for attr in message.attributes {
                    if let attr = attr as? AuthorSignatureMessageAttribute {
                        if !message.flags.contains(.Failed) {
                            let badge: NSAttributedString = .initialize(string: " " + attr.signature, color: !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.short))
                        
                            adminBadge = TextViewLayout(badge, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                            adminBadge?.mayItems = false
                            adminBadge?.measure(width: .greatestFiniteMagnitude)
                        }
                        break
                    }
                }
            }
            if postAuthor == nil, ChatRowItem.authorIsChannel(message: message, account: context.account) {
                if let author = message.forwardInfo?.authorSignature {
                    let attr: NSAttributedString = .initialize(string: author, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .normal(.small) : .normal(.short))
                    postAuthor = TextViewLayout(attr, maximumNumberOfLines: 1)
                }
            }
            
            
            if let peer = coreMessageMainPeer(message) as? TelegramUser, peer.botInfo != nil || peer.id == context.peerId {
                if !peer.flags.contains(.isSupport) {
                    self.isRead = true
                }
            }
            
            if let info = message.forwardInfo, !message.isImported {
                
                
                var accept:Bool = !isHasSource && message.id.peerId != context.peerId
                
                if let media = message.anyMedia as? TelegramMediaFile {
                    for attr in media.attributes {
                        switch attr {
                        case let .Audio(isVoice, _, _, _, _):
                            if !isVoice, let forwardInfo = message.forwardInfo, let source = forwardInfo.source, source.isChannel {
                                accept = accept && forwardInfo.author?.id == forwardInfo.source?.id
                            } else {
                                accept = accept && isVoice
                            }
                        default:
                            break
                        }
                    }
                }
                if !hasBubble && renderType == .bubble, message.forwardInfo?.psaType != nil {
                    accept = false
                } else if (entry.renderType == .list && message.forwardInfo?.psaType != nil) {
                    accept = false
                }
                
                if accept || (ChatRowItem.authorIsChannel(message: message, account: context.account) && info.author?.id != message.chatPeer(context.peerId)?.id), message.id.peerId != verifyCodePeerId {
                    forwardType = fwdType
                    
                    var attr = NSMutableAttributedString()

                    if ChatRowItem.authorIsChannel(message: message, account: context.account) {
                        if let author = info.author {
                            let range = attr.append(string: author.displayTitle, color: presentation.chat.linkColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                            
                            let appLink = inAppLink.peerInfo(link: "", peerId: author.id, action: nil, openChat: !(author is TelegramUser), postId: info.sourceMessageId?.id, callback: chatInteraction.openInfo)
                            attr.add(link: appLink, for: range, color: presentation.chat.linkColor(isIncoming, object.renderType == .bubble))
                        } else {
                            let color = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                            let range = attr.append(string: info.authorTitle, color: color, font: .normal(.text))
                            attr.add(link: inAppLink.callback("hid", { _ in
                                hiddenFwdTooltip?()
                            }), for: range, color: color)
                        }
                    } else {
                        
                        let color: NSColor
                        if message.forwardInfo?.psaType != nil {
                            color = presentation.chat.greenUI(isIncoming, object.renderType == .bubble)
                        } else {
                            color = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                        }
                        
                        if let source = info.source, source.isChannel {
                            var range = attr.append(string: source.displayTitle, color: color, font: .medium(.text))
                            if info.author?.id != source.id {
                                let subrange = attr.append(string: " (\(info.authorTitle))", color: color, font: .medium(.text))
                                range.length += subrange.length
                            }
                            
                            let link = source.addressName == nil ? "https://t.me/c/\(source.id.id._internalGetInt64Value())/\(info.sourceMessageId?.id != nil ? "\(info.sourceMessageId!.id)" : "")" : "https://t.me/\(source.addressName!)/\(info.sourceMessageId?.id != nil ? "\(info.sourceMessageId!.id)" : "")"
                            let appLink = inApp(for: link.nsstring, context: context, peerId: nil, openInfo: chatInteraction.openInfo)
                            attr.add(link: appLink, for: range, color: color)
                            
                        } else {
                            let range = attr.append(string: info.authorTitle, color: color, font: info.author == nil ? .normal(.text) : .medium(.text))
                            
                            var linkAbility: Bool = true
                            if let channel = info.author as? TelegramChannel {
                                if channel.username == nil && channel.participationStatus != .member {
                                    linkAbility = false
                                }
                            }
                            if linkAbility, let author = info.author {
                                attr.add(link: inAppLink.peerInfo(link: "", peerId: author.id, action:nil, openChat: author.isChannel, postId: info.sourceMessageId?.id, callback:chatInteraction.openInfo), for: range, color: color)
                            } else if info.author == nil {
                                attr.add(link: inAppLink.callback("hid", { _ in
                                    hiddenFwdTooltip?()
                                }), for: range, color: color)
                                
                            }
                        }
                    }
                    
                    
                    var isInstantVideo: Bool {
                        if let media = message.anyMedia as? TelegramMediaFile {
                            if media.isInstantVideo {
                                if let data = object.additionalData.transribeState {
                                    switch data {
                                    case .loading, .revealed:
                                        return false
                                    default:
                                        break
                                    }
                                }
                            }
                            return media.isInstantVideo
                        }
                        return false
                    }
                    
                    let forwardNameColor: NSColor
                    if message.forwardInfo?.psaType != nil {
                        forwardNameColor = theme.chat.greenUI(isIncoming, object.renderType == .bubble)
                    } else if isForwardScam {
                        forwardNameColor = theme.chat.redUI(isIncoming, object.renderType == .bubble)
                    } else if !hasBubble {
                        forwardNameColor = presentation.colors.grayText
                    } else if isIncoming {
                        forwardNameColor = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                    } else {
                        forwardNameColor = presentation.chat.grayText(isIncoming || isInstantVideo, object.renderType == .bubble)
                    }
                    
                    if renderType == .bubble {
                        
                        let text: String
                        let linkString: String
                        if let psaType = message.forwardInfo?.psaType {
                            text = localizedPsa("psa.title.bubbles_new", type: psaType, args: [attr.string])
                            linkString = psaType
                        } else {
                            var fullName = attr.string
                            if let signature = message.forwardInfo?.authorSignature, message.isAnonymousMessage {
                                fullName += " (\(signature))"
                            }
                            if message.forwardInfo?.author != nil {
                                text = strings().chatBubblesForwardedFromWithPhoto(fullName)
                            } else {
                                text = strings().chatBubblesForwardedFromNew(fullName)
                            }
                            linkString = fullName
                        }
                        if !attr.string.isEmpty, let link = attr.attribute(NSAttributedString.Key.link, at: 0, effectiveRange: nil) {
                            let newAttr = NSAttributedString.initialize(string: text, color: forwardNameColor, font: .normal(.short))
                            attr = newAttr.mutableCopy() as! NSMutableAttributedString

                            
                            let range = attr.string.nsstring.range(of: linkString)
                            
                            
                            let hashRange = attr.string.nsstring.range(of: forwardKeyString)
                            if hashRange.location != NSNotFound, hashRange.max < range.min {
                                attr.addAttribute(.foregroundColor, value: NSColor.clear, range: NSMakeRange(hashRange.location + 1, hashRange.length - 1))
                                self.forwardPhotoPlaceRange = NSMakeRange(hashRange.location + 1, hashRange.length - 1)
                            }

                            if range.location != NSNotFound {
                                attr.addAttribute(.link, value: link, range: range)
                                if message.forwardInfo?.author != nil || message.forwardInfo == nil {
                                    attr.addAttribute(.font, value: NSFont.medium(.short), range: range)
                                }
                            }
                        } else {
                            let newAttr = NSAttributedString.initialize(string: text, color: forwardNameColor, font: .normal(.short))
                            attr = newAttr.mutableCopy() as! NSMutableAttributedString
                        }
                        
                    } else {
                        _ = attr.append(string: " ")
                        _ = attr.append(string: DateUtils.string(forLastSeen: info.date), color: renderType == .bubble ? forwardNameColor : presentation.colors.grayText, font: .normal(.short))
                    }

                    
                    forwardNameLayout = TextViewLayout(attr, maximumNumberOfLines: renderType == .bubble ? 2 : 1, truncationType: .end, alwaysStaticItems: true)
                    forwardNameLayout?.interactions = globalLinkExecutor
                }
            }
            
            if !message.isExpiredStory, let story = message.media.first as? TelegramMediaStory, let author = message.peers[story.storyId.peerId] {
                let forwardNameColor: NSColor
                if isForwardScam {
                    forwardNameColor = theme.chat.redUI(isIncoming, object.renderType == .bubble)
                } else if !hasBubble {
                    forwardNameColor = presentation.colors.grayText
                } else if isIncoming {
                    forwardNameColor = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                } else {
                    forwardNameColor = presentation.chat.grayText(isIncoming, object.renderType == .bubble)
                }
                
                var attr: NSMutableAttributedString = NSMutableAttributedString()
                let fullName = author.compactDisplayTitle
                
                let text = strings().chatBubblesForwardedStory(fullName)
                
                let newAttr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.short), textColor: forwardNameColor), link: MarkdownAttributeSet(font: .medium(.short), textColor: forwardNameColor), linkAttribute: { contents in
                    return (NSAttributedString.Key.link.rawValue, inAppLink.peerInfo(link: "", peerId: author.id, action: nil, openChat: false, postId: nil, callback:chatInteraction.openInfo))
                }))
                attr = newAttr.mutableCopy() as! NSMutableAttributedString

                forwardNameLayout = TextViewLayout(attr, maximumNumberOfLines: renderType == .bubble ? 2 : 1, truncationType: .end, alwaysStaticItems: true)
                forwardNameLayout?.interactions = globalLinkExecutor

            }
            
            let fillName: Bool
            var rank: String?
            switch itemType {
            case let .Full(r, header):
                rank = r 
                fillName = header == .normal
            case let .Short(r, header):
                rank = r
                fillName = header == .normal && theme.bubbled
            }
            
            if fillName {
                
                let canFillAuthorName: Bool = ChatRowItem.canFillAuthorName(message, chatInteraction: chatInteraction, renderType: renderType, isIncoming: isIncoming, hasBubble: hasBubble)

                if isForwardScam || canFillAuthorName {
                    self.isForwardScam = false
                }
                
                var titlePeer:Peer? = self.peer
                var title:String = self.peer?.displayTitle ?? ""
                
                
                
                if object.renderType == .list, let _ = message.forwardInfo?.psaType {
                    
                } else if let peer = message.peers[message.id.peerId] as? TelegramChannel, case let .broadcast(info) = peer.info {
                    if info.flags.contains(.messagesShouldHaveProfiles) {
                        titlePeer = message.author ?? self.peer
                        title = titlePeer?.displayTitle ?? ""
                    }
                } else if let peer = coreMessageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info, message.adAttribute == nil {
                    title = peer.displayTitle
                    titlePeer = peer
                }
                
                let attr:NSMutableAttributedString = NSMutableAttributedString()
                
                if let peer = titlePeer {
                    var nameColor:NSColor = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                    
                    if let _nameColor = peer.nameColor {
                        nameColor = context.peerNameColors.get(_nameColor).main
                    }
                    if coreMessageMainPeer(message) is TelegramChannel || coreMessageMainPeer(message) is TelegramGroup {
                        if context.peerId != peer.id {
                            if object.renderType == .bubble, message.isAnonymousMessage, !isIncoming {
                                nameColor = theme.colors.accentIconBubble_outgoing
                            } else if object.renderType == .bubble, message.author?.id != context.peerId, !isIncoming {
                                nameColor = theme.colors.accentIconBubble_outgoing
                            }
                        }
                    }
                    
                    if message.forwardInfo?.psaType != nil, object.renderType == .list {
                        nameColor = theme.colors.greenUI
                    }
                    
                    if message.adAttribute != nil, let author = message.author {
                        nameColor = context.peerNameColors.get(author.nameColor ?? .blue).main
                    }
                    
                    
                    if canFillAuthorName {
                        let range = attr.append(string: title, color: nameColor, font: .medium(.text))
                        if peer.id.id._internalGetInt64Value() != 0 {
                            attr.addAttribute(NSAttributedString.Key.link, value: inAppLink.peerInfo(link: "", peerId:peer.id, action:nil, openChat: peer.isChannel, postId: nil, callback: chatInteraction.openInfo), range: range)
                        } else {
                            nameHide = strings().chatTooltipHiddenForwardName
                        }
                    }
                    
                    
                    if let bot = message.inlinePeer, message.hasInlineAttribute, let address = bot.username {
                        if message.forwardInfo?.psaType == nil, !isBubbled || hasBubble {
                            if attr.length > 0 {
                                _ = attr.append(string: " ")
                            }
                            _ = attr.append(string: "\(strings().chatMessageVia) ", color: !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble), font:.medium(.text))
                            let range = attr.append(string: "@" + address, color: theme.chat.linkColor(isIncoming, hasBubble && isBubbled), font:.medium(.text))
                            attr.addAttribute(NSAttributedString.Key.link, value: inAppLink.callback("@" + address, { (parameter) in
                                chatInteraction.updateInput(with: parameter + " ")
                            }), range: range)
                        }
                    }
                    if canFillAuthorName {
                        var badge: NSAttributedString? = nil
                        if let rank = rank {
                            badge = .initialize(string: " " + rank, color: !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.short))
                            
                        }
                        else if ChatRowItem.authorIsChannel(message: message, account: context.account) {
                            badge = .initialize(string: " " + strings().chatChannelBadge, color: !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.short))
                        }
                        if let badge = badge {
                            adminBadge = TextViewLayout(badge, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                            adminBadge?.mayItems = false
                            adminBadge?.measure(width: .greatestFiniteMagnitude)
                        }
                        
                        var boostBadge: NSMutableAttributedString? = nil
                        if let boostAttribute = message.boostAttribute {
                            boostBadge = NSMutableAttributedString()
                            boostBadge?.append(string: " \(boostAttribute.count)", color: nameColor, font: .normal(.short))
                            boostBadge?.insert(.embedded(name: boostAttribute.count > 1 ? "Icon_Boost_Indicator_Multiple" : "Icon_Boost_Indicator_Single", color: nameColor, resize: false), at: 1)
                        }
                        if let boostBadge = boostBadge {
                            self.boostBadge = TextViewLayout(boostBadge, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                            self.boostBadge?.mayItems = false
                            self.boostBadge?.measure(width: .greatestFiniteMagnitude)
                        }
                    }
                    
                    if attr.length > 0 {
                        authorText = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                        authorText?.mayItems = false
                        authorText?.interactions = globalLinkExecutor
                    }
                }
                
            }
            
            let dateFormatter = DateSelectorUtil.chatDateFormatter
            let dateColor = isStateOverlayLayout ? stateOverlayTextColor : (!hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble))
            
            let dateFont: NSFont = renderType == .bubble ? .normal(.small) : .normal(.short)

            
            if let attribute = message.pendingProcessingAttribute {
                var time:TimeInterval = TimeInterval(attribute.approximateCompletionTime)
                time -= context.timeDifference
                
                let dateText = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(time)))
                
                let attr: NSMutableAttributedString = NSAttributedString.initialize(string: strings().chatVideoProccessingMessageTime(dateText), color: dateColor, font: dateFont).mutableCopy() as! NSMutableAttributedString
                
                self.date = TextViewLayout(attr, maximumNumberOfLines: 1)
                self.date?.measure(width: .greatestFiniteMagnitude)

            } else  if message.timestamp != scheduleWhenOnlineTimestamp && message.adAttribute == nil, chatInteraction.mode.customChatContents == nil {
                var time:TimeInterval = TimeInterval(message.timestamp)
                time -= context.timeDifference
                
                
                let attr: NSMutableAttributedString = NSAttributedString.initialize(string: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(time))), color: dateColor, font: dateFont).mutableCopy() as! NSMutableAttributedString
                
                if let attribute = message.inlineBotAttribute, let peerId = attribute.peerId, let peer = message.peers[peerId] {
                    attr.insert(.initialize(string: "\(attribute.title ?? peer.displayTitle), ", color: dateColor, font: dateFont), at: 0)
                }
                
                self.date = TextViewLayout(attr, maximumNumberOfLines: 1)
                self.date?.measure(width: .greatestFiniteMagnitude)
            } else if let _ = message.adAttribute {
                let text = ""//adAttr.messageType == .recommended ? strings().chatMessageRecommended : strings().chatMessageSponsored
                let attr: NSAttributedString = .initialize(string: text, color: isStateOverlayLayout ? stateOverlayTextColor : (!hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble)), font: renderType == .bubble ? .normal(.small) : .normal(.short))
                self.date = TextViewLayout(attr, maximumNumberOfLines: 1)
                self.date?.measure(width: .greatestFiniteMagnitude)
            }

        } else {
            self.isIncoming = false
            self.hasBubble = false
        }
 
        
        
        super.init(initialSize)
        
        hiddenFwdTooltip = { [weak self] in
            guard let view = self?.view as? ChatRowView, let forwardName = view.forwardName else { return }
            tooltip(for: forwardName, text: strings().chatTooltipHiddenForwardName, autoCorner: false)
        }
        
        let editedAttribute = messages.compactMap({
            return $0.editedAttribute
        }).sorted(by: {
            $0.date < $1.date
        }).first
        
        
        if let message = message {
            
            let formatter = DateSelectorUtil.chatFullDateFormatter
            //
            var fullDate: String = message.timestamp == scheduleWhenOnlineTimestamp ? "" : formatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp) - context.timeDifference))
            
            let threadId: Int64? = chatInteraction.chatLocation.threadId
            
            if let message = effectiveCommentMessage {
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyThreadMessageAttribute, attribute.count > 0 {
                        if let peer = chatInteraction.peer, peer.isSupergroup, !chatInteraction.mode.isThreadMode {
                            let attr: NSAttributedString = .initialize(string: Int(attribute.count).prettyNumber, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .normal(.small) : .normal(.short))
                            self.replyCount = TextViewLayout(attr, maximumNumberOfLines: 1)
                        }
                        break
                    }
                }
            }
            
            if let paidStars = message.paidStarsAttribute, message.id.peerId.namespace != Namespaces.Peer.CloudUser {
                let count: Int
                switch entry {
                case let .groupedPhotos(values, _):
                    count = values.count
                case .MessageEntry:
                    count = 1
                default:
                    count = 0
                }
                let attr: NSAttributedString = .initialize(string: "\(Int64(count) * paidStars.stars.value)", color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .normal(.small) : .normal(.short))
                paidMessage = TextViewLayout(attr, maximumNumberOfLines: 1)
                paidMessage?.measure(width: .greatestFiniteMagnitude)
            }
            
            if editedAttribute != nil || message.id.namespace == Namespaces.Message.Cloud {
                if isEditMarkVisible || isUnsent, message.id.peerId != context.peerId {
                    let attr: NSAttributedString = .initialize(string: strings().chatMessageEdited, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .normal(.small) : .normal(.short))
                    editedLabel = TextViewLayout(attr, maximumNumberOfLines: 1)
                    editedLabel?.measure(width: .greatestFiniteMagnitude)
                }
                
                
                if let attribute = editedAttribute {
                    let formatterEdited = DateSelectorUtil.chatFullDateFormatter
                    fullDate = "\(fullDate) (\(formatterEdited.string(from: Date(timeIntervalSince1970: TimeInterval(attribute.date)))))"
                }
            } else if message.isImported, let forwardInfo = message.forwardInfo  {
                let formatter = DateSelectorUtil.chatImportedFormatter
                let text: String
                if forwardInfo.date == message.timestamp {
                    text = strings().chatMessageImportedShort
                } else {
                   text = strings().chatMessageImported(formatter.string(from: Date(timeIntervalSince1970: TimeInterval(forwardInfo.date))))
                }
                let attr: NSAttributedString = .initialize(string: text, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .normal(.small) : .normal(.short))
                editedLabel = TextViewLayout(attr, maximumNumberOfLines: 1)
                editedLabel?.measure(width: .greatestFiniteMagnitude)
                fullDate = strings().chatMessageImportedText + "\n\n" + fullDate
            } else if let forwardInfo = message.forwardInfo {
                let formatterEdited = DateSelectorUtil.chatFullDateFormatter
                fullDate = "\(fullDate) (\(formatterEdited.string(from: Date(timeIntervalSince1970: TimeInterval(forwardInfo.date)))))"
            }
            let replyPresentation = ChatAccessoryPresentation(background: hasBubble ? theme.chat.backgroundColor(isIncoming, object.renderType == .bubble) : isBubbled ?  theme.colors.grayForeground : theme.colors.background, colors: theme.chat.replyTitle(self), enabledText: theme.chat.replyText(self), disabledText: theme.chat.replyDisabledText(self), quoteIcon: theme.chat.replyQuote(self), pattern: theme.chat.replyPattern(self), app: theme)

            for attribute in message.attributes {
                if let attribute = attribute as? ReplyMessageAttribute, let replyMessage = message.associatedMessages[attribute.messageId] {
                    
                    var ignore: Bool = false
                    if threadId == message.threadId && Int64(attribute.messageId.id) == threadId {
                        ignore = true
                    }
                    
                    if message.media.first is TelegramMediaGiveawayResults {
                        ignore = true
                    }
                    if !ignore {
                        
                        let isQuote = attribute.isQuote
                        
                        if replyMessage.isExpiredStory, let media = replyMessage.media.first as? TelegramMediaStory {
                            self.replyModel = ExpiredStoryReplyModel(message: message, storyId: media.storyId, bubbled: renderType == .bubble, context: context, presentation: replyPresentation)
                        } else {
                            self.replyModel = ReplyModel(message: message, replyMessageId: attribute.messageId, context: context, replyMessage: replyMessage, quote: isQuote ? attribute.quote : nil, autodownload: downloadSettings.isDownloable(replyMessage), presentation: replyPresentation, translate: entry.additionalData.replyTranslate)
                        }
                        replyModel?.isSideAccessory = isBubbled && !hasBubble
                    }
                }
                if let attribute = attribute as? ReplyStoryAttribute {
                    if let story = message.associatedStories[attribute.storyId]?.get(Stories.StoredItem.self) {
                        self.replyModel = StoryReplyModel(message: message, storyId: attribute.storyId, story: story, context: context, presentation: replyPresentation)
                        replyModel?.isSideAccessory = isBubbled && !hasBubble
                    }
                }
                if let attribute = attribute as? QuotedReplyMessageAttribute, self.replyModel == nil {
                    if let attr = message.replyAttribute, message.associatedMessages[attr.messageId] == nil {
                        self.replyModel = ReplyModel(message: message, replyMessageId: message.id, context: context, replyMessage: message, quote: attribute.quote, presentation: replyPresentation, customHeader: attribute.authorName)
                    } else if message.replyAttribute == nil {
                        self.replyModel = ReplyModel(message: message, replyMessageId: message.id, context: context, replyMessage: message, quote: attribute.quote, presentation: replyPresentation, customHeader: attribute.authorName)
                    }
                }
                if let attribute = attribute as? ViewCountMessageAttribute {
                    let attr: NSAttributedString = .initialize(string: max(1, attribute.count).prettyNumber, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .normal(.small) : .normal(.short))
                    
                    self.channelViews = TextViewLayout(attr, maximumNumberOfLines: 1)
                    self.channelViews?.measure(width: .greatestFiniteMagnitude)
                    var author: String = ""
                    loop: for attr in message.attributes {
                        if let attr = attr as? AuthorSignatureMessageAttribute {
                            author = "\(attr.signature), "
                            break loop
                        }
                    }
                    
                    
                    if attribute.count >= 1000 {
                        fullDate = "\(author)\(attribute.count.separatedNumber) \(strings().chatMessageTooltipViews), \(fullDate)"
                    } else {
                        fullDate = "\(author)\(fullDate)"
                    }
                }
               
                if let story = message.media.first as? TelegramMediaStory, message.isExpiredStory {
                    self.replyModel = ExpiredStoryReplyModel(message: message, storyId: story.storyId, bubbled: renderType == .bubble, context: context, presentation: replyPresentation)
                    replyModel?.isSideAccessory = isBubbled && !hasBubble
                } else if let storyReply = message.storyAttribute, message.isExpiredReplyStory {
                    self.replyModel = ExpiredStoryReplyModel(message: message, storyId: storyReply.storyId, bubbled: renderType == .bubble, context: context, presentation: replyPresentation)
                    replyModel?.isSideAccessory = isBubbled && !hasBubble
                }
                
                let paid: Bool
                if let invoice = message.anyMedia as? TelegramMediaInvoice {
                    paid = invoice.receiptMessageId != nil
                } else {
                    paid = false
                }
                if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline) {
                    if message.restrictedText(context.contentSettings) == nil {
                        if !message.hasExtendedMedia {
                            let xtrAmount: Int64?
                            if let invoice = message.anyMedia as? TelegramMediaInvoice, invoice.currency == XTR {
                                xtrAmount = invoice.totalAmount
                            } else {
                                xtrAmount = nil
                            }
                            replyMarkupModel = ReplyMarkupNode(attribute.rows, attribute.flags, chatInteraction.processBotKeyboard(with: message), theme, paid: paid, xtrAmount: xtrAmount)
                        }
                    }
                } else if let attribute = attribute as? SuggestedPostMessageAttribute {
                    if attribute.state == nil, let peer = message.peers[message.id.peerId], isIncoming {
                        //peer.groupAccess.canPostMessages
                        
                        let markupAttribute = attribute.replyMarkup(isIncoming: isIncoming)
                        replyMarkupModel = ReplyMarkupNode(markupAttribute.rows, markupAttribute.flags, chatInteraction.processBotKeyboard(with: message), theme, paid: paid, xtrAmount: nil, isPostSuggest: true)
                    }
                }
            }

            if message.adAttribute == nil, chatInteraction.mode.customChatContents == nil {
                self.fullDate = fullDate
                self.originalFullDate = fullDate
            }
        }
    }
    
    func runTimerIfNeeded() {
        let context = self.chatInteraction.context
        if let attr = message?.autoremoveAttribute, let begin = attr.countdownBeginTime, let fullDate = originalFullDate {
            if self.updateCountDownTimer == nil {
                self.updateCountDownTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                    let left = Int(begin + attr.timeout - context.timestamp)
                    if left >= 0 {
                        let leftText = "\n\n" + strings().chatContextMenuAutoDelete(smartTimeleftText(left))
                        self?.fullDate = fullDate + leftText
                        self?.updateTooltip?(fullDate + leftText)
                    } else {
                        self?.updateCountDownTimer = nil
                    }
                }, queue: .mainQueue())
                self.updateCountDownTimer?.start()
            }
        } else {
            updateCountDownTimer = nil
        }
    }
    func cancelTimer() {
        self.updateCountDownTimer = nil
    }
    
    init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ entry: ChatHistoryEntry, theme: TelegramPresentationTheme) {
        self.entry = entry
        self.context = chatInteraction.context
        self.message = entry.message
        self.chatInteraction = chatInteraction
        self.renderType = entry.renderType
        self.downloadSettings = .defaultSettings
        self.presentation = theme
        self.isIncoming = false
        self.hasBubble = false
        self._isScam = false
        self.isForwardScam = false
        self._isFake = false
        self.isForwardFake = false
        self.wpPresentation = .init(text: .clear, activity: .init(main: .clear), link: .clear, selectText: .clear, ivIcon: theme.icons.ivAudioPlay, renderType: entry.renderType, pattern: nil)
        super.init(initialSize)
    }
    
    public static func item(_ initialSize:NSSize, from entry:ChatHistoryEntry, interaction:ChatInteraction, theme: TelegramPresentationTheme) -> TableRowItem {
        
        switch entry {
        case .UnreadEntry:
            return ChatUnreadRowItem(initialSize, interaction, interaction.context, entry, theme: theme)
        case .groupedPhotos:
            return ChatGroupedItem(initialSize, interaction, interaction.context, entry, theme: theme)
        case .DateEntry:
            return ChatDateStickItem(initialSize, entry, interaction: interaction, theme: theme)
        case let .bottom(theme):
            return GeneralRowItem(initialSize, height: theme.bubbled ? 10 : 20, stableId: entry.stableId, backgroundColor: .clear)
        case let .empty(_, theme):
            return GeneralRowItem(initialSize, height: theme.bubbled ? 10 : 20, stableId: entry.stableId, backgroundColor: .clear, ignoreAtInitialization: true)
        case .commentsHeader:
            return ChatCommentsHeaderItem(initialSize, entry, interaction: interaction, theme: theme)
        case .repliesHeader:
            return RepliesHeaderRowItem(initialSize, entry: entry)
        case let .topThreadInset(height, _, _):
            return GeneralRowItem(initialSize, height: height, stableId: entry.stableId, backgroundColor: .clear)
        case let .userInfo(status, peer, commonGroups, _, _, theme):
            return ChatUserInfoRowItem(initialSize, interaction, entry, settings: status, peer: peer, commonGroups: commonGroups, theme: theme)
        case .topicSeparator:
            return ChatTopicSeparatorItem(initialSize, entry, interaction: interaction, theme: theme)
        default:
            break
        }
        
        if let message = entry.message {
            if message.adAttribute != nil {
                return ChatMessageItem(initialSize, interaction, interaction.context, entry, theme: theme)
            } else if message.media.count == 0 || message.anyMedia is TelegramMediaWebpage {
                return ChatMessageItem(initialSize, interaction, interaction.context, entry, theme: theme)
            } else {
                if message.id.peerId.namespace != Namespaces.Peer.SecretChat, message.autoclearTimeout != nil {
                    if let media = message.media.first, media is TelegramMediaImage || (media.isVideoFile && !media.isInstantVideo) {
                        return ChatServiceItem(initialSize, interaction,interaction.context, entry, theme: theme)
                    }
                }
                if message.media.first is TelegramMediaGiveawayResults {
                    return ChatGiveawayResultRowItem(initialSize, interaction, interaction.context, entry, theme: theme)
                } else if message.media.first is TelegramMediaGiveaway {
                    return ChatGiveawayRowItem(initialSize, interaction, interaction.context, entry, theme: theme)
                }
                if let action = message.media[0] as? TelegramMediaAction {
                   switch action.action {
                   case .giftCode:
                       return ChatGiveawayGiftRowItem(initialSize, interaction, interaction.context, entry, theme: theme)
                   case .prizeStars:
                       return ChatGiveawayGiftRowItem(initialSize, interaction, interaction.context, entry, theme: theme)
                   case .phoneCall:
                       return ChatCallRowItem(initialSize, interaction, interaction.context, entry, theme: theme)
                   case .conferenceCall:
                       return ChatCallRowItem(initialSize, interaction, interaction.context, entry, theme: theme)
//                   case .starGift:
//                       return ChatServiceStarsGiftItem(initialSize, interaction, interaction.context, entry, theme: theme)
                   default:
                       return ChatServiceItem(initialSize, interaction, interaction.context, entry, theme: theme)
                   }
               } else if let file = message.media[0] as? TelegramMediaFile {
                    if file.isVideoSticker {
                        return ChatGIFMediaItem(initialSize, interaction, interaction.context,entry, theme: theme)
                    } else if file.isInstantVideo {
                        if let data = entry.additionalData.transribeState {
                            switch data {
                            case .loading, .revealed:
                                return ChatVoiceRowItem(initialSize,interaction, interaction.context,entry, theme: theme)
                            default:
                                break
                            }
                        }
                        return ChatVideoMessageItem(initialSize, interaction, interaction.context,entry, theme: theme)
                    } else if file.isVideo && !file.isAnimated {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, theme: theme)
                    } else if file.isStaticSticker {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, theme: theme)
                    } else if file.isVoice {
                        return ChatVoiceRowItem(initialSize,interaction, interaction.context, entry, theme: theme)
                    } else if file.isVideo && file.isAnimated {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, theme: theme)
                    } else if !file.isVideo && (file.isAnimated && !file.mimeType.hasSuffix("gif")) {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, theme: theme)
                    } else if file.isMusic {
                        return ChatMusicRowItem(initialSize,interaction, interaction.context, entry, theme: theme)
                    } else if file.isAnimatedSticker {
                        return ChatAnimatedStickerItem(initialSize,interaction, interaction.context, entry, theme: theme)
                    }
                    return ChatFileMediaItem(initialSize,interaction, interaction.context, entry, theme: theme)
                } else if let story = message.media[0] as? TelegramMediaStory {
                    if message.isExpiredStory && !story.isMention {
                        return ChatRowItem(initialSize, interaction, interaction.context, entry, theme: theme)
                    } else {
                        if story.isMention {
                            return ChatServiceItem(initialSize, interaction,interaction.context, entry, theme: theme)
                        } else {
                            return ChatMediaItem(initialSize, interaction, interaction.context, entry, theme: theme)
                        }
                    }
                } else if message.media[0] is TelegramMediaMap {
                    return ChatMapRowItem(initialSize,interaction, interaction.context, entry, theme: theme)
                } else if message.media[0] is TelegramMediaContact {
                    return ChatContactRowItem(initialSize, interaction, interaction.context, entry, theme: theme)
                } else if let media = message.media[0] as? TelegramMediaInvoice {
                    if let extendedMedia = media.extendedMedia {
                        switch extendedMedia {
                        case .preview:
                            return ChatInvoiceItem(initialSize, interaction, interaction.context, entry, theme: theme)
                        case .full:
                            return ChatMediaItem(initialSize, interaction, interaction.context, entry, theme: theme)
                        }
                    } else {
                        return ChatInvoiceItem(initialSize, interaction, interaction.context, entry, theme: theme)
                    }
                } else if message.media[0] is TelegramMediaExpiredContent {
                    return ChatServiceItem(initialSize, interaction,interaction.context, entry, theme: theme)
                } else if message.anyMedia is TelegramMediaGame {
                    return ChatMessageItem(initialSize, interaction, interaction.context, entry, theme: theme)
                } else if message.anyMedia is TelegramMediaPoll {
                    return ChatPollItem(initialSize, interaction, interaction.context, entry, theme: theme)
                } else if message.anyMedia is TelegramMediaTodo {
                    return ChatRowTodoItem(initialSize, interaction, interaction.context, entry, theme: theme)
                } else if message.anyMedia is TelegramMediaUnsupported {
                    return ChatMessageItem(initialSize, interaction, interaction.context,entry, theme: theme)
                } else if message.anyMedia is TelegramMediaDice {
                    return ChatMediaDice(initialSize, interaction, interaction.context, entry, theme: theme)
                } else if message.anyMedia is TelegramMediaPaidContent {
                    return ChatMediaPaidContentItem(initialSize, interaction, interaction.context, entry, theme: theme)
                }
                
                return ChatMediaItem(initialSize, interaction, interaction.context, entry, theme: theme)
            }
            
        }
        
        fatalError("no item for entry")
        
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
                
        let result = super.makeSize(width, oldWidth: oldWidth)
        isForceRightLine = false
                
        commentsBubbleData?.makeSize()
        commentsBubbleDataOverlay?.makeSize()
        
        _commentsBubbleData?.drawBorder = !isBubbleFullFilled || !captionLayouts.isEmpty
        
       
        
//        if !(self is ChatGroupedItem) {
//            for layout in captionLayouts {
//                layout.layout.dropLayoutSize()
//            }
//        }
        
        channelViews?.measure(width: hasBubble ? 60 : max(150,width - contentOffset.x - 44 - 150))
        replyCount?.measure(width: hasBubble ? 60 : max(150,width - contentOffset.x - 44 - 150))
       
       
        self.rightFrames = ChatRightView.Frames(self, size: NSMakeSize(.greatestFiniteMagnitude, rightHeight))
        
        var widthForContent: CGFloat = blockWidth
        if previousBlockWidth != widthForContent {
            self.previousBlockWidth = widthForContent
            _contentSize = self.makeContentSize(widthForContent)
        }
        
       
        
        
        var maxContentWidth = _contentSize.width
        if hasBubble {
            maxContentWidth -= bubbleDefaultInnerInset
        }
        
        if isBubbled && isBubbleFullFilled {
            widthForContent = maxContentWidth
        } else if fixedContentSize {
            widthForContent = maxContentWidth
        }
        
        if let factCheckLayout {
            if isBubbled {
                if isBubbleFullFilled {
                    factCheckLayout.measure(for: widthForContent + defaultContentInnerInset)
                } else {
                    if let webpageLayout = (self as? ChatMessageItem)?.webpageLayout {
                        factCheckLayout.measure(for: webpageLayout.size.width)
                    } else {
                        factCheckLayout.measure(for: max(_contentSize.width, 220))
                    }
                }
            } else {
                factCheckLayout.measure(for: max(_contentSize.width, widthForContent - rightSize.width))
            }
        }
        
        if let reactions = reactionsLayout {
            if isBubbled {
                if !hasBubble {
                    reactions.measure(for: min(320, blockWidth))
                } else if reactions.presentation.isOutOfBounds {
                    reactions.measure(for: _contentSize.width + 40)
                } else {
                    var w = widthForContent
                    if let item = self as? ChatMessageItem {
                        if item.webpageLayout != nil {
                            w = _contentSize.width
                        }
                    } else if let _ = self as? ChatGiveawayRowItem {
                        w = _contentSize.width
                    }
                    reactions.measure(for: w)
                }
            } else {
                reactions.measure(for: max(_contentSize.width, widthForContent - rightSize.width))
            }
        }
    
        
        if !(self is ChatGroupedItem) {
            for layout in captionLayouts {
                layout.layout.measure(width: maxContentWidth - defaultContentInnerInset)
            }
        }
        
        for layout in captionLayouts {
            if layout.isLoading {
                layout.layout.makeImageBlock(backgroundColor: .blackTransparent)
            }
        }
        
        if let forwardNameLayout = forwardNameLayout {
            var w = widthForContent
            if isBubbled && !hasBubble {
                w = width - _contentSize.width - 85 - (monoforumState == .vertical ? 80 : 0)
            }
            forwardNameLayout.measure(width: min(w, 250))
        }
        
        if (forwardType == .FullHeader || forwardType == .ShortHeader) && (entry.renderType == .bubble || message?.forwardInfo?.psaType == nil), renderType == .list {
            
            let color: NSColor
            let text: String
            if let psaType = message?.forwardInfo?.psaType {
                color = presentation.chat.greenUI(isIncoming, isBubbled)
                text = localizedPsa("psa.title", type: psaType)
            } else {
                color = !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble)
                text = strings().messagesForwardHeader
            }
            
            forwardHeader = .init(.initialize(string: text, color: color, font: .normal(.text)), maximumNumberOfLines: 1)
            forwardHeader?.measure(width: .greatestFiniteMagnitude)
        } else {
            forwardHeader = nil
        }
        
        
        
        if let value = topicLinkLayout {
            if !isBubbled {
                value.measure(widthForContent)
            } else  {
                if let item = self as? ChatMessageItem, item.webpageLayout == nil && !value.isSideAccessory {
                    if isBubbled {
                        value.measure(max(blockWidth, 200))
                    } else {
                        value.measure(max(contentSize.width, 200))
                    }
                } else {
                    if !hasBubble {
                        value.measure(min(width - _contentSize.width - contentOffset.x - 80, 300))
                    } else {
                        value.measure(_contentSize.width - bubbleDefaultInnerInset)
                    }
                }
            }
        }
        
        
        if !canFillAuthorName, let replyModel = replyModel, let authorText = authorText, replyModel.isSideAccessory {
            var adminWidth: CGFloat = 0
            if let adminBadge = adminBadge {
                adminWidth += adminBadge.layoutSize.width
            }
            if let boostBadge = boostBadge {
                adminWidth += boostBadge.layoutSize.width
            }
            authorText.measure(width: replyModel.size.width - 10 - adminWidth)
            
            replyModel.topOffset = authorText.layoutSize.height + 6
            replyModel.measureSize(replyModel.width, sizeToFit: replyModel.sizeToFit)
        } else {
            var adminWidth: CGFloat = 0
            if let adminBadge = adminBadge {
                adminWidth += adminBadge.layoutSize.width
            }
            if let boostBadge = boostBadge {
                adminWidth += boostBadge.layoutSize.width
            }
            var supplyOffset: CGFloat = 0
            if !isBubbled {
                supplyOffset += rightSize.width
            }
            
            authorText?.measure(width: widthForContent - adminWidth - supplyOffset)
            
        }
        
         if hasBubble && !isBubbleFullFilled {
            if _contentSize.width < rightSize.width {
                if !(self is ChatMessageItem)  {
                    _contentSize.width = rightSize.width
                } else if additionalLineForDateInBubbleState != nil {
                    _contentSize.width = rightSize.width
                }
            }
        }
        

        if !isBubbled {
            if let replyModel = replyModel {
                replyModel.measureSize(widthForContent, sizeToFit: true)
                if replyModel.size.width < _contentSize.width {
                    replyModel.measureSize(_contentSize.width, sizeToFit: false)
                }
            }
        } else if let replyModel = replyModel {
            if !replyModel.isSideAccessory {
                replyModel.measureSize(max(blockWidth - bubbleDefaultInnerInset, 200), sizeToFit: true)
                let fill_size = max_reply_size_width
                if replyModel.size.width < fill_size || isBubbleFullFilled {
                    replyModel.measureSize(fill_size, sizeToFit: false)
                }
            } else {
                if _contentSize.width == 0 {
                    replyModel.measureSize(200, sizeToFit: true)
                } else {
                    replyModel.measureSize(_contentSize.width - bubbleContentInset * 2, sizeToFit: true)
                }
            }
        }
        
        if isBubbled {
            replyMarkupModel?.measureSize(bubbleFrame.width - additionBubbleInset)
        } else {
            if let item = self as? ChatMessageItem {
                if item.webpageLayout != nil {
                    replyMarkupModel?.measureSize(_contentSize.width)
                } else if _contentSize.width < 200 {
                    replyMarkupModel?.measureSize(max(_contentSize.width, min(blockWidth, 320)))
                } else {
                    replyMarkupModel?.measureSize(_contentSize.width)
                }
            } else {
                 replyMarkupModel?.measureSize(_contentSize.width)
            }
        }
        
        
        return result
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    var bubbleContentInset: CGFloat {
        return 11
    }
    
    var additionBubbleInset: CGFloat {
        return 6
    }
    
    var insetBetweenContentAndDate: CGFloat {
        return 10
    }
    
    var bubbleCornerInset: CGFloat {
        if isIncoming {
            if let message = message, let peer = message.peers[message.id.peerId] {
                if peer.isGroup || peer.isSupergroup {
                    return additionBubbleInset + 36
                }
            }
        }
        return additionBubbleInset
    }
    
    var maxTitleWidth: CGFloat {
        let nameWidth:CGFloat
        if hasBubble {
            nameWidth = (authorText?.layoutSize.width ?? 0) + statusSize + (adminBadge?.layoutSize.width ?? 0) + (boostBadge?.layoutSize.width ?? 0)
        } else {
            nameWidth = 0
        }

        let forwardWidth = hasBubble ? (forwardNameLayout?.layoutSize.width ?? 0) + forwardStatusSize + (isPsa ? 30 : 0) : 0
        
        let replyWidth = min(hasBubble ? (replyModel?.size.width ?? 0) : 0, 200)
        
        let topicReplyWidth = min(hasBubble ? (topicLinkLayout?.size.width ?? 0) : 0, 200)

        return max(nameWidth, forwardWidth, replyWidth, topicReplyWidth)//min(max(max(nameWidth, forwardWidth), replyWidth), contentSize.width)
    }
    
    var hasStatus: Bool {
        if let peer = self.peer, let message = self.message, PremiumStatusControl.hasControl(peer, left: false) {
            if authorText != nil, let peer = message.peers[message.id.peerId] {
                if peer.isGroup || peer.isSupergroup || peer.isGigagroup {
                    return true
                }
            }
        }
        return false
    }
    
    var statusSize: CGFloat {
        if let peer = self.peer, hasStatus, let controlSize = PremiumStatusControl.controlSize(peer, false, left: false) {
            return controlSize.width
        }
        return 0
    }
    var forwardStatusSize: CGFloat {
        if let peer = self.peer, false, let controlSize = PremiumStatusControl.controlSize(peer, false, left: false) {
            return controlSize.width
        }
        return 0
    }
    
    func status(_ cached: PremiumStatusControl?, animated: Bool) -> PremiumStatusControl? {
        if let peer = peer, let attr = authorText?.attributedString, !attr.string.isEmpty, hasStatus {
            if let color = attr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor {
                return PremiumStatusControl.control(peer, account: context.account, inlinePacksContext: context.inlinePacksContext, left: false, isSelected: false, color: color, cached: cached, animated: animated)
            }
        }
        return nil
    }
    
    var bubbleFrame: NSRect {
        

        let nameWidth:CGFloat
        if hasBubble {
            nameWidth = (authorText?.layoutSize.width ?? 0) + statusSize + (adminBadge?.layoutSize.width ?? 0) + (boostBadge?.layoutSize.width ?? 0)
        } else {
            nameWidth = 0
        }
        
        let forwardWidth = hasBubble ? (forwardNameLayout?.layoutSize.width ?? 0) + forwardStatusSize + (isPsa ? 30 : 0) : 0
        let replyWidth: CGFloat = hasBubble ? (replyModel?.size.width ?? 0) : 0
        let topicLinkWidth: CGFloat = hasBubble ? (topicLinkLayout?.size.width ?? 0) : 0

        var rect = NSMakeRect(defLeftInset, 2, contentSize.width, height - 4)
        
        if isBubbled, let replyMarkup = replyMarkupModel {
            rect.size.height -= (replyMarkup.size.height + defaultReplyMarkupInset)
            
//            if self is ChatMessageItem {
//                rect.size.height += 2
//            }
        }

        
        if let reactions = self.reactionsLayout {
            if reactions.presentation.isOutOfBounds {
                rect.size.height -= defaultReactionsInset
                rect.size.height -= reactions.size.height
            }
        }
        
        if additionalLineForDateInBubbleState == nil && rightSize.width > 0 {
            if let lastLine = lastLineContentWidth {
                if lastLine.single {
                    rect.size.width = max(rect.size.width, lastLine.width)
                    if rect.size.width + rightSize.width < blockWidth {
                        let effective = lastLine.width + rightSize.width
                        if effective > contentSize.width {
                            rect.size.width += rightSize.width + insetBetweenContentAndDate + bubbleContentInset * 2
                        } else {
                            rect.size.width += bubbleDefaultInnerInset
                        }
                    } else {
                        let effective = lastLine.width + rightSize.width + insetBetweenContentAndDate
                        let add = effective - rect.size.width
                        if add > 0 {
                            rect.size.width += add
                        }
                        rect.size.width += bubbleDefaultInnerInset
                    }
                } else {
                    rect.size.width += bubbleDefaultInnerInset
                }
            } else {
                rect.size.width += bubbleDefaultInnerInset
            }
        } else {
            rect.size.width += bubbleDefaultInnerInset
        }
        
        
        rect.size.width = max(nameWidth + bubbleDefaultInnerInset, rect.width)
        
        rect.size.width = max(rect.width, replyWidth + bubbleDefaultInnerInset)
        
        rect.size.width = max(rect.width, forwardWidth + bubbleDefaultInnerInset)
        
        rect.size.width = max(rect.width, topicLinkWidth + bubbleDefaultInnerInset)

        if let reactions = reactionsLayout, !reactions.presentation.isOutOfBounds {
            rect.size.width = max(reactions.size.width + bubbleDefaultInnerInset, rect.width)
        }
        
        if let factCheckLayout = factCheckLayout {
            rect.size.width = max(factCheckLayout.size.width + bubbleDefaultInnerInset, rect.width)
        }
        
        if let commentsBubbleData = commentsBubbleData {
            rect.size.width = max(rect.size.width, commentsBubbleData.size(hasBubble, false).width + (isBubbled ? 0 : 10))
        }
        
        return rect
    }
    
    
    var unsupported: Bool {
        if let message = message, message.text.isEmpty && (message.media.isEmpty || message.anyMedia is TelegramMediaUnsupported) {
            return message.inlinePeer == nil
        } else {
            return false
        }
    }
    
    var isBigEmoji: Bool {
        return false
    }
    
    var additionalLineForDateInBubbleState: CGFloat? {

        if unsupported {
            return rightSize.height
        }
        if isBigEmoji {
            return rightSize.height
        }
        if message?.isExpiredStory == true {
             return rightSize.height / 2
        }
  
        if let lastLine = lastLineContentWidth {
            if lastLine.single && !isBubbleFullFilled {
                if contentOffset.x + lastLine.width + (rightSize.width + insetBetweenContentAndDate) > blockWidth {
                    return rightSize.height
                } else {
                    return nil
                }
            } else {
                if max(realContentSize.width, maxTitleWidth) < lastLine.width + (rightSize.width + insetBetweenContentAndDate) {
                    return rightSize.height
                } else {
                    return nil
                }
            }
        }
        return isForceRightLine ? rightSize.height : nil
    }
    
    func deleteMessage() {
        _ = context.account.postbox.transaction { [weak message] transaction -> Void in
            if let message = message {
                if let _ = message.groupingKey {
                    let messages = transaction.getMessageGroup(message.id)
                    if let messages = messages {
                        transaction.deleteMessages(messages.map { $0.id }, forEachMedia: { media in
                            
                        })
                    }
                } else {
                    transaction.deleteMessages([message.id], forEachMedia: { media in
                        
                    })
                }
                
            }
        }.start()
    }
    
    func openTopic() {
        if let message = message, let threadId = message.threadId {
            let isLog = chatInteraction.isLogInteraction
            _ = ForumUI.openTopic(threadId, peerId: chatInteraction.peerId, context: context, messageId: isLog ? nil : message.id, animated: true, addition: true).start()
        }
    }
    
    func openForwardInfo() {
        if let author = message?.forwardInfo?.author {
            chatInteraction.openInfo(author.id, false, nil, nil)
        }
    }
    
    func openInfo() {
        switch chatInteraction.chatLocation {
        case .peer, .thread:
            if let peer = peer {
                let messageId: MessageId?
                if chatInteraction.isGlobalSearchMessage {
                    messageId = self.message?.id
                } else if case .searchHashtag = chatInteraction.mode.customChatContents?.kind {
                    messageId = self.message?.id
                } else {
                    messageId = nil
                }
                if let message = message {
                    context.engine.messages.ensureMessagesAreLocallyAvailable(messages: [.init(message)])
                }
                if peer.id == self.message?.id.peerId, messageId == nil {
                    chatInteraction.openInfo(peer.id, false, nil, nil)
                } else {
                    chatInteraction.openInfo(peer.id, !(peer is TelegramUser) || messageId != nil, messageId, nil)
                }
            }
        }
        
    }
    
    func toggleSelect() {
        if let message = self.message {
            chatInteraction.withToggledSelectedMessage({ current in
                return current.withToggledSelectedMessage(message.id)
            })
        }
       
    }
    
    func resendMessage(_ ids: [MessageId]) {
       _ = resendMessages(account: context.account, messageIds: ids).start()
    }
    func resendFailed(_ messageId: MessageId) {
        let signal = chatInteraction.context.account.postbox.transaction { transaction -> [MessageId] in
            return transaction.getMessageFailedGroup(messageId)?.compactMap({$0.id}) ?? []
        } |> deliverOnMainQueue

        
        _ = signal.start(next: { [weak self] ids in
            guard let context = self?.chatInteraction.context else {
                return
            }
            if !ids.isEmpty {
                
                verifyAlert_button(for: context.window, header: strings().alertSendErrorHeader, information: strings().alertSendErrorText, ok: strings().alertSendErrorResend, option: strings().alertSendErrorDelete, successHandler: { result in
                    switch result {
                    case .basic:
                        self?.resendMessage([messageId])
                    case .thrid:
                        if ids.count > 1 {
                            self?.resendMessage(ids)
                        } else {
                            self?.deleteMessage()
                        }
                    }
                })
                
//                let alert:NSAlert = NSAlert()
//                alert.window.appearance = theme.appearance
//                alert.alertStyle = .informational
//                alert.messageText = strings().alertSendErrorHeader
//                alert.informativeText = strings().alertSendErrorText
//                
//                
//                alert.addButton(withTitle: strings().alertSendErrorResend)
//                
//                if ids.count > 1 {
//                    alert.addButton(withTitle: strings().alertSendErrorResendItemsCountable(ids.count))
//                }
//                
//                alert.addButton(withTitle: strings().alertSendErrorDelete)
//                
//                alert.addButton(withTitle: strings().alertSendErrorIgnore)
//                
//                
//                alert.beginSheetModal(for: context.window, completionHandler: { response in
//                    switch response.rawValue {
//                    case 1000:
//                        self?.resendMessage([messageId])
//                    case 1001:
//                        if ids.count > 1 {
//                            self?.resendMessage(ids)
//                        } else {
//                            self?.deleteMessage()
//                        }
//                    case 1002:
//                        if ids.count > 1 {
//                            self?.deleteMessage()
//                        }
//                    default:
//                        break
//                    }
//                })
            }
        })
    }
    
    func makeContentSize(_ width:CGFloat) -> NSSize {
        
        return NSZeroSize
    }
    
    override func viewClass() -> AnyClass {
        return ChatRowView.self
    }
    
    func boost() {
        if let peerId = self.message?.id.peerId {
            let context = self.context
            
            let signal: Signal<(Peer, ChannelBoostStatus?, MyBoostStatus?)?, NoError> = context.account.postbox.loadedPeerWithId(peerId) |> mapToSignal { value in
                return combineLatest(context.engine.peers.getChannelBoostStatus(peerId: value.id), context.engine.peers.getMyBoostStatus()) |> map {
                    (value, $0, $1)
                }
            }
            _ = showModalProgress(signal: signal, for: context.window).start(next: { value in
                if let value = value, let boosts = value.1 {
                    showModal(with: BoostChannelModalController(context: context, peer: value.0, boosts: boosts, myStatus: value.2), for: context.window)
                } else {
                    alert(for: context.window, info: strings().unknownError)
                }
            })
        }
    }
    
    func replyAction() -> Bool {
        if chatInteraction.presentation.canReplyInRestrictedMode, chatInteraction.chatLocation.threadMsgId != effectiveCommentMessage?.id, let message = message {
            chatInteraction.setupReplyMessage(message, .init(messageId: message.id, quote: nil, todoItemId: nil))
            return true
        }
        return false
    }
    func editAction() -> Bool {
         if chatInteraction.presentation.state == .normal || chatInteraction.presentation.state == .editing, chatInteraction.chatLocation.threadMsgId != effectiveCommentMessage?.id {
            if let message = message, canEditMessage(message, chatInteraction: chatInteraction, context: context) {
                chatInteraction.beginEditingMessage(message)
                return true
            }
        }
        return false
    }
    func forwardAction() -> Bool {
        if chatInteraction.presentation.state != .selecting, let message = message {
            if canForwardMessage(message, chatInteraction: chatInteraction) {
                chatInteraction.forwardMessages([message])
                return true
            }
        }
        return false
    }
    
    func reactAction() -> Bool {
        if canReact {
            
            
            
            let context = self.context
            let value = context.reactionSettings.quickReaction
            let message = self.message
            
            guard let message = message else {
                return false
            }
            
            var reaction: MessageReaction.Reaction?
            
            let messageId = message.id
            let builtin = self.entry.additionalData.reactions
            let allowed = chatInteraction.presentation.allowedReactions
            if let allowed = allowed {
                switch allowed {
                case .all:
                    switch value {
                    case .builtin:
                        reaction = value
                    case .custom:
                        reaction = context.isPremium ? value : builtin?.enabled.first?.value
                    case .stars:
                        break
                    }
                case let .limited(array):
                    if array.contains(value) {
                        reaction = value
                    } else {
                        reaction = builtin?.enabled.first(where: {
                            array.contains($0.value)
                        })?.value
                    }
                case .empty:
                    break
                }
            } else {
                switch value {
                case .custom:
                    reaction = context.isPremium ? value : builtin?.enabled.first?.value
                case .builtin:
                    reaction = value
                case .stars:
                    break
                }
            }
            if let reaction = reaction {
                if context.isFrozen {
                    context.freezeAlert()
                } else {
                    context.reactions.react(messageId, values: message.newReactions(with: reaction.toUpdate(), isTags: context.peerId == message.id.peerId))
                }
            }
        }
        return false
    }
    
    override var menuAdditionView: Signal<Window?, NoError> {
        if canReact {
            
            let context = self.context
            
            guard let message = self.message, let peer = chatInteraction.presentation.mainPeer else {
                return .single(nil)
            }
            let peerId = self.chatInteraction.peerId
            
            let builtin = context.reactions.stateValue
            let peerAllowed: Signal<PeerAllowedReactions?, NoError> = getCachedDataView(peerId: peerId, postbox: context.account.postbox)
            |> map { cachedData in
                if let cachedData = cachedData as? CachedGroupData {
                    return cachedData.reactionSettings.knownValue?.allowedReactions
                } else if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.reactionSettings.knownValue?.allowedReactions
                } else {
                    return nil
                }
            }
            |> take(1)
            
            let starsAllowed: Signal<Bool?, NoError> = getCachedDataView(peerId: peerId, postbox: context.account.postbox)
            |> map { cachedData in
                if let cachedData = cachedData as? CachedGroupData {
                    return cachedData.reactionSettings.knownValue?.starsAllowed
                } else if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.reactionSettings.knownValue?.starsAllowed
                } else {
                    return nil
                }
            }
            |> take(1)
            
            let maximumReactionsLimit: Signal<Int32?, NoError> = getCachedDataView(peerId: peerId, postbox: context.account.postbox)
            |> map { cachedData in
                if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.reactionSettings.knownValue?.maxReactionCount
                } else {
                    return nil
                }
            }
            |> take(1)

            
            let isTags = context.peerId == peerId

            
            
            let reactions:Signal<[RecentReactionItem], NoError> = context.diceCache.top_reactions |> map { view in
                
                var recentReactionsView: OrderedItemListView?
                var topReactionsView: OrderedItemListView?
                var defaultTagReactions: OrderedItemListView?
                for orderedView in view.orderedItemListsViews {
                    if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentReactions {
                        recentReactionsView = orderedView
                    } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudTopReactions {
                        topReactionsView = orderedView
                    } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudDefaultTagReactions {
                        defaultTagReactions = orderedView
                    }
                }
                var recentReactionsItems:[RecentReactionItem] = []
                var topReactionsItems:[RecentReactionItem] = []
                var defaultTagReactionsItems:[RecentReactionItem] = []

                if let recentReactionsView = recentReactionsView {
                    for item in recentReactionsView.items {
                        guard let item = item.contents.get(RecentReactionItem.self) else {
                            continue
                        }
                        recentReactionsItems.append(item)
                    }
                }
                if let defaultTagReactions = defaultTagReactions {
                    for item in defaultTagReactions.items {
                        guard let item = item.contents.get(RecentReactionItem.self) else {
                            continue
                        }
                        defaultTagReactionsItems.append(item)
                    }
                }
                if let topReactionsView = topReactionsView {
                    for item in topReactionsView.items {
                        guard let item = item.contents.get(RecentReactionItem.self) else {
                            continue
                        }
                        topReactionsItems.append(item)
                    }
                }
                if !defaultTagReactionsItems.isEmpty, isTags {
                    return defaultTagReactionsItems
                }
                return topReactionsItems.filter { value in
                    if context.isPremium {
                        return true
                    } else {
                        if case .custom = value.content {
                            return false
                        } else {
                            return true
                        }
                    }
                }
            }
            
            
            let signal = combineLatest(queue: .mainQueue(), builtin, peerAllowed, reactions, maximumReactionsLimit, starsAllowed)
            |> take(1)

            return signal |> map { builtin, peerAllowed, reactions, maximumReactionsLimit, starsAllowed in
                let enabled = builtin?.enabled ?? []

                var available:[ContextReaction] = []
                
                let allowed = peerAllowed
                
                var accessToAll: Bool
                
                let isSelected:(MessageReaction.Reaction)->Bool = { reaction in
                    return message.effectiveReactions(isTags: isTags)?.contains(where: { $0.value == reaction && $0.isSelected }) ?? false
                }

                if isTags {
                    accessToAll = true
                } else if peer.isChannel {
                   accessToAll = false
                } else if let peerAllowed = peerAllowed {
                    switch peerAllowed {
                    case .all:
                        accessToAll = true
                    case .limited, .empty:
                        accessToAll = false
                    }
                } else {
                    accessToAll = true
                }
                
                if !accessToAll {
                    if let reactions = builtin {
                        if let allowed = allowed {
                            switch allowed {
                            case .all:
                                available = reactions.enabled.map {
                                    .builtin(value: $0.value, staticFile: $0.staticIcon._parse(), selectFile: $0.selectAnimation._parse(), appearFile: $0.appearAnimation._parse(), isSelected: isSelected($0.value))
                                }
                            case let .limited(array):
                                available = array.compactMap { reaction in
                                    switch reaction {
                                    case .builtin:
                                        if let first = reactions.enabled.first(where: { $0.value == reaction }) {
                                            return .builtin(value: first.value, staticFile: first.staticIcon._parse(), selectFile: first.selectAnimation._parse(), appearFile: first.appearAnimation._parse(), isSelected: isSelected(reaction))
                                        } else {
                                            return nil
                                        }
                                    case let .custom(fileId):
                                        return .custom(value: reaction, fileId: fileId, nil, isSelected: isSelected(reaction))
                                    case .stars:
                                        return nil
                                    }
                                }
                            case .empty:
                                available = []
                            }
                        } else {
                            available = []
                        }
                    }
                } else {
                    available = reactions.compactMap { value in
                        switch value.content {
                        case let .builtin(emoji):
                            if let generic = enabled.first(where: { $0.value.string == emoji }) {
                                return .builtin(value: generic.value, staticFile: generic.staticIcon._parse(), selectFile: generic.selectAnimation._parse(), appearFile: generic.appearAnimation._parse(), isSelected: isSelected(generic.value))
                            } else {
                                return nil
                            }
                        case let .custom(file):
                            return .custom(value: .custom(file._parse().fileId.id), fileId: file._parse().fileId.id, file._parse(), isSelected: isSelected(.custom(file._parse().fileId.id)))
                        case .stars:
                            return nil
                        }
                    }
                }
                
                var uniqueLimit: Int = .max
                
                if let maximumReactionsLimit = maximumReactionsLimit {
                    uniqueLimit = Int(maximumReactionsLimit)
                } else if let value = context.appConfiguration.data?["reactions_uniq_max"] as? Double {
                    uniqueLimit = Int(value)
                }
                
                            
                if let reactions = message.effectiveReactions(isTags: isTags), reactions.count >= uniqueLimit {
                    available = reactions.compactMap { reaction in
                        switch reaction.value {
                        case let .custom(fileId):
                            if !accessToAll {
                                let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                return .custom(value: reaction.value, fileId: fileId, message.associatedMedia[mediaId] as? TelegramMediaFile, isSelected: isSelected(reaction.value))
                            } else {
                                return nil
                            }
                        case .builtin:
                            if let generic = enabled.first(where: { $0.value == reaction.value }) {
                                return .builtin(value: generic.value, staticFile: generic.staticIcon._parse(), selectFile: generic.selectAnimation._parse(), appearFile: generic.appearAnimation._parse(), isSelected: isSelected(reaction.value))
                            } else {
                                return nil
                            }
                        case .stars:
                            return nil
                        }
                    }
                    accessToAll = false
                }
                
                if let starsAllowed, starsAllowed {
                    available.insert(.stars(file: LocalAnimatedSticker.premium_reaction_6.file, isSelected: isSelected(.stars)), at: 0)
                }
                
                guard !available.isEmpty else {
                    return nil
                }
                
                
                if accessToAll {
                    available = Array(available.prefix(7))
                }
                
                if isTags, !context.isPremium {
                   accessToAll = false
                }
                
                
                let width = ContextAddReactionsListView.width(for: available.count, maxCount: 7, allowToAll: accessToAll)
                let aboveText: String?
                if isTags {
                    if context.isPremium {
                        aboveText = strings().chatReactionsTagMessage
                    } else {
                        aboveText = strings().chatReactionsTagMessagePremium
                    }
                } else {
                    aboveText = nil
                }
                
                let w_width = width + 20 + (accessToAll ? 0 : 0)
                
                let aboveLayout: TextViewLayout?
                if let aboveText = aboveText {
                    let color = theme.colors.darkGrayText.withAlphaComponent(0.8)
                    let link = theme.colors.link.withAlphaComponent(0.8)
                    let attributed = parseMarkdownIntoAttributedString(aboveText, attributes: .init(body: .init(font: .normal(.text), textColor: color), bold: .init(font: .medium(.text), textColor: color), link: .init(font: .normal(.text), textColor: link), linkAttribute: { link in
                        return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                            prem(with: PremiumBoardingController(context: context, source: .saved_tags, openFeatures: true), for: context.window)
                        }))
                    })).detectBold(with: .medium(.text))
                    aboveLayout = TextViewLayout(attributed, maximumNumberOfLines: 2, alignment: .center)
                    aboveLayout?.measure(width: w_width - 24)
                    aboveLayout?.interactions = globalLinkExecutor
                } else {
                    aboveLayout = nil
                }
                
                let rect = NSMakeRect(0, 0, w_width, 40 + 20 + (aboveLayout != nil ? aboveLayout!.layoutSize.height + 4 : 0))
                
                
                let panel = Window(contentRect: rect, styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
                panel._canBecomeMain = false
                panel._canBecomeKey = false
                panel.level = .popUpMenu
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = false
                

                let reveal:((ContextAddReactionsListView & StickerFramesCollector)->Void)?
                
                
                var selectedItems: [EmojiesSectionRowItem.SelectedItem] = []

                if let reactions = message.effectiveReactions(isTags: isTags) {
                    for reaction in reactions {
                        if reaction.isSelected {
                            switch reaction.value {
                            case let .builtin(emoji):
                                selectedItems.append(.init(source: .builtin(emoji), type: .transparent))
                            case let .custom(fileId):
                                selectedItems.append(.init(source: .custom(fileId), type: .transparent))
                            case .stars:
                                break
                            }
                        }
                    }
                }
                
                if accessToAll {
                    reveal = { view in
                        let window = ReactionsWindowController(context, peerId: message.id.peerId, selectedItems: selectedItems, react: { sticker, fromRect in
                            let value: UpdateMessageReaction
                            if let bundle = sticker.file._parse().stickerText {
                                value = .builtin(bundle)
                            } else {
                                value = .custom(fileId: sticker.file._parse().fileId.id, file: sticker.file._parse())
                            }
                            var contains: Bool = false
                            for reaction in reactions {
                                switch reaction.content {
                                case let .custom(file):
                                    if file.fileId == sticker.file._parse().fileId {
                                        contains = true
                                        break
                                    }
                                default:
                                    break
                                }
                            }
                            
                            if isTags, !context.isPremium {
                                prem(with: PremiumBoardingController(context: context, source: .saved_tags, openFeatures: true), for: context.window)
                            } else {
                                if case .custom = value, !context.isPremium && sticker.file._parse().isPremiumEmoji, !contains {
                                    showModalText(for: context.window, text: strings().customReactionPremiumAlert, callback: { _ in
                                        prem(with: PremiumBoardingController(context: context, source: .premium_stickers), for: context.window)
                                    })
                                } else {
                                    let updated = message.newReactions(with: value, isTags: isTags)
                                    context.reactions.react(message.id, values: updated, fromRect: fromRect, storeAsRecentlyUsed: true)
                                }
                            }
                        })
//                        let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeOut)
//                        transition.updateFrame(view: view, frame: CGRect(origin: view.frame.origin, size: NSMakeSize(view.frame.width, 60)))
//                        view.updateLayout(size: view.frame.size, transition: transition)
                        window.show(view)
                    }
                } else {
                    reveal = nil
                }
                
                
                let view = ContextAddReactionsListView(frame: rect, context: context, list: available, add: { value, checkPrem, fromRect in
                    if isTags, !context.isPremium {
                        prem(with: PremiumBoardingController(context: context, source: .saved_tags, openFeatures: true), for: context.window)
                    } else {
                        if value == .stars {
                            context.reactions.sendStarsReaction(message.id, count: 1, fromRect: fromRect)
                        } else {
                            context.reactions.react(message.id, values: message.newReactions(with: value.toUpdate(), isTags: isTags), fromRect: fromRect, storeAsRecentlyUsed: true)
                        }
                    }
                }, radiusLayer: nil, revealReactions: reveal, aboveText: aboveLayout, message: message)
                
                
                panel.contentView?.addSubview(view)
                panel.contentView?.wantsLayer = true
                view.autoresizingMask = [.width, .height]
                return panel
            }
        }
        return .single(nil)
    }
    
    override var instantlyResize: Bool {
        return forwardType != nil
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if let message = message, !context.isFrozen {
            return chatMenuItems(for: message, entry: entry, textLayout: nil, chatInteraction: chatInteraction)
        }
        return super.menuItems(in: location)
    }
    
    var stateOverlayBackgroundColor: NSColor {
        guard let media = self.message?.anyMedia else {
            return self.presentation.chatServiceItemColor
        }
        if media is TelegramMediaImage {
            return self.presentation.colors.blackTransparent.withAlphaComponent(0.5)
        } else if let media = media as? TelegramMediaFile, media.isVideo && !media.isInstantVideo {
            return self.presentation.colors.blackTransparent.withAlphaComponent(0.5)
        } else if media is TelegramMediaMap {
            return self.presentation.colors.blackTransparent.withAlphaComponent(0.5)
        } else {
            return self.presentation.chatServiceItemColor
        }
    }
    
    var stateOverlayTextColor: NSColor {
       guard let media = self.message?.anyMedia else {
           return self.presentation.chatServiceItemTextColor
       }
        if let file = media as? TelegramMediaFile, file.isInstantVideo {
            return self.presentation.chatServiceItemTextColor
        } else if media is TelegramMediaMap {
            return NSColor(0xffffff)
        }
        
       if media.isInteractiveMedia {
            return NSColor(0xffffff)
       } else {
           return self.presentation.chatServiceItemTextColor
       }
    }
    var isInteractiveMedia: Bool {
        guard let media = self.message?.anyMedia else {
            return false
        }
        return media.isInteractiveMedia
    }
    
    var hasTranscribeText: Bool {
        if let transcribe = entry.additionalData.transribeState {
            switch transcribe {
            case .loading:
                return false
            case .revealed(let bool):
                return bool
            case .collapsed(let bool):
                return bool
            }
        }
        return false
    }
    
    var transcribeSize: NSSize {
        return NSMakeSize(40, 40)
    }
    
    struct LastLineData {
        let width: CGFloat
        let single: Bool
    }
    var lastLineContentWidth: LastLineData? {
        if let reactionsLayout = reactionsLayout {
            var oneLine = reactionsLayout.oneLine
            if let item = self as? ChatMessageItem {
                if item.webpageLayout != nil {
                    oneLine = false
                }
            }
            if !reactionsLayout.presentation.isOutOfBounds {
                return LastLineData(width: reactionsLayout.lastLineSize.width, single: oneLine)
            }
        }
        if let factCheckLayout {
            return LastLineData(width: factCheckLayout.size.width, single: false)
        }
        if captionLayouts.count == 1, !invertMedia {
            if let item = self as? ChatGroupedItem {
                switch item.layoutType {
                case .files:
                    if let caption = captionLayouts.first(where: { $0.id == self.lastMessage?.stableId})?.layout {
                        if let line = caption.lastLine {
                            return LastLineData(width: line.isRTL || caption.lastLineIsQuote ? blockWidth : line.frame.width, single: caption.linesCount == 1)
                        }
                    }
                case .photoOrVideo:
                    if let caption = captionLayouts.first?.layout {
                        if let line = caption.lastLine {
                            return LastLineData(width: line.isRTL || caption.lastLineIsQuote ? blockWidth : line.frame.width, single: caption.linesCount == 1 && !isBubbleFullFilled)
                        }
                    }
                }
            } else {
                if let caption = captionLayouts.first?.layout {
                    if let line = caption.lastLine {
                        return LastLineData(width: line.isRTL || caption.lastLineIsQuote ? blockWidth : line.frame.width, single: caption.linesCount == 1 && !isBubbleFullFilled)
                    }
                }
            }
        } else if captionLayouts.count > 1 {
            if let item = self as? ChatGroupedItem {
                switch item.layoutType {
                case .files:
                    if let caption = captionLayouts.first(where: { $0.id == self.lastMessage?.stableId })?.layout {
                        if let line = caption.lastLine {
                            return LastLineData(width: line.isRTL || caption.lastLineIsQuote ? blockWidth : line.frame.width, single: caption.linesCount == 1)
                        }
                    }
                case .photoOrVideo:
                    if let caption = captionLayouts.first?.layout {
                        if let line = caption.lastLine {
                            return LastLineData(width: line.isRTL || caption.lastLineIsQuote ? blockWidth : line.frame.width, single: caption.linesCount == 1)
                        }
                    }
                }
            }
        }
        
        if let item = self as? ChatMessageItem {
            if item.actionButtonText != nil {
                return nil
            }
            if item.textLayout.lastLineIsRtl {
                return nil
            }
            if item.textLayout.lastLineIsBlock {
                return LastLineData(width: item.textLayout.size.width, single: false)
            }
            if let _ = item.webpageLayout, !item.webpageAboveContent {
                return nil
            }
            if let line = item.textLayout.lastLine {
                return LastLineData(width: line.frame.width, single: item.textLayout.linesCount == 1)
            }
        }
        return nil
    }
    
    func invokeMessageEffect() {
        if let message = message {
            let mirror = self.renderType == .list ? false : message.isIncoming(context.account, renderType == .bubble)
            chatInteraction.runPremiumScreenEffect(message, mirror, false)
        }
    }
    
    
    func revealBlockAtIndex(_ index: Int, messageId: MessageId? = nil) {
        if let messageId = messageId ?? self.message?.id {
            chatInteraction.toggleQuote(QuoteMessageIndex(messageId: messageId, index: index))
        }
    }
    
    override func inset(for text: String) -> CGFloat {
        for captionLayout in captionLayouts {
            if let rect = captionLayout.layout.rect(for: text) {
                return rect.maxY
            }
        }
        return super.inset(for: text)
    }


}

