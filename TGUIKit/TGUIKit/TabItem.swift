//
//  TabItem.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa



open class TabItem: NSObject {
    let image: CGImage
    let selectedImage: CGImage
    let controller:ViewController
    let subNode:Node?
    
    public init(image: CGImage, selectedImage: CGImage, controller:ViewController, subNode:Node? = nil) {
        self.image = image
        self.selectedImage = selectedImage
        self.controller = controller
        self.subNode = subNode
        super.init()
    }
}
