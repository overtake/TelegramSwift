//
//  MonoforumVerticalView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.05.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

struct MonoforumItem : Equatable {
    
    enum MediaItem {
        case topic(Int64)
        case avatar(EnginePeer)
        case image(CGImage)
    }
    
    var item: EngineChatList.Item?
    
    init(item: EngineChatList.Item?) {
        self.item = item
    }
    
    var title: String {
        if let item {
            if let threadData = item.threadData {
                return threadData.info.title
            } else {
                return item.renderedPeer.chatMainPeer?._asPeer().displayTitle ?? ""
            }
        } else {
            return strings().chatMonoforumUIAllTab
        }
    }
    
    func mediaItem(selected: Bool) -> MediaItem? {
        if let item {
            if let threadData = item.threadData {
                if let icon = threadData.info.icon {
                    return .topic(icon)
                } else {
                    return .topic(0)
                }
            }
            if let peer = item.renderedPeer.chatMainPeer {
                return .avatar(peer)
            }
        } else {
            return .image(NSImage(resource: .iconSidebarAllChats).precomposed(selected ? theme.colors.accent : theme.colors.grayIcon))
        }
        
        return nil
    }
    
    var id:EngineChatList.Item.Id? {
        return item?.id
    }
    
    var uniqueId: Int64 {
        if let item {
            switch item.id {
            case let .chatList(peerId):
                return peerId.toInt64()
            case let .forum(threadId):
                return threadId
            }
        } else {
            return 0
        }
    }
    
    var pinnedIndex: UInt16? {
        return self.item?.chatListIndex.pinningIndex
    }
    

    var file: TelegramMediaFile {
        return LocalAnimatedSticker.duck_empty.file
    }
}

private enum MonoforumEntry : Comparable, Identifiable {
    
    enum PinnedState : Equatable {
        case first
        case inner
        case last
    }
    
    
    static func < (lhs: MonoforumEntry, rhs: MonoforumEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    case item(item: MonoforumItem, PinnedState?, index: Int, selected: Bool)
    case toggle(index: Int)
    case size(index: Int, stableId: AnyHashable)
    
    var selected: Bool {
        switch self {
        case .item(_, _, _, let selected):
            return selected
        case .toggle:
            return false
        case .size:
            return false
        }
    }
    
    var index: Int {
        switch self {
        case let .item(_, _, index, _):
            return index
        case let .toggle(index):
            return index
        case let .size(index, _):
            return index
        }
    }
    
    var stableId: AnyHashable {
        switch self {
        case let .item(item, _, _, _):
            if let item = item.item {
                return item.id
            } else {
                return -1
            }
        case .toggle:
            return 0
        case let .size(_, stableId):
            return stableId
        }
    }
    
    fileprivate func item(initialSize: NSSize, chatInteraction: ChatInteraction) -> TableRowItem {
        switch self {
        case let .item(item, pinnedState, index, selected):
            return Monoforum_VerticalItem(initialSize, stableId: stableId, item: item, pinnedState: pinnedState, chatInteraction: chatInteraction, selected: selected)
        case .toggle:
            return MonoforumToggleItem(initialSize, stableId: stableId, chatInteraction: chatInteraction)
        case let .size(_, stableId):
            return GeneralRowItem(initialSize, height: 15, stableId: stableId)
        }
    }
}

private final class MonoforumToggleItem : TableRowItem {
    private let chatInteraction:ChatInteraction
    init(_ initialSize: NSSize, stableId: AnyHashable, chatInteraction: ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(initialSize, stableId: stableId)
    }
    
    func action() {
        chatInteraction.toggleMonoforumState()
    }
    
    override func viewClass() -> AnyClass {
        return MonoforumToggleView.self
    }
    
    override var height: CGFloat {
        return 34
    }
}

private final class MonoforumToggleView : TableRowView {
    private let imageView = ImageView()
    private let overlay = Control()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(overlay)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MonoforumToggleItem else {
            return
        }
        
        overlay.setSingle(handler: { [weak item] _ in
            item?.action()
        }, for: .Click)
        
