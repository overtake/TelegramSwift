//
//  EmptyGroupstickerSearchRowItem.swift
//  Telegram
//
//  Created by keepcoder on 25/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class EmptyGroupstickerSearchRowItem: GeneralRowItem {

    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable, inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0)) {
        super.init(initialSize, height: height, stableId: stableId, inset: inset)
    }
    
    override func viewClass() -> AnyClass {
        return EmptyGroupstickerSearchRowView.self
    }
}


private class EmptyGroupstickerSearchRowView : TableRowView {
    private let headerView: TextView = TextView()
    private let descView: TextView = TextView()
    private let imageView: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(headerView)
        addSubview(descView)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        imageView.image = theme.icons.groupStickerNotFound
        imageView.sizeToFit()
        needsLayout = true
    }
    
    override func updateColors() {
        descView.backgroundColor = backdorColor
        headerView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        
        if let item = item as? EmptyGroupstickerSearchRowItem {
            let headerLayout = TextViewLayout(.initialize(string: tr(L10n.groupStickersEmptyHeader), color: theme.colors.redUI, font: .medium(.text)), maximumNumberOfLines: 1)
            let descLayout = TextViewLayout(.initialize(string: tr(L10n.groupStickersEmptyDesc), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
            headerLayout.measure(width: frame.width - item.inset.left - item.inset.right - 40)
            descLayout.measure(width: frame.width - item.inset.left - item.inset.right - 40)
            descView.update(descLayout)
            headerView.update(headerLayout)
            
            headerView.setFrameOrigin(item.inset.left + 40, 8)
            descView.setFrameOrigin(item.inset.left + 40, frame.height - descView.frame.height - 8)
            
            imageView.centerY(x: item.inset.left)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
