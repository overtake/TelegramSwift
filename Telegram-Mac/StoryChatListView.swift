//
//  StoryChatListView.swift
//  Telegram
//
//  Created by Mike Renoir on 08.05.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox
import ObjcUtils

func interpolateArray(from minValue: CGFloat, to maxValue: CGFloat, count: Int) -> [CGFloat] {
    var result: [CGFloat] = []
    
    for i in 0..<count {
        let t = CGFloat(i) / CGFloat(count - 1)
        let interpolatedValue = (1 - t) * maxValue + t * minValue
        result.append(interpolatedValue)
    }
    
    return result
}

func linearArray(from minValue: CGFloat, to maxValue: CGFloat, count: Int) -> [CGFloat] {
    var result: [CGFloat] = []
    
    let value = (maxValue - minValue) / CGFloat(count)
    for _ in 0 ..< count {
        result.append(value)
    }
    return result
}


private struct StoryChatListEntry : Equatable, Comparable, Identifiable {
    let item: EngineStorySubscriptions.Item
    let index: Int
    let appearance: Appearance
    static func <(lhs: StoryChatListEntry, rhs: StoryChatListEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    static func ==(lhs: StoryChatListEntry, rhs: StoryChatListEntry) -> Bool {
        if lhs.item != rhs.item {
            return false
        }
        return lhs.appearance == rhs.appearance
    }
    
    var stableId: AnyHashable {
        return item.peer.id
    }
    var id: PeerId {
        return item.peer.id
    }
    var hasUnseen: Bool {
        return self.item.hasUnseen
    }
}



final class StoryListChatListRowItem : TableRowItem {
    
    enum InterfaceState : Equatable {
        
        enum From {
            case concealed
            case revealed
        }
        
        case revealed
        case concealed
        case empty
        case progress(CGFloat, From, Bool)
        
        var height: CGFloat {
            switch self {
            case .revealed:
                return 66
            case .concealed:
                return 30
            case .empty:
                return 0
            case let .progress(progress, _, _):
                return 30 + 36 * progress
            }
        }
        
        var initFromEvent: Bool? {
            switch self {
            case let .progress(_, _, initFromEvent):
                return initFromEvent
            default:
                return nil
            }
        }
        
        var navigationHeight: CGFloat {
            return InterfaceState.revealed.height * self.progress + (9 * self.progress)
        }
        var progress: CGFloat {
            switch self {
            case .revealed:
                return 1.0
            case .concealed:
                return 0.0
            case .empty:
                return 0.0
            case let .progress(progress, _, _):
                return progress
            }
        }
        
        var isProgress: Bool {
            switch self {
            case .progress:
                return true
            default:
                return false
            }
        }
        
        static var small: CGFloat {
            return 30
        }
        static var full: CGFloat {
            return 66
        }
    }
    
    private let _stableId: AnyHashable
    let context: AccountContext
    let state: EngineStorySubscriptions
    let isArchive: Bool
    let open: (StoryInitialIndex?, Bool)->Void
    let getInterfaceState: ()->InterfaceState
    let reveal: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, isArchive: Bool, state: EngineStorySubscriptions, open:@escaping(StoryInitialIndex?, Bool)->Void, getInterfaceState: @escaping()->InterfaceState = { return .revealed }, reveal: @escaping()->Void) {
        self._stableId = stableId
        self.context = context
        self.isArchive = isArchive
        self.state = state
        self.open = open
        self.reveal = reveal
        self.getInterfaceState = getInterfaceState
        super.init(initialSize)
    }
    
    
    var itemsCount: Int {
        var count: Int = 0
        if !self.isArchive, let accountItem = self.state.accountItem, accountItem.storyCount > 0 {
            count += 1
        }
        count += self.state.items.count
        return count
    }
    
    static var smallSize: NSSize {
        return NSMakeSize(24, 24)
    }
    static var fullSize: NSSize {
        return NSMakeSize(44, 44)
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return getInterfaceState().height
    }
    
    var progress: CGFloat {
        return getInterfaceState().progress
    }
    
    var navigationHeight: CGFloat {
        return getInterfaceState().navigationHeight
    }
    
    override func viewClass() -> AnyClass {
        return StoryListChatListRowView.self
    }
    
    override var animatable: Bool {
        return true
    }
}

private final class StoryListContainer : Control {
    
    var loadMore:((ScrollDirection)->Void)? = nil
    
