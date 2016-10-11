//
//  BackNavigationBar.swift
//  TGUIKit
//
//  Created by keepcoder on 05/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class BackNavigationBar: TextButtonBarView {

    private weak var navigation:NavigationViewController?
    
    public init(_ navigation:NavigationViewController) {
        self.navigation = navigation
        
        let backSettings = navigation.controller.backSettings()

        super.init(text: backSettings.0, style: navigationButtonStyle)
        
        if let image = backSettings.1 {
            button.set(image: image, for: .Normal)
        }
        
        button.set (handler:{[weak self] in
            
            self?.navigation?.back()
            
        }, for:.Click)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}
