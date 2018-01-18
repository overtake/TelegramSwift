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
    case Full(isAdmin: Bool)
    case Short
}

enum ChatItemRenderType {
    case bubble
    case list
}

func ==(lhs: ChatItemType, rhs: ChatItemType) -> Bool {
    switch lhs {
    case .Full(let isAdmin):
        if case .Full(isAdmin: isAdmin) = rhs {
            return true
        } else {
            return false
        }
    case .Short:
        if case .Short = rhs {
            return true
        } else {
            return false
        }
    }
}

class ChatRowItem: TableRowItem {
    
    private(set) var chatInteraction:ChatInteraction
    
    var account:Account!
    private(set) var peer:Peer?
    private(set) var entry:ChatHistoryEntry
    private(set) var message:Message?
    private(set) var itemType:ChatItemType = .Full(isAdmin: false)
    
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
   
    var fullDate:String?
    
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
        
        if let peer = peer as? TelegramChannel, case .broadcast = peer.info, !isUnsent {
            size.width += 0
        } else {
            if !isIncoming {
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
            size.width += editedLabel.0.size.width + 6
        }
        
        size.width = max(isBubbled ? size.width : 54, size.width)
        
        size.width += stateOverlayAdditionCorner * 2
        
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
        return file?.isSticker == true
    }
    

    override var height: CGFloat  {
        var height:CGFloat = self.contentSize.height + _defaultHeight
        if let captionLayout = captionLayout {
            height += captionLayout.layoutSize.height + defaultContentInnerInset
        }
        if let replyMarkupModel = replyMarkupModel {
            height += replyMarkupModel.size.height + defaultContentInnerInset
        }
        
        if isBubbled {
            if let additional = additionalLineForDateInBubbleState {
                height += additional
            }
   
            //height = max(height, 40)
           // height += 4
            //height = max(height, 48)
        }
        

        return max(rightSize.height + 8, height)
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
                if file.isSticker {
                    return isBubbled
                }
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
                if isIncoming && message.id.peerId == account.peerId {
                    return true
                }
                if !peer.isUser && !peer.isSecretChat && !peer.isChannel && isIncoming {
                    return true
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
                if let file = message?.media.first as? TelegramMediaFile {
                    apply = !file.isSticker && !file.isInstantVideo
                }
            }
            if apply {
                top += max(34, replyModel.size.height) + ((!isBubbleFullFilled && isBubbled && self is ChatMediaItem) ? 0 : 8)
                if authorText != nil && self is ChatMessageItem {
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
                    return chatInteraction.peerId == account.peerId && account.peerId != attr.messageId.peerId
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
    
    func share() {
        if let message = message {
            showModal(with: ShareModalController(ShareMessageObject(account, message)), for: mainWindow)
        }
    }
    
    var isSharable: Bool {
        var peers:[Peer] = []
        if let peer = peer {
            peers.append(peer)
        }
        if let info = message?.forwardInfo {
            peers.append(info.author)
            
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
                    return self is ChatMediaItem && !chatInteraction.isLogInteraction
                }
            }
        }
        
        return false
    }
    
    var isFailed: Bool {
        if let message = message {
            return message.flags.contains(.Failed)
        }
        return false
    }
    
    var isIncoming: Bool {
        if let message = message {
            return message.isIncoming(account, isBubbled)
        }
        return false
    }
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
        if let info = message?.forwardInfo {
            peers.append(info.author)
        }
        
        for peer in peers {
            if let peer = peer as? TelegramChannel {
                switch peer.info {
                case .broadcast:
                    return false
                default:
                    break
                }
            }
            if let peer = peer as? TelegramUser {
                if peer.botInfo != nil {
                    return false
                }
            }
        }
        
        if let message = message {
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
        
        return !chatInteraction.isLogInteraction && message?.groupingKey == nil
    }
    
    var isBubbled: Bool {
        return renderType == .bubble
    }
    var hasBubble: Bool {
        return isBubbled && ChatRowItem.hasBubble(message, type: itemType)
    }
    
    static func hasBubble(_ message: Message?, type: ChatItemType) -> Bool {
        if let message = message, let media = message.media.first {
            
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
            } else if let author = message.author, peer == nil {
                if author is TelegramSecretChat {
                    peer = messageMainPeer(message)
                } else {
                    peer = author
                }
            }
            
            if message.groupInfo != nil {
                return !message.text.isEmpty || message.replyAttribute != nil || message.forwardInfo != nil
            }
            
            if let file = media as? TelegramMediaFile {
                if file.isSticker {
                    return false
                }
                if file.isInstantVideo {
                    return false //!message.text.isEmpty || (message.replyAttribute != nil && !file.isInstantVideo) || (message.forwardInfo != nil && !file.isInstantVideo)
                }
            }
//            if media is TelegramMediaImage {
//                if case .Full = type {
//                    return true
//                }
//                return !message.text.isEmpty || message.replyAttribute != nil || message.forwardInfo != nil
//            }
        }
        return true
    }
    
