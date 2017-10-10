//
//  ChatToasterView.swift
//  TelegramMac
//
//  Created by keepcoder on 25/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



class ToasterView: View {

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.background = .random
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
