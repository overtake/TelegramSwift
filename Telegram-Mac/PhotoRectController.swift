//
//  PhotoRectController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class PhotoRectView : View {
    
}

class PhotoRectController: ModalViewController {
    private let context: AccountContext
    private let path: String
    init(context: AccountContext, path: String) {
        self.context = context
        self.path = path
        super.init(frame: NSMakeRect(0, 0, 380, 350))
    }
    
}
