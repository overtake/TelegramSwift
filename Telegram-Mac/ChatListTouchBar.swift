//
//  ChatListTouchBar.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

@available(OSX 10.12.2, *)
private extension NSTouchBarItem.Identifier {
    static let chatListSearch = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chatListSearch")
    static let chatListNewChat = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chatListNewChat")
    static let chatListRecent = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chatListRecent")
    
    static let composeNewGroup = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.composeNewGroup")
    static let composeNewChannel = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.composeNewChannel")
    static let composeNewSecretChat = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.composeNewSecretChat")

}


@available(OSX 10.12.2, *)
private class TouchBarRecentPeerItemView: NSScrubberItemView {
    private let selectView = View()
    private var imageView: AvatarControl = AvatarControl.init(font: .avatar(12))
    private let fetchDisposable = MetaDisposable()
    
    private var badgeNode: BadgeNode?
    private var badgeView:View?

    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(selectView)
        addSubview(imageView)
        imageView.setFrameSize(NSMakeSize(30, 30))
        selectView.setFrameSize(NSMakeSize(30, 30))
        
        selectView.layer?.cornerRadius = 15
        selectView.layer?.borderColor = theme.colors.accent.cgColor
        selectView.layer?.borderWidth = 1.5
        selectView.layer?.opacity = 0
        
        selectView.isEventLess = true
    }
    
    private(set) var peerId: PeerId?
    
    func update(context: AccountContext, peer: TouchBarPeerItem, selected: Bool) {
        
        self.peerId = peer.peer.id
        
        if peer.unreadCount > 0 {
            if badgeView == nil {
                badgeView = View()
                self.addSubview(badgeView!)
            }
            guard let badgeView = self.badgeView else {
                return
            }
            badgeView.removeAllSubviews()
            
            if peer.muted {
                self.badgeNode = BadgeNode(.initialize(string: "\(peer.unreadCount)", color: theme.chatList.badgeTextColor, font: .medium(8)), theme.colors.grayText)
            } else {
                self.badgeNode = BadgeNode(.initialize(string: "\(peer.unreadCount)", color: theme.chatList.badgeTextColor, font: .medium(8)), theme.colors.accent)
            }
            guard let badgeNode = self.badgeNode else {
                return
            }
            
            badgeNode.additionSize = NSMakeSize(0, 0)
            
            
            
            badgeView.setFrameSize(badgeNode.size)
            badgeNode.view = badgeView
            badgeNode.setNeedDisplay()
            needsLayout = true
        } else {
            self.badgeView?.removeFromSuperview()
            self.badgeView = nil
        }
        
        imageView.setPeer(account: context.account, peer: peer.peer)
    }
    private var _selected: Bool = false
    func updateSelected(_ selected: Bool) {
        if self._selected != selected {
            self._selected = selected
            selectView.change(opacity: selected ? 1 : 0, animated: true, duration: 0.1, timingFunction: .spring)
            if selected {
                selectView.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.2, removeOnCompletion: true)
                imageView.layer?.animateScaleSpring(from: 1, to: 0.75, duration: 0.2, removeOnCompletion: false)
                badgeView?.layer?.animateScaleSpring(from: 1, to: 0.75, duration: 0.2, removeOnCompletion: false)
            } else {
                selectView.layer?.animateScaleSpring(from: 1.0, to: 0.2, duration: 0.2, removeOnCompletion: false)
                imageView.layer?.animateScaleSpring(from: 0.75, to: 1.0, duration: 0.2, removeOnCompletion: true)
                badgeView?.layer?.animateScaleSpring(from: 0.75, to: 1.0, duration: 0.2, removeOnCompletion: true)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
    }
    
    deinit {
        fetchDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
        selectView.center()
        imageView.center()
        
        guard let badgeView = self.badgeView else {
            return
        }
        badgeView.setFrameOrigin(NSMakePoint(frame.width - badgeView.frame.width, badgeView.frame.height - 11))

    }
}


@available(OSX 10.12.2, *)
private class RecentPeersScrubberBarItem: NSCustomTouchBarItem, NSScrubberDelegate, NSScrubberDataSource, NSScrubberFlowLayoutDelegate {
    
    private static let peerIdentifier = "peerIdentifier"
    
