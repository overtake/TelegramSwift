//
//  ChatListFiltersHeaderItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03.03.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class ChatListFiltersHeaderItem: GeneralRowItem {
    fileprivate let textLayout: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let sticker: LocalAnimatedSticker
    init(_ initialSize: NSSize, context: AccountContext, stableId: AnyHashable, sticker: LocalAnimatedSticker, text: NSAttributedString) {
        self.textLayout = TextViewLayout(text, alignment: .center, alwaysStaticItems: true)
        self.context = context
        self.sticker = sticker
        super.init(initialSize, stableId: stableId, inset: NSEdgeInsets(left: 20, right: 20, top: 0, bottom: 10))
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        textLayout.measure(width: width - inset.left - inset.right)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return ChatListFiltersHeaderView.self
    }
    
    override var height: CGFloat {
        return 112 + textLayout.layoutSize.height + (textLayout.layoutSize.height > 0 ? inset.bottom : 0)
    }
}


private final class ChatListFiltersHeaderView : TableRowView {
    private let stickerView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(stickerView)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListFiltersHeaderItem else { return }
        
        self.stickerView.update(with: item.sticker.file, size: NSMakeSize(112, 112), context: item.context, parent: nil, table: item.table, parameters: item.sticker.parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
        
        self.textView.update(item.textLayout)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? ChatListFiltersHeaderItem else { return }
        
        self.stickerView.centerX(y: 0)
        self.textView.centerX(y: self.stickerView.frame.maxY + item.inset.bottom)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
