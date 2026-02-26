//
//  StorageUsageMediaCells.swift
//  Telegram
//
//  Created by Mike Renoir on 29.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox
import TGUIKit


class StorageMediaCell : MediaCell {
    
    
    private class Accessory : View {
        private let textView = TextView()
        private var playable: ImageView?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            self.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            if let view = self.playable {
                transition.updateFrame(view: view, frame: view.centerFrameY(x: 5, addition: -3))
                transition.updateFrame(view: textView, frame: textView.centerFrameY(x: 10 + 9))
            } else {
                transition.updateFrame(view: textView, frame: textView.centerFrame())
            }
        }
        
        func update(text: TextViewLayout, playable: Bool, transition: ContainedViewLayoutTransition) {
            textView.update(text)
            if playable {
                let isNew: Bool
                let current: ImageView
                if let view = self.playable {
                    current = view
                    isNew = false
                } else {
                    current = ImageView()
                    self.playable = current
                    addSubview(current)
                    isNew = true
                }
                current.image = theme.icons.storage_media_play
                current.sizeToFit()
                if isNew {
                    current.centerY(x: 5, addition: -3)
                    if transition.isAnimated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
            } else if let view = self.playable {
                self.playable = nil
                performSubviewRemoval(view, animated: transition.isAnimated)
            }
            self.updateLayout(size: frame.size, transition: transition)
        }
    }
    
    private let accessory: Accessory = Accessory(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(accessory)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: accessory, frame: NSMakeRect(size.width - accessory.frame.width - 3, size.height - accessory.frame.height - 3, accessory.frame.width, accessory.frame.height))
    }
    
    func updateSize(_ text: TextViewLayout, playable: Bool, animated: Bool) {
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        let size: NSSize = NSMakeSize(playable ? 5 + 9 + text.layoutSize.width + 10 : text.layoutSize.width + 10, text.layoutSize.height + 6)
        
        let rect = CGRect(origin: NSMakePoint(frame.width - accessory.frame.width - 3, frame.height - accessory.frame.height - 3), size: size)
        
        transition.updateFrame(view: accessory, frame: rect)
        
        accessory.update(text: text, playable: playable, transition: transition)
        accessory.layer?.cornerRadius = size.height / 2
        self.updateLayout(size: frame.size, transition: transition)
    }
}


class StorageUsageMediaCells: GeneralRowItem {
    let items:[Message]
    fileprivate let context: AccountContext
    private var contentHeight: CGFloat = 0
    
    fileprivate private(set) var layoutItems:[MediaCellLayoutItem] = []
    fileprivate private(set) var itemSize: NSSize = NSZeroSize
    private let _menuItems:(Message)->[ContextMenuItem]
    fileprivate let getSelected: (MessageId)->Bool?
    fileprivate let toggle: (MessageId, Bool?)->Void
    private let sizes: [MessageId : Int64]
    
    private var textSizes:[MessageId: TextViewLayout] = [:]
    
    func getTextSize(_ messageId: MessageId) -> TextViewLayout {
        if let text = textSizes[messageId] {
            return text
        } else {
            let size = sizes[messageId] ?? 0
            let text = TextViewLayout.init(.initialize(string: .prettySized(with: size, round: true), color: .white, font: .normal(10)))
            text.measure(width: .greatestFiniteMagnitude)
            textSizes[messageId] = text
            return text
        }
    }
    func isPlayable(_ message: Message) -> Bool {
        if let file = message.anyMedia as? TelegramMediaFile {
            return file.isVideo || file.isInstantVideo
        }
        return false
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, context: AccountContext, items: [Message], sizes:[MessageId : Int64], getSelected: @escaping(MessageId)->Bool?, toggle: @escaping(MessageId, Bool?)->Void, menuItems:@escaping(Message)->[ContextMenuItem]) {
        self.items = items
        self.sizes = sizes
        self.context = context
        self.getSelected = getSelected
        self._menuItems = menuItems
        self.toggle = toggle
        super.init(initialSize, stableId: stableId, viewType: viewType, inset: NSEdgeInsets())
    }
    
    override var canBeAnchor: Bool {
        return true
    }
    