    private var list: [StoryChatListEntry] = []
    private var views: [ItemView] = []
    private let documentView = View()
    private let componentsView = View()
    private var components:[ComponentView] = []

    private let scrollView = HorizontalScrollView(frame: .zero)
    private var progress: CGFloat = 1.0

    private var item: StoryListChatListRowItem?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        scrollView.documentView = documentView
        addSubview(scrollView)
        
        documentView.layer?.masksToBounds = false
        componentsView.layer?.masksToBounds = false
        self.layer?.masksToBounds = false
        scrollView.layer?.masksToBounds = false
        scrollView.contentView.layer?.masksToBounds = false
        documentView.addSubview(componentsView)
        scrollView.background = .clear
        //self.scaleOnClick = true
        
        set(handler: { [weak self] _ in
            self?.item?.reveal()
        }, for: .Click)
        
        NotificationCenter.default.addObserver(forName: NSScrollView.boundsDidChangeNotification, object: scrollView.clipView, queue: nil, using: { [weak self] _ in
            self?.updateScroll()
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var scrollOffset: NSPoint = .zero
    
    private func updateScroll() {
        let previous = self.scrollOffset
        let current = scrollView.documentOffset
        self.scrollOffset = current
        
        if previous.x < current.x, (current.x - frame.width) - documentSize.width < frame.width {
            self.loadMore?(.bottom)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func getAlpha(_ item: StoryListEntryRowItem, index i: Int, progress: CGFloat) -> CGFloat {
        if visibleRange.contains(i) {
            if !focusRange.contains(i) {
                return progress
            } else {
                return 1.0
            }
        } else {
            return progress == 1.0 ? 1 : 0
        }
    }
    
    private func getFrame(_ item: StoryListEntryRowItem, index i: Int, progress: CGFloat) -> NSRect {
        let focusRange = self.focusRange
        
        let w = StoryListChatListRowItem.smallSize.width
        let itemSize = NSMakeSize(w + (item.itemWidth - w) * progress, w + (item.itemHeight - w) * progress)
        
        var frame = CGRect(origin: .zero, size: itemSize)
        if i < focusRange.location {
            let w = itemSize.width - (itemSize.width / 2 * (1 - progress))
            let h = itemSize.height - (itemSize.height / 2 * (1 - progress))
            frame.size = NSMakeSize(w, h)
            
            frame.origin.x = (CGFloat(i) * itemSize.width)

            frame.origin.x += (10.0 + (CGFloat(i) * 20))
        } else {
            
            if i >= focusRange.max {
                let w = itemSize.width - (itemSize.width / 2 * (1 - progress))
                let h = itemSize.height - (itemSize.height / 2 * (1 - progress))
                frame.size = NSMakeSize(w, h)
            }
            
            frame.origin.x = ((1.0 - progress) * CGFloat(i - focusRange.location)) * itemSize.width + (CGFloat(i) * itemSize.width * progress) + ((1.0 - progress) * 13.0)
            
            let insets = (10.0 + (CGFloat(i) * 20)) * progress
            frame.origin.x += insets
            
            if i > focusRange.max {
                frame.origin.x -= 20 * CGFloat(i - focusRange.max) * (1 - progress)
            }
            if i > focusRange.location {
                frame.origin.x -= ((1.0 - progress) * itemSize.width / 2) * CGFloat(i - focusRange.location)
            }
        }
        frame.origin.y = (self.frame.height - frame.height) / 2
        return frame
    }
    
    
    func set(transition: TableUpdateTransition, item: StoryListChatListRowItem, context: AccountContext, progress: CGFloat, animated: Bool) {
        
        self.progress = progress
        self.item = item
        
        if !transition.isEmpty {
            var toRemove_v:[AnyHashable : ItemView] = [:]
            var toRemove_c:[AnyHashable : ComponentView] = [:]

            for deleted in transition.deleted.reversed() {
                let view = views.remove(at: deleted)
                let component = components.remove(at: deleted)
                if let item = view.item {
                    toRemove_v[item.stableId] = view
                } else {
                    performSubviewRemoval(view, animated: animated, scale: true)
                }
                if let item = component.item {
                    toRemove_c[item.stableId] = component
                } else {
                    performSubviewRemoval(view, animated: animated, scale: true)
                }
            }
            for inserted in transition.inserted {
                let item = inserted.1 as! StoryListEntryRowItem
                
                let view: ItemView
                let component: ComponentView
                let isNew: Bool
                if let v = toRemove_v[item.stableId] {
                    let c = toRemove_c[item.stableId]!
                    views.insert(v, at: inserted.0)
                    components.insert(c, at: inserted.0)
                    toRemove_v.removeValue(forKey: item.stableId)
                    toRemove_c.removeValue(forKey: item.stableId)
                    view = v
                    component = c
                    isNew = false
                } else {
                    let rect = getFrame(item, index: inserted.0, progress: progress)
                    let alpha = Float(getAlpha(item, index: inserted.0, progress: progress))
                    view = ItemView(frame: rect)
                    component = ComponentView(frame: rect)
                    
                    views.insert(view, at: inserted.0)
                    components.insert(component, at: inserted.0)
                    
                    view.layer?.opacity = alpha
                    component.layer?.opacity = alpha
                    
                    isNew = true
                }
                
                view.set(item: item, open: { [weak self] item in
                    self?.open(item)
                }, progress: progress, animated: false)
                
                component.set(item: item, open: { [weak self] item in
                    self?.open(item)
                }, progress: progress, animated: false)
                
                if inserted.0 == 0 {
                    documentView.addSubview(view, positioned: .above, relativeTo: componentsView)
                } else {
                    documentView.addSubview(view, positioned: .above, relativeTo: views[inserted.0 - 1])
                }
                
                if inserted.0 == 0 {
                    componentsView.addSubview(component, positioned: .below, relativeTo: componentsView.subviews.first)
                } else {
                    componentsView.addSubview(component, positioned: .above, relativeTo: components[inserted.0 - 1])
                }
                
                if animated, isNew {
                    view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    view.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                    
                    component.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    component.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)

                }
            }
            for updated in transition.updated {
                views[updated.0].set(item: updated.1, open: { [weak self] item in
                    self?.open(item)
                }, progress: progress, animated: animated)
                
                components[updated.0].set(item: updated.1, open: { [weak self] item in
                    self?.open(item)
                }, progress: progress, animated: animated)
            }
            
            for (_, view) in toRemove_c {
                performSubviewRemoval(view, animated: animated, scale: true)
            }
            for (_, view) in toRemove_v {
                performSubviewRemoval(view, animated: animated, scale: true)
            }
            toRemove_c.removeAll()
            toRemove_v.removeAll()
        }
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate

        if progress != 1.0 {
            if animated, scrollView.documentOffset != .zero {
                let to = CGRect.init(origin: .zero, size: scrollView.clipView.bounds.size)
                scrollView.clipView.layer?.animateBounds(from: scrollView.clipView.bounds, to: to, duration: 0.2, timingFunction: .easeOut)
            }
        }
        self.updateLayout(size: frame.size, transition: transition)
        
        for (i, view) in views.enumerated() {
            view.component = components[i]
            
            if focusRange.contains(i) {
                view.layer?.zPosition = 1000.0 - CGFloat(i)
            } else {
                view.layer?.zPosition = CGFloat(views.count - i)
            }
            view.userInteractionEnabled = progress == 1.0
        }
        for (i, view) in components.enumerated() {
            view.layer?.zPosition = CGFloat(i)
        }
        self.userInteractionEnabled = progress != 1.0
    }
    
    var focusRange: NSRange {
        if let itemView = views.first, itemView.item?.peerId == item?.context.peerId {
            if views.count > 3 {
                return NSMakeRange(1, 3)
            } else {
                if views.count > 3, views[1].item?.entry.hasUnseen == true {
                    return NSMakeRange(1, min(3, views.count))
                } else {
                    return NSMakeRange(0, min(3, views.count))
                }
            }
        } else {
            return NSMakeRange(0, min(3, views.count))
        }
    }
    
    var visibleRange: NSRange {
        let range = NSMakeRange(0, Int(ceil(max(0, floor(scrollView.documentOffset.x)) + frame.width / 70)))
        return range
    }
    
    var documentSize: NSSize {
        if let last = views.last {
            return NSMakeSize(max(last.frame.maxX + 10, frame.width), frame.height)
        }
        return frame.size
    }
    
    
    var unitDocumentSize: NSSize {
        let count = CGFloat(views.count)
        return NSMakeSize(10 + (count * 50) + ((count - 1) * 20) + 10, frame.height)
    }
    
    private func open(_ item: StoryListEntryRowItem) {
        item.open(.init(peerId: item.entry.id, id: nil, messageId: nil, takeControl: { [weak self] peerId, _, _ in
            return self?.scrollAndFindItem(peerId, animated: false)
        }), false)
    }
    
    private func scrollAndFindItem(_ peerId: PeerId, animated: Bool) -> NSView? {
        for (i, view) in views.enumerated() {
            if view.item?.entry.id == peerId {
                if view.visibleRect != .zero {
                    return view.imageView
                }
               // self.scroll(index: i, animated: animated, toVisible: true)
            }
        }
        return nil
    }
    
    private func scroll(index: Int, animated: Bool, toVisible: Bool) {
        let view = self.views[index]
        if toVisible && view.visibleRect.width < view.frame.width / 2 || !toVisible {
            scrollView.clipView.scroll(to: NSMakePoint(min(max(view.frame.midX - frame.width / 2, 0), max(documentView.frame.width - frame.width, 0)), 0), animated: animated)
        }
    }
    
    func scaleItems(scale: CGFloat, animated: Bool) {
        for view in views {
            if view.visibleRect != .zero {
                let rect = view.bounds
                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, rect.width / 2, rect.height / 2, 0)
                fr = CATransform3DScale(fr, scale, scale, 1)
                fr = CATransform3DTranslate(fr, -(rect.width / 2), -(rect.height / 2), 0)
                view.layer?.transform = fr
            }
        }
    }

    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let documentRect = CGRect(origin: .zero, size: documentSize)
        transition.updateFrame(view: documentView, frame: documentRect)
        transition.updateFrame(view: componentsView, frame: documentRect)

        scrollView.contentView._change(size: CGSize(width: scrollView.contentView.bounds.width, height: size.height), animated: transition.isAnimated, duration: transition.duration, timingFunction: transition.timingFunction)
        

        transition.updateFrame(view: scrollView, frame: size.bounds)
        
        for (i, view) in views.enumerated() {
            if let item = view.item {
                let frame = getFrame(item, index: i, progress: progress)
                let alpha = getAlpha(item, index: i, progress: progress)
                
                transition.updateFrame(view: view, frame: frame)
                transition.updateAlpha(view: view, alpha: alpha)
                view.set(progress: progress, transition: transition)

                let component = components[i]
                
                transition.updateFrame(view: component, frame: frame)
                transition.updateAlpha(view: component, alpha: alpha)
                component.set(progress: progress, transition: transition)
            }
        }
        
    }
}

final class StoryListChatListRowView: TableRowView {
        
