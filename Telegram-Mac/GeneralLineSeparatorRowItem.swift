//
//  GeneralLineSeparatorRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 10/06/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class GeneralLineSeparatorRowItem: GeneralRowItem {
    init(initialSize: NSSize, stableId: AnyHashable, height: CGFloat = .borderSize) {
        super.init(initialSize, height: height, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return GeneralLineSeparatorRowView.self
    }
}

private final class GeneralLineSeparatorRowView : TableRowView {
    override var backdorColor: NSColor {
        return theme.colors.border
    }
}
