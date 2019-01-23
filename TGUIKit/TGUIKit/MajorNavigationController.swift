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
    
    public var alwaysAnimate: Bool = false
    private var majorClass:AnyClass
    private var defaultEmpty:ViewController
    private var listeners:[WeakReference<ViewController>] = []
    
    private let container:GenericViewController<BackgroundView> = GenericViewController<BackgroundView>()
    
    override var containerView:BackgroundView {
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
        containerView.frame = bounds
        navigationBar.frame = NSMakeRect(0, 0, containerView.frame.width, controller.bar.height)
        controller.view.frame = NSMakeRect(0, controller.bar.height , containerView.frame.width, containerView.frame.height - controller.bar.height)
        
        navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: .none, animationStyle: controller.animationStyle, liveSwiping: false)
        
        containerView.addSubview(controller.view)
        Queue.mainQueue().justDispatch {
            self.controller.viewDidAppear(false)
        }
        
        
    }
    
    public func closeSidebar() {
        genericView.removeProportion(state: .dual)
        genericView.setProportion(proportion: SplitProportion(min:380, max: .greatestFiniteMagnitude), state: .single)
        genericView.layout()
        
        viewDidChangedNavigationLayout(.single)
    }
    
    public init(_ majorClass:AnyClass, _ empty:ViewController) {
        self.majorClass = majorClass
        self.defaultEmpty = empty
        container.bar = .init(height: 0)
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
        controller.viewDidChangedNavigationLayout(state)
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
                let removeAnimateFlag = strongSelf.stackCount == 2 && isMajorController && !strongSelf.alwaysAnimate
                
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
                controller.viewDidChangedNavigationLayout(strongSelf.genericView.state)

            }
        }))
    }
    
    public var doSomethingOnEmptyBack: (()->Void)? = nil
    
    open override func back(animated:Bool = true, forceAnimated: Bool = false, animationStyle: ViewControllerStyle = .pop) -> Void {
        if  !isLocked, let last = stack.last, last.invokeNavigationBack() {
            if stackCount > 1 {
                let ncontroller = stack[stackCount - 2]
                let removeAnimateFlag = ((ncontroller == defaultEmpty || !animated) && !alwaysAnimate) && !forceAnimated
                last.didRemovedFromStack()
                stack.removeLast()
                
                show(ncontroller, removeAnimateFlag ? .none : animationStyle)
            } else {
                doSomethingOnEmptyBack?()
            }
        }
        
    }
    
    
    
    
    public func removeExceptMajor() {
        let index = stack.index(where: { current in
            return current.className == NSStringFromClass(self.majorClass)
        })
        if let index = index {
            while stack.count > index {
                stack.removeLast()
            }
        } else {
            while stack.count > 1 {
                stack.removeLast()
            }
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
        
        self.window?.add(swipe: { [weak self] direction -> SwipeHandlerResult in
            guard let `self` = self, self.controller.view.layer?.animationKeys() == nil else {return .failed}
            
            
            switch direction {
            case let .left(state):
                switch state {
                case .start:
                    
                    guard let previous = self.previousController, self.controller.supportSwipes, self.stackCount > 1 && !self.isLocked, (self.genericView.state == .single || self.stackCount > 2) else {return .failed}
                
                    previous.view.frame = NSMakeRect(0, previous.bar.height, self.frame.width, self.frame.height - previous.bar.height)
                    
                    self.containerView.addSubview(previous.view, positioned: .below, relativeTo: self.controller.view)
                    
                    
                    let prevBackgroundView = self.containerView.copy() as! NSView
                    let nextBackgroundView = self.containerView.copy() as! NSView
                    
                    if !previous.isOpaque {
                        previous.view.addSubview(prevBackgroundView, positioned: .below, relativeTo: previous.view.subviews.first)
                        prevBackgroundView.setFrameOrigin(NSMakePoint(prevBackgroundView.frame.minX, -previous.view.frame.minY))
                    }
                    if !self.controller.isOpaque {
                        self.controller.view.addSubview(nextBackgroundView, positioned: .below, relativeTo: self.controller.view.subviews.first)
                        nextBackgroundView.setFrameOrigin(NSMakePoint(nextBackgroundView.frame.minX, -self.controller.view.frame.minY))
                    }
                    
                    self.addShadowView(.left)
                    if previous.bar.has {
                        self.navigationBar.startMoveViews(left: previous.leftBarView, center: previous.centerBarView, right: previous.rightBarView, direction: direction)
                    }
                    self.lock = true
                    return .success(previous)
                case let .swiping(delta, previous):
                    
                    
                    let nPosition = min(max(0, delta), self.containerView.frame.width)
                    self.controller.view._change(pos: NSMakePoint(nPosition, self.controller.view.frame.minY), animated: false)
                    let previousStart = -round(NSWidth(self.containerView.frame)/3.0)
                    previous.view._change(pos: NSMakePoint(min(previousStart + delta / 3.0, 0), previous.view.frame.minY), animated: false)

                    self.shadowView.setFrameOrigin(nPosition - self.shadowView.frame.width, self.shadowView.frame.minY)
                    self.shadowView.layer?.opacity = min(1.0 - Float(nPosition / self.containerView.frame.width) + 0.2, 1.0)
                    
                    if previous.bar.has {
                        self.navigationBar.moveViews(left: previous.leftBarView, center: previous.centerBarView, right: previous.rightBarView, direction: direction, percent: nPosition / self.containerView.frame.width)
                    } else {
                        self.navigationBar.setFrameOrigin(nPosition, self.navigationBar.frame.minY)
                    }
                    return .deltaUpdated(available: nPosition)
                    
                case let .success(_, controller):
                    self.lock = false
                    
                    controller.removeBackgroundCap()
                    self.controller.removeBackgroundCap()
                    
                    self.back(forceAnimated: true)
                case let .failed(_, previous):
                 //   CATransaction.begin()
                    let animationStyle = previous.animationStyle
                    self.controller.view._change(pos: NSMakePoint(0, self.controller.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    self.containerView.subviews[0]._change(pos: NSMakePoint(-round(self.containerView.frame.width / 3), self.containerView.subviews[0].frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self, weak previous] completed in
                        if completed {
                            self?.containerView.subviews[0].removeFromSuperview()
                            self?.controller.removeBackgroundCap()
                            previous?.removeBackgroundCap()
                        }
                    })
                    self.shadowView.change(pos: NSMakePoint(-self.shadowView.frame.width, self.shadowView.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self] completed in
                        self?.shadowView.removeFromSuperview()
                    })
                    self.shadowView.change(opacity: 1, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    if previous.bar.has {
                        self.navigationBar.moveViews(left: previous.leftBarView, center: previous.centerBarView, right: previous.rightBarView, direction: direction, percent: 0, animationStyle: animationStyle)
                    } else {
                        self.navigationBar.change(pos: NSMakePoint(0, self.navigationBar.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    }
                    self.lock = false
                  //  CATransaction.commit()
                }
            case let .right(state):
                
                switch state {
                case .start:
                    guard let new = self.controller.rightSwipeController, !self.isLocked else {return .failed}
                    new._frameRect = self.containerView.bounds
                    new.view.setFrameOrigin(NSMakePoint(self.containerView.frame.width, self.controller.frame.minY))

                    
                    let prevBackgroundView = self.containerView.copy() as! NSView
                    let nextBackgroundView = self.containerView.copy() as! NSView
                    
                    if !new.isOpaque {
                        new.view.addSubview(prevBackgroundView, positioned: .below, relativeTo: new.view.subviews.first)
                        prevBackgroundView.setFrameOrigin(NSMakePoint(prevBackgroundView.frame.minX, -new.view.frame.minY))
                    }
                    if !self.controller.isOpaque {
                        self.controller.view.addSubview(nextBackgroundView, positioned: .below, relativeTo: self.controller.view.subviews.first)
                        nextBackgroundView.setFrameOrigin(NSMakePoint(nextBackgroundView.frame.minX, -self.controller.view.frame.minY))
                    }
                    
                    self.containerView.addSubview(new.view, positioned: .above, relativeTo: self.controller.view)
                    self.addShadowView(.right)
                    self.navigationBar.startMoveViews(left: new.leftBarView, center: new.centerBarView, right: new.rightBarView, direction: direction)
                    self.lock = true
                    return .success(new)
                case let .swiping(delta, new):
                    let delta = min(max(0, delta), self.containerView.frame.width)
                    
                    let nPosition = self.containerView.frame.width - delta
                   // NSLog("\(nPosition)")
                    new.view._change(pos: NSMakePoint(nPosition, new.frame.minY), animated: false)
                    
                    self.controller.view._change(pos: NSMakePoint(min(-delta / 3.0, 0), self.controller.view.frame.minY), animated: false)
                    
                    self.shadowView.setFrameOrigin(nPosition - self.shadowView.frame.width, self.shadowView.frame.minY)
                    self.shadowView.layer?.opacity = min(1.0 - Float(nPosition / self.containerView.frame.width) + 0.2, 1.0)
                    
                    self.navigationBar.moveViews(left: new.leftBarView, center: new.centerBarView, right: new.rightBarView, direction: direction, percent: delta / self.containerView.frame.width)

                    return .deltaUpdated(available: delta)
                case let .success(_, controller):
                    self.lock = false
                    
                    controller.removeBackgroundCap()
                    self.controller.removeBackgroundCap()
                    
                    self.push(controller, true, style: .push)
                case let .failed(_, new):
                   // CATransaction.begin()
                    let animationStyle = new.animationStyle
                    var _new:ViewController? = new
                    
                    
                    _new?.view._change(pos: NSMakePoint(self.containerView.frame.width, self.controller.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    self.containerView.subviews[0]._change(pos: NSMakePoint(0, self.containerView.subviews[0].frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak new, weak self] completed in
                        self?.controller.removeBackgroundCap()
                        new?.view.removeFromSuperview()
                        _new = nil
                    })
                    self.shadowView.change(pos: NSMakePoint(self.containerView.frame.width, self.shadowView.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self] completed in
                        self?.shadowView.removeFromSuperview()
                    })
                    self.shadowView.change(opacity: 1, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    self.navigationBar.moveViews(left: new.leftBarView, center: new.centerBarView, right: new.rightBarView, direction: direction, percent: 0, animationStyle: animationStyle)
                    self.lock = false
                   // CATransaction.commit()
                }
            default:
                break
            }
            
            return .nothing
        }, with: self.containerView, identifier: "main-navigation")
        
    }
    private var previousController: ViewController? {
        if stackCount > 1 {
            return stack[stackCount - 2]
        }
        return nil
    }
    
    
    
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.window?.removeAllHandlers(for: self)
        self.window?.removeAllHandlers(for: self.containerView)
    }
    
    open override func backKeyAction() -> KeyHandlerResult {
        let status:KeyHandlerResult = stackCount > 1 ? .invoked : .rejected
        if isLocked {
            return .invoked
        }
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
        if isLocked {
            return .invoked
        }
        return self.controller.nextKeyAction()
    }
    
    
    open override func escapeKeyAction() -> KeyHandlerResult {
        let status:KeyHandlerResult = stackCount > 1 ? .invoked : .rejected
        if isLocked {
            return .invoked
        }
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
        let index = listeners.index(where: { (weakView) -> Bool in
            return listener.value == weakView.value
        })
        if index == nil {
            listeners.append(listener)
        }
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
