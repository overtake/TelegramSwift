//
//  GeneralActionButtonRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class GeneralActionButtonRowItem : GeneralRowItem {
    fileprivate let text: String
    init(_ initialSize: NSSize, stableId: AnyHashable, text: String, viewType: GeneralViewType, action: @escaping()->Void, inset: NSEdgeInsets = NSEdgeInsetsMake(0, 20, 0, 20)) {
        self.text = text
        super.init(initialSize, stableId: stableId, viewType: viewType, action: action, inset: inset)
    }
    override func viewClass() -> AnyClass {
        return GeneralActionButtonView.self
    }
    
    override var height: CGFloat {
        return 60
    }
    
    override var backdorColor: NSColor {
        switch viewType {
        case .legacy:
            return .clear
        default:
            return super.backdorColor
        }
    }
    
    override var blockWidth: CGFloat {
        switch viewType {
        case .legacy:
            return width
        default:
            return super.blockWidth
        }
    }
}


private final class GeneralActionButtonView: GeneralContainableRowView {
    private let button = TextButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? GeneralRowItem else {
            return .clear
        }
        return item.backdorColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GeneralActionButtonRowItem else {
            return
        }
        
        button.set(background: theme.colors.accent, for: .Normal)
        button.set(font: .medium(.text), for: .Normal)
        button.set(color: theme.colors.underSelectedColor, for: .Normal)
        button.set(text: item.text, for: .Normal)
        button.sizeToFit(NSMakeSize(item.blockWidth - 20, item.height - 20))
        button.layer?.cornerRadius = 10
        button.autohighlight = false
        button.scaleOnClick = true
        button.removeAllHandlers()
        button.set(handler: { [weak item] _ in
            item?.action()
        }, for: .Click)
        
        needsLayout = true
    }
    override func layout() {
        super.layout()
        button.frame = containerView.focus(NSMakeSize(containerView.frame.width - 20, containerView.frame.height - 20))
    }
}
