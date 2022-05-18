//
//  PremiumBoardingRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 10.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class PremiumBoardingRowItem : GeneralRowItem {
    fileprivate let value : PremiumValue
    fileprivate let limits: PremiumLimitConfig
    
    fileprivate let titleLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    
    fileprivate let isLastItem: Bool

    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, value: PremiumValue, limits: PremiumLimitConfig, isLast: Bool) {
        self.value = value
        self.limits = limits
        self.isLastItem = isLast
        self.titleLayout = .init(.initialize(string: value.title(limits), color: theme.colors.text, font: .medium(.title)))
        self.infoLayout = .init(.initialize(string: value.info(limits), color: theme.colors.grayText, font: .normal(.text)))

        super.init(initialSize, stableId: stableId, viewType: viewType)
        _ = self.makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        let _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.titleLayout.measure(width: width - 30 - 50)
        self.infoLayout.measure(width: width - 30 - 50)

        return true
    }
    
    override var height: CGFloat {
        return titleLayout.layoutSize.height + 4 + infoLayout.layoutSize.height + 20
    }
    
    override func viewClass() -> AnyClass {
        return PremiumBoardingRowView.self
    }
}


private final class PremiumBoardingRowView: GeneralRowView {
    private let titleView = TextView()
    private let infoView = TextView()
    private let borderView = View()
    private let imageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(infoView)
        addSubview(imageView)
        addSubview(borderView)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        titleView.setFrameOrigin(NSMakePoint(50, 10))
        imageView.setFrameOrigin(NSMakePoint(titleView.frame.minX - imageView.frame.width - 10, titleView.frame.minY + 2))

        
        infoView.setFrameOrigin(NSMakePoint(50, titleView.frame.maxY + 4))
        borderView.frame = NSMakeRect(50, frame.height - .borderSize, frame.width - 50, .borderSize)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PremiumBoardingRowItem else {
            return
        }
        
        imageView.image = item.value.icon
        imageView.sizeToFit()
        
        titleView.update(item.titleLayout)
        infoView.update(item.infoLayout)
        
        borderView.backgroundColor = theme.colors.border
        borderView.isHidden = item.isLastItem
        
        needsLayout = true
    }
}
