//
//  SearchStoryFoundItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import Postbox

final class SearchStoryFoundItem : GeneralRowItem {
    
    init(_ initialSize: NSSize, stableId: AnyHashable, list: SearchStoryListContext.State, context: AccountContext) {
        super.init(initialSize, height: 40, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return SearchStoryFoundView.self
    }
}


private final class SearchStoryFoundView: GeneralRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
