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
    
    var title: String {
        if let item {
            return item.messages.first?.author?._asPeer().displayTitle ?? ""
        } else {
            //TODOLANG
            return "All"
        }
    }
    
    func mediaItem(selected: Bool) -> MediaItem? {
        if let item {
            if let threadData = item.threadData {
                if let icon = threadData.info.icon {
                    return .topic(icon)
                }
            }
            if let peer = item.messages.first?.author {
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
            case let .forum(id):
                return id
            default:
                return 0
            }
        } else {
            return 0
        }
    }
    
    var file: TelegramMediaFile {
        return LocalAnimatedSticker.duck_empty.file
    }
}

private enum MonoforumEntry : Comparable, Identifiable {
    static func < (lhs: MonoforumEntry, rhs: MonoforumEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    case item(item: MonoforumItem, index: Int, selected: Bool)
    case toggle(index: Int)
    case size(index: Int, stableId: AnyHashable)
    
    var selected: Bool {
        switch self {
        case .item(_, _, let selected):
            return selected
        case .toggle:
            return false
        case .size:
            return false
        }
    }
    
    var index: Int {
        switch self {
        case let .item(_, index, _):
            return index
        case let .toggle(index):
            return index
        case let .size(index, _):
            return index
        }
    }
    
    var stableId: AnyHashable {
        switch self {
        case let .item(item, _, _):
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
        case let .item(item, index, selected):
            return Monoforum_VerticalItem(initialSize, stableId: stableId, item: item, chatInteraction: chatInteraction, selected: selected)
        case .toggle:
            return MonoforumToggleItem(initialSize, stableId: stableId)
        case let .size(_, stableId):
            return GeneralRowItem(initialSize, height: 15, stableId: stableId)
        }
    }
}

private final class MonoforumToggleItem : TableRowItem {
    override init(_ initialSize: NSSize, stableId: AnyHashable) {
        super.init(initialSize, stableId: stableId)
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
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MonoforumToggleItem else {
            return
        }
        
        imageView.image = NSImage(resource: .iconMonoforumToggle).precomposed(theme.colors.accent)
        imageView.sizeToFit()
    }
    
    
    override func layout() {
        super.layout()
        imageView.centerX(y: 0)
    }
}

private final class Monoforum_VerticalItem : TableRowItem {
    fileprivate let nameLayout: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let item: MonoforumItem
    fileprivate let selected: Bool
    fileprivate let chatInteraction: ChatInteraction
    init(_ initialSize: NSSize, stableId: AnyHashable, item: MonoforumItem, chatInteraction: ChatInteraction, selected: Bool) {
        self.chatInteraction = chatInteraction
        self.nameLayout = .init(.initialize(string: item.title, color: selected ? theme.colors.accent : theme.colors.listGrayText, font: .normal(.text)), truncationType: .middle, alignment: .center)
        self.nameLayout.measure(width: 70)
        self.selected = selected
        self.context = chatInteraction.context
        self.item = item
        super.init(initialSize, stableId: stableId)
    }
    
    
    func select() {
        chatInteraction.updateChatLocationThread(self.item.uniqueId == 0 ? nil : self.item.uniqueId)
    }
    
    override var height: CGFloat {
        return 60
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
    private let control = Control()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(control)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        control.set(handler: { [weak self] _ in
            if let item = self?.item as? Monoforum_VerticalItem {
                item.select()
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Monoforum_VerticalItem else {
            return
        }
        
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
                
                if let view = self.animatedView, view.animateLayer.fileId == fileId {
                } else {
                    if let animatedView {
                        performSubviewRemoval(animatedView, animated: animated)
                        self.animatedView = nil
                    }
                    let animatedView = InlineStickerView(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: NSMakeSize(30, 30))
                    self.animatedView = animatedView
                    self.addSubview(animatedView, positioned: .below, relativeTo: control)
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
                    current.setFrameSize(NSMakeSize(30, 30))
                    self.addSubview(current, positioned: .below, relativeTo: control)
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
                    self.addSubview(current, positioned: .below, relativeTo: control)
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
        
//        self.animatedView.update(with: item.item.file, size: NSMakeSize(30, 30), context: item.context, table: item.table, animated: animated)
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        self.animatedView?.centerX(y: 3)
        self.photoView?.centerX(y: 3)
        self.imageView?.centerX(y: 3)
        self.textView.centerX(y: frame.height - self.textView.frame.height - 4)
        self.control.frame = bounds
    }
}

class MonoforumVerticalView : View {
    private let tableView: TableView = TableView(frame: .zero)
    
    private var entries: [MonoforumEntry] = []
    
    private let selectionView: View = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        
        addSubview(selectionView)
        
        selectionView.layer?.cornerRadius = .cornerRadius
        
        updateLocalizationAndTheme(theme: theme)
        
        tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] scroll in
            self?.updateSelectionRect()
        }))
        
        border = [.Right]

        
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
        
        transition.updateFrame(view: self.selectionView, frame:  NSMakeRect(-4, rect.origin.y + 5 - scrollY, 8, 50))
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        self.backgroundColor = theme.colors.background
        self.selectionView.backgroundColor = theme.colors.accent
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(items: [MonoforumItem], selected: Int64?, chatInteraction: ChatInteraction, animated: Bool) {
        
        var entries: [MonoforumEntry] = []
        
        var index: Int = 0
        
        entries.append(.size(index: index, stableId: InputDataIdentifier("h1")))
        index += 1
        
        entries.append(.toggle(index: index))
        index += 1

        entries.append(.item(item: .init(item: nil), index: 0, selected: selected == nil))
        index += 1
        
        for item in items {
            entries.append(.item(item: item, index: index, selected: item.id == selected.flatMap(EngineChatList.Item.Id.forum)))
            index += 1
        }
        
        entries.append(.size(index: index, stableId: InputDataIdentifier("h2")))
        index += 1

        
        let (deleteIndices, indicesAndItems, updateIndices) = proccessEntriesWithoutReverse(self.entries, right: entries, { entry in
            return entry.item(initialSize: .zero, chatInteraction: chatInteraction)
        })
        
        let transition = TableUpdateTransition(deleted: deleteIndices, inserted: indicesAndItems, updated: updateIndices, animated: animated, grouping: true)
        
        tableView.merge(with: transition, appearAnimated: false)
        
        self.entries = entries
        
        self.updateSelectionRect(animated: animated)
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updateSelectionRect()
    }
    
    override func layout() {
        super.layout()
        self.tableView.frame = bounds
        
        self.updateSelectionRect()
    }
}