    let renderType: ChatItemRenderType
    var modernBubbleImage:(CGImage, NSEdgeInsets)? = nil
    var selectedBubbleImage:(CGImage, NSEdgeInsets)? = nil

    init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account:Account, _ object: ChatHistoryEntry) {
        self.entry = object
        self.account = account
        self.chatInteraction = chatInteraction
        
        var message: Message?
        var isRead: Bool = true
        var itemType: ChatItemType = .Full(isAdmin: false)
        var fwdType: ForwardItemType? = nil
        var renderType:ChatItemRenderType = .list
        var object = object
        
        var captionMessage: Message? = object.message

        var hasGroupCaption: Bool = object.message?.text.isEmpty == false
        if case let .groupedPhotos(entries, _) = object {
            object = entries.last!
            
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
        
        if case let .MessageEntry(_message, _isRead, _renderType, _itemType, _fwdType, _) = object {
            message = _message
            isRead = _isRead
            itemType = _itemType
            fwdType = _fwdType
            renderType = _renderType
        }
        
        var isStateOverlayLayout: Bool {
            if renderType == .bubble, let message = captionMessage, let media = message.media.first {
                if let file = media as? TelegramMediaFile {
                    if file.isSticker {
                        return renderType == .bubble
                    }
                }
                if let media = media as? TelegramMediaMap {
                    return media.venue == nil
                }
                return media.isInteractiveMedia && !hasGroupCaption
            }
            return false
        }
        
        if message?.id.peerId == account.peerId {
            itemType = .Full(isAdmin: false)
        }
        self.renderType = renderType
        self.message = message
                
        if let message = message {
            
            let hasBubble = ChatRowItem.hasBubble(captionMessage ?? message, type: itemType)
            
            let isIncoming: Bool = message.isIncoming(account, renderType == .bubble)
            
           
            
            if case .bubble = renderType , hasBubble{
                let isFull: Bool
                if case .Full = itemType {
                    isFull = true
                    
                } else {
                    isFull = false
                }
                
                modernBubbleImage = messageBubbleImageModern(incoming: isIncoming, fillColor: theme.chat.backgroundColor(isIncoming), strokeColor: theme.chat.bubbleBorderColor(isIncoming), neighbors: isFull ? .none : .both)
                selectedBubbleImage = messageBubbleImageModern(incoming: isIncoming, fillColor: theme.chat.backgoundSelectedColor(isIncoming), strokeColor: theme.chat.backgoundSelectedColor(isIncoming), neighbors: isFull ? .none : .both)
            }
            
            self.itemType = itemType
            self.isRead = isRead
            
            self.peer = message.chatPeer
            
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
                        if !message.flags.contains(.Unsent), !message.flags.contains(.Failed) {
                            postAuthorAttributed = .initialize(string: attr.signature, color: isStateOverlayLayout ? .white : !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), font: renderType == .bubble ? .italic(.small) : .normal(.short))
                        }
                        break
                    }
                }
            }
            
            if let peer = messageMainPeer(message) as? TelegramUser, peer.botInfo != nil || peer.id == account.peerId {
                self.isRead = true
            }
            
            if let info = message.forwardInfo {
                
                
                var accept:Bool = !isHasSource && message.id.peerId != account.peerId
                
                if let media = message.media.first as? TelegramMediaFile {
                    for attr in media.attributes {
                        switch attr {
                        case .Sticker:
                            accept = false
                        case let .Audio(isVoice, _, _, _, _):
                            accept = isVoice && accept
                        default:
                            break
                        }
                    }
                }
                
                
                if accept {
                    forwardType = fwdType
                    var attr = NSMutableAttributedString()
                    if let source = info.source, source.isChannel {
                        var range = attr.append(string: source.displayTitle, color: theme.chat.linkColor(isIncoming), font: .medium(.text))
                        if info.author.id != source.id {
                            let subrange = attr.append(string: " (\(info.author.displayTitle))", color: theme.chat.linkColor(isIncoming), font: .medium(.text))
                            range.length += subrange.length
                        }
                        attr.add(link: inAppLink.peerInfo(peerId: source.id, action:nil, openChat: true, postId: nil, callback:chatInteraction.openInfo), for: range)
                        
                    } else {
                        let range = attr.append(string: info.author.displayTitle, color: theme.chat.linkColor(isIncoming), font: .medium(.text))
                        var linkAbility: Bool = true
                        if let channel = info.author as? TelegramChannel {
                            if channel.username == nil && channel.participationStatus != .member {
                                linkAbility = false
                            }
                        }
                        if linkAbility {
                            attr.add(link: inAppLink.peerInfo(peerId: info.author.id, action:nil, openChat: info.author.isChannel, postId: info.sourceMessageId?.id, callback:chatInteraction.openInfo), for: range)
                        }
                    }
                    
                    var isInstantVideo: Bool {
                        if let media = message.media.first as? TelegramMediaFile {
                            return media.isInstantVideo
                        }
                        return false
                    }
                    
                    let forwardNameColor: NSColor
                    if !hasBubble {
                        forwardNameColor = theme.colors.grayText
                    } else if isIncoming, theme.colors.name == dayClassic.name {
                        forwardNameColor = theme.chat.linkColor(isIncoming)
                    } else {
                        forwardNameColor = theme.chat.grayText(isIncoming || isInstantVideo)
                    }
                    
                    if renderType == .bubble {
                        
                        
                        
                        
                        let newAttr = parseMarkdownIntoAttributedString(L10n.chatBubblesForwardedFrom(attr.string), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.short), textColor:forwardNameColor), link: MarkdownAttributeSet(font: hasBubble ? .medium(.short) : .normal(.short), textColor: forwardNameColor), linkAttribute: { contents in
                            if let link = attr.attribute(NSAttributedStringKey.link, at: 0, effectiveRange: nil) {
                                return (NSAttributedStringKey.link.rawValue, link)
                            }
                            return nil
                        }))
                        attr = newAttr.mutableCopy() as! NSMutableAttributedString
                    } else {
                        _ = attr.append(string: " ")
                        _ = attr.append(string: DateUtils.string(forLastSeen: info.date), color: forwardNameColor, font: .normal(.short))
                    }

                    
                    forwardNameLayout = TextViewLayout(attr, maximumNumberOfLines: renderType == .bubble ? 2 : 1, truncationType: .end)
                    forwardNameLayout?.interactions = globalLinkExecutor
                }
            }
            
            if case .Full(let isAdmin) = itemType {
                
                var canFillAuthorName: Bool = true
                if renderType == .bubble, let peer = messageMainPeer(message) {
                    canFillAuthorName = isIncoming && (peer.isGroup || peer.isSupergroup || message.id.peerId == account.peerId)
                    if let media = message.media.first {
                        canFillAuthorName = canFillAuthorName && !media.isInteractiveMedia && hasBubble && isIncoming
                    }
                }
                
                var titlePeer:Peer? = self.peer
                
                var title:String = peer?.displayTitle ?? ""
                if let peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info {
                    title = peer.displayTitle
                    titlePeer = peer
                }
                
                let attr:NSMutableAttributedString = NSMutableAttributedString()
                
                if let peer = titlePeer {
                    var nameColor:NSColor = theme.chat.linkColor(isIncoming)
                    
                    if messageMainPeer(message) is TelegramChannel || messageMainPeer(message) is TelegramGroup {
                        if let peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info {
                            nameColor = theme.chat.linkColor(isIncoming)
                        } else if account.peerId != peer.id {
                            let value = abs(Int(peer.id.id) % 7)
                            nameColor = theme.chat.peerName(value)
                        }
                    }
                    if canFillAuthorName {
                        let range = attr.append(string: title, color: nameColor, font: .medium(.text))
                        attr.addAttribute(NSAttributedStringKey.link, value: inAppLink.peerInfo(peerId:peer.id, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), range: range)
                    }
                    
                    
                    for attribute in message.attributes {
                        if let attribute = attribute as? InlineBotMessageAttribute, let bot = message.peers[attribute.peerId] as? TelegramUser, let address = bot.username {
                            if attr.length > 0 {
                                _ = attr.append(string: " ")
                            }
                            _ = attr.append(string: "\(tr(L10n.chatMessageVia)) ", color: !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), font:.medium(.text))
                            let range = attr.append(string: "@" + address, color: theme.chat.linkColor(isIncoming), font:.medium(.text))
                            attr.addAttribute(NSAttributedStringKey.link, value: inAppLink.callback("@" + address, { (parameter) in
                                chatInteraction.updateInput(with: parameter + " ")
                            }), range: range)
                        }
                    }
                    
                    if isAdmin, canFillAuthorName {
                        _ = attr.append(string: " \(tr(L10n.chatAdminBadge))", color: !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), font: .normal(.short))
                    }
                    if attr.length > 0 {
                        authorText = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                        authorText?.interactions = globalLinkExecutor
                    }
                }
                
            }
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= account.context.timeDifference
            date = TextNode.layoutText(maybeNode: nil, .initialize(string: DateUtils.string(forShortTime: Int32(time)), color: isStateOverlayLayout ? .white : (!hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming)), font: renderType == .bubble ? .italic(.small) : .normal(.short)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .left)

        }
        
        super.init(initialSize)
        
        if let message = message {
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            formatter.locale = Locale(identifier: appCurrentLanguage.languageCode)
            var fullDate: String = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp) - account.context.timeDifference))
            
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyMessageAttribute  {
                    let replyPresentation = ChatAccessoryPresentation(background: hasBubble ? theme.chat.backgroundColor(isIncoming) : isBubbled ?   theme.colors.grayForeground : theme.colors.background, title: theme.chat.replyTitle(self), enabledText: theme.chat.replyText(self), disabledText: theme.chat.replyDisabledText(self), border: theme.chat.replyTitle(self))
                    
                    self.replyModel = ReplyModel(replyMessageId: attribute.messageId, account:account, replyMessage:message.associatedMessages[attribute.messageId], presentation: replyPresentation, makesizeCallback: { [weak self] in
                        guard let strongSelf = self else {return}
                        _ = strongSelf.makeSize(strongSelf.width, oldWidth: 0)
                         strongSelf.redraw()
                    })
                    replyModel?.isSideAccessory = isBubbled && !hasBubble
                }
                if let attribute = attribute as? ViewCountMessageAttribute {
                    channelViewsAttributed = .initialize(string: attribute.count.prettyNumber, color: isStateOverlayLayout ? .white : !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), font: renderType == .bubble ? .italic(.small) : .normal(.short))
                    
                    if attribute.count >= 1000 {
                        fullDate = "\(attribute.count.separatedNumber) \(tr(L10n.chatMessageTooltipViews)), \(fullDate)"
                    }
                }
                if let attribute = attribute as? EditedMessageAttribute {
                    if isEditMarkVisible {
                        editedLabel = TextNode.layoutText(maybeNode: nil, .initialize(string: tr(L10n.chatMessageEdited), color: isStateOverlayLayout ? .white : !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), font: renderType == .bubble ? .italic(.small) : .normal(.short)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .left)
                    }
                    
                    let formatterEdited = DateFormatter()
                    formatterEdited.dateStyle = .short
                    formatterEdited.timeStyle = .medium
                    formatterEdited.locale = Locale(identifier: appCurrentLanguage.languageCode)
                    fullDate = "\(fullDate) (\(formatterEdited.string(from: Date(timeIntervalSince1970: TimeInterval(attribute.date)))))"
                }
                if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline) {
                    replyMarkupModel = ReplyMarkupNode(attribute.rows, attribute.flags, chatInteraction.processBotKeyboard(with: message))
                }
            }
            
            
            self.fullDate = fullDate
        }
    }
    
    init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ entry: ChatHistoryEntry) {
        self.entry = entry
        self.message = entry.message
        self.chatInteraction = chatInteraction
        self.renderType = entry.renderType
        super.init(initialSize)
    }
    
    public static func item(_ initialSize:NSSize, from entry:ChatHistoryEntry, with account:Account, interaction:ChatInteraction) -> ChatRowItem {
        
        if let message = entry.message {
            if message.media.count == 0 || (message.media.count == 1 && message.media[0] is TelegramMediaWebpage) {
                return ChatMessageItem(initialSize, interaction, account,entry)
            } else {
                if message.id.peerId.namespace == Namespaces.Peer.CloudUser, let _ = message.autoremoveAttribute {
                    return ChatServiceItem(initialSize,interaction,account,entry)
                } else if let file = message.media[0] as? TelegramMediaFile {
                    if file.isInstantVideo {
                        return ChatVideoMessageItem(initialSize,interaction,account,entry)
                    } else if file.isVideo && !file.isAnimated {
                        return ChatMediaItem(initialSize,interaction,account,entry)
                    } else if file.isSticker {
                        return ChatMediaItem(initialSize,interaction,account,entry)
                    } else if file.isVoice {
                        return ChatVoiceRowItem(initialSize,interaction,account,entry)
                    } else if file.isVideo && file.isAnimated {
                        return ChatGIFMediaItem(initialSize,interaction,account,entry)
                    } else if !file.isVideo && file.isAnimated {
                        return ChatMediaItem(initialSize,interaction,account,entry)
                    } else if file.isMusic {
                        return ChatMusicRowItem(initialSize,interaction,account,entry)
                    }
                    return ChatFileMediaItem(initialSize,interaction,account,entry)
                } else if let action = message.media[0] as? TelegramMediaAction {
                    switch action.action {
                    case .phoneCall:
                        return ChatCallRowItem(initialSize, interaction, account, entry)
                    default:
                        return ChatServiceItem(initialSize, interaction, account, entry)
                    }
                    
                } else if message.media[0] is TelegramMediaMap {
                    return ChatMapRowItem(initialSize,interaction,account,entry)
                } else if message.media[0] is TelegramMediaContact {
                    return ChatContactRowItem(initialSize,interaction,account,entry)
                } else if message.media[0] is TelegramMediaInvoice {
                    return ChatInvoiceItem(initialSize,interaction,account,entry)
                } else if message.media[0] is TelegramMediaExpiredContent {
                    return ChatServiceItem(initialSize,interaction,account,entry)
                } else if message.media.first is TelegramMediaGame {
                    return ChatMessageItem(initialSize, interaction, account, entry)
                }
                
                return ChatMediaItem(initialSize,interaction,account,entry)
            }
            
        }
        
        fatalError("no item for entry")
        
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        

        isForceRightLine = false
        
        if let channelViewsAttributed = channelViewsAttributed {
            channelViews = TextNode.layoutText(maybeNode: channelViewsNode, channelViewsAttributed, !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), 1, .end, NSMakeSize(hasBubble ? 60 : max(150,width - contentOffset.x - 44 - 150), 20), nil, false, .left)
        }
        if let postAuthorAttributed = postAuthorAttributed {
            postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), 1, .end, NSMakeSize(hasBubble ? 60 : (width - contentOffset.x - 44) / 2, 20), nil, false, .left)
        }

       
        var widthForContent: CGFloat = blockWidth
        
        _contentSize = self.makeContentSize(widthForContent)

        if hasBubble {
            func layout() -> Bool {
                if additionalLineForDateInBubbleState == nil && !isFixedRightPosition {
                    if _contentSize.width + rightSize.width + insetBetweenContentAndDate > widthForContent {
                        widthForContent = _contentSize.width - 5
                        self.isForceRightLine = true
                        //_contentSize = self.makeContentSize(widthForContent)
                        return true
                    }
                }
                return true
            }
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
        
        authorText?.measure(width: widthForContent)

        
        if let forwardNameLayout = forwardNameLayout {
            var w = widthForContent
            if isBubbled && !hasBubble {
                w = width - _contentSize.width - 70
            }
            forwardNameLayout.measure(width: w)
        }
        
        if forwardType == .FullHeader || forwardType == .ShortHeader {
            forwardHeader = TextNode.layoutText(maybeNode: forwardHeaderNode, .initialize(string: tr(L10n.messagesForwardHeader), color: !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), font: .normal(.text)), nil, 1, .end, NSMakeSize(width - self.contentOffset.x - 44, 20), nil,false, .left)
        } else {
            forwardHeader = nil
        }
        
        if !isBubbled {
            replyModel?.measureSize(widthForContent, sizeToFit: true)
        } else {
            if let item = self as? ChatMessageItem, item.webpageLayout == nil {
                replyModel?.measureSize(widthForContent, sizeToFit: true)
            } else {
                if !hasBubble {
                    replyModel?.measureSize(min(width - _contentSize.width - contentOffset.x - 100, 300), sizeToFit: true)
                } else {
                    replyModel?.measureSize(widthForContent, sizeToFit: true)
                }
            }
        }
        
        
        if isBubbled {
            replyMarkupModel?.measureSize(bubbleFrame.width - additionBubbleInset)
        } else {
            if !(self is ChatMessageItem) {
                replyMarkupModel?.measureSize(_contentSize.width)
            } else {
                replyMarkupModel?.measureSize(max(_contentSize.width, blockWidth))
            }
        }
        
        if isBubbled {
            if let postAuthor = postAuthor, let postAuthorAttributed = postAuthorAttributed {
                let size = rightSize.width - postAuthor.0.size.width - 8
                self.postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), 1, .end, NSMakeSize( _contentSize.width - size - bubbleContentInset - additionBubbleInset - 10, 20), nil, false, .left)
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
                    self.postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? theme.colors.grayText : theme.chat.grayText(isIncoming), 1, .end, NSMakeSize( w, 20), nil, false, .left)
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
        
        return super.makeSize(width, oldWidth: oldWidth)
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
        let nameWidth = hasBubble ? (authorText?.layoutSize.width ?? 0) : 0
        let forwardWidth = hasBubble ? (forwardNameLayout?.layoutSize.width ?? 0) : 0
        let replyWidth = hasBubble ? (replyModel?.size.width ?? 0) : 0

        var rect = NSMakeRect(defLeftInset, 1, contentSize.width, height - 2)
        
       
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
        
        rect.size.width = max(rect.size.width, replyWidth  + bubbleDefaultInnerInset)
        
        rect.size.width = max(rect.size.width, forwardWidth  + bubbleDefaultInnerInset)
        
        return rect
    }
    
    var isFixedRightPosition: Bool {
        return additionalLineForDateInBubbleState != nil
    }
    
    var additionalLineForDateInBubbleState: CGFloat? {
        return isForceRightLine ? rightSize.height : nil
    }
    
    func deleteMessage() {
        _ = account.postbox.modify { [weak message] modifier -> Void in
            if let message = message {
                modifier.deleteMessages([message.id])
            }
        }.start()
    }
    
    func resendMessage() {
        if let message = message {
            _ = resendMessages(account: account, messageIds: [message.id]).start()
        }
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
            if let message = message, canEditMessage(message, account: account) {
                chatInteraction.beginEditingMessage(message)
                return true
            }
        }
        return false
    }
    func forwardAction() -> Bool {
        if chatInteraction.presentation.state != .selecting, let message = message {
            if canForwardMessage(message, account: account) {
                chatInteraction.forwardMessages([message.id])
                return true
            }
        }
        return false
    }
    
    override var instantlyResize: Bool {
        return forwardType != nil
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        if chatInteraction.disableSelectAbility {
            return super.menuItems(in: location)
        }
        if let message = message, let peer = peer {
            return chatMenuItems(for: message, account: account, chatInteraction: chatInteraction, peer: peer)
        }
        return super.menuItems(in: location)
    }
}

