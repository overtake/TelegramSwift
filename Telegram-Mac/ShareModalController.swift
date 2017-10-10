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
        let layout = TextViewLayout(.initialize(string: tr(.modalShare).uppercased(), color: .white, font: .normal(.header)), maximumNumberOfLines: 1)
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
    private let separator = View()
    fileprivate let invokeButton = ShareButton(frame: NSZeroRect)
    private let shadowView: View = ShadowView()
    
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
        addSubview(searchView)
        addSubview(tableView)
        addSubview(separator)
        searchView.delegate = self
        separator.backgroundColor = theme.colors.border
        self.backgroundColor = theme.colors.background
        share.set(image: theme.icons.modalShare, for: .Normal)
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        
        share.sizeToFit()
        dismiss.sizeToFit()
        
        addSubview(share)
        addSubview(dismiss)
        
        shadowView.backgroundColor = theme.colors.background.withAlphaComponent(1.0)
        shadowView.setFrameSize(frame.width, 70)
        
        addSubview(shadowView)
        addSubview(invokeButton)

    }
    private var count:Int = 0
    
    func updateCount(_ count:Int, animated: Bool) -> Void {
        self.count = count
        invokeButton.updateCount(count)
        if count == 0 {
            invokeButton.change(pos: NSMakePoint(invokeButton.frame.minX, frame.height), animated: animated, timingFunction: kCAMediaTimingFunctionSpring)
            shadowView.change(pos: NSMakePoint(shadowView.frame.minX, frame.height), animated: animated, timingFunction: kCAMediaTimingFunctionSpring)
        } else {
            invokeButton.change(pos: NSMakePoint(invokeButton.frame.minX, frame.height - invokeButton.frame.height - 16), animated: animated, timingFunction: kCAMediaTimingFunctionSpring)
            shadowView.change(pos: NSMakePoint(shadowView.frame.minX, frame.height - shadowView.frame.height), animated: animated, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    func tokenizedViewDidChangedHeight(_ view: TokenizedView, height: CGFloat, animated: Bool) {
        searchView._change(pos: NSMakePoint(50, 10), animated: animated)
        tableView.change(size: NSMakeSize(frame.width, frame.height - height - 20), animated: animated)
        tableView.change(pos: NSMakePoint(0, height + 20), animated: animated)
        separator.change(pos: NSMakePoint(0, searchView.frame.maxY + 10), animated: animated)
    }
    
    
    fileprivate override func layout() {
        super.layout()
        searchView.setFrameSize(frame.width - 50 - (share.isHidden ? 10 : 50), searchView.frame.height)
        share.setFrameOrigin(frame.width - share.frame.width - 10, 10)
        dismiss.setFrameOrigin(10, 10)
        searchView.setFrameOrigin(50, 10)
        tableView.frame = NSMakeRect(0, searchView.frame.maxY + 10, frame.width, frame.height - searchView.frame.height - 20)
        separator.frame = NSMakeRect(0, searchView.frame.maxY + 10, frame.width, .borderSize)
        invokeButton.centerX(y: count == 0 ? frame.height : frame.height - invokeButton.frame.height - 16)
        shadowView.setFrameOrigin(0, count == 0 ? frame.height : frame.height - shadowView.frame.height)
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
    
    func perform(to entries:[PeerId]) {
        
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
    
    override func perform(to peerIds:[PeerId]) {
        for peerId in peerIds {
            var attributes:[MessageAttribute] = []
            if FastSettings.isChannelMessagesMuted(peerId) {
                attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
            }
            _ = enqueueMessages(account: account, peerId: peerId, messages: [EnqueueMessage.message(text: link, attributes: attributes, media: nil, replyToMessageId: nil)]).start()
        }
    }
}

class ShareContactObject : ShareObject {
    let user:TelegramUser
    init(_ account:Account, user:TelegramUser) {
        self.user = user
        super.init(account)
    }
    
    override func perform(to peerIds:[PeerId]) {
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
    
    init(_ account:Account, _ message:Message) {
        self.messageIds = [message.id]
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

    override func perform(to peerIds:[PeerId]) {
        for peerId in peerIds {
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
            let color = presence?.status.attribute(NSAttributedStringKey.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
            return  ShortPeerRowItem(initialSize, peer: peer, account:account, stableId: entry.stableId, height: 48, photoSize:NSMakeSize(36, 36), statusStyle: ControlStyle(font: .normal(.text), foregroundColor: color ?? theme.colors.grayText, highlightColor:.white), status: presence?.status.string, drawCustomSeparator: drawSeparator, inset:NSEdgeInsets(left: 10, right: 10), interactionType:.selectable(selectInteraction))
        case let .separator(text, _):
            return SeparatorRowItem(initialSize, entry.stableId, string: text)
        case .emptySearch:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId)
        }
        
        
    })
    
    
    return TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated: animated, state: animated ? .none(nil) : .saveVisible(.lower), grouping: !animated, animateVisibleOnly: false)
    
}



class ShareModalController: ModalViewController, Notifable {
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
                genericView.searchView.addToken(token: SearchToken(name: value.peers[item]?.compactDisplayTitle ?? tr(.peerDeletedUser), uniqueId: item.toInt64()), animated: animated)
            }
            
            for item in removed {
                genericView.searchView.removeToken(uniqueId: item.toInt64(), animated: animated)
            }
            genericView.updateCount(value.selected.count, animated: animated)
            
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
            showPopover(for: control, with: SPopoverViewController(items: [SPopoverItem(tr(.modalCopyLink), {
                if share.hasLink {
                    share.shareLink()
                    self?.show(toaster: ControllerToaster(text: tr(.shareLinkCopied), height:50), for: 2.0, animated: true)
                }
            })]), edge: .maxY, inset: NSMakePoint(-100,  -40))
        }, for: .Click)
        
        genericView.invokeButton.set(handler: { [weak self] _ in
            share.perform(to: selectInteraction.presentation.selected.map{$0})
            self?.close()
        }, for: .Click)
        
        tokenDisposable.set(genericView.searchView.tokensUpdater.start(next: { tokens in
            let ids = Set(tokens.map({PeerId($0.uniqueId)}))
            let unselected = selectInteraction.presentation.selected.symmetricDifference(ids)
            
            selectInteraction.update( { unselected.reduce($0, { current, value in
                return current.deselect(peerId: value)
            })})

        }))
        
        let list:Signal<TableUpdateTransition, Void> = combineLatest(request.get() |> distinctUntilChanged |> deliverOnPrepareQueue, search.get() |> distinctUntilChanged |> deliverOnPrepareQueue, genericView.searchView.stateValue.get() |> deliverOnPrepareQueue) |> mapToSignal { location, search, state -> Signal<TableUpdateTransition, Void> in
            
            if state == .None {
                return combineLatest(recentPeers(account: account) |> deliverOnPrepareQueue, recentlySearchedPeers(postbox: account.postbox) |> deliverOnPrepareQueue) |> map { top, recent -> TableUpdateTransition in
                    
                    var entries:[SelectablePeersEntry] = []
                    
                    var contains:[PeerId:PeerId] = [:]
                
                    var indexId:Int32 = Int32.max
                    
                    let chatListIndex:()-> ChatListIndex = {
                        let index = MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 1, id: indexId), timestamp: indexId)
                        indexId -= 1
                        return ChatListIndex(pinningIndex: nil, messageIndex: index)
                    }
                    
                    if !top.isEmpty {
                        entries.insert(.separator(tr(.searchSeparatorPopular).uppercased(), chatListIndex()), at: 0)
                        
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
                        
                        entries.insert(.separator(tr(.searchSeparatorRecent).uppercased(), chatListIndex()), at: 0)

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
            } else if search.isEmpty {
                
                
                var signal:Signal<(ChatListView,ViewUpdateType),Void>
                
                switch(location) {
                case let .Initial(count, _):
                    signal = account.viewTracker.tailChatListView(count: count)
                case let .Index(index):
                    signal = account.viewTracker.aroundChatListView(index: index, count: 30)
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
                return account.postbox.searchPeers(query: search.lowercased()) |> map {
                    return $0.flatMap({$0.chatMainPeer}).filter({!($0 is TelegramSecretChat)})
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
       return genericView.searchView.responder
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if !selectInteractions.presentation.peers.isEmpty {
            share.perform(to: selectInteractions.presentation.peers.map {$0.key})
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

    
    init(_ share:ShareObject) {
        self.share = share
        super.init(frame: NSMakeRect(0, 0, 360, 400))
        bar = .init(height: 0)
    }
//    override var modalInteractions: ModalInteractions? {
//        if let share = share as? ShareMessageObject {
//            if let link = share.link {
//                return ModalInteractions(acceptTitle:tr(.modalShare), accept:{ [weak self] in
//                    if let interactions = self?.selectInteractions, let share = self?.share {
//                        share.perform(to: interactions.presentation.selected.map({$0}))
//                    }
//                    self?.modal?.close()
//                }, cancelTitle:tr(.modalCopyLink), cancel: { [weak self] in
//                    if let strongSelf = self, let share = strongSelf.share as? ShareMessageObject {
//                        
//                        self?.exportLinkDisposable.set(exportMessageLink(account: strongSelf.share.account, peerId: share.messageIds[0].peerId, messageId: share.messageIds[0]).start(next: { valueLink in
//                            if let valueLink = valueLink {
//                                copyToClipboard(valueLink)
//                            } else {
//                                copyToClipboard(link)
//                            }
//                        }))
//                    }
//                    
//                        self?.show(toaster: ControllerToaster(text: tr(.shareLinkCopied), height:50), for: 2.0, animated: true)
//                }, drawBorder:true, height:40)
//            } else {
//                return ModalInteractions(acceptTitle:tr(.modalShare), accept:{ [weak self] in
//                    if let interactions = self?.selectInteractions, let share = self?.share {
//                        share.perform(to: interactions.presentation.selected.map({$0}))
//                    }
//                    self?.modal?.close()
//                }, cancelTitle: tr(.modalCancel), drawBorder:true, height:40)
//            }
//            
//        } else if let share = share as? ShareLinkObject {
//            return ModalInteractions(acceptTitle: tr(.modalShare), accept:{ [weak self] in
//                if let interactions = self?.selectInteractions, let share = self?.share {
//                    share.perform(to: interactions.presentation.selected.map({$0}))
//                }
//                self?.modal?.close()
//            }, cancelTitle: tr(.modalCopyLink), cancel: { [weak self] in
//                copyToClipboard(share.link)
//                self?.show(toaster: ControllerToaster(text: tr(.shareLinkCopied), height:50), for: 2.0, animated: true)
//            }, drawBorder:true, height:40)
//
//        } else if let _ = share as? ShareContactObject {
//            return ModalInteractions(acceptTitle: tr(.modalShare), accept:{ [weak self] in
//                if let interactions = self?.selectInteractions, let share = self?.share {
//                    share.perform(to: interactions.presentation.selected.map({$0}))
//                }
//                self?.modal?.close()
//            }, drawBorder:true, height:40)
//        }
//        return nil
//    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    deinit {
        disposable.dispose()
        tokenDisposable.dispose()
        exportLinkDisposable.dispose()
    }
    
}
