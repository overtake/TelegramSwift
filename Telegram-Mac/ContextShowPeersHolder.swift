//
//  ContextShowPeersHolder.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.12.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class ContextShowPeersHolderItem: GeneralRowItem {
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, action: @escaping()->Void) {
        textLayout = TextViewLayout.init(.initialize(string: "Show All Users", color: theme.colors.accent, font: .normal(.text)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 40, stableId: stableId, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        self.textLayout.measure(width: width - 60)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return ContextShowPeersHolderView.self
    }
}


private final class ContextShowPeersHolderView : TableRowView {
    private let textView: TextView = TextView()
    private let borderView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(borderView)
        textView.isSelectable = false
        textView.userInteractionEnabled = false
    }
    
    override func updateColors() {
        super.updateColors()
        self.textView.backgroundColor = theme.colors.background
        borderView.backgroundColor = theme.colors.border
    }
    
    override func layout() {
        super.layout()
        self.textView.center()
        self.borderView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? ContextShowPeersHolderItem else {
            return
        }
        self.textView.update(item.textLayout)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
