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
import SyncCore
import Postbox

class ChatMediaDice: ChatMediaItem {
    override var additionalLineForDateInBubbleState: CGFloat? {
        return rightSize.height + 5
    }
    override var isFixedRightPosition: Bool {
        return true
    }
    override var isBubbleFullFilled: Bool {
        return true
    }
}
