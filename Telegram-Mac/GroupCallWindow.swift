//
//  GroupCallWindow.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class GroupCallWindow : Window {
    
}


final class GroupCallContext {
    let window: GroupCallWindow
    init() {
        self.window = GroupCallWindow(contentRect: NSMakeRect(0, 0, 400, 580), styleMask: [.fullSizeContentView, .borderless, .resizable, .miniaturizable, .titled], backing: .buffered, defer: true, screen: NSScreen.main)
        self.window.minSize = NSMakeSize(400, 580)
        self.window.isOpaque = true
        self.window.backgroundColor = .black
    }
}
