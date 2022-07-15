//
//  EmojiesSectionRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 30.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import AppKit
import SwiftSignalKit
import Postbox

final class EmojiesSectionRowItem : GeneralRowItem {
    
    struct Item : Equatable {
        let rect: NSRect
        let item: StickerPackItem
    }
    
    let items: [Item]
    let context: AccountContext
    let callback:(StickerPackItem)->Void
    let itemSize: NSSize
    let info: StickerPackCollectionInfo?
    let viewSet: ((StickerPackCollectionInfo)->Void)?
    
    let nameLayout: TextViewLayout?
    let isPremium: Bool
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, info: StickerPackCollectionInfo?, items: [StickerPackItem], callback:@escaping(StickerPackItem)->Void, viewSet:((StickerPackCollectionInfo)->Void)? = nil) {
        self.itemSize = NSMakeSize(41, 34)
        self.info = info
        self.viewSet = viewSet
        self.isPremium = items.contains(where: { $0.file.isPremiumEmoji }) && stableId != AnyHashable(0)
        var mapped: [Item] = []
        var point = NSMakePoint(10, 0)
        for item in items {
            mapped.append(.init(rect: CGRect(origin: point, size: itemSize).insetBy(dx: 2, dy: 2), item: item))
            point.x += itemSize.width
            if mapped.count % 8 == 0 {
                point.y += itemSize.height
                point.x = 10
            }
        }
        self.items = mapped
        self.context = context
        self.callback = callback
        
        if stableId != AnyHashable(0), let info = info {
            let layout = TextViewLayout(.initialize(string: info.title.uppercased(), color: theme.colors.grayText, font: .normal(12)), alwaysStaticItems: true)
            layout.measure(width: 300)
            self.nameLayout = layout
        } else {
            self.nameLayout = nil
        }
        
        
        
        super.init(initialSize, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return EmojiesSectionRowView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
                
        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        
        if let nameLayout = nameLayout {
            height += nameLayout.layoutSize.height + 5
        }
        
        height += self.itemSize.height * CGFloat(ceil(CGFloat(items.count) / 8.0))
        
        if let _ = nameLayout {
            height += 5
        }
        return height
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items: [ContextMenuItem] = []
        
        let info = self.info
//        let context = self.context
        
        if stableId == AnyHashable(0) || self.viewSet == nil {
            return super.menuItems(in: location)
        }
        
        if let info = info {
            items.append(ContextMenuItem(strings().contextViewEmojiSet, handler: { [weak self] in
                self?.viewSet?(info)
            }, itemImage: MenuAnimation.menu_view_sticker_set.value))
        }
       
        
        
//        items.append(ContextMenuItem(strings().emojiContextRemove, handler: {
//            _ = context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .delete).start()
//        }, itemImage: MenuAnimation.menu_delete.value))
//
        return .single(items)
    }
}



private final class EmojiesSectionRowView : TableRowView {
    
