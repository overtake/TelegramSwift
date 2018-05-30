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
    public let controller:ViewController
    let subNode:Node?
    let longHoverHandler:((Control)->Void)?
    public init(image: CGImage, selectedImage: CGImage, controller:ViewController, subNode:Node? = nil, longHoverHandler:((Control)->Void)? = nil) {
        self.image = image
        self.longHoverHandler = longHoverHandler
        self.selectedImage = selectedImage
        self.controller = controller
        self.subNode = subNode
        super.init()
    }
    
    public func withUpdatedImages(_ image: CGImage, _ selectedImage: CGImage) -> TabItem {
        return TabItem(image: image, selectedImage: selectedImage, controller: self.controller, subNode: self.subNode, longHoverHandler: self.longHoverHandler)
    }
}
