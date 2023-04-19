//
//  ShareModalController.swift
//  TelegramMac
//
//  Created by keepcoder on 20/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Localization
import Postbox
import TGModernGrowingTextView
import KeyboardKey
import InAppSettings

fileprivate class ShareButton : Control {
    private var badge: BadgeNode?
    private var badgeView: View = View()
    private let shareText = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(badgeView)
        addSubview(shareText)
        let layout = TextViewLayout(.initialize(string: strings().modalShare.uppercased(), color: .white, font: .normal(.header)), maximumNumberOfLines: 1)
        layout.measure(width: .greatestFiniteMagnitude)
        shareText.update(layout)
        setFrameSize(NSMakeSize(22 + shareText.frame.width + 47, 41))
        layer?.cornerRadius = 20
        set(background: theme.colors.accent, for: .Hover)
        set(background: theme.colors.accent, for: .Normal)
        set(background: theme.colors.accent, for: .Highlight)
        shareText.backgroundColor = theme.colors.accent
        needsLayout = true
        updateCount(0)
        shareText.userInteractionEnabled = false
        shareText.isSelectable = false

    }
    
    override func layout() {
        super.layout()
        shareText.centerY(x: 22)
        shareText.setFrameOrigin(22, shareText.frame.minY + 2)
        badgeView.centerY(x: shareText.frame.maxX + 9)
        
    }
    
    func updateCount(_ count:Int) -> Void {
        badge = BadgeNode(.initialize(string: "\(max(count, 1))", color: theme.colors.accent, font: .medium(.small)), .white)
        badgeView.setFrameSize(badge!.size)
        badge?.view = badgeView
        badge?.setNeedDisplay()
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate class ShareModalView : Control, TokenizedProtocol {
    let tokenizedView:TokenizedView
    let basicSearchView: SearchView = SearchView(frame: NSMakeRect(0,0, 260, 30))
    let tableView:TableView = TableView()
    fileprivate let share:ImageButton = ImageButton()
    fileprivate let dismiss:ImageButton = ImageButton()

    
    fileprivate let textView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    fileprivate let sendButton = ImageButton()
    fileprivate let emojiButton = ImageButton()
    fileprivate let actionsContainerView: Control = Control()
    fileprivate let textContainerView: View = View()
    fileprivate let bottomSeparator: View = View()

    fileprivate var sendWithoutSound: (()->Void)? = nil
    fileprivate var scheduleMessage: (()->Void)? = nil
    fileprivate var scheduleWhenOnline: (()->Void)? = nil

    private let topSeparator = View()
    fileprivate var hasShareMenu: Bool = true {
        didSet {
            share.isHidden = !hasShareMenu
            needsLayout = true
        }
    }
    
    
    required init(frame frameRect: NSRect, shareObject: ShareObject) {
        tokenizedView = TokenizedView(frame: NSMakeRect(0, 0, 300, 30), localizationFunc: { key in
            return translate(key: key, [])
        }, placeholderKey: shareObject.searchPlaceholderKey)
        super.init(frame: frameRect)
        
        backgroundColor = theme.colors.background
        textContainerView.backgroundColor = theme.colors.background
        actionsContainerView.backgroundColor = theme.colors.background
        textView.setBackgroundColor(theme.colors.background)
        
        addSubview(tokenizedView)
        addSubview(basicSearchView)
        addSubview(tableView)
        addSubview(topSeparator)
        tokenizedView.delegate = self
        bottomSeparator.backgroundColor = theme.colors.border
        topSeparator.backgroundColor = theme.colors.border
        
        self.backgroundColor = theme.colors.background
        
        dismiss.disableActions()
        share.disableActions()

        
        addSubview(share)
        addSubview(dismiss)
        
        
        sendButton.contextMenu = { [weak self] in
            
            
            var items:[ContextMenuItem] = []

            items.append(ContextMenuItem(strings().chatSendWithoutSound, handler: {
                self?.sendWithoutSound?()
            }, itemImage: MenuAnimation.menu_mute.value))
            
            items.append(ContextMenuItem(strings().chatSendScheduledMessage, handler: {
                self?.scheduleMessage?()
            }, itemImage: MenuAnimation.menu_schedule_message.value))
            
            
            if !items.isEmpty {
                let menu = ContextMenu()
                for item in items {
                    menu.addItem(item)
                }
                return menu
            }
            return nil
        }
        
        sendButton.set(image: theme.icons.chatSendMessage, for: .Normal)
        sendButton.autohighlight = false
        _ = sendButton.sizeToFit()
        
        emojiButton.set(image: theme.icons.chatEntertainment, for: .Normal)
        _ = emojiButton.sizeToFit()
        
        actionsContainerView.addSubview(sendButton)
        actionsContainerView.addSubview(emojiButton)
        
        
        actionsContainerView.setFrameSize(sendButton.frame.width + emojiButton.frame.width + 40, 50)
        
        emojiButton.centerY(x: 0)
        sendButton.centerY(x: emojiButton.frame.maxX + 20)
        
        backgroundColor = theme.colors.background
        textView.background = theme.colors.background
        textView.textFont = .normal(.text)
        textView.textColor = theme.colors.text
        textView.linkColor = theme.colors.link
        textView.max_height = 120
        
        textView.setFrameSize(NSMakeSize(0, 34))
        textView.setPlaceholderAttributedString(.initialize(string:  strings().previewSenderCommentPlaceholder, color: theme.colors.grayText, font: .normal(.text)), update: false)

        
        textContainerView.addSubview(textView)

        addSubview(textContainerView)
        addSubview(actionsContainerView)
        addSubview(bottomSeparator)
        
        updateLocalizationAndTheme(theme: theme)

    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        share.set(image: theme.icons.modalShare, for: .Normal)
        _ = share.sizeToFit()

        if inForumMode {
            dismiss.set(image: theme.icons.chatNavigationBack, for: .Normal)
        } else {
            dismiss.set(image: theme.icons.modalClose, for: .Normal)
        }
        _ = dismiss.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
    }
    
    var searchView: NSView {
        if hasCaptionView {
            return tokenizedView
        } else {
            return basicSearchView
        }
    }
    
    var hasCaptionView: Bool = true {
        didSet {
            textContainerView.isHidden = !hasCaptionView
            actionsContainerView.isHidden = !hasCaptionView
            bottomSeparator.isHidden = !hasCaptionView
            
            basicSearchView.isHidden = hasCaptionView
            tokenizedView.isHidden = !hasCaptionView
            dismiss.isHidden = hasCaptionView
            
            if oldValue != hasCaptionView, hasCaptionView {
                textContainerView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                actionsContainerView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                bottomSeparator.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                basicSearchView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                tokenizedView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                dismiss.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            needsLayout = true
        }
    }
    
    var hasCommentView: Bool = true {
        didSet {
            textContainerView.isHidden = !hasCommentView
            bottomSeparator.isHidden = !hasCommentView
            actionsContainerView.isHidden = !hasCommentView
            needsLayout = true
        }
    }
    
    var hasSendView: Bool = true {
        didSet {
            sendButton.isHidden = !hasSendView
            needsLayout = true
        }
    }
    
    func applyTransition(_ transition: TableUpdateTransition) {
        self.tableView.resetScrollNotifies()
        self.tableView.scroll(to: .up(false))
        self.tableView.merge(with: transition)
        self.tableView.cancelHighlight()
        
        let item = self.tableView.item(stableId: UIChatListEntryId.reveal)
        self.topSeparator.change(opacity: item != nil ? 0 : 1, animated: transition.animated)
    }
    
    private var forumTopicItems:[ForumTopicItem] = []
    private var forumTopicsView: TableView?
    
    var inForumMode: Bool {
        return forumTopicsView != nil
    }
    
   
    
    private class ForumTopicArguments {
        let context: AccountContext
        let select:(Int64)->Void
        init(context: AccountContext, select:@escaping(Int64)->Void) {
            self.context = context
            self.select = select
        }
    }
    
    private struct ForumTopicItem : TableItemListNodeEntry {
        let item: EngineChatList.Item
                
        static func < (lhs: ShareModalView.ForumTopicItem, rhs: ShareModalView.ForumTopicItem) -> Bool {
            return lhs.item.index < rhs.item.index
        }
        static func == (lhs: ShareModalView.ForumTopicItem, rhs: ShareModalView.ForumTopicItem) -> Bool {
            return lhs.item == rhs.item
        }
        
        var stableId: EngineChatList.Item.Id {
            return item.id 
        }
        func item(_ arguments: ShareModalView.ForumTopicArguments, initialSize: NSSize) -> TableRowItem {
            let threadId: Int64?
            switch item.id {
            case let .forum(id):
                threadId = id
            default:
                threadId = nil
            }
            return SearchTopicRowItem(initialSize, stableId: self.item.id, item: self.item, context: arguments.context, action: {
                if let threadId = threadId {
                    arguments.select(threadId)
                }
            })
        }
    }
    
    func appearForumTopics(_ items: [EngineChatList.Item], peerId: PeerId, interactions: SelectPeerInteraction, delegate: TableViewDelegate?, context: AccountContext, animated: Bool) {
        
        let arguments = ForumTopicArguments(context: context, select: { threadId in
            interactions.action(peerId, threadId)
        })
        
        let mapped:[ForumTopicItem] = items.map {
            .init(item: $0)
        }
        let animated = animated && self.forumTopicsView == nil
        
        let tableView = self.forumTopicsView ?? TableView()
        if tableView.superview == nil {
            tableView.frame = self.tableView.frame
            addSubview(tableView)
            self.forumTopicsView = tableView
        }
        
        tableView.delegate = delegate
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.forumTopicItems, rightList: mapped)
        
        self.forumTopicItems = mapped

        
        tableView.beginTableUpdates()
        
        for deleteIndex in deleteIndices.reversed() {
            tableView.remove(at: deleteIndex)
        }
        for indicesAndItem in indicesAndItems {
            let item = indicesAndItem.1.item(arguments, initialSize: tableView.frame.size)
            _ = tableView.insert(item: item, at: indicesAndItem.0)
        }
        for updateIndex in updateIndices {
            let item = updateIndex.1.item(arguments, initialSize: tableView.frame.size)
            tableView.replace(item: item, at: updateIndex.0, animated: false)
        }

        tableView.endTableUpdates()
        

        if animated {
            let oneOfThrid = frame.width / 3
            tableView.layer?.animatePosition(from: NSMakePoint(oneOfThrid * 2, tableView.frame.minY), to: tableView.frame.origin, duration: 0.35, timingFunction: .spring)
            self.tableView.layer?.animatePosition(from: tableView.frame.origin, to: NSMakePoint(-oneOfThrid, tableView.frame.minY), duration: 0.35, timingFunction: .spring)
        }
        
        updateLocalizationAndTheme(theme: theme)
        needsLayout = true
    }
    
    func cancelForum(animated: Bool) {
        guard let view = self.forumTopicsView else {
            return
        }
        if animated {
            let oneOfThrid = frame.width / 3
            view.layer?.animatePosition(from: tableView.frame.origin, to: NSMakePoint(frame.width, view.frame.minY), duration: 0.35, timingFunction: .spring, removeOnCompletion: false, completion: { [weak view] _ in
                view?.removeFromSuperview()
            })
            self.tableView.layer?.animatePosition(from: NSMakePoint(-oneOfThrid, tableView.frame.minY), to: tableView.frame.origin, duration: 0.35, timingFunction: .spring)
        } else {
            view.removeFromSuperview()
        }
        self.forumTopicsView = nil
        self.forumTopicItems = []
        self.tableView.cancelSelection()
        self.updateLocalizationAndTheme(theme: theme)
        self.needsLayout = true
    }
        
    func tokenizedViewDidChangedHeight(_ view: TokenizedView, height: CGFloat, animated: Bool) {
        if !tokenizedView.isHidden {
            searchView._change(pos: NSMakePoint(10 + (!dismiss.isHidden ? 40 : 0), 10), animated: animated)
            tableView.change(size: NSMakeSize(frame.width, frame.height - height - 20 - (textContainerView.isHidden ? 0 : textContainerView.frame.height)), animated: animated)
            tableView.change(pos: NSMakePoint(0, height + 20), animated: animated)
            topSeparator.change(pos: NSMakePoint(0, searchView.frame.maxY + 10), animated: animated)
        }
    }
    
    func textViewUpdateHeight(_ height: CGFloat, _ animated: Bool) {
        CATransaction.begin()
        textContainerView.change(size: NSMakeSize(frame.width, height + 16), animated: animated)
        textContainerView.change(pos: NSMakePoint(0, frame.height - textContainerView.frame.height), animated: animated)
        textView._change(pos: NSMakePoint(10, height == 34 ? 8 : 11), animated: animated)
        tableView.change(size: NSMakeSize(frame.width, frame.height - searchView.frame.height - 20 - (!textContainerView.isHidden ? 50 : 0)), animated: animated)

        actionsContainerView.change(pos: NSMakePoint(frame.width - actionsContainerView.frame.width, frame.height - actionsContainerView.frame.height), animated: animated)
        
        bottomSeparator.change(pos: NSMakePoint(0, textContainerView.frame.minY), animated: animated)
        CATransaction.commit()
        
        needsLayout = true
    }
    
    var additionHeight: CGFloat {
        return textView.frame.height + 16 + searchView.frame.height + 20
    }
    
    
    fileprivate override func layout() {
        super.layout()
        
        emojiButton.centerY(x: 0)
        actionsContainerView.setFrameSize((sendButton.isHidden ? 0 : (sendButton.frame.width + 20)) + emojiButton.frame.width + 20, 50)

        sendButton.centerY(x: emojiButton.frame.maxX + 20)
        
        searchView.setFrameSize(frame.width - 10 - (!dismiss.isHidden ? 40 : 0) - (share.isHidden ? 10 : 50), searchView.frame.height)
        share.setFrameOrigin(frame.width - share.frame.width - 10, 10)
        dismiss.setFrameOrigin(10, 10)
        searchView.setFrameOrigin(10 + (!dismiss.isHidden ? 40 : 0), 10)
        tableView.frame = NSMakeRect(0, searchView.frame.maxY + 10, frame.width, frame.height - searchView.frame.height - 20 - (!textContainerView.isHidden ? 50 : 0))
        topSeparator.frame = NSMakeRect(0, searchView.frame.maxY + 10, frame.width, .borderSize)
        actionsContainerView.setFrameOrigin(frame.width - actionsContainerView.frame.width, frame.height - actionsContainerView.frame.height)
        
        textContainerView.setFrameSize(frame.width, textView.frame.height + 16)
        textContainerView.setFrameOrigin(0, frame.height - textContainerView.frame.height)

        
        textView.setFrameSize(NSMakeSize(textContainerView.frame.width - 10 - actionsContainerView.frame.width, textView.frame.height))
        textView.setFrameOrigin(10, textView.frame.height == 34 ? 8 : 11)
        bottomSeparator.frame = NSMakeRect(0, textContainerView.frame.minY, frame.width, .borderSize)
        
        forumTopicsView?.frame = tableView.frame

    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}

final class ShareAdditionItem {
    let peer: Peer
    let status: String?
    init(peer: Peer, status: String?) {
        self.peer = peer
        self.status = status
    }
}

final class ShareAdditionItems {
    let items: [ShareAdditionItem]
    let topSeparator: String
    let bottomSeparator: String
    init(items: [ShareAdditionItem], topSeparator: String, bottomSeparator: String) {
        self.items = items
        self.topSeparator = topSeparator
        self.bottomSeparator = bottomSeparator
    }
}


class ShareObject {
    
    let additionTopItems:ShareAdditionItems?
    
    let context: AccountContext
    let emptyPerformOnClose: Bool
    let excludePeerIds: Set<PeerId>
    let defaultSelectedIds:Set<PeerId>
    let limit: Int?
    
    var withoutSound: Bool = false
    var scheduleDate: Date? = nil
    
    init(_ context:AccountContext, emptyPerformOnClose: Bool = false, excludePeerIds:Set<PeerId> = [], defaultSelectedIds: Set<PeerId> = [], additionTopItems:ShareAdditionItems? = nil, limit: Int? = nil) {
        self.limit = limit
        self.context = context
        self.emptyPerformOnClose = emptyPerformOnClose
        self.excludePeerIds = excludePeerIds
        self.additionTopItems = additionTopItems
        self.defaultSelectedIds = defaultSelectedIds
    }
    
    var multipleSelection: Bool {
        return true
    }
    var hasCaptionView: Bool {
        return true
    }
    var blockCaptionView: Bool {
        return false
    }
    var interactionOk: String {
        return strings().modalOK
    }
    var mutableSelection: Bool {
        return true
    }
    var hasInteraction: Bool {
        return true
    }
    var selectTopics: Bool {
        return true
    }
    
    func attributes(_ peerId: PeerId) -> [MessageAttribute] {
        var attributes:[MessageAttribute] = []
        if FastSettings.isChannelMessagesMuted(peerId) || withoutSound {
            attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
        }
        if let date = scheduleDate {
            attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970)))
        }
        return attributes
    }
    
    var searchPlaceholderKey: String {
        return "ShareModal.Search.Placeholder"
    }

    var alwaysEnableDone: Bool {
        return false
    }
    
    func perform(to entries:[PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        return .complete()
    }
    func limitReached() {
        
    }
    
    var hasLink: Bool {
        return false
    }
    
    func shareLink() {
        
    }
    
    func possibilityPerformTo(_ peer:Peer) -> Bool {
        return peer.canSendMessage(false) && !self.excludePeerIds.contains(peer.id)
    }
    func statusString(_ peer: Peer, presence: PeerStatusStringResult?, autoDeletion: Int32?) -> String? {
        return peer.id == context.peerId ? (multipleSelection ? nil : strings().forwardToSavedMessages) : presence?.status.string
    }
    func statusStyle(_ peer: Peer, presence: PeerStatusStringResult?, autoDeletion: Int32?) -> ControlStyle {
        let color = presence?.status.string.isEmpty == false ? presence?.status.attribute(NSAttributedString.Key.foregroundColor, at: 0, effectiveRange: nil) as? NSColor : nil
        return ControlStyle(font: .normal(.text), foregroundColor: peer.id == context.peerId ? theme.colors.grayText : color ?? theme.colors.grayText, highlightColor:.white)
    }
}

