//
//  GeneralRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



final class GeneralRowContainerView : Control {
    private let maskLayer = CAShapeLayer()
    
    private var corners: GeneralViewItemCorners = []
    func setCorners(_ corners: GeneralViewItemCorners, animated: Bool = false) {
        self.corners = corners
        if animated {
            let animation = CABasicAnimation();
            animation.duration = 0.2
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.keyPath = "path";
            let newPath = self.createMask()
            animation.fromValue = self.maskLayer.path
            animation.toValue = newPath
            self.maskLayer.path = newPath
            self.maskLayer.add(animation, forKey: "path")
        } else {
            maskLayer.path = createMask()
            layer?.mask = maskLayer
        }
        
    }
    private func createMask() -> CGPath {
        let path = CGMutablePath()
        
        let minx:CGFloat = 0, midx = frame.width/2.0, maxx = frame.width
        let miny:CGFloat = 0, midy = frame.height/2.0, maxy = frame.height
        
        path.move(to: NSMakePoint(minx, midy))
        
        var topLeftRadius: CGFloat = 0
        var bottomLeftRadius: CGFloat = 0
        var topRightRadius: CGFloat = 0
        var bottomRightRadius: CGFloat = 0
        
        
        if corners.contains(.topLeft)  {
            bottomLeftRadius = 10
        }
        if corners.contains(.topRight) {
            bottomRightRadius = 10
        }
        if corners.contains(.bottomLeft) {
            topLeftRadius = 10
        }
        if corners.contains(.bottomRight) {
            topRightRadius = 10
        }
        
        path.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
        path.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
        path.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topRightRadius)
        path.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topLeftRadius)
        
        
        return path
    }
    
    override func change(size: NSSize, animated: Bool, _ save: Bool = true, removeOnCompletion: Bool = true, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = .easeOut, completion: ((Bool) -> Void)? = nil) {
        super.change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
        
        let animation = CABasicAnimation();
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)
        animation.keyPath = "path";
        
        let newPath = self.createMask()
        
        animation.fromValue = self.maskLayer.path
        animation.toValue = newPath
        
        self.maskLayer.path = newPath
        self.maskLayer.add(animation, forKey: "path")
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class GeneralRowView: TableRowView,ViewDisplayDelegate {
    

     private var errorTextView: TextView? = nil
    
    var general:GeneralRowItem? {
        return self.item as? GeneralRowItem
    }
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    override var firstResponder: NSResponder? {
        return nil
    }
    
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        if let item = item as? GeneralRowItem {
            self.border = item.border
            
            if let errorLayout = item.errorLayout {
                if errorTextView == nil {
                    errorTextView = TextView()
                    errorTextView?.isSelectable = false
                    errorTextView?.setFrameOrigin(item.inset.left, frame.height - 6 - errorLayout.layoutSize.height)
                    addSubview(errorTextView!)
                }
                errorTextView!.update(errorLayout)
                errorTextView!.change(pos: NSMakePoint(item.inset.left, frame.height - 6 - errorLayout.layoutSize.height), animated: animated)

                if animated {
                    errorTextView!.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            } else {
                if let errorTextView = self.errorTextView {
                    if animated {
                        self.errorTextView = nil
                        errorTextView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, completion: { [weak errorTextView] _ in
                            errorTextView?.removeFromSuperview()
                        })
                    } else {
                        errorTextView.removeFromSuperview()
                        self.errorTextView = nil
                    }
                }
                
            }
        }
        self.needsDisplay = true
        self.needsLayout = true
    }

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        if backingScaleFactor == 1.0 {
            ctx.setFillColor(backdorColor.cgColor)
            ctx.fill(layer.bounds)
        }
        super.draw(layer, in: ctx)
    }
    


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
     //   let inset = general?.inset ?? NSEdgeInsets()
      //  overlay.frame = NSMakeRect(inset.left, 0, newSize.width - (inset.left + inset.right), newSize.height)
    }
    
    override func layout() {
        
        guard let item = item as? GeneralRowItem else {return}

        
        if let errorTextView = errorTextView {
            switch item.viewType {
            case .legacy:
                errorTextView.setFrameOrigin(item.inset.left, frame.height - 6 - errorTextView.frame.height)
            case let .modern(_, insets):
                errorTextView.setFrameOrigin(item.inset.left + insets.left, frame.height - 2
                    - errorTextView.frame.height)
            }
        }
    }
    
    override var backdorColor: NSColor {
        
        guard let item = self.item as? GeneralRowItem else {
            return .clear
        }
        return item.backgroundColor
    }
    
}
