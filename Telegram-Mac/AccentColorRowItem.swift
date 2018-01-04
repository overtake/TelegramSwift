//
//  AccentColorRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/01/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import TGUIKit

class AccentColorRowItem: GeneralRowItem {

    fileprivate let color: NSColor
    init(_ initialSize: NSSize, stableId: AnyHashable, color: NSColor) {
        self.color = color
        super.init(initialSize, height: 50, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return AccentColorRowView.self
    }
}


private final class AccentColorRowView : TableRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
