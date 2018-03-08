//
//  EBlockRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac

extension CATiledLayer {
    func fadeDuration() -> CFTimeInterval {
        return 0.00
    }
}

class ETiledLayer : CALayer {
    
    
    fileprivate var layoutNextRequest: Bool = true
    
//    open override func setNeedsDisplay() {
//        if layoutNextRequest {
//            super.setNeedsDisplay()
//            layoutNextRequest = false
//        }
//    }
}

private class EmojiSegmentView: NSView, CALayerDelegate {
    
    fileprivate override var isFlipped: Bool {
        return true
    }
    
    private let item:Atomic<EBlockItem?> = Atomic(value: nil)
    
    fileprivate func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let item = item.modify({$0}) {
            ctx.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            var ts:NSPoint = NSMakePoint(17, 29)
            
            for segment in item.lineAttr {
                for line in segment {
                    ctx.textPosition = ts
                    CTLineDraw(CTLineCreateWithAttributedString(line), ctx)
                    ts.x+=xAdd
                }
                ts.y += yAdd
                ts.x = 17
            }
        }
        
    }
    
    
    var tiled:ETiledLayer = ETiledLayer()
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        self.layer?.addSublayer(tiled)
        tiled.frame = self.bounds
        tiled.contentsScale = backingScaleFactor
      //  tiled.levelsOfDetailBias = Int(backingScaleFactor)
        self.tiled.delegate = self
        
        //tiled.shouldRasterize
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        tiled.contentsScale = backingScaleFactor
      //  tiled.levelsOfDetailBias = Int(backingScaleFactor)
    }
    
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = true
        }
    }
    
    override func setNeedsDisplay(_ invalidRect: NSRect) {
        
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        tiled.frame = bounds
      //  tiled.tileSize = bounds.size
    }
    
    func update(with item:EBlockItem?) -> Void {
        _ = self.item.swap(item)
        tiled.layoutNextRequest = true
        background = theme.colors.background
        self.needsDisplay = true
        tiled.setNeedsDisplay()
    }
    
}

private let xAdd:CGFloat = 41
private let yAdd:CGFloat = 34

class EBlockRowView: TableRowView {
    
   // var tiled:CATiledLayer = CATiledLayer()
    
    var button:Control = Control()
    private var segmentView:EmojiSegmentView = EmojiSegmentView()
    var mouseDown:Bool = false
    private var popover: NSPopover?
    
    var selectedEmoji:String = ""
    
    private let longHandle = MetaDisposable()
    private var useEmoji: Bool = true
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
       // self.segmentView.backgroundColor = .clear
        
        button.frame = NSMakeRect(0, 0, 33, 33)
        self.button.layer?.cornerRadius = 4.0
        self.button.backgroundColor = .clear
        self.button.set(background: theme.colors.grayBackground, for: .Highlight)
        
        self.addSubview(button)
        self.addSubview(segmentView)
       // segmentView.layer?.shouldRasterize = true
        self.button.userInteractionEnabled = false
//        self.button.set(handler: { 
//            var bp:Int = 0
//            bp += 1
//        }, for: .Click)
        
      //  self.layer?.addSublayer(tiled)
       // tiled.frame = self.bounds
       // tiled.levelsOfDetailBias = 2
       // self.tiled.delegate = self
    }
    
    func update(with location:NSPoint) -> Bool {
        
        if self.mouse(location, in: self.visibleRect) {
            if let item = item as? EBlockItem {
                
                var point:NSPoint = location
                var ts:NSPoint = NSMakePoint(15, 0)
                var stop:Bool = false
                var xIndex:Int = 0
                var yIndex:Int = 0
                for line in item.lineAttr {
                    for _ in line {
                        
                        if point.x >= ts.x && point.x < ts.x + xAdd {
                            if point.y >= ts.y && point.y < ts.y + xAdd {
                                point = NSMakePoint(ts.x, ts.y )
                                stop = true
                                break
                            }
                        }

                        ts.x+=xAdd
                        xIndex += 1
                    }
                    if stop {
                        break
                    }
                    ts.y += yAdd 
                    ts.x = 15
                    yIndex += 1
                    xIndex = 0
                }
                
                if stop {
                    selectedEmoji = item.lineAttr[yIndex][xIndex].string
                }
                
                if point != button.frame.origin {
                    if self.button.isSelected {
                        button.layer?.animatePosition(from: button.frame.origin, to: point, duration: 0.1, timingFunction: kCAMediaTimingFunctionLinear)
                    }
                    button.frame = NSMakeRect(point.x, point.y, button.frame.width, button.frame.height)
                    
                    popover?.close()
                    self.popover = nil
                }
                
                if stop {
                    return true
                }
                
            }

        }
        
        return false
    }
    
    override func rightMouseUp(with event: NSEvent) {
        if selectedEmoji.emojiUnmodified != selectedEmoji, let item = item as? EBlockItem {
            popover?.close()
            popover = NSPopover()
            popover?.contentViewController = EmojiToleranceController(selectedEmoji.emojiUnmodified, postbox: item.account.postbox, handle: { [weak self, weak item] emoji in
                if let item = item {
                    _ = modifySkinEmoji(emoji, postbox: item.account.postbox).start()
                }
                self?.popover?.close()
                self?.popover = nil
            })
            popover?.show(relativeTo: NSZeroRect, of: button, preferredEdge: .minY)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        mouseDown = true
        
        self.button.isSelected = self.update(with: segmentView.convert(event.locationInWindow, from: nil))
        let emoji = selectedEmoji
        let lhs = emoji.emojiUnmodified.glyphCount
        let rhs = ( emoji.emojiUnmodified + "🏻").glyphCount
        longHandle.set((Signal<Void, Void>.single(Void()) |> delay(0.3, queue: Queue.mainQueue())).start(next: { [weak self] in
            if let strongSelf = self, lhs == rhs, let item = self?.item as? EBlockItem {
                strongSelf.useEmoji = false
                strongSelf.popover?.close()
                strongSelf.popover = NSPopover()
                strongSelf.popover?.contentViewController = EmojiToleranceController(emoji.emojiUnmodified, postbox: item.account.postbox, handle: { [weak strongSelf, weak item] emoji in
                    if let item = item {
                        _ = modifySkinEmoji(emoji, postbox: item.account.postbox).start()
                    }
                    strongSelf?.popover?.close()
                    strongSelf?.popover = nil
                })
                strongSelf.popover?.show(relativeTo: NSZeroRect, of: strongSelf.button, preferredEdge: .minY)
            }
        }))
        
       
        
    }
    
    override func mouseUp(with event: NSEvent) {
        mouseDown = false
        
        longHandle.set(nil)
        
        if let item = item as? EBlockItem, button.isSelected, useEmoji {
            item.selectHandler(selectedEmoji)
        }
        useEmoji = true
        button.isSelected = false
    }
    
    deinit {
        longHandle.dispose()
    }
    
    override func viewDidMoveToWindow() {
        if window == nil {
            popover?.close()
            popover = nil
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        self.button.isSelected = self.update(with: segmentView.convert(event.locationInWindow, from: nil))
    }
    
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        segmentView.layer?.rasterizationScale = CGFloat(backingScaleFactor)
        // tiled.levelsOfDetailBias = Int(System.backingScale)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
       
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
      //  tiled.frame = bounds
      //  tiled.tileSize = bounds.size
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        segmentView.frame = NSMakeRect(0, 0, item.width, item.height)
        segmentView.update(with: item as? EBlockItem)
        segmentView.background = .clear
    }
    
}
