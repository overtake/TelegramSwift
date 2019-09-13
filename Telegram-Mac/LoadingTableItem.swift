//
//  LoadingTableItem.swift
//  Telegram
//
//  Created by keepcoder on 11/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class LoadingTableItem: GeneralRowItem {

    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable, viewType: GeneralViewType = .legacy) {
        super.init(initialSize, height: height, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return LoadingTableRowView.self
    }
}


class LoadingTableRowView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let progress: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 20, 20))
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(progress)
        addSubview(containerView)
    }
    
    override func viewDidMoveToWindow() {
        if let _ = window {
            progress.animates = true
        } else {
            progress.animates = false
        }
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        if let item = item as? GeneralRowItem {
            containerView.background = backdorColor
            backgroundColor = item.viewType.rowBackground
        }
    }
    
    override func layout() {
        super.layout()
        
        if let item = item as? GeneralRowItem {
            switch item.viewType {
            case .legacy:
                containerView.frame = bounds
            case .modern:
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
            }
            self.containerView.setCorners(item.viewType.corners)
            progress.center()
        }
    }
    
    deinit {
        progress.animates = false
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
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