    var entries: [TouchBarPeerItem]
    private let context: AccountContext
    private let selected: ChatLocation?
    init(identifier: NSTouchBarItem.Identifier, context: AccountContext, entries: [TouchBarPeerItem], selected: ChatLocation?) {
        self.entries = entries
        self.context = context
        self.selected = selected
        super.init(identifier: identifier)
        
        let scrubber = NSScrubber()
        scrubber.register(TouchBarRecentPeerItemView.self, forItemIdentifier: NSUserInterfaceItemIdentifier(rawValue: RecentPeersScrubberBarItem.peerIdentifier))
        
        scrubber.mode = .free
        scrubber.selectionBackgroundStyle = .none
        scrubber.floatsSelectionViews = true
        scrubber.delegate = self
        scrubber.dataSource = self
        
        
        let gesture = NSPressGestureRecognizer(target: self, action: #selector(self.pressGesture(_:)))
        gesture.allowedTouchTypes = NSTouch.TouchTypeMask.direct
        gesture.allowableMovement = 0
        gesture.minimumPressDuration = 0
        scrubber.addGestureRecognizer(gesture)
        
        self.view = scrubber
    }
    
    @objc private func pressGesture(_ gesture: NSPressGestureRecognizer) {
        
        let context = self.context
        
        let runSelector:(Bool, Bool)->Void = { [weak self] cancelled, navigate in
            guard let `self` = self else {
                return
            }
            let scrollView = HackUtils.findElements(byClass: "NSScrollView", in: self.view)?.first as? NSScrollView
            
            guard let container = scrollView?.documentView?.subviews.first else {
                return
            }
            var point = gesture.location(in: container)
            point.y = 0
            for itemView in container.subviews {
                if let itemView = itemView as? TouchBarRecentPeerItemView {
                    if NSPointInRect(point, itemView.frame) {
                        itemView.updateSelected(!cancelled)
                        if navigate, let peerId = itemView.peerId {
                            context.sharedContext.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(peerId)))
                        }
                    } else {
                        itemView.updateSelected(false)
                    }
                }
            }
        }
        
        switch gesture.state {
        case .began:
            runSelector(false, false)
        case .failed, .cancelled:
            runSelector(true, false)
        case .ended:
            runSelector(true, true)
        case .changed:
            runSelector(false, false)
        case .possible:
            break
        @unknown default:
            runSelector(false, false)
        }
    }
    fileprivate var modalPreview: PreviewModalController?

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    func numberOfItems(for scrubber: NSScrubber) -> Int {
        return entries.count
    }
    
    func scrubber(_ scrubber: NSScrubber, didHighlightItemAt highlightedIndex: Int) {
        scrubber.selectionBackgroundStyle = .none
    }
    
    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        let itemView: NSScrubberItemView
        
        let peer = self.entries[index]
        
        let view = scrubber.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: RecentPeersScrubberBarItem.peerIdentifier), owner: nil) as! TouchBarRecentPeerItemView
        view.update(context: context, peer: peer, selected: self.selected?.peerId == peer.peer.id)
        itemView = view
        
        return itemView
    }
    
    func scrubber(_ scrubber: NSScrubber, layout: NSScrubberFlowLayout, sizeForItemAt itemIndex: Int) -> NSSize {
        return NSSize(width: 40, height: 40)
    }
    
    
    func scrubber(_ scrubber: NSScrubber, didSelectItemAt index: Int) {
       
    }
}



@available(OSX 10.12.2, *)
final class ComposePopoverTouchBar : NSTouchBar, NSTouchBarDelegate {
    
