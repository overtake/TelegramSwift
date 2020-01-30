//
//  SearchSettingsEmptyItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class SearchSettingsEmptyItem: TableRowItem {
    let textLayout:TextViewLayout
    override init(_ initialSize:NSSize) {
        textLayout = TextViewLayout(.initialize(string: L10n.settingsSearchEmptyItem, color: theme.colors.grayText, font: .normal(.title)), alignment: .center)
        super.init(initialSize)
    }
    
    override var height: CGFloat {
        if let table = table {
            return table.frame.height
        } else {
            return initialSize.height
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return SearchSettingsEmptyView.self
    }
}

class SearchSettingsEmptyView : TableRowView {
    private let textView:TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        border = [.Right]
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        if let item = item as? SearchSettingsEmptyItem {
            item.textLayout.measure(width: frame.width - 60)
            textView.update(item.textLayout)
            textView.center()
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
