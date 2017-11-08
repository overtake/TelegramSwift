//
//  MediaGroupPreviewRowItem.swift
//  Telegram
//
//  Created by keepcoder on 02/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class MediaGroupPreviewRowItem: TableRowItem {
    fileprivate let account: Account
    private let _stableId: UInt32 = arc4random()
    fileprivate let layout: GroupedLayout
    init(_ initialSize: NSSize, messages: [Message], account: Account) {
        layout = GroupedLayout(messages)
        self.account = account
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        layout.measure(NSMakeSize(width - 20, width - 20))
        return super.makeSize(width, oldWidth: oldWidth)
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

private class MediaGroupPreviewRowView : TableRowView {
    private var contents: [ChatMediaContentView] = []
    private var startPoint: NSPoint = NSZeroPoint
    private var draggingIndex: Int? = nil

    override func draw(_ dirtyRect: NSRect) {
        
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
        
        for content in contents {
            addSubview(content)
        }
        
        assert(contents.count == item.layout.count)
        
        for i in 0 ..< item.layout.count {
            contents[i].update(with: item.layout.messages[i].media[0], size: item.layout.frame(at: i).size, account: item.account, parent: nil, table: item.table, positionFlags: item.layout.position(at: i))
        }
        super.set(item: item, animated: animated)
        
        needsLayout = true
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let item = item as? MediaGroupPreviewRowItem else {return}
        let point = convert(event.locationInWindow, from: nil)
        draggingIndex = nil
        previous = point
        for i in 0 ..< item.layout.count {
            if NSPointInRect(point, item.layout.frame(at: i).offsetBy(dx: 10, dy: 6)) {
                self.startPoint = point
                self.draggingIndex = i
                //contents[i].removeFromSuperview()
                addSubview(contents[i])
                break
            }
        }
        
    }
    
    override func mouseUp(with event: NSEvent) {
        
        guard let item = item as? MediaGroupPreviewRowItem else {return}

        let point = convert(event.locationInWindow, from: nil)
        
        if let index = draggingIndex, let newIndex = item.layout.moveItemIfNeeded(at: index, point: point) {
            
            let current = contents[index]
            contents.remove(at: index)
            contents.insert(current, at: newIndex)
            
            
            _ = item.makeSize(frame.width, oldWidth: 0)
            set(item: item, animated: true)
            for i in 0 ..< item.layout.count {
                let rect = item.layout.frame(at: i).offsetBy(dx: 10, dy: 6)
                contents[i].change(pos: rect.origin, animated: true)
                contents[i].change(size: rect.size, animated: true)
            }
        } else {
            for i in 0 ..< item.layout.count {
                let rect = item.layout.frame(at: i).offsetBy(dx: 10, dy: 6)
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
                
                let next: Int? = new
                let indexPoint = item.layout.frame(at: index).offsetBy(dx: 10, dy: 6).origin
                let selected = item.layout.frame(at: new).offsetBy(dx: 10, dy: 6).origin
                
                let selectedFlags = layout.position(at: new)
                

                
                
                /*
                 if new > index {
                 if indexPoint.y != selected.y {
                 if indexPoint.y > selected.y {
                 current.y += 1
                 } else {
                 current.y -= 1
                 }
                 } else {
                 if selected.y == 6 {
                 current.y -= 1
                 } else {
                 current.x -= 1
                 }
                 }
                 
                 } else {
                 if indexPoint.y != selected.y {
                 if indexPoint.y < selected.y {
                 current.y -= 1
                 } else {
                 
                 if selected.x == 10 {
                 current.x += 1
                 } else {
                 current.y += 1
                 }
                 }
                 } else {
                 current.x += 1
                 }
                 }
 */
                
                
                for i in 0 ..< layout.count {
                    var current = item.layout.frame(at: i).offsetBy(dx: 10, dy: 6).origin
                    let currentFlags = item.layout.position(at: i)

                    if i != index {
                        if i == next {
//                            if selectedFlags.contains(.left) {
//                                if currentFlags.contains(.left) {
//                                    NSLog("left->left")
//                                } else if currentFlags.contains(.right) {
//                                    NSLog("left->right")
//                                } else if currentFlags.contains(.bottom) {
//                                    NSLog("left->bottom")
//                                } else if currentFlags.contains(.top) {
//                                    NSLog("left->top")
//                                }
//                            } else if selectedFlags.contains(.right) {
//                                if currentFlags.contains(.left) {
//                                    NSLog("right->left")
//                                } else if currentFlags.contains(.right) {
//                                    NSLog("right->right")
//                                } else if currentFlags.contains(.bottom) {
//                                    NSLog("right->bottom")
//                                } else if currentFlags.contains(.top) {
//                                    NSLog("right->top")
//                                }
//                            } else if selectedFlags.contains(.bottom) {
//                                if currentFlags.contains(.left) {
//                                    NSLog("bottom->left")
//                                } else if currentFlags.contains(.right) {
//                                    NSLog("bottom->right")
//                                } else if currentFlags.contains(.bottom) {
//                                    NSLog("bottom->bottom")
//                                } else if currentFlags.contains(.top) {
//                                    NSLog("bottom->top")
//                                }
//                            } else if selectedFlags.contains(.top) {
//                                if currentFlags.contains(.left) {
//                                    NSLog("top->left")
//                                } else if currentFlags.contains(.right) {
//                                    NSLog("top->right")
//                                } else if currentFlags.contains(.bottom) {
//                                    NSLog("top->bottom")
//                                } else if currentFlags.contains(.top) {
//                                    NSLog("top->top")
//                                }
//                            }
                        }
                        contents[i].setFrameOrigin(current)
                    }
                    
                }
            } else {
                for i in 0 ..< item.layout.count {
                    if i != index {
                        contents[i].setFrameOrigin(item.layout.frame(at: i).origin.offsetBy(dx: 10, dy: 6))
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
            contents[i].setFrameOrigin(item.layout.frame(at: i).origin.offsetBy(dx: 10, dy: 6))
        }
        
    }
}