    static func rowCount(blockWidth: CGFloat, viewType: GeneralViewType) -> (Int, CGFloat) {
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        while true {
            let maximum = blockWidth - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 90 {
                break
            } else {
                rowCount -= 1
            }
        }
        return (rowCount, perWidth)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        let (rowCount, perWidth) = StorageUsageMediaCells.rowCount(blockWidth: self.blockWidth, viewType: self.viewType)
        
        assert(rowCount >= 1)
                
        let itemSize = NSMakeSize(ceil(perWidth) + 2, ceil(perWidth) + 2)
        
        layoutItems.removeAll()
        var point: CGPoint = CGPoint(x: 0, y: itemSize.height)
        for (i, message) in self.items.enumerated() {
            let viewType: MediaCell.Type
            if let file = message.anyMedia as? TelegramMediaFile {
                if file.isAnimated && file.isVideo {
                    viewType = MediaGifCell.self
                } else {
                    viewType = MediaVideoCell.self
                }
            } else {
                viewType = MediaPhotoCell.self
            }
            
            var topLeft: ImageCorner = .Corner(0)
            var topRight: ImageCorner = .Corner(0)
            var bottomLeft: ImageCorner = .Corner(0)
            var bottomRight: ImageCorner = .Corner(0)
            
            if self.viewType.position != .first && self.viewType.position != .inner {
                if self.items.count < rowCount {
                    if message == self.items.first {
                        if self.viewType.position != .last {
                            topLeft = .Corner(.cornerRadius)
                        }
                        bottomLeft = .Corner(.cornerRadius)
                    }
                } else if self.items.count == rowCount {
                    if message == self.items.first {
                        if self.viewType.position != .last {
                            topLeft = .Corner(.cornerRadius)
                        }
                        bottomLeft = .Corner(.cornerRadius)
                    } else if message == self.items.last {
                        if message == self.items.last {
                            if self.viewType.position != .last {
                                topRight = .Corner(.cornerRadius)
                            }
                            bottomRight = .Corner(.cornerRadius)
                        }
                    }
                } else {
                    let i = i + 1
                    let firstLine = i <= rowCount
                    let div = (items.count % rowCount) == 0 ? rowCount : (items.count % rowCount)
                    let lastLine = i > (items.count - div)
                    
                    if firstLine {
                        if self.viewType.position != .last {
                            if i % rowCount == 1 {
                                topLeft = .Corner(.cornerRadius)
                            } else if i % rowCount == 0 {
                                topRight = .Corner(.cornerRadius)
                            }
                        }
                    } else if lastLine {
                        if i % rowCount == 1 {
                            bottomLeft = .Corner(.cornerRadius)
                        } else if i % rowCount == 0 {
                            bottomRight = .Corner(.cornerRadius)
                        }
                    }
                }
            }
            let corners = ImageCorners(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
            self.layoutItems.append(MediaCellLayoutItem(message: message, frame: CGRect(origin: point.offsetBy(dx: 0, dy: -itemSize.height), size: itemSize), viewType: viewType, corners: corners, context: context))
            point.x += itemSize.width
            if self.layoutItems.count % rowCount == 0, message != self.items.last {
                point.y += itemSize.height + 1
                point.x = 0
            }
        }
        self.itemSize = itemSize
        self.contentHeight = point.y
        return true
    }
    
    func contains(_ id: MessageId) -> Bool {
        return layoutItems.contains(where: { $0.message.id == id})
    }
    
    override var height: CGFloat {
        return self.contentHeight
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    deinit {

    }
    
    override func viewClass() -> AnyClass {
        return StorageUsageMediaCellsView.self
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        let layoutItem = layoutItems.first(where: { NSPointInRect(location, $0.frame) })
        if let layoutItem = layoutItem {
            return .single(_menuItems(layoutItem.message))
        }
        return .single([])
    }
}


private final class StorageUsageMediaCellsView : GeneralContainableRowView {
    private var contentViews:[Optional<StorageMediaCell>] = []

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        containerView.set(handler: { [weak self] _ in
            self?.action(event: .Down)
        }, for: .Down)
        
        containerView.set(handler: { [weak self] _ in
            self?.action(event: .MouseDragging)
        }, for: .MouseDragging)
        
        containerView.set(handler: { [weak self] _ in
            self?.action(event: .Click)
        }, for: .Click)
    }
    
    private func action(event: ControlEvent) {
        guard let item = self.item as? StorageUsageMediaCells, let window = window else {
            return
        }
        let point = containerView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if let layoutItem = item.layoutItems.first(where: { NSPointInRect(point, $0.frame) }) {
            if item.getSelected(layoutItem.message.id) != nil {
                switch event {
                case .MouseDragging:
                    item.toggle(layoutItem.message.id, haveToSelectOnDrag)
                case .Down:
                    haveToSelectOnDrag = item.getSelected(layoutItem.message.id) == false
                    item.toggle(layoutItem.message.id, nil)
                default:
                    break
                }
            } else {
                switch event {
                case .Click:
                    if let event = NSApp.currentEvent {
                        self.showContextMenu(event)
                    }
                default:
                    break
                }
            }
        }
    }

    private var haveToSelectOnDrag: Bool = false
    
    
    private weak var currentMouseCell: MediaCell?
    
    @objc func _updateMouse() {
        super.updateMouse(animated: true)
        guard let window = self.window else {
            return
        }
        let point = self.containerView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let mediaCell = self.contentViews.first(where: {
            return $0 != nil && NSPointInRect(point, $0!.frame)
        })?.map { $0 }
        
        if currentMouseCell != mediaCell {
            currentMouseCell?.updateMouse(false)
        }
        currentMouseCell = mediaCell
        mediaCell?.updateMouse(window.isKeyWindow)
        
    }
    
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        _updateMouse()
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        _updateMouse()
    }
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        _updateMouse()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? StorageUsageMediaCells else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        containerView.set(background: self.backdorColor, for: .Normal)
    }
    
    
    @objc private func updateVisibleItems() {
        self.layoutVisibleItems(animated: false)
    }
    
    private var previousRange: (Int, Int) = (0, 0)
    private var isCleaned: Bool = false
    
    private func layoutVisibleItems(animated: Bool) {
        guard let item = item as? StorageUsageMediaCells, let table = item.table else {
            return
        }
        let height = table.frame.height
        let visibleRect = NSMakeRect(0, table.documentOffset.y, table.frame.width, height).insetBy(dx: 0, dy: -height/2)
        let size = item.itemSize
                
        if superview != nil && window != nil {
            let visibleRange = (Int(ceil(visibleRect.minY / (size.height))), Int(ceil(visibleRect.height / (size.height))))
            if visibleRange != self.previousRange {
                self.previousRange = visibleRange
                isCleaned = false
            } else {
                return
            }

        } else {
            self.previousRange = (0, 0)
            CATransaction.begin()
            if !isCleaned {
                for (i, view) in self.contentViews.enumerated() {
                    view?.removeFromSuperview()
                    self.contentViews[i] = nil
                }
            }
            isCleaned = true
            CATransaction.commit()
            return
        }
        

        CATransaction.begin()
          
        var unused:[MediaCell] = []
        for (i, layout) in item.layoutItems.enumerated() {
            if NSPointInRect(layout.frame.origin, visibleRect) {
                var view: StorageMediaCell
                if self.contentViews[i] == nil {
                    view = StorageMediaCell(frame: layout.frame)
                    self.contentViews[i] = view
                } else {
                    view = self.contentViews[i]!
                }
                let selected = item.getSelected(layout.message.id)
                let isUpdated = view.layoutItem == nil || !view.layoutItem!.isEqual(to: layout)
                if isUpdated || view.selecting != selected {
                    view.update(layout: layout, selected: selected, context: item.context, table: item.table, animated: animated)
                    view.updateSize(item.getTextSize(layout.message.id), playable: item.isPlayable(layout.message), animated: animated)
                }

                view.frame = layout.frame
            } else {
                if let view = self.contentViews[i] {
                    unused.append(view)
                    self.contentViews[i] = nil
                }
            }
        }
          
        for view in unused {
            view.removeFromSuperview()
        }
        
        containerView.subviews = self.contentViews.compactMap { $0 }

        CATransaction.commit()

        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidMoveToWindow() {
         if window == nil {
             NotificationCenter.default.removeObserver(self)
         } else {
             NotificationCenter.default.addObserver(self, selector: #selector(updateVisibleItems), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
            NotificationCenter.default.addObserver(self, selector: #selector(_updateMouse), name: NSWindow.didBecomeKeyNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(_updateMouse), name: NSWindow.didResignKeyNotification, object: nil)
         }
         updateVisibleItems()
     }
    
    override func layout() {
        super.layout()
        
        updateVisibleItems()
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool) -> NSView {
        if let innerId = innerId.base as? MessageId {
            let view = contentViews.compactMap { $0 }.first(where: { $0.layoutItem?.id == innerId })
            return view ?? NSView()
        }
        return self
    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        if let innerId = innerId.base as? MessageId {
            let cell = contentViews.compactMap { $0 }.first(where: { $0.layoutItem?.id == innerId })
            cell?.addAccesoryOnCopiedView(view: view)
        }
    }
    
    override func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        return containerView.convert(point, from: nil)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StorageUsageMediaCells else {
            return
        }
        
        self.previousRange = (0, 0)
        
        while self.contentViews.count > item.layoutItems.count {
            self.contentViews.removeLast()
        }
        while self.contentViews.count < item.layoutItems.count {
            self.contentViews.append(nil)
        }
        
        layoutVisibleItems(animated: animated)
    }
    
}
