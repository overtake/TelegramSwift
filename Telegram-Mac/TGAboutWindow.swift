//
//  TGAboutWindow.swift
//  Telegram
//
//  Created by s0ph0s on 2019-04-06.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa

class TGAboutWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        self.orderOut(sender)
    }
}
