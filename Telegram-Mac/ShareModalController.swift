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
import SyncCore
import Postbox



fileprivate class ShareButton : Control {
    private var badge: BadgeNode?
    private var badgeView: View = View()
    private let shareText = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(badgeView)
        addSubview(shareText)
        let layout = TextViewLayout(.initialize(string: tr(L10n.modalShare).uppercased(), color: .white, font: .normal(.header)), maximumNumberOfLines: 1)
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

fileprivate class ShareModalView : View, TokenizedProtocol {
    let tokenizedView:TokenizedView
    let basicSearchView: SearchView = SearchView(frame: NSMakeRect(0,0, 260, 30))
    let tableView:TableView = TableView()
    fileprivate let share:ImageButton = ImageButton()
    fileprivate let dismiss:ImageButton = ImageButton()
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    fileprivate let textView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    fileprivate let sendButton = ImageButton()
    fileprivate let emojiButton = ImageButton()
    fileprivate let actionsContainerView: View = View()
    fileprivate let textContainerView: View = View()
    fileprivate let bottomSeparator: View = View()

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
        share.set(image: theme.icons.modalShare, for: .Normal)
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        
        _ = share.sizeToFit()
        _ = dismiss.sizeToFit()
        
        addSubview(share)
        addSubview(dismiss)
        
        
  
        
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
        textView.setPlaceholderAttributedString(.initialize(string:  tr(L10n.previewSenderCommentPlaceholder), color: theme.colors.grayText, font: .normal(.text)), update: false)

        
        textContainerView.addSubview(textView)

        addSubview(textContainerView)
        addSubview(actionsContainerView)
        addSubview(bottomSeparator)

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
            dismiss.isHidden = !hasCaptionView
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
    
    
    
    func tokenizedViewDidChangedHeight(_ view: TokenizedView, height: CGFloat, animated: Bool) {
        searchView._change(pos: NSMakePoint(50, 10), animated: animated)
        tableView.change(size: NSMakeSize(frame.width, frame.height - height - 20 - (textContainerView.isHidden ? 0 : textContainerView.frame.height)), animated: animated)
        tableView.change(pos: NSMakePoint(0, height + 20), animated: animated)
        topSeparator.change(pos: NSMakePoint(0, searchView.frame.maxY + 10), animated: animated)
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
    var interactionOk: String {
        return L10n.modalOK
    }
    
    var searchPlaceholderKey: String {
        return "ShareModal.Search.Placeholder"
    }

    var alwaysEnableDone: Bool {
        return false
    }
    
    func perform(to entries:[PeerId], comment: String? = nil) -> Signal<Never, String> {
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
        return peer.canSendMessage && !self.excludePeerIds.contains(peer.id)
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
    
    override func perform(to peerIds:[PeerId], comment: String? = nil) -> Signal<Never, String> {
        for peerId in peerIds {
            
            if let comment = comment?.trimmed, !comment.isEmpty {
                _ = Sender.enqueue(message: EnqueueMessage.message(text: comment, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil), context: context, peerId: peerId).start()
            }
            
            var attributes:[MessageAttribute] = []
            if FastSettings.isChannelMessagesMuted(peerId) {
                attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
            }
            _ = enqueueMessages(context: context, peerId: peerId, messages: [EnqueueMessage.message(text: link, attributes: attributes, mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
        }
        return .complete()
    }
}

class ShareContactObject : ShareObject {
    let user:TelegramUser
    init(_ context: AccountContext, user:TelegramUser) {
        self.user = user
        super.init(context)
    }
    
    override func perform(to peerIds:[PeerId], comment: String? = nil) -> Signal<Never, String> {
        for peerId in peerIds {
            _ = Sender.shareContact(context: context, peerId: peerId, contact: user).start()
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
    
    override func perform(to peerIds:[PeerId], comment: String? = nil) -> Signal<Never, String> {
        return callback(peerIds) |> mapError { _ in return String() }
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
        var peer = messageMainPeer(message) as? TelegramChannel
        var messageId = message.id
        if let author = message.forwardInfo?.author as? TelegramChannel {
            peer = author
            messageId = message.forwardInfo?.sourceMessageId ?? message.id
        }
//            peer = messageMainPeer(message) as? TelegramChannel
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
           exportLinkDisposable.set(exportMessageLink(account: context.account, peerId: messageIds[0].peerId, messageId: messageIds[0]).start(next: { valueLink in
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

    override func perform(to peerIds:[PeerId], comment: String? = nil) -> Signal<Never, String> {
        for peerId in peerIds {
            if let comment = comment?.trimmed, !comment.isEmpty {
                _ = Sender.enqueue(message: EnqueueMessage.message(text: comment, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil), context: context, peerId: peerId).start()
            }
            
            _ = Sender.forwardMessages(messageIds: messageIds, context: context, peerId: peerId).start()
        }
        return .complete()
    }
    
    override func possibilityPerformTo(_ peer:Peer) -> Bool {
        return message.possibilityForwardTo(peer)
    }
}

final class ForwardMessagesObject : ShareObject {
    fileprivate let messageIds: [MessageId]
    private let disposable = MetaDisposable()
    init(_ context: AccountContext, messageIds: [MessageId], emptyPerformOnClose: Bool = false) {
        self.messageIds = messageIds
        super.init(context, emptyPerformOnClose: emptyPerformOnClose)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override var multipleSelection: Bool {
        return false
    }
    
    override func perform(to peerIds: [PeerId], comment: String?) -> Signal<Never, String> {
        let comment = comment != nil && !comment!.isEmpty ? comment : nil
        let context = self.context
        
        let peers = context.account.postbox.transaction { transaction -> Peer? in
            for peerId in peerIds {
                if let peer = transaction.getPeer(peerId) {
                    return peer
                }
            }
            return nil
        }
        
        return combineLatest(context.account.postbox.messagesAtIds(messageIds), peers)
            |> deliverOnMainQueue
            |> mapError { _ in return String() }
            |> mapToSignal {  messages, peer in
                
                let messageIds = messages.map { $0.id }
                
                if let peer = peer, peer.isChannel {
                    for message in messages {
                        if message.isPublicPoll {
                            return .fail(L10n.pollForwardError)
                        }
                    }
                }
                
                let navigation = self.context.sharedContext.bindings.rootNavigation()
                if let peerId = peerIds.first {
                    if peerId == context.peerId {
                        _ = Sender.forwardMessages(messageIds: messageIds, context: context, peerId: context.account.peerId).start()
                        if let controller = context.sharedContext.bindings.rootNavigation().controller as? ChatController {
                            controller.chatInteraction.update({$0.withoutSelectionState()})
                        }
                        delay(0.2, closure: {
                            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
                        })
                    } else {
                        if let controller = navigation.controller as? ChatController, controller.chatInteraction.peerId == peerId {
                            controller.chatInteraction.update({$0.withoutSelectionState().updatedInterfaceState({$0.withUpdatedForwardMessageIds(messageIds)})})
                        } else {
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
                                newone = ChatController(context: context, chatLocation: .peer(peerId), initialAction: .forward(messageIds: messageIds, text: comment, behavior: .automatic))
                            } else {
                                newone = ChatAdditionController(context: context, chatLocation: .peer(peerId), initialAction: .forward(messageIds: messageIds, text: comment, behavior: .automatic))
                            }
                            navigation.push(newone)
                            
                            return newone.ready.get() |> filter {$0} |> take(1) |> ignoreValues |> mapError { _ in return String() }
                        }
                    }
                } else {
                    if let controller = navigation.controller as? ChatController {
                        controller.chatInteraction.update({$0.withoutSelectionState().updatedInterfaceState({$0.withUpdatedForwardMessageIds(messageIds)})})
                    }
                }
                return .complete()
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
    var hashValue: Int {
        switch self {
        case let .plain(peerId, _):
            return peerId.hashValue
        case .separator(let index):
            return index.hashValue
        case .emptySearch:
            return 0
        }
    }
}

enum SelectablePeersEntry : Comparable, Identifiable {
    case secretChat(Peer, PeerId, ChatListIndex, PeerStatusStringResult?, Bool)
    case plain(Peer, ChatListIndex, PeerStatusStringResult?, Bool)
    case separator(String, ChatListIndex)
    case emptySearch
    var stableId: SelectablePeersEntryStableId {
        switch self {
        case let .plain(peer, index, _, _):
            return .plain(peer.id, index)
        case let .secretChat(_, peerId, index, _, _):
            return .plain(peerId, index)
        case let .separator(_, index):
            return .separator(index)
        case .emptySearch:
            return .emptySearch
        }
    }
    
    var index:ChatListIndex {
        switch self {
        case let .plain(_, id, _, _):
            return id
        case let .secretChat(_, _, id, _, _):
            return id
        case let .separator(_, index):
            return index
        case .emptySearch:
            return ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex.absoluteLowerBound())
        }
    }
}

func <(lhs:SelectablePeersEntry, rhs:SelectablePeersEntry) -> Bool {
    return lhs.index < rhs.index
}

func ==(lhs:SelectablePeersEntry, rhs:SelectablePeersEntry) -> Bool {
    switch lhs {
    case let .plain(lhsPeer, lhsIndex, lhsPresence, lhsSeparator):
        if case let .plain(rhsPeer, rhsIndex, rhsPresence, rhsSeparator) = rhs {
            return lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex && lhsPresence == rhsPresence && lhsSeparator == rhsSeparator
        } else {
            return false
        }
    case let .secretChat(lhsPeer, lhsPeerId, lhsIndex, lhsPresence, lhsSeparator):
        if case let .secretChat(rhsPeer, rhsPeerId, rhsIndex, rhsPresence, rhsSeparator) = rhs {
            return lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex && lhsPresence == rhsPresence && lhsSeparator == rhsSeparator && lhsPeerId == rhsPeerId
        } else {
            return false
        }
    case let .separator(text, index):
        if case .separator(text, index) = rhs {
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



fileprivate func prepareEntries(from:[SelectablePeersEntry]?, to:[SelectablePeersEntry], account:Account, initialSize:NSSize, animated:Bool, multipleSelection: Bool, selectInteraction:SelectPeerInteraction) -> TableUpdateTransition {
  
    let (deleted,inserted,updated) = proccessEntries(from, right: to, { entry -> TableRowItem in
        
        switch entry {
        case let .plain(peer, _, presence, drawSeparator):
            let color = presence?.status.string.isEmpty == false ? presence?.status.attribute(NSAttributedString.Key.foregroundColor, at: 0, effectiveRange: nil) as? NSColor : nil
            return  ShortPeerRowItem(initialSize, peer: peer, account:account, stableId: entry.stableId, height: 48, photoSize:NSMakeSize(36, 36), statusStyle: ControlStyle(font: .normal(.text), foregroundColor: peer.id == account.peerId ? theme.colors.grayText : color ?? theme.colors.grayText, highlightColor:.white), status: peer.id == account.peerId ? (multipleSelection ? nil : L10n.forwardToSavedMessages) : presence?.status.string, drawCustomSeparator: drawSeparator, isLookSavedMessage : peer.id == account.peerId, inset:NSEdgeInsets(left: 10, right: 10), drawSeparatorIgnoringInset: true, interactionType: multipleSelection ? .selectable(selectInteraction) : .plain, action: {
               selectInteraction.action(peer.id)
            })
        case let .secretChat(peer, peerId, _, _, drawSeparator):
            return  ShortPeerRowItem(initialSize, peer: peer, account :account, peerId: peerId, stableId: entry.stableId, height: 48, photoSize:NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(.title), foregroundColor: theme.colors.accent, highlightColor: .white), statusStyle: ControlStyle(font: .normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status: L10n.composeSelectSecretChat.lowercased(), drawCustomSeparator: drawSeparator, isLookSavedMessage : peer.id == account.peerId, inset:NSEdgeInsets(left: 10, right: 10), drawSeparatorIgnoringInset: true, interactionType: multipleSelection ? .selectable(selectInteraction) : .plain, action: {
                selectInteraction.action(peerId)
            })
        case let .separator(text, _):
            return SeparatorRowItem(initialSize, entry.stableId, string: text)
        case .emptySearch:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId)
        }
        
        
    })
    
    
    return TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated: animated, state: animated ? .none(nil) : .saveVisible(.lower), grouping: true, animateVisibleOnly: false)
    
}



class ShareModalController: ModalViewController, Notifable, TGModernGrowingDelegate, TableViewDelegate {
   
    
    private let share:ShareObject
    private let selectInteractions:SelectPeerInteraction = SelectPeerInteraction()
    private let search:Promise<SearchState> = Promise()
    private let inSearchSelected:Atomic<[PeerId]> = Atomic(value:[])
    private let disposable:MetaDisposable = MetaDisposable()
    private let exportLinkDisposable:MetaDisposable = MetaDisposable()
    private let tokenDisposable: MetaDisposable = MetaDisposable()
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
            
            let added = value.selected.subtracting(oldValue.selected)
            let removed = oldValue.selected.subtracting(value.selected)

            
            let selected = value.selected.filter {
                $0.namespace != ChatListFilterPeerCategories.Namespace
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
                let title = item == share.context.account.peerId ? L10n.peerSavedMessages : value.peers[item]?.compactDisplayTitle ?? L10n.peerDeletedUser
                return SearchToken(name: title, uniqueId: item.toInt64())
            }
            genericView.tokenizedView.addTokens(tokens: tokens, animated: animated)
            
            let idsToRemove:[Int64] = removed.map {
                $0.toInt64()
            }
            genericView.tokenizedView.removeTokens(uniqueIds: idsToRemove, animated: animated)
            self.modal?.interactions?.updateEnables(!value.selected.isEmpty || share.alwaysEnableDone)
            
        }
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
        return !self.share.multipleSelection && !(item is SeparatorRowItem)
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return !self.share.multipleSelection
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
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.highlightPrev()
            return .invoked
        }, with: self, for: .UpArrow, priority: .modal)
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.highlightNext()
            return .invoked
        }, with: self, for: .DownArrow, priority: .modal)
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            if let highlighted = self.genericView.tableView.highlightedItem() as? ShortPeerRowItem  {
                _ = self.genericView.tableView.select(item: highlighted)
                (highlighted.view as? ShortPeerRowView)?.invokeAction(highlighted, clickCount: 1)
            }
            
            return .rejected
        }, with: self, for: .Return, priority: .low)
        
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.selectInteractions.action(context.peerId)
            return .invoked
        }, with: self, for: .Zero, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.invokeShortCut(0)
            return .invoked
        }, with: self, for: .One, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.invokeShortCut(1)
            return .invoked
        }, with: self, for: .Two, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.invokeShortCut(2)
            return .invoked
        }, with: self, for: .Three, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.invokeShortCut(3)
            return .invoked
        }, with: self, for: .Four, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.invokeShortCut(4)
            return .invoked
        }, with: self, for: .Five, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.invokeShortCut(5)
            return .invoked
        }, with: self, for: .Six, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.invokeShortCut(6)
            return .invoked
        }, with: self, for: .Seven, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.invokeShortCut(7)
            return .invoked
        }, with: self, for: .Eight, priority: self.responderPriority, modifierFlags: [.command])
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.invokeShortCut(8)
            return .invoked
        }, with: self, for: .Nine, priority: self.responderPriority, modifierFlags: [.command])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.window?.removeAllHandlers(for: self)
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.tableView.delegate = self
        
        let interactions = EntertainmentInteractions(.emoji, peerId: PeerId(0))
        interactions.sendEmoji = { [weak self] emoji in
            self?.genericView.textView.appendText(emoji)
            _ = self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        }
        emoji.update(with: interactions)
        
        genericView.emojiButton.set(handler: { [weak self] control in
            self?.showEmoji(for: control)
        }, for: .Hover)

        
        genericView.textView.delegate = self
        genericView.hasShareMenu = self.share.hasLink
        genericView.hasCaptionView = self.share.multipleSelection
        genericView.hasCommentView = self.share.hasCaptionView
        genericView.hasSendView = self.share.multipleSelection
        if self.share.multipleSelection {
            search.set(combineLatest(genericView.tokenizedView.textUpdater, genericView.tokenizedView.stateValue.get()) |> map { SearchState(state: $1, request: $0)})
        } else {
            search.set(genericView.basicSearchView.searchValue)
        }
        
        genericView.dismiss.set(handler: { [weak self] _ in
            self?.close()
        }, for: .Click)
        
        
        let initialSize = self.atomicSize.modify({$0})
        let request = Promise<ChatListIndexRequest>()
        let context = self.share.context
        let selectInteraction = self.selectInteractions
        
     
        
        let share = self.share
        selectInteraction.add(observer: self)
        let previous:Atomic<[SelectablePeersEntry]?> = Atomic(value: nil)
        
        selectInteraction.action = { [weak self] peerId in
            guard let `self` = self else { return }
            _ = share.perform(to: [peerId], comment: self.genericView.textView.string()).start(error: { error in
               alert(for: context.window, info: error)
            }, completed: { [weak self] in
                self?.close()
            })
        }
        
        genericView.share.set(handler: { [weak self] control in
            showPopover(for: control, with: SPopoverViewController(items: [SPopoverItem(L10n.modalCopyLink, {
                if share.hasLink {
                    share.shareLink()
                    self?.show(toaster: ControllerToaster(text: L10n.shareLinkCopied), for: 2.0, animated: true)
                }
            })]), edge: .maxY, inset: NSMakePoint(-100,  -40))
        }, for: .Click)
        
        
        genericView.sendButton.set(handler: { [weak self] _ in
            if let strongSelf = self, !selectInteraction.presentation.selected.isEmpty {
                _ = strongSelf.invoke()
            }
        }, for: .SingleClick)
        

        
        tokenDisposable.set(genericView.tokenizedView.tokensUpdater.start(next: { tokens in
            let ids = Set(tokens.map({PeerId($0.uniqueId)}))
            let unselected = selectInteraction.presentation.selected.symmetricDifference(ids)
            
            selectInteraction.update( { unselected.reduce($0, { current, value in
                return current.deselect(peerId: value)
            })})

        }))
        
        let previousChatList:Atomic<ChatListView?> = Atomic(value: nil)

        let multipleSelection = self.share.multipleSelection
        
        
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
        
        let list:Signal<TableUpdateTransition, NoError> = combineLatest(request.get() |> distinctUntilChanged |> deliverOnPrepareQueue, search.get() |> distinctUntilChanged |> deliverOnPrepareQueue) |> mapToSignal { location, query -> Signal<TableUpdateTransition, NoError> in
            
             if query.request.isEmpty {
                if !multipleSelection && query.state == .Focus {
                    return combineLatest(context.account.postbox.loadedPeerWithId(context.peerId), recentPeers(account: context.account) |> deliverOnPrepareQueue, recentlySearchedPeers(postbox: context.account.postbox) |> deliverOnPrepareQueue) |> map { user, rawTop, recent -> TableUpdateTransition in
                        
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
                        
                        entries.append(.plain(user, ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: Int32.max), timestamp: Int32.max)), nil, top.isEmpty && recent.isEmpty))
                        contains[user.id] = user.id
                        
                        if !top.isEmpty {
                            entries.insert(.separator(L10n.searchSeparatorPopular.uppercased(), chatListIndex()), at: 0)
                            
                            var count: Int32 = 0
                            for peer in top {
                                if contains[peer.id] == nil {
                                    if share.possibilityPerformTo(peer) {
                                        entries.insert(.plain(peer, chatListIndex(), nil, count < 4), at: 0)
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
                            
                            entries.insert(.separator(L10n.searchSeparatorRecent.uppercased(), chatListIndex()), at: 0)
                            
                            for rendered in recent {
                                if let peer = rendered.peer.chatMainPeer {
                                    if contains[peer.id] == nil {
                                        if share.possibilityPerformTo(peer) {
                                            entries.insert(.plain(peer, chatListIndex(), nil, true), at: 0)
                                            contains[peer.id] = peer.id
                                        }
                                    }
                                }
                            }
                        }
                        
                        entries.sort(by: <)
                        
                        return prepareEntries(from: previous.swap(entries), to: entries, account: context.account, initialSize: initialSize, animated: true, multipleSelection: multipleSelection, selectInteraction:selectInteraction)
                        
                    }
                } else {
                    var signal:Signal<(ChatListView,ViewUpdateType), NoError>
                    
                    
                    switch(location) {
                    case let .Initial(count, _):
                        signal = context.account.viewTracker.tailChatListView(groupId: .root, filterPredicate: nil, count: count)
                    case let .Index(index, _):
                        signal = context.account.viewTracker.aroundChatListView(groupId: .root, filterPredicate: nil, index: index, count: 30)
                    }
                    
                    return signal |> deliverOnPrepareQueue |> mapToSignal { value -> Signal<(ChatListView,ViewUpdateType, [PeerId: PeerStatusStringResult], Peer), NoError> in
                        var peerIds:[PeerId] = []
                        for entry in value.0.entries {
                            switch entry {
                            case let .MessageEntry(_, _, _, _, _, renderedPeer, _, _, _, _):
                                peerIds.append(renderedPeer.peerId)
                            default:
                                break
                            }
                        }
                        
                        _ = previousChatList.swap(value.0)
                        
                        let keys = peerIds.map {PostboxViewKey.peer(peerId: $0, components: .all)}
                        return combineLatest(context.account.postbox.combinedView(keys: keys), context.account.postbox.loadedPeerWithId(context.peerId)) |> map { values, selfPeer in
                            var presences:[PeerId: PeerStatusStringResult] = [:]
                            for value in values.views {
                                if let view = value.value as? PeerView {
                                    presences[view.peerId] = stringStatus(for: view, context: context)
                                }
                            }
                            
                            return (value.0, value.1, presences, selfPeer)
                            
                        } |> take(1)
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
                                entries.append(.plain(item.peer, index, PeerStatusStringResult(title, status), true))
                                offset -= 1
                            }
                            
                            index = ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: offset), timestamp: offset))
                            entries.append(.separator(additionTopItems.bottomSeparator, index))
                            offset -= 1
                        }
                        
                        if !share.excludePeerIds.contains(value.3.id) {
                            entries.append(.plain(value.3, ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: offset), timestamp: offset)), nil, true))
                            contains[value.3.id] = value.3.id
                        }
                        
                        for entry in value.0.entries {
                            switch entry {
                            case let .MessageEntry(id, _, _, _, _, renderedPeer, _, _, _, _):
                                if let main = renderedPeer.peer {
                                    if contains[main.id] == nil {
                                        if share.possibilityPerformTo(main) {
                                            if let peer = renderedPeer.chatMainPeer {
                                                if main.id.namespace == Namespaces.Peer.SecretChat {
                                                    entries.append(.secretChat(peer, main.id, id, value.2[peer.id], true))
                                                } else {
                                                    entries.append(.plain(peer, id, value.2[peer.id], true))
                                                }
                                            }
                                            contains[main.id] = main.id
                                        }
                                    }
                                }
                            default:
                                break
                            }
                        }
                        
                        entries.sort(by: <)
                        
                        return prepareEntries(from: previous.swap(entries), to: entries, account: context.account, initialSize: initialSize, animated: true, multipleSelection: multipleSelection, selectInteraction:selectInteraction)
                    }
                }
                
                
            } else {
                
                _ = previousChatList.swap(nil)
                
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
                
                let remotePeers = Signal<[RenderedPeer], NoError>.single([]) |> then( searchPeers(account: context.account, query: query.request.lowercased()) |> map { $0.0.map {RenderedPeer($0)} + $0.1.map {RenderedPeer($0)} } )
                
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
                        if L10n.peerSavedMessages.lowercased().hasPrefix(query.request.lowercased()) || NSLocalizedString("Peer.SavedMessages", comment: "nil").lowercased().hasPrefix(query.request.lowercased()) || values.0.contains(where: {$0.peerId == context.peerId}), !share.excludePeerIds.contains(values.2.id) {
                            let index = MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: i), timestamp: i)
                            entries.append(.plain(values.2, ChatListIndex(pinningIndex: 0, messageIndex: index), nil, true))
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
                                                entries.append(.secretChat(peer, main.id, id, values.1[peer.id], true))
                                            } else {
                                                entries.append(.plain(peer, id, values.1[peer.id], true))
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
                    
                        return prepareEntries(from: previous.swap(entries), to: entries, account: context.account, initialSize: initialSize, animated: false, multipleSelection: multipleSelection, selectInteraction:selectInteraction)
                }
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
            self?.genericView.tableView.resetScrollNotifies()
            self?.genericView.tableView.scroll(to: .up(false))
            self?.genericView.tableView.merge(with: transition)
            self?.genericView.tableView.cancelHighlight()
        
            self?.readyOnce()
            
        }))
        
        
        request.set(.single(.Initial(100, nil)))
        
        
        self.genericView.tableView.setScrollHandler { position in
            let view = previousChatList.modify({$0})
        }
        
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
        
        if self.share.multipleSelection {
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
                        if info.flags.contains(.slowModeEnabled) && (peer.adminRights != nil || !peer.flags.contains(.isCreator)) {
                            if let cachedData = cachedData, let validUntil = cachedData.slowModeValidUntilTimestamp {
                                if validUntil > share.context.timestamp {
                                    failed.append(ShareFailedReason(peerId: peer.id, reason: slowModeTooltipText(validUntil - share.context.timestamp), target: .token))
                                }
                            }
                            if !comment.isEmpty {
                                failed.append(ShareFailedReason(peerId: peer.id, reason: L10n.slowModeForwardCommentError, target: .comment))
                            }
                            if unsentIds.contains(peer.id) {
                                failed.append(ShareFailedReason(peerId: peer.id, reason: L10n.slowModeMultipleError, target: .token))
                            }
                        }
                        
                    default:
                        break inner
                    }
                }
                if failed.isEmpty {
                    self.genericView.tokenizedView.removeAllFailed(animated: true)
                    _ = share.perform(to: Array(ids), comment: comment).start()
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
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.tableView.highlightedItem() != nil {
            genericView.tableView.cancelHighlight()
            return .invoked
        }
        if genericView.tokenizedView.state == .Focus {
            _ = window?.makeFirstResponder(nil)
            return .invoked
        }
        
        return .rejected
    }

    private let emoji: EmojiViewController
    
    init(_ share:ShareObject) {
        self.share = share
        emoji = EmojiViewController(share.context)
        super.init(frame: NSMakeRect(0, 0, 360, 400))
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
        
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
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
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        return 1024
    }
    
    private func updateSize(_ width: CGFloat, animated: Bool) {
        if let contentSize = self.window?.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(width, min(contentSize.height - 100, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: animated)
        }
    }
    
    override var modalInteractions: ModalInteractions? {
        if !share.hasCaptionView {
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
            _ = self.share.perform(to: []).start()
        }
        super.close(animationType: animationType)
    }
    
    deinit {
        disposable.dispose()
        tokenDisposable.dispose()
        exportLinkDisposable.dispose()
    }
    
}