        imageView.image = NSImage(resource: .iconMonoforumToggle).precomposed(theme.colors.accent)
        imageView.sizeToFit()
    }
    
    
    override func layout() {
        super.layout()
        imageView.centerX(y: 0)
        overlay.frame = bounds
    }
}

private final class Monoforum_VerticalItem : TableRowItem {
    fileprivate let nameLayout: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let item: MonoforumItem
    fileprivate let selected: Bool
    fileprivate let chatInteraction: ChatInteraction
    fileprivate let badge: CGImage?
    fileprivate let pinnedState: MonoforumEntry.PinnedState?
    init(_ initialSize: NSSize, stableId: AnyHashable, item: MonoforumItem, pinnedState: MonoforumEntry.PinnedState?, chatInteraction: ChatInteraction, selected: Bool) {
        self.chatInteraction = chatInteraction
        self.pinnedState = pinnedState
        self.nameLayout = .init(.initialize(string: item.title, color: selected ? theme.colors.accent : theme.colors.listGrayText, font: .normal(.text)), maximumNumberOfLines: 2, truncationType: .middle, alignment: .center)
        self.nameLayout.measure(width: 70)
        self.selected = selected
        self.context = chatInteraction.context
        self.item = item
        
        let generateIcon:()->CGImage? = {
            let icon: CGImage?
            if let item = item.item, let unreadCount = item.readCounters?.count, unreadCount > 0 {
                
                
                let unreadCount = Int(unreadCount)
                
                let textColor: NSColor
                textColor = .white

                
                let attributedString = NSAttributedString.initialize(string: "\(unreadCount.prettyNumber)", color: textColor, font: .medium(.short))
                let textLayout = TextNode.layoutText(maybeNode: nil,  attributedString, nil, 1, .start, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .center)
                var size = NSMakeSize(textLayout.0.size.width + 8, textLayout.0.size.height + 5)
                size = NSMakeSize(max(size.height,size.width), size.height)
                let badge = generateImage(size, rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    
                    // Outer background
                    ctx.setFillColor(theme.colors.background.cgColor)
                    let outerPath = CGMutablePath()
                    outerPath.addRoundedRect(in: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2)
                    outerPath.closeSubpath()
                    ctx.addPath(outerPath)
                    ctx.fillPath()
                    
                    // Inner fill
                    let insetRect = rect.insetBy(dx: 1, dy: 1)
                    ctx.setFillColor(item.isMuted ? theme.colors.grayIcon.cgColor : theme.colors.accentIcon.cgColor)
                    let innerPath = CGMutablePath()
                    innerPath.addRoundedRect(in: insetRect, cornerWidth: insetRect.height / 2, cornerHeight: insetRect.height / 2)
                    innerPath.closeSubpath()
                    ctx.addPath(innerPath)
                    ctx.fillPath()

                    // Text
                    let focus = rect.focus(textLayout.0.size)
                    textLayout.1.draw(
                        focus.offsetBy(dx: 0, dy: -1),
                        in: ctx,
                        backingScaleFactor: System.backingScale,
                        backgroundColor: .white
                    )
                })!

                icon = badge
            } else if pinnedState != nil || item.item?.threadData?.isClosed == true {
                let pinned = NSImage(resource: .iconMonoforumPin).precomposed(theme.colors.background, flipVertical: true)
                let closed = NSImage(resource: .iconMonoforumLock).precomposed(theme.colors.background, flipVertical: true)
                
                var icons: [CGImage] = []
                if pinnedState != nil {
                    icons.append(pinned)
                }
                if item.item?.threadData?.isClosed == true {
                    icons.append(closed)
                }
                
                let spacing: CGFloat = 1
                let paddingHorizontal: CGFloat = 4
                let paddingVertical: CGFloat = 2

                let iconHeight = icons.map { $0.backingSize.height }.max() ?? 0
                let iconWidths = icons.map { $0.backingSize.width }
                let totalWidth = iconWidths.reduce(0, +) + CGFloat(max(0, icons.count - 1)) * spacing

                let badgeSize = NSSize(width: totalWidth + paddingHorizontal * 2,
                                       height: iconHeight + paddingVertical * 2 + 2)

                let badge = generateImage(badgeSize, rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)

                    // Outer background
                    ctx.setFillColor(theme.colors.background.cgColor)
                    let outerPath = CGMutablePath()
                    outerPath.addRoundedRect(in: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2)
                    outerPath.closeSubpath()
                    ctx.addPath(outerPath)
                    ctx.fillPath()

                    // Inner fill
                    let insetRect = rect.insetBy(dx: 1, dy: 1)
                    ctx.setFillColor(theme.colors.badgeMuted.cgColor)
                    let innerPath = CGMutablePath()
                    innerPath.addRoundedRect(in: insetRect, cornerWidth: insetRect.height / 2, cornerHeight: insetRect.height / 2)
                    innerPath.closeSubpath()
                    ctx.addPath(innerPath)
                    ctx.fillPath()

                    // Draw icons
                    var x = paddingHorizontal
                    for (index, icon) in icons.enumerated() {
                        let y = (size.height - icon.backingSize.height) / 2
                        ctx.draw(icon, in: NSRect(x: x, y: y, width: icon.backingSize.width, height: icon.backingSize.height))
                        x += icon.backingSize.width
                        if index < icons.count - 1 {
                            x += spacing
                        }
                    }
                })!

