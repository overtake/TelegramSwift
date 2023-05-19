//
//  NavigationModalAction.swift
//  TGUIKit
//
//  Created by keepcoder on 01/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa


open class NavigationModalAction: NSObject {
    let reason:String
    let desc:String
    public var afterInvoke:()->Void = {}
    weak var navigation:NavigationViewController?
    weak var view:NavigationModalView?
    
    public init(reason:String, desc:String) {
        self.reason = reason
        self.desc = desc
    }
    
    open func alertError(for value:Any, with:Window) -> Void {
        
    }
    
    open func close() {
        if let view = view {
            view.close()
        } else {
            navigation?.removeModalAction()
        }
    }
    
    open func isInvokable(for value:Any) -> Bool {
        return true
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
   
}