class SharefilterCallbackObject : ShareObject {
    private let callback:(PeerId, MessageId?)->Signal<Never, NoError>
    private let limits: [String]
    init(_ context: AccountContext, limits: [String], callback:@escaping(PeerId, MessageId?)->Signal<Never, NoError>) {
        self.callback = callback
        self.limits = limits
        super.init(context)
    }
    
    override func perform(to peerIds:[PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        if let peerId = peerIds.first {
            return callback(peerId, threadId) |> castError(String.self)
        } else {
            return .complete()
        }
    }
    
    override func statusString(_ peer: Peer, presence: PeerStatusStringResult?, autoDeletion: Int32?) -> String? {
        if peer.id == context.peerId {
            return nil
        } else {
            return super.statusString(peer, presence: presence, autoDeletion: autoDeletion)
        }
    }
    
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        if !canSendMessagesToPeer(peer) {
            return false
        }
        if peer.isBot {
            if !limits.contains("bots") {
                return false
            }
        }
        if peer.isUser {
            if !limits.contains("users") {
                return false
            }
        }
        if peer.isChannel {
            if !limits.contains("channels") {
                return false
            }
        }
        if peer.isGroup || peer.isSupergroup || peer.isGigagroup {
            if !limits.contains("groups") {
                return false
            }
        }
        return true
    }
    
    
    override var multipleSelection: Bool {
        return false
    }
    override var hasCaptionView: Bool {
        return false
    }
    override var blockCaptionView: Bool {
        return true
    }
}


