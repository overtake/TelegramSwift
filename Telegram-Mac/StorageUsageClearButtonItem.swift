//
//  StorageUsageClearButtonItem.swift
//  Telegram
//
//  Created by Mike Renoir on 21.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class StorageUsageClearButtonItem : GeneralRowItem {
    fileprivate let text: String
    init(_ initialSize: NSSize, stableId: AnyHashable, text: String, enabled: Bool, viewType: GeneralViewType, action:@escaping()->Void) {
        self.text = text
        super.init(initialSize, height: 40 + viewType.innerInset.top + viewType.innerInset.bottom, stableId: stableId, viewType: viewType, action: action, enabled: enabled)
    }
    
    override func viewClass() -> AnyClass {
        return StorageUsageClearButtonView.self
    }
}


private final class StorageUsageClearButtonView: GeneralContainableRowView {
    private let button = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        button.scaleOnClick = true
        button.autohighlight = false
        button.disableActions()
        button.layer?.cornerRadius = 10
        addSubview(button)
        
        button.set(handler: { [weak self] _ in
            if let item = self?.item as? GeneralRowItem {
                item.action()
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        button.center()
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StorageUsageClearButtonItem else {
            return
        }
        
        button.set(font: .medium(.title), for: .Normal)
        button.set(color: theme.colors.underSelectedColor, for: .Normal)
        button.set(text: item.text, for: .Normal)
        button.set(background: theme.colors.accent, for: .Normal)
        
        button.isEnabled = item.enabled
        button.sizeToFit(.zero, NSMakeSize(item.blockWidth - item.viewType.innerInset.left - item.viewType.innerInset.right, 40), thatFit: true)
    }
}
