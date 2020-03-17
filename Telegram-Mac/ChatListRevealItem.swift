//
//  ChatListRevealItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import SyncCore

class ChatListRevealItem: TableStickItem {
    fileprivate let action:((ChatListFilter?)->Void)?
    fileprivate let context: AccountContext?
    fileprivate let tabs: [ChatListFilter]
    fileprivate let selected: ChatListFilter?
    fileprivate let openSettings: (()->Void)?
    fileprivate let counters: ChatListFilterBadges
    fileprivate let _menuItems: ((ChatListFilter?)->[ContextMenuItem])?
    init(_ initialSize: NSSize, context: AccountContext, tabs: [ChatListFilter], selected: ChatListFilter?, counters: ChatListFilterBadges, action: ((ChatListFilter?)->Void)? = nil, openSettings: (()->Void)? = nil, menuItems: ((ChatListFilter?)->[ContextMenuItem])? = nil) {
        self.action = action
        self.context = context
        self.tabs = tabs
        self.selected = selected
        self.openSettings = openSettings
        self.counters = counters
        self._menuItems = menuItems
        super.init(initialSize)
    }
    
    required init(_ initialSize: NSSize) {
        self.action = nil
        self.context = nil
        self.tabs = []
        self.selected = nil
        self.openSettings = nil
        self._menuItems = nil
        self.counters = ChatListFilterBadges(total: 0, filters: [])
        super.init(initialSize)
    }

    
    func menuItems(for item: ChatListFilter?) -> [ContextMenuItem] {
        return self._menuItems?(item) ?? []
    }
    
    override var stableId: AnyHashable {
        return UIChatListEntryId.reveal
    }
    
    override func viewClass() -> AnyClass {
        return ChatListRevealView.self
    }
    
    override var identifier: String {
        return "ChatListRevealView"
    }
    
    override var height: CGFloat {
        return 36
    }
}


