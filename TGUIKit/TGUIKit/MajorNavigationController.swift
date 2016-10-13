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
    
    private var listeners:[WeakReference<ViewController>] = []
    
    
    public init(_ majorClass:AnyClass, _ empty:ViewController) {
        self.majorClass = majorClass
        assert(majorClass is ViewController.Type)
        
        super.init(empty)
    }
    
    override public func push(_ controller: ViewController, _ animated: Bool) {
        controller.navigationController = self
        controller.loadViewIfNeeded(self.bounds)
        
        
        pushDisposable.set((controller.ready.get() |> take(1)).start(next: {[weak self] _ in
            if let strongSelf = self {
                
                let removeAnimateFlag = strongSelf.stackCount == 2 && controller.isKind(of: strongSelf.majorClass) ?? false
                
                if controller.isKind(of: strongSelf.majorClass) {
                    strongSelf.stack.removeAll()
                    strongSelf.stack.append(strongSelf.empty)
                }
                
                if let index = strongSelf.stack.index(of: controller) {
                    strongSelf.stack.remove(at: index)
                }
                
                 strongSelf.stack.append(controller)
                
                let anim = animated && strongSelf.controller != strongSelf.empty && !removeAnimateFlag
                
                strongSelf.show(controller, anim ? .push : .none)
            }
        }))
    }
    
    public override func back(_ index:Int = -1) -> Void {
        if stackCount > 1 {
            let ncontroller = stack[stackCount - 2]
            let removeAnimateFlag = stack.last!.isKind(of: majorClass) && stackCount == 2
            show(ncontroller, removeAnimateFlag ? .none : .pop)
        }
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
