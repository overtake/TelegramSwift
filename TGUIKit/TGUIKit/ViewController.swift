//
//  ViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKitMac

class ControllerToasterView : View {
    
    private weak var toaster:ControllerToaster?
    private let textView:TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        self.autoresizingMask = [.viewWidthSizable]
        self.border = [.Bottom]
    }
    
   
    
    func update(with toaster:ControllerToaster) {
        self.toaster = toaster
    }
    
    override func layout() {
        super.layout()
        if let toaster = toaster {
            toaster.text.measure(width: frame.width - 40)
            textView.update(toaster.text)
            textView.center()
        }
        self.setNeedsDisplayLayer()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class ControllerToaster {
    let text:TextViewLayout
    var view:ControllerToasterView?
    let disposable:MetaDisposable = MetaDisposable()
    public init(text:NSAttributedString) {
        self.text = TextViewLayout(text, maximumNumberOfLines: 1, truncationType: .middle)
    }
    
    func show(for controller:ViewController, timeout:Double, animated:Bool) {
        assert(view == nil)
        view = ControllerToasterView(frame: NSMakeRect(0, 0, controller.frame.width, 30))
        view?.update(with: self)
        controller.addSubview(view!)
        
        if animated {
            view?.layer?.animatePosition(from: NSMakePoint(0, -30), to: NSZeroPoint, duration: 0.2)
        }
        
        let signal:Signal<Void,Void> = .single() |> delay(timeout, queue: Queue.mainQueue())
        disposable.set(signal.start(next:{ [weak self] in
            self?.hide(true)
        }))
    }
    
    func hide(_ animated:Bool) {
        if animated {
            view?.layer?.animatePosition(from: NSZeroPoint, to: NSMakePoint(0, -30), duration: 0.2, removeOnCompletion:false, completion:{ [weak self] (completed) in
                self?.view?.removeFromSuperview()
                self?.view = nil
            })
        } else {
            view?.removeFromSuperview()
            view = nil
            disposable.dispose()
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
}

open class ViewController : NSObject {
    fileprivate var _view:NSView?;
    public var _frameRect:NSRect
    
    private var toaster:ControllerToaster?
    
    public var atomicSize:Atomic<NSSize> = Atomic(value:NSZeroSize)
    
    weak open var navigationController:NavigationViewController? {
        didSet {
            if navigationController != oldValue {
                updateNavigation(navigationController)
                if let modalAction = navigationController?.modalAction {
                    self.invokeNavigation(action: modalAction)
                }
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
    
    public var view:NSView {
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
    
    open func executeReturn() -> Void {
        self.navigationController?.back()
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
    
    open func readyOnce() -> Void {
        if !didSetReady {
            didSetReady = true
            ready.set(.single(true))
        }
    }
    
    open func loadView() -> Void {
        if(_view == nil) {
            
            leftBarView = getLeftBarViewOnce()
            centerBarView = getCenterBarViewOnce()
            rightBarView = getRightBarViewOnce()
            
            let vz = viewClass() as! NSView.Type
            _view = vz.init(frame: _frameRect);
            _view?.autoresizingMask = [.viewWidthSizable,.viewHeightSizable]
            
            NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: Notification.Name.NSViewFrameDidChange, object: _view!)
            
            _ = atomicSize.swap(_view!.frame.size)
        }
    }
    
    @objc func viewFrameChanged(_ notification:Notification) {
        viewDidResized(frame.size)
    }
    
    open func viewDidResized(_ size:NSSize) {
        _ = atomicSize.swap(size)
    }
    
    open func getLeftBarViewOnce() -> BarView {
        return enableBack ? BackNavigationBar(self) : BarView()
    }
    
    open func getCenterBarViewOnce() -> TitledBarView {
        return TitledBarView(NSAttributedString.initialize(string: localizedString(self.className), font: systemMediumFont(TGFont.titleSize)))
    }
    
    open func getRightBarViewOnce() -> BarView {
        return BarView()
    }
    
    open func viewClass() ->AnyClass {
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
        viewDidResized(view.frame.size)
    }
    
    open func viewWillAppear(_ animated:Bool) -> Void {
        
    }
    
    deinit {
        self.window?.removeObserver(for: self)
        NotificationCenter.default.removeObserver(self)
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
        return _view?.window as? Window
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
    
    open func closePopover() -> Void {
        self.popover?.hide()
    }
    
    open func invokeNavigation(action:NavigationModalAction) {
        
    }
    
    public func show(toaster:ControllerToaster, for delay:Double = 3.0, animated:Bool = true) {
        assert(isLoaded())
        if let toaster = self.toaster {
            toaster.hide(true)
        }
        
        self.toaster = toaster
        toaster.show(for: self, timeout: delay, animated: animated)
        
    }
}


open class GenericViewController<T> : ViewController where T:NSView {
    public var genericView:T {
        return super.view as! T
    }
    
    override open func loadView() -> Void {
        if(_view == nil) {
            
            leftBarView = getLeftBarViewOnce()
            centerBarView = getCenterBarViewOnce()
            rightBarView = getRightBarViewOnce()
            
            let vz = T.self as! NSView.Type
            _view = vz.init(frame: _frameRect);
            _view?.autoresizingMask = [.viewWidthSizable,.viewHeightSizable]
            
            NotificationCenter.default.addObserver(self, selector: #selector(viewFrameChanged(_:)), name: Notification.Name.NSViewFrameDidChange, object: _view!)
            
            _ = atomicSize.swap(_view!.frame.size)
        }
    }

    
}
