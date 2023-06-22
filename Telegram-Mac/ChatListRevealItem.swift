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
import InAppSettings

class ChatListRevealItem: TableStickItem {
    fileprivate let action:((ChatListFilter)->Void)?
    fileprivate let context: AccountContext?
    fileprivate let tabs: [ChatListFilter]
    fileprivate let selected: ChatListFilter
    fileprivate let openSettings: (()->Void)?
    fileprivate let counters: ChatListFilterBadges
    fileprivate let _menuItems: ((ChatListFilter, Int?, Bool?)->[ContextMenuItem])?
    init(_ initialSize: NSSize, context: AccountContext, tabs: [ChatListFilter], selected: ChatListFilter, counters: ChatListFilterBadges, action: ((ChatListFilter)->Void)? = nil, openSettings: (()->Void)? = nil, menuItems: ((ChatListFilter, Int?, Bool?)->[ContextMenuItem])? = nil) {
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
        self.selected = .allChats
        self.openSettings = nil
        self._menuItems = nil
        self.counters = ChatListFilterBadges(total: 0, filters: [])
        super.init(initialSize)
    }

    override var singletonItem: Bool {
        return true
    }
    
    func menuItems(for item: ChatListFilter, unreadCount: Int?) -> Signal<[ContextMenuItem], NoError> {
        
        let id = item.id
        let folder = item
        let context = self.context
        
        guard let context = self.context else {
            return .complete()
        }
        
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
            return self?._menuItems?(item, unreadCount, allMuted) ?? []
        }
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
    
    private var removeAnimationForNextTransition: Bool = false
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListRevealItem else {
            return
        }
        
        var animated = (self.animated || animated)
        self.animated = true
        
        
        guard let context = item.context else {
            return
        }
        
        let generateIcon:(ChatListFilter?)->CGImage? = { tab in
            let unreadCount:ChatListFilterBadge? = item.counters.count(for: tab)
            let icon: CGImage?
            if let unreadCount = unreadCount, unreadCount.count > 0 {
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
                        ctx.setFillColor(theme.colors.badgeMuted.cgColor)
                    }
                    
                    
                    ctx.round(size, size.height/2.0)
                    ctx.fill(rect)
                    
                    let focus = rect.focus(textLayout.0.size)
                    textLayout.1.draw(focus.offsetBy(dx: 0, dy: -1), in: ctx, backingScaleFactor: 2.0, backgroundColor: .white)
                    
                })!
            } else if let _ = tab {
                icon = nil
            } else {
                icon = nil
            }
            return icon
        }
        
        animated = animated && splitViewState == context.layout
        self.splitViewState = context.layout
        
        let segmentTheme = ScrollableSegmentTheme(background: presentation.colors.background, border: presentation.colors.border, selector: presentation.colors.accent, inactiveText: presentation.colors.grayText, activeText: presentation.colors.accent, textFont: .normal(.title))
        var index: Int = 0
        let insets = NSEdgeInsets(left: 10, right: 10, bottom: 6)
        var items:[ScrollableSegmentItem] = []
        for tab in item.tabs {
            let unreadCount = item.counters.count(for: tab)
            let icon: CGImage? = generateIcon(tab)
            let title: String = tab.title
           
            items.append(ScrollableSegmentItem(title: title, index: index, uniqueId: tab.id, selected: item.selected == tab, insets: insets, icon: icon, theme: segmentTheme, equatable: UIEquatable(unreadCount)))
            index += 1
        }
        
        segmentView.updateItems(items, animated: animated)
        let range: NSRange
        if context.isPremium {
            range = NSMakeRange(0, items.count)
        } else {
            range = NSMakeRange(1, items.count - 1)
        }
        segmentView.resortRange = range
        segmentView.resortHandler = { from, to in
            _ = context.engine.peers.updateChatListFiltersInteractively({ state in
                var state = state
                if context.isPremium {
                    state.move(at: from, to: to)
                } else {
                    state.move(at: from - 1, to: to - 1)
                }
                return state
            }).start()
        }
        segmentView.didChangeSelectedItem = { [weak item] selected in
            if let item = item {
                if selected.uniqueId == -1 {
                    item.action?(.allChats)
                } else if selected.uniqueId == -2 {
                    item.openSettings?()
                } else {
                    item.action?(item.tabs[selected.index])
                }
            }
        }
        segmentView.menuItems = { [weak item] selected in
            if let item = item, selected.uniqueId != -1 && selected.uniqueId != -2 {
                return item.menuItems(for: item.tabs[selected.index], unreadCount: item.counters.count(for: item.tabs[selected.index])?.count)
            } else if let item = item, selected.uniqueId == -1 {
                return item.menuItems(for: .allChats, unreadCount: nil)
            } else {
                return .single([])
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
