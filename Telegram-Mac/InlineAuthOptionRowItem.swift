//
//  InlineAuthOptionRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class InlineAuthOptionRowItem: GeneralRowItem {

    fileprivate let selected: Bool
    fileprivate let textLayout: TextViewLayout
    
    init(_ initialSize: NSSize, stableId: AnyHashable, attributedString: NSAttributedString, selected: Bool, action: @escaping()->Void) {
        self.selected = selected
        self.textLayout = TextViewLayout(attributedString, maximumNumberOfLines: 3, alwaysStaticItems: true)
        super.init(initialSize, stableId: stableId, action: action, inset: NSEdgeInsetsMake(10, 30, 10, 30))
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        textLayout.measure(width: width - inset.left - inset.right - 50)
        
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return InlineAuthOptionRowView.self
    }
    
    override var height: CGFloat {
        return max(textLayout.layoutSize.height + inset.top + inset.bottom, 30)
    }
}


private final class InlineAuthOptionRowView : TableRowView {
    private let textView = TextView()
    private let selectView: SelectingControl = SelectingControl(unselectedImage: theme.icons.chatGroupToggleUnselected, selectedImage: theme.icons.chatGroupToggleSelected)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(selectView)
        selectView.userInteractionEnabled = false
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let item = item as? InlineAuthOptionRowItem else {
            return
        }
        item.action()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? InlineAuthOptionRowItem else {
            return
        }
        
        selectView.set(selected: item.selected, animated: animated)
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? InlineAuthOptionRowItem else {
            return
        }
        
        textView.update(item.textLayout)
        
        if item.textLayout.layoutSize.height < selectView.frame.height {
            selectView.centerY(x: item.inset.left)
            textView.centerY(x: selectView.frame.maxX + 10)
        } else {
            selectView.setFrameOrigin(NSMakePoint(item.inset.left, item.inset.top))
            textView.setFrameOrigin(NSMakePoint(selectView.frame.maxX + 10, selectView.frame.minY))
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