    private var inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]

    private let contentView = Control()
    
    private let shapeLayer = SimpleShapeLayer()
    private var nameView: TextView?
    
    private var lockView: ImageView?
    private let container = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        addSubview(contentView)
        
        
        self.layer?.addSublayer(shapeLayer)

        contentView.set(handler: { [weak self] _ in
            self?.updateDown()
        }, for: .Down)
        
        contentView.set(handler: { [weak self] _ in
            self?.updateDragging()
        }, for: .MouseDragging)
        
        contentView.set(handler: { [weak self] _ in
            self?.updateUp()
        }, for: .Up)
        
       
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    private var currentDownItem: (InlineStickerItemLayer, EmojiesSectionRowItem.Item, Bool)?
    private func updateDown() {
        if let item = itemUnderMouse {
            self.currentDownItem = (item.0, item.1, true)
        }
        if let itemUnderMouse = self.currentDownItem {
            itemUnderMouse.0.animateScale(from: 1, to: 0.85, duration: 0.2, removeOnCompletion: false)
        }
    }
    private func updateDragging() {
        if let current = self.currentDownItem {
            if self.itemUnderMouse?.1 != current.1, current.2  {
                current.0.animateScale(from: 0.85, to: 1, duration: 0.2, removeOnCompletion: true)
                self.currentDownItem?.2 = false
            } else if !current.2, self.itemUnderMouse?.1 == current.1 {
                current.0.animateScale(from: 1, to: 0.85, duration: 0.2, removeOnCompletion: false)
                self.currentDownItem?.2 = true
            }
        }
            
    }
    private func updateUp() {
        if let itemUnderMouse = self.currentDownItem {
            itemUnderMouse.0.animateScale(from: 0.85, to: 1, duration: 0.2, removeOnCompletion: true)
            if itemUnderMouse.1 == self.itemUnderMouse?.1 {
                self.click()
            }
        }
        self.currentDownItem = nil
    }
    
    override func layout() {
        super.layout()
        
        
        var containerSize = NSZeroSize
        if let nameView = self.nameView {
            containerSize = NSMakeSize(nameView.frame.width, nameView.frame.height)
        }
        if let lockView = lockView, let nameView = nameView {
            containerSize.width += lockView.frame.width
            containerSize.height = max(nameView.frame.height, lockView.frame.height)
        }
        container.setFrameSize(containerSize)
        
        if let lockView = lockView {
            lockView.centerY(x: 0)
            nameView?.centerY(x: lockView.frame.maxX)
        } else {
            nameView?.center()
        }
        
        
        container.centerX(y: 0)
        
        var contentRect = bounds
        if let nameView = nameView {
            contentRect = contentRect.offsetBy(dx: 0, dy: nameView.frame.height + 5)
        }
        contentView.frame = contentRect
        
        let groupBorderFrame = NSMakeRect(10, 8, bounds.width - 20, bounds.height - 2 - 8)

        
        shapeLayer.frame = groupBorderFrame
        
        
        let radius: CGFloat = 10
        
        let headerWidth: CGFloat = container.frame.width + 10
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: floor((groupBorderFrame.width - headerWidth) / 2.0), y: 0.0))
        path.addLine(to: CGPoint(x: radius, y: 0.0))
        path.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: 0.0, y: radius), radius: radius)
        path.addLine(to: CGPoint(x: 0.0, y: groupBorderFrame.height - radius))
        path.addArc(tangent1End: CGPoint(x: 0.0, y: groupBorderFrame.height), tangent2End: CGPoint(x: radius, y: groupBorderFrame.height), radius: radius)
        path.addLine(to: CGPoint(x: groupBorderFrame.width - radius, y: groupBorderFrame.height))
        path.addArc(tangent1End: CGPoint(x: groupBorderFrame.width, y: groupBorderFrame.height), tangent2End: CGPoint(x: groupBorderFrame.width, y: groupBorderFrame.height - radius), radius: radius)
        path.addLine(to: CGPoint(x: groupBorderFrame.width, y: radius))
        path.addArc(tangent1End: CGPoint(x: groupBorderFrame.width, y: 0.0), tangent2End: CGPoint(x: groupBorderFrame.width - radius, y: 0.0), radius: radius)
        path.addLine(to: CGPoint(x: floor((groupBorderFrame.width - headerWidth) / 2.0) + headerWidth, y: 0.0))
        
        let pathLength = (2.0 * groupBorderFrame.width + 2.0 * groupBorderFrame.height - 8.0 * radius + 2.0 * .pi * radius) - headerWidth
        
        var numberOfDashes = Int(floor(pathLength / 6.0))
        if numberOfDashes % 2 == 0 {
            numberOfDashes -= 1
        }
        let wholeLength = 6.0 * CGFloat(numberOfDashes)
        let remainingLength = pathLength - wholeLength
        let dashSpace = remainingLength / CGFloat(numberOfDashes)
                               
        shapeLayer.path = path
        shapeLayer.lineDashPattern = [(5.0 + dashSpace) as NSNumber, (7.0 + dashSpace) as NSNumber]


    }
    
    private var itemUnderMouse: (InlineStickerItemLayer, EmojiesSectionRowItem.Item)? {
        guard let window = self.window, let item = self.item as? EmojiesSectionRowItem else {
            return nil
        }
        let point = self.contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        let firstItem = item.items.first(where: {
            return NSPointInRect(point, $0.rect)
        })
        let firstLayer = self.inlineStickerItemViews.first(where: { layer in
            return NSPointInRect(point, layer.1.frame)
        })?.value
        
        if let firstItem = firstItem, let firstLayer = firstLayer {
            return (firstLayer, firstItem)
        }
        
        return nil
    }
    
    private func click() {
        
        guard let item = self.item as? EmojiesSectionRowItem else {
            return
        }
        if let first = currentDownItem {
            item.callback(first.1.item)
        }
    }

    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? EmojiesSectionRowItem else {
            return
        }
        
        shapeLayer.strokeColor = theme.colors.grayIcon.withAlphaComponent(0.7).cgColor
        shapeLayer.lineWidth = 1
        shapeLayer.lineCap = .round
        shapeLayer.fillColor = nil
        
        shapeLayer.opacity = !item.context.isPremium && item.isPremium ? 1 : 0
        
        if !item.context.isPremium && item.isPremium {
            let current: ImageView
            if let view = self.lockView {
                current = view
            } else {
                current = ImageView()
                self.lockView = current
                container.addSubview(current)
            }
            current.image = theme.icons.premium_emoji_lock
            current.sizeToFit()
        } else if let view = self.lockView {
            performSubviewRemoval(view, animated: animated)
            self.lockView = nil
        }
        
        if let layout = item.nameLayout {
            let current: TextView
            if let view = self.nameView {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.nameView = current
                container.addSubview(current)
            }
            current.update(layout)
        } else if let view = self.nameView {
            performSubviewRemoval(view, animated: animated)
            self.nameView = nil
        }
        
        
        self.layout()

        self.updateInlineStickers(context: item.context, contentView: contentView, items: item.items)
        
        self.updateListeners()
        
    }
    
    
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.updateListeners()
        self.updateAnimatableContent()
    }
    
    private func updateListeners() {
        let center = NotificationCenter.default
        if let window = window {
            center.removeObserver(self)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didResignKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
        } else {
            center.removeObserver(self)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func updateAnimatableContent() -> Void {
        for (_, value) in inlineStickerItemViews {
            if let superview = value.superview {
                value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && window != nil && window!.isKeyWindow
            }
        }
    }
    
    func updateInlineStickers(context: AccountContext, contentView: NSView, items: [EmojiesSectionRowItem.Item]) {
        var validIds: [InlineStickerItemLayer.Key] = []
        var index: Int = 0

        for item in items {
            let id = InlineStickerItemLayer.Key(id: item.item.file.fileId.id, index: index)
            validIds.append(id)

            let rect = item.rect

            let view: InlineStickerItemLayer
            if let current = self.inlineStickerItemViews[id], current.frame.size == rect.size {
                view = current
            } else {
                self.inlineStickerItemViews[id]?.removeFromSuperlayer()
                view = InlineStickerItemLayer(context: context, file: item.item.file, size: rect.size)
                self.inlineStickerItemViews[id] = view
                view.superview = contentView
                contentView.layer?.addSublayer(view)
            }
            index += 1

            view.isPlayable = NSIntersectsRect(rect, contentView.visibleRect) && window != nil && window!.isKeyWindow
            view.frame = rect
        }

        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, itemLayer) in self.inlineStickerItemViews {
            if !validIds.contains(key) {
                removeKeys.append(key)
                itemLayer.removeFromSuperlayer()
            }
        }
        for key in removeKeys {
            self.inlineStickerItemViews.removeValue(forKey: key)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
