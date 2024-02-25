//
//  OverlayControl.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class OverlayControl: Control {

    public var externalScroll: ((NSEvent)->Void)? = nil
    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        super.updateTrackingAreas();
        
        
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        trackingArea = nil
        
        if let _ = window {
            let options:NSTrackingArea.Options = [NSTrackingArea.Options.cursorUpdate, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.mouseMoved, NSTrackingArea.Options.activeInKeyWindow]
            self.trackingArea = NSTrackingArea.init(rect: self.bounds, options: options, owner: self, userInfo: nil)
            
            self.addTrackingArea(self.trackingArea!)
        }
    }
    
    deinit {
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
    }
    
    override open func mouseInside() -> Bool {
        if let window = self.window {
            var location:NSPoint = window.mouseLocationOutsideOfEventStream
            location = self.convert(location, from: nil)
            
            return NSPointInRect(location, self.bounds)
            
        }
        return false
    }
    
    open override func rightMouseDown(with event: NSEvent) {
        if userInteractionEnabled {
            updateState()
        } else {
            super.rightMouseDown(with: event)
        }
    }
    
    open override func scrollWheel(with event: NSEvent) {
        if let externalScroll = externalScroll {
            externalScroll(event)
            return
        }
        if userInteractionEnabled, handleScrollEventOnInteractionEnabled {
            updateState()
        } else {
            super.scrollWheel(with: event)
        }
    }

    
}
