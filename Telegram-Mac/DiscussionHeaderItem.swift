//
//  DiscussionHeaderItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit


class DiscussionHeaderItem: GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, text: NSAttributedString) {
        self.context = context
        self.textLayout = TextViewLayout(text, alignment: .center, alwaysStaticItems: true)
        super.init(initialSize, stableId: stableId, inset: NSEdgeInsets(left: 30.0, right: 30.0, top: 0, bottom: 10))
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        textLayout.measure(width: width - inset.left - inset.right)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return DiscussionHeaderView.self
    }
    
    override var height: CGFloat {
        return inset.top + inset.bottom + 160 + inset.top + textLayout.layoutSize.height
    }
}


private final class DiscussionHeaderView : TableRowView {
    private let imageView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: .zero)
    private let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        
        textView.isSelectable = false
        textView.userInteractionEnabled = false
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
        
        guard let item = item as? DiscussionHeaderItem else { return }
        
        imageView.update(with: LocalAnimatedSticker.discussion.file, size: NSMakeSize(160, 160), context: item.context, parent: nil, table: item.table, parameters: LocalAnimatedSticker.discussion.parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
        
//        self.imageView.image = item.icon
//        self.imageView.sizeToFit()
        
        self.textView.update(item.textLayout)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? DiscussionHeaderItem else { return }

        self.imageView.centerX(y: item.inset.top)
        self.textView.centerX(y: self.imageView.frame.maxY + item.inset.bottom)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
