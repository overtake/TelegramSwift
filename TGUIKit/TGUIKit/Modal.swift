//
//  Modal.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

class Modal: NSObject {
    
    private var window:Window
    private weak var controller:ViewController?

    public init(controller:ViewController, for window:Window) {
        self.controller = controller
        self.window = window
        super.init()
    }
    
}
