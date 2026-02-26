//
//  File.swift
//  
//
//  Created by Mike Renoir on 03.01.2024.
//

import Foundation
import AppKit


public extension NSImage {
    func drawInRect(rect: CGRect, withCapInsets capInsets: NSEdgeInsets) {
        var rect = rect
        rect.origin.x = round(rect.origin.x)
        rect.origin.y = round(rect.origin.y)
        rect.size.width = round(rect.size.width)
        rect.size.height = round(rect.size.height)
        
        // Bottom left
        self.draw(in: NSRect(x: rect.origin.x, y: rect.origin.y,
                             width: capInsets.left, height: capInsets.bottom),
                  from: NSRect(x: 0.0, y: 0.0,
                               width: capInsets.left, height: capInsets.bottom),
                  operation: .sourceOver, fraction: 1.0)
        
        // Top left
        self.draw(in: NSRect(x: rect.origin.x, y: rect.origin.y + rect.size.height - capInsets.top,
                             width: capInsets.left, height: capInsets.top),
                  from: NSRect(x: 0.0, y: self.size.height - capInsets.top,
                               width: capInsets.left, height: capInsets.top),
                  operation: .sourceOver, fraction: 1.0)
        
        // Top right
        self.draw(in: NSRect(x: rect.origin.x + rect.size.width - capInsets.right, y: rect.origin.y + rect.size.height - capInsets.top,
                             width: capInsets.right, height: capInsets.top),
                  from: NSRect(x: self.size.width - capInsets.right, y: self.size.height - capInsets.top,
                               width: capInsets.right, height: capInsets.top),
                  operation: .sourceOver, fraction: 1.0)
        
        // Bottom right
        self.draw(in: NSRect(x: rect.origin.x + rect.size.width - capInsets.right, y: rect.origin.y,
                             width: capInsets.right, height: capInsets.bottom),
                  from: NSRect(x: self.size.width - capInsets.right, y: 0.0,
                               width: capInsets.right, height: capInsets.bottom),
                  operation: .sourceOver, fraction: 1.0)
        
        // Bottom center
        self.draw(in: NSRect(x: rect.origin.x + capInsets.left, y: rect.origin.y,
                             width: rect.size.width - capInsets.right - capInsets.left, height: capInsets.bottom),
                  from: NSRect(x: capInsets.left, y: 0.0,
                               width: self.size.width - capInsets.right - capInsets.left, height: capInsets.bottom),
                  operation: .sourceOver, fraction: 1.0)
        
        // Top center
        self.draw(in: NSRect(x: rect.origin.x + capInsets.left, y: rect.origin.y + rect.size.height - capInsets.top,
                             width: rect.size.width - capInsets.right - capInsets.left, height: capInsets.top),
                  from: NSRect(x: capInsets.left, y: self.size.height - capInsets.top,
                               width: self.size.width - capInsets.right - capInsets.left, height: capInsets.top),
                  operation: .sourceOver, fraction: 1.0)
        
        // Left center
        self.draw(in: NSRect(x: rect.origin.x, y: rect.origin.y + capInsets.bottom,
                             width: capInsets.left, height: rect.size.height - capInsets.top - capInsets.bottom),
                  from: NSRect(x: 0.0, y: capInsets.bottom,
                               width: capInsets.left, height: self.size.height - capInsets.top - capInsets.bottom),
                  operation: .sourceOver, fraction: 1.0)
        
        // Right center
        self.draw(in: NSRect(x: rect.origin.x + rect.size.width - capInsets.right, y: rect.origin.y + capInsets.bottom,
                             width: capInsets.right, height: rect.size.height - capInsets.top - capInsets.bottom),
                  from: NSRect(x: self.size.width - capInsets.right, y: capInsets.bottom,
                               width: capInsets.right, height: self.size.height - capInsets.top - capInsets.bottom),
                  operation: .sourceOver, fraction: 1.0)
        
        // Center center
        self.draw(in: NSRect(x: rect.origin.x + capInsets.left, y: rect.origin.y + capInsets.bottom,
                             width: rect.size.width - capInsets.right - capInsets.left, height: rect.size.height - capInsets.top - capInsets.bottom),
                  from: NSRect(x: capInsets.left, y: capInsets.bottom,
                               width: self.size.width - capInsets.right - capInsets.left, height: self.size.height - capInsets.top - capInsets.bottom),
                  operation: .sourceOver, fraction: 1.0)
    }
}

public class NinePathImage : NSView {
    
    public var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }
    public var capInsets: NSEdgeInsets = .init() {
        didSet {
            needsDisplay = true
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if let image = image {
            image.drawInRect(rect: self.bounds, withCapInsets: capInsets)
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public init() {
        super.init(frame: .zero)
        wantsLayer = true
    }
}
