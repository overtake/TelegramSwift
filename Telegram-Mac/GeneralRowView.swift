//
//  GeneralRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class GeneralContainableRowView : TableRowView {
    let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let borderView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        super.addSubview(self.containerView)
        containerView.addSubview(borderView)
    }
    
    deinit {
        self.containerView.removeAllSubviews()
    }
    
    override func addSubview(_ view: NSView) {
        self.containerView.addSubview(view)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? GeneralRowItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
        self.borderView.backgroundColor = theme.colors.border
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {
            return
        }
        let blockWidth = min(600, frame.width - item.inset.left - item.inset.right)
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - blockWidth) / 2), item.inset.top, blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        borderView.frame = NSMakeRect(item.viewType.innerInset.left, containerView.frame.height - .borderSize, containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, .borderSize)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        
        borderView.isHidden = !item.viewType.hasBorder
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class GeneralRowContainerView : Control {
    private let maskLayer = CAShapeLayer()
    private var newPath: CGPath?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.mask = maskLayer
    }
    
    private var corners: GeneralViewItemCorners? = nil
    func setCorners(_ corners: GeneralViewItemCorners, animated: Bool = false, frame: NSRect? = nil) {
        if animated && self.corners != nil {
            let newPath = self.createMask(for: corners, frame: frame ?? self.frame)
            
            var oldPath: CGPath = self.maskLayer.path ?? CGMutablePath()
            
            if let presentation = self.maskLayer.presentation(), let _ = self.maskLayer.animation(forKey:"path") {
                oldPath = presentation.path ?? oldPath
                if newPath == self.newPath {
                    self.corners = corners
                    return
                }
            }
            self.newPath = newPath
            
            self.maskLayer.animate(from: oldPath, to: newPath, keyPath: "path", timingFunction: .easeOut, duration: 0.18, removeOnCompletion: false, additive: false, completion: { [weak self] completed in
                if completed {
                    self?.maskLayer.removeAllAnimations()
                }
                self?.maskLayer.path = newPath
            })
            
        } else {
            self.maskLayer.path = createMask(for: corners, frame: frame ?? self.bounds)
        }
        self.corners = corners
    }
    private func createMask(for corners: GeneralViewItemCorners, frame: NSRect) -> CGPath {
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
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    func change(size: NSSize, animated: Bool, corners: GeneralViewItemCorners) {
        super._change(size: size, animated: animated, animated, duration: 0.18)
        setCorners(corners, animated: animated, frame: NSMakeRect(0, 0, size.width, size.height))
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
            
            let minX = (frame.width - item.blockWidth) / 2

            
            if let errorLayout = item.errorLayout {
                let alphaAnimated = animated && errorTextView == nil
                let posAnimated = animated && errorTextView != nil
                if errorTextView == nil {
                    errorTextView = TextView()
                    errorTextView?.isSelectable = false
                    addSubview(errorTextView!)
                }
                errorTextView!.update(errorLayout)
                switch item.viewType {
                case .legacy:
                    errorTextView!.change(pos: NSMakePoint(item.inset.left, frame.height - 6 - errorLayout.layoutSize.height), animated: posAnimated)
                case let .modern(_, insets):
                    errorTextView!.change(pos: NSMakePoint(minX + insets.left, frame.height - 2 - errorLayout.layoutSize.height), animated: posAnimated)
                }
                if alphaAnimated {
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

        let minX = (frame.width - item.blockWidth) / 2
        
        if let errorTextView = errorTextView {
            switch item.viewType {
            case .legacy:
                errorTextView.setFrameOrigin(item.inset.left, frame.height - 6 - errorTextView.frame.height)
            case let .modern(_, insets):
                errorTextView.setFrameOrigin(minX + insets.left, frame.height - 2
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
