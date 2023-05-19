//
//  WeakReference.swift
//  TGUIKit
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class WeakReference<T> where T:AnyObject {
    
    public private(set) weak var value:T?
    
    public init(value:T?) {
        self.value = value
    }
}

