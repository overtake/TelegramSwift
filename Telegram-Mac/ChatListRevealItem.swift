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
    fileprivate let action:((ChatListFilterPreset?)->Void)?
    fileprivate let context: AccountContext?
    fileprivate let tabs: [ChatListFilterPreset]
    fileprivate let selected: ChatListFilterPreset?
    fileprivate let openSettings: (()->Void)?
    fileprivate let counters: [Int32: Int32]
    init(_ initialSize: NSSize, context: AccountContext, tabs: [ChatListFilterPreset], selected: ChatListFilterPreset?, counters: [Int32 : Int32], action: ((ChatListFilterPreset?)->Void)? = nil, openSettings: (()->Void)? = nil) {
        self.action = action
        self.context = context
        self.tabs = tabs
        self.selected = selected
        self.openSettings = openSettings
        self.counters = counters
        super.init(initialSize)
    }
    
    required init(_ initialSize: NSSize) {
        self.action = nil
        self.context = nil
        self.tabs = []
        self.selected = nil
        self.openSettings = nil
        self.counters = [:]
        super.init(initialSize)
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


private final class ChatListRevealView : TableStickView {
    private let containerView = View()
    private var animated: Bool = false
    private let segmentView: ScrollableSegmentView = ScrollableSegmentView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(segmentView)
        border = [.Right]
    }
    
    override func scrollWheel(with event: NSEvent) {
        segmentView.scrollWheel(with: event)
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
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListRevealItem else {
            return
        }
        
        let animated = self.animated || animated
        self.animated = true
        
        let segmentTheme = ScrollableSegmentTheme(border: presentation.colors.border, selector: presentation.colors.accent, inactiveText: presentation.colors.grayText, activeText: presentation.colors.accent, textFont: .normal(.title))
        var index: Int = 0
        let insets = NSEdgeInsets(left: 10, right: 10, bottom: 6)
        var items:[ScrollableSegmentItem] = [.init(title: L10n.chatListFilterAllChats, index: 0, uniqueId: -1, selected: item.selected == nil, insets: insets, icon: nil, theme: segmentTheme, equatable: UIEquatable(0))]
        index += 1
        for tab in item.tabs {
            
            let unreadCount = item.counters[tab.uniqueId]
            let icon: CGImage?
            if let unreadCount = unreadCount, unreadCount > 0 {
                let attributedString = NSAttributedString.initialize(string: "\(Int(unreadCount).prettyNumber)", color: theme.colors.background, font: .medium(.text), coreText: true)
                let textLayout = TextNode.layoutText(maybeNode: nil,  attributedString, nil, 1, .start, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .center)
                
                icon = generateImage(NSMakeSize(textLayout.0.size.width + 12, textLayout.0.size.height + 4), rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    
                    ctx.setFillColor(theme.colors.accent.cgColor)
                    
                    
                    ctx.round(size, size.height/2.0)
                    ctx.fill(rect)
                    
                    let focus = NSMakePoint((rect.width - textLayout.0.size.width) / 2, (rect.height - textLayout.0.size.height) / 2)
                    textLayout.1.draw(NSMakeRect(focus.x, 2, textLayout.0.size.width, textLayout.0.size.height), in: ctx, backingScaleFactor: 2.0, backgroundColor: .white)
                    
                })!
            } else {
                icon = nil
            }
          
            
            items.append(ScrollableSegmentItem(title: tab.title, index: index, uniqueId: tab.uniqueId, selected: item.selected == tab, insets: insets, icon: icon, theme: segmentTheme, equatable: UIEquatable(unreadCount ?? 0)))
            index += 1
        }
        if let _ = item.openSettings {
            items.append(.init(title: "", index: index, uniqueId: -2, selected: false, insets: NSEdgeInsets(left: 5, right: 10, bottom: 6), icon: theme.icons.chat_filter_add, theme: segmentTheme, equatable: UIEquatable(0)))
            index += 1
        }
       
        
        
        segmentView.updateItems(items, animated: animated)
        
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
        var bp:Int = 0
        bp += 1
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
