//
//  Modal.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

class Modal: NSObject {
    
    private var window:NSWindow
    private weak var controller:ViewController?

    public init(controller:ViewController) {
        self.controller = controller
        window = NSWindow.init(contentRect: NSZeroRect, styleMask: [], backing: .buffered, defer: true, screen: NSScreen.main())
        window.backgroundColor = NSColor.clear
        
        super.init()
    }
    
}
