//
//  ExMajorNavigationController.swift
//  Telegram
//
//  Created by keepcoder on 01/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore


class ExMajorNavigationController: MajorNavigationController {
    private let context:AccountContext
    
    override var sidebar: ViewController? {
        return context.bindings.entertainment()
    }
    
    override var window: Window? {
        return context.window
    }
    
    open override var responderPriority: HandlerPriority {
        return .medium
    }
    
    public init(_ context: AccountContext, _ majorClass:AnyClass, _ empty:ViewController) {
        self.context = context
        super.init(majorClass, empty, context.window)
    }
    
    override func push(_ controller: ViewController, _ animated: Bool, style: ViewControllerStyle?) {
        super.push(controller, animated, style: style)
    }
    
}