class ShareLinkObject : ShareObject {
    let link:String
    init(_ context: AccountContext, link:String) {
        self.link = link.removingPercentEncoding ?? link
        super.init(context)
    }
    
    override var hasLink: Bool {
        return true
    }
    
    override func shareLink() {
        copyToClipboard(link)
    }
    
    override func perform(to peerIds:[PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        for peerId in peerIds {
            var link = self.link
            if let comment = comment, !comment.inputText.isEmpty {
                link += "\n\(comment.inputText)"
            }
            
            let attributes:[MessageAttribute] = attributes(peerId)
        
            _ = enqueueMessages(account: context.account, peerId: peerId, messages: [EnqueueMessage.message(text: link, attributes: attributes, inlineStickers: [:], mediaReference: nil, replyToMessageId: threadId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).start()
        }
        return .complete()
    }
}


class ShareUrlObject : ShareObject {
    let url:String
    init(_ context: AccountContext, url:String) {
        self.url = url
        super.init(context)
    }
    
    override var hasLink: Bool {
        return true
    }
    
    override func shareLink() {
        copyToClipboard(url)
    }
    
    override func perform(to peerIds:[PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        for peerId in peerIds {
            
            let attributes:[MessageAttribute] = attributes(peerId)
            
            let media = TelegramMediaFile(fileId: MediaId.init(namespace: 0, id: 0), partialReference: nil, resource: LocalFileReferenceMediaResource.init(localFilePath: url, randomId: arc4random64()), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "text/plain", size: nil, attributes: [.FileName(fileName: url.nsstring.lastPathComponent)])
                        
            _ = enqueueMessages(account: context.account, peerId: peerId, messages: [EnqueueMessage.message(text: "", attributes: attributes, inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: media), replyToMessageId: threadId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).start()
        }
        return .complete()
    }
}

class ShareContactObject : ShareObject {
    let user:TelegramUser
    let media: Media
    init(_ context: AccountContext, user:TelegramUser) {
        self.user = user
        self.media = TelegramMediaContact(firstName: user.firstName ?? "", lastName: user.lastName ?? "", phoneNumber: user.phone ?? "", peerId: user.id, vCardData: nil)
        super.init(context)
    }
    
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        return !excludePeerIds.contains(peer.id) && peer.canSendMessage(media: media)
    }
    
    override func perform(to peerIds:[PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        for peerId in peerIds {
            if let comment = comment, !comment.inputText.isEmpty {
                let attributes:[MessageAttribute] = attributes(peerId)
                _ = enqueueMessages(account: context.account, peerId: peerId, messages: [EnqueueMessage.message(text: comment.inputText, attributes: attributes, inlineStickers: [:], mediaReference: nil, replyToMessageId: threadId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).start()
            }
            _ = Sender.shareContact(context: context, peerId: peerId, media: media, replyId: threadId).start()
        }
        return .complete()
    }

}

class ShareCallbackObject : ShareObject {
    private let callback:([PeerId])->Signal<Never, NoError>
    init(_ context: AccountContext, callback:@escaping([PeerId])->Signal<Never, NoError>) {
        self.callback = callback
        super.init(context)
    }
    
    override func perform(to peerIds:[PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        return callback(peerIds) |> castError(String.self)
    }
    
}


class ShareCallbackPeerTypesObject : ShareObject {
    private let callback:([PeerId])->Signal<Never, NoError>
    private let peerTypes: ReplyMarkupButtonAction.PeerTypes
    init(_ context: AccountContext, peerTypes: ReplyMarkupButtonAction.PeerTypes, callback:@escaping([PeerId])->Signal<Never, NoError>) {
        self.callback = callback
        self.peerTypes = peerTypes
        super.init(context, limit: 1)
    }
    
    override var multipleSelection: Bool {
        return false
    }
    override var hasCaptionView: Bool {
        return false
    }
    override var blockCaptionView: Bool {
        return true
    }
    
    override func perform(to peerIds:[PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        return callback(peerIds) |> castError(String.self)
    }
    
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        if self.peerTypes.isEmpty {
            return super.possibilityPerformTo(peer)
        }
        if peer.isUser {
            if peerTypes.contains(.users) {
                return canSendMessagesToPeer(peer)
            }
        }
        if peer.isGroup || peer.isSupergroup || peer.isGigagroup {
            if peerTypes.contains(.groups) {
                return canSendMessagesToPeer(peer)
            }
        }
        if peer.isChannel {
            if peerTypes.contains(.channels) {
                return canSendMessagesToPeer(peer)
            }
        }
        if peer.isBot {
            if peerTypes.contains(.bots) {
                return canSendMessagesToPeer(peer)
            }
        }
        return false
    }
    
}


class ShareMessageObject : ShareObject {
    fileprivate let messageIds:[MessageId]
    private let message:Message
    let link:String?
    private let exportLinkDisposable = MetaDisposable()
    
    init(_ context: AccountContext, _ message:Message, _ groupMessages:[Message] = []) {
        self.messageIds = groupMessages.isEmpty ? [message.id] : groupMessages.map{$0.id}
        self.message = message
        var peer = coreMessageMainPeer(message) as? TelegramChannel
        var messageId = message.id
        if let author = message.forwardInfo?.author as? TelegramChannel {
            peer = author
            messageId = message.forwardInfo?.sourceMessageId ?? message.id
        }
        //            peer = coreMessageMainPeer(message) as? TelegramChannel
        //        }
        if let peer = peer, let address = peer.username {
            switch peer.info {
            case .broadcast:
                self.link = "https://t.me/" + address + "/" + "\(messageId.id)"
            default:
                self.link = nil
            }
        } else {
            self.link = nil
        }
        super.init(context)
    }
    
    override var hasLink: Bool {
        return link != nil
    }
    
    override func shareLink() {
        if let link = link {
            exportLinkDisposable.set(context.engine.messages.exportMessageLink(peerId: messageIds[0].peerId, messageId: messageIds[0]).start(next: { valueLink in
                if let valueLink = valueLink {
                    copyToClipboard(valueLink)
                } else {
                    copyToClipboard(link)
                }
            }))
        }
    }

    deinit {
        exportLinkDisposable.dispose()
    }

    override func perform(to peerIds:[PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        
        let context = self.context
        let messageIds = self.messageIds
        var signals: [Signal<[MessageId?], NoError>] = []
        let attrs:(PeerId)->[MessageAttribute] = { [weak self] peerId in
            return self?.attributes(peerId) ?? []
        }
        let date = self.scheduleDate
        let withoutSound = self.withoutSound
        for peerId in peerIds {
            let viewSignal: Signal<(Peer, PeerId?), NoError> = combineLatest(context.account.postbox.loadedPeerWithId(peerId), getCachedDataView(peerId: peerId, postbox: context.account.postbox))
            |> take(1)
            |> map { peer, cachedData in
                if let cachedData = cachedData as? CachedChannelData {
                    return (peer, cachedData.sendAsPeerId)
                } else {
                    return (peer, nil)
                }
            }
            signals.append(viewSignal |> mapToSignal { (peer, sendAs) in
                let forward: Signal<[MessageId?], NoError> = Sender.forwardMessages(messageIds: messageIds, context: context, peerId: peerId, replyId: threadId, silent: FastSettings.isChannelMessagesMuted(peerId) || withoutSound, atDate: date, sendAsPeerId: sendAs)
                var caption: Signal<[MessageId?], NoError>?
                if let comment = comment, !comment.inputText.isEmpty, peer.canSendMessage() {
                    let parsingUrlType: ParsingType
                    if peerId.namespace != Namespaces.Peer.SecretChat {
                        parsingUrlType = [.Hashtags]
                    } else {
                        parsingUrlType = [.Links, .Hashtags]
                    }
                                    
                    var attributes:[MessageAttribute] = [TextEntitiesMessageAttribute(entities: comment.messageTextEntities(parsingUrlType))]
                    attributes += attrs(peerId)
                    if let sendAs = sendAs {
                        attributes.append(SendAsMessageAttribute(peerId: sendAs))
                    }
                    
                    caption = Sender.enqueue(message: EnqueueMessage.message(text: comment.inputText, attributes: attributes, inlineStickers: [:], mediaReference: nil, replyToMessageId: threadId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []), context: context, peerId: peerId)
                }
                if let caption = caption {
                    return caption |> then(forward)
                } else {
                    return forward
                }
            })
        }
        return combineLatest(signals)
        |> castError(String.self)
        |> ignoreValues
    }
    
    override func possibilityPerformTo(_ peer:Peer) -> Bool {
        return message.possibilityForwardTo(peer)
    }
}

final class ForwardMessagesObject : ShareObject {
    fileprivate let messages: [Message]
    
    var messageIds: [MessageId] {
        return messages.map { $0.id }
    }
    private let disposable = MetaDisposable()
    private let album: Bool
    init(_ context: AccountContext, messages: [Message], emptyPerformOnClose: Bool = false, album: Bool = false) {
        self.messages = messages
        self.album = album
        super.init(context, emptyPerformOnClose: emptyPerformOnClose)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override var multipleSelection: Bool {
        return false
    }
    
    override func possibilityPerformTo(_ peer: Peer) -> Bool {
        let canSend = messages.map {
            return peer.canSendMessage(media: $0.media.first)
        }.allSatisfy { $0 }
        return !excludePeerIds.contains(peer.id) && canSend
    }
    
    
    
    override func perform(to peerIds: [PeerId], threadId: MessageId?, comment: ChatTextInputState? = nil) -> Signal<Never, String> {
        
        if peerIds.count == 1 {
            let context = self.context
            let album = self.album
            let messageIds = self.messageIds
            let comment = comment != nil ? comment!.inputText.isEmpty ? nil : comment : nil
            let peers = context.account.postbox.transaction { transaction -> Peer? in
                for peerId in peerIds {
                    if let peer = transaction.getPeer(peerId) {
                        return peer
                    }
                }
                return nil
            }
            
            let messages: Signal<[Message], NoError> = context.account.postbox.transaction { transaction in
                var list:[Message] = []
                for messageId in messageIds {
                    if let messages = transaction.getMessageGroup(messageId), album {
                        list.append(contentsOf: messages)
                    } else if let message = transaction.getMessage(messageId) {
                        list.append(message)
                    }
                }
                return list
            }
            
            return combineLatest(messages, peers)
                |> deliverOnMainQueue
                |> castError(String.self)
                |> mapToSignal {  messages, peer in
                    
                    let messageIds = messages.map { $0.id }
                    
                    if let peer = peer, peer.isChannel {
                        for message in messages {
                            if message.isPublicPoll {
                                return .fail(strings().pollForwardError)
                            }
                        }
                    }
                    
                    
                    let navigation = self.context.bindings.rootNavigation()
                    if let peerId = peerIds.first {
                        if peerId == context.peerId {
                            if let comment = comment, !comment.inputText.isEmpty {
                                let parsingUrlType: ParsingType
                                if peerId.namespace != Namespaces.Peer.SecretChat {
                                    parsingUrlType = [.Hashtags]
                                } else {
                                    parsingUrlType = [.Links, .Hashtags]
                                }
                                let attributes:[MessageAttribute] = [TextEntitiesMessageAttribute(entities: comment.messageTextEntities(parsingUrlType))]
                                _ = Sender.enqueue(message: EnqueueMessage.message(text: comment.inputText, attributes: attributes, inlineStickers: [:], mediaReference: nil, replyToMessageId: threadId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []), context: context, peerId: peerId).start()
                            }
                            _ = Sender.forwardMessages(messageIds: messageIds, context: context, peerId: context.account.peerId, replyId: threadId).start()
                            if let controller = context.bindings.rootNavigation().controller as? ChatController {
                                controller.chatInteraction.update({$0.withoutSelectionState()})
                            }
                            delay(0.2, closure: {
                                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
                            })
                        } else if let peer = peer {
                            
                            let comment = peer.canSendMessage() ? comment : nil
                            
                            if let controller = navigation.controller as? ChatController, controller.chatInteraction.chatLocation == .peer(peerId) {
                                controller.chatInteraction.update({ current in
                                    current.withoutSelectionState().updatedInterfaceState {
                                        $0.withUpdatedForwardMessageIds(messageIds).withUpdatedInputState(comment ?? current.effectiveInput)
                                    }
                                })
                            } else {
                                
                                let initialAction: ChatInitialAction = .forward(messageIds: messageIds, text: comment, behavior: .automatic)
                                
                                if let threadId = threadId {
                                    return ForumUI.openTopic(makeMessageThreadId(threadId), peerId: peerId, context: context, animated: true, addition: true, initialAction: initialAction) |> filter {$0}
                                    |> take(1)
                                    |> ignoreValues
                                    |> castError(String.self)
                                }
                                
                                (navigation.controller as? ChatController)?.chatInteraction.update({ $0.withoutSelectionState() })
                                
                                var existed: Bool = false
                                navigation.enumerateControllers { controller, _ in
                                    if let controller = controller as? ChatController, controller.chatInteraction.peerId == peerId {
                                        existed = true
                                    }
                                    return existed
                                }
                                let newone: ChatController
                                
                                if existed {
                                    newone = ChatController(context: context, chatLocation: .peer(peerId), initialAction: initialAction)
                                } else {
                                    newone = ChatAdditionController(context: context, chatLocation: .peer(peerId), initialAction: initialAction)
                                }
                                navigation.push(newone)
                                
                                return newone.ready.get() |> filter {$0} |> take(1) |> ignoreValues |> castError(String.self)
                            }
                        }
                    } else {
                        if let controller = navigation.controller as? ChatController {
                            controller.chatInteraction.update({$0.withoutSelectionState().updatedInterfaceState({$0.withUpdatedForwardMessageIds(messageIds)})})
                        }
                    }
                    return .complete()
                }
        } else {
            let navigation = self.context.bindings.rootNavigation()
            
            if let controller = navigation.controller as? ChatController {
                controller.chatInteraction.update({ $0.withoutSelectionState() })
            }
            
            let context = self.context
            let messageIds = self.messageIds
            var signals: [Signal<[MessageId?], NoError>] = []
            let attrs:(PeerId)->[MessageAttribute] = { [weak self] peerId in
                return self?.attributes(peerId) ?? []
            }
            let date = self.scheduleDate
            let withoutSound = self.withoutSound
            for peerId in peerIds {
                let viewSignal: Signal<(Peer, PeerId?), NoError> = combineLatest(context.account.postbox.loadedPeerWithId(peerId), getCachedDataView(peerId: peerId, postbox: context.account.postbox))
                |> take(1)
                |> map { peer, cachedData in
                    if let cachedData = cachedData as? CachedChannelData {
                        return (peer, cachedData.sendAsPeerId)
                    } else {
                        return (peer, nil)
                    }
                }
                signals.append(viewSignal |> mapToSignal { (peer, sendAs) in
                    let forward: Signal<[MessageId?], NoError> = Sender.forwardMessages(messageIds: messageIds, context: context, peerId: peerId, replyId: threadId, silent: FastSettings.isChannelMessagesMuted(peerId) || withoutSound, atDate: date, sendAsPeerId: sendAs)
                    var caption: Signal<[MessageId?], NoError>?
                    if let comment = comment, !comment.inputText.isEmpty, peer.canSendMessage() {
                        let parsingUrlType: ParsingType
                        if peerId.namespace != Namespaces.Peer.SecretChat {
                            parsingUrlType = [.Hashtags]
                        } else {
                            parsingUrlType = [.Links, .Hashtags]
                        }
                                        
                        var attributes:[MessageAttribute] = [TextEntitiesMessageAttribute(entities: comment.messageTextEntities(parsingUrlType))]
                        attributes += attrs(peerId)
                        if let sendAs = sendAs {
                            attributes.append(SendAsMessageAttribute(peerId: sendAs))
                        }
                        
                        caption = Sender.enqueue(message: EnqueueMessage.message(text: comment.inputText, attributes: attributes, inlineStickers: [:], mediaReference: nil, replyToMessageId: threadId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []), context: context, peerId: peerId)
                    }
                    if let caption = caption {
                        return caption |> then(forward)
                    } else {
                        return forward
                    }
                })
            }
            return combineLatest(signals)
            |> castError(String.self)
            |> ignoreValues
        }
        
        
    }
    
    override var searchPlaceholderKey: String {
        return "ShareModal.Search.ForwardPlaceholder"
    }
}

enum SelectablePeersEntryStableId : Hashable {
    case plain(PeerId, ChatListIndex)
    case emptySearch
    case separator(ChatListIndex)
    case folders
    var hashValue: Int {
        switch self {
        case let .plain(peerId, _):
            return peerId.hashValue
        case .separator(let index):
            return index.hashValue
        case .emptySearch:
            return 0
        case .folders:
            return -1
        }
    }
}

enum SelectablePeersEntry : Comparable, Identifiable {
    case folders([ChatListFilter], ChatListFilter)
    case secretChat(Peer, PeerId, ChatListIndex, PeerStatusStringResult?, Bool, Bool)
    case plain(Peer, ChatListIndex, PeerStatusStringResult?, Int32?, Bool, Bool)
    case separator(String, ChatListIndex)
    case emptySearch
    var stableId: SelectablePeersEntryStableId {
        switch self {
        case let .plain(peer, index, _, _, _, _):
            return .plain(peer.id, index)
        case let .secretChat(_, peerId, index, _, _, _):
            return .plain(peerId, index)
        case let .separator(_, index):
            return .separator(index)
        case .emptySearch:
            return .emptySearch
        case .folders:
            return .folders
        }
    }
    
    var index:ChatListIndex {
        switch self {
        case let .plain(_, id, _, _, _, _):
            return id
        case let .secretChat(_, _, id, _, _, _):
            return id
        case let .separator(_, index):
            return index
        case .emptySearch:
            return ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex.absoluteLowerBound())
        case .folders:
            return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound())
        }
    }
}

func <(lhs:SelectablePeersEntry, rhs:SelectablePeersEntry) -> Bool {
    return lhs.index < rhs.index
}

func ==(lhs:SelectablePeersEntry, rhs:SelectablePeersEntry) -> Bool {
    switch lhs {
    case let .plain(lhsPeer, index, presence, autoDeletion, separator, multiple):
        if case .plain(let rhsPeer, index, presence, autoDeletion, separator, multiple) = rhs {
            return lhsPeer.isEqual(rhsPeer)
        } else {
            return false
        }
    case let .secretChat(lhsPeer, peerId, index, presence, separator, multiple):
        if case .secretChat(let rhsPeer, peerId, index, presence, separator, multiple) = rhs {
            return lhsPeer.isEqual(rhsPeer)
        } else {
            return false
        }
    case let .separator(text, index):
        if case .separator(text, index) = rhs {
            return true
        } else {
            return false
        }
    case let .folders(filters, current):
        if case .folders(filters, current) = rhs {
            return true
        } else {
            return false
        }
    case .emptySearch:
        if case .emptySearch = rhs {
            return true
        } else {
            return false
        }
    }
}



fileprivate func prepareEntries(from:[SelectablePeersEntry]?, to:[SelectablePeersEntry], context: AccountContext, initialSize:NSSize, animated:Bool, multipleSelection: Bool, selectInteraction:SelectPeerInteraction, share: ShareObject) -> TableUpdateTransition {
  
    let (deleted,inserted,updated) = proccessEntries(from, right: to, { entry -> TableRowItem in
        
        switch entry {
        case let .plain(peer, _, presence, autoDeletion, drawSeparator, multiple):
            return  ShortPeerRowItem(initialSize, peer: peer, account: context.account, context: context, stableId: entry.stableId, height: 48, photoSize:NSMakeSize(36, 36), statusStyle: share.statusStyle(peer, presence: presence, autoDeletion: autoDeletion), status: share.statusString(peer, presence: presence, autoDeletion: autoDeletion), drawCustomSeparator: drawSeparator, isLookSavedMessage : peer.id == context.peerId, inset:NSEdgeInsets(left: 10, right: 10), drawSeparatorIgnoringInset: true, interactionType: multiple ? .selectable(selectInteraction, side: .right) : .plain, action: {
                if peer.isForum && share.selectTopics {
                    selectInteraction.openForum(peer.id)
                } else {
                    selectInteraction.action(peer.id, nil)
                }
            }, contextMenuItems: {
                return .single([
                    .init(strings().shareModalSelect, handler: {
                        if share.mutableSelection {
                            selectInteraction.toggleSelection(peer)
                        }
                    }, itemImage: MenuAnimation.menu_select_messages.value)
                ])
            }, highlightVerified: true)
        case let .secretChat(peer, peerId, _, _, drawSeparator, multiple):
            return  ShortPeerRowItem(initialSize, peer: peer, account: context.account, context: context, peerId: peerId, stableId: entry.stableId, height: 48, photoSize:NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(.title), foregroundColor: theme.colors.accent, highlightColor: .white), statusStyle: ControlStyle(font: .normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status: strings().composeSelectSecretChat.lowercased(), drawCustomSeparator: drawSeparator, isLookSavedMessage : peer.id == context.peerId, inset:NSEdgeInsets(left: 10, right: 10), drawSeparatorIgnoringInset: true, interactionType: multiple ? .selectable(selectInteraction, side: .right) : .plain, action: {
                selectInteraction.action(peerId, nil)
            })
        case let .separator(text, _):
            return SeparatorRowItem(initialSize, entry.stableId, string: text)
        case .emptySearch:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId)
        case let .folders(filters, current):
            return ChatListRevealItem(initialSize, context: context, tabs: filters, selected: current, counters: ChatListFilterBadges(total: 0, filters: []), action: selectInteraction.updateFolder)
        }
        
        
    })
    
    
    return TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated: animated, state: animated ? .none(nil) : .saveVisible(.lower), grouping: true, animateVisibleOnly: false)
    
}



class ShareModalController: ModalViewController, Notifable, TGModernGrowingDelegate, TableViewDelegate {
   
    
    private let share:ShareObject
    private let selectInteractions:SelectPeerInteraction = SelectPeerInteraction()
    private let search:Promise<SearchState> = Promise()
    private let forumPeerId:ValuePromise<PeerId?> = ValuePromise(nil, ignoreRepeated: true)
    private let inSearchSelected:Atomic<[PeerId]> = Atomic(value:[])
    private let disposable:MetaDisposable = MetaDisposable()
    private let exportLinkDisposable:MetaDisposable = MetaDisposable()
    private let tokenDisposable: MetaDisposable = MetaDisposable()
    private let filterDisposable = MetaDisposable()
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private let inputContextHelper: InputContextHelper
    private let contextChatInteraction: ChatInteraction
    
    private let forumDisposable = MetaDisposable()
    
    private let multipleSelection: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)

    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
            
            genericView.hasCaptionView = value.multipleSelection && !share.blockCaptionView
            genericView.hasSendView = value.multipleSelection && !share.blockCaptionView
            if value.multipleSelection && !share.blockCaptionView {
                search.set(combineLatest(genericView.tokenizedView.textUpdater, genericView.tokenizedView.stateValue.get()) |> map { SearchState(state: $1, request: $0)})
            } else {
                search.set(genericView.basicSearchView.searchValue)
            }
            
            self.multipleSelection.set(value.multipleSelection)
            
            let added = value.selected.subtracting(oldValue.selected)
            let removed = oldValue.selected.subtracting(value.selected)

            
            let selected = value.selected.filter {
                $0.namespace._internalGetInt32Value() != ChatListFilterPeerCategories.Namespace
            }
            
            if let limit = self.share.limit, selected.count > limit {
                DispatchQueue.main.async { [unowned self] in
                    self.selectInteractions.update(animated: true, { current in
                        var current = current
                        for peerId in added {
                            if let peer = current.peers[peerId] {
                                current = current.withToggledSelected(peerId, peer: peer)
                            }
                        }
                        return current
                    })
                    self.share.limitReached()
                }
                return
            }
            
            let tokens:[SearchToken] = added.map { item in
                let title = item == share.context.account.peerId ? strings().peerSavedMessages : value.peers[item]?.compactDisplayTitle ?? strings().peerDeletedUser
                return SearchToken(name: title, uniqueId: item.toInt64())
            }
            genericView.tokenizedView.addTokens(tokens: tokens, animated: animated)
            genericView.sendButton.isEnabled = !value.selected.isEmpty || share.alwaysEnableDone
            let idsToRemove:[Int64] = removed.map {
                $0.toInt64()
            }
            genericView.tokenizedView.removeTokens(uniqueIds: idsToRemove, animated: animated)
            self.modal?.interactions?.updateEnables(!value.selected.isEmpty || share.alwaysEnableDone)
            
            if value.inputQueryResult != oldValue.inputQueryResult {
                inputContextHelper.context(with: value.inputQueryResult, for: self.genericView, relativeView: self.genericView.textContainerView, position: .above, selectIndex: nil, animated: animated)
            }
            if let (possibleQueryRange, possibleTypes, _) = textInputStateContextQueryRangeAndType(ChatTextInputState(inputText: value.comment.string, selectionRange: value.comment.range.min ..< value.comment.range.max, attributes: []), includeContext: false) {
                if possibleTypes.contains(.mention) {
                    let peers: [Peer] = value.peers.compactMap { (_, value) in
                        if value.isGroup || value.isSupergroup {
                            return value
                        } else {
                            return nil
                        }
                    }
                    let query = String(value.comment.string[possibleQueryRange])
                    if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(chatLocations: peers.map { .peer($0.id) }, .mention(query: query, includeRecent: false), currentQuery: self.contextQueryState?.0, context: share.context) {
                        self.contextQueryState?.1.dispose()
                        var inScope = true
                        var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                        self.contextQueryState = (updatedContextQueryState, (updatedContextQuerySignal |> deliverOnMainQueue).start(next: { [weak self] result in
                            if let strongSelf = self {
                                if Thread.isMainThread && inScope {
                                    inScope = false
                                    inScopeResult = result
                                } else {
                                    strongSelf.selectInteractions.update(animated: animated, {
                                        $0.updatedInputQueryResult { previousResult in
                                            return result(previousResult)
                                        }
                                    })
                                    
                                }
                            }
                        }))
                        inScope = false
                        if let inScopeResult = inScopeResult {
                            selectInteractions.update(animated: animated, {
                                $0.updatedInputQueryResult { previousResult in
                                    return inScopeResult(previousResult)
                                }
                            })
                        }
                    } else {
                        selectInteractions.update(animated: animated, {
                            $0.updatedInputQueryResult { _ in
                                return nil
                            }
                        })
                    }
                } else {
                    selectInteractions.update(animated: animated, {
                        $0.updatedInputQueryResult { _ in
                            return nil
                        }
                    })
                }
            } else {
                selectInteractions.update(animated: animated, {
                    $0.updatedInputQueryResult { _ in
                        return nil
                    }
                })
            }
        } else if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if value.effectiveInput != oldValue.effectiveInput {
                updateInput(value, prevState: oldValue, animated)
            }
        }
        
        _ = self.window?.makeFirstResponder(firstResponder())
    }
    
    private func updateInput(_ state:ChatPresentationInterfaceState, prevState: ChatPresentationInterfaceState, _ animated:Bool = true) -> Void {
        
        let textView = genericView.textView
        
        if textView.string() != state.effectiveInput.inputText || state.effectiveInput.attributes != prevState.effectiveInput.attributes  {
            textView.animates = false
            textView.setAttributedString(state.effectiveInput.attributedString, animated:animated)
            textView.animates = true
        }
        let range = NSMakeRange(state.effectiveInput.selectionRange.lowerBound, state.effectiveInput.selectionRange.upperBound - state.effectiveInput.selectionRange.lowerBound)
        if textView.selectedRange().location != range.location || textView.selectedRange().length != range.length {
            textView.setSelectedRange(range)
        }
        textViewTextDidChangeSelectedRange(range)
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ModalViewController {
            return other == self
        }
        return false
    }
    
    fileprivate var genericView:ShareModalView {
        return self.view as! ShareModalView
    }
    
    override func viewClass() -> AnyClass {
        return ShareModalView.self
    }
    
    override func initializer() -> NSView {
        let vz = viewClass() as! ShareModalView.Type
        return vz.init(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), shareObject: share);
    }

    
    override var modal: Modal? {
        didSet {
            modal?.interactions?.updateEnables(false)
        }
    }
    
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return !selectInteractions.presentation.multipleSelection && !(item is SeparatorRowItem)
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return !selectInteractions.presentation.multipleSelection
    }
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private func invokeShortCut(_ index: Int) {
        if genericView.tableView.count > index, let item = self.genericView.tableView.item(at: index) as? ShortPeerRowItem  {
            _ = self.genericView.tableView.select(item: item)
            (item.view as? ShortPeerRowView)?.invokeAction(item, clickCount: 1)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let context = self.share.context
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.tableView.highlightPrev()
            return .invoked
        }, with: self, for: .UpArrow, priority: .modal)
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.tableView.highlightNext()
            return .invoked
        }, with: self, for: .DownArrow, priority: .modal)
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            if let highlighted = self.genericView.tableView.highlightedItem() as? ShortPeerRowItem  {
                _ = self.genericView.tableView.select(item: highlighted)
                (highlighted.view as? ShortPeerRowView)?.invokeAction(highlighted, clickCount: 1)
            }
            
            return .rejected
        }, with: self, for: .Return, priority: .low)
        
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.selectInteractions.action(context.peerId, nil)
            return .invoked
        }, with: self, for: .Zero, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.invokeShortCut(0)
            return .invoked
        }, with: self, for: .One, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.invokeShortCut(1)
            return .invoked
        }, with: self, for: .Two, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.invokeShortCut(2)
            return .invoked
        }, with: self, for: .Three, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.invokeShortCut(3)
            return .invoked
        }, with: self, for: .Four, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.invokeShortCut(4)
            return .invoked
        }, with: self, for: .Five, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.invokeShortCut(5)
            return .invoked
        }, with: self, for: .Six, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.invokeShortCut(6)
            return .invoked
        }, with: self, for: .Seven, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.invokeShortCut(7)
            return .invoked
        }, with: self, for: .Eight, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.invokeShortCut(8)
            return .invoked
        }, with: self, for: .Nine, priority: self.responderPriority, modifierFlags: [.command])
        
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.boldWord()
            return .invoked
        }, with: self, for: .B, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.makeUrl()
            return .invoked
        }, with: self, for: .U, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.italicWord()
            return .invoked
        }, with: self, for: .I, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.codeWord()
            return .invoked
        }, with: self, for: .K, priority: self.responderPriority, modifierFlags: [.command, .shift])
    }
    
    
    private func makeUrl() {
        let range = self.genericView.textView.selectedRange()
        guard range.min != range.max, let window = window else {
            return
        }
        var effectiveRange:NSRange = NSMakeRange(NSNotFound, 0)
        let defaultTag: TGInputTextTag? = genericView.textView.attributedString().attribute(NSAttributedString.Key(rawValue: TGCustomLinkAttributeName), at: range.location, effectiveRange: &effectiveRange) as? TGInputTextTag
        let defaultUrl = defaultTag?.attachment as? String
        if effectiveRange.location == NSNotFound || defaultTag == nil {
            effectiveRange = range
        }
        showModal(with: InputURLFormatterModalController(string: genericView.textView.string().nsstring.substring(with: effectiveRange), defaultUrl: defaultUrl, completion: { [weak self] text, url in
            self?.genericView.textView.addLink(url, text: text, range: effectiveRange)
        }), for: window)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.window?.removeAllHandlers(for: self)
        self.contextChatInteraction.remove(observer: self)
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    
    private func openForum(_ peerId: PeerId, animated: Bool) {
        let context = share.context
        let selectInteractions = self.selectInteractions
        var filter = chatListViewForLocation(chatListLocation: .forum(peerId: peerId), location: .Initial(100, nil), filter: nil, account: context.account) |> filter {
            !$0.list.isLoading
        } |> take(1)
        genericView.basicSearchView.setString("")
        filter = showModalProgress(signal: filter, for: context.window)
        let signal: Signal<[EngineChatList.Item], NoError> = combineLatest(filter, self.search.get()) |> map { update, query in
            let items = update.list.items.reversed().filter {
                $0.renderedPeer.peer?._asPeer().canSendMessage(true, threadData: $0.threadData) ?? true
            }
            if query.request.isEmpty {
                return items
            } else {
                return items.filter { item in
                    let title = item.threadData?.info.title ?? ""
                    return title.lowercased().contains(query.request.lowercased())
                }
            }
        } |> deliverOnMainQueue
        
        
        forumDisposable.set(signal.start(next: { [weak self] items in
            self?.genericView.appearForumTopics(items, peerId: peerId, interactions: selectInteractions, delegate: self, context: context, animated: animated)
            self?.forumPeerId.set(peerId)
        }))
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let initialSize = self.atomicSize.modify({$0})
        let context = self.share.context
        let share = self.share
        let selectInteraction = self.selectInteractions
        selectInteraction.add(observer: self)
        
        
        selectInteractions.update(animated: false, {
            $0.withUpdatedMultipleSelection(share.multipleSelection)
        })
        
        if share.multipleSelection {
            search.set(combineLatest(genericView.tokenizedView.textUpdater, genericView.tokenizedView.stateValue.get()) |> map { SearchState(state: $1, request: $0)})
        } else {
            search.set(genericView.basicSearchView.searchValue)
        }
        self.multipleSelection.set(share.multipleSelection)
        
        
        self.notify(with: self.selectInteractions.presentation, oldValue: self.selectInteractions.presentation, animated: false)
        self.contextChatInteraction.add(observer: self)

        
        genericView.tableView.delegate = self
        
        let interactions = EntertainmentInteractions(.emoji, peerId: PeerId(0))
        interactions.sendEmoji = { [weak self] emoji, _ in
            self?.genericView.textView.appendText(emoji)
            _ = self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        }
        emoji.update(with: interactions, chatInteraction: self.contextChatInteraction)
        
        genericView.emojiButton.set(handler: { [weak self] control in
            self?.showEmoji(for: control)
        }, for: .Hover)

        
        genericView.textView.delegate = self
        genericView.hasShareMenu = self.share.hasLink
        
        
        
        genericView.dismiss.set(handler: { [weak self] _ in
            if self?.genericView.inForumMode == true {
                self?.cancelForum(animated: true)
            } else {
                self?.close()
            }
        }, for: .Click)
        
              
     
        
        let previous:Atomic<[SelectablePeersEntry]?> = Atomic(value: nil)
        
        selectInteraction.action = { [weak self] peerId, threadId in
            guard let `self` = self else { return }
            let id = threadId != nil ? makeThreadIdMessageId(peerId: peerId, threadId: threadId!) : nil
            _ = share.perform(to: [peerId], threadId: id, comment: self.contextChatInteraction.presentation.interfaceState.inputState).start(error: { error in
               alert(for: context.window, info: error)
            }, completed: { [weak self] in
                self?.close()
            })
        }
        
        selectInteraction.openForum = { [weak self] peerId in
            self?.openForum(peerId, animated: true)
            
        }
        
        genericView.share.contextMenu = { [weak self] in
            let menu = ContextMenu()
            menu.addItem(ContextMenuItem(strings().modalCopyLink, handler: {
                if share.hasLink {
                    share.shareLink()
                    self?.show(toaster: ControllerToaster(text: strings().shareLinkCopied), for: 2.0, animated: true)
                }
            }, itemImage: MenuAnimation.menu_copy_link.value))
            return menu
        }
        
        genericView.sendButton.set(handler: { [weak self] _ in
            if let strongSelf = self, !selectInteraction.presentation.selected.isEmpty {
                _ = strongSelf.invoke()
            }
        }, for: .SingleClick)
        

        genericView.sendWithoutSound = { [weak self] in
            self?.share.withoutSound = true
            _ = self?.invoke()
        }
        genericView.scheduleMessage = { [weak self] in
            guard let share = self?.share else {
                return
            }
            let context = share.context
            let peerId = share.context.peerId
            showModal(with: DateSelectorModalController(context: context, mode: .schedule(peerId), selectedAt: { date in
                self?.share.scheduleDate = date
                _ = self?.invoke()
            }), for: context.window)
        }
        
        genericView.scheduleWhenOnline = { [weak self] in
            guard let share = self?.share else {
                return
            }
            let context = share.context
            let peerId = share.context.peerId
            self?.share.scheduleDate = scheduleWhenOnlineDate
            _ = self?.invoke()
        }
        
        tokenDisposable.set(genericView.tokenizedView.tokensUpdater.start(next: { tokens in
            let ids = Set(tokens.map({PeerId($0.uniqueId)}))
            let unselected = selectInteraction.presentation.selected.symmetricDifference(ids)
            
            selectInteraction.update( { unselected.reduce($0, { current, value in
                return current.deselect(peerId: value)
            })})

        }))
        

        
        
        let defaultItems = context.account.postbox.transaction { transaction -> [Peer] in
            var peers:[Peer] = []
            
            if let addition = share.additionTopItems {
                for item in addition.items {
                    if share.defaultSelectedIds.contains(item.peer.id) {
                        peers.append(item.peer)
                    }
                }
            }
           
            for peerId in share.defaultSelectedIds  {
                if let peer = transaction.getPeer(peerId) {
                    peers.append(peer)
                }
            }
            return peers
        }
        
        
        
        let filter = ValuePromise<FilterData>(ignoreRepeated: true)
        let filterValue = Atomic<FilterData>(value: FilterData(filter: .allChats, tabs: [], sidebar: false, request: .Initial(50, nil)))
        
        func updateFilter(_ f:(FilterData)->FilterData) {
            let previous = filterValue.with { $0 }
            let data = filterValue.modify(f)
            if previous.filter != data.filter {
                self.genericView.tableView.scroll(to: .up(true))
            }
            filter.set(data)
        }
        
        var first: Bool = true
        let filterView = chatListFilterPreferences(engine: context.engine) |> deliverOnMainQueue
        filterDisposable.set(filterView.start(next: { filters in
            updateFilter( { current in
                var current = current
                current = current.withUpdatedTabs(filters.list)
                if !first, let updated = filters.list.first(where: { $0.id == current.filter.id }) {
                    current = current.withUpdatedFilter(updated)
                } else {
                    current = current.withUpdatedFilter(nil)
                }
                return current
            } )
            first = false
        }))
        
        genericView.tableView.set(stickClass: ChatListRevealItem.self, handler: { _ in
            
        })
        
        selectInteraction.updateFolder = { filter in
            updateFilter {
                $0.withUpdatedFilter(filter)
            }
        }
        
        let chatList: Signal<(EngineChatList, FilterData), NoError> = filter.get() |> mapToSignal { data in
            let signal = chatListViewForLocation(chatListLocation: .chatList(groupId: .root), location: data.request, filter: data.filter, account: context.account) |> take(1)
            return  signal |> map { view in
                return (view.list, data)
            }
        }
        
        let list:Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, search.get() |> distinctUntilChanged, forumPeerId.get(), multipleSelection.get(), chatList) |> mapToSignal { query, forumPeerId, multipleSelection, chatList -> Signal<TableUpdateTransition, NoError> in
            
            if query.request.isEmpty || query.state == .None {
                if !multipleSelection && query.state == .Focus && forumPeerId == nil {
                    return combineLatest(context.account.postbox.loadedPeerWithId(context.peerId), context.engine.peers.recentPeers() |> deliverOnPrepareQueue, context.engine.peers.recentlySearchedPeers() |> deliverOnPrepareQueue) |> map { user, rawTop, recent -> TableUpdateTransition in
                        
                        var entries:[SelectablePeersEntry] = []
                        
                        let top:[Peer]
                        switch rawTop {
                        case let .peers(peers):
                            top = peers
                        default:
                            top = []
                        }
                        
                        
                        var contains:[PeerId:PeerId] = [:]
                        
                        var indexId:Int32 = Int32.max
                        
                        let chatListIndex:()-> ChatListIndex = {
                            let index = MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 1, id: indexId), timestamp: indexId)
                            indexId -= 1
                            return ChatListIndex(pinningIndex: nil, messageIndex: index)
                        }
                        
                        entries.append(.plain(user, ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: Int32.max), timestamp: Int32.max)), nil, nil, top.isEmpty && recent.isEmpty, multipleSelection))
                        contains[user.id] = user.id
                        
                        if !top.isEmpty {
                            entries.insert(.separator(strings().searchSeparatorPopular.uppercased(), chatListIndex()), at: 0)
                            
                            var count: Int32 = 0
                            for peer in top {
                                if contains[peer.id] == nil {
                                    if share.possibilityPerformTo(peer) {
                                        entries.insert(.plain(peer, chatListIndex(), nil, nil, count < 4, multipleSelection), at: 0)
                                        contains[peer.id] = peer.id
                                        count += 1
                                    }
                                }
                                if count >= 5 {
                                    break
                                }
                            }
                        }
                        
                        if !recent.isEmpty {
                            
                            entries.insert(.separator(strings().searchSeparatorRecent.uppercased(), chatListIndex()), at: 0)
                            
                            for rendered in recent {
                                if let peer = rendered.peer.chatMainPeer {
                                    if contains[peer.id] == nil {
                                        if share.possibilityPerformTo(peer) {
                                            entries.insert(.plain(peer, chatListIndex(), nil, nil, true, multipleSelection), at: 0)
                                            contains[peer.id] = peer.id
                                        }
                                    }
                                }
                            }
                        }
                        
                        entries.sort(by: <)
                        
                        return prepareEntries(from: previous.swap(entries), to: entries, context: context, initialSize: initialSize, animated: true, multipleSelection: multipleSelection, selectInteraction:selectInteraction, share: share)
                        
                    } |> take(1)
                } else {
                    var peerIds:[PeerId] = []
                    for entry in chatList.0.items {
                        peerIds.append(entry.renderedPeer.peerId)

                    }
                    let keys = peerIds.map {PostboxViewKey.peer(peerId: $0, components: .all)}
                    return combineLatest(context.account.postbox.combinedView(keys: keys), context.account.postbox.loadedPeerWithId(context.peerId)) |> map { values, selfPeer -> (EngineChatList, FilterData, [PeerId: PeerStatusStringResult], Peer) in
                        var presences:[PeerId: PeerStatusStringResult] = [:]
                        for value in values.views {
                            if let view = value.value as? PeerView {
                                presences[view.peerId] = stringStatus(for: view, context: context)
                            }
                        }
                        return (chatList.0, chatList.1, presences, selfPeer)
                    } |> deliverOn(prepareQueue) |> take(1) |> map { value -> TableUpdateTransition in
                        var entries:[SelectablePeersEntry] = []
                        
                        
                        
                        var contains:[PeerId:PeerId] = [:]
                        
                        var offset: Int32 = Int32.max
                        
                        if let additionTopItems = share.additionTopItems {
                            var index = ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: offset), timestamp: offset))
                            entries.append(.separator(additionTopItems.topSeparator, index))
                            offset -= 1
                            
                            
                            for item in additionTopItems.items {
                                index = ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: offset), timestamp: offset))
                                let theme = PeerStatusStringTheme()
                                
                                let status = NSAttributedString.initialize(string: item.status, color: theme.statusColor, font: theme.statusFont)
                                let title = NSAttributedString.initialize(string: item.peer.displayTitle, color: theme.titleColor, font: theme.titleFont)
                                entries.append(.plain(item.peer, index, PeerStatusStringResult(title, status), nil, true, multipleSelection))
                                offset -= 1
                            }
                            
                            index = ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: offset), timestamp: offset))
                            entries.append(.separator(additionTopItems.bottomSeparator, index))
                            offset -= 1
                        }
                        
                        if !share.excludePeerIds.contains(value.3.id) {
                            entries.append(.plain(value.3, ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: offset), timestamp: offset)), nil, nil, true, multipleSelection))
                            contains[value.3.id] = value.3.id
                        }
                        
                        for item in value.0.items {
                            if let main = item.renderedPeer.peer?._asPeer() {
                                if contains[main.id] == nil {
                                    if share.possibilityPerformTo(main) {
                                        if let peer = item.renderedPeer.chatMainPeer?._asPeer() {
                                            if main.id.namespace == Namespaces.Peer.SecretChat {
                                                entries.append(.secretChat(peer, main.id, item.chatListIndex, value.2[peer.id], true, multipleSelection))
                                            } else {
                                                entries.append(.plain(peer, item.chatListIndex, value.2[peer.id], item.autoremoveTimeout, true, multipleSelection))
                                            }
                                        }
                                        contains[main.id] = main.id
                                    }
                                }
                            }
                        }
                        
                        if !value.1.isEmpty {
                            entries.append(.folders(value.1.tabs, value.1.filter))
                        } else {
                            var bp = 0
                            bp += 1
                        }
                        
                        entries.sort(by: <)
                        
                        return prepareEntries(from: previous.swap(entries), to: entries, context: context, initialSize: initialSize, animated: true, multipleSelection: multipleSelection, selectInteraction:selectInteraction, share: share)
                    }
                }
                
                
            } else if forumPeerId == nil {
                
                
                var all = query.request.transformKeyboard
                all.insert(query.request.lowercased(), at: 0)
                all = all.uniqueElements
                let localPeers = combineLatest(all.map {
                    return context.account.postbox.searchPeers(query: $0)
                }) |> map { result in
                    return result.reduce([], {
                        return $0 + $1
                    })
                }
                
                let remotePeers = Signal<[RenderedPeer], NoError>.single([]) |> then( context.engine.contacts.searchRemotePeers(query: query.request.lowercased()) |> map { $0.0.map {RenderedPeer($0)} + $0.1.map {RenderedPeer($0)} } )
                
                return combineLatest(localPeers, remotePeers) |> map {$0 + $1} |> mapToSignal { peers -> Signal<([RenderedPeer], [PeerId: PeerStatusStringResult], Peer), NoError> in
                    let keys = peers.map {PostboxViewKey.peer(peerId: $0.peerId, components: .all)}
                    return combineLatest(context.account.postbox.combinedView(keys: keys), context.account.postbox.loadedPeerWithId(context.peerId)) |> map { values, selfPeer -> ([RenderedPeer], [PeerId: PeerStatusStringResult], Peer) in
                        
                        var presences:[PeerId: PeerStatusStringResult] = [:]
                        for value in values.views {
                            if let view = value.value as? PeerView {
                                presences[view.peerId] = stringStatus(for: view, context: context)
                            }
                        }
                        
                        return (peers, presences, selfPeer)
                        
                    } |> take(1)
                } |> deliverOn(prepareQueue) |> map { values -> TableUpdateTransition in
                        var entries:[SelectablePeersEntry] = []
                        var contains:[PeerId:PeerId] = [:]
                        var i:Int32 = Int32.max
                        if query.request.isSavedMessagesText || values.0.contains(where: {$0.peerId == context.peerId}), !share.excludePeerIds.contains(values.2.id) {
                            let index = MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: i), timestamp: i)
                            entries.append(.plain(values.2, ChatListIndex(pinningIndex: 0, messageIndex: index), nil, nil, true, multipleSelection))
                            i -= 1
                            contains[values.2.id] = values.2.id
                        }
                        for renderedPeer in values.0 {
                            if let main = renderedPeer.peer {
                                if contains[main.id] == nil {
                                    if share.possibilityPerformTo(main) {
                                        if let peer = renderedPeer.chatMainPeer {
                                            
                                            let index = MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: i), timestamp: i)
                                            let id = ChatListIndex(pinningIndex: nil, messageIndex: index)
                                            i -= 1
                                            
                                            if main.id.namespace == Namespaces.Peer.SecretChat {
                                                entries.append(.secretChat(peer, main.id, id, values.1[peer.id], true, multipleSelection))
                                            } else {
                                                entries.append(.plain(peer, id, values.1[peer.id], nil, true, multipleSelection))
                                            }
                                        }
                                        contains[main.id] = main.id
                                    }
                                }
                            }
                        }
                        if entries.isEmpty {
                            entries.append(.emptySearch)
                        }
                    
                        
                    
                        entries.sort(by: <)
                    
                        return prepareEntries(from: previous.swap(entries), to: entries, context: context, initialSize: initialSize, animated: false, multipleSelection: multipleSelection, selectInteraction:selectInteraction, share: share)
                }
            } else {
                return .complete()
            }
        } |> deliverOnMainQueue
        
        let signal:Signal<TableUpdateTransition, NoError> = defaultItems |> deliverOnMainQueue |> mapToSignal { [weak self] defaultSelected in
            
            self?.selectInteractions.update(animated: false, { value in
                var value = value
                for peer in defaultSelected {
                    value = value.withToggledSelected(peer.id, peer: peer)
                }
                return value
            })
            
            return list
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.applyTransition(transition)
            self?.readyOnce()
        }))
                
        
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        _ = window?.makeFirstResponder(nil)
        return false
    }
    
    
    override func firstResponder() -> NSResponder? {
        if window?.firstResponder == genericView.textView.inputView {
            return genericView.textView.inputView
        }
        
        if let event = NSApp.currentEvent {
            if event.type == .keyDown {
                switch event.keyCode {
                case KeyboardKey.UpArrow.rawValue:
                    return window?.firstResponder
                case KeyboardKey.DownArrow.rawValue:
                    return window?.firstResponder
                default:
                    break
                }
            }
        }
        
        if selectInteractions.presentation.multipleSelection {
            return genericView.tokenizedView.responder
        } else {
            return genericView.basicSearchView.input
        }
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let event = NSApp.currentEvent, !FastSettings.checkSendingAbility(for: event) {
            return .rejected
        }
        return invoke()
    }
    
    private func invoke() -> KeyHandlerResult {
        if !genericView.tokenizedView.query.isEmpty {
            if !genericView.tableView.isEmpty, let item = genericView.tableView.item(at: 0) as? ShortPeerRowItem {
                selectInteractions.update({$0.withToggledSelected(item.peer.id, peer: item.peer)})
            }
            return .invoked
        }
        if !selectInteractions.presentation.peers.isEmpty || share.alwaysEnableDone {
            
            let ids = selectInteractions.presentation.selected

            let account = share.context.account
     
            let peerAndData:Signal<[(TelegramChannel, CachedChannelData?)], NoError> = share.context.account.postbox.transaction { transaction in
                var result:[(TelegramChannel, CachedChannelData?)] = []
                for id in ids {
                    if let peer = transaction.getPeer(id) as? TelegramChannel {
                        result.append((peer, transaction.getPeerCachedData(peerId: id) as? CachedChannelData))
                    }
                }
                return result
            } |> deliverOnMainQueue
            
            
            
            let signal = peerAndData |> mapToSignal { peerAndData in
                return account.postbox.unsentMessageIdsView() |> take(1) |> map {
                    (peerAndData, Set($0.ids.map { $0.peerId }))
                }
            } |> deliverOnMainQueue
            
            _ = signal.start(next: { [weak self] (peerAndData, unsentIds) in
                guard let `self` = self else { return }
                let share = self.share
                let comment = self.genericView.textView.string()
                
                enum ShareFailedTarget {
                    case token
                    case comment
                }
                struct ShareFailedReason {
                    let peerId:PeerId
                    let reason: String
                    let target: ShareFailedTarget
                }
                
                var failed:[ShareFailedReason] = []
                
                for (peer, cachedData) in peerAndData {
                    inner: switch peer.info {
                    case let .group(info):
                        if info.flags.contains(.slowModeEnabled) && (peer.adminRights == nil && !peer.flags.contains(.isCreator)) {
                            if let cachedData = cachedData, let validUntil = cachedData.slowModeValidUntilTimestamp {
                                if validUntil > share.context.timestamp {
                                    failed.append(ShareFailedReason(peerId: peer.id, reason: slowModeTooltipText(validUntil - share.context.timestamp), target: .token))
                                }
                            }
                            if !comment.isEmpty {
                                failed.append(ShareFailedReason(peerId: peer.id, reason: strings().slowModeForwardCommentError, target: .comment))
                            }
                            if unsentIds.contains(peer.id) {
                                failed.append(ShareFailedReason(peerId: peer.id, reason: strings().slowModeMultipleError, target: .token))
                            }
                        }
                        
                    default:
                        break inner
                    }
                }
                if failed.isEmpty {
                    self.genericView.tokenizedView.removeAllFailed(animated: true)
                    _ = share.perform(to: Array(ids), threadId: nil, comment: self.contextChatInteraction.presentation.interfaceState.inputState).start()
                    self.emoji.popover?.hide()
                    self.close()
                } else {
                    self.genericView.tokenizedView.markAsFailed(failed.map {
                        $0.peerId.toInt64()
                    }, animated: true)
                    
                    let last = failed.last!
                    
                    switch last.target {
                    case .comment:
                        self.genericView.textView.shake()
                        tooltip(for: self.genericView.bottomSeparator, text: last.reason)
                    case .token:
                        self.genericView.tokenizedView.addTooltip(for: last.peerId.toInt64(), text: last.reason)
                    }
                }
            })
        
            return .invoked
        }
        
        if share is ForwardMessagesObject {
            if genericView.tableView.highlightedItem() == nil, !genericView.tableView.isEmpty {
                let item = genericView.tableView.item(at: 0)
                if let item = item as? ShortPeerRowItem {
                    item.action()
                }
                _ = genericView.tableView.select(item: item)
                return .invoked
            }
        }
        
        return .rejected
    }
    
    private func cancelForum(animated: Bool) {
        self.forumPeerId.set(nil)
        self.forumDisposable.set(nil)
        self.genericView.cancelForum(animated: animated)
        self.genericView.basicSearchView.cancel(animated)
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.tableView.highlightedItem() != nil {
            genericView.tableView.cancelHighlight()
            return .invoked
        }
        if genericView.inForumMode {
            self.cancelForum(animated: true)
            return .invoked
        }
        if genericView.tokenizedView.state == .Focus {
            _ = window?.makeFirstResponder(nil)
            return .invoked
        }
        
        return .rejected
    }

    private let emoji: EmojiesController
    
    init(_ share:ShareObject) {
        self.share = share
        emoji = EmojiesController(share.context)
        self.contextChatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: share.context)
        inputContextHelper = InputContextHelper(chatInteraction: contextChatInteraction)
        super.init(frame: NSMakeRect(0, 0, 360, 400))
        bar = .init(height: 0)
        
        
        contextChatInteraction.movePeerToInput = { [weak self] peer in
            if let strongSelf = self {
                let string = strongSelf.genericView.textView.string()
                let range = strongSelf.genericView.textView.selectedRange()
                let textInputState = ChatTextInputState(inputText: string, selectionRange: range.min ..< range.max, attributes: chatTextAttributes(from: strongSelf.genericView.textView.attributedString()))
                strongSelf.contextChatInteraction.update({$0.withUpdatedEffectiveInputState(textInputState)})
                if let (range, _, _) = textInputStateContextQueryRangeAndType(textInputState, includeContext: false) {
                    let inputText = textInputState.inputText
                    
                    let name:String = peer.addressName ?? peer.compactDisplayTitle
                    
                    let distance = inputText.distance(from: range.lowerBound, to: range.upperBound)
                    let replacementText = name + " "
                    
                    let atLength = peer.addressName != nil ? 0 : 1
                    
                    let range = strongSelf.contextChatInteraction.appendText(replacementText, selectedRange: textInputState.selectionRange.lowerBound - distance - atLength ..< textInputState.selectionRange.upperBound)
                    
                    if peer.addressName == nil {
                        let state = strongSelf.contextChatInteraction.presentation.effectiveInput
                        var attributes = state.attributes
                        attributes.append(.uid(range.lowerBound ..< range.upperBound - 1, peer.id.id._internalGetInt64Value()))
                        let updatedState = ChatTextInputState(inputText: state.inputText, selectionRange: state.selectionRange, attributes: attributes)
                        strongSelf.contextChatInteraction.update({$0.withUpdatedEffectiveInputState(updatedState)})
                    }
                }
            }
        }
        
        
        bar = .init(height: 0)
    }

    func showEmoji(for control: Control) {
        showPopover(for: control, with: emoji)
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
        updateSize(frame.width, animated: animated)
        
        genericView.textViewUpdateHeight(height, animated)
        
    }

    func textViewEnterPressed(_ event: NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            _ = returnKeyAction()
            return true
        }
        return false
    }
    
    func textViewTextDidChange(_ string: String) {
        let range = self.genericView.textView.selectedRange()
        self.selectInteractions.update {
            $0.withUpdatedComment(.init(string: string, range: range))
        }
        let attributed = genericView.textView.attributedString()
        let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.location ..< range.location + range.length, attributes: chatTextAttributes(from: attributed))
        contextChatInteraction.update({$0.withUpdatedEffectiveInputState(state)})

    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        let string = self.genericView.textView.string()
        self.selectInteractions.update {
            $0.withUpdatedComment(.init(string: string, range: range))
        }
        let attributed = genericView.textView.attributedString()
        let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.location ..< range.location + range.length, attributes: chatTextAttributes(from: attributed))
        contextChatInteraction.update({$0.withUpdatedEffectiveInputState(state)})
    }
    
    func textViewDidReachedLimit(_ textView: Any) {
        genericView.textView.shake()
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        return false
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        return NSMakeSize(frame.width - 40, textView.frame.height)
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func canTransformInputText() -> Bool {
        return true
    }
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        return 1024
    }
    
    private func updateSize(_ width: CGFloat, animated: Bool) {
        if let contentSize = self.window?.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(width, min(contentSize.height - 100, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: animated)
        }
    }
    
    override var modalInteractions: ModalInteractions? {
        if !share.hasCaptionView, share.hasInteraction {
            return ModalInteractions(acceptTitle: share.interactionOk, accept: { [weak self] in
                _ = self?.invoke()
            }, drawBorder: true, height: 50, singleButton: true)
        } else {
            return nil
        }
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 100, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: false)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        if self.share.emptyPerformOnClose {
            _ = self.share.perform(to: [], threadId: nil).start()
        }
        super.close(animationType: animationType)
    }
    
    deinit {
        disposable.dispose()
        tokenDisposable.dispose()
        exportLinkDisposable.dispose()
        forumDisposable.dispose()
        filterDisposable.dispose()
    }
    
}