                icon = badge
            } else {
                icon = nil
            }
            return icon
        }
        self.badge = generateIcon()
        
        super.init(initialSize, stableId: stableId)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return chatInteraction.monoforumMenuItems(self.item)
    }
    
    func select() {
        chatInteraction.updateChatLocationThread(self.item.uniqueId == 0 ? nil : self.item.uniqueId)
    }
    
    override var height: CGFloat {
        return 14 + 30 + nameLayout.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return Monoforum_VerticalView.self
    }
}

private final class Monoforum_VerticalView : TableRowView {
    private let textView = TextView()
    private var animatedView: InlineStickerView?
    private var imageView: ImageView?
    private var photoView: AvatarControl?
//    private let control = Control()
    private let badgeView = ImageView()
    private var pinnedView: SimpleShapeLayer?
    
    private var pinnedIcon: ImageView?
    private var closedView: ImageView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(badgeView)

        badgeView.isEventLess = true
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Monoforum_VerticalItem else {
            return
        }
        
        badgeView.image = item.badge
        badgeView.sizeToFit()
        

//
//        if let pinnedState = item.pinnedState {
//            let current: SimpleShapeLayer
//            if let view = self.pinnedView {
//                current = view
//            } else {
//                current = SimpleShapeLayer(frame: bounds)
//                self.layer?.addSublayer(current)
//                self.pinnedView = current
//            }
//            
//            
//            let path = CGMutablePath()
//            let cornerRadius: CGFloat = 4
//            let insetBounds = bounds.insetBy(dx: 4, dy: 0)
//
//            switch pinnedState {
//            case .last:
//                path.addRoundedRect(in: insetBounds, topLeft: true, topRight: true, bottomLeft: false, bottomRight: false, radius: cornerRadius)
//            case .inner:
//                path.addRect(insetBounds)
//            case .first:
//                path.addRoundedRect(in: insetBounds, topLeft: false, topRight: false, bottomLeft: true, bottomRight: true, radius: cornerRadius)
//            }
//
//            current.path = path
//            current.fillColor = theme.colors.grayIcon.withAlphaComponent(0.1).cgColor
//            current.frame = bounds
//
//        } else if let pinnedView {
//            performSublayerRemoval(pinnedView, animated: animated)
//            self.pinnedView = nil
//        }

        
        self.textView.update(item.nameLayout)
        
