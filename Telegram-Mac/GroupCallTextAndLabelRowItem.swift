//
//  GroupCallTextAndLabelRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09.03.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit


class GroupCallTextAndLabelItem: GeneralRowItem {


    
    private var labelStyle:ControlStyle = ControlStyle()
    private var textStyle:ControlStyle = ControlStyle()

    private var label:NSAttributedString
    
    var labelLayout:(TextNodeLayout, TextNode)?
    var textLayout:TextViewLayout
    
    
    init(_ initialSize:NSSize, stableId:AnyHashable, label:String, text: String, viewType: GeneralViewType, customTheme: GeneralRowItem.Theme) {
        self.label = NSAttributedString.initialize(string: label, color: customTheme.accentColor, font: .normal(FontSize.text))
        let attr = NSMutableAttributedString()
        _ = attr.append(string: text.trimmed.fullTrimmed, color: customTheme.textColor, font: .normal(.title))
        
        textLayout = TextViewLayout(attr, alwaysStaticItems: true)
        textLayout.interactions = globalLinkExecutor
        
        super.init(initialSize, stableId: stableId, viewType: viewType, customTheme: customTheme)
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallTextAndLabelRowView.self
    }
    
    var textWidth:CGFloat {
        return blockWidth - viewType.innerInset.left - viewType.innerInset.right
    }
    
    override var height: CGFloat {
        return labelsHeight + viewType.innerInset.top + viewType.innerInset.bottom - 4
    }
    
    var labelsHeight:CGFloat {
        var inset:CGFloat = 0
        if let labelLayout = labelLayout {
            inset = labelLayout.0.size.height
        }
        return (textLayout.layoutSize.height + inset + 4)
    }
    
    var textY:CGFloat {
        var inset:CGFloat = 0
        if let labelLayout = labelLayout {
            inset = labelLayout.0.size.height
        }
        return ((height - labelsHeight) / 2.0) + inset + 4.0
    }
    
    var labelY:CGFloat {
        return (height - labelsHeight) / 2.0
    }

//
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: textWidth)
        
        labelLayout = TextNode.layoutText(maybeNode: nil,  label, nil, 1, .end, NSMakeSize(textWidth, .greatestFiniteMagnitude), nil, false, .left)
        return result
    }
    
}

private class GroupCallTextAndLabelRowView: GeneralRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private var labelView:TextView = TextView()
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let item = item as? GroupCallTextAndLabelItem, let label = item.labelLayout, layer == containerView.layer {
            switch item.viewType {
            case .legacy:
                label.1.draw(NSMakeRect(item.inset.left, item.labelY, label.0.size.width, label.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
                if item.drawCustomSeparator {
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
                }
            case let .modern(position, insets):
                label.1.draw(NSMakeRect(insets.left, item.labelY, label.0.size.width, label.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
                if position.border {
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(insets.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - insets.left - insets.right, .borderSize))
                }
            }
        }
        
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? GeneralRowItem, let customTheme = item.customTheme else {
            return theme.colors.background
        }
        return customTheme.backgroundColor
    }
    override func updateColors() {
        if let item = item as? GroupCallTextAndLabelItem {
            self.labelView.backgroundColor = backdorColor
            self.containerView.backgroundColor = backdorColor
            self.background = item.viewType.rowBackground
        }
    }

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(labelView)
        self.addSubview(self.containerView)
        self.containerView.displayDelegate = self
        self.containerView.userInteractionEnabled = false
        
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GroupCallTextAndLabelItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)

        if let _ = item.labelLayout {
            labelView.setFrameOrigin(item.viewType.innerInset.left, item.textY)
        } else {
            labelView.centerY(x: item.viewType.innerInset.left)
        }
        self.containerView.setCorners(item.viewType.corners)
    }
    
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        
        if let item = item as? GroupCallTextAndLabelItem {
            labelView.update(item.textLayout)
        }
        containerView.needsDisplay = true
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
