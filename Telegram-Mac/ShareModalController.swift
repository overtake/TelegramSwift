//
//  ShareModalController.swift
//  TelegramMac
//
//  Created by keepcoder on 20/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac



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
        set(background: theme.colors.blueFill, for: .Hover)
        set(background: theme.colors.blueFill, for: .Normal)
        set(background: theme.colors.blueFill, for: .Highlight)
        shareText.backgroundColor = theme.colors.blueFill
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
        badge = BadgeNode(.initialize(string: "\(max(count, 1))", color: theme.colors.blueFill, font: .medium(.small)), .white)
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
    let searchView:TokenizedView
    let tableView:TableView = TableView()
    fileprivate let share:ImageButton = ImageButton()
    fileprivate let dismiss:ImageButton = ImageButton()
    
    
    
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
    
    required init(frame frameRect: NSRect) {
        searchView = TokenizedView(frame: NSMakeRect(0, 0, 260, 30), localizationFunc: { key in
            return translate(key: key, [])
        }, placeholderKey: "ShareModal.Search.Placeholder")
        super.init(frame: frameRect)
        
        backgroundColor = theme.colors.background
        textContainerView.backgroundColor = theme.colors.background
        actionsContainerView.backgroundColor = theme.colors.background
        
        addSubview(searchView)
        addSubview(tableView)
        addSubview(topSeparator)
        searchView.delegate = self
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
    
    func tokenizedViewDidChangedHeight(_ view: TokenizedView, height: CGFloat, animated: Bool) {
        searchView._change(pos: NSMakePoint(50, 10), animated: animated)
        tableView.change(size: NSMakeSize(frame.width, frame.height - height - 20 - textView.frame.height - 16), animated: animated)
        tableView.change(pos: NSMakePoint(0, height + 20), animated: animated)
        topSeparator.change(pos: NSMakePoint(0, searchView.frame.maxY + 10), animated: animated)
    }
    
    func textViewUpdateHeight(_ height: CGFloat, _ animated: Bool) {
        CATransaction.begin()
        textContainerView.change(size: NSMakeSize(frame.width, height + 16), animated: animated)
        textContainerView.change(pos: NSMakePoint(0, frame.height - textContainerView.frame.height), animated: animated)
        textView._change(pos: NSMakePoint(10, height == 34 ? 8 : 11), animated: animated)
        tableView.change(size: NSMakeSize(frame.width, frame.height - searchView.frame.height - 20 - 50), animated: animated)

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
        searchView.setFrameSize(frame.width - 50 - (share.isHidden ? 10 : 50), searchView.frame.height)
        share.setFrameOrigin(frame.width - share.frame.width - 10, 10)
        dismiss.setFrameOrigin(10, 10)
        searchView.setFrameOrigin(50, 10)
        tableView.frame = NSMakeRect(0, searchView.frame.maxY + 10, frame.width, frame.height - searchView.frame.height - 20 - 50)
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
    
}


class ShareObject {
    let account:Account
    init(_ account:Account) {
        self.account = account
    }
    
    func perform(to entries:[PeerId], comment: String? = nil) {
        
    }
    
    var hasLink: Bool {
        return false
    }
    
    func shareLink() {
        
    }
    
    func possibilityPerformTo(_ peer:Peer) -> Bool {
        return peer.canSendMessage
    }
}

class ShareLinkObject : ShareObject {
    let link:String
    init(_ account:Account, link:String) {
        self.link = link
        super.init(account)
    }
    
    override var hasLink: Bool {
        return true
    }
    
    override func shareLink() {
        copyToClipboard(link)
    }
    
    override func perform(to peerIds:[PeerId], comment: String? = nil) {
        for peerId in peerIds {
            
            if let comment = comment?.trimmed, !comment.isEmpty {
                _ = Sender.enqueue(message: EnqueueMessage.message(text: comment, attributes: [], media: nil, replyToMessageId: nil, localGroupingKey: nil), account: account, peerId: peerId).start()
            }
            
            var attributes:[MessageAttribute] = []
            if FastSettings.isChannelMessagesMuted(peerId) {
                attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
            }
            _ = enqueueMessages(account: account, peerId: peerId, messages: [EnqueueMessage.message(text: link, attributes: attributes, media: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
        }
    }
}

class ShareContactObject : ShareObject {
    let user:TelegramUser
    init(_ account:Account, user:TelegramUser) {
        self.user = user
        super.init(account)
    }
    
    override func perform(to peerIds:[PeerId], comment: String? = nil) {
        for peerId in peerIds {
            _ = Sender.shareContact(account: account, peerId: peerId, contact: user).start()
        }
    }

}

class ShareMessageObject : ShareObject {
    fileprivate let messageIds:[MessageId]
    private let message:Message
    let link:String?
    private let exportLinkDisposable = MetaDisposable()
    
    init(_ account:Account, _ message:Message, _ groupMessages:[Message] = []) {
        self.messageIds = groupMessages.isEmpty ? [message.id] : groupMessages.map{$0.id}
        self.message = message
        let peer:TelegramChannel?
        if let author = message.forwardInfo?.author as? TelegramChannel {
            peer = author
        } else {
            peer = messageMainPeer(message) as? TelegramChannel
        }
        if let peer = peer, let address = peer.username {
            switch peer.info {
            case .broadcast:
                self.link = "https://t.me/" + address + "/" + "\(message.id.id)"
            default:
                self.link = nil
            }
        } else {
            self.link = nil
        }
        super.init(account)
    }
    
    override var hasLink: Bool {
        return link != nil
    }
    
    override func shareLink() {
        if let link = link {
           exportLinkDisposable.set(exportMessageLink(account: account, peerId: messageIds[0].peerId, messageId: messageIds[0]).start(next: { valueLink in
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

    override func perform(to peerIds:[PeerId], comment: String? = nil) {
        for peerId in peerIds {
            if let comment = comment?.trimmed, !comment.isEmpty {
                _ = Sender.enqueue(message: EnqueueMessage.message(text: comment, attributes: [], media: nil, replyToMessageId: nil, localGroupingKey: nil), account: account, peerId: peerId).start()
            }
            _ = Sender.forwardMessages(messageIds: messageIds, account: account, peerId: peerId).start()
        }
    }
    
    override func possibilityPerformTo(_ peer:Peer) -> Bool {
        return message.possibilityForwardTo(peer)
    }
}

enum SelectablePeersEntryStableId : Hashable {
    case plain(PeerId)
    case emptySearch
    case separator(ChatListIndex)
    var hashValue: Int {
        switch self {
        case let .plain(peerId):
            return peerId.hashValue
        case .separator(let index):
            return index.hashValue
        case .emptySearch:
            return 0
        }
    }
    
    static func ==(lhs:SelectablePeersEntryStableId, rhs:SelectablePeersEntryStableId) -> Bool {
        switch lhs {
        case let .plain(peerId):
            if case .plain(peerId) = rhs {
                return true
            } else {
                return false
            }
        case let .separator(index):
            if case .separator(index) = rhs {
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
}

enum SelectablePeersEntry : Comparable, Identifiable {
    case plain(Peer, ChatListIndex, PeerStatusStringResult?, Bool)
    case separator(String, ChatListIndex)
    case emptySearch
    var stableId: SelectablePeersEntryStableId {
        switch self {
        case let .plain(peer,_, _, _):
            return .plain(peer.id)
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



fileprivate func prepareEntries(from:[SelectablePeersEntry]?, to:[SelectablePeersEntry], account:Account, initialSize:NSSize, animated:Bool, selectInteraction:SelectPeerInteraction) -> TableUpdateTransition {
  
    let (deleted,inserted,updated) = proccessEntries(from, right: to, { entry -> TableRowItem in
        
        switch entry {
        case let .plain(peer, _, presence, drawSeparator):
            //
            let color = presence?.status.attribute(NSAttributedStringKey.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
            return  ShortPeerRowItem(initialSize, peer: peer, account:account, stableId: entry.stableId, height: 48, photoSize:NSMakeSize(36, 36), statusStyle: ControlStyle(font: .normal(.text), foregroundColor: color ?? theme.colors.grayText, highlightColor:.white), status: peer.id == account.peerId ? nil : presence?.status.string, drawCustomSeparator: drawSeparator, isLookSavedMessage : peer.id == account.peerId, inset:NSEdgeInsets(left: 10, right: 10), interactionType:.selectable(selectInteraction))
        case let .separator(text, _):
            return SeparatorRowItem(initialSize, entry.stableId, string: text)
        case .emptySearch:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId)
        }
        
        
    })
    
    
    return TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated: animated, state: animated ? .none(nil) : .saveVisible(.lower), grouping: !animated, animateVisibleOnly: false)
    
}



class ShareModalController: ModalViewController, Notifable, TGModernGrowingDelegate {
    private let share:ShareObject
    private let selectInteractions:SelectPeerInteraction = SelectPeerInteraction()
    private let search:Promise<String> = Promise()
    private let inSearchSelected:Atomic<[PeerId]> = Atomic(value:[])
    private let disposable:MetaDisposable = MetaDisposable()
    private let exportLinkDisposable:MetaDisposable = MetaDisposable()
    private let tokenDisposable: MetaDisposable = MetaDisposable()
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
            
            let added = value.selected.subtracting(oldValue.selected)
            let removed = oldValue.selected.subtracting(value.selected)

            for item in added {
                let title = item == share.account.peerId ? tr(L10n.peerSavedMessages) : value.peers[item]?.compactDisplayTitle ?? tr(L10n.peerDeletedUser)
                genericView.searchView.addToken(token: SearchToken(name: title, uniqueId: item.toInt64()), animated: animated)
            }
            
            for item in removed {
                genericView.searchView.removeToken(uniqueId: item.toInt64(), animated: animated)
            }
            
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
    
    override var modal: Modal? {
        didSet {
            modal?.interactions?.updateEnables(false)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let interactions = EntertainmentInteractions(.emoji, peerId: PeerId(0))
        interactions.sendEmoji = { [weak self] emoji in
            self?.genericView.textView.appendText(emoji)
            self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        }
        emoji.update(with: interactions)
        
        genericView.emojiButton.set(handler: { [weak self] control in
            self?.showEmoji(for: control)
        }, for: .Hover)

        
        genericView.textView.delegate = self
        genericView.hasShareMenu = self.share.hasLink
        search.set(genericView.searchView.textUpdater)
        
        genericView.dismiss.set(handler: { [weak self] _ in
            self?.close()
        }, for: .Click)
        
        
        
        let initialSize = self.atomicSize.modify({$0})
        let request = Promise<ChatListIndexRequest>()
        let account = self.share.account
        let selectInteraction = self.selectInteractions
        let share = self.share
        selectInteraction.add(observer: self)
        let previous:Atomic<[SelectablePeersEntry]?> = Atomic(value: nil)
        
        
        genericView.share.set(handler: { [weak self] control in
            showPopover(for: control, with: SPopoverViewController(items: [SPopoverItem(tr(L10n.modalCopyLink), {
                if share.hasLink {
                    share.shareLink()
                    self?.show(toaster: ControllerToaster(text: tr(L10n.shareLinkCopied), height:50), for: 2.0, animated: true)
                }
            })]), edge: .maxY, inset: NSMakePoint(-100,  -40))
        }, for: .Click)
        
        
        genericView.sendButton.set(handler: { [weak self] _ in
            if let strongSelf = self, !selectInteraction.presentation.selected.isEmpty {
                _ = strongSelf.returnKeyAction()
            }
        }, for: .SingleClick)
        

        
        tokenDisposable.set(genericView.searchView.tokensUpdater.start(next: { tokens in
            let ids = Set(tokens.map({PeerId($0.uniqueId)}))
            let unselected = selectInteraction.presentation.selected.symmetricDifference(ids)
            
            selectInteraction.update( { unselected.reduce($0, { current, value in
                return current.deselect(peerId: value)
            })})

        }))
        
        let list:Signal<TableUpdateTransition, Void> = combineLatest(request.get() |> distinctUntilChanged |> deliverOnPrepareQueue, search.get() |> distinctUntilChanged |> deliverOnPrepareQueue, genericView.searchView.stateValue.get() |> deliverOnPrepareQueue) |> mapToSignal { location, search, state -> Signal<TableUpdateTransition, Void> in
            
            if state == .Focus, search.isEmpty {
                return combineLatest(account.postbox.loadedPeerWithId(account.peerId), recentPeers(account: account) |> deliverOnPrepareQueue, recentlySearchedPeers(postbox: account.postbox) |> deliverOnPrepareQueue) |> map { user, top, recent -> TableUpdateTransition in
                    
                    var entries:[SelectablePeersEntry] = []
                    
                    var contains:[PeerId:PeerId] = [:]
                
                    var indexId:Int32 = Int32.max
                    
                    let chatListIndex:()-> ChatListIndex = {
                        let index = MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 1, id: indexId), timestamp: indexId)
                        indexId -= 1
                        return ChatListIndex(pinningIndex: nil, messageIndex: index)
                    }
                    
                    var topPeers:[Peer] = []
                    
                    switch top {
                    case let .peers(_top):
                        topPeers = _top
                    default:
                        break
                    }
                    
                    entries.append(.plain(user, chatListIndex(), nil, topPeers.isEmpty && recent.isEmpty))
                    contains[user.id] = user.id
                    
                    if !topPeers.isEmpty {
                        entries.insert(.separator(tr(L10n.searchSeparatorPopular).uppercased(), chatListIndex()), at: 0)
                        
                        var count: Int32 = 0
                        for peer in topPeers {
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
                        
                        entries.insert(.separator(tr(L10n.searchSeparatorRecent).uppercased(), chatListIndex()), at: 0)

                        for rendered in recent {
                            if let peer = rendered.chatMainPeer {
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
                    
                    return prepareEntries(from: previous.swap(entries), to: entries, account: account, initialSize: initialSize, animated: true, selectInteraction:selectInteraction)

                }
            } else if state == .None {
                
                
                var signal:Signal<(ChatListView,ViewUpdateType),Void>
                
                switch(location) {
                case let .Initial(count, _):
                    signal = account.viewTracker.tailChatListView(groupId: nil, count: count)
                case let .Index(index, _):
                    signal = account.viewTracker.aroundChatListView(groupId: nil, index: index, count: 30)
                }
                
                return signal |> deliverOnPrepareQueue |> mapToSignal { value -> Signal<(ChatListView,ViewUpdateType, [PeerId: PeerStatusStringResult]), Void> in
                    var peerIds:[PeerId] = []
                    for entry in value.0.entries {
                        switch entry {
                        case let .MessageEntry(_, _, _, _, _, renderedPeer, _):
                            peerIds.append(renderedPeer.peerId)
                        default:
                            break
                        }
                    }
                    let keys = peerIds.map {PostboxViewKey.peer(peerId: $0)}
                    return account.postbox.combinedView(keys: keys) |> map { values -> (ChatListView,ViewUpdateType, [PeerId: PeerStatusStringResult]) in
                        
                        var presences:[PeerId: PeerStatusStringResult] = [:]
                        for value in values.views {
                            if let view = value.value as? PeerView {
                                presences[view.peerId] = stringStatus(for: view)
                            }
                        }
                        
                        return (value.0, value.1, presences)
                        
                    } |> take(1)
                } |> deliverOn(prepareQueue) |> take(1) |> map { value -> TableUpdateTransition in
                    var entries:[SelectablePeersEntry] = []
                    
                    var contains:[PeerId:PeerId] = [:]
                    contains[account.peerId] = account.peerId
                    for entry in value.0.entries {
                        switch entry {
                        case let .MessageEntry(id, _, _, _, _, renderedPeer, _):
                            if let peer = renderedPeer.chatMainPeer {
                                if contains[peer.id] == nil {
                                    if share.possibilityPerformTo(peer) {
                                        entries.append(.plain(peer,id, value.2[peer.id], true))
                                        contains[peer.id] = peer.id
                                    }
                                }
                            }
                        default:
                            break
                        }
                    }
                    
                    entries.sort(by: <)
                    
                    return prepareEntries(from: previous.swap(entries), to: entries, account: account, initialSize: initialSize, animated: true, selectInteraction:selectInteraction)
                }
            } else {
                return account.postbox.searchPeers(query: search.lowercased(), groupId: nil) |> map {
                    return $0.compactMap({$0.chatMainPeer}).filter({!($0 is TelegramSecretChat)})
                } |> mapToSignal { peers -> Signal<([Peer], [PeerId: PeerStatusStringResult]), Void> in
                    let keys = peers.map {PostboxViewKey.peer(peerId: $0.id)}
                    return account.postbox.combinedView(keys: keys) |> map { values -> ([Peer], [PeerId: PeerStatusStringResult]) in
                        
                        var presences:[PeerId: PeerStatusStringResult] = [:]
                        for value in values.views {
                            if let view = value.value as? PeerView {
                                presences[view.peerId] = stringStatus(for: view)
                            }
                        }
                        
                        return (peers, presences)
                        
                    } |> take(1)
                } |> deliverOn(prepareQueue) |> take(1) |> map { values -> TableUpdateTransition in
                        var entries:[SelectablePeersEntry] = []
                        var contains:[PeerId:PeerId] = [:]
                        var i:Int32 = Int32.max
                        for peer in values.0 {
                            if share.possibilityPerformTo(peer), contains[peer.id] == nil {
                                let index = MessageIndex(id: MessageId(peerId: PeerId(0), namespace: Namespaces.Message.Cloud, id: i), timestamp: i)
                                entries.append(.plain(peer, ChatListIndex(pinningIndex: nil, messageIndex: index), values.1[peer.id], true))
                                i -= 1
                                contains[peer.id] = peer.id
                            }
                        }
                        if entries.isEmpty {
                            entries.append(.emptySearch)
                        }
                    
                        entries.sort(by: <)
                    
                        return prepareEntries(from: previous.swap(entries), to: entries, account: account, initialSize: initialSize, animated: true, selectInteraction:selectInteraction)
                }
            }
        } |> deliverOnMainQueue
        
        disposable.set(list.start(next: { [weak self] transition in
            self?.genericView.tableView.resetScrollNotifies()
            self?.genericView.tableView.merge(with:transition)
            self?.readyOnce()
        }))
        
        
        request.set(.single(.Initial(100, nil)))
        
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
    
    
    override func firstResponder() -> NSResponder? {
        if window?.firstResponder == genericView.textView.inputView {
            return genericView.textView.inputView
        }
       return genericView.searchView.responder
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if !genericView.searchView.query.isEmpty {
            if genericView.tableView.count == 1, let item = genericView.tableView.item(at: 0) as? ShortPeerRowItem {
                selectInteractions.update({$0.withToggledSelected(item.peer.id, peer: item.peer)})
            }
            return .invoked
        }
        if !selectInteractions.presentation.peers.isEmpty {
            share.perform(to: selectInteractions.presentation.peers.map {$0.key}, comment: genericView.textView.string())
            emoji.popover?.hide()
            modal?.close(true)
            return .invoked
        }
        return .rejected
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        
        if genericView.searchView.state == .Focus {
            window?.makeFirstResponder(nil)
            return .invoked
        }
        
        return .rejected
    }

    private let emoji: EmojiViewController
    
    init(_ share:ShareObject) {
        self.share = share
        emoji = EmojiViewController(share.account)
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
        return 200
    }
    
    private func updateSize(_ width: CGFloat, animated: Bool) {
        if let contentSize = self.window?.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(width, min(contentSize.height - 70, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: animated)
        }
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: false)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    deinit {
        disposable.dispose()
        tokenDisposable.dispose()
        exportLinkDisposable.dispose()
    }
    
}
