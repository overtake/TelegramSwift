//
//  ChannelRecentPostRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.03.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore

class ChannelRecentPostRowItem: GeneralRowItem {
    init(_ initialSize: NSSize, stableId: AnyHashable, message: Message, viewType: GeneralViewType, action: @escaping()->Void) {
        super.init(initialSize, height: 40, stableId: stableId, viewType: viewType, action: action)
    }
}
