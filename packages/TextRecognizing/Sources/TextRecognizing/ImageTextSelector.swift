//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 22.11.2021.
//

import Foundation
import Cocoa
import TGUIKit
import AppKit



@available(macOS 10.15, *)
public extension TextRecognizing {
    
    final class ImageTextSelector : View {
        
        class TranslateView : View {
            
            
            private class DrawingTextLayer: SimpleLayer {
                let textView = TextView()
                override init() {
                    super.init()
                    textView.lockDrawingLayer = true
                    self.addSublayer(textView.drawingLayer)
                    
                    textView.drawingLayer.transform = CATransform3DMakeRotation(.pi, 1, 0, 0)
                }
                
                required init?(coder: NSCoder) {
                    fatalError("init(coder:) has not been implemented")
                }
                func set(translated: TextRecognizing.TranslateResult.Value, rect: NSRect, maxWidth: CGFloat) -> NSRect {
                    
                    let font = fontSizeThatFits(text: translated.text, in: rect, initialFont: .medium(30), minFontSize: 10)
                    
                    let textLayout = TextViewLayout(.initialize(string: translated.text, color: NSColor.black, font: font), maximumNumberOfLines: 1)
                    
                    textLayout.measure(width: maxWidth - rect.minX)
                    textView.update(textLayout)
                    
                    textView.drawingLayer.frame = textLayout.layoutSize.bounds //rect.focusY(textLayout.layoutSize, x: 0)
                    
                    return NSMakeRect(rect.minX, rect.minY, max(textView.frame.width, rect.width), max(textView.frame.height, rect.height))
                }
            }
            
            private var shimmers: [ShimmerLayer] = []
            private var texts: [DrawingTextLayer] = []
            
            private var backgroundImage: SimpleLayer?

            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                isEventLess = true
            }
            
