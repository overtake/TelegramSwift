//
//  PopularPeersRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import SwiftSignalKitMac
import TelegramCoreMac

enum PopularItemType : Hashable {
    
    
    var hashValue: Int {
        return 0
    }
    
    static func == (lhs: PopularItemType, rhs: PopularItemType) -> Bool {
        switch lhs {
        case .savedMessages:
            if case .savedMessages = rhs {
                return true
            } else {
                return false
            }
        case let .articles(unreadCount):
            if case .articles(unreadCount) = rhs {
                return true
            } else {
                return false
            }
        case let .peer(lhsPeer, lhsBadge, lhsActive):
            if case let .peer(rhsPeer, rhsBadge, rhsActive) = rhs {
                return lhsPeer.isEqual(rhsPeer) && lhsBadge == rhsBadge && lhsActive == rhsActive
            } else {
                return false
            }
        }
    }
    
    case savedMessages(Peer)
    case articles(Int32)
    case peer(Peer, UnreadSearchBadge?, Bool)
    
    
    
}

private final class PopularPeerItem : TableRowItem {
    fileprivate let type: PopularItemType
    fileprivate let account: Account
    fileprivate let actionHandler: (PopularItemType)->Void
    init(type: PopularItemType, account: Account, action: @escaping(PopularItemType)->Void) {
        self.type = type
        self.account = account
        self.actionHandler = action
        super.init(NSZeroSize)
    }
    
    override var height: CGFloat {
        return 66
    }
    
    override var width: CGFloat {
        return 74
    }
    
    override var stableId: AnyHashable {
        return type
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items:[ContextMenuItem] = []
        switch type {
        case let .peer(peer, _, _):
            items.append(ContextMenuItem(L10n.searchPopularDelete, handler: { [weak self] in
                guard let `self` = self else {return}
               // self.table?.remove(at: self.index, redraw: true, animation: .effectFade)
                _ = removeRecentPeer(account: self.account, peerId: peer.id).start()
  
            }))
        default:
            break
        }
        
        
        return .single(items)
    }
    
    override func viewClass() -> AnyClass {
        return PopularPeerItemView.self
    }
}


private final class PopularPeerItemView : HorizontalRowView {
    private let imageView: AvatarControl = AvatarControl(font: .avatar(18))
    private let textView: TextView = TextView()
    private let badgeView: View = View()
    private let activeImage: ImageView = ImageView()
    private var badgeNode: BadgeNode?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.setFrameSize(45, 45)
        addSubview(imageView)
        addSubview(textView)
        addSubview(activeImage)
        activeImage.isEventLess = true
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        badgeView.userInteractionEnabled = false
        badgeView.isEventLess = true
        imageView.set(handler: { [weak self] _ in
            guard let item = self?.item as? PopularPeerItem else {return}
            item.actionHandler(item.type)
        }, for: .Click)
        
        
    }
