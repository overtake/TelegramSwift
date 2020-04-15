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
import SyncCore
import Postbox
import SwiftSignalKit

class MediaGroupPreviewRowItem: TableRowItem {
    fileprivate let context: AccountContext
    private let _stableId: UInt32 = arc4random()
    fileprivate let layout: GroupedLayout
    fileprivate let reorder:(Int, Int)->Void
    fileprivate let urls: [URL]
    fileprivate let hasEditedData: [URL: EditedImageData]
    fileprivate let edit:(URL)->Void
    fileprivate let delete:(URL)->Void
    init(_ initialSize: NSSize, messages: [Message], urls: [URL], editedData: [URL : EditedImageData], edit: @escaping(URL)->Void, delete:@escaping(URL)->Void, context: AccountContext, reorder:@escaping(Int, Int)->Void) {
        layout = GroupedLayout(messages)
        self.hasEditedData = editedData
        self.edit = edit
        self.delete = delete
        self.urls = urls
        self.reorder = reorder
        self.context = context
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        layout.measure(NSMakeSize(width - 20, width - 20))
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
    
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        
        guard let item = item as? MediaGroupPreviewRowItem else { return nil }
        
        for i in 0 ..< item.layout.count {
            if NSPointInRect(point, item.layout.frame(at: i).offsetBy(dx: offset.x, dy: offset.y)) {
                let contentNode = contents[i]
                if contentNode is ChatGIFContentView {
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
            let control: MediaPreviewEditControl
            if let editControl = content.subviews.last as? MediaPreviewEditControl {
                control = editControl
            } else {
                let editControl = MediaPreviewEditControl()
                content.addSubview(editControl)
                control = editControl
            }
            control.canEdit = item.layout.messages[i].media[0] is TelegramMediaImage
            control.set(edit: { [weak item] in
                guard let item = item else {return}
                item.edit(item.urls[i])
            }, delete: { [weak item] in
                    guard let item = item else {return}
                    item.delete(item.urls[i])
            }, hasEditedData: item.hasEditedData[item.urls[i]] != nil)
            
        }
        
        assert(contents.count == item.layout.count)
        
        for i in 0 ..< item.layout.count {
            contents[i].update(with: item.layout.messages[i].media[0], size: item.layout.frame(at: i).size, context: item.context, parent: nil, table: item.table, positionFlags: item.layout.position(at: i))
        }
        super.set(item: item, animated: animated)
        
        needsLayout = true
        
        updateMouse()
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
    
    override func updateMouse() {
        guard let window = window, let table = item?.table else {
            for node in self.contents {
                if let control = node.subviews.last as? MediaPreviewEditControl {
                    control.isHidden = true
                }
            }
            return
        }
        
        let row = table.row(at: table.documentView!.convert(window.mouseLocationOutsideOfEventStream, from: nil))
        
        if row == item?.index {
            let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            for node in self.contents {
                if let control = node.subviews.last as? MediaPreviewEditControl {
                    if NSPointInRect(point, node.frame) {
                        control.isHidden = false
                    } else {
                        control.isHidden = true
                    }
                }
            }
        } else {
            for node in self.contents {
                if let control = node.subviews.last as? MediaPreviewEditControl {
                    control.isHidden = true
                }
            }
        }
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
                //contents[i].removeFromSuperview()
                addSubview(contents[i])
                break
            }
        }
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
                contents[i].change(pos: rect.origin, animated: true)
                contents[i].change(size: rect.size, animated: true)
            }
        } else {
            for i in 0 ..< item.layout.count {
                let rect = item.layout.frame(at: i).offsetBy(dx: offset.x, dy: offset.y)
                contents[i].change(pos: rect.origin, animated: true)
                contents[i].change(size: rect.size, animated: true)
            }
        }
        
        draggingIndex = nil
        startPoint = NSZeroPoint
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
            
            
            let size = contents[index].frame.size.fitted(NSMakeSize(100, 100))
            current.x -= (size.width - past.width) * ((point.x - past.minX) / past.width)
            current.y -= (size.height - past.height) * ((point.y - past.minY) / past.height)
            

            contents[index].change(pos: current, animated: false)
            
            if size != contents[index].frame.size {
                contents[index].change(size: size, animated: true)
            }
            previous = point
            
            
            
            
            let layout = GroupedLayout(item.layout.messages)
            layout.measure(NSMakeSize(frame.width - 20, frame.width - 20))
            
            if let new = layout.moveItemIfNeeded(at: index, point: point) {
                
                
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
    
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            for content in contents {
                content.willRemove()
            }
        }
    }

    
    override var backdorColor: NSColor {
        return theme.colors.background
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
            if let control = contents[i].subviews.last {
                control.setFrameOrigin(NSMakePoint(contents[i].frame.width - control.frame.width - 10, contents[i].frame.height - control.frame.height - 10))
            }
        }
        
    }
}
