//
//  PaymentsCheckoutPriceItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation



import Foundation
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TGUIKit

final class PaymentsCheckoutPriceItem : GeneralRowItem {
    fileprivate let titleLayout: TextViewLayout
    fileprivate let priceLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, title: String, price: String, font: NSFont, color: NSColor, viewType: GeneralViewType) {
        
        self.titleLayout = TextViewLayout(.initialize(string: title, color: color, font: font), maximumNumberOfLines: 1)
        self.priceLayout = TextViewLayout(.initialize(string: price, color: color, font: font))

        super.init(initialSize, viewType: viewType)
    }
    
    private var contentHeight: CGFloat = 0
    fileprivate private(set) var imageSize: NSSize = .zero
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        titleLayout.measure(width: blockWidth / 2 - 10 - viewType.innerInset.left - viewType.innerInset.right)
        priceLayout.measure(width: blockWidth / 2 - 10 - viewType.innerInset.left - viewType.innerInset.right)

        contentHeight = max(titleLayout.layoutSize.height, priceLayout.layoutSize.height)
        
        return true
    }
    
    override var height: CGFloat {
        return  viewType.innerInset.bottom + contentHeight + viewType.innerInset.top
    }
    
    override func viewClass() -> AnyClass {
        return PaymentsCheckoutPriceView.self
    }
    
    override var hasBorder: Bool {
        return false
    }
}


private final class PaymentsCheckoutPriceView : GeneralContainableRowView {
    private let title: TextView = TextView()
    private let price: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(price)
        title.userInteractionEnabled = false
        title.isSelectable = false
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PaymentsCheckoutPriceItem else {
            return
        }
        title.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
        price.setFrameOrigin(NSMakePoint(item.blockWidth - item.viewType.innerInset.left - price.frame.width, item.viewType.innerInset.top))
    }
    

    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        
        guard let item = item as? PaymentsCheckoutPriceItem else {
            return
        }
        
        title.update(item.titleLayout)
        price.update(item.priceLayout)
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
