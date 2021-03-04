//
//  GroupCallRecorderRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.03.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore

final class GroupCallRecorderRowItem : GeneralRowItem {
    
    fileprivate let account: Account
    fileprivate let startedRecordedTime: Int32?
    fileprivate let callback: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, account: Account, startedRecordedTime: Int32?, customTheme: GeneralRowItem.Theme? = nil, callback:@escaping()->Void) {
        self.startedRecordedTime = startedRecordedTime
        self.callback = callback
        self.account = account
        super.init(initialSize, height: 42, stableId: stableId, viewType: viewType, customTheme: customTheme)
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallRecorderRowView.self
    }
}

final class GroupCallRecorderRowView : GeneralContainableRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override var backdorColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.backgroundColor
        }
        return super.backdorColor
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallRecorderRowItem else {
            return
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
