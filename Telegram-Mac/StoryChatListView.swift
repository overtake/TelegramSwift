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

private func interpolateArray(from minValue: Double, to maxValue: Double, count: Int) -> [Double] {
    var result: [Double] = []
    
    for i in 0..<count {
        let t = Double(i) / Double(count - 1)
        let interpolatedValue = (1 - t) * maxValue + t * minValue
        result.append(interpolatedValue)
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
        case progress(CGFloat, From)
        
        var height: CGFloat {
            switch self {
            case .revealed:
                return 86
            case .concealed:
                return 30
            case let .progress(progress, _):
                return 30 + 56 * progress
            }
        }
        var progress: CGFloat {
            switch self {
            case .revealed:
                return 1.0
            case .concealed:
                return 0.0
            case let .progress(progress, _):
                return progress
            }
        }
        
        static var small: CGFloat {
            return 30
        }
        static var full: CGFloat {
            return 86
        }
    }
    
    private let _stableId: AnyHashable
    let context: AccountContext
    let state: EngineStorySubscriptions
    let open: (StoryInitialIndex?, Bool)->Void
    let archive: Bool
    let getInterfaceState: ()->InterfaceState
    let reveal: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, archive: Bool, state: EngineStorySubscriptions, open:@escaping(StoryInitialIndex?, Bool)->Void, getInterfaceState: @escaping()->InterfaceState = { return .revealed }, reveal: @escaping()->Void) {
        self._stableId = stableId
        self.context = context
        self.state = state
        self.archive = archive
        self.open = open
        self.reveal = reveal
        self.getInterfaceState = getInterfaceState
        super.init(initialSize)
    }
    
    
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return getInterfaceState().height
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
    private let scrollView = HorizontalScrollView(frame: .zero)
    private var shortTextView: TextView?
    private var progress: CGFloat = 1.0

    private var item: StoryListChatListRowItem?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        scrollView.documentView = documentView
        addSubview(scrollView)
        
        
        scrollView.background = .clear
        self.scaleOnClick = true
        
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
        let visibleRange = self.visibleRange
        
        let itemSize = NSMakeSize(22 + (item.itemWidth - 22) * progress, 22 + (item.itemHeight - 22) * progress)
        
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
    
    private func getTextAlpha() -> CGFloat {
        return 1.0 - self.progress
    }
    private func getTextRect() -> CGRect {
        var edgeView: NSView?
        if !views.isEmpty {
            edgeView = views[focusRange.max - 1]
        } else {
            edgeView = nil
        }
        if let edgeView = edgeView, let shortTextView = shortTextView {
            return CGRect(origin: NSMakePoint(edgeView.frame.maxX + 12.0, floorToScreenPixels(backingScaleFactor, (frame.height - shortTextView.frame.height) / 2)), size: shortTextView.frame.size)
        } else {
            return .zero
        }
    }
    private func getTextScale() -> CGFloat {
        return 1.0 - self.progress
    }
    
    
    func set(transition: TableUpdateTransition, item: StoryListChatListRowItem, context: AccountContext, progress: CGFloat, animated: Bool) {
        
        self.progress = progress
        self.item = item
        
        if !transition.isEmpty {
            var toRemove:[AnyHashable : ItemView] = [:]
            
            for deleted in transition.deleted.reversed() {
                let view = views.remove(at: deleted)
                if let item = view.item {
                    toRemove[item.stableId] = view
                } else {
                    performSubviewRemoval(view, animated: animated, scale: true)
                }
            }
            for inserted in transition.inserted {
                let item = inserted.1 as! StoryListEntryRowItem
                
                let view: ItemView
                let isNew: Bool
                if let v = toRemove[item.stableId] {
                    views.insert(v, at: inserted.0)
                    toRemove.removeValue(forKey: item.stableId)
                    view = v
                    isNew = false
                } else {
                    let rect = getFrame(item, index: inserted.0, progress: progress)
                    view = ItemView(frame: rect)
                    views.insert(view, at: inserted.0)
                    view.layer?.opacity = Float(getAlpha(item, index: inserted.0, progress: progress))
                    isNew = true
                }
                
                view.set(item: item, open: { [weak self] item in
                    self?.open(item)
                }, progress: progress, animated: false)
                
                if inserted.0 == 0 {
                    documentView.addSubview(view, positioned: .below, relativeTo: views.first)
                } else {
                    documentView.addSubview(view, positioned: .above, relativeTo: views[inserted.0 - 1])
                }
                if animated, isNew {
                    view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    view.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            for updated in transition.updated {
                views[updated.0].set(item: updated.1, open: { [weak self] item in
                    self?.open(item)
                }, progress: progress, animated: animated)
            }
            
            for (_, view) in toRemove {
                performSubviewRemoval(view, animated: animated, scale: true)
            }
            toRemove.removeAll()
        }
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate

        if progress == 1.0 {
            if let shortTextView = self.shortTextView {
                performSubviewRemoval(shortTextView, animated: animated)
                self.shortTextView = nil
            }
        } else {
            if animated, scrollView.documentOffset != .zero {
                let to = CGRect.init(origin: .zero, size: scrollView.clipView.bounds.size)
                scrollView.clipView.layer?.animateBounds(from: scrollView.clipView.bounds, to: to, duration: 0.2, timingFunction: .easeOut)
            }
//            scrollView.clipView.scroll(to: NSMakePoint(scrollView.documentOffset.x * progress, 0), animated: animated)
            
            let shortTextView: TextView
            let isNew: Bool
            if let view = self.shortTextView {
                shortTextView = view
                isNew = false
            } else {
                shortTextView = TextView()
                shortTextView.userInteractionEnabled = false
                shortTextView.isSelectable = false
                addSubview(shortTextView, positioned: .below, relativeTo: self.scrollView)
                self.shortTextView = shortTextView
                isNew = true
            }
            let text = "Show Stories"
            
            let color: NSColor?
            let string: String?
            if let attr = shortTextView.textLayout?.attributedString, !attr.string.isEmpty {
                color = attr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
                string = attr.string
            } else {
                string = nil
                color = nil
            }
            let newColor = theme.colors.text
            if string != text || color != newColor {
                let layout = TextViewLayout(.initialize(string: text, color: newColor, font: .medium(.text)))
                layout.measure(width: frame.width - 80)
                shortTextView.update(layout)
            }
            if isNew {
                shortTextView.frame = getTextRect()
                shortTextView.layer?.opacity = Float(getTextAlpha())
                shortTextView.layer?.transform = CATransform3DMakeScale(getTextScale(), getTextScale(), 1.0)
            }
        }
        
        self.updateLayout(size: frame.size, transition: transition)
        
        for (i, view) in views.enumerated() {
            if focusRange.contains(i) {
                view.layer?.zPosition = 1000.0 - CGFloat(i)
            } else {
                view.layer?.zPosition = CGFloat(views.count - i)
            }
            view.userInteractionEnabled = progress == 1.0
        }
        self.userInteractionEnabled = progress != 1.0
    }
    
    var focusRange: NSRange {
        if let itemView = views.first, itemView.item?.peerId == item?.context.peerId {
            if views.count > 3 {
                return NSMakeRange(1, 3)
            } else {
                return NSMakeRange(0, min(3, views.count))
            }
        } else {
            return NSMakeRange(0, min(3, views.count))
        }
    }
    
    var visibleRange: NSRange {
        return NSMakeRange(0, Int(ceil(scrollView.documentOffset.x + frame.width / 70)))
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
                self.scroll(index: i, animated: animated, toVisible: true)
                return view.imageView
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
        
        scrollView.contentView._change(size: CGSize(width: scrollView.contentView.bounds.width, height: size.height), animated: transition.isAnimated, duration: transition.duration, timingFunction: transition.timingFunction)
        

        transition.updateFrame(view: scrollView, frame: size.bounds)
        
        for (i, view) in views.enumerated() {
            if let item = view.item {
                transition.updateFrame(view: view, frame: getFrame(item, index: i, progress: progress))
                transition.updateAlpha(view: view, alpha: getAlpha(item, index: i, progress: progress))
                view.set(progress: progress, transition: transition)
            }
        }
        
        if let shortTextView = shortTextView {
            transition.updateTransformScale(layer: shortTextView.layer!, scale: getTextAlpha())
            transition.updateFrame(view: shortTextView, frame: getTextRect())
            transition.updateAlpha(view: shortTextView, alpha: getTextAlpha())
        }
    }
}

private final class StoryListChatListRowView: TableRowView {
        
    private let interfaceView: StoryListContainer
    private let borderView = View()
    
    private var listener: TableScrollListener!
    
    required init(frame frameRect: NSRect) {
        self.interfaceView = StoryListContainer(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(interfaceView)
        addSubview(borderView)
        
        self.listener = .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] _ in
            self?.updateOverscroll()
        })
        

        interfaceView.loadMore = { [weak self] direction in
            switch direction {
            case .bottom:
                if let item = self?.item as? StoryListChatListRowItem {
                    if let _ = item.state.hasMoreToken {
                        if !item.archive {
                            item.context.account.filteredStorySubscriptionsContext?.loadMore()
                        } else {
                            item.context.account.allStorySubscriptionsContext?.loadMore()
                        }
                    }
                }
            default:
                break
            }
        }
    }
    
    private func updateOverscroll() {
        guard let item = self.item as? StoryListChatListRowItem, let table = item.table else {
            return
        }
        let state = item.getInterfaceState()
        let value = table.documentOffset.y
        switch state {
        case .revealed:
            let progress: CGFloat
            if value < 0 {
                let dest: CGFloat = 700
                let unit = log(dest)
                let current = log(abs(value))
                
                let result = current / unit * value
                
                progress = (item.height + min(abs(result), 9.0)) / item.height
            } else {
                progress = 1.0
            }
            interfaceView.scaleItems(scale: progress, animated: false)
        default:
            break
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
        let isArchive = item.archive
        if let item = item.state.accountItem, item.storyCount > 0 {
            entries.append(.init(item: item, index: index, appearance: appAppearance))
            index += 1
        }
        
        for item in item.state.items {
            if item.storyCount > 0 {
                if !isArchive {
                    if item.peer._asPeer().storyArchived {
                        continue
                    }
                }
                entries.append(.init(item: item, index: index, appearance: appAppearance))
                index += 1
            }
        }
        

        
        let previous = self.interfaceState
        let interfaceState = item.getInterfaceState()
        self.interfaceState = interfaceState
                
        borderView.backgroundColor = .clear//theme.colors.border
        


        let initialSize = NSMakeSize(item.height, item.height)
        let context = item.context
        let archive = item.archive

        let (deleted, inserted, updated) = proccessEntriesWithoutReverse(self.current, right: entries, { entry in
            return StoryListEntryRowItem(initialSize, entry: entry, context: context, archive: archive, open: item.open)
        })
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated: animated, grouping: false, animateVisibleOnly: false)

        CATransaction.begin()

        self.interfaceView.set(transition: transition, item: item, context: item.context, progress: interfaceState.progress, animated: animated)
        self.updateOverscroll()

        CATransaction.commit()

        self.current = entries
        
        if interfaceView.unitDocumentSize.width < interfaceView.frame.width * 4 {
            if let _ = item.state.hasMoreToken {
                if !archive {
                    item.context.account.filteredStorySubscriptionsContext?.loadMore()
                } else {
                    item.context.account.allStorySubscriptionsContext?.loadMore()
                }
            }
        }
        
        if let table = item.table {
            table.addScroll(listener: self.listener)
        }
    }
    
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        transition.updateFrame(view: interfaceView, frame: size.bounds)
        interfaceView.updateLayout(size: size, transition: transition)
        transition.updateFrame(view: borderView, frame: NSMakeRect(0, size.height - .borderSize, size.width, .borderSize))
        interfaceView.updateLayout(size: size, transition: transition)
    }
}

