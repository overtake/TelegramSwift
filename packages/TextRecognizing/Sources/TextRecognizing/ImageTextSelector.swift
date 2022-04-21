//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 22.11.2021.
//

import Foundation
import Cocoa
import TGUIKit

@available(macOS 10.15, *)
public extension TextRecognizing {
    
    final class ImageTextSelector : View {
        
        private var trackingArea:NSTrackingArea?

        
        public private(set) var result: Result?
        private var showRects: Bool = false
        private var startPoint: NSPoint? = nil
        private var currentPoint: NSPoint? = nil
        private var finished: Bool = false
        private let linearProgress = LinearProgressControl(progressHeight: 2)
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
        
        public func set(_ result: Result?, showRects: Bool = false) {
            self.result = result
            self.showRects = showRects
            self.userInteractionEnabled = result != nil
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