//    
//    override var backdorColor: NSColor {
//        return .random
//    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PopularPeerItem else {return}
        badgeView.removeFromSuperview()
        activeImage.isHidden = true
        badgeNode = nil
        let text: String
        switch item.type {
        case .savedMessages:
            let icon = theme.icons.searchSaved
            imageView.setSignal(generateEmptyPhoto(imageView.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(imageView.frame.size.width - 20, imageView.frame.size.height - 20)), cornerRadius: nil)) |> map {($0, false)})
            text = L10n.searchPopularSavedMessages
        case let .articles(unreadCount):
            let icon = theme.icons.searchArticle
            imageView.setSignal(generateEmptyPhoto(imageView.frame.size, type: .icon(colors: theme.colors.peerColors(4), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(imageView.frame.size.width - 20, imageView.frame.size.height - 20)), cornerRadius: nil)) |> map {($0, false)})
            text = L10n.searchPopularArticles
            if unreadCount > 0 {
                let node = BadgeNode(NSAttributedString.initialize(string: "\(unreadCount)", color: .white, font: .medium(11)), theme.chatList.badgeBackgroundColor)
                node.view = badgeView
                self.badgeNode = node
                badgeView.setFrameSize(node.size)
                addSubview(badgeView)
            } else {
                badgeView.removeFromSuperview()
            }
        case let .peer(peer, unreadBadge, isActive):
            imageView.setPeer(account: item.account, peer: peer)
            text = peer.compactDisplayTitle
            
            activeImage.isHidden = !isActive
            activeImage.image = theme.icons.hintPeerActive
            activeImage.sizeToFit()
            
            if let unreadBadge = unreadBadge {
                let isMuted: Bool
                let count: Int32?
                switch unreadBadge {
                case let .muted(c):
                    isMuted = true
                    count = c
                case let .unmuted(c):
                    isMuted = false
                    count = c
                case .none:
                    isMuted = true
                    count = nil
                }
                if let unreadCount = count {
                    let node = BadgeNode(.initialize(string: "\(unreadCount)", color: .white, font: .medium(11)), isMuted ? theme.chatList.badgeMutedBackgroundColor : theme.chatList.badgeBackgroundColor)
                    node.view = badgeView
                    self.badgeNode = node
                    badgeView.setFrameSize(node.size)
                    addSubview(badgeView)
                } else {
                    badgeView.removeFromSuperview()
                }
            } else {
                 badgeView.removeFromSuperview()
            }
        }
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: .normal(11)), maximumNumberOfLines: 1)
        layout.measure(width: frame.width - 10)
        textView.update(layout)
        
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        imageView.centerX(addition: -4)
        textView.centerX(y: imageView.frame.maxY + 5, addition: -4)
        badgeView.setFrameOrigin(imageView.frame.maxX - badgeView.frame.width / 2, 0)
        activeImage.setFrameOrigin(imageView.frame.maxX - activeImage.frame.width - 1, imageView.frame.maxY - 12)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PopularPeersRowItem: GeneralRowItem {

    let peers: [Peer]
    fileprivate let account: Account
    fileprivate let unreadArticles: Int32
    fileprivate let selfPeer: Peer
    fileprivate let actionHandler: (PopularItemType)->Void
    fileprivate let articlesEnabled: Bool
    fileprivate let unread: [PeerId : UnreadSearchBadge]
    fileprivate let online: [PeerId: Bool]
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, selfPeer: Peer, articlesEnabled: Bool, unreadArticles: Int32, peers:[Peer], unread: [PeerId : UnreadSearchBadge], online: [PeerId: Bool], action: @escaping(PopularItemType)->Void) {
        self.peers = peers
        self.account = account
        self.unread = unread
        self.online = online
        self.articlesEnabled = articlesEnabled
        self.selfPeer = selfPeer
        self.actionHandler = action
        self.unreadArticles = unreadArticles
        super.init(initialSize, height: 74, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return PopularPeersRowView.self
    }
    
}


private final class PopularPeersRowView : TableRowView {
    

    
    private let tableView: HorizontalTableView
    private let separator: View = View()
    required init(frame frameRect: NSRect) {
        tableView = HorizontalTableView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(separator)
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        
        tableView.beginTableUpdates()
        tableView.removeAll(animation: .effectFade)
        
        guard let item = item as? PopularPeersRowItem else {return}
        _ = tableView.addItem(item: PopularPeerItem(type: .savedMessages(item.selfPeer), account: item.account, action: item.actionHandler))
        if item.articlesEnabled {
            _ = tableView.addItem(item: PopularPeerItem(type: .articles(item.unreadArticles), account: item.account, action: item.actionHandler))
        }
        
        for peer in item.peers {
            _ = tableView.addItem(item: PopularPeerItem(type: .peer(peer, item.unread[peer.id], item.online[peer.id] ?? false), account: item.account, action: item.actionHandler))
        }
        
        tableView.endTableUpdates()
        
        separator.backgroundColor = theme.colors.border
        separator.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
