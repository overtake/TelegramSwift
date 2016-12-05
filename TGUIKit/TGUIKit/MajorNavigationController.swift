//
//  SingleChatNavigationController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
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
   
    override public func push(_ controller: ViewController, _ animated: Bool) {
        
        if isLocked {
            return
        }
        
        assertOnMainThread()
        
        controller.navigationController = self
        controller.loadViewIfNeeded(self.bounds)
        
        pushDisposable.set((controller.ready.get() |> take(1)).start(next: {[weak self] _ in
            if let strongSelf = self {
                strongSelf.lock = true
                let removeAnimateFlag = strongSelf.stackCount == 2 && controller.isKind(of: strongSelf.majorClass) ?? false
                
                if controller.isKind(of: strongSelf.majorClass) {
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
                
                let anim = animated && (!controller.isKind(of: strongSelf.majorClass) || strongSelf.controller != strongSelf.defaultEmpty) && !removeAnimateFlag
                
                strongSelf.show(controller, anim ? .push : .none)
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
        self.window?.set(handler: escapeKeyAction, with: self, for: .Escape, priority:.medium)
        self.window?.set(handler: returnKeyAction, with: self, for: .Return, priority:.low)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.window?.remove(object: self, for: .Escape)
        self.window?.remove(object: self, for: .Return)
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
