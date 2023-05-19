//
//  ChatMediaDice.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

class ChatMediaDice: ChatMediaItem {
    override var isForceRightLine: Bool {
        return true
    }
   
    override var isBubbleFullFilled: Bool {
        return true
    }
    
}