    private let interfaceView: StoryListContainer
    
    
    required init(frame frameRect: NSRect) {
        self.interfaceView = StoryListContainer(frame: NSMakeRect(0, 0, max(frameRect.width, 300), frameRect.height))
        super.init(frame: frameRect)
        addSubview(interfaceView)
        

        interfaceView.loadMore = { [weak self] direction in
            switch direction {
            case .bottom:
                if let item = self?.item as? StoryListChatListRowItem {
                    if let _ = item.state.hasMoreToken {
                        item.context.account.filteredStorySubscriptionsContext?.loadMore()
                    }
                }
            default:
                break
            }
        }
    }
    
    override var backdorColor: NSColor {
        return .clear
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var current: [StoryChatListEntry] = []
    
    private var interfaceState: StoryListChatListRowItem.InterfaceState?
    override func set(item: TableRowItem, animated: Bool = false) {
        
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoryListChatListRowItem else {
            return
        }
        
        var entries:[StoryChatListEntry] = []
        var index: Int = 0
        if !item.isArchive, let item = item.state.accountItem, item.storyCount > 0 {
            entries.append(.init(item: item, index: index, appearance: appAppearance))
            index += 1
        }
        
        for item in item.state.items {
            if item.storyCount > 0 {
                entries.append(.init(item: item, index: index, appearance: appAppearance))
                index += 1
            }
        }
        

        
        let previous = self.interfaceState
        let interfaceState = item.getInterfaceState()
        self.interfaceState = interfaceState
        
                
      

        let initialSize = NSMakeSize(item.height, item.height)
        let context = item.context

        let (deleted, inserted, updated) = proccessEntriesWithoutReverse(self.current, right: entries, { entry in
            return StoryListEntryRowItem(initialSize, entry: entry, context: context, open: item.open)
        })
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated: animated, grouping: false, animateVisibleOnly: false)

//        CATransaction.begin()
        self.interfaceView.set(transition: transition, item: item, context: item.context, progress: item.progress, animated: animated)
//        CATransaction.commit()
        

        self.current = entries
        
        if interfaceView.unitDocumentSize.width < interfaceView.frame.width * 4 {
            if let _ = item.state.hasMoreToken {
                item.context.account.filteredStorySubscriptionsContext?.loadMore()
            }
        }
        
    }
    
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        let rect = NSMakeSize(max(300, size.width), size.height).bounds
        transition.updateFrame(view: interfaceView, frame: rect)
        interfaceView.updateLayout(size: rect.size, transition: transition)
    }
}

