//
//  GroupCallTileRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.06.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import SyncCore
import Postbox
import TelegramCore

final class GroupCallTileRowItem : GeneralRowItem {
    fileprivate let takeView: ()->(NSSize, GroupCallTileView)?
    init(_ initialSize: NSSize, stableId: AnyHashable, takeView: @escaping()->(NSSize, GroupCallTileView)?) {
        self.takeView = takeView
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        let value = takeView()
        if let value = value {
            return value.1.getSize(value.0).height + 5
        }
        return 1
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallTileRowView.self
    }
}

private final class GroupCallTileRowView: TableRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override var backdorColor: NSColor {
        return GroupCallTheme.windowBackground
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? GroupCallTileRowItem else {
            return
        }
        if let view = item.takeView() {
            addSubview(view.1)
        }
    }
    
    
}
