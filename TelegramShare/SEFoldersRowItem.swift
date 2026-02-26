//
//  SEFoldersRowItem.swift
//  TelegramShare
//
//  Created by Mikhail Filimonov on 19.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import InAppSettings

class SEFoldersRowItem: TableStickItem {
    fileprivate let action:((ChatListFilter)->Void)?
    fileprivate let context: AccountContext?
    fileprivate let tabs: [ChatListFilter]
    fileprivate let selected: ChatListFilter
    fileprivate let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, context: AccountContext, tabs: [ChatListFilter], selected: ChatListFilter, action: ((ChatListFilter)->Void)? = nil, presentation: TelegramPresentationTheme = theme) {
        self.action = action
        self.context = context
        self.tabs = tabs
        self.presentation = presentation
        self.selected = selected
        super.init(initialSize)
    }
    
    required init(_ initialSize: NSSize) {
        self.action = nil
        self.context = nil
        self.tabs = []
        self.presentation = theme
        self.selected = .allChats
        super.init(initialSize)
    }
    

    override var backdorColor: NSColor {
        return self.presentation.colors.background
    }
    
    override var borderColor: NSColor {
        return self.presentation.colors.border
    }

    override var singletonItem: Bool {
        return false
    }
    
    override var stableId: AnyHashable {
        return SelectablePeersEntryStableId.folders
    }
    
    override func viewClass() -> AnyClass {
        return FoldersRowView.self
    }
    
    override var identifier: String {
        return "FoldersRowView"
    }
    
    override var height: CGFloat {
        return 36
    }
}


final class FoldersRowView : TableStickView {
    private let containerView = View()
    private var animated: Bool = false
    let segmentView: ScrollableSegmentView = ScrollableSegmentView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(segmentView)
    }
    
    
    
    override func mouseUp(with event: NSEvent) {
       
    }
    override func mouseDown(with event: NSEvent) {
        if mouseInside() {
        }
    }
    
    
    override func updateIsVisible(_ visible: Bool, animated: Bool) {
        super.updateIsVisible(visible, animated: animated)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func updateColors() {
        super.updateColors()
        if let item = item as? SEFoldersRowItem {
            segmentView.updateLocalizationAndTheme(theme: item.presentation)
        }
        needsDisplay = true
    }
    
    private var splitViewState: SplitViewState?
    
    private var removeAnimationForNextTransition: Bool = false
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SEFoldersRowItem else {
            return
        }
        
        var animated = (self.animated || animated)
        self.animated = true
        
        
        guard let context = item.context else {
            return
        }
        
        animated = animated && splitViewState == context.layout
        self.splitViewState = context.layout
        
        let segmentTheme = ScrollableSegmentTheme(background: item.presentation.colors.background, border: item.presentation.colors.border, selector: item.presentation.colors.accent, inactiveText: item.presentation.colors.grayText, activeText: item.presentation.colors.accent, textFont: .normal(.title))
        var index: Int = 0
        let insets = NSEdgeInsets(left: 10, right: 10, bottom: 6)
        var items:[ScrollableSegmentItem] = []
        for tab in item.tabs {
            let title: String = tab.title
            items.append(ScrollableSegmentItem(title: title, index: index, uniqueId: Int64(tab.id), selected: item.selected == tab, insets: insets, icon: nil, theme: segmentTheme, equatable: UIEquatable(tab)))
            index += 1
        }
        
        segmentView.updateItems(items, animated: animated)

        segmentView.didChangeSelectedItem = { [weak item] selected in
            if let item = item {
                if selected.uniqueId == -1 {
                    item.action?(.allChats)
                } else {
                    item.action?(item.tabs[selected.index])
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
