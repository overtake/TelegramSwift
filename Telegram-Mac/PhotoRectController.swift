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
    private let account: Account
    private let path: String
    init(account: Account, path: String) {
        self.account = account
        self.path = path
        super.init(frame: NSMakeRect(0, 0, 380, 350))
    }
    
}
