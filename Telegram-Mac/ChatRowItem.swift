//
//  ChatRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac



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
    case Full(rank: String?)
    case Short
}

enum ChatItemRenderType {
    case bubble
    case list
}

class ChatRowItem: TableRowItem {
    
    private(set) var chatInteraction:ChatInteraction
    
    let context: AccountContext
    private(set) var peer:Peer?
    private(set) var entry:ChatHistoryEntry
    private(set) var message:Message?
    
    var messages: [Message] {
        if let message = message {
            return [message]
        }
        return []
    }
    
    private(set) var itemType:ChatItemType = .Full(rank: nil)
    
    var isFullItemType: Bool {
        if case .Full = itemType {
            return true
        } else {
            return false
        }
    }

    //right view
    private(set) var date:(TextNodeLayout,TextNode)?
    
    private(set) var channelViewsNode:TextNode?
    private(set) var channelViews:(TextNodeLayout,TextNode)?
    private(set) var channelViewsAttributed:NSAttributedString?
    
    private(set) var postAuthorNode:TextNode?
    private(set) var postAuthor:(TextNodeLayout,TextNode)?
    private(set) var postAuthorAttributed:NSAttributedString?
    
    private(set) var editedLabel:(TextNodeLayout,TextNode)?
   
    private(set) var fullDate:String?
    private(set) var forwardHid: String?
    private(set) var nameHide: String?

	var forwardType:ForwardItemType? {
        didSet {
            
        }
    }
    
    var selectableLayout:[TextViewLayout] {
        if let caption = captionLayout {
            return [caption]
        }
        return []
    }
    
    var sending: Bool {
        return message?.flags.contains(.Unsent) ?? false
    }

    private var forwardHeaderNode:TextNode?
    private(set) var forwardHeader:(TextNodeLayout, TextNode)?
    var forwardNameLayout:TextViewLayout?
    var captionLayout:TextViewLayout?
    private(set) var authorText:TextViewLayout?
    private(set) var adminBadge:TextViewLayout?

    var replyModel:ReplyModel?
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
    let leftInset:CGFloat = 20

    
    var _defaultHeight:CGFloat {
        return self.contentOffset.y + defaultContentTopOffset
    }
    
    var _contentSize:NSSize = NSZeroSize;
    var previousBlockWidth:CGFloat = 0;

    var bubbleDefaultInnerInset: CGFloat {
        return bubbleContentInset * 2 + additionBubbleInset
    }
    
    var blockWidth:CGFloat {
        
        var widthForContent: CGFloat = 0
        
        if isBubbled {
            widthForContent = min(width - self.contentOffset.x - bubbleDefaultInnerInset - (20 + 36 + 10 + additionBubbleInset), 500)
        } else {
            if case .Full = itemType {
                let additionWidth:CGFloat = date?.0.size.width ?? 20
                widthForContent = width - self.contentOffset.x - 44 - additionWidth
            } else {
                widthForContent = width - self.contentOffset.x - rightSize.width - 44
            }
        }
        
        if forwardType != nil {
            widthForContent -= leftContentInset
        }
        
        return widthForContent
    }
    
    public var rightSize:NSSize {
        
        var size:NSSize = NSZeroSize
        
        if let date = date {
            size = NSMakeSize(date.0.size.width, isBubbled && !isFailed ? 15 : 16)
        }
        
        if let peer = peer as? TelegramChannel, case .broadcast = peer.info, (!isUnsent && !isFailed) {
            size.width += 0
        } else {
            if !isIncoming || (isUnsent || isFailed) {
                if isBubbled {
                    size.width += 16
                    if isFailed {
                        size.width += 4
                    }
                } else {
                    size.width += 20
                }
            }
        }
        
        
        
        if let channelViews = channelViews {
            size.width += channelViews.0.size.width + 8 + 16
        }
        if let postAuthor = postAuthor {
            size.width += postAuthor.0.size.width + 8
        }
        
        if let editedLabel = editedLabel {
            size.width += editedLabel.0.size.width + 7
        }
        
        size.width = max(isBubbled ? size.width : 54, size.width)
        
        size.width += stateOverlayAdditionCorner * 2
        size.height = isStateOverlayLayout ? 17 : size.height
        return size
        
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
        let file = message?.media.first as? TelegramMediaFile
        return file?.isStaticSticker == true || file?.isAnimatedSticker == true
    }
    

    override var height: CGFloat  {
        var height:CGFloat = self.contentSize.height + _defaultHeight
        
        if !isBubbled, case .Full = self.itemType, self is ChatMessageItem {
            height += 2
        }
        
        if let captionLayout = captionLayout {
            height += captionLayout.layoutSize.height + defaultContentInnerInset
        }
        if let replyMarkupModel = replyMarkupModel {
            height += replyMarkupModel.size.height + defaultReplyMarkupInset
        }
        
        if isBubbled {
            if let additional = additionalLineForDateInBubbleState {
                height += additional
            }
   
            if hasPhoto || replyModel?.isSideAccessory == true {
                height = max(48, height)
            }
            
//            if self is ChatMessageItem {
//                height += 4
//            } else {
//                height += 2
//            }
            //height = max(height, 40)
            
            //height = max(height, 48)
        }
        

        return max(rightSize.height + 8, height)
    }
    
    var defaultReplyMarkupInset: CGFloat {
        return  (isBubbled ? 4 : defaultContentInnerInset)
    }
    
    var defaultContentInnerInset: CGFloat {
        return 6
    }
    
    var elementsContentInset: CGFloat {
        return 0
    }
    
    var replyOffset:CGFloat {
        var top:CGFloat = defaultContentTopOffset
        if isBubbled && authorText != nil {
            top -= topInset
        } 
        if let author = authorText {
            top += author.layoutSize.height + defaultContentInnerInset
        }
        
        return top
    }
    
    var isBubbleFullFilled: Bool {
        return false
    }
    
