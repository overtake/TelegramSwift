//
//  LeftSidebarFolderItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/04/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SwiftSignalKit

extension FolderIcon {
    convenience init(_ filter: ChatListFilter) {
        switch filter {
        case .allChats:
            self.init(emoticon: .allChats)
        case .filter:
            if let emoticon = filter.emoticon {
                self.init(emoticon: .emoji(emoticon))
            } else {
                switch chatListFilterType(filter) {
                case .bots:
                    self.init(emoticon: .bots)
                case .channels:
                    self.init(emoticon: .channels)
                case .contacts:
                    self.init(emoticon: .personal)
                case .groups:
                    self.init(emoticon: .groups)
                case .nonContacts:
                    self.init(emoticon: .personal)
                case .unmuted:
                    self.init(emoticon: .unmuted)
                case .unread:
                    self.init(emoticon: .unread)
                case .generic:
                    self.init(emoticon: .folder)
                }
            }
        }
    }
}

class LeftSidebarFolderItem: TableRowItem {

    fileprivate let folder: ChatListFilter
    fileprivate let selected: Bool
    fileprivate let callback: (ChatListFilter)->Void
    fileprivate let menuItems: (ChatListFilter, Int?, Bool?)-> [ContextMenuItem]
    fileprivate let context: AccountContext
    let icon: CGImage
    let badge: CGImage?
    let nameLayout: TextViewLayout
    let unreadCount: Int
    
    
    init(_ initialSize: NSSize, context: AccountContext, folder: ChatListFilter, selected: Bool, unreadCount: Int, hasUnmutedUnread: Bool, callback: @escaping(ChatListFilter)->Void, menuItems: @escaping(ChatListFilter, Int?, Bool?) -> [ContextMenuItem]) {
        self.folder = folder
        self.context = context
        self.selected = selected
        self.callback = callback
        self.unreadCount = unreadCount
        self.menuItems = menuItems
        var folderIcon = FolderIcon(folder).icon(for: selected ? .sidebarActive : .sidebar)
        nameLayout = TextViewLayout(.initialize(string: folder.title, color: !selected ? NSColor.white.withAlphaComponent(0.5) : .white, font: .medium(10)), alignment: .center)
        nameLayout.measure(width: initialSize.width - 10)
        
        
        
        let generateIcon:()->CGImage? = {
            let icon: CGImage?
            if unreadCount > 0 {
                
                let textColor: NSColor
                if selected {
                    textColor = .black
                } else  {
                    textColor = .white
                }
                
                let attributedString = NSAttributedString.initialize(string: "\(unreadCount.prettyNumber)", color: textColor, font: .medium(.short))
                let textLayout = TextNode.layoutText(maybeNode: nil,  attributedString, nil, 1, .start, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .center)
                var size = NSMakeSize(textLayout.0.size.width + 8, textLayout.0.size.height + 5)
                size = NSMakeSize(max(size.height,size.width), size.height)
                
                let badge = generateImage(size, rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    if selected {
                        ctx.setFillColor(.white)
                    } else if hasUnmutedUnread {
                        ctx.setFillColor(NSColor.accentIcon.cgColor)
                    } else {
                        ctx.setFillColor(NSColor.grayIcon.cgColor)
                    }
                    ctx.round(size, floorToScreenPixels(size.height/2.0))
                    ctx.fill(rect)
                    
//                    ctx.setBlendMode(.clear)
                    
                    let focus = rect.focus(textLayout.0.size)
                    textLayout.1.draw(focus.offsetBy(dx: 0, dy: -1), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .white)
                    
                })!
                
                folderIcon = generateImage(folderIcon.systemSize, contextGenerator: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    
                    ctx.draw(folderIcon, in: rect.focus(folderIcon.systemSize))
                    
                    ctx.clip(to: NSMakeRect(rect.width - floorToScreenPixels(badge.systemSize.width / 2) - 6, rect.height - badge.systemSize.height + 3, badge.systemSize.width + 4, badge.systemSize.height + 4), mask: badge)
                    
                    ctx.clear(rect)
                    
                   // ctx.draw(badge, in: rect)
                })!
                
                icon = badge
                
            } else {
                icon = nil
            }
            return icon
        }
        self.badge = generateIcon()
        self.icon = folderIcon
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return folder.id
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        
        let id = self.folder.id
        let folder = self.folder
        let unreadCount = self.unreadCount
        let context = self.context
        
        let filterPeersAreMuted: Signal<Bool, NoError> = context.engine.peers.currentChatListFilters()
        |> take(1)
        |> mapToSignal { filters -> Signal<Bool, NoError> in
            guard let filter = filters.first(where: { $0.id == id }) else {
                return .single(false)
            }
            guard case let .filter(_, _, _, data) = filter else {
                return .single(false)
            }
            return context.engine.data.get(
                EngineDataList(data.includePeers.peers.map(TelegramEngine.EngineData.Item.Peer.NotificationSettings.init(id:)))
            )
            |> map { list -> Bool in
                for item in list {
                    switch item.muteState {
                    case .default, .unmuted:
                        return false
                    default:
                        break
                    }
                }
                return true
            }
        } |> deliverOnMainQueue
        
        return filterPeersAreMuted |> map { [weak self] allMuted in
            return self?.menuItems(folder, unreadCount, allMuted) ?? []
        }
    }
    
    override var height: CGFloat {
        return 32 + 8 + 8 + nameLayout.layoutSize.height + 4
    }
    
    override func viewClass() -> AnyClass {
        return LeftSidebarFolderView.self
    }
    
}


private final class LeftSidebarFolderView : TableRowView {
    private let imageView = ImageView(frame: NSMakeRect(0, 0, 32, 32))
    private let badgeView = ImageView()
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        addSubview(badgeView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isEventLess = true
        badgeView.isEventLess = true
        imageView.isEventLess = true
    }
 
    override func updateIsResorting() {
        updateHighlight(animated: true)
    }
 
    func updateHighlight(animated: Bool = true) {
        guard let item = item as? LeftSidebarFolderItem else {
            return
        }
        if !item.selected, mouseInside(), (NSEvent.pressedMouseButtons & (1 << 0)) != 0 {
            self.imageView.change(opacity: 0.8, animated: animated)
            self.textView.change(opacity: 0.8, animated: animated)
        } else {
            self.imageView.change(opacity: 1.0, animated: animated)
            self.textView.change(opacity: 1.0, animated: animated)
        }
    }
    
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHighlight()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHighlight()
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateHighlight()
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        updateHighlight()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        updateHighlight()
        
        if mouseInside() {
            guard let item = item as? LeftSidebarFolderItem else {
                return
            }
            item.callback(item.folder)
        }
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? LeftSidebarFolderItem else {
            return
        }
     //   imageView.animates = animated
        imageView.image = item.icon
        imageView.sizeToFit()
        textView.update(item.nameLayout)
        
        
      //  badgeView.animates = animated
        badgeView.image = item.badge
        badgeView.sizeToFit()
        
        updateHighlight(animated: animated)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        imageView.centerX(y: 8)
        textView.centerX(y: imageView.frame.maxY + 4)
        badgeView.setFrameOrigin(NSMakePoint(imageView.frame.maxX - floorToScreenPixels(badgeView.frame.width / 2) - 4, imageView.frame.minY - 4))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
