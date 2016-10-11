//
//  TabItem.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class TabItem: NSObject {
    var image: CGImage
    var selectedImage: CGImage
    
    var controller:ViewController
    
    public init(image: CGImage, selectedImage: CGImage, controller:ViewController) {
        self.image = image
        self.selectedImage = selectedImage
        self.controller = controller
        
        super.init()
    }
}
