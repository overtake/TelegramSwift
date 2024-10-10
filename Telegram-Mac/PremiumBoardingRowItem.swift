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
    fileprivate let callback: (PremiumValue)->Void

    fileprivate let premValueIndex: Int
    fileprivate let business: Bool
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let isNew: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, presentation: TelegramPresentationTheme, index: Int, value: PremiumValue, limits: PremiumLimitConfig, isLast: Bool, isNew: Bool, callback: @escaping(PremiumValue)->Void) {
        self.value = value
        self.limits = limits
        self.presentation = presentation
        self.premValueIndex = index
        self.isLastItem = isLast
        self.callback = callback
        self.business = value.isBusiness
        self.isNew = isNew
        self.titleLayout = .init(.initialize(string: value.title(limits), color: presentation.colors.text, font: .medium(.title)))
        self.infoLayout = .init(.initialize(string: value.info(limits), color: presentation.colors.grayText, font: .normal(.text)))

        super.init(initialSize, stableId: stableId, viewType: viewType, inset: NSEdgeInsets(left: 20, right: 20))
        _ = self.makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        let _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.titleLayout.measure(width: blockWidth - (viewType.innerInset.left + viewType.innerInset.right) - 50)
        self.infoLayout.measure(width: blockWidth - (viewType.innerInset.left + viewType.innerInset.right) - 50)

        return true
    }
    
    override var height: CGFloat {
        return titleLayout.layoutSize.height + 4 + infoLayout.layoutSize.height + 20
    }
    
    override func viewClass() -> AnyClass {
        return PremiumBoardingRowView.self
    }
}


private final class PremiumBoardingRowView: GeneralContainableRowView {
    private let titleView = TextView()
    private let infoView = TextView()
    private let imageView = ImageView()
    private let nextView = ImageView()
    private let overlay = Control()
    private var newBadge: ImageView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(infoView)
        addSubview(imageView)
        addSubview(nextView)
        addSubview(overlay)
        
        
        overlay.set(background: .clear, for: .Normal)
        overlay.set(background: .clear, for: .Hover)
        overlay.set(background: theme.colors.grayText.withAlphaComponent(0.1), for: .Highlight)

        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        
        overlay.set(handler: { [weak self] _ in
            if let item = self?.item as? PremiumBoardingRowItem {
                item.callback(item.value)
            }
        }, for: .Click)
        
    }
    
    override var borderColor: NSColor {
        guard let item = item as? PremiumBoardingRowItem else {
            return super.backdorColor
        }
        return item.presentation.colors.border
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? PremiumBoardingRowItem else {
            return super.backdorColor
        }
        return item.presentation.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        titleView.setFrameOrigin(NSMakePoint(50, 10))
        imageView.setFrameOrigin(NSMakePoint(titleView.frame.minX - imageView.frame.width - 10, titleView.frame.minY + 2))

        
        infoView.setFrameOrigin(NSMakePoint(50, titleView.frame.maxY + 4))
        
        nextView.centerY(x: containerView.frame.width - 20 - nextView.frame.width)
        
        if let newBadge = newBadge {
            newBadge.setFrameOrigin(NSMakePoint(titleView.frame.maxX + 5, titleView.frame.minY + 1))
        }
        
        overlay.frame = bounds
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PremiumBoardingRowItem else {
            return
        }
        
        imageView.image = item.value.icon(item.premValueIndex, business: item.business, presentation: item.presentation)
        imageView.sizeToFit()
        
        nextView.image = item.presentation.icons.premium_boarding_feature_next
        nextView.sizeToFit()
        
        titleView.update(item.titleLayout)
        infoView.update(item.infoLayout)
        
        
        if item.isNew {
            let current: ImageView
            if let view = self.newBadge {
                current = view
            } else {
                current = ImageView()
                addSubview(current)
                self.newBadge = current
            }
            current.image = generateTextIcon_NewBadge(bgColor: theme.colors.accent, textColor: theme.colors.underSelectedColor)
            current.sizeToFit()
        } else if let view = self.newBadge {
            performSubviewRemoval(view, animated: animated)
            self.newBadge = nil
        }
        
        
        needsLayout = true
    }
}
