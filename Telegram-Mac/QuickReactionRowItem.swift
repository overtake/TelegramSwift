//
//  CustomReactionRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 26.08.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore

final class QuickReactionRowItem : GeneralRowItem {
    let context: AccountContext
    let reaction: ContextReaction
    let select: (Control)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, reaction: ContextReaction, viewType: GeneralViewType, select:@escaping(Control)->Void) {
        self.context = context
        self.reaction = reaction
        self.select = select
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        return 42
    }
    
    override func viewClass() -> AnyClass {
        return QuickReactionRowView.self
    }
}

private final class QuickReactionRowView : GeneralContainableRowView {
    private var imageLayer: InlineStickerItemLayer?
    private let control = Control(frame: NSMakeRect(0, 0, 25, 25))
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(control)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        
        control.set(handler: { [weak self] control in
            if let item = self?.item as? QuickReactionRowItem {
                item.select(control)
            }
        }, for: .Click)
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? QuickReactionRowItem, let control = self?.control {
                item.select(control)
            }
        }, for: .Click)
    }
    
    var highlightColor: NSColor {
        return theme.colors.grayHighlight
    }
    
    
    override func updateColors() {
        super.updateColors()
        if let item = item as? GeneralRowItem {
            self.background = item.viewType.rowBackground
            let highlighted = isSelect ? self.backdorColor : highlightColor
            containerView.set(background: self.backdorColor, for: .Normal)
            containerView.set(background: highlighted, for: .Highlight)
        }
        containerView.needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        if let item = item as? GeneralRowItem {
            var rect = containerView.focus(control.frame.size)
            rect.origin.x = containerView.frame.width - rect.size.width - item.viewType.innerInset.right
            control.frame = rect
            
            textView.centerY(x: item.viewType.innerInset.left)

        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        let previous = self.item as? QuickReactionRowItem
        super.set(item: item, animated: animated)
        
        guard let item = item as? QuickReactionRowItem else {
            return
        }
        
        let textLayout = TextViewLayout.init(.initialize(string: strings().reactionSettingsQuickTitle, color: theme.colors.text, font: .normal(.text)))
        textLayout.measure(width: .greatestFiniteMagnitude)
        
        self.textView.update(textLayout)
        
        if previous?.reaction != item.reaction {
            if let imageLayer = self.imageLayer {
                performSublayerRemoval(imageLayer, animated: animated, scale: true)
                self.imageLayer = nil
            }
            let size = NSMakeSize(25, 25)
            let current: InlineStickerItemLayer
            switch item.reaction {
            case let .builtin(_, staticFile, _, _):
               current = InlineStickerItemLayer(account: item.context.account, file: staticFile, size: size)
            case let .custom(_, fileId, file):
                current = InlineStickerItemLayer(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: fileId, file: file, emoji: ""), size: size)
            }
            current.superview = self
            self.imageLayer = current
            self.control.layer?.addSublayer(current)
            current.isPlayable = true
            current.frame = CGRect(origin: .zero, size: size)
            if animated {
                current.animateAlpha(from: 0, to: 1, duration: 0.2)
                current.animateScale(from: 0.1, to: 1, duration: 0.2)
            }
        }
        needsLayout = true
    }
}
