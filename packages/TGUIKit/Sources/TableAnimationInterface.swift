
//
//  TableAnimationInterface.swift
//  TGUIKit
//
//  Created by keepcoder on 02/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TableAnimationInterface: NSObject {
    
    public struct AnimateItem {
        public let index: Int
        public let from: NSPoint
        public let to: NSPoint
    }
    
    public let scrollBelow:Bool
    public let saveIfAbove:Bool
    let animate:([AnimateItem])->Void
    public init(_ scrollBelow:Bool = true, _ saveIfAbove:Bool = true, _ animate:@escaping([AnimateItem])->Void) {
        self.scrollBelow = scrollBelow
        self.saveIfAbove = saveIfAbove
        self.animate = animate
    }

    @discardableResult public func animate(table:TableView, documentOffset: NSPoint, added:[TableRowItem], removed:[TableRowItem], previousRange: NSRange = NSMakeRange(NSNotFound, 0)) -> [AnimateItem] {
        
        var height:CGFloat = 0
        
        let contentView = table.clipView
        let bounds = contentView.bounds
        
        var scrollBelow = self.scrollBelow || (bounds.minY - height) < 0
        var checkBelowAfter: Bool = false
        
       
        
        var range:NSRange = table.visibleRows(height)
        
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
            height += item.heightValue
        }
        
        for item in removed {
            height -= item.heightValue
        }
        
        if previousRange.length == 0  {
            return []
        }
        
        range = table.visibleRows(height)
        
        if added.isEmpty && removed.isEmpty {
            return []
        }
        
        if scrollBelow, documentOffset.y >= 0 {
            table.tile()
            contentView.updateBounds(to: NSMakePoint(0, min(0, documentOffset.y)))
        } else {
            checkBelowAfter = true
        }
        
        var animatedItems:[AnimateItem] = []
        
        scrollBelow = scrollBelow || (checkBelowAfter && (bounds.minY - height) < 0)
      
        if height - bounds.height < table.frame.height || bounds.minY > height, scrollBelow {
            
            contentView.updateBounds(to: NSMakePoint(0, min(0, documentOffset.y)))
            
            if range.length >= added[0].index {
                for idx in added[0].index ..< range.length {
                    
                    if let view = table.viewNecessary(at: idx), let layer = view.layer {
                        
                        var inset = (layer.frame.minY - height);
                        if let presentLayer = layer.presentation(), presentLayer.animation(forKey: "position") != nil {
                            inset = presentLayer.position.y
                         }
                        
                        let from: CGPoint = NSMakePoint(0, inset)
                        let to: CGPoint = NSMakePoint(0, layer.position.y)
                        
                        
                      //  if layer.presentation()?.animation(forKey: "position") == nil {
                            layer.animatePosition(from: from, to: to, duration: 0.2, timingFunction: .easeOut)
                      //  }
                        
                        animatedItems.append(AnimateItem(index: added[0].index, from: from, to: to))
                        
                        /*
                         if layer.presentation()?.animation(forKey: "position") == nil {
                         layer.animatePosition(from: NSMakePoint(0, -height), to: NSZeroPoint, duration: 0.2, timingFunction: .easeOut, additive: true)
                         }
 */
                        
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

        if !animatedItems.isEmpty {
            self.animate(animatedItems)
        }
        return animatedItems
    }
    
    public func scroll(table:TableView, from:NSRect, to:NSRect) -> Void {
        table.contentView.layer?.animateBounds(from: from, to: to, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut)
    }

    
}
