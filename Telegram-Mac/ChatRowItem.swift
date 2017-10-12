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



let userChatColors:[Int:NSColor] = {
    var colors:[Int:NSColor] = [:]
    colors[0] = NSColor(0xce5247);
    colors[1] = NSColor(0xcda322);
    colors[2] = NSColor(0x5eaf33);
    colors[3] = NSColor(0x468ec4);
    colors[4] = NSColor(0xac6bc8);
    colors[5] = NSColor(0xe28941);
    return colors
}()


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
    private(set) var fontSize:Int32 = 13
    private(set) var itemType:ChatItemType = .Full(isAdmin: false)

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
    let defaultContentTopOffset:CGFloat = 6
    
    var rightInset:CGFloat {
        return chatInteraction.presentation.selectionState != nil ? 42.0 : 20.0
    }
    let leftInset:CGFloat = 20

    
    var _defaultHeight:CGFloat {
        return self.contentOffset.y + defaultContentTopOffset
    }
    
    var _contentSize:NSSize = NSZeroSize;
    
    public var blockSize:NSSize {
        return NSMakeSize(width - contentOffset.x - rightSize.width - 44, height)
    }
    
    public var rightSize:NSSize {
        
        var size:NSSize = NSZeroSize
        
        if let date = date {
            size = NSMakeSize(date.0.size.width, 16)
        }
        
        if let message = message {
            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                size.width += 0
            } else {
                if !message.flags.contains(.Incoming) {
                    size.width += 20
                }
            }

            
            if let channelViews = channelViews {
                size.width += channelViews.0.size.width + 8 + 16
            }
            if let postAuthor = postAuthor {
                size.width += postAuthor.0.size.width + 8
            }
            
            if let editedLabel = editedLabel {
                size.width += editedLabel.0.size.width + 8
            }
        }
        
        size.width = max(50,size.width)
        
        return size
        
    }
    
    public var contentSize:NSSize {
        return _contentSize
    }
    

    override var height: CGFloat  {
        var height:CGFloat = self.contentSize.height + _defaultHeight
        if let captionLayout = captionLayout {
            height += captionLayout.layoutSize.height + defaultContentTopOffset
        }
        if let replyMarkupModel = replyMarkupModel {
            height += replyMarkupModel.size.height + defaultContentTopOffset
        }

        return max(rightSize.height + 8, height)
    }
    
    var replyOffset:CGFloat {
        var top:CGFloat = defaultContentTopOffset
        
        if let author = authorText {
            top += author.layoutSize.height + defaultContentTopOffset
        }
        
        return top
    }
    
    var forwardHeaderInset:NSPoint {
        
        var top:CGFloat = 0
        
        if let author = authorText {
            top += author.layoutSize.height + 7
        }
        
        return NSMakePoint(defLeftInset, top)
    }
    
    var forwardNameInset:NSPoint {
        
        var top:CGFloat = forwardHeaderInset.y + 4
        
        if let header = forwardHeader {
            top += header.0.size.height + 4
        }
        
        return NSMakePoint(self.contentOffset.x, top)
    }
    
    var gameInset: NSPoint {
        return NSMakePoint(contentOffset.x - 10, contentOffset.y)
    }
    
    var defLeftInset:CGFloat {
        return leftInset + 36 + 10
    }
    
    var contentOffset:NSPoint {
        
        var left:CGFloat = defLeftInset
        
        var top:CGFloat = defaultContentTopOffset
        
        if let author = authorText {
            top += author.layoutSize.height + topInset
        }
        
        if let replyModel = replyModel {
            top += max(34, replyModel.size.height) + 8
        }
        
        if let forwardNameLayout = forwardNameLayout {
            top += forwardNameLayout.layoutSize.height + topInset
        }
        
        if let forwardType = forwardType {
            if forwardType == .FullHeader || forwardType == .ShortHeader {
                if let forwardHeader = forwardHeader {
                    top += forwardHeader.0.size.height + 6
                }
            } else {
                if self is ChatMessageItem {
                    top -= topInset
                }
            }

        }
        
        
        if forwardNameLayout != nil {
            left += 10
        }
        
        if isGame {
            left += 10
        }
        
        return NSMakePoint(left, top)
    }
    
    private(set) var isRead:Bool = false
    private(set) var isGame:Bool = false
    
    override var stableId: AnyHashable {
        return entry.stableId
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
        
        return !chatInteraction.isLogInteraction
    }
    
    init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account:Account, _ object: ChatHistoryEntry) {
        self.entry = object
        self.account = account
        self.chatInteraction = chatInteraction
        
        if case let .MessageEntry(message,isRead,itemType, fwdType, _) = object {
            
            self.itemType = itemType
            self.message = message
            self.isRead = isRead
            self.isGame = message.media.first is TelegramMediaGame
            if let peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info {
                self.peer = peer
                
                if let author = message.author, author.id != peer.id, !message.flags.contains(.Unsent), !message.flags.contains(.Failed) {
                    postAuthorAttributed = .initialize(string: author.displayTitle, color: theme.colors.grayText, font: NSFont.normal(.short))
                }
                
            } else if let author = message.author {
                if author is TelegramSecretChat {
                    peer = messageMainPeer(message)
                } else {
                    peer = author
                }
            }
            
            if let peer = messageMainPeer(message) as? TelegramUser, peer.botInfo != nil || peer.id == account.peerId {
                self.isRead = true
            }
            
            if let info = message.forwardInfo {
                
                var accept:Bool = true
                
                if let media = message.media.first as? TelegramMediaFile {
                    for attr in media.attributes {
                        switch attr {
                        case .Sticker:
                            accept = false
                        case let .Audio(isVoice, _, _, _, _):
                            accept = isVoice
                        default:
                            break
                        }
                    }
                }
                
                if accept {
                    forwardType = fwdType
                    let attr = NSMutableAttributedString()
                    if let source = info.source, source.isChannel {
                        var range = attr.append(string: source.displayTitle, color: theme.colors.link, font: .medium(.text))
                        if info.author.id != source.id {
                            let subrange = attr.append(string: " (\(info.author.displayTitle))", color: theme.colors.link, font: .medium(.text))
                            range.length += subrange.length
                        }
                        attr.add(link: inAppLink.peerInfo(peerId: source.id, action:nil, openChat: true, postId: nil, callback:chatInteraction.openInfo), for: range)
                        
                    } else {
                        let range = attr.append(string: info.author.displayTitle, color: theme.colors.link, font: .medium(.text))
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
                    
                    
                    
                    _ = attr.append(string: " ")
                    _ = attr.append(string: DateUtils.string(forLastSeen: info.date), color: theme.colors.grayText, font: .normal(.short))
                    
                    forwardNameLayout = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end)
                    forwardNameLayout?.interactions = globalLinkExecutor
                } 
            }
            
            if case .Full(let isAdmin) = itemType {
                
                var titlePeer:Peer? = self.peer
                
                var title:String = peer?.displayTitle ?? ""
                if let peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info {
                    title = peer.displayTitle
                    titlePeer = peer
                }
                
                let attr:NSMutableAttributedString = NSMutableAttributedString()
                
                if let peer = titlePeer {
                    var nameColor:NSColor = theme.colors.link
                    
                    if messageMainPeer(message) is TelegramChannel || messageMainPeer(message) is TelegramGroup {
                        if let peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info {
                            nameColor = theme.colors.link
                        } else if account.peerId != peer.id {
                            let value = ObjcUtils.colorMask(peer.id.id, mainId: account.peerId.id)
                            nameColor = userChatColors[Int(value) % userChatColors.count] ?? theme.colors.blueText
                        }
                    }
                    
                    let range = attr.append(string: title, color: nameColor, font:.medium(.text))
                    attr.addAttribute(NSAttributedStringKey.link, value: inAppLink.peerInfo(peerId:peer.id, action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), range: range)
                    
                    
                    for attribute in message.attributes {
                        if let attribute = attribute as? InlineBotMessageAttribute, let bot = message.peers[attribute.peerId] as? TelegramUser, let address = bot.username {
                            _ = attr.append(string: " \(tr(.chatMessageVia)) ", color: theme.colors.grayText, font:.medium(.text))
                            let range = attr.append(string: "@" + address, color: theme.colors.blueText, font:.medium(.text))
                            attr.addAttribute(NSAttributedStringKey.link, value: inAppLink.callback("@" + address, { (parameter) in
                                chatInteraction.updateInput(with: parameter + " ")
                            }), range: range)
                        }
                    }
                    
                    if isAdmin {
                        _ = attr.append(string: " \(tr(.chatAdminBadge))", color: theme.colors.grayText, font: .normal(.short))
                    }
                    
                    authorText = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                    
                    authorText?.interactions = globalLinkExecutor

                }
            }
            var time:TimeInterval = TimeInterval(message.timestamp)
            time -= account.context.timeDifference
            date = TextNode.layoutText(maybeNode: nil,  NSAttributedString.initialize(string: DateUtils.string(forMessageListDate: Int32(time)), color: theme.colors.grayText, font: NSFont.normal(.short)), nil, 1, .end, NSMakeSize(CGFloat.greatestFiniteMagnitude, 20), nil, false, .left)
            
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
                    self.replyModel = ReplyModel(replyMessageId: attribute.messageId, account:account, replyMessage:message.associatedMessages[attribute.messageId])
                }
                if let attribute = attribute as? ViewCountMessageAttribute {
                    channelViewsAttributed = NSAttributedString.initialize(string: attribute.count.prettyNumber, color: theme.colors.grayText, font: NSFont.normal(.short))
                }
                if let attribute = attribute as? EditedMessageAttribute {
                    if isEditMarkVisible {
                        editedLabel = TextNode.layoutText(maybeNode: nil,  NSAttributedString.initialize(string: tr(.chatMessageEdited), color: theme.colors.grayText, font: NSFont.normal(.short)), nil, 1, .end, NSMakeSize(CGFloat.greatestFiniteMagnitude, 20), nil, false, .left)
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
                }
                
                return ChatMediaItem(initialSize,interaction,account,entry)
            }
            
        }
        
        fatalError("no item for entry")
        
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        

        
        if let channelViewsAttributed = channelViewsAttributed {
            channelViews = TextNode.layoutText(maybeNode: channelViewsNode, channelViewsAttributed, theme.colors.grayText, 1, .end, NSMakeSize(max(150,width - contentOffset.x - 44 - 150), 20), nil, false, .left)
        }
        if let postAuthorAttributed = postAuthorAttributed {
            postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, theme.colors.grayText, 1, .end, NSMakeSize((width - contentOffset.x - 44) / 2, 20), nil, false, .left)
        }
        //let additionWidth:CGFloat = date?.0.size.width ?? 20
       // _contentSize = self.makeContentSize(width - self.contentOffset.x - rightSize.width - 44)
        
        if case .Full = itemType {
            let additionWidth:CGFloat = date?.0.size.width ?? 20
            _contentSize = self.makeContentSize(width - self.contentOffset.x - 44 - additionWidth)
        } else {
            _contentSize = self.makeContentSize(width - self.contentOffset.x - rightSize.width - 44)
        }
        
        if let captionLayout = captionLayout {
            captionLayout.measure(width: _contentSize.width)
        }
        
        authorText?.measure(width: blockSize.width)

        
        if let forwardNameLayout = forwardNameLayout {
            forwardNameLayout.measure(width: width - self.contentOffset.x - rightSize.width - 20)
        }
        
        if forwardType == .FullHeader || forwardType == .ShortHeader {
            forwardHeader = TextNode.layoutText(maybeNode: forwardHeaderNode, NSAttributedString.initialize(string: tr(.messagesForwardHeader), color: theme.colors.grayText, font: NSFont.normal(FontSize.text)), nil, 1, .end, NSMakeSize(width - self.contentOffset.x - 44, 20), nil,false, .left)
        } else {
            forwardHeader = nil
        }
        

        replyModel?.measureSize(width - self.contentOffset.x - 44)
        
        if !(self is ChatMessageItem) {
            replyMarkupModel?.measureSize(_contentSize.width)
        } else {
            replyMarkupModel?.measureSize(max(_contentSize.width, blockSize.width))
        }

        
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
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
    
    override func menuItems() -> Signal<[ContextMenuItem], Void> {
        
        if self.chatInteraction.isLogInteraction {
            return .single([])
        }
        
        var items:[ContextMenuItem] = []
        let chatInteraction = self.chatInteraction
        if chatInteraction.presentation.state != .selecting {
            if let message = message, let peer = peer {
                let account = self.account!
                
                if peer.canSendMessage {
                    items.append(ContextMenuItem(tr(.messageContextReply), handler: {
                        chatInteraction.setupReplyMessage(message.id)
                    }))
                }
                
                if let peer = message.peers[message.id.peerId] as? TelegramChannel, peer.isSupergroup {
                    if let address = peer.addressName {
                        items.append(ContextMenuItem(tr(.messageContextCopyMessageLink), handler: {
                            copyToClipboard("t.me/\(address)/\(message.id.id)")
                        }))
                    }
                    if peer.hasAdminRights(.canPinMessages) {
                        items.append(ContextMenuItem(tr(.messageContextPin), handler: {
                            confirm(for: mainWindow, with: appName, and: tr(.messageContextConfirmPin), thridTitle: tr(.messageContextConfirmOnlyPin), successHandler: { result in
                                chatInteraction.updatePinned(message.id, false, result == .thrid)
                            })
                        }))
                    }
                }
                
                items.append(ContextSeparatorItem())
                
                if canEditMessage(message, account:account) {
                    items.append(ContextMenuItem(tr(.messageContextEdit), handler: {
                        chatInteraction.beginEditingMessage(message)
                    }))
                }
                
                if canForwardMessage(message, account: account) {
                    items.append(ContextMenuItem(tr(.messageContextForward), handler: {
                        chatInteraction.forwardMessages([message.id])
                    }))
                }
               
                if canDeleteMessage(message, account: account) {
                    items.append(ContextMenuItem(tr(.messageContextDelete), handler: {
                        chatInteraction.deleteMessages([message.id])
                    }))
                }
                
                
                items.append(ContextMenuItem(tr(.messageContextSelect), handler: {
                    chatInteraction.update({$0.withToggledSelectedMessage(message.id)})
                }))
                

                if canForwardMessage(message, account: account) {
                    items.append(ContextSeparatorItem())
                    items.append(ContextMenuItem(tr(.messageContextForwardToCloud), handler: {
                        _ = Sender.forwardMessages(messageIds: [message.id], account: account, peerId: account.peerId).start()
                    }))
                    
                }
 
                
                for media in message.media {
                    if let file = media as? TelegramMediaFile {
                        if file.isVideo && file.isAnimated {
                            
                            if !canForwardMessage(message, account: account) {
                                items.append(ContextSeparatorItem())
                            }
                            
                            items.append(ContextMenuItem(tr(.messageContextSaveGif), handler: {
                                let _ = addSavedGif(postbox: account.postbox, file: file).start()
                            }))
                        }
                    }
                }
                
            }
        }
        
        return .single(items)
    }
}