        if let mediaItem = item.item.mediaItem(selected: item.selected) {
            switch mediaItem {
            case let .topic(fileId):
                if let photoView {
                    performSubviewRemoval(photoView, animated: animated)
                    self.photoView = nil
                }
                if let imageView {
                    performSubviewRemoval(imageView, animated: animated)
                    self.imageView = nil
                }
                
                if let view = self.animatedView, view.animateLayer.fileId == fileId || view.animateLayer.fileId == item.item.uniqueId {
                } else {
                    if let animatedView {
                        performSubviewRemoval(animatedView, animated: animated)
                        self.animatedView = nil
                    }
                    
                    let file: TelegramMediaFile?
                    if fileId == 0, let data = item.item.item?.threadData?.info {
                        file = ForumUI.makeIconFile(title: data.title, iconColor: data.iconColor, isGeneral: item.item.uniqueId == 1)
                    } else {
                        file = nil
                    }
                    
                    let animatedView = InlineStickerView(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: fileId == 0 ? item.item.uniqueId : fileId, file: file, emoji: ""), size: NSMakeSize(30, 30), playPolicy: .framesCount(1))
                    self.animatedView = animatedView
                    self.addSubview(animatedView, positioned: .below, relativeTo: self)
                }
            case let .avatar(peer):
                if let animatedView {
                    performSubviewRemoval(animatedView, animated: animated)
                    self.animatedView = nil
                }
                if let imageView {
                    performSubviewRemoval(imageView, animated: animated)
                    self.imageView = nil
                }
                
                let current: AvatarControl
                if let view = self.photoView {
                    current = view
                } else {
                    current = AvatarControl(font: .avatar(13))
                    current.userInteractionEnabled = false
                    current.setFrameSize(NSMakeSize(30, 30))
                    self.addSubview(current, positioned: .below, relativeTo: self)
                    self.photoView = current
                }
                current.setPeer(account: item.context.account, peer: peer._asPeer())
            case let .image(image):
                if let animatedView {
                    performSubviewRemoval(animatedView, animated: animated)
                    self.animatedView = nil
                }
                if let photoView {
                    performSubviewRemoval(photoView, animated: animated)
                    self.photoView = nil
                }
                
                let current: ImageView
                if let view = self.imageView {
                    current = view
                } else {
                    current = ImageView()
                    self.addSubview(current, positioned: .below, relativeTo: self)
                    self.imageView = current
                }
                current.image = image
                current.sizeToFit()
            }
        } else {
            if let animatedView {
                performSubviewRemoval(animatedView, animated: animated)
                self.animatedView = nil
            }
            if let photoView {
                performSubviewRemoval(photoView, animated: animated)
                self.photoView = nil
            }
            if let imageView {
                performSubviewRemoval(imageView, animated: animated)
                self.imageView = nil
            }
        }
        
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        self.animatedView?.centerX(y: 3)
        self.photoView?.centerX(y: 3)
        self.imageView?.centerX(y: 3)
        
        let imageView = self.photoView ?? self.imageView ?? self.animatedView
        
        self.textView.centerX(y: frame.height - self.textView.frame.height - 4)
        
        if let imageView {
            badgeView.setFrameOrigin(NSMakePoint(imageView.frame.maxX - floorToScreenPixels(badgeView.frame.width / 2) - 4, 3))
        }
    }
}

