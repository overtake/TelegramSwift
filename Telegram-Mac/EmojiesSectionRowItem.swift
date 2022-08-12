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
    
    enum Item : Equatable {
        case item(rect: NSRect, item: StickerPackItem)
        case more(rect: NSRect, count: Int)
        
        var rect: NSRect {
            switch self {
            case let .item(rect, _):
                return rect
            case let .more(rect, _):
                return rect
            }
        }
        var item: StickerPackItem? {
            switch self {
            case let .item(_, item):
                return item
            default:
                return nil
            }
        }
    }
    
    let items: [Item]
    let stickerItems: [StickerPackItem]
    let context: AccountContext
    let callback:(StickerPackItem)->Void
    let itemSize: NSSize
    let info: StickerPackCollectionInfo?
    let viewSet: ((StickerPackCollectionInfo)->Void)?
    
    let nameLayout: TextViewLayout?
    let isPremium: Bool
    let revealed: Bool
    let showAllItems:(()->Void)?
    
    let installed: Bool
    
    let unlockText: (String, Bool)?
    
    let openPremium:(()->Void)?
    let installPack:((StickerPackCollectionInfo, [StickerPackItem])->Void)?
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, revealed: Bool, installed: Bool, info: StickerPackCollectionInfo?, items: [StickerPackItem], callback:@escaping(StickerPackItem)->Void, viewSet:((StickerPackCollectionInfo)->Void)? = nil, showAllItems:(()->Void)? = nil, openPremium:(()->Void)? = nil, installPack:((StickerPackCollectionInfo, [StickerPackItem])->Void)? = nil) {
        self.itemSize = NSMakeSize(41, 34)
        self.info = info
        self.viewSet = viewSet
        self.installed = installed
        self.revealed = revealed
        self.stickerItems = items
        self.showAllItems = showAllItems
        self.openPremium = openPremium
        self.installPack = installPack
        self.isPremium = items.contains(where: { $0.file.isPremiumEmoji }) && stableId != AnyHashable(0)
        var mapped: [Item] = []
        var point = NSMakePoint(10, 0)
        
        let optimized = (isPremium && !context.isPremium || !installed) && !revealed && items.count > 24 ? Array(items.prefix(23)) : items
        for item in optimized {
            mapped.append(.item(rect: CGRect(origin: point, size: itemSize).insetBy(dx: 2, dy: 2), item: item))
            point.x += itemSize.width
            if mapped.count % 8 == 0 {
                point.y += itemSize.height
                point.x = 10
            }
        }
        
        if optimized.count != items.count {
            mapped.append(.more(rect: CGRect(origin: point, size: itemSize).insetBy(dx: -5, dy: 0), count: items.count - optimized.count))
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
        
        if let _ = info {
            if isPremium && !context.isPremium {
                if installed {
                    self.unlockText = (strings().emojiPackRestore, true)
                } else {
                    self.unlockText = (strings().emojiPackUnlock, true)
                }
            } else if !installed {
                self.unlockText = (strings().emojiPackAdd, false)
            } else {
                self.unlockText = nil
            }
        } else {
            self.unlockText = nil
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
            height += nameLayout.layoutSize.height + (unlockText != nil ? 15 : 5)
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
    
    func invokeLockAction() {
        if let info = info {
            if isPremium && !context.isPremium {
                self.openPremium?()
            } else if !installed {
                self.installPack?(info, self.stickerItems)
            }
        }
    }
}



private final class EmojiesSectionRowView : TableRowView, ModalPreviewRowViewProtocol {
    
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        
        if let item = itemUnderMouse?.1, let file = item.item?.file, let emojiReference = file.emojiReference {
            let reference = FileMediaReference.stickerPack(stickerPack: emojiReference, media: file)
            if file.isVideoSticker && !file.isWebm {
                return (.file(reference, GifPreviewModalView.self), nil)
            } else if file.isAnimatedSticker || file.isWebm {
                return (.file(reference, AnimatedStickerPreviewModalView.self), nil)
            } else if file.isStaticSticker {
                return (.file(reference, StickerPreviewModalView.self), nil)
            }
        }
        return nil
    }
    
    
    fileprivate final class UnlockView : Control {
        private let gradient: PremiumGradientView = PremiumGradientView(frame: .zero)
        private let textView = TextView()
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
            container.addSubview(textView)
            addSubview(container)
            scaleOnClick = true
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            gradient.frame = bounds
            container.center()
            textView.centerY(x: 0)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(name: String, width: CGFloat, context: AccountContext, table: TableView?) -> NSSize {
            let layout = TextViewLayout(.initialize(string: name, color: NSColor.white, font: .medium(12)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            container.setFrameSize(NSMakeSize(layout.layoutSize.width, layout.layoutSize.height))
            let size = NSMakeSize(container.frame.width + 20, layout.layoutSize.height + 10)
            

            needsLayout = true
            
            return size
        }
    }
    

    fileprivate var unlock: Control?

    
    private var inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]

    private let contentView = Control()
    
    private var nameView: TextView?
    
    private var lockView: ImageView?
    private let container = View()
    
    private var reveal: TitleButton?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        addSubview(contentView)
        
        contentView.set(handler: { [weak self] _ in
            self?.updateDown()
        }, for: .Down)
        
        contentView.set(handler: { [weak self] _ in
            self?.updateDragging()
        }, for: .MouseDragging)
        
        contentView.set(handler: { [weak self] _ in
            self?.updateUp()
        }, for: .Up)
        
        contentView.set(handler: { [weak self] _ in
            let item = self?.item as? EmojiesSectionRowItem
            let table = item?.table
            let window = self?.window as? Window
            if let item = item, let table = table, let window = window {
                startModalPreviewHandle(table, window: window, context: item.context)
            }
        }, for: .LongMouseDown)
        
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
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        var containerSize = NSZeroSize
        if let nameView = self.nameView {
            containerSize = NSMakeSize(nameView.frame.width, nameView.frame.height)
        }
        if let lockView = lockView, let nameView = nameView {
            containerSize.width += lockView.frame.width
            containerSize.height = max(nameView.frame.height, lockView.frame.height)
        }

        transition.updateFrame(view: container, frame: CGRect(origin: NSMakePoint(20, 5), size: containerSize))
        
        
        if let lockView = lockView {
            transition.updateFrame(view: lockView, frame: lockView.centerFrameY(x: 0))
            if let nameView = nameView {
                transition.updateFrame(view: nameView, frame: nameView.centerFrameY(x: lockView.frame.maxX))
            }
        } else {
            if let nameView = nameView {
                transition.updateFrame(view: nameView, frame: nameView.centerFrame())
            }
        }
        
        var contentRect = bounds
        if let nameView = nameView {
            contentRect = contentRect.offsetBy(dx: 0, dy: nameView.frame.height + (unlock != nil ? 15 : 5))
        }
        transition.updateFrame(view: contentView, frame: contentRect)
        
        if let unlock = unlock {
            transition.updateFrame(view: unlock, frame: CGRect(origin: CGPoint(x: size.width - unlock.frame.width - 15, y: 0), size: unlock.frame.size))
        }
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
        if let first = currentDownItem, let current = first.1.item {
            item.callback(current)
        }
    }

    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? EmojiesSectionRowItem else {
            return
        }
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
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
        
        
        //        if (isPremium && !context.isPremium) || !installed {

     
        
        
        if case let .more(rect, count) = item.items.last {
            let current: TitleButton
            if let view = self.reveal {
                current = view
            } else {
                current = TitleButton()
                self.reveal = current
                contentView.addSubview(current)
            }
            current.set(font: .avatar(12), for: .Normal)
            current.set(color: theme.colors.accent, for: .Normal)
            current.set(background: theme.colors.accent.withAlphaComponent(0.1), for: .Normal)
            current.set(text: "+\(count)", for: .Normal)
            current.sizeToFit(.zero, NSMakeSize(rect.width - 10, 25), thatFit: true)
            current.autoSizeToFit = false
            current.scaleOnClick = true
            current.layer?.cornerRadius = current.frame.height / 2
            current.setFrameOrigin(rect.origin.offsetBy(dx: 2, dy: 4))
            
            current.removeAllHandlers()
            current.set(handler: { [weak item] _ in
                item?.showAllItems?()
            }, for: .Click)
        } else if let view = self.reveal {
            performSubviewRemoval(view, animated: animated)
            self.reveal = nil
        }
        
        
        if let unlockText = item.unlockText {
            if unlockText.1 {
                let isNew: Bool
                let current: UnlockView
                if let view = self.unlock as? UnlockView {
                    current = view
                    isNew = false
                } else {
                    if let view = unlock {
                        performSubviewRemoval(view, animated: animated)
                    }
                    current = UnlockView(frame: rect)
                    current.layer?.cornerRadius = 10
                    self.unlock = current
                    self.addSubview(current)
                    isNew = true
                }
                let size = current.update(name: unlockText.0, width: frame.width - 30, context: item.context, table: item.table)
                let rect = CGRect(origin: NSMakePoint(frame.width - size.width - 15, 0), size: size)
                if isNew {
                    current.frame = rect
                } else {
                    transition.updateFrame(view: current, frame: rect)
                }
                current.removeAllHandlers()
                current.set(handler: { [weak item] _ in
                    item?.invokeLockAction()
                }, for: .Click)
            } else {
                let current: TitleButton
                let isNew: Bool
                if let view = self.unlock as? TitleButton {
                    current = view
                    isNew = false
                } else {
                    if let view = unlock {
                        performSubviewRemoval(view, animated: animated)
                    }
                    current = TitleButton(frame: .zero)
                    current.autohighlight = false
                    current.scaleOnClick = true
                    current.layer?.cornerRadius = 10
                    self.unlock = current
                    self.addSubview(current)
                    isNew = true
                }
                current.set(background: theme.colors.accent, for: .Normal)
                current.set(font: .medium(12), for: .Normal)
                current.set(color: theme.colors.underSelectedColor, for: .Normal)
                current.set(text: unlockText.0, for: .Normal)
                current.sizeToFit(NSMakeSize(10, 10), .zero, thatFit: false)
                
                let rect = CGRect(origin: NSMakePoint(frame.width - current.frame.size.width - 15, 0), size: current.frame.size)
                if isNew {
                    current.frame = rect
                } else {
                    transition.updateFrame(view: current, frame: rect)
                }
                
                current.removeAllHandlers()
                current.set(handler: { [weak item] _ in
                    item?.invokeLockAction()
                }, for: .Click)
            }
            
        } else if let view = self.unlock {
            performSubviewRemoval(view, animated: animated)
            self.unlock = nil
        }
        
        if let unlock = unlock {
            unlock.layer?.cornerRadius = unlock.frame.height / 2
        }
        
        self.updateLayout(size: frame.size, transition: transition)
        
        
 

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
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self)
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
            if let current = item.item {
                let id = InlineStickerItemLayer.Key(id: current.file.fileId.id, index: index)
                validIds.append(id)

                let rect = item.rect

                let view: InlineStickerItemLayer
                if let current = self.inlineStickerItemViews[id], current.frame.size == rect.size {
                    view = current
                } else {
                    self.inlineStickerItemViews[id]?.removeFromSuperlayer()
                    view = InlineStickerItemLayer(context: context, file: current.file, size: rect.size)
                    self.inlineStickerItemViews[id] = view
                    view.superview = contentView
                    contentView.layer?.addSublayer(view)
                }
                index += 1

                view.isPlayable = NSIntersectsRect(rect, contentView.visibleRect) && window != nil && window!.isKeyWindow
                view.frame = rect
            }
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


/*
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

 
 shapeLayer.strokeColor = theme.colors.grayIcon.withAlphaComponent(0.7).cgColor
 shapeLayer.lineWidth = 1
 shapeLayer.lineCap = .round
 shapeLayer.fillColor = nil
 
 shapeLayer.opacity = !item.context.isPremium && item.isPremium ? 1 : 0
 */
