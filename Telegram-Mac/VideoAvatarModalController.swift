//
//  VideoAvatarModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/06/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class VideoAvatarModalController: ModalController {
    private let context: AccountContext
    init(context: AccountContext) {
        self.context = context
        super.init()
    }
}
