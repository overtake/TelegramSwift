
//
//  TableAnimationInterface.swift
//  TGUIKit
//
//  Created by keepcoder on 02/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TableAnimationInterface: NSObject {
    
    public let scrollBelow:Bool
    public let saveIfAbove:Bool
    public init(_ scrollBelow:Bool = true, _ saveIfAbove:Bool = true) {
        self.scrollBelow = scrollBelow
        self.saveIfAbove = saveIfAbove
    }

    public func animate(table:TableView, added:[TableRowItem], removed:[TableRowItem]) -> Void {
        
        var height:CGFloat = 0
        
        
       
        
        let contentView = table.contentView
        let bounds = contentView.bounds
        
        var scrollBelow = self.scrollBelow || (bounds.minY - height) < 0
        var checkBelowAfter: Bool = false
        
        if scrollBelow {
            contentView.bounds = NSMakeRect(0, 0, contentView.bounds.width, contentView.bounds.height)
            contentView.layer?.removeAllAnimations()
        } else {
            checkBelowAfter = true
        }
        
        let range:NSRange = table.visibleRows(height)
        
        let added = added.filter { item in
            if item.index < range.location || item.index > range.location + range.length {
                return false
            } else {
                return true
            }
        }
        
        let removed = removed.filter { item in
            if item.index < range.location || item.index > range.location + range.length {
                return false
            } else {
                return true
            }
        }
        
        for item in added {
            height += item.height
        }
        
        for item in removed {
            height -= item.height
        }
        
        if added.isEmpty && removed.isEmpty {
            return
        }
        
        
        scrollBelow = scrollBelow || (checkBelowAfter && (bounds.minY - height) < 0)
      
        if height - bounds.height < table.frame.height || bounds.minY > height, scrollBelow {
            
            contentView.bounds = NSMakeRect(0, 0, contentView.bounds.width, contentView.bounds.height)
            
            if range.length >= added[0].index {
                for idx in added[0].index ..< range.length {
                    
                    if let view = table.viewNecessary(at: idx), let layer = view.layer {
                        
                        var inset = (layer.frame.minY - height);
                        //   if let presentLayer = layer.presentation(), presentLayer.animation(forKey: "position") != nil {
                        // inset = presentLayer.position.y
                        // }
                        //NSMakePoint(0, layer.position.y)
                        layer.animatePosition(from: NSMakePoint(0, -height), to: NSZeroPoint, duration: 0.2, timingFunction: .easeOut, additive: true)
                        
                        for item in added {
                            if item.index == idx {
                                //layer.animateAlpha(from: 0, to: 1, duration: 0.2)
                            }
                        }
                        
                    }
                }
            }
            
        } else if !scrollBelow {
            contentView.bounds = NSMakeRect(0, bounds.minY + height, contentView.bounds.width, contentView.bounds.height)
            table.reflectScrolledClipView(contentView)
        }

    }
    
    public func scroll(table:TableView, from:NSRect, to:NSRect) -> Void {
        table.contentView.layer?.animateBounds(from: from, to: to, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut)
    }

    
}
