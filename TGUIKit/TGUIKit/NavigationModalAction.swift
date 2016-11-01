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
    
    weak var view:NavigationModalView?
    
    public init(reason:String, desc:String) {
        self.reason = reason
        self.desc = desc
    }
}