private final class StoryListEntryRowItem : TableRowItem {
    let entry: StoryChatListEntry
    let context: AccountContext
    
    let stateComponent: AvatarStoryIndicatorComponent

    let open:(StoryInitialIndex?, Bool)->Void
    init(_ initialSize: NSSize, entry: StoryChatListEntry, context: AccountContext, open: @escaping(StoryInitialIndex?, Bool)->Void) {
        self.entry = entry
        self.context = context
        self.open = open
        self.stateComponent = .init(story: entry.item, presentation: presentation)
        super.init(initialSize)
    }
    
    var peerId: PeerId {
        return entry.item.peer.id
    }
    
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items: [ContextMenuItem] = []
        let peerId = self.entry.item.peer.id
        let context = self.context
        
        if context.peerId != peerId {
            items.append(.init("View Profile", handler: {
                PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
            }, itemImage: MenuAnimation.menu_open_profile.value))
            
            let peer = self.entry.item.peer._asPeer()
            if peer.storyArchived {
                items.append(.init("Unarchive", handler: {
                    context.engine.peers.updatePeerStoriesHidden(id: peerId, isHidden: false)
                    showModalText(for: context.window, text: "Stories from \(peer.compactDisplayTitle) will now be shown in Chats.")
                }, itemImage: MenuAnimation.menu_show_message.value))
            } else {
                items.append(.init("Archive", handler: {
                    context.engine.peers.updatePeerStoriesHidden(id: peerId, isHidden: true)
                    showModalText(for: context.window, text: "Stories from \(peer.compactDisplayTitle) will now be shown in Archive.")
                }, itemImage: MenuAnimation.menu_move_to_contacts.value))
            }
            
        } else {
            items.append(.init("Saved Stories", handler: {
                context.bindings.rootNavigation().push(StoryMediaController(context: context, peerId: context.peerId, listContext: PeerStoryListContext(account: context.account, peerId: context.peerId, isArchived: false), standalone: true, isArchived: false))
            }, itemImage: MenuAnimation.menu_stories.value))
            
            items.append(.init("Archived Stories", handler: {
                context.bindings.rootNavigation().push(StoryMediaController(context: context, peerId: context.peerId, listContext: PeerStoryListContext(account: context.account, peerId: context.peerId, isArchived: true), standalone: true, isArchived: true))
            }, itemImage: MenuAnimation.menu_archive.value))
        }
        

