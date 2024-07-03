//
//  MediaGroupPreviewRowItem.swift
//  Telegram
//
//  Created by keepcoder on 02/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

class MediaGroupPreviewRowItem: TableRowItem {
    fileprivate let context: AccountContext
    private let _stableId: UInt32 = arc4random()
    fileprivate let layout: GroupedLayout
    fileprivate let reorder:(Int, Int)->Void
    fileprivate let urls: [URL]
    fileprivate let editedData: [URL: EditedImageData]
    fileprivate let edit:(URL)->Void
    fileprivate let paint:(URL)->Void
    fileprivate let delete:(URL)->Void
    fileprivate let parameters:[ChatMediaLayoutParameters]
    fileprivate let payAmount: Int64?
    init(_ initialSize: NSSize, messages: [Message], urls: [URL], editedData: [URL : EditedImageData], isSpoiler: Bool, payAmount: Int64?, edit: @escaping(URL)->Void, paint: @escaping(URL)->Void, delete:@escaping(URL)->Void, context: AccountContext, reorder:@escaping(Int, Int)->Void) {
        layout = GroupedLayout(messages)
        self.editedData = editedData
        self.edit = edit
        self.paint = paint
        self.delete = delete
        self.urls = urls
        self.reorder = reorder
        self.context = context
        self.payAmount = payAmount
        self.parameters = messages.map {
            let param = ChatMediaLayoutParameters(presentation: .empty, media: $0.media[0])
            param.forceSpoiler = isSpoiler || payAmount != nil
            param.fillContent = true
            return param
        }
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        layout.measure(NSMakeSize(width, width), preview: true)
        return success
    }
    
    override var height: CGFloat {
        return layout.dimensions.height + 12
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }

    
    
    override func viewClass() -> AnyClass {
        return MediaGroupPreviewRowView.self
    }
    
}

class MediaGroupPreviewRowView : TableRowView, ModalPreviewRowViewProtocol {
    private var contents: [ChatMediaContentView] = []
    private var startPoint: NSPoint = NSZeroPoint
    private(set) var draggingIndex: Int? = nil
    private var paidView: PaidContentView?
    
    private let editControl = MediaPreviewEditControl()
    
    
    private final class PaidContentView: NSVisualEffectView {
        private let textView = InteractiveTextView()
        required override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.wantsLayer = true
            self.material = .ultraDark
            self.blendingMode = .withinWindow
            self.state = .active
            
            addSubview(textView)
            
