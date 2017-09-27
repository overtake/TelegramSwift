//
//  BackNavigationBar.swift
//  TGUIKit
//
//  Created by keepcoder on 05/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class BackNavigationBar: TextButtonBarView {

    
    public init(_ controller:ViewController) {
        let backSettings = controller.backSettings()
        super.init(controller: controller, text: backSettings.0, style: navigationButtonStyle)
        
        if let image = backSettings.1 {
            button.set(image: image, for: .Normal)
        }
        button.disableActions()
        button.set(handler: { [weak self] _ in
            self?.controller?.executeReturn()
        }, for: .Up)
    }
    
    public func requestUpdate() {
        let backSettings = controller?.backSettings() ?? ("",nil)
        button.set(text: backSettings.0, for: .Normal)
        if let image = backSettings.1 {
             button.set(image: image, for: .Normal)
        } else {
            button.removeImage(for: .Normal)
        }
        style = navigationButtonStyle
        button.style = navigationButtonStyle
        needsLayout = true
    }
    
    open override func layout() {
        super.layout()
        if controller?.backSettings().1 != nil {
            button.centerY(x: 10)
        } else {
            button.center()
        }
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}
