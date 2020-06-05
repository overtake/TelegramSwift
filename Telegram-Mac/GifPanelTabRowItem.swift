//
//  GifPanelTabRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05/06/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class GifPanelTabRowItem: TableRowItem {
    override var stableId: AnyHashable {
        return entry
    }
    
    let entry: GifTabEntryId
    private let selected: Bool
    
    let select:(GifTabEntryId)->Void
    
    fileprivate let icon: CGImage
    
    init(_ initialSize: NSSize, selected: Bool, entry: GifTabEntryId, select: @escaping(GifTabEntryId)->Void) {
        self.selected = selected
        self.entry = entry
        self.select = select
        var icon: CGImage
        switch entry {
        case .recent:
            icon = theme.icons.stickersTabRecent
        case .tranding:
            icon = theme.icons.stickersTabRecent
        case let .recommended(value):
            icon = generateTextIcon(.initialize(string: value, color: .white, font: .normal(18)))
        }
        
        self.icon = generateImage(NSMakeSize(35, 35), contextGenerator: { size, ctx in
            let rect = CGRect(origin: CGPoint(), size: size)
            ctx.interpolationQuality = .high
            ctx.clear(rect)
            if selected {
                ctx.round(size, .cornerRadius)
                ctx.setFillColor(theme.colors.grayForeground.cgColor)
                ctx.fill(rect)
            }
            ctx.draw(icon, in: rect.focus(icon.backingSize))
        })!
        
        
        super.init(initialSize)
    }
    
    override var height:CGFloat {
        return 40.0
    }
    override var width: CGFloat {
        return 40.0
    }
    
    override func viewClass() -> AnyClass {
        return GifPanelTabRowView.self
    }
}


private final class GifPanelTabRowView: HorizontalRowView {
    
    private let control: ImageButton = ImageButton()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(control)
        
        control.set(handler: { [weak self] control in
            if let item = self?.item as? GifPanelTabRowItem {
                item.select(item.entry)
            }
        }, for: .Click)
        
        
        control.autohighlight = false
        control.animates = false
        control.frame = NSMakeRect(0, 0, 40, 40)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? GifPanelTabRowItem {
            control.set(image: item.icon, for: .Normal)
            control.set(image: item.icon, for: .Highlight)
            control.set(image: item.icon, for: .Hover)

        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
