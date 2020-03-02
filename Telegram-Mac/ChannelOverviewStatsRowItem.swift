//
//  ChannelOverviewStatsRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore
import GraphCore

struct ChannelOverviewItem : Equatable {
    let title: String
    let value: NSAttributedString
}

extension ChannelStatsValue {
    var attributedString: NSAttributedString {
        
        let deltaValue = self.current - self.previous
        let deltaCompact = abs(Int(deltaValue)).prettyNumber
        var delta = deltaValue == 0 ? "" : deltaValue > 0 ? " +\(deltaCompact)" : " -\(deltaCompact)"
        var deltaPercentage = 0.0
        if self.previous > 0.0, deltaValue != 0 {
            deltaPercentage = abs(deltaValue / self.previous)
            delta += String(format: " (%.02f%%)", deltaPercentage * 100)
        }
        
        let attr = NSMutableAttributedString()
        
        _ = attr.append(string: Int(self.current).prettyNumber, color: theme.colors.text, font: .medium(.header))
        if !delta.isEmpty {
            _ = attr.append(string: delta, color: deltaValue < 0 ? theme.colors.redUI : theme.colors.greenUI, font: .normal(.small))
        }
        
        return attr

    }
}
extension ChannelStatsPercentValue {
    var attributedString: NSAttributedString {
        let attr = NSMutableAttributedString()

        let deltaPercentage = abs(self.value / self.total)

        _ = attr.append(string: String(format: "%.02f%%", deltaPercentage * 100), color: theme.colors.text, font: .medium(.header))
        
        return attr
    }
}

private struct ChannelOverviewLayoutItem {
    let title: TextViewLayout
    let name: TextViewLayout
    
    init(item: ChannelOverviewItem) {
        self.name = TextViewLayout(.initialize(string: item.title, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        self.title = TextViewLayout(item.value, maximumNumberOfLines: 1)
    }
    
    func measure(_ width: CGFloat) {
        self.title.measure(width: width)
        self.name.measure(width: width)
    }
    
    var size: NSSize {
        return NSMakeSize(max(self.title.layoutSize.width, self.name.layoutSize.width), title.layoutSize.height + 3 + name.layoutSize.height)
    }
}

class ChannelOverviewStatsRowItem: GeneralRowItem {
    
    
    fileprivate let layoutItems:[ChannelOverviewLayoutItem]
    
    
    init(_ initialSize: NSSize, stableId: AnyHashable, items: [ChannelOverviewItem], viewType: GeneralViewType) {
        self.layoutItems = items.map {
            return ChannelOverviewLayoutItem(item: $0)
        }
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        for item in layoutItems {
            item.measure((blockWidth - viewType.innerInset.left - viewType.innerInset.right - 20) / 2)
        }
        
        return true
    }
    
    override var height: CGFloat {
        
        var height: CGFloat = 0
        
        for (i, item) in layoutItems.enumerated() {
            if i % 2 == 0 {
                height += item.size.height
                if i < layoutItems.count - 2 {
                    height += 10
                }
            }
        }
        
        return height + viewType.innerInset.bottom + viewType.innerInset.top
    }
    
    override func viewClass() -> AnyClass {
        return ChannelOverviewStatsRowView.self
    }
}

private final class ChannelOverviewLayoutView : View {
    private let titleView: TextView = TextView()
    private let nameView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(nameView)
        
        nameView.isSelectable = false
        nameView.userInteractionEnabled = false
    }
    
    override func layout() {
        super.layout()
        self.titleView.setFrameOrigin(.zero)
        self.nameView.setFrameOrigin(NSMakePoint(0, self.titleView.frame.maxY + 3))
    }
    
    func update(_ item: ChannelOverviewLayoutItem) {
        self.titleView.update(item.title)
        self.nameView.update(item.name)
        needsLayout = true
    }
    
    func updateColors() {
        
        let backgroundColor = (theme.colors.isDark ? GColorMode.night : GColorMode.day).chartBackgroundColor
        
        self.backgroundColor = backgroundColor
        self.titleView.backgroundColor = backgroundColor
        self.nameView.backgroundColor = backgroundColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ChannelOverviewStatsRowView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.containerView)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {
            return
        }
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        
        var point: CGPoint = NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top)
        for (i, subview) in self.containerView.subviews.enumerated() {
            subview.setFrameOrigin(point)
            if i < self.containerView.subviews.count - 1 {
                if (i + 1) % 2 == 0 {
                    point.x = item.viewType.innerInset.left
                    point.y += self.containerView.subviews[i + 1].frame.height
                    if i < self.containerView.subviews.count - 1  {
                        point.y += 10
                    }
                } else {
                    var width: CGFloat = self.containerView.subviews[i + 1].frame.width
                    if i > 1 {
                        width = max(width, self.containerView.subviews[i - 1].frame.width)
                    }
                    if i + 2 < self.containerView.subviews.count {
                        width = max(width, self.containerView.subviews[i + 3].frame.width)
                    }
                    
                    point.x = self.containerView.frame.width - width - item.viewType.innerInset.right
                   
                }
            }
            
        }
    }
    
    override var backdorColor: NSColor {
        return (theme.colors.isDark ? GColorMode.night : GColorMode.day).chartBackgroundColor
    }
    
    override func updateColors() {
        guard let item = item as? GeneralRowItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
        
        for subview in self.containerView.subviews {
            (subview as? ChannelOverviewLayoutView)?.updateColors()
        }
    }
    
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        
        guard let item = item as? ChannelOverviewStatsRowItem else {
            return
        }
        self.containerView.removeAllSubviews()
        
        for item in item.layoutItems {
            let view = ChannelOverviewLayoutView(frame: CGRect(origin: .zero, size: item.size))
            view.update(item)
            self.containerView.addSubview(view)
        }
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}


