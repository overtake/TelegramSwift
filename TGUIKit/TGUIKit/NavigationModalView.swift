//
//  NavigationModalView.swift
//  TGUIKit
//
//  Created by keepcoder on 01/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

class NavigationModalView: Control {
    
    private var textNode:TextNode = TextNode()
    private var attributeString:NSAttributedString
    
    let action:NavigationModalAction
    weak var viewController:NavigationViewController?
    
    private var lock:Bool = false
    
    init(action:NavigationModalAction, viewController:NavigationViewController) {
        self.action = action
        
        let attr:NSMutableAttributedString = NSMutableAttributedString()
        _ = attr.append(string: action.reason, color: presentation.colors.text, font: .normal(20.0))
        _ = attr.append(string: "\n")
        _ = attr.append(string: action.desc, color: presentation.colors.grayText, font: .normal(.text))
        
        self.attributeString = attr.copy() as! NSAttributedString
        
        
        self.viewController = viewController
        //  viewController.navigationController?.lock = true
        
        super.init()
        self.autoresizingMask = [.width, .height]
        
        set(handler: { control in
            let control = control as! NavigationModalView
            if !control.lock {
                control.close()
            }
        }, for: .Click)
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        let attr:NSMutableAttributedString = NSMutableAttributedString()
        
        _ = attr.append(string: action.reason, color: presentation.colors.text, font: .normal(20.0))
        _ = attr.append(string: "\n")
        _ = attr.append(string: action.desc, color: presentation.colors.grayText, font: .normal(.text))
        
        self.attributeString = attr.copy() as! NSAttributedString
        self.backgroundColor = .clear
        needsDisplay = true
    }
    
    override func scrollWheel(with event: NSEvent) {
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        ctx.setFillColor(presentation.colors.background.withAlphaComponent(0.9).cgColor)
        ctx.fill(layer.frame)
        super.draw(layer, in: ctx)
        
        let node = TextNode.layoutText(maybeNode: textNode, attributeString, nil, 3, .end, NSMakeSize(frame.width - 40, frame.height), nil, false, .center)
        
        let f = focus(node.0.size)
        
        node.1.draw(f, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
    }
    
    func close() {
        
        kitWindow?.removeAllHandlers(for: self)
        
        self.lock = true
        self.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion:false, completion:{[weak self] (completed) in
            self?.viewController?.removeModalAction()
        })
    }
    
    override func removeFromSuperview() {
        kitWindow?.removeAllHandlers(for: self)
        super.removeFromSuperview()
    }
    
    override func viewDidMoveToWindow() {
        if window != nil {
            self.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            self.kitWindow?.set(escape: {[weak self] () -> KeyHandlerResult in
                self?.close()
                return .invoked
            }, with: self, priority: .high)
            self.kitWindow?.set(responder: { () -> NSResponder? in
                return nil
            }, with: self, priority: .modal)
        } else {
            // self.viewController?.navigationController?.lock = false
        }
    }
    
    override func layout() {
        super.layout()
        self.setNeedsDisplayLayer()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    
}

