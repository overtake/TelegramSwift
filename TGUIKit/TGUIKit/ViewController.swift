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
    public var _view:View?;
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
    
    public var leftBarView:BarView!
    public var centerBarView:TitledBarView!
    public var rightBarView:BarView!
    
    public var popover:Popover?
    public var modal:Modal?
    
    
    private let _ready = Promise<Bool>()
    open var ready: Promise<Bool> {
        return self._ready
    }
    public var didSetReady:Bool = false
    
    public var view:View {
        get {
            if(_view == nil) {
                loadView();
            }
            
            return _view!;
        }
       
    }
    
    open var enableBack:Bool {
        return false
    }
    
    open func updateNavigation(_ navigation:NavigationViewController?) {
        if let navigation = navigation {
            
            leftBarView = enableBack ? BackNavigationBar(navigation) : BarView()
            centerBarView = TitledBarView(NSAttributedString.initialize(string: localizedString(self.className), font: systemMediumFont(TGFont.titleSize)))
            rightBarView = BarView()
        }
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
    
    open func readyOnce() -> Void {
        if !didSetReady {
            didSetReady = true
            ready.set(.single(true))
        }
    }
    
    open func loadView() -> Void {
        if(_view == nil) {
            let vz = viewClass() as! View.Type
            _view = vz.init(frame: _frameRect);
            _view?.autoresizingMask = [.viewWidthSizable,.viewHeightSizable]

        }
    }
    
    public func viewClass() ->AnyClass {
        return View.self
    }
    
    open func draggingItems(for pasteboard:NSPasteboard) -> [DragItem] {
        return []
    }
    
    public func loadViewIfNeeded(_ frame:NSRect = NSZeroRect) -> Void {
        
         guard let view = _view else {
            if !NSIsEmptyRect(frame) {
                _frameRect = frame
            }
            self.loadView()
            
            return
        }
    }
    
    open func viewDidLoad() -> Void {
        
    }
    
    open func viewWillAppear(_ animated:Bool) -> Void {
        
    }
    
    deinit {
        self.window?.removeObserver(for: self)
    }
    
    open func viewWillDisappear(_ animated:Bool) -> Void {
        //assert(self.window != nil)
        if canBecomeResponder {
            self.window?.removeObserver(for: self)
        }
    }
    
    public func isLoaded() -> Bool {
        return _view != nil
    }
    
    open func viewDidAppear(_ animated:Bool) -> Void {
        //assert(self.window != nil)
        if canBecomeResponder {
            self.window?.set(responder: {[weak self] () -> NSResponder? in
                return self?.firstResponder()
            }, with: self, priority: responderPriority)
            
            self.window?.applyResponderIfNeeded()
        }
    }
    
    open var canBecomeResponder: Bool {
        return true
    }
    
    open func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    open func returnKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    open func didRemovedFromStack() -> Void {
        
    }
    
    open func viewDidDisappear(_ animated:Bool) -> Void {
        
    }
    
    open func becomeFirstResponder() -> Bool? {

        return _view?.becomeFirstResponder()
    }
    
    public var window:Window? {
        return _view?.kitWindow
    }
    
    open func firstResponder() -> NSResponder? {
        return nil
    }
    
    open var responderPriority:HandlerPriority {
        return .low
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
        return (localizedString("Navigation.back"),backImage)
    }
    
    open var popoverClass:AnyClass {
        return Popover.self
    }
    
    open func show(for control:Control, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint) -> Void {
        if popover == nil {
            self.popover = (self.popoverClass as! Popover.Type).init(controller: self)
        }
        
        if let popover = popover {
            popover.show(for: control, edge: edge, inset: inset)
        }
    }
    

}


