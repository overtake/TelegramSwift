//
//  ETabRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class ETabRowView: HorizontalRowView {
    
    var overlay:ImageButton = ImageButton()
    
    override var isFlipped: Bool {
        return false
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    
        addSubview(overlay)
        
        overlay.set(handler: { [weak self] _ in
            if let item = self?.item as? ETabRowItem {
                item.clickHandler(item.stableId)
            }
        }, for: .Down)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
    }
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func layout() {
        super.layout()
        overlay.center()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated:animated)
        if let item = item as? ETabRowItem {
            overlay.style = ControlStyle(highlightColor: theme.colors.blueIcon)
            overlay.set(image: item.icon, for: .Normal)
            overlay.disableActions()
            _ = overlay.sizeToFit()
            overlay.isSelected = item.isSelected
            overlay.set(background: theme.colors.background, for: .Normal)
        }
        
    }
    
    
    
}