            override var isFlipped: Bool {
                return false
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func set(_ translate: TranslateResult) {
                                
                switch translate {
                case let .progress(result):
                    
                    if let backgroundImage {
                        performSublayerRemoval(backgroundImage, animated: true)
                    }
                    
                    for text in texts {
                        performSublayerRemoval(text, animated: true)
                    }
                    
                    let rects = result.selectableRects(viewSize: bounds.size)
                    let rotations = result.rotations()
                    
                    while shimmers.count > rects.count {
                        shimmers[shimmers.count - 1].removeFromSuperlayer()
                    }
                    while shimmers.count < rects.count {
                        let current = ShimmerLayer()
                        shimmers.append(current)
                        self.layer?.addSublayer(current)
                        current.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                    
                    for (i, shimmerView) in shimmers.enumerated() {
                        let value = rects[i]
                        let rotation = rotations[i]
                        shimmerView.cornerRadius = 4
                        shimmerView.masksToBounds = true
                        shimmerView.update(backgroundColor: .blackTransparent, data: nil, size: value.size, imageSize: value.size)
                        shimmerView.updateAbsoluteRect(value.size.bounds, within: value.size)
                        shimmerView.frame = value
                        shimmerView.transform = CATransform3DMakeRotation(rotation, 0, 0, 1)
                    }
                    
                case let .success(translated, result):
                    for shimmer in shimmers {
                        performSublayerRemoval(shimmer, animated: true)
                    }
                    
                    var rects = result.selectableRects(viewSize: bounds.size)
                    let rotations = result.rotations()

                    while texts.count < rects.count {
                        let current = DrawingTextLayer()
                        texts.append(current)
                        self.layer?.addSublayer(current)
                        current.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                    for (i, text) in texts.enumerated() {
                        let rotation = rotations[i]
                        
                        rects[i] = text.set(translated: translated[i], rect: rects[i], maxWidth: frame.width)
                        text.frame = rects[i]
                        text.transform = CATransform3DMakeRotation(rotation, 0, 0, 1)
                    }
                    
                    do {
                        let current: SimpleLayer
                        if let layer = self.backgroundImage {
                            current = layer
                        } else {
                            current = SimpleLayer()
                            self.backgroundImage = current
                            self.layer?.insertSublayer(current, at: 0)
                            current.animateAlpha(from: 0, to: 1, duration: 0.2)
                        }
                        current.frame = self.bounds
                        
                        current.contents = generateImage(self.bounds.size, contextGenerator: { size, ctx in
                            ctx.clear(size.bounds)
                            ctx.setFillColor(.white)
                            for (index, rect) in rects.enumerated() {
                                let rect = rect.insetBy(dx: -4, dy: -4)
                                let rotationAngle = rotations[index]

                                ctx.saveGState()

                                let centerX = rect.midX
                                let centerY = rect.midY
                                ctx.translateBy(x: centerX, y: centerY)
                                ctx.rotate(by: rotationAngle)
                                ctx.translateBy(x: -centerX, y: -centerY)
                                ctx.fill(rect)
                                ctx.setFillColor(NSColor.grayForeground.withAlphaComponent(0.5).cgColor)
                                ctx.fill(rect)
                                ctx.restoreGState()
                            }
                        })
                    }

                }
            }
            
            override func layout() {
                super.layout()
            }
        }
        
        
        private var trackingArea:NSTrackingArea?

        
        public private(set) var result: Result?
        private var showRects: Bool = false
        private var translate: TranslateResult? = nil
        private var startPoint: NSPoint? = nil
        private var currentPoint: NSPoint? = nil
        private var finished: Bool = false
        private let linearProgress = LinearProgressControl(progressHeight: 2)
        
        private var translateView: TranslateView?
        
        public required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(linearProgress)
            linearProgress.style = .init(foregroundColor: NSColor.systemBlue.withAlphaComponent(0.6))
        }
        
        public override func updateTrackingAreas() {
            super.updateTrackingAreas();
            
            if let trackingArea = trackingArea {
                self.removeTrackingArea(trackingArea)
            }
            
            trackingArea = nil
            
            if let _ = window {
                let options:NSTrackingArea.Options = [NSTrackingArea.Options.cursorUpdate, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.mouseMoved, NSTrackingArea.Options.activeInKeyWindow, NSTrackingArea.Options.inVisibleRect]
                self.trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
                
                self.addTrackingArea(self.trackingArea!)
            }
            
        }
        
        public override func mouseUp(with event: NSEvent) {
            //super.mouseUp(with: event)
            self.finishSelect(event)
        }
        public override func mouseDown(with event: NSEvent) {
            super.mouseDown(with: event)
            self.startSelect(event)
        }
        public override func mouseDragged(with event: NSEvent) {
            super.mouseDragged(with: event)
            self.processSelect(event)
        }

        public override func mouseEntered(with event: NSEvent) {
            super.mouseEntered(with: event)
            self.cursorUpdate(with: event)
        }
        
        public override func mouseExited(with event: NSEvent) {
            super.mouseExited(with: event)
            self.cursorUpdate(with: event)
        }
        
        public override func mouseMoved(with event: NSEvent) {
            super.mouseMoved(with: event)
            self.cursorUpdate(with: event)
        }
        
        public override func cursorUpdate(with event: NSEvent) {
            super.cursorUpdate(with: event)
            
            guard let result = result else {
                return
            }
            
            var cursor: NSCursor = NSCursor.arrow
            
            let point = self.convert(event.locationInWindow, from: nil)
            let paths = result.selectablePaths(viewSize: self.frame.size)
            
            for path in paths {
                if path.contains(point) {
                    cursor = NSCursor.iBeam
                    break
                }
            }
            cursor.set()
        }
        
        private var realStartPoint: NSPoint?
        private func startSelect(_ event: NSEvent) {
            self.realStartPoint = self.convert(event.locationInWindow, from: nil)
        }
        private func processSelect(_ event: NSEvent) {
            let current = self.convert(event.locationInWindow, from: nil)
            if let from = self.realStartPoint {
                let w = max(current.x, from.x) - min(current.x, from.x)
                let h = max(current.y, from.y) - min(current.y, from.y)
                if w < 1 && h < 1 {
                    return
                }
            }
            
            if self.finished || self.startPoint == nil {
                self.startPoint = self.convert(event.locationInWindow, from: nil)
            }
            self.currentPoint = current
            self.finished = false
            self.needsDisplay = true
        }
        private func finishSelect(_ event: NSEvent) {
            if self.finished || (result == nil || result!.inProgress) {
                cancelSelection()
            } else {
                self.finished = true
                self.realStartPoint = nil
                self.needsDisplay = true
            }
           
        }
        
        public override func layout() {
            super.layout()
            linearProgress.frame = NSMakeRect(0, 0, frame.width, linearProgress.frame.height)
            translateView?.frame = bounds
        }
        
        public override var isFlipped: Bool {
            return false
        }
                
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public override func draw(_ layer: CALayer, in ctx: CGContext) {
            super.draw(layer, in: ctx)
            guard let result = result else {
                return
            }
            
            
            if self.showRects {
                let paths = result.selectablePaths(viewSize: self.frame.size)
                for path in paths {
                    ctx.setFillColor(NSColor.white.withAlphaComponent(0.2).cgColor)
                    ctx.addPath(path)
                    ctx.fillPath()
                }
            }
            
            if let updated = self.selectedResult {
                
                if !self.finished {
                    if let from = self.startPoint, let to = self.currentPoint {
                        let selected = NSMakeRect(min(from.x, to.x), min(from.y, to.y), max(from.x, to.x) - min(from.x, to.x), max(from.y, to.y) - min(from.y, to.y))
                        ctx.setFillColor(NSColor.lightGray.withAlphaComponent(0.6).cgColor)
                        ctx.fill(selected)
                    }
                }
                
                let paths = updated.selectablePaths(viewSize: self.frame.size)
                for path in paths {
                    ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.4).cgColor)
                    ctx.addPath(path)
                    ctx.fillPath()
                }
            }
        }
        
