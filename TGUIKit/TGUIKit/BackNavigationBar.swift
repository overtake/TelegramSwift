//
//  BackNavigationBar.swift
//  TGUIKit
//
//  Created by keepcoder on 05/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class BackNavigationBar: TextButtonBarView {

    private weak var controller:ViewController?
    
    public init(_ controller:ViewController?) {
        self.controller = controller
        let backSettings = controller?.backSettings() ?? ("",nil)
        super.init(text: backSettings.0, style: navigationButtonStyle)
        
        if let image = backSettings.1 {
            button.set(image: image, for: .Normal)
        }
        
        button.set (handler:{[weak self] in
            
            self?.controller?.executeReturn()
            
        }, for:.Click)
    }
    
    public func requestUpdate() {
        let backSettings = controller?.backSettings() ?? ("",nil)
        button.set(text: backSettings.0, for: .Normal)
        if let image = backSettings.1 {
             button.set(image: image, for: .Normal)
        } else {
            button.removeImage(for: .Normal)
        }
        setFrameSize(frame.size)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}
