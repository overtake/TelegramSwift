//
//  TabBadgeItem.swift
//  TelegramMac
//
//  Created by keepcoder on 05/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import SwiftSignalKitMac
import TelegramCoreMac


class TabBadgeItem: TabItem {
    private let account:Account
    init(_ account:Account, controller:ViewController, image: CGImage, selectedImage: CGImage) {
        self.account = account
        super.init(image: image, selectedImage: selectedImage, controller: controller, subNode:GlobalBadgeNode(account))
    }
    
}