            textView.userInteractionEnabled = false
            textView.textView.isSelectable = false
            
        }
        
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(amount: Int64, context: AccountContext, short: Bool) {
            
            let attr = NSMutableAttributedString()
            attr.append(string: "\(clown)", color: .white, font: .medium(.text))
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency.file), for: clown)
            attr.append(string: " \(amount)", color: .white, font: .medium(.text))
            
            let textLayout = TextViewLayout(attr)
            textLayout.measure(width: .greatestFiniteMagnitude)

            self.textView.set(text: textLayout, context: context)
            
            self.setFrameSize(NSMakeSize(textView.frame.width + 20, 30))

        }
        
        override func layout() {
            super.layout()
            self.textView.centerY(x: 10)
        }
    }
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        
        guard let item = item as? MediaGroupPreviewRowItem else { return nil }
        
        for i in 0 ..< item.layout.count {
            if NSPointInRect(point, item.layout.frame(at: i).offsetBy(dx: offset.x, dy: offset.y)) {
                let contentNode = contents[i]
                if contentNode is VideoStickerContentView {
                    if let file = contentNode.media as? TelegramMediaFile {
                        let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                        return (.file(reference, GifPreviewModalView.self), contentNode)
                    }
                } else if contentNode is ChatInteractiveContentView {
                    if let image = contentNode.media as? TelegramMediaImage {
                        let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                        return (.image(reference, ImagePreviewModalView.self), contentNode)
                    }
                }
            }
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func updateColors() {
        super.updateColors()
        for content in contents {
            content.backgroundColor = .clear
        }
    }
    
    private var offset: NSPoint {
        guard let item = item as? MediaGroupPreviewRowItem else { return NSZeroPoint }
        return NSMakePoint((frame.width - item.layout.dimensions.width) / 2, 6)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? MediaGroupPreviewRowItem else {return}
        
        if contents.count > item.layout.count {
            let contentCount = contents.count
            let layoutCount = item.layout.count
            
            for i in layoutCount ..< contentCount {
                contents[i].removeFromSuperview()
            }
            contents = contents.subarray(with: NSMakeRange(0, layoutCount))
        } else if contents.count < item.layout.count {
            let contentCount = contents.count
            for _ in contentCount ..< item.layout.count {
                contents.append(ChatInteractiveContentView(frame: NSZeroRect))
                contents.last?.userInteractionEnabled = false
            }
        }
                
        for i in 0 ..< contents.count {
            let content = contents[i]
            addSubview(content)
        }
        
        assert(contents.count == item.layout.count)
        
        for i in 0 ..< item.layout.count {
            contents[i].update(with: item.layout.messages[i].media[0], size: item.layout.frame(at: i).size, context: item.context, parent: nil, table: item.table, parameters: item.parameters[i], animated: false, positionFlags: nil)
        }
        super.set(item: item, animated: animated)
        
        
        if let payAmount = item.payAmount {
            let current: PaidContentView
            if let view = self.paidView {
                current = view
            } else {
                current = PaidContentView(frame: NSMakeRect(0, 0, 100, 30))
                self.paidView = current
            }
            current.update(amount: payAmount, context: item.context, short: true)
            current.layer?.cornerRadius = current.frame.height / 2
            addSubview(current)
            current.center()
        } else if let view = self.paidView {
            performSubviewRemoval(view, animated: false)
            self.paidView = nil
        }
        
        needsLayout = true
        
        updateMouse(animated: animated)
    }
    
    override func forceClick(in location: NSPoint) {
        guard let item = item as? MediaGroupPreviewRowItem else {return}

        for i in 0 ..< item.layout.count {
            if NSPointInRect(location, item.layout.frame(at: i).offsetBy(dx: offset.x, dy: offset.y)) {
                _ = contents[i].previewMediaIfPossible()
                break
            }
        }
    }
    
    override func updateMouse(animated: Bool) {
        updateControl()
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let item = item as? MediaGroupPreviewRowItem else {return}
        let point = convert(event.locationInWindow, from: nil)
        draggingIndex = nil
        previous = point
        for i in 0 ..< item.layout.count {
            if NSPointInRect(point, item.layout.frame(at: i).offsetBy(dx: offset.x, dy: offset.y)) {
                self.startPoint = point
                self.draggingIndex = i
                addSubview(contents[i])
                break
            }
        }
        updateControl()
        super.mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        
        guard let item = item as? MediaGroupPreviewRowItem else {return}

        var point = convert(event.locationInWindow, from: nil)
        point = NSMakePoint(min(max(0, point.x), frame.width - 10), min(max(0, point.y), frame.height - 10))
        if let index = draggingIndex, let newIndex = item.layout.moveItemIfNeeded(at: index, point: point) {
            
            let current = contents[index]
            contents.remove(at: index)
            contents.insert(current, at: newIndex)
            
            _ = item.makeSize(frame.width, oldWidth: 0)
            item.table?.noteHeightOfRow(item.index, true)
            
            item.reorder(index, newIndex)
            
            set(item: item, animated: true)
            for i in 0 ..< item.layout.count {
                let rect = item.layout.frame(at: i).offsetBy(dx: offset.x, dy: offset.y)
                contents[i].frame = rect
            }
        } else {
            for i in 0 ..< item.layout.count {
                let rect = item.layout.frame(at: i).offsetBy(dx: offset.x, dy: offset.y)
                contents[i].frame = rect
            }
        }
        
        draggingIndex = nil
        startPoint = NSZeroPoint
        updateControl()
    }
    private var previous: NSPoint = NSZeroPoint
    override func mouseDragged(with event: NSEvent) {
        guard let item = item as? MediaGroupPreviewRowItem else {return}

        let point = convert(event.locationInWindow, from: nil)
       
        if let index = draggingIndex {
            let past = contents[index].frame

            var current = contents[index].frame.origin
            current.x += (point.x - previous.x)
            current.y += (point.y - previous.y)
            
            
            let size = contents[index].frame.size.fitted(NSMakeSize(150, 150))
            current.x -= (size.width - past.width) * ((point.x - past.minX) / past.width)
            current.y -= (size.height - past.height) * ((point.y - past.minY) / past.height)
            
            
            if size != contents[index].frame.size {
                contents[index].setFrameSize(size)
            }
            contents[index].setFrameOrigin(current)


            
            previous = point
            
            
            
            
            let layout = GroupedLayout(item.layout.messages)
            layout.measure(NSMakeSize(frame.width, frame.width))
            
            if layout.moveItemIfNeeded(at: index, point: point) != nil {
                
                for i in 0 ..< layout.count {
                    let current = item.layout.frame(at: i).offsetBy(dx: offset.x, dy: offset.y).origin
                    if i != index {
                        contents[i].setFrameOrigin(current)
                    }
                }
            } else {
                for i in 0 ..< item.layout.count {
                    if i != index {
                        contents[i].setFrameOrigin(item.layout.frame(at: i).origin.offsetBy(dx: offset.x, dy: offset.y))
                    }
                }
            }
        }
        updateControl()
    }
    
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = newValue
            for content in contents {
                content.needsDisplay = newValue
            }
        }
    }
    override var backgroundColor: NSColor {
        didSet {
            for content in contents {
                content.backgroundColor = backdorColor
            }
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        updateControl()
        
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateControl()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateControl()
    }
    
    
    func updateControl() {
        
        addSubview(editControl)
        if let paidView {
            addSubview(paidView)
        }
        
        
        guard let item = item as? MediaGroupPreviewRowItem else {
            return
        }
        
        let location = self.convert(self.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        
        var found = false
        for i in 0 ..< item.layout.count {
            let rect = item.layout.frame(at: i).offsetBy(dx: offset.x, dy: offset.y)
            if rect.contains(location) {
                self.editControl.canEdit = item.layout.messages[i].media[0] is TelegramMediaImage
                
                self.editControl.set(edit: { [weak item] in
                    guard let item = item else {return}
                    item.edit(item.urls[i])
                }, paint: { [weak item] in
                    guard let item = item else {return}
                    item.paint(item.urls[i])
                }, delete: { [weak item] in
                    guard let item = item else {return}
                    item.delete(item.urls[i])
                }, editedData: item.editedData[item.urls[i]])
                
                self.editControl.setFrameOrigin(NSMakePoint(rect.maxX - editControl.frame.width - 5, rect.maxY - editControl.frame.height - 5))
                found = true
                break
            }
        }
        
        self.editControl.isHidden = self.draggingIndex != nil || !found
        
        
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            for content in contents {
                content.willRemove()
            }
        }
    }

    
    override var backdorColor: NSColor {
        return .clear
    }
    
    
    override func layout() {
        super.layout()
        guard let item = item as? MediaGroupPreviewRowItem else {return}
        
        assert(contents.count == item.layout.count)
        
        if let _ = draggingIndex {
            return
        }
        
        for i in 0 ..< item.layout.count {
            contents[i].setFrameOrigin(item.layout.frame(at: i).origin.offsetBy(dx: offset.x, dy: offset.y))
            if let control = contents[i].subviews.first(where: { $0 is MediaPreviewEditControl }) {
                control.setFrameOrigin(NSMakePoint(contents[i].frame.width - control.frame.width - 10, contents[i].frame.height - control.frame.height - 10))
            }
        }
        
        paidView?.center()
        
    }
}
