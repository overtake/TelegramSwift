//
//  NavigationBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public struct NavigationBarStyle {
    public let height:CGFloat
    public let enableBorder:Bool
    public init(height:CGFloat, enableBorder:Bool = true) {
        self.height = height
        self.enableBorder = enableBorder
    }
}

public class NavigationBarView: View {
    
    private var bottomBorder:View = View()
    
    private var leftView:BarView = BarView(frame: NSZeroRect)
    private var centerView:BarView = BarView(frame: NSZeroRect)
    private var rightView:BarView = BarView(frame: NSZeroRect)
    
    override init() {
        super.init()
        self.autoresizingMask = [.width]
        updateLocalizationAndTheme()
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.autoresizingMask = [.width]
        updateLocalizationAndTheme()
    }
    
    override public func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        bottomBorder.backgroundColor = presentation.colors.border
        backgroundColor = presentation.colors.background
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        super.draw(layer, in: ctx)
//        ctx.setFillColor(NSColor.white.cgColor)
//        ctx.fill(self.bounds)
//
//        ctx.setFillColor(theme.colors.border.cgColor)
//        ctx.fill(NSMakeRect(0, NSHeight(self.frame) - .borderSize, NSWidth(self.frame), .borderSize))
    }
    
    override public func layout() {
        super.layout()
        self.bottomBorder.setNeedsDisplay()
    }

    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.bottomBorder.frame = NSMakeRect(0, newSize.height - .borderSize, newSize.width, .borderSize)
        self.layout(left: leftView, center: centerView, right: rightView)
    }
    
    public override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    
    func layout(left: BarView, center: BarView, right: BarView) -> Void {
        if frame.height > 0 {
            //proportions = 50 / 25 / 25
            
            
            let leftWidth = left.isFitted ? left.frame.width : left.fit(to: (right.frame.width == right.minWidth ? frame.width / 3 : frame.width / 4))
            let rightWidth = right.isFitted ? right.frame.width : right.fit(to: (left.frame.width == left.minWidth ? frame.width / 3 : frame.width / 4))
            
            left.frame = NSMakeRect(0, 0, leftWidth, frame.height - .borderSize);
            center.frame = NSMakeRect(left.frame.maxX, 0, frame.width - (leftWidth + rightWidth), frame.height - .borderSize);
            right.frame = NSMakeRect(center.frame.maxX, 0, rightWidth, frame.height - .borderSize);
        }
    }
    
    // ! PUSH !
    //  left from center
    //  right cross fade
    //  center from right
    
    // ! POP !
    // old left -> new center
    // old center -> right
    // old right -> fade
    
    @objc func viewFrameChanged(_ notification:Notification) {
       layout(left: leftView, center: centerView, right: rightView)
    }
    
    public func switchViews(left:BarView, center:BarView, right:BarView, controller:ViewController, style:ViewControllerStyle, animationStyle:AnimationStyle) {
        
        layout(left: left, center: center, right: right)
        self.bottomBorder.isHidden = !controller.bar.enableBorder
        if style != .none {
            
            
            NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: leftView)
            NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: centerView)
            NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: rightView)
            
            NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: left)
            NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: center)
            NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: NSView.frameDidChangeNotification, object: right)

            
            CATransaction.begin()
            
            self.addSubview(left)
            self.addSubview(center)
            self.addSubview(right)
            self.addSubview(bottomBorder)
            
            left.setNeedsDisplay()
            center.setNeedsDisplay()
            right.setNeedsDisplay()
            
            let pLeft = self.leftView
            let pCenter = self.centerView
            let pRight = self.rightView
            
            pLeft.updateLocalizationAndTheme()
            pCenter.updateLocalizationAndTheme()
            pRight.updateLocalizationAndTheme()
            
            self.leftView = left
            self.centerView = center
            self.rightView = right
            
            var pLeft_from:CGFloat = 0,pRight_from:CGFloat = 0, pCenter_from:CGFloat = 0, pLeft_to:CGFloat = 0, pRight_to:CGFloat = 0, pCenter_to:CGFloat = 0
            var nLeft_from:CGFloat = 0, nRight_from:CGFloat = 0, nCenter_from:CGFloat = 0, nLeft_to:CGFloat = 0, nRight_to:CGFloat = 0, nCenter_to:CGFloat = 0
            
            switch style {
            case .push:
                
                //left
                pLeft_from = 0
                pLeft_to = 0
                nLeft_from = round(NSWidth(self.frame) - NSWidth(left.frame))/2.0
                nLeft_to = 0
                
                //center
                pCenter_from = NSMinX(pCenter.frame)
                pCenter_to = 0
                nCenter_from = NSMinX(right.frame)
                nCenter_to = NSMaxX(left.frame)
                
                //right
                pRight_from = NSMinX(right.frame)
                pRight_to = NSMinX(right.frame)
                nRight_from = NSMinX(right.frame)
                nRight_to = NSMinX(right.frame)
                
                break
            case .pop:
                
                //left
                pLeft_from = 0
                pLeft_to = 0
                nLeft_from = 0
                nLeft_to = 0
                
                //center
                pCenter_from = NSMinX(center.frame)
                pCenter_to = NSMinX(right.frame)
                nCenter_from = 0
                nCenter_to = NSMaxX(left.frame)
                
                //right
                pRight_from = NSMinX(right.frame)
                pRight_to = NSMinX(right.frame)
                nRight_from = NSMinX(right.frame)
                nRight_to = NSMinX(right.frame)

                
                break
            case .none:
                break
            }
            
            
            // old
            pLeft.layer?.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion: false, completion:{ [weak pLeft] (completed) in
                if completed {
                    pLeft?.removeFromSuperview()
                }
            })
            pLeft.layer?.animate(from: pLeft_from as NSNumber, to: pLeft_to as NSNumber, keyPath: "position.x", timingFunction: kCAMediaTimingFunctionSpring, duration: animationStyle.duration)
            
            pCenter.layer?.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: kCAMediaTimingFunctionSpring, duration: animationStyle.duration, removeOnCompletion: false, completion:{ [weak pCenter] (completed) in
                if completed {
                    pCenter?.removeFromSuperview()
                }
            })
            pCenter.layer?.animate(from: pCenter_from as NSNumber, to: pCenter_to as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration)
            
            pRight.layer?.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: kCAMediaTimingFunctionSpring, duration: animationStyle.duration, removeOnCompletion: false, completion:{ [weak pRight] (completed) in
                if completed {
                    pRight?.removeFromSuperview()
                }
            })
            pRight.layer?.animate(from: pRight_from as NSNumber, to: pRight_to as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration)
            
            // new
            if !left.isHidden {
                left.layer?.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: kCAMediaTimingFunctionSpring, duration: animationStyle.duration)
            }
            left.layer?.animate(from: nLeft_from as NSNumber, to: nLeft_to as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration)
            if !center.isHidden {
                center.layer?.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: kCAMediaTimingFunctionSpring, duration: animationStyle.duration)
            }
            center.layer?.animate(from: nCenter_from as NSNumber, to: nCenter_to as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration)
            
            if !right.isHidden {
                right.layer?.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: kCAMediaTimingFunctionSpring, duration: animationStyle.duration)
            }
            right.layer?.animate(from: nRight_from as NSNumber, to: nRight_to as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration)
            
            
            
            CATransaction.commit()

        } else {
            self.removeAllSubviews()
            self.addSubview(left)
            self.addSubview(center)
            self.addSubview(right)
            
            self.leftView = left
            self.centerView = center
            self.rightView = right
            
            self.addSubview(bottomBorder)
        }
        
        
        
    }
    
}
