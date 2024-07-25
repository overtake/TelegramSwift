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
    init(_ initialSize: NSSize, stableId: AnyHashable, text: String, viewType: GeneralViewType, action: @escaping()->Void) {
        self.text = text
        super.init(initialSize, stableId: stableId, viewType: viewType, action: action)
    }
    override func viewClass() -> AnyClass {
        return GeneralActionButtonView.self
    }
    
    override var height: CGFloat {
        return 60
    }
}


private final class GeneralActionButtonView: GeneralContainableRowView {
    private let button = TextButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
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
