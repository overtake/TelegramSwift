//
//  ChatMusicContentView.swift
//  TelegramMac
//
//  Created by keepcoder on 25/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

class ChatMusicContentView: ChatAudioContentView {

    override func update(with media: Media, size: NSSize, account: Account, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool, positionFlags: GroupLayoutPositionFlags? = nil) {
        super.update(with: media, size: size, account: account, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags)
        
        if let parameters = parameters as? ChatMediaMusicLayoutParameters {
            textView.update(parameters.nameLayout)
            durationView.update(parameters.durationLayout)
        }
    }
    
    
    override func layout() {
        super.layout()
        let center = floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2.0)
        textView.setFrameOrigin(leftInset, center - textView.frame.height - 2)
        durationView.setFrameOrigin(leftInset, center + 2)
    }
    
}
