//
//  GroupCallVideoOrientationRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03.09.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import TGUIKit
import SwiftSignalKit

final class GroupCallVideoOrientationRowItem : GeneralRowItem {
    
    fileprivate let account: Account
    fileprivate let select: (GroupCallSettingsState.VideoOrientation)->Void

    fileprivate let selected:GroupCallSettingsState.VideoOrientation
    
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, account: Account, customTheme: GeneralRowItem.Theme? = nil, selected: GroupCallSettingsState.VideoOrientation, select:@escaping(GroupCallSettingsState.VideoOrientation)->Void) {
        self.account = account
        self.select = select
        self.selected = selected
       
        super.init(initialSize, height: 143, stableId: stableId, viewType: viewType, customTheme: customTheme)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallVideoOrientationRowView.self
    }
}


private final class GroupCallVideoOrientationRowView : GeneralContainableRowView {
    
    private final class OrientationView : Control {

        private let images: View = View()
        private let isVertical: Bool
        required init(frame frameRect: NSRect, isVertical: Bool) {
            self.isVertical = isVertical
            super.init(frame: frameRect)
            addSubview(images)
            images.isEventLess = true
            backgroundColor = GroupCallTheme.windowBackground
            
            
            self.layer?.cornerRadius = 4
            
            set(handler: { [weak self] _ in
                self?.updateColors()
            }, for: .Normal)
            
            set(handler: { [weak self] _ in
                self?.updateColors()
            }, for: .Highlight)
        }
        
        func updateColors() {
            if isSelected || controlState == .Highlight {
                self.layer?.borderWidth = 2
                self.layer?.borderColor = GroupCallTheme.purple.cgColor
            } else {
                self.layer?.borderWidth = 0
                self.layer?.borderColor = .clear
            }
        }
        
        override var isSelected: Bool {
            didSet {
                needsLayout = true
                updateColors()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
        
        
        
        override func layout() {
            super.layout()
            
            images.removeAllSubviews()
            
            let top = ImageView()
            top.image = NSImage(named: "Icon_GroupCall_Record_Avatar1")?._cgImage
            top.isEventLess = true
            top.layer?.cornerRadius = 2
            
            images.addSubview(top)
            
            top.sizeToFit()

            
            if isVertical {
                images.setFrameSize(NSMakeSize(60, 81))
            } else {
                images.setFrameSize(NSMakeSize(80, 60))
            }
            
            
            var list:[ImageView] = []
            
            for i in 2 ... 4 {
                let imageView = ImageView()
                imageView.isEventLess = true
                imageView.image = NSImage(named: "Icon_GroupCall_Record_Avatar\(i)")?._cgImage
                imageView.setFrameSize(NSMakeSize(19, 19))
                imageView.layer?.cornerRadius = 2
                
                images.addSubview(imageView)
                list.append(imageView)
            }
            
            top.setFrameOrigin(NSMakePoint(0, 0))
            
            if isVertical {
                for (i, image) in list.enumerated() {
                    image.setFrameOrigin(NSMakePoint(CGFloat(i) * (image.frame.width + 1), 61))
                }
            } else {
                for (i, image) in list.enumerated() {
                    image.setFrameOrigin(NSMakePoint(top.frame.maxX + 1, CGFloat(i) * (image.frame.height + 1)))
                }
            }
            
            images.center()
            
        }
    }
    
    

    private let vertical = OrientationView(frame: NSMakeRect(0, 0, 120, 100), isVertical: true)
    private let horizontal = OrientationView(frame: NSMakeRect(0, 0, 120, 100), isVertical: false)

    private let verticalTextView = TextView()
    private let horizontalTextView = TextView()
    
    private let container = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        container.addSubview(vertical)
        container.addSubview(horizontal)
        container.addSubview(verticalTextView)
        container.addSubview(horizontalTextView)
        vertical.layout()
        horizontal.layout()
        
        containerView.set(handler: { [weak self] control in
            self?.updateColors()
        }, for: .Highlight)
        
        containerView.set(handler: { [weak self] control in
            self?.updateColors()
        }, for: .Normal)
        
        containerView.set(handler: { [weak self] control in
            self?.updateColors()
        }, for: .Hover)
        
        vertical.set(handler: { [weak self] _ in
            self?.select(.portrait)
        }, for: .Click)

        horizontal.set(handler: { [weak self] _ in
            self?.select(.landscape)
        }, for: .Click)
        
    }
    
    private func select(_ value: GroupCallSettingsState.VideoOrientation) {
        guard let item = item as? GroupCallVideoOrientationRowItem else {
            return
        }
        item.select(value)
    }
    
    override func updateColors() {
        super.updateColors()
        containerView.backgroundColor = containerView.controlState != .Highlight ? backdorColor : highlightColor
        borderView.backgroundColor = borderColor
    }
    
    
    var highlightColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.highlightColor
        }
        return theme.colors.grayHighlight
    }
    override var backdorColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.backgroundColor
        }
        return super.backdorColor
    }
    
    var textColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.textColor
        }
        return theme.colors.text
    }
    var secondaryColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.grayTextColor
        }
        return theme.colors.grayText
    }
    
    override var borderColor: NSColor {
        if let item = item as? GeneralRowItem, let theme = item.customTheme {
            return theme.borderColor
        }
        return theme.colors.border
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GroupCallVideoOrientationRowItem else {
            return
        }
        
        container.setFrameSize(NSMakeSize(vertical.frame.width + horizontal.frame.width + 20, 120))
        container.centerX(y: item.viewType.innerInset.top)
        
        vertical.setFrameOrigin(.zero)
        horizontal.setFrameOrigin(NSMakePoint(vertical.frame.maxX + 20, 0))

        
        let verticalLayout = TextViewLayout(.initialize(string: "Portrait", color: item.selected == .portrait ? GroupCallTheme.purple : GroupCallTheme.customTheme.grayTextColor, font: .medium(.text)))
        
        let horizontalLayout = TextViewLayout(.initialize(string: "Landscape", color: item.selected == .landscape ? GroupCallTheme.purple : GroupCallTheme.customTheme.grayTextColor, font: .medium(.text)))

        
        verticalLayout.measure(width: vertical.frame.width)
        verticalTextView.update(verticalLayout)
        
        horizontalLayout.measure(width: horizontal.frame.width)
        horizontalTextView.update(horizontalLayout)

        verticalTextView.setFrameOrigin(NSMakePoint((vertical.frame.width - verticalTextView.frame.width) / 2, vertical.frame.maxY + 5))
        
        horizontalTextView.setFrameOrigin(NSMakePoint(horizontal.frame.minX + (horizontal.frame.width - horizontalTextView.frame.width) / 2, horizontal.frame.maxY + 5))

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallVideoOrientationRowItem else {
            return
        }
        
        vertical.isSelected = item.selected == .portrait
        horizontal.isSelected = item.selected == .landscape

        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