final class ChatListRevealView : TableStickView {
    private let containerView = View()
    private var animated: Bool = false
    let segmentView: ScrollableSegmentView = ScrollableSegmentView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(segmentView)
        border = [.Right]
        
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: segmentView.scrollView.contentView, queue: OperationQueue.main, using: { [weak self] notification  in
            guard let `self` = self else {
                return
            }
            guard let item = self.item else {
                return
            }
            guard let view = item.view as? ChatListRevealView else {
                return
            }
            if !self.segmentView.scrollView.clipView.isAnimateScrolling {
                if view !== self {
                    view.segmentView.scrollView.contentView.scroll(to: self.segmentView.scrollView.documentOffset)
                } else if let view = item.table?.p_stickView as? ChatListRevealView, view !== self {
                    view.segmentView.scrollView.contentView.scroll(to: self.segmentView.scrollView.documentOffset)
                }
            }
        })
        
    }
    
    
    override func mouseUp(with event: NSEvent) {
       
    }
    override func mouseDown(with event: NSEvent) {
        if mouseInside() {
        }
    }
    
    
    override func updateIsVisible(_ visible: Bool, animated: Bool) {
        super.updateIsVisible(visible, animated: animated)
                
//        var visible = visible
//        if let table = item?.table {
//            visible = visible && table.documentOffset.y > 0
//        }
//        separator.change(opacity: visible ? 1 : 0, animated: false)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        super.updateColors()
        backgroundColor = backdorColor
        segmentView.updateLocalizationAndTheme(theme: theme)
        needsDisplay = true
    }
    
    private var splitViewState: SplitViewState?
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListRevealItem else {
            return
        }
        
        var animated = self.animated || animated
        self.animated = true
        
        
        guard let context = item.context else {
            return
        }
        
        let generateIcon:(ChatListFilter?)->CGImage? = { tab in
            let unreadCount:ChatListFilterBadge? = item.counters.count(for: tab)
            let icon: CGImage?
            if let unreadCount = unreadCount, unreadCount.count > 0, context.sharedContext.layout != .minimisize {
                let attributedString = NSAttributedString.initialize(string: "\(unreadCount.count.prettyNumber)", color: theme.colors.background, font: .medium(.short), coreText: true)
                let textLayout = TextNode.layoutText(maybeNode: nil,  attributedString, nil, 1, .start, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .center)
                var size = NSMakeSize(textLayout.0.size.width + 8, textLayout.0.size.height + 5)
                size = NSMakeSize(max(size.height,size.width), size.height)
                
                icon = generateImage(size, rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    if item.selected == tab || unreadCount.hasUnmutedUnread {
                        ctx.setFillColor(theme.colors.accent.cgColor)
                    } else {
                        ctx.setFillColor(theme.colors.grayText.cgColor)
                    }
                    
                    
                    ctx.round(size, size.height/2.0)
                    ctx.fill(rect)
                    
                    let focus = rect.focus(textLayout.0.size)
                    textLayout.1.draw(focus.offsetBy(dx: 0, dy: -1), in: ctx, backingScaleFactor: 2.0, backgroundColor: .white)
                    
                })!
            } else if let tab = tab {
                if context.sharedContext.layout == .minimisize {
                    icon = tab.icon
                } else {
                    icon = nil
                }
            } else {
                icon = nil
            }
            return icon
        }
        
        animated = animated && splitViewState == context.sharedContext.layout
        self.splitViewState = context.sharedContext.layout
        
        let segmentTheme = ScrollableSegmentTheme(border: presentation.colors.border, selector: presentation.colors.accent, inactiveText: presentation.colors.grayText, activeText: presentation.colors.accent, textFont: .normal(.title))
        var index: Int = 0
        let insets = NSEdgeInsets(left: 10, right: 10, bottom: 6)
        var items:[ScrollableSegmentItem] = [.init(title: L10n.chatListFilterAllChats, index: 0, uniqueId: -1, selected: item.selected == nil, insets: insets, icon: generateIcon(nil), theme: segmentTheme, equatable: UIEquatable(L10n.chatListFilterAllChats))]
        index += 1
        for tab in item.tabs {
            let unreadCount = item.counters.count(for: tab)
            let icon: CGImage? = generateIcon(tab)
            let title: String = context.sharedContext.layout == .minimisize ? "" : tab.title
           
            items.append(ScrollableSegmentItem(title: title, index: index, uniqueId: tab.id, selected: item.selected == tab, insets: insets, icon: icon, theme: segmentTheme, equatable: UIEquatable(unreadCount)))
            index += 1
        }
//        if let _ = item.openSettings {
//            items.append(.init(title: "", index: index, uniqueId: -2, selected: false, insets: NSEdgeInsets(left: 5, right: 10, bottom: 6), icon: theme.icons.chat_filter_add, theme: segmentTheme, equatable: UIEquatable(0)))
//            index += 1
//        }
//       
        
        
        segmentView.updateItems(items, animated: animated)
        
        segmentView.resortRange = NSMakeRange(1, items.count - 1)
        segmentView.resortHandler = { from, to in
            _ = updateChatListFiltersInteractively(postbox: context.account.postbox, { state in
                var state = state
                state.move(at: from - 1, to: to - 1)
                return state
            }).start()
        }
        segmentView.didChangeSelectedItem = { [weak item] selected in
            if let item = item {
                if selected.uniqueId == -1 {
                    item.action?(nil)
                } else if selected.uniqueId == -2 {
                    item.openSettings?()
                } else {
                    item.action?(item.tabs[selected.index - 1])
                }
            }
        }
        segmentView.menuItems = { [weak item] selected in
            if let item = item, selected.uniqueId != -1 && selected.uniqueId != -2 {
                return item.menuItems(for: item.tabs[selected.index - 1])
            } else if let item = item, selected.uniqueId == -1 {
                return item.menuItems(for: nil)
            } else {
                return []
            }
        }
      
    }
    
    
    override var isHidden: Bool {
        didSet {
            if isHidden {
                var bp:Int = 0
                bp += 1
            }
        }
    }
    
    override var isAlwaysUp: Bool {
        return true
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
    }
    
    public override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func layout() {
        super.layout()
        
        containerView.frame = NSMakeRect(0, 0, bounds.width - 1, bounds.height)
        
        segmentView.frame = containerView.bounds
      
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