func chatMenuItems(for message: Message, account: Account, chatInteraction: ChatInteraction, peer: Peer) -> Signal<[ContextMenuItem], Void> {
    
    if chatInteraction.isLogInteraction || chatInteraction.presentation.state == .selecting {
        return .single([])
    }
    
    var items:[ContextMenuItem] = []
    
    if peer.canSendMessage, chatInteraction.peerId == message.id.peerId {
        items.append(ContextMenuItem(tr(L10n.messageContextReply1) + (FastSettings.tooltipAbility(for: .edit) ? " (\(tr(L10n.messageContextReplyHelp)))" : ""), handler: {
            chatInteraction.setupReplyMessage(message.id)
        }))
    }
    
    if let peer = message.peers[message.id.peerId] as? TelegramChannel {
        if let address = peer.addressName {
            items.append(ContextMenuItem(tr(L10n.messageContextCopyMessageLink), handler: {
                copyToClipboard("t.me/\(address)/\(message.id.id)")
            }))
        }
        
    }
    
    items.append(ContextSeparatorItem())
    
    if let peer = message.peers[message.id.peerId] as? TelegramChannel, peer.hasAdminRights(.canPinMessages) || (peer.isChannel && peer.hasAdminRights(.canEditMessages)) {
        items.append(ContextMenuItem(tr(L10n.messageContextPin), handler: {
            if peer.isSupergroup {
                confirm(for: mainWindow, information: tr(L10n.messageContextConfirmPin), thridTitle: tr(L10n.messageContextConfirmOnlyPin), successHandler: { result in
                    chatInteraction.updatePinned(message.id, false, result == .thrid)
                })
            } else {
                chatInteraction.updatePinned(message.id, false, true)
            }
        }))
    }
    
    if canEditMessage(message, account:account) {
        items.append(ContextMenuItem(tr(L10n.messageContextEdit), handler: {
            chatInteraction.beginEditingMessage(message)
        }))
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
        items.append(ContextSeparatorItem())
        items.append(ContextMenuItem(tr(L10n.messageContextForwardToCloud), handler: {
            _ = Sender.forwardMessages(messageIds: [message.id], account: account, peerId: account.peerId).start()
        }))
    }
    
    
    for media in message.media {
        if let file = media as? TelegramMediaFile {
            if file.isVideo && file.isAnimated {
                
                if !canForwardMessage(message, account: account) {
                    items.append(ContextSeparatorItem())
                }
                
                items.append(ContextMenuItem(tr(L10n.messageContextSaveGif), handler: {
                    let _ = addSavedGif(postbox: account.postbox, file: file).start()
                }))
            }
        }
    }
    
    let signal:Signal<[ContextMenuItem], Void> = .single(items)
    
    if let file = message.media.first as? TelegramMediaFile {
        return signal |> mapToSignal { items -> Signal<[ContextMenuItem], Void> in
            var items = items
            return account.postbox.mediaBox.resourceData(file.resource) |> deliverOnMainQueue |> mapToSignal { data in
                if data.complete {
                    items.append(ContextMenuItem(tr(L10n.contextCopyMedia), handler: {
                        saveAs(file, account: account)
                    }))
                }
                
                if file.isSticker, let fileId = file.id {
                    return account.postbox.modify { modifier -> [ContextMenuItem] in
                        let saved = getIsStickerSaved(modifier: modifier, fileId: fileId)
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
    } else if let image = message.media.first as? TelegramMediaImage {
        return signal |> mapToSignal { items -> Signal<[ContextMenuItem], Void> in
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
    
    return signal
}