        return .single(items)
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override var height: CGFloat {
        return 70
    }

    override var width: CGFloat {
        return 86
    }
    
    var itemHeight: CGFloat {
        return 66
    }
    var itemWidth: CGFloat {
        return 50
    }
}

private final class ComponentView : Control {
    private let stateView = AvatarStoryIndicatorComponent.IndicatorView(frame: StoryListChatListRowItem.fullSize.bounds)
    fileprivate var item: StoryListEntryRowItem?
    private var progress: CGFloat = 1.0
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(stateView)
        stateView.isEventLess = true
        self.userInteractionEnabled = false
        self.scaleOnClick = true
        self.layer?.masksToBounds = false

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func set(item: TableRowItem, open: @escaping(StoryListEntryRowItem)->Void, progress: CGFloat, animated: Bool) {
        guard let item = item as? StoryListEntryRowItem else {
            return
        }
        self.progress = progress
        self.item = item
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        self.updateLayout(size: frame.size, transition: transition)

    }
    
    func set(progress: CGFloat, transition: ContainedViewLayoutTransition) {
        self.progress = progress
        self.updateLayout(size: self.frame.size, transition: transition)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        guard let item = self.item else {
            return
        }
        
        let stateSize = NSMakeSize(size.width - 6, size.width - 6)
        let stateRect = CGRect(origin: CGPoint(x: (size.width - stateSize.width) / 2, y: 3), size: stateSize)
        
        transition.updateFrame(view: stateView, frame: stateRect.insetBy(dx: -3, dy: -3))
        stateView.update(component: item.stateComponent, availableSize: NSMakeSize(size.width - 6, size.width - 6), progress: progress, transition: transition)

    }

}