        var selectedResult: Result? {
            if let from = self.startPoint, let to = self.currentPoint, let result = self.result {
                return result.select(from: from, to: to, viewSize: self.frame.size)
            }
            return nil
        }
        
        public func set(_ result: Result?, translate: TranslateResult? = nil, showRects: Bool = false) {
            self.result = result
            self.showRects = showRects
            self.translate = translate
            self.userInteractionEnabled = result != nil && translate == nil
            self.isEventLess = result == nil
            
            if let result = result {
                switch result {
                case let .progress(progress):
                    self.linearProgress.set(progress: CGFloat(progress), animated: true)
                    self.linearProgress.change(opacity: 1)
                default:
                    self.linearProgress.change(opacity: 0)
                }
            }
            
            if let translate {
                let current: TranslateView
                if let view = self.translateView {
                    current = view
                } else {
                    current = TranslateView(frame: bounds)
                    self.translateView = current
                    addSubview(current)
                }
                current.set(translate)
            } else if let view = self.translateView {
                performSubviewRemoval(view, animated: false)
                self.translateView = nil
            }
            
            needsDisplay = true
        }
        
        public var hasSelectedText: Bool {
            if let selectedResult = selectedResult {
                return !selectedResult.selectablePaths(viewSize: self.frame.size).isEmpty
            }
            return false
        }
        public func cancelSelection() {
            self.startPoint = nil
            self.currentPoint = nil
            self.realStartPoint = nil
            self.finished = false
            self.needsDisplay = true
        }
        public func copySelectedText() -> Bool {
            if let selectedText = self.selectedText {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(selectedText, forType: .string)
                return true
            }
            return false
        }
        
        public var selectedText: String? {
            if let selectedResult = self.selectedResult {
                switch selectedResult {
                case let .finish(_, texts):
                    if !texts.isEmpty {
                        var string: String = ""
                        for value in texts {
                            string += value.text
                            if value != texts.last {
                                string += "\n"
                            }
                        }
                        return string
                    }
                default:
                    break
                }
            }
            return nil
        }
    }
    
}