private final class StoryListEntryRowItem : TableRowItem {
    let entry: StoryChatListEntry
    let context: AccountContext
    let archive: Bool
    let open:(StoryInitialIndex?, Bool)->Void
    init(_ initialSize: NSSize, entry: StoryChatListEntry, context: AccountContext, archive: Bool, open: @escaping(StoryInitialIndex?, Bool)->Void) {
        self.entry = entry
        self.context = context
        self.open = open
        self.archive = archive
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
        
        items.append(.init("View Profile", handler: {
            
        }, itemImage: MenuAnimation.menu_open_profile.value))
        
        items.append(.init("Mute", handler: {
            
        }, itemImage: MenuAnimation.menu_mute.value))
        
        if self.entry.item.peer._asPeer().storyArchived {
            items.append(.init("Unarchive", handler: {
                context.engine.peers.updatePeerStoriesHidden(id: peerId, isHidden: false)
            }, itemImage: MenuAnimation.menu_show.value))
            
        } else {
            if !archive {
                items.append(.init("Archive", handler: {
                    context.engine.peers.updatePeerStoriesHidden(id: peerId, isHidden: true)
                }, itemImage: MenuAnimation.menu_hide.value))
            }
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

private final class ItemView : Control {
    fileprivate let imageView = AvatarControl(font: .avatar(15))
    fileprivate let smallImageView = AvatarControl(font: .avatar(7))
    fileprivate let textView = TextView()
    fileprivate let stateView = View()
    fileprivate var item: StoryListEntryRowItem?
    private var open:((StoryListEntryRowItem)->Void)?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.setFrameSize(NSMakeSize(44, 44))
        self.addSubview(textView)
        stateView.isEventLess = true
        smallImageView.userInteractionEnabled = false
        imageView.userInteractionEnabled = false
        self.addSubview(stateView)
        self.addSubview(imageView)
        self.addSubview(smallImageView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
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
        
        imageView.setPeer(account: item.context.account, peer: item.entry.item.peer._asPeer(), size: NSMakeSize(44, 44))
        smallImageView.setPeer(account: item.context.account, peer: item.entry.item.peer._asPeer(), size: NSMakeSize(22, 22))
        
        imageView.isHidden = progress == 0
        smallImageView.isHidden = progress != 0
        
        let name: String
        if item.entry.id == item.context.peerId {
            name = "My Story"
            stateView.isHidden = false
        } else {
            name = item.entry.item.peer._asPeer().compactDisplayTitle
            stateView.isHidden = false
        }
        
        let layout = TextViewLayout.init(.initialize(string: name, color: theme.colors.text, font: .normal(10)), maximumNumberOfLines: 1, truncationType: .middle)
        layout.measure(width: item.height - 4)
        textView.update(layout)
        
        stateView.layer?.borderWidth = item.entry.hasUnseen ? 1.5 : 1.0
        stateView.layer?.borderColor = item.entry.hasUnseen ? theme.colors.accent.cgColor : theme.colors.grayIcon.withAlphaComponent(0.5).cgColor
        stateView.backgroundColor = theme.colors.background
        
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
        let imageSize = NSMakeSize(size.width - 6, size.width - 6)
        
        transition.updateFrame(view: imageView, frame: CGRect(origin: CGPoint(x: (size.width - imageSize.width) / 2, y: 3), size: imageSize))
        transition.updateFrame(view: smallImageView, frame: CGRect(origin: CGPoint(x: (size.width - imageSize.width) / 2, y: 3), size: imageSize))

        transition.updateFrame(view: stateView, frame: imageView.frame.insetBy(dx: -(max(3 * progress, 2)), dy: -(max(3 * progress, 2))))
        
        stateView.layer?.cornerRadius = stateView.frame.height / 2
        if transition.isAnimated {
            stateView.layer?.animateCornerRadius(duration: transition.duration, timingFunction: transition.timingFunction)
        }
        
        imageView.layer?.cornerRadius = imageView.frame.height / 2
        if transition.isAnimated {
            imageView.layer?.animateCornerRadius(duration: transition.duration, timingFunction: transition.timingFunction)
        }
        
        transition.updateTransformScale(layer: textView.layer!, scale: progress)
        transition.updateFrame(view: textView, frame: textView.centerFrameX(y: stateView.frame.maxY + (4.0 * progress), addition: (textView.frame.width * (1 - progress)) / 2))
        transition.updateAlpha(view: textView, alpha: progress)
    }
    
}











/*
 
 private final class StoryListEntryRowView : HorizontalRowView {
     
     private let view = View(frame: NSMakeRect(0, 0, 50, 66))
     private let overlay = Control(frame: NSMakeRect(0, 0, 70, 86))
     private let itemView: ItemView = ItemView(frame: NSMakeRect(0, 0, 50, 66))
     required init(frame frameRect: NSRect) {
         super.init(frame: frameRect)
         
         addSubview(overlay)
         
         view.isEventLess = true
         overlay.addSubview(view)
         view.addSubview(itemView)
         
         overlay.scaleOnClick = true
         
         overlay.set(handler: { [weak self] _ in
             if let item = self?.item as? StoryListEntryRowItem {
                 item.callopenStory()
             }
         }, for: .Click)
     }
     
     override var backdorColor: NSColor {
         return .clear
     }
     
     func takeControl(_ peerId: PeerId) -> NSView? {
         if let tableView = self.item?.table {
             let view = tableView.item(stableId: AnyHashable(peerId))?.view as? StoryListEntryRowView
             return view?.itemView.imageView
         }
         return nil
     }
     
     required init?(coder: NSCoder) {
         fatalError("init(coder:) has not been implemented")
     }
     
     
     override func set(item: TableRowItem, animated: Bool) {
         super.set(item: item, animated: animated)
         
         guard let item = item as? StoryListEntryRowItem else {
             return
         }
         itemView.set(item: item, open: { _ in }, progress: 1.0, animated: animated)
     }
     
     override func layout() {
         super.layout()
         view.centerX(y: 10)
         itemView.center()
     }
     
 }

 */