class MonoforumVerticalView : View, TableViewDelegate {
    
    
    private var ignoreNextSelectAction: Bool = false
    
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        if let item = item as? Monoforum_VerticalItem {
            if !ignoreNextSelectAction {
                item.select()
            }
        }
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return item is Monoforum_VerticalItem
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return item is Monoforum_VerticalItem
    }
    
    private let tableView: TableView = TableView(frame: .zero)
    
    private var entries: [MonoforumEntry] = []
    
    private let selectionView: View = View()
    private let separator = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        
        addSubview(selectionView)
        addSubview(separator)
        
        selectionView.layer?.cornerRadius = .cornerRadius
        
        updateLocalizationAndTheme(theme: theme)
        
        tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] scroll in
            self?.updateSelectionRect()
        }))
                
        
        tableView.delegate = self
        
        self.layout()
    }
    
    private func updateSelectionRect(animated: Bool = false) {
        
        guard let selected = entries.first(where: { $0.selected }) else {
            return
        }
        guard let item = self.tableView.item(stableId: selected.stableId) else {
            return
        }
        guard tableView.contentView.bounds != .zero else {
            return
        }
        
        let scroll = self.tableView.scrollPosition().current
        let scrollY = scroll.rect.minY - tableView.frame.height
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        let rect = tableView.rectOf(item: item)
        
        transition.updateFrame(view: self.selectionView, frame:  NSMakeRect(-4, tableView.frame.minY + rect.origin.y + 5 - scrollY, 8, rect.height - 5))
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        self.backgroundColor = theme.colors.background
        self.selectionView.backgroundColor = theme.colors.accent
        self.separator.backgroundColor = theme.colors.border

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(items: [MonoforumItem], selected: Int64?, chatInteraction: ChatInteraction, animated: Bool) {
        
        let context = chatInteraction.context
        
        let isMonoforum = items.first(where: { $0.item?.threadData != nil }) == nil
        
        var entries: [MonoforumEntry] = []
        
        var index: Int = 0
        
//        entries.append(.size(index: index, stableId: InputDataIdentifier("h1")))
//        index += 1
//        
//        entries.append(.toggle(index: index))
//        index += 1

        entries.append(.item(item: .init(item: nil), nil, index: 0, selected: selected == nil))
        index += 1

        var pinnedState: MonoforumEntry.PinnedState?
        for (i, item) in items.enumerated() {
            
            let next = i < items.count - 1 ? items[i + 1] : nil
            
            if item.pinnedIndex != nil {
                if pinnedState == nil {
                    pinnedState = .first
                } else if pinnedState != nil, next?.pinnedIndex != nil {
                    pinnedState = .inner
                } else if pinnedState != nil, next?.pinnedIndex == nil {
                    pinnedState = .last
                } else {
                    pinnedState = nil
                }
            } else {
                pinnedState = nil
            }
            
            entries.append(.item(item: item, pinnedState, index: index, selected: item.uniqueId == selected))
            index += 1
        }
        
        entries.append(.size(index: index, stableId: InputDataIdentifier("h2")))
        index += 1

        
        let (deleteIndices, indicesAndItems, updateIndices) = proccessEntriesWithoutReverse(self.entries, right: entries, { entry in
            return entry.item(initialSize: .zero, chatInteraction: chatInteraction)
        })
        
        let transition = TableUpdateTransition(deleted: deleteIndices, inserted: indicesAndItems, updated: updateIndices, animated: animated, grouping: true)
        
        tableView.merge(with: transition, appearAnimated: false)
        
        
        var sortRange: NSRange = NSMakeRange(NSNotFound, 1)
        
        var pinned: [Int64] = []
        var offsetIndex = -1
        
        for (i, item) in entries.enumerated() {
            switch item {
            case let .item(item, _, _, _):
                if let _ = item.pinnedIndex {
                    pinned.append(item.uniqueId)
                    if offsetIndex == -1 {
                        offsetIndex = i
                    }
                    if sortRange.location == NSNotFound {
                        sortRange.location = i
                        
                    } else {
                        sortRange.length += 1
                    }
                }
            default:
                break
            }
        }
        
        
        
        let peerId = chatInteraction.peerId
        
   //     let signal = context.engine.peers.setForumChannelPinnedTopics(id: peerId, threadIds: items) |> deliverOnMainQueue

        
        if sortRange.location != NSNotFound {
            tableView.resortController = .init(resortRange: sortRange, start: { _ in }, resort: { _ in }, complete: { [weak self] fromIndex, toIndex in
                
                pinned.move(at: fromIndex - offsetIndex, to: toIndex - offsetIndex)
                var items = items
                items.move(at: fromIndex - offsetIndex, to: toIndex - offsetIndex)
                
                _ = context.engine.peers.setForumChannelPinnedTopics(id: peerId, threadIds: pinned).start()
                self?.updateSelectionRect(animated: true)
                self?.set(items: items, selected: selected, chatInteraction: chatInteraction, animated: false)
            })
        } else {
            tableView.resortController = nil
        }
        if let item = entries.first(where: { $0.selected }) {
            if let item = tableView.item(stableId: item.stableId), !item.isSelected {
                self.ignoreNextSelectAction = true
                _ = tableView.select(item: item)
                self.ignoreNextSelectAction = false
            }
        }
        
        self.entries = entries
        
        self.updateSelectionRect(animated: animated)
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updateSelectionRect()
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let rect = NSMakeRect(0, 40, size.width, size.height - 40)
        self.tableView.frame = rect
        self.tableView.tile()
        transition.updateFrame(view: self.separator, frame: NSMakeRect(rect.width - .borderSize, 0, .borderSize, size.height))
        self.updateSelectionRect(animated: transition.isAnimated)

    }
}
