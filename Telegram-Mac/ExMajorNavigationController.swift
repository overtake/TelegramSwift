//
//  ExMajorNavigationController.swift
//  Telegram
//
//  Created by keepcoder on 01/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac

class ExMajorNavigationController: MajorNavigationController {
    private let account:Account
    
    override var sidebar: ViewController? {
        return account.context.entertainment
    }
    
    public init(_ account: Account, _ majorClass:AnyClass, _ empty:ViewController) {
        self.account = account
        super.init(majorClass, empty)
    }
    
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        return globalAudio?.makeTouchBar()
    }
    
}
