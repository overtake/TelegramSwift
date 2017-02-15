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

public class MajorNavigationController: NavigationViewController {
    
    private var majorClass:AnyClass
    private var defaultEmpty:ViewController
    private var listeners:[WeakReference<ViewController>] = []
    
    
    public init(_ majorClass:AnyClass, _ empty:ViewController) {
        self.majorClass = majorClass
        self.defaultEmpty = empty
        assert(majorClass is ViewController.Type)
        
        super.init(empty)
    }
    
    public override func currentControllerDidChange() {
        if let view = view as? DraggingView {
            view.controller = controller
        }
    }
    
    public override func viewClass() ->AnyClass {
        return DraggingView.self
    }
   
    override public func push(_ controller: ViewController, _ animated: Bool, style:ViewControllerStyle? = nil) {
        

        
        assertOnMainThread()
        
        controller.navigationController = self
        controller.loadViewIfNeeded(self.bounds)
        
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
    
    public override func back(animated:Bool = true) -> Void {
        if stackCount > 1 && !isLocked {
            let ncontroller = stack[stackCount - 2]
            let removeAnimateFlag = ncontroller == defaultEmpty || !animated
            stack.last?.didRemovedFromStack()
            stack.removeLast()
            
            show(ncontroller, removeAnimateFlag ? .none : .pop)
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
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
        }, with: self, for: .Return, priority:.low)
        
        
        self.window?.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.backKeyAction()
            }
            return .rejected
        }, with: self, for: .LeftArrow, priority:.low)
        
        self.window?.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.nextKeyAction()
            }
            return .rejected
        }, with: self, for: .RightArrow, priority:.low)
        
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.window?.remove(object: self, for: .Escape)
        self.window?.remove(object: self, for: .Return)
        self.window?.remove(object: self, for: .LeftArrow)
        self.window?.remove(object: self, for: .RightArrow)
    }
    
    public override func backKeyAction() -> KeyHandlerResult {
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
    
    public override func nextKeyAction() -> KeyHandlerResult {
        return self.controller.nextKeyAction()
    }
    
    
    public override func escapeKeyAction() -> KeyHandlerResult {
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
    
    public override func returnKeyAction() -> KeyHandlerResult {
        return .rejected
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