private final class ItemView : Control {
    fileprivate let imageView = AvatarControl(font: .avatar(15))
    fileprivate let smallImageView = AvatarControl(font: .avatar(7))
    fileprivate let textView = TextView()
    fileprivate let backgroundView = View()
    fileprivate var item: StoryListEntryRowItem?
    private var open:((StoryListEntryRowItem)->Void)?
    
    weak var component: ComponentView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.setFrameSize(StoryListChatListRowItem.fullSize)
        self.addSubview(textView)
        smallImageView.userInteractionEnabled = false
        imageView.userInteractionEnabled = false
        self.addSubview(backgroundView)
        self.addSubview(imageView)
        self.addSubview(smallImageView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        self.layer?.masksToBounds = false
        
        self.scaleOnClick = true
        
        self.contextMenu = { [weak self] in
            let menu = ContextMenu()
            if let signal = self?.item?.menuItems(in: .zero) {
                _ = signal.start(next: { [weak menu] items in
                    for item in items {
                        menu?.addItem(item)
                    }
                })
            }
            return menu
        }
        
        set(handler: { [weak self] _ in
            if let item = self?.item {
                self?.open?(item)
            }
        }, for: .Click)
        
    }
    
    override func stateDidUpdate(_ state: ControlState) {
        super.stateDidUpdate(state)
        component?.stateDidUpdate(state)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(item: TableRowItem, open: @escaping(StoryListEntryRowItem)->Void, progress: CGFloat, animated: Bool) {
        
        guard let item = item as? StoryListEntryRowItem else {
            return
        }
        
        self.open = open
        self.progress = progress
        self.item = item
        
        imageView.setPeer(account: item.context.account, peer: item.entry.item.peer._asPeer(), size: StoryListChatListRowItem.fullSize)
        smallImageView.setPeer(account: item.context.account, peer: item.entry.item.peer._asPeer(), size: StoryListChatListRowItem.smallSize)
        
        imageView.isHidden = progress == 0
        smallImageView.isHidden = progress != 0
        
        
        let name: String
        if item.entry.id == item.context.peerId {
            name = "My Story"
        } else {
            name = item.entry.item.peer._asPeer().compactDisplayTitle
        }
        
        let layout = TextViewLayout.init(.initialize(string: name, color: item.entry.hasUnseen || item.entry.id == item.context.peerId ? theme.colors.text : theme.colors.grayText, font: .normal(10)), maximumNumberOfLines: 1, truncationType: .middle)
        layout.measure(width: item.itemWidth - 4)
        textView.update(layout)
        
        self.backgroundView.backgroundColor = theme.colors.background
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate

        self.updateLayout(size: frame.size, transition: transition)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    private var progress: CGFloat = 1.0
    
    func set(progress: CGFloat, transition: ContainedViewLayoutTransition) {
        self.progress = progress
        self.updateLayout(size: self.frame.size, transition: transition)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        let stateSize = NSMakeSize(size.width - 6 , size.width - 6)
        
        let imageSize = NSMakeSize(size.width - 6 + (1 - progress) * 1, size.width - 6 + (1 - progress) * 1)
        
        let imageRect = CGRect(origin: CGPoint(x: (size.width - imageSize.width) / 2, y: 3 - (1 - progress) * 0.5), size: imageSize)
        
        transition.updateFrame(view: imageView, frame: imageRect)
        transition.updateFrame(view: smallImageView, frame: imageRect)

        transition.updateFrame(view: backgroundView, frame: imageRect.insetBy(dx: -1.5, dy: -1.5))

        

        backgroundView.layer?.cornerRadius = backgroundView.frame.height / 2
        if transition.isAnimated {
            backgroundView.layer?.animateCornerRadius(duration: transition.duration, timingFunction: transition.timingFunction)
        }

        
        imageView.layer?.cornerRadius = imageView.frame.height / 2
        if transition.isAnimated {
            imageView.layer?.animateCornerRadius(duration: transition.duration, timingFunction: transition.timingFunction)
        }
        
        transition.updateTransformScale(layer: textView.layer!, scale: progress)
        transition.updateFrame(view: textView, frame: textView.centerFrameX(y: imageView.frame.maxY + 3 + (4.0 * progress), addition: (textView.frame.width * (1 - progress)) / 2))
        transition.updateAlpha(view: textView, alpha: progress)
        
    }
    
}