    private let newGroup:()->Void
    private let newSecretChat:()->Void
    private let newChannel:()->Void
    init(newGroup:@escaping()->Void, newSecretChat:@escaping()->Void, newChannel:@escaping()->Void) {
        self.newGroup = newGroup
        self.newSecretChat = newSecretChat
        self.newChannel = newChannel
        super.init()
        
        delegate = self
        defaultItemIdentifiers = [.flexibleSpace, .composeNewGroup, .composeNewSecretChat, .composeNewChannel, .flexibleSpace]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func newGroupAction() {
        newGroup()
    }
    @objc private func newSecretChatAction() {
        newSecretChat()
    }
    @objc private func newChannelAction() {
        newChannel()
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .composeNewGroup:
            let item: NSCustomTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
            let image = NSImage(named: NSImage.Name("Icon_TouchBar_ComposeGroup"))!
            let button = NSButton(title: L10n.composePopoverNewGroup, image: image, target: self, action: #selector(newGroupAction))
            item.view = button
            item.customizationLabel = L10n.composePopoverNewGroup
            return item
        case .composeNewChannel:
            let item: NSCustomTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
            let image = NSImage(named: NSImage.Name("Icon_TouchBar_ComposeChannel"))!
            let button = NSButton(title: L10n.composePopoverNewChannel, image: image, target: self, action: #selector(newChannelAction))
            item.view = button
            item.customizationLabel = L10n.composePopoverNewChannel
            return item
        case .composeNewSecretChat:
            let item: NSCustomTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
            let image = NSImage(named: NSImage.Name("Icon_TouchBar_ComposeSecretChat"))!
            let button = NSButton(title: L10n.composePopoverNewSecretChat, image: image, target: self, action: #selector(newSecretChatAction))
            item.view = button
            item.customizationLabel = L10n.composePopoverNewSecretChat
            return item
        default:
            break
        }
        return nil
    }
}

private struct TouchBarPeerItem : Equatable {
    let peer: Peer
    let unreadCount: Int32
    let muted: Bool
    static func ==(lhs: TouchBarPeerItem, rhs: TouchBarPeerItem) -> Bool {
        return lhs.peer.id == rhs.peer.id
    }
}

@available(OSX 10.12.2, *)
class ChatListTouchBar: NSTouchBar, NSTouchBarDelegate {

    private let search:()->Void
    private let newGroup:()->Void
    private let newSecretChat:()->Void
    private let newChannel:()->Void
    private let context: AccountContext
    private var peers:[TouchBarPeerItem] = []
    private var selected: ChatLocation?
    private let disposable = MetaDisposable()
    init(context: AccountContext, search:@escaping()->Void, newGroup:@escaping()->Void, newSecretChat:@escaping()->Void, newChannel:@escaping()->Void) {
        self.search = search
        self.newGroup = newGroup
        self.newSecretChat = newSecretChat
        self.newChannel = newChannel
        self.context = context
        super.init()
        delegate = self
        customizationIdentifier = .windowBar
        defaultItemIdentifiers = [.chatListNewChat, .flexibleSpace, .chatListSearch, .flexibleSpace]
        customizationAllowedItemIdentifiers = defaultItemIdentifiers
        
        
//        let recent:Signal<[TouchBarPeerItem], NoError> = recentlySearchedPeers(postbox: context.account.postbox) |> map { recent in
//            return recent.prefix(10).compactMap { $0.peer.peer != nil ? TouchBarPeerItem(peer: $0.peer.peer!, unreadCount: $0.unreadCount, muted: $0.notificationSettings?.isMuted ?? false) : nil }
//        }
//        let top:Signal<[TouchBarPeerItem], NoError> = recentPeers(account: context.account) |> mapToSignal { top in
//            switch top {
//            case .disabled:
//                return .single([])
//            case let .peers(peers):
//                let peers = Array(peers.prefix(7))
//                return combineLatest(peers.map {context.account.viewTracker.peerView($0.id)}) |> mapToSignal { peerViews -> Signal<[TouchBarPeerItem], NoError> in
//                    return context.account.postbox.unreadMessageCountsView(items: peerViews.map {.peer($0.peerId)}) |> map { values in
//                        var peers:[TouchBarPeerItem] = []
//                        for peerView in peerViews {
//                            if let peer = peerViewMainPeer(peerView) {
//                                let isMuted = peerView.isMuted
//                                let unreadCount = values.count(for: .peer(peerView.peerId))
//                                peers.append(TouchBarPeerItem(peer: peer, unreadCount: unreadCount ?? 0, muted: isMuted))
//                            }
//                        }
//                        return peers
//                    }
//                }
//            }
//        }
//

//        let signal = combineLatest(queue: .mainQueue(), recent, top)
//        disposable.set(signal.start(next: { [weak self] recent, top in
//            self?.peers = (top + recent).prefix(14).uniqueElements
//            self?.updateInterface()
//        }))
    }
    
    private func identifiers() -> [NSTouchBarItem.Identifier] {
        var items:[NSTouchBarItem.Identifier] = []
        
        items.append(.chatListNewChat)
        if peers.isEmpty {
            items.append(.flexibleSpace)
            items.append(.chatListSearch)
            items.append(.flexibleSpace)
        } else {
            items.append(.fixedSpaceSmall)
            items.append(.chatListRecent)
            items.append(.fixedSpaceSmall)
        }
        return items
    }
    
    private func updateInterface() {
        defaultItemIdentifiers = identifiers()
        customizationAllowedItemIdentifiers = defaultItemIdentifiers
        
        for identifier in itemIdentifiers {
            switch identifier {
            case .chatListRecent:
                let view = (item(forIdentifier: identifier) as? RecentPeersScrubberBarItem)
                view?.entries = self.peers
                (view?.view as? NSScrubber)?.reloadData()
            default:
                break
            }
        }
        
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .chatListNewChat:
            let item = NSPopoverTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(named: NSImage.Name("Icon_TouchBar_Compose"))!, target: item, action: #selector(NSPopoverTouchBarItem.showPopover(_:)))
            
            item.popoverTouchBar = ComposePopoverTouchBar(newGroup: self.newGroup, newSecretChat: self.newSecretChat, newChannel: self.newChannel)
            item.collapsedRepresentation = button
            item.customizationLabel = L10n.touchBarLabelNewChat
            return item
        case .chatListSearch:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let image = NSImage(named: NSImage.Name("Icon_TouchBar_Search"))!
            let button = NSButton(title: L10n.touchBarSearchUsersOrMessages, image: image, target: self, action: #selector(searchAction))
            button.imagePosition = .imageLeft
            button.imageHugsTitle = true
            button.addWidthConstraint(relation: .equal, size: 350)
            item.view = button
            item.customizationLabel = button.title
            return item
        case .chatListRecent:
            let scrubberItem: NSCustomTouchBarItem = RecentPeersScrubberBarItem(identifier: identifier, context: context, entries: self.peers, selected: self.selected)
            return scrubberItem
        default:
            break
        }
        return nil
    }
    
    @objc private func composeAction() {
        
    }
    
    @objc private func searchAction() {
        self.search()
    }
}
