//
//  SingleChatNavigationController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac



public protocol MajorControllerListener : class {
    func navigationWillShowMajorController(_ controller:ViewController);
}

open class MajorNavigationController: NavigationViewController, SplitViewDelegate {
    
    private var majorClass:AnyClass
    private var defaultEmpty:ViewController
    private var listeners:[WeakReference<ViewController>] = []
    
    private let container:GenericViewController<View> = GenericViewController<View>()
    
    override var containerView:View {
        get {
            return container.genericView
        }
        set {
            super.containerView = newValue
        }
    }
    
    
    
    open override func loadView() {
        super.loadView()
        
        genericView.setProportion(proportion: SplitProportion(min:380, max: .greatestFiniteMagnitude), state: .single)

        controller._frameRect = bounds
        controller.viewWillAppear(false)
        controller.navigationController = self
        
        containerView.addSubview(navigationBar)
        
        navigationBar.frame = NSMakeRect(0, 0, NSWidth(containerView.frame), controller.bar.height)
        controller.view.frame = NSMakeRect(0, controller.bar.height , NSWidth(containerView.frame), NSHeight(containerView.frame) - controller.bar.height)
        
        navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: .none, animationStyle: controller.animationStyle)
        
        containerView.addSubview(controller.view)
        Queue.mainQueue().justDispatch {
            self.controller.viewDidAppear(false)
        }
        
    }
    
    public func closeSidebar() {
        genericView.removeProportion(state: .dual)
        genericView.setProportion(proportion: SplitProportion(min:380, max: .greatestFiniteMagnitude), state: .single)
        genericView.layout()
    }
    
    public init(_ majorClass:AnyClass, _ empty:ViewController) {
        self.majorClass = majorClass
        self.defaultEmpty = empty
        assert(majorClass is ViewController.Type)
        
        super.init(empty)
    }
    
    open override func currentControllerDidChange() {
        if let view = view as? DraggingView {
            view.controller = controller
        }
        for listener in listeners {
            listener.value?.navigationWillChangeController()
        }
    }
    
    open override func viewDidLoad() {
        //super.viewDidLoad()
        
        genericView.delegate = self
        genericView.update()

    }
    
    public func splitViewDidNeedSwapToLayout(state: SplitViewState) {
        genericView.removeAllControllers();
        
        switch state {
        case .dual:
            genericView.addController(controller: container, proportion: SplitProportion(min: 800, max: .greatestFiniteMagnitude))
            if let sidebar = sidebar {
                genericView.addController(controller: sidebar, proportion: SplitProportion(min:350, max: 350))
            }
        case .single:
            genericView.addController(controller: container, proportion: SplitProportion(min: 800, max: .greatestFiniteMagnitude))
        default:
            break
        }
    }
    
    public func splitViewDidNeedMinimisize(controller: ViewController) {
        
    }
    
    public func splitViewDidNeedFullsize(controller: ViewController) {
        
    }
    
    public func splitViewIsCanMinimisize() -> Bool {
        return false;
    }
    
    public func splitViewDrawBorder() -> Bool {
        return true
    }
    
    open override func viewClass() ->AnyClass {
        return DraggingView.self
    }
    
    public var genericView:SplitView {
        return view as! SplitView
    }
   
    override open func push(_ controller: ViewController, _ animated: Bool, style:ViewControllerStyle? = nil) {
        
        assertOnMainThread()
        
        controller.navigationController = self
        controller.loadViewIfNeeded(self.container.bounds)
        
        genericView.update()
        
        pushDisposable.set((controller.ready.get() |> deliverOnMainQueue |> take(1)).start(next: {[weak self] _ in
            if let strongSelf = self {
                strongSelf.lock = true
                let isMajorController = controller.className == NSStringFromClass(strongSelf.majorClass)
                let removeAnimateFlag = strongSelf.stackCount == 2 && isMajorController
                
                if isMajorController {
                    for controller in strongSelf.stack {
                        controller.didRemovedFromStack()
                    }
                    strongSelf.stack.removeAll()
                    
                    strongSelf.stack.append(strongSelf.empty)
                }
                
                if let index = strongSelf.stack.index(of: controller) {
                    strongSelf.stack.remove(at: index)
                }
                
                 strongSelf.stack.append(controller)
                
                let anim = animated && (!isMajorController || strongSelf.controller != strongSelf.defaultEmpty) && !removeAnimateFlag
                
                let newStyle:ViewControllerStyle
                if let style = style {
                    newStyle = style
                } else {
                    newStyle = anim ? .push : .none
                }

                
                strongSelf.show(controller, newStyle)
                

            }
        }))
    }
    
    override func show(_ controller:ViewController,_ style:ViewControllerStyle) -> Void {
        
        let previous:ViewController = self.controller;
        _setController(controller)
        controller.navigationController = self
        
        
        if(previous == controller) {
            previous.viewWillDisappear(false)
            previous.viewDidDisappear(false)
            
            controller.viewWillAppear(false)
            controller.viewDidAppear(false)
            _ = controller.becomeFirstResponder()
            
            return;
        }
        

        self.navigationBar.frame = NSMakeRect(0, 0, NSWidth(containerView.frame), controller.bar.height)
        
        var contentInset = controller.bar.height
        
        if let header = header, header.needShown {
            header.view.frame = NSMakeRect(0, contentInset, containerView.frame.width, header.height)
            containerView.addSubview(header.view, positioned: .below, relativeTo: self.navigationBar)
            contentInset += header.height
        }
        
        controller.view.removeFromSuperview()
        controller.view.frame = NSMakeRect(0, contentInset , NSWidth(containerView.frame), NSHeight(containerView.frame) - contentInset)
        if #available(OSX 10.12, *) {
            
        } else {
            controller.view.needsLayout = true
        }
        
        
        var pfrom:CGFloat = 0, pto:CGFloat = 0, nto:CGFloat = 0, nfrom:CGFloat = 0;
        
        switch style {
        case .push:
            nfrom = NSWidth(containerView.frame)
            nto = 0
            pfrom = 0
            pto = -100//round(NSWidth(self.frame)/3.0)
            containerView.addSubview(controller.view, positioned: .above, relativeTo: previous.view)
        case .pop:
            nfrom = -round(NSWidth(containerView.frame)/3.0)
            nto = 0
            pfrom = 0
            pto = NSWidth(containerView.frame)
            previous.view.setFrameOrigin(NSMakePoint(pto, previous.frame.minY))
            containerView.addSubview(controller.view, positioned: .below, relativeTo: previous.view)
        case .none:
            previous.viewWillDisappear(false);
            previous.view.removeFromSuperview()
            containerView.addSubview(controller.view)
            controller.viewWillAppear(false);
            previous.viewDidDisappear(false);
            controller.viewDidAppear(false);
            _ = controller.becomeFirstResponder();
            
            self.navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: style, animationStyle: controller.animationStyle)
            lock = false
            
            navigationBar.removeFromSuperview()
            containerView.addSubview(navigationBar)
            
            if let header = header, header.needShown {
                header.view.removeFromSuperview()
                containerView.addSubview(header.view, positioned: .above, relativeTo: controller.view)
            }
            
            return // without animations
        }
        
        
        
        if previous.removeAfterDisapper, let index = stack.index(of: previous) {
            self.stack.remove(at: index)
        }
        
        navigationBar.removeFromSuperview()
        containerView.addSubview(navigationBar)
        
        if let header = header, header.needShown {
            header.view.removeFromSuperview()
            containerView.addSubview(header.view, positioned: .above, relativeTo: controller.view)
        }
        
        previous.viewWillDisappear(true);
        controller.viewWillAppear(true);
        
        
        CATransaction.begin()
        
        
        self.navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: style, animationStyle: controller.animationStyle)
        
        previous.view.layer?.animate(from: pfrom as NSNumber, to: pto as NSNumber, keyPath: "position.x", timingFunction: kCAMediaTimingFunctionSpring, duration: previous.animationStyle.duration, removeOnCompletion: true, additive: false, completion: {[weak self] (completed) in
            
            previous.view.removeFromSuperview()
            previous.viewDidDisappear(true);
            
            self?.lock = false
        });
        
        
        controller.view.layer?.animate(from: nfrom as NSNumber, to: nto as NSNumber, keyPath: "position.x", timingFunction: kCAMediaTimingFunctionSpring, duration: controller.animationStyle.duration, removeOnCompletion: true, additive: false, completion: { (completed) in
            
            controller.viewDidAppear(true);
            _ = controller.becomeFirstResponder()
        });
        
        
        CATransaction.commit()
        
    }
    
    open override func back(animated:Bool = true) -> Void {
        if stackCount > 1 && !isLocked, let last = stack.last, last.invokeNavigationBack() {
            let ncontroller = stack[stackCount - 2]
            let removeAnimateFlag = ncontroller == defaultEmpty || !animated
            last.didRemovedFromStack()
            stack.removeLast()
            
            show(ncontroller, removeAnimateFlag ? .none : .pop)
        }
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.window?.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.escapeKeyAction()
            }
            return .rejected
        }, with: self, for: .Escape, priority:.medium)
        
        self.window?.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.returnKeyAction()
            }
            return .rejected
        }, with: self, for: .Return, priority:.medium)
        
        
        self.window?.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.backKeyAction()
            }
            return .rejected
        }, with: self, for: .LeftArrow, priority:.medium)
        
        self.window?.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.nextKeyAction()
            }
            return .rejected
        }, with: self, for: .RightArrow, priority:.medium)
        
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.window?.removeAllHandlers(for: self)
    }
    
    open override func backKeyAction() -> KeyHandlerResult {
        let status:KeyHandlerResult = stackCount > 1 ? .invoked : .rejected
        
        let cInvoke = self.controller.backKeyAction()
        
        if cInvoke == .invokeNext {
            return .invokeNext
        } else if cInvoke == .invoked {
            return .invoked
        }
        self.back()
        return status
    }
    
    open override func nextKeyAction() -> KeyHandlerResult {
        return self.controller.nextKeyAction()
    }
    
    
    open override func escapeKeyAction() -> KeyHandlerResult {
        let status:KeyHandlerResult = stackCount > 1 ? .invoked : .rejected
        
        let cInvoke = self.controller.escapeKeyAction()
        
        if cInvoke == .invokeNext {
            return .invokeNext
        } else if cInvoke == .invoked {
            return .invoked
        }
        self.back()
        return status
    }
    
    open override func returnKeyAction() -> KeyHandlerResult {
        let status:KeyHandlerResult = .rejected
        
        let cInvoke = self.controller.returnKeyAction()
        
        if cInvoke == .invokeNext {
            return .invokeNext
        } else if cInvoke == .invoked {
            return .invoked
        }
        return status
    }
    
    public func add(listener:WeakReference<ViewController>) -> Void {
        listeners.append(listener)
    }
    
    public func remove(listener:WeakReference<ViewController>) -> Void {
        
        let index = listeners.index(where: { (weakView) -> Bool in
            return listener.value == weakView.value
        })
        
        if let index = index {
            listeners.remove(at: index)
        }
    }
    
}
