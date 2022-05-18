//
//  PremiumLimitRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 06.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class PremiumIncreaseLimitItem : GeneralRowItem {
    let limitType: PremiumLimitController.LimitType
    let counts: PremiumLimitController.Counts?
    let context: AccountContext
    var updatedHeight: CGFloat = 271
    let callback: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, type: PremiumLimitController.LimitType, counts: PremiumLimitController.Counts?, viewType: GeneralViewType, callback:@escaping()->Void) {
        self.limitType = type
        self.counts = counts
        self.context = context
        self.callback = callback
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        return true
    }
    
    override var height: CGFloat {
        return updatedHeight
    }
    
    override func viewClass() -> AnyClass {
        return PremiumIncreaseLimitView.self
    }
}


private final class PremiumIncreaseLimitView: GeneralContainableRowView {
    private let view = PremiumLimitView(frame: NSMakeRect(0, 0, 350, 200))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(view)
    }
    
    override func layout() {
        super.layout()
        view.frame = containerView.bounds
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? PremiumIncreaseLimitItem else {
            return
        }
        
        view.premium = item.callback
        
        let size = view.update(with: item.limitType, counts: item.counts, context: item.context, animated: animated, hasDismiss: false)

        if item.updatedHeight != size.height {
            item.updatedHeight = size.height
            item.redraw()
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

