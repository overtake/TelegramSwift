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

    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable, viewType: GeneralViewType = .legacy) {
        super.init(initialSize, height: height, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return EmptyGroupstickerSearchRowView.self
    }
}


private class EmptyGroupstickerSearchRowView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let headerView: TextView = TextView()
    private let descView: TextView = TextView()
    private let imageView: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(imageView)
        containerView.addSubview(headerView)
        containerView.addSubview(descView)
        addSubview(containerView)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? GeneralRowItem {
            let contentRect: NSRect
            switch item.viewType {
            case .legacy:
                contentRect = bounds
            case .modern:
                contentRect = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
            }
            self.containerView.change(size: contentRect.size, animated: animated, corners: item.viewType.corners)
            self.containerView.change(pos: contentRect.origin, animated: animated)
        }
        
        imageView.image = theme.icons.groupStickerNotFound
        imageView.sizeToFit()
        needsLayout = true
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        if let item = item as? GeneralRowItem {
            descView.backgroundColor = backdorColor
            headerView.backgroundColor = backdorColor
            containerView.backgroundColor = backdorColor
            backgroundColor = item.viewType.rowBackground
        }
    }
    
    override func layout() {
        super.layout()
        
        if let item = item as? EmptyGroupstickerSearchRowItem {
            switch item.viewType {
            case .legacy:
                containerView.frame = bounds
            case let .modern(_, insets):
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
                
                let headerLayout = TextViewLayout(.initialize(string: L10n.groupStickersEmptyHeader, color: theme.colors.redUI, font: .medium(.text)), maximumNumberOfLines: 1)
                let descLayout = TextViewLayout(.initialize(string: L10n.groupStickersEmptyDesc, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
                headerLayout.measure(width: item.blockWidth - insets.left - insets.right - 40)
                descLayout.measure(width: item.blockWidth - insets.left - insets.right - 40)
                descView.update(descLayout)
                headerView.update(headerLayout)
                
                headerView.setFrameOrigin(insets.left + 40, 8)
                descView.setFrameOrigin(insets.left + 40, containerView.frame.height - descView.frame.height - 8)
                
                imageView.centerY(x: insets.left)
                
            }
            self.containerView.setCorners(item.viewType.corners)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
