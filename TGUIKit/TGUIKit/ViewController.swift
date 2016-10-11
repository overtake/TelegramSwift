//
//  ViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKitMac
open class ViewController : NSObject {
    private var _view:View?;
    public var _frameRect:NSRect
    
    weak open var navigationController:NavigationViewController? {
        didSet {
            if navigationController != oldValue {
                updateNavigation(navigationController)
            }
        }
    }
    public var animationStyle:AnimationStyle = AnimationStyle(duration:0.4, function:kCAMediaTimingFunctionSpring)
    public var bar:NavigationBarStyle = NavigationBarStyle(height:50)
    
    public var leftBarView:BarView = BarView()
    public var centerBarView:BarView = BarView()
    public var rightBarView:BarView = BarView()
    
    
    public var popover:Popover?
    
    private let _ready = Promise<Bool>()
    open var ready: Promise<Bool> {
        return self._ready
    }
    
    public var view:View {
        get {
            if(_view == nil) {
                loadView();
            }
            
            return _view!;
        }
       
    }
    
    open func updateNavigation(_ navigation:NavigationViewController?) {
        
    }
    
    public private(set) var internalId:Int = 0;
    
    public override init() {
        _frameRect = NSZeroRect
        self.internalId = Int(arc4random());
        super.init()
    }
    
    public init(frame frameRect:NSRect) {
        _frameRect = frameRect;
        self.internalId = Int(arc4random());
    }
    
    open func loadView() -> Void {
        if(_view == nil) { 
            _view = View(frame: _frameRect);
            _view?.autoresizingMask = [.viewWidthSizable,.viewHeightSizable]
        }
    }
    
    public func loadViewIfNeeded() -> Void {
        guard let view = _view else {
            self.loadView()
            
            return
        }
    }
    
    open func viewWillAppear(_ animated:Bool) -> Void {
        
    }
    
    open func viewWillDisappear(_ animated:Bool) -> Void {
        
    }
    
    open func viewDidAppear(_ animated:Bool) -> Void {
        
    }
    
    open func viewDidDisappear(_ animated:Bool) -> Void {
        
    }
    
    open func becomeFirstResponder() -> Bool? {
        return self.view.becomeFirstResponder()
    }
    
    public var frame:NSRect {
        get {
            return self.view.frame
        }
        set {
            self.view.frame = newValue
        }
    }
    public var bounds:NSRect {
        return self.view.bounds
    }
    
    public func addSubview(_ subview:NSView) -> Void {
        self.view.addSubview(subview)
    }
    
    public func removeFromSuperview() ->Void {
        self.view.removeFromSuperview()
    }
    
    public let backImage = #imageLiteral(resourceName: "Icon_NavigationBack").precomposed()
    
    open func backSettings() -> (String,CGImage?) {
        return (NSLocalizedString("Navigation.back",comment:""),backImage)
    }
    
    open var popoverClass:AnyClass {
        return Popover.self
    }
    
    public func show(for control:Control, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint) -> Void {
        if popover == nil {
            
            self.popover = (self.popoverClass as! Popover.Type).init(controller: self)
        }
        
        if let popover = popover {
            popover.show(for: control, edge: edge, inset: inset)
        }
    }

}