    var isStateOverlayLayout: Bool {
        if let message = message, let media = message.media.first {
            if let file = media as? TelegramMediaFile {
                if file.isStaticSticker || file.isAnimatedSticker {
                    return isBubbled
                }
            }
            if let media = media as? TelegramMediaMap {
                if let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                    var time:TimeInterval = Date().timeIntervalSince1970
                    time -= context.timeDifference
                    if Int32(time) < message.timestamp + liveBroadcastingTimeout {
                        return false
                    }
                }
                return media.venue == nil
            }
            return isBubbled && media.isInteractiveMedia && captionLayout == nil
        }
        return false
    }
    
    private(set) var isForceRightLine: Bool = false
    
    var forwardHeaderInset:NSPoint {
        
        var top:CGFloat = defaultContentTopOffset
        
        if !isBubbled, forwardHeader == nil {
            top -= topInset
        }
        
        if let author = authorText {
            top += author.layoutSize.height
        }
        
        return NSMakePoint(defLeftInset, top)
    }
    
    var forwardNameInset:NSPoint {
        
        var top:CGFloat = forwardHeaderInset.y
        
        if let header = forwardHeader, !isBubbled {
            top += header.0.size.height + defaultContentInnerInset
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
                inset += 36 + 6
            }
        } else {
            inset += 36 + 10
        }
        
        return inset
    }
    
    var hasPhoto: Bool {
        if !isBubbled {
            if case .Full = itemType {
                return true
            } else {
                return false
            }
        } else {
            if case .Full = itemType, let message = message, let peer = message.peers[message.id.peerId] {
                
                switch chatInteraction.chatLocation {
                case .peer:
                    if isIncoming && message.id.peerId == context.peerId {
                        return true
                    }
                    if !peer.isUser && !peer.isSecretChat && !peer.isChannel && isIncoming {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    var isInstantVideo: Bool {
        if let media = message?.media.first as? TelegramMediaFile {
            return media.isInstantVideo
        }
        return false
    }
    
    var contentOffset:NSPoint {
        
        var left:CGFloat = defLeftInset
        
        var top:CGFloat = defaultContentTopOffset
        
        
        if let author = authorText {
            top += author.layoutSize.height
            if !isBubbled {
                top += topInset
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
                top += max(34, replyModel.size.height) + ((!isBubbleFullFilled && isBubbled && self is ChatMediaItem) ? 0 : 8)
                if (authorText != nil) && self is ChatMessageItem {
                    top += topInset
                    //top -= defaultContentInnerInset
                } else if hasBubble && self is ChatMessageItem {
                    top -= topInset
                }
            }
        }
        
        if let forwardNameLayout = forwardNameLayout, !isBubbled || !isInstantVideo  {
            top += forwardNameLayout.layoutSize.height
            //if !isBubbled {
                top += 2
            //}
        }
        
        if let forwardType = forwardType, !isBubbled {
            if forwardType == .FullHeader || forwardType == .ShortHeader {
                if let forwardHeader = forwardHeader {
                    top += forwardHeader.0.size.height + defaultContentInnerInset
                } else {
                    top += bubbleDefaultInnerInset
                }
            }
        }
        
        if isBubbled, self is ChatMessageItem {
            top -= 1
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
    
    var isStorage: Bool {
        if let message = message {
            for attr in message.attributes {
                if let attr = attr as? SourceReferenceMessageAttribute {
                    if authorIsChannel {
                        return true
                    }
                    return (chatInteraction.peerId == context.peerId && context.peerId != attr.messageId.peerId)
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
    
    
    func gotoSourceMessage() {
        if let message = message {
            for attr in message.attributes {
                if let attr = attr as? SourceReferenceMessageAttribute {
                    chatInteraction.openInfo(attr.messageId.peerId, true, attr.messageId, nil)
                }
            }
        }
    }
    
    var isVideoOrBigEmoji: Bool {
        return self is ChatVideoMessageItem || (message != nil && bigEmojiMessage(context.sharedContext, message: message!))
    }
    
    func share() {
        if let message = message {
            showModal(with: ShareModalController(ShareMessageObject(context, message)), for: mainWindow)
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
    
    var isSharable: Bool {
        var peers:[Peer] = []
        if let peer = peer {
            peers.append(peer)
        }
        if authorIsChannel {
            return false
        }
        if let message = message, message.isScheduledMessage {
            return false
        }
        if let info = message?.forwardInfo {
            if let author = info.author {
                peers.append(author)
            }
            
            if let peer = info.source {
                peers.append(peer)
            }
        }
        
        for peer in peers {
            if let peer = peer as? TelegramChannel {
                switch peer.info {
                case .broadcast:
                    return !chatInteraction.isLogInteraction
                default:
                    break
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
    
    let isScam: Bool
    let isForwardScam: Bool

    var isFailed: Bool {
        if let message = message {
            return message.flags.contains(.Failed)
        }
        return false
    }
    
    let isIncoming: Bool
    
    var isUnsent: Bool {
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
//            if let peer = peer as? TelegramChannel {
//                switch peer.info {
//                case .broadcast:
//                    return false
//                default:
//                    break
//                }
//            }
            if let peer = peer as? TelegramUser {
                if peer.botInfo != nil {
                    return false
                }
            }
        }
        
        if let message = message {
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
        }
        
        return !chatInteraction.isLogInteraction && message?.groupingKey == nil && message?.id.peerId != context.peerId
    }
    
    private static func canFillAuthorName(_ message: Message, chatInteraction: ChatInteraction, renderType: ChatItemRenderType, isIncoming: Bool, hasBubble: Bool) -> Bool {
        var canFillAuthorName: Bool = true
        switch chatInteraction.chatLocation {
        case .peer:
            if renderType == .bubble, let peer = messageMainPeer(message) {
                canFillAuthorName = isIncoming && (peer.isGroup || peer.isSupergroup || message.id.peerId == chatInteraction.context.peerId)
                if let media = message.media.first {
                    canFillAuthorName = canFillAuthorName && !media.isInteractiveMedia && hasBubble && isIncoming
                } else if bigEmojiMessage(chatInteraction.context.sharedContext, message: message) {
                    canFillAuthorName = false
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
    
    var hasBubble: Bool 
    
    static func hasBubble(_ message: Message?, entry: ChatHistoryEntry, type: ChatItemType, sharedContext: SharedAccountContext) -> Bool {
        if let message = message, let media = message.media.first {
            
            if let file = media as? TelegramMediaFile {
                if file.isStaticSticker {
                    return false
                }
                if file.isAnimatedSticker {
                    return false
                }
                if file.isInstantVideo {
                    return false //!message.text.isEmpty || (message.replyAttribute != nil && !file.isInstantVideo) || (message.forwardInfo != nil && !file.isInstantVideo)
                }
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
            
            if let _peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = _peer.info {
                peer = _peer
            } else if let author = message.effectiveAuthor, peer == nil {
                if author is TelegramSecretChat {
                    peer = messageMainPeer(message)
                } else {
                    peer = author
                }
            }
            
            if message.groupInfo != nil {
                switch entry {
                case .groupedPhotos(let entries, _):
                    return !message.text.isEmpty || message.replyAttribute != nil || message.forwardInfo != nil || entries.count == 1
                default:
                    return true
                }
            }
            
            
//            if media is TelegramMediaImage {
//                if case .Full = type {
//                    return true
//                }
//                return !message.text.isEmpty || message.replyAttribute != nil || message.forwardInfo != nil
//            }
        } else if let message = message {
            return !bigEmojiMessage(sharedContext, message: message)
        }
        return true
    }
    
    let renderType: ChatItemRenderType
    var modernBubbleImage:(CGImage, NSEdgeInsets)? = nil
    var selectedBubbleImage:(CGImage, NSEdgeInsets)? = nil
    
    private let downloadSettings: AutomaticMediaDownloadSettings
    
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
    
    var forceBackgroundColor: NSColor? = nil
    
    init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        self.entry = object
        self.context = chatInteraction.context
        self.presentation = theme
        self.chatInteraction = chatInteraction
        self.downloadSettings = downloadSettings
        self._approximateSynchronousValue = Thread.isMainThread
        self._avatarSynchronousValue = Thread.isMainThread
        var message: Message?
        var isRead: Bool = true
        var itemType: ChatItemType = .Full(rank: nil)
        var fwdType: ForwardItemType? = nil
        var renderType:ChatItemRenderType = .list
        var object = object
        
        var hiddenFwdTooltip:(()->Void)? = nil
        
        var captionMessage: Message? = object.message
        
        var hasGroupCaption: Bool = object.message?.text.isEmpty == false
        if case let .groupedPhotos(entries, _) = object {
            object = entries.filter({!$0.message!.media.isEmpty}).last!
            
            loop: for entry in entries {
                if let _ = captionMessage, !entry.message!.text.isEmpty {
                    captionMessage = nil
                    hasGroupCaption = false
                    break loop
                }
                if !entry.message!.text.isEmpty {
                    captionMessage = entry.message!
                    hasGroupCaption = true
                }
            }
            if captionMessage == nil {
                captionMessage = object.message!
            }
        }
        
        if case let .MessageEntry(_message, _, _isRead, _renderType, _itemType, _fwdType, _, _, _) = object {
            message = _message
            isRead = _isRead
            itemType = _itemType
            fwdType = _fwdType
            renderType = _renderType
        }
        
        var isStateOverlayLayout: Bool {
            if renderType == .bubble, let message = captionMessage, let media = message.media.first {
                if let file = media as? TelegramMediaFile {
                    if file.isStaticSticker || file.isAnimatedSticker {
                        return renderType == .bubble
                    }
                    
                }
                if let media = media as? TelegramMediaMap {
                    if let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                        var time:TimeInterval = Date().timeIntervalSince1970
                        time -= context.timeDifference
                        if Int32(time) < message.timestamp + liveBroadcastingTimeout {
                            return false
                        }
                    }
                    return media.venue == nil
                }
                return media.isInteractiveMedia && !hasGroupCaption
            } else if let message = message, bigEmojiMessage(context.sharedContext, message: message), renderType == .bubble {
                return true
            }
            return false
        }
        
        if message?.id.peerId == context.peerId {
            itemType = .Full(rank: nil)
        }
        self.renderType = renderType
        self.message = message
        
        var isForwardScam: Bool = false
        var isScam = false
        if let message = message, let peer = messageMainPeer(message) {
            if peer.isGroup || peer.isSupergroup {
                if let author = message.forwardInfo?.author {
                    isForwardScam = author.isScam
                }
                if let author = message.author, case .Full = itemType {
                    isScam = author.isScam
                }
            }
        }
        self.isScam = isScam
        self.isForwardScam = isForwardScam
                
        if let message = message {
            let isBubbled = renderType == .bubble
            let hasBubble = ChatRowItem.hasBubble(captionMessage ?? message, entry: entry, type: itemType, sharedContext: context.sharedContext)
            self.hasBubble = isBubbled && hasBubble
            
            let isIncoming: Bool = message.isIncoming(context.account, renderType == .bubble)
            self.isIncoming = isIncoming

            
            if case .bubble = renderType , hasBubble{
                let isFull: Bool
                if case .Full = itemType {
                    isFull = true
                    
                } else {
                    isFull = false
                }
                
                modernBubbleImage = messageBubbleImageModern(incoming: isIncoming, fillColor: presentation.chat.backgroundColor(isIncoming, object.renderType == .bubble), strokeColor: presentation.chat.bubbleBorderColor(isIncoming, renderType == .bubble), neighbors: isFull && !message.isHasInlineKeyboard ? .none : .both)
                selectedBubbleImage = messageBubbleImageModern(incoming: isIncoming, fillColor: presentation.chat.backgoundSelectedColor(isIncoming, object.renderType == .bubble), strokeColor: presentation.chat.backgoundSelectedColor(isIncoming, renderType == .bubble), neighbors: isFull && !message.isHasInlineKeyboard ? .none : .both)
            }
            
            self.itemType = itemType
            self.isRead = isRead
            
            if let info = message.forwardInfo, chatInteraction.peerId == context.account.peerId {
                if info.author == nil, let signature = info.authorSignature {
                    self.peer = TelegramUser(id: PeerId(namespace: 0, id: 0), accessHash: nil, firstName: signature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
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
                            postAuthorAttributed = .initialize(string: attr.signature, color: isStateOverlayLayout ? .white : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short))
                        }
                        break
                    }
                }
            }
            if postAuthorAttributed == nil, ChatRowItem.authorIsChannel(message: message, account: context.account) {
                if let author = message.forwardInfo?.authorSignature {
                    postAuthorAttributed = .initialize(string: author, color: isStateOverlayLayout ? .white : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short))
                }
            }
            
            
            if let peer = messageMainPeer(message) as? TelegramUser, peer.botInfo != nil || peer.id == context.peerId {
                self.isRead = true
            }
            
            if let info = message.forwardInfo {
                
                
                var accept:Bool = !isHasSource && message.id.peerId != context.peerId
                
                if let media = message.media.first as? TelegramMediaFile {
                    if media.isAnimatedSticker {
                        accept = false
                    }
                    for attr in media.attributes {
                        switch attr {
                        case .Sticker:
                            accept = false
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
                
                
                if accept || (ChatRowItem.authorIsChannel(message: message, account: context.account) && info.author?.id != message.chatPeer(context.peerId)?.id) {
                    forwardType = fwdType
                    
                    var attr = NSMutableAttributedString()

                    if ChatRowItem.authorIsChannel(message: message, account: context.account) {
                        if let author = info.author {
                            var range = attr.append(string: author.displayTitle, color: presentation.chat.linkColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                            
                            let appLink = inAppLink.peerInfo(link: "", peerId: author.id, action: nil, openChat: !(author is TelegramUser), postId: info.sourceMessageId?.id, callback: chatInteraction.openInfo)
                            attr.add(link: appLink, for: range)
                        }
                    } else {
                        if let source = info.source, source.isChannel {
                            var range = attr.append(string: source.displayTitle, color: presentation.chat.linkColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                            if info.author?.id != source.id {
                                let subrange = attr.append(string: " (\(info.authorTitle))", color: presentation.chat.linkColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                                range.length += subrange.length
                            }
                            
                            let link = source.addressName == nil ? "https://t.me/c/\(source.id.id)/\(info.sourceMessageId?.id != nil ? "\(info.sourceMessageId!.id)" : "")" : "https://t.me/\(source.addressName!)/\(info.sourceMessageId?.id != nil ? "\(info.sourceMessageId!.id)" : "")"
                            let appLink = inApp(for: link.nsstring, context: context, peerId: nil, openInfo: chatInteraction.openInfo)
                            attr.add(link: appLink, for: range)
                            
                        } else {
                            let range = attr.append(string: info.authorTitle, color: presentation.chat.linkColor(isIncoming, object.renderType == .bubble), font: info.author == nil ? .normal(.text) : .medium(.text))
                            
                            var linkAbility: Bool = true
                            if let channel = info.author as? TelegramChannel {
                                if channel.username == nil && channel.participationStatus != .member {
                                    linkAbility = false
                                }
                            }
                            if linkAbility, let author = info.author {
                                attr.add(link: inAppLink.peerInfo(link: "", peerId: author.id, action:nil, openChat: author.isChannel, postId: info.sourceMessageId?.id, callback:chatInteraction.openInfo), for: range)
                            } else if info.author == nil {
                                attr.add(link: inAppLink.callback("hid", { _ in
                                    hiddenFwdTooltip?()
                                }), for: range)
                                
                            }
                        }
                    }
                    
                    
                    var isInstantVideo: Bool {
                        if let media = message.media.first as? TelegramMediaFile {
                            return media.isInstantVideo
                        }
                        return false
                    }
                    
                    let forwardNameColor: NSColor
                    if isForwardScam {
                        forwardNameColor = theme.colors.redUI
                    } else if !hasBubble {
                        forwardNameColor = presentation.colors.grayText
                    } else if isIncoming {
                        forwardNameColor = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                    } else {
                        forwardNameColor = presentation.chat.grayText(isIncoming || isInstantVideo, object.renderType == .bubble)
                    }
                    
                    if renderType == .bubble {
                        
                        let newAttr = parseMarkdownIntoAttributedString(L10n.chatBubblesForwardedFrom(attr.string), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.short), textColor:forwardNameColor), link: MarkdownAttributeSet(font: hasBubble && info.author != nil ? .medium(.short) : .normal(.short), textColor: forwardNameColor), linkAttribute: { [weak attr] contents in
                            if let attr = attr, !attr.string.isEmpty, let link = attr.attribute(NSAttributedString.Key.link, at: 0, effectiveRange: nil) {
                                return (NSAttributedString.Key.link.rawValue, link)
                            }
                            return nil
                        }))
                        attr = newAttr.mutableCopy() as! NSMutableAttributedString
                    } else {
                        _ = attr.append(string: " ")
                        _ = attr.append(string: DateUtils.string(forLastSeen: info.date), color: renderType == .bubble ? forwardNameColor : presentation.colors.grayText, font: .normal(.short))
                    }

                    
                    forwardNameLayout = TextViewLayout(attr, maximumNumberOfLines: renderType == .bubble ? 2 : 1, truncationType: .end)
                    forwardNameLayout?.interactions = globalLinkExecutor
                }
            }
            
            if case let .Full(rank) = itemType {
                
                
                let canFillAuthorName: Bool = ChatRowItem.canFillAuthorName(message, chatInteraction: chatInteraction, renderType: renderType, isIncoming: isIncoming, hasBubble: hasBubble)

                
                var titlePeer:Peer? = self.peer
                
                var title:String = peer?.displayTitle ?? ""
                if let peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info {
                    title = peer.displayTitle
                    titlePeer = peer
                }
                
                let attr:NSMutableAttributedString = NSMutableAttributedString()
                
                if let peer = titlePeer {
                    var nameColor:NSColor = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                    
                    if messageMainPeer(message) is TelegramChannel || messageMainPeer(message) is TelegramGroup {
                        if let peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info {
                            nameColor = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                        } else if context.peerId != peer.id {
                            let value = abs(Int(peer.id.id) % 7)
                            nameColor = presentation.chat.peerName(value)
                        }
                    }
                    if canFillAuthorName {
                        let range = attr.append(string: title, color: nameColor, font: .medium(.text))
                        if peer.id.id != 0 {
                            attr.addAttribute(NSAttributedString.Key.link, value: inAppLink.peerInfo(link: "", peerId:peer.id, action:nil, openChat: peer.isChannel, postId: nil, callback: chatInteraction.openInfo), range: range)
                        } else {
                            nameHide = L10n.chatTooltipHiddenForwardName
                        }
                    }
                    
                    
                    if let bot = message.inlinePeer, message.hasInlineAttribute, let address = bot.username {
                        if attr.length > 0 {
                            _ = attr.append(string: " ")
                        }
                        _ = attr.append(string: "\(L10n.chatMessageVia) ", color: !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font:.medium(.text))
                        let range = attr.append(string: "@" + address, color: presentation.chat.linkColor(isIncoming, hasBubble && isBubbled), font:.medium(.text))
                        attr.addAttribute(NSAttributedString.Key.link, value: inAppLink.callback("@" + address, { (parameter) in
                            chatInteraction.updateInput(with: parameter + " ")
                        }), range: range)
                    }
                    if canFillAuthorName {
                        var badge: NSAttributedString? = nil
                        if let rank = rank {
                            badge = .initialize(string: " " + rank, color: !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.short))
                            
                        }
                        else if ChatRowItem.authorIsChannel(message: message, account: context.account) {
                            badge = .initialize(string: " " + L10n.chatChannelBadge, color: !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.short))
                        }
                        if let badge = badge {
                            adminBadge = TextViewLayout(badge, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                            adminBadge?.mayItems = false
                            adminBadge?.measure(width: .greatestFiniteMagnitude)
                        }
                    }
                    
                    if attr.length > 0 {
                        authorText = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                        authorText?.mayItems = false
                        authorText?.interactions = globalLinkExecutor
                    }
                }
                
            }
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= context.timeDifference
            
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .none
            dateFormatter.timeZone = NSTimeZone.local
            
            date = TextNode.layoutText(maybeNode: nil, .initialize(string: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(time))), color: isStateOverlayLayout ? .white : (!hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble)), font: renderType == .bubble ? .italic(.small) : .normal(.short)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .left)

        } else {
            self.isIncoming = false
            self.hasBubble = false
        }
 
        
        super.init(initialSize)
        
        hiddenFwdTooltip = { [weak self] in
            guard let view = self?.view as? ChatRowView, let forwardName = view.forwardName else { return }
            tooltip(for: forwardName, text: L10n.chatTooltipHiddenForwardName, autoCorner: false)
        }
        
        if let message = message {
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            formatter.timeZone = NSTimeZone.local
            //
            var fullDate: String = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp) - context.timeDifference))
            
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyMessageAttribute, let replyMessage = message.associatedMessages[attribute.messageId]  {
                    let replyPresentation = ChatAccessoryPresentation(background: hasBubble ? presentation.chat.backgroundColor(isIncoming, object.renderType == .bubble) : isBubbled ?   presentation.colors.grayForeground : presentation.colors.background, title: presentation.chat.replyTitle(self), enabledText: presentation.chat.replyText(self), disabledText: presentation.chat.replyDisabledText(self), border: presentation.chat.replyTitle(self))
                    
                    self.replyModel = ReplyModel(replyMessageId: attribute.messageId, account: context.account, replyMessage:replyMessage, autodownload: downloadSettings.isDownloable(replyMessage), presentation: replyPresentation, makesizeCallback: { [weak self] in
                        guard let `self` = self else {return}
                        _ = self.makeSize(self.oldWidth, oldWidth: 0)
                        Queue.mainQueue().async { [weak self] in
                            self?.redraw()
                        }
                    })
                    replyModel?.isSideAccessory = isBubbled && !hasBubble
                }
                if let attribute = attribute as? ViewCountMessageAttribute {
                    channelViewsAttributed = .initialize(string: attribute.count.prettyNumber, color: isStateOverlayLayout ? .white : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short))
                    
                    if attribute.count >= 1000 {
                        fullDate = "\(attribute.count.separatedNumber) \(tr(L10n.chatMessageTooltipViews)), \(fullDate)"
                    }
                }
                if let attribute = attribute as? EditedMessageAttribute {
                    if isEditMarkVisible {
                        editedLabel = TextNode.layoutText(maybeNode: nil, .initialize(string: tr(L10n.chatMessageEdited), color: isStateOverlayLayout ? .white : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .left)
                    }
                    
                    let formatterEdited = DateFormatter()
                    formatterEdited.dateStyle = .short
                    formatterEdited.timeStyle = .medium
                    formatterEdited.timeZone = NSTimeZone.local
                    fullDate = "\(fullDate) (\(formatterEdited.string(from: Date(timeIntervalSince1970: TimeInterval(attribute.date)))))"
                }
                if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline) {
                    replyMarkupModel = ReplyMarkupNode(attribute.rows, attribute.flags, chatInteraction.processBotKeyboard(with: message))
                }
//                else if let attribute = attribute as? ReactionsMessageAttribute {
//                    var buttons:[ReplyMarkupButton] = []
//                    let sorted = attribute.reactions.sorted(by: { $0.count > $1.count })
//                    for reaction in sorted {
//                        buttons.append(ReplyMarkupButton(title: reaction.value + " \(reaction.count)", titleWhenForwarded: nil, action: .url(reaction.value)))
//                    }
//                    if !buttons.isEmpty {
//                        replyMarkupModel = ReplyMarkupNode([ReplyMarkupRow(buttons: buttons)], [], ReplyMarkupInteractions(proccess: { (button, _) in
//                            switch button.action {
//                            case let .url(buttonReaction):
//                                if let index = sorted.firstIndex(where: { $0.value == buttonReaction}) {
//                                    let reaction = sorted[index]
//                                    var newValues = sorted
//                                    if reaction.isSelected {
//                                        newValues.remove(at: index)
//                                    } else {
//                                        newValues[index] = MessageReaction(value: reaction.value, count: reaction.count + 1, isSelected: true)
//                                    }
//                                    chatInteraction.updateReactions(message.id, buttonReaction, { value in
//                                    })
//                                }
//
//                            default:
//                                break
//                            }
//                        }))
//                    }
//                }
                
                /*
                 let reactions = object.message?.attributes.first(where: { attr -> Bool in
                 return attr is ReactionsMessageAttribute
                 })
                 
                 if let reactions = reactions as? ReactionsMessageAttribute {
                 var bp:Int = 0
                 bp += 1
                 }
 */
              
            }
            
           
            
            self.fullDate = fullDate
        }
    }
    
    init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ entry: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        self.entry = entry
        self.context = chatInteraction.context
        self.message = entry.message
        self.chatInteraction = chatInteraction
        self.renderType = entry.renderType
        self.downloadSettings = downloadSettings
        self.presentation = theme
        self.isIncoming = false
        self.hasBubble = false
        self.isScam = false
        self.isForwardScam = false
        super.init(initialSize)
    }
    
    public static func item(_ initialSize:NSSize, from entry:ChatHistoryEntry, interaction:ChatInteraction, downloadSettings: AutomaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings, theme: TelegramPresentationTheme) -> ChatRowItem {
        
        if let message = entry.message {
            if message.media.count == 0 || message.media.first is TelegramMediaWebpage {
                return ChatMessageItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
            } else {
                if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let _ = message.autoremoveAttribute {
                    return ChatServiceItem(initialSize,interaction, interaction.context,entry, downloadSettings, theme: theme)
                } else if let file = message.media[0] as? TelegramMediaFile {
                    if file.isInstantVideo {
                        return ChatVideoMessageItem(initialSize, interaction, interaction.context,entry, downloadSettings, theme: theme)
                    } else if file.isVideo && !file.isAnimated {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if file.isStaticSticker {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if file.isVoice {
                        return ChatVoiceRowItem(initialSize,interaction, interaction.context,entry, downloadSettings, theme: theme)
                    } else if file.isVideo && file.isAnimated {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if !file.isVideo && (file.isAnimated && !file.mimeType.hasSuffix("gif")) {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if file.isMusic {
                        return ChatMusicRowItem(initialSize,interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if file.isAnimatedSticker {
                        return ChatAnimatedStickerItem(initialSize,interaction, interaction.context, entry, downloadSettings, theme: theme)
                    }
                    return ChatFileMediaItem(initialSize,interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if let action = message.media[0] as? TelegramMediaAction {
                    switch action.action {
                    case .phoneCall:
                        return ChatCallRowItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    default:
                        return ChatServiceItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    }
                    
                } else if message.media[0] is TelegramMediaMap {
                    return ChatMapRowItem(initialSize,interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media[0] is TelegramMediaContact {
                    return ChatContactRowItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media[0] is TelegramMediaInvoice {
                    return ChatInvoiceItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media[0] is TelegramMediaExpiredContent {
                    return ChatServiceItem(initialSize, interaction,interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media.first is TelegramMediaGame {
                    return ChatMessageItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media.first is TelegramMediaPoll {
                    return ChatPollItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media.first is TelegramMediaUnsupported {
                    return ChatMessageItem(initialSize, interaction, interaction.context,entry, downloadSettings, theme: theme)
                }
                
                return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
            }
            
        }
        
        fatalError("no item for entry")
        
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        
        let result = super.makeSize(width, oldWidth: oldWidth)
        
        isForceRightLine = false
        
        if let channelViewsAttributed = channelViewsAttributed {
            channelViews = TextNode.layoutText(maybeNode: channelViewsNode, channelViewsAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize(hasBubble ? 60 : max(150,width - contentOffset.x - 44 - 150), 20), nil, false, .left)
        }
       
        var widthForContent: CGFloat = blockWidth
        if previousBlockWidth != widthForContent {
            self.previousBlockWidth = widthForContent
            _contentSize = self.makeContentSize(widthForContent)
        }
       

        func layout() -> Bool {
            if additionalLineForDateInBubbleState == nil && !isFixedRightPosition {
                if _contentSize.width + rightSize.width + insetBetweenContentAndDate > widthForContent, replyMarkupModel == nil {
                    widthForContent = _contentSize.width - 5
                    self.isForceRightLine = true
                    //_contentSize = self.makeContentSize(widthForContent)
                    return true
                }
            }
            return true
        }
        
        if hasBubble {
           
            while !layout() {}
        }
        
        
        
        var maxContentWidth = _contentSize.width
        if hasBubble {
            maxContentWidth -= bubbleDefaultInnerInset
        }
        
        if isBubbled && isBubbleFullFilled {
            widthForContent = maxContentWidth
        }
        
        if let captionLayout = captionLayout {
            captionLayout.measure(width: maxContentWidth)
        }
        

        
        if let forwardNameLayout = forwardNameLayout {
            var w = widthForContent
            if isBubbled && !hasBubble {
                w = width - _contentSize.width - 85
            }
            forwardNameLayout.measure(width: w)
        }
        
        if forwardType == .FullHeader || forwardType == .ShortHeader {
            forwardHeader = TextNode.layoutText(maybeNode: forwardHeaderNode, .initialize(string: tr(L10n.messagesForwardHeader), color: !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), font: .normal(.text)), nil, 1, .end, NSMakeSize(width - self.contentOffset.x - 44, 20), nil,false, .left)
        } else {
            forwardHeader = nil
        }
        
        if !isBubbled {
            replyModel?.measureSize(widthForContent, sizeToFit: true)
        } else if let replyModel = replyModel {
            if let item = self as? ChatMessageItem, item.webpageLayout == nil && !replyModel.isSideAccessory {
                replyModel.measureSize(widthForContent, sizeToFit: true)
            } else {
                if !hasBubble {
                    replyModel.measureSize(min(width - _contentSize.width - contentOffset.x - 80, 300), sizeToFit: true)
                } else {
                    replyModel.measureSize(min(_contentSize.width - bubbleDefaultInnerInset, 300), sizeToFit: true)
                }
            }
        }
        
       
        
        if !canFillAuthorName, let replyModel = replyModel, let authorText = authorText, replyModel.isSideAccessory {
            var adminWidth: CGFloat = 0
            if let adminBadge = adminBadge {
                adminWidth = adminBadge.layoutSize.width
            }
            
            authorText.measure(width: replyModel.size.width - 10 - adminWidth)
            
            replyModel.topOffset = authorText.layoutSize.height + 6
            replyModel.measureSize(replyModel.width, sizeToFit: replyModel.sizeToFit)
        } else {
            var adminWidth: CGFloat = 0
            if let adminBadge = adminBadge {
                adminWidth = adminBadge.layoutSize.width
            }
            
            let channelOffset = (channelViews != nil ? channelViews!.0.size.width + 20 : 0)
            
            authorText?.measure(width: widthForContent - adminWidth - (postAuthorAttributed != nil ? 50 + channelOffset : 0))
            
            
        }
      
       
        if let postAuthorAttributed = postAuthorAttributed {
            
            postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize(hasBubble ? 60 : (width - (authorText != nil ? authorText!.layoutSize.width : 0) - contentOffset.x - 44) / 2, 20), nil, false, .left)
        }
        
        if hasBubble && isBubbleFullFilled {
            if let postAuthor = postAuthor, let postAuthorAttributed = postAuthorAttributed {
                let width: CGFloat = _contentSize.width - (rightSize.width - postAuthor.0.size.width - 8) - bubbleContentInset - additionBubbleInset - 10
                if width < 0 {
                    self.postAuthor = nil
                } else {
                    self.postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize( width, 20), nil, false, .left)
                }
            }
        }
        
         if hasBubble && !isBubbleFullFilled {
            if let postAuthorAttributed = postAuthorAttributed, let postAuthor = postAuthor {
                if bubbleFrame.width < width - 150 {
                    let size = rightSize.width - postAuthor.0.size.width - 8
                    var w = width - bubbleFrame.width - 150
                    if let _ = self as? ChatMessageItem, additionalLineForDateInBubbleState != nil {
                        w = _contentSize.width - size
                    }
                    self.postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize( w, 20), nil, false, .left)
                } else if bubbleFrame.width > _contentSize.width + rightSize.width + bubbleDefaultInnerInset {
                    var size = bubbleFrame.width - (_contentSize.width + rightSize.width + bubbleDefaultInnerInset)
                    if !postAuthor.0.isPerfectSized {
                        size = bubbleFrame.width - (_contentSize.width + bubbleDefaultInnerInset)
                    }
                    self.postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize( size, 20), nil, false, .left)
                    while !layout() {}
                }
                
            }
            
            
            
            if _contentSize.width < rightSize.width {
                if !(self is ChatMessageItem)  {
                    _contentSize.width = rightSize.width
                } else if additionalLineForDateInBubbleState != nil {
                    _contentSize.width = rightSize.width
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
                    replyMarkupModel?.measureSize(max(_contentSize.width, blockWidth))
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
        return 13
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
    
    var bubbleFrame: NSRect {
        let nameWidth:CGFloat
        if hasBubble {
            nameWidth = (authorText?.layoutSize.width ?? 0) + (isScam ? theme.icons.chatScam.backingSize.width + 3 : 0) + (adminBadge?.layoutSize.width ?? 0)
        } else {
            nameWidth = 0
        }
        //hasBubble ? ((authorText?.layoutSize.width ?? 0) + (isScam ? theme.icons.chatScam.backingSize.width + 3 : 0) + (adminBadge?.layoutSize.width ?? 0)) : 0
        
        let forwardWidth = hasBubble ? (forwardNameLayout?.layoutSize.width ?? 0) + (isForwardScam ? theme.icons.chatScam.backingSize.width + 3 : 0) : 0
        let replyWidth = hasBubble ? (replyModel?.size.width ?? 0) : 0

        var rect = NSMakeRect(defLeftInset, 2, contentSize.width, height - 4)
        
       
        if isBubbled, let replyMarkup = replyMarkupModel {
            rect.size.height -= (replyMarkup.size.height + defaultContentInnerInset)
        }
        
        //if forwardType != nil {
         //   rect.origin.x -= leftContentInset
        //}
        
        if additionalLineForDateInBubbleState == nil && !isFixedRightPosition {
            rect.size.width += rightSize.width + insetBetweenContentAndDate + bubbleDefaultInnerInset
        } else {
            rect.size.width += bubbleContentInset * 2 + insetBetweenContentAndDate
        }
        
        
        
        rect.size.width = max(nameWidth + bubbleDefaultInnerInset, rect.width)
        
        rect.size.width = max(rect.size.width, replyWidth + bubbleDefaultInnerInset)
        
        rect.size.width = max(rect.size.width, forwardWidth + bubbleDefaultInnerInset)
        
        return rect
    }
    
    var isFixedRightPosition: Bool {
        return additionalLineForDateInBubbleState != nil
    }
    
    var additionalLineForDateInBubbleState: CGFloat? {
        return isForceRightLine ? rightSize.height : nil
    }
    
    func deleteMessage() {
        _ = context.account.postbox.transaction { [weak message] transaction -> Void in
            if let message = message {
                transaction.deleteMessages([message.id], forEachMedia: { media in
                    
                })
            }
        }.start()
    }
    
    func openInfo() {
        switch chatInteraction.chatLocation {
        case .peer:
            if let peer = peer {
                chatInteraction.openInfo(peer.id, !(peer is TelegramUser), nil, nil)
            }
        }
        
    }
    
    func resendMessage(_ ids: [MessageId]) {
       _ = resendMessages(account: context.account, messageIds: ids).start()
    }
    
    func makeContentSize(_ width:CGFloat) -> NSSize {
        
        return NSZeroSize
    }
    
    override func viewClass() -> AnyClass {
        return ChatRowView.self
    }
    
    func replyAction() -> Bool {
        if chatInteraction.presentation.state == .normal {
            chatInteraction.setupReplyMessage(message?.id)
            return true
        }
        return false
    }
    func editAction() -> Bool {
         if chatInteraction.presentation.state == .normal || chatInteraction.presentation.state == .editing {
            if let message = message, canEditMessage(message, context: context) {
                chatInteraction.beginEditingMessage(message)
                return true
            }
        }
        return false
    }
    func forwardAction() -> Bool {
        if chatInteraction.presentation.state != .selecting, let message = message {
            if canForwardMessage(message, account: context.account) {
                chatInteraction.forwardMessages([message.id])
                return true
            }
        }
        return false
    }
    
    override var instantlyResize: Bool {
        return forwardType != nil
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if chatInteraction.disableSelectAbility {
            return super.menuItems(in: location)
        }
        if let message = message {
            return chatMenuItems(for: message, chatInteraction: chatInteraction)
        }
        return super.menuItems(in: location)
    }
}

func chatMenuItems(for message: Message, chatInteraction: ChatInteraction) -> Signal<[ContextMenuItem], NoError> {
    
    let account = chatInteraction.context.account
    let context = chatInteraction.context
    let peerId = chatInteraction.peerId
    let peer = chatInteraction.peer
    
    if chatInteraction.isLogInteraction || chatInteraction.presentation.state == .selecting {
        return .single([])
    }
    
    var items:[ContextMenuItem] = []
    

    
    if message.isScheduledMessage {
        items.append(ContextMenuItem(L10n.chatContextScheduledSendNow, handler: {
            _ = sendScheduledMessageNowInteractively(postbox: account.postbox, messageId: message.id).start()
        }))
        items.append(ContextMenuItem(L10n.chatContextScheduledReschedule, handler: {
            showModal(with: ScheduledMessageModalController(context: context, defaultDate: Date(timeIntervalSince1970: TimeInterval(message.timestamp)) , scheduleAt: { date in
                _ = showModalProgress(signal: requestEditMessage(account: account, messageId: message.id, text: message.text, media: .keep, scheduleTime: Int32(date.timeIntervalSince1970)), for: context.window).start(next: { result in
                    
                }, error: { error in
                   
                })
           }), for: context.window)
        }))
        items.append(ContextSeparatorItem())
    }
    
    if canReplyMessage(message, peerId: chatInteraction.peerId) && !message.isScheduledMessage  {
        items.append(ContextMenuItem(tr(L10n.messageContextReply1) + (FastSettings.tooltipAbility(for: .edit) ? " (\(tr(L10n.messageContextReplyHelp)))" : ""), handler: {
            chatInteraction.setupReplyMessage(message.id)
        }))
    }
    
    if let file = message.media.first as? TelegramMediaFile, file.isEmojiAnimatedSticker {
        items.append(ContextMenuItem(L10n.textCopyText, handler: {
            copyToClipboard(message.text)
        }))
    }
    
    if let peer = message.peers[message.id.peerId] as? TelegramChannel {
        if !message.flags.contains(.Failed), !message.flags.contains(.Unsent), !message.isScheduledMessage {
            items.append(ContextMenuItem(tr(L10n.messageContextCopyMessageLink1), handler: {
                _ = showModalProgress(signal: exportMessageLink(account: account, peerId: peer.id, messageId: message.id), for: context.window).start(next: { link in
                    if let link = link {
                        copyToClipboard(link)
                    }
                })
               
            }))
        }
    }
    
    items.append(ContextSeparatorItem())
    
    if canEditMessage(message, context: context){
        items.append(ContextMenuItem(tr(L10n.messageContextEdit), handler: {
            chatInteraction.beginEditingMessage(message)
        }))
    }
    
    if !message.isScheduledMessage {
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, peer.hasPermission(.pinMessages) || (peer.isChannel && peer.hasPermission(.editAllMessages)) {
            if !message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                items.append(ContextMenuItem(tr(L10n.messageContextPin), handler: {
                    if peer.isSupergroup {
                        modernConfirm(for: context.window, account: account, peerId: nil, header: L10n.messageContextConfirmPin1, information: nil, thridTitle: L10n.messageContextConfirmNotifyPin, successHandler: { result in
                            chatInteraction.updatePinned(message.id, false, result != .thrid)
                        })
                    } else {
                        chatInteraction.updatePinned(message.id, false, true)
                    }
                }))
            }
        } else if message.id.peerId == account.peerId {
            items.append(ContextMenuItem(L10n.messageContextPin, handler: {
                chatInteraction.updatePinned(message.id, false, true)
            }))
        } else if let peer = message.peers[message.id.peerId] as? TelegramGroup, peer.canPinMessage {
            items.append(ContextMenuItem(L10n.messageContextPin, handler: {
                modernConfirm(for: mainWindow, account: account, peerId: nil, header: L10n.messageContextConfirmPin1, information: nil, thridTitle: L10n.messageContextConfirmNotifyPin, successHandler: { result in
                    chatInteraction.updatePinned(message.id, false, result == .thrid)
                })
            }))
        }
    }
   
    
    if canForwardMessage(message, account: account) {
        items.append(ContextMenuItem(tr(L10n.messageContextForward), handler: {
            chatInteraction.forwardMessages([message.id])
        }))
    }
    
    if canDeleteMessage(message, account: account) {
        items.append(ContextMenuItem(tr(L10n.messageContextDelete), handler: {
            chatInteraction.deleteMessages([message.id])
        }))
    }
    
    
    items.append(ContextMenuItem(tr(L10n.messageContextSelect), handler: {
        chatInteraction.update({$0.withToggledSelectedMessage(message.id)})
    }))
    

    
    if canForwardMessage(message, account: account), chatInteraction.peerId != account.peerId {
        items.append(ContextMenuItem(tr(L10n.messageContextForwardToCloud), handler: {
            _ = Sender.forwardMessages(messageIds: [message.id], context: chatInteraction.context, peerId: account.peerId).start()
        }))
        items.append(ContextSeparatorItem())
    }
    
    
    
    

    
    var signal:Signal<[ContextMenuItem], NoError> = .single(items)
    
    
    if let file = message.media.first as? TelegramMediaFile, let mediaId = file.id {
        signal = signal |> mapToSignal { items -> Signal<[ContextMenuItem], NoError> in
            var items = items
            
            return account.postbox.transaction { transaction -> [ContextMenuItem] in
                if file.isAnimated && file.isVideo {
                    let gifItems = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).compactMap {$0.contents as? RecentMediaItem}
                    if let _ = gifItems.firstIndex(where: {$0.media.id == mediaId}) {
                        items.append(ContextMenuItem(L10n.messageContextRemoveGif, handler: {
                            let _ = removeSavedGif(postbox: account.postbox, mediaId: mediaId).start()
                        }))
                    } else {
                        items.append(ContextMenuItem(L10n.messageContextSaveGif, handler: {
                            let _ = addSavedGif(postbox: account.postbox, fileReference: FileMediaReference.message(message: MessageReference(message), media: file)).start()
                        }))
                    }
                }
                return items
            } |> mapToSignal { items in
                var items = items
                return account.postbox.mediaBox.resourceData(file.resource) |> deliverOnMainQueue |> mapToSignal { data in
                    if !file.isInteractiveMedia && !file.isVoice && !file.isMusic && !file.isStaticSticker && !file.isGraphicFile {
                        let quickLook = ContextMenuItem(L10n.contextOpenInQuickLook, handler: {
                            FastSettings.toggleOpenInQuickLook(fileExtenstion(file))
                        })
                        quickLook.state = FastSettings.openInQuickLook(fileExtenstion(file)) ? .on : .off
                        items.append(quickLook)
                    }
                   
                    if data.complete {
                        items.append(ContextMenuItem(tr(L10n.contextCopyMedia), handler: {
                            saveAs(file, account: account)
                        }))
                        
                        if !file.isVoice {
                            let path = data.path + "." + fileExtenstion(file)
                            try? FileManager.default.removeItem(atPath: path)
                            try? FileManager.default.linkItem(atPath: data.path, toPath: path)
                            let result = ObjcUtils.apps(forFileUrl: path)
                            if let result = result, !result.isEmpty {
                                let item = ContextMenuItem(L10n.messageContextOpenWith, handler: {})
                                let menu = NSMenu()
                                item.submenu = menu
                                for item in result {
                                    menu.addItem(ContextMenuItem(item.fullname, handler: {
                                        NSWorkspace.shared.openFile(path, withApplication: item.app.path)
                                    }, image: item.icon))
                                }
                                items.append(item)
                            }
                            
                        }
                    }
                    
                    if file.isStaticSticker, let fileId = file.id {
                        return account.postbox.transaction { transaction -> [ContextMenuItem] in
                            let saved = getIsStickerSaved(transaction: transaction, fileId: fileId)
                            items.append(ContextMenuItem( !saved ? tr(L10n.chatContextAddFavoriteSticker) : tr(L10n.chatContextRemoveFavoriteSticker), handler: {
                                
                                if !saved {
                                    _ = addSavedSticker(postbox: account.postbox, network: account.network, file: file).start()
                                } else {
                                    _ = removeSavedSticker(postbox: account.postbox, mediaId: fileId).start()
                                }
                            }))
                            
                            return items
                        }
                    }
                    
                    return .single(items)
                }
            }
            
            
        }
    } else if let image = message.media.first as? TelegramMediaImage {
        signal = signal |> mapToSignal { items -> Signal<[ContextMenuItem], NoError> in
            var items = items
            if let resource = image.representations.last?.resource {
                return account.postbox.mediaBox.resourceData(resource) |> take(1) |> deliverOnMainQueue |> map { data in
                    if data.complete {
                        items.append(ContextMenuItem(tr(L10n.galleryContextCopyToClipboard), handler: {
                            if let path = link(path: data.path, ext: "jpg") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.writeObjects([NSURL(fileURLWithPath: path)])
                            }
                        }))
                        items.append(ContextMenuItem(tr(L10n.contextCopyMedia), handler: {
                            savePanel(file: data.path, ext: "jpg", for: mainWindow)
                        }))
                    }
                    return items
                }
            } else {
                return .single(items)
            }
        }
    }
    
    
    signal = signal |> map { items in
        if let peer = chatInteraction.peer as? TelegramChannel, peer.isSupergroup {
            if peer.hasPermission(.banMembers), let author = message.author, author.id != account.peerId {
                var items = items
                items.append(ContextMenuItem(L10n.chatContextRestrict, handler: {
                    _ = showModalProgress(signal: fetchChannelParticipant(account: account, peerId: chatInteraction.peerId, participantId: author.id), for: mainWindow).start(next: { participant in
                        if let participant = participant {
                            switch participant {
                            case let .member(memberId, _, _, _, _):
                                showModal(with: RestrictedModalViewController(context, peerId: peerId, memberId: memberId, initialParticipant: participant, updated: { updatedRights in
                                    _ = context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: context.account, peerId: peerId, memberId: author.id, bannedRights: updatedRights).start()
                                }), for: context.window)
                            default:
                                break
                            }
                        }

                    })
                }))
                return items
            }
        }
        return items
    }
//
    signal = signal |> map { items in
        var items = items
        if canReportMessage(message, account) {
            items.append(ContextMenuItem(L10n.messageContextReport, handler: {
                _ = reportReasonSelector().start(next: { reason in
                    _ = showModalProgress(signal: reportPeerMessages(account: account, messageIds: [message.id], reason: reason), for: mainWindow).start()
                })
            }))
        }
        return items
    }
    
    return signal |> map { items in
        var items = items
        if let peer = peer, peer.isGroup || peer.isSupergroup, let author = message.author, !message.isScheduledMessage {
            items.append(ContextSeparatorItem())
            items.append(ContextMenuItem(L10n.chatServiceSearchAllMessages(author.compactDisplayTitle), handler: {
                chatInteraction.searchPeerMessages(author)
            }))
        }
        return items
    }
}
