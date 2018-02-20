
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
        
        for item in added {
            height += item.height
        }
        
        for item in removed {
            height -= item.height
        }
        
        if added.isEmpty && removed.isEmpty {
            return
        }
        
        let contentView = table.contentView
        let bounds = contentView.bounds
        
        let scrollBelow = self.scrollBelow || (bounds.minY - height) < 0
        
        
        if bounds.minY > height, scrollBelow {
//            height = bounds.minY
//            
//            let presentation = contentView.layer?.presentation()
//            if let presentation = presentation, contentView.layer?.animation(forKey:"bounds") != nil {
//                height += presentation.bounds.minY
//            }
//            
            
            table.scroll(to: .down(true))

            
            
        } else if height - bounds.height < table.frame.height, scrollBelow {
            
            
            if scrollBelow {
                contentView.bounds = NSMakeRect(0, 0, contentView.bounds.width, contentView.bounds.height)
            }
            
            let range:NSRange = table.visibleRows(height)
            
            for item in added {
                if item.index < range.location || item.index > range.location + range.length {
                    return
                }
            }
            
            CATransaction.begin()
            for idx in added[0].index ..< range.length {
                
                if let view = table.viewNecessary(at: idx), let layer = view.layer {
                    
                    var inset = (layer.frame.minY - height);
                    if let presentLayer = layer.presentation(), presentLayer.animation(forKey: "position") != nil {
                        inset = presentLayer.position.y
                    }
                    layer.animatePosition(from: NSMakePoint(0, inset), to: NSMakePoint(0, layer.position.y), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseOut)
                    
                    for item in added {
                        if item.index == idx {
                            layer.animateAlpha(from: 0, to: 1, duration: 0.2)
                        }
                    }
                    
                }
                
            }
            
            CATransaction.commit()
            
        } else if !scrollBelow {
            contentView.bounds = NSMakeRect(0, bounds.minY + height, contentView.bounds.width, contentView.bounds.height)
            table.reflectScrolledClipView(contentView)
        }

    }
    
    public func scroll(table:TableView, from:NSRect, to:NSRect) -> Void {
        table.contentView.layer?.animateBounds(from: from, to: to, duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseOut)
    }

    
}
