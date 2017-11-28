//
//  SavedMessagesRowItem.swift
//  Telegram
//
//  Created by keepcoder on 25/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class SavedMessagesRowItem: TableRowItem {

    private let _stableId: AnyHashable
    private let _height: CGFloat
    fileprivate let photoSize: NSSize
    fileprivate let action:()->Void
    fileprivate let drawBottom: Bool
    override var height: CGFloat {
        return _height
    }
    override var stableId: AnyHashable {
        return _stableId
    }
    init(_ initialSize: NSSize, stableId: AnyHashable, height: CGFloat = 50, photoSize: NSSize = NSMakeSize(36, 36), drawBottom: Bool = false, action: @escaping()->Void = {}) {
        self._stableId = stableId
        self.action = action
        self.photoSize = photoSize
        self._height = height
        self.drawBottom = drawBottom
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return SavedMessagesRowView.self
    }
    
}

private class SavedMessagesRowView : TableRowView {
    private let avatar: AvatarControl = AvatarControl(font: .normal(.text))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(frameRect.height - 20, frameRect.height - 20)
        addSubview(avatar)
        
        border = [.Right]
    }
    
    override func layout() {
        super.layout()
        avatar.centerY(x: 10)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? SavedMessagesRowItem else { return }
        
        let layout = TextNode.layoutText(NSAttributedString.initialize(string: tr(.peerSavedMessages), color: item.isSelected ? .white : theme.colors.text, font: .medium(.text)), backdorColor, 1, .end, NSMakeSize(frame.width - 30 - avatar.frame.width, .greatestFiniteMagnitude), nil, false, .left)
        
        var f = focus(layout.0.size)
        f.origin.x = avatar.frame.maxX + 10
        layout.1.draw(f, in: ctx, backingScaleFactor: backingScaleFactor)
        
        if !item.isLast && item.drawBottom {
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(f.origin.x, frame.height - .borderSize, frame.width - f.origin.x, .borderSize))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        guard let item = item as? SavedMessagesRowItem else { return }
        
        avatar.setFrameSize(item.photoSize)
        let icon = theme.icons.peerSavedMessages
        avatar.setSignal(generateEmptyPhoto(avatar.frame.size, type: .icon(colors: (NSColor(0x2a9ef1), NSColor(0x72d5fd)), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatar.frame.size.width - 20, avatar.frame.size.height - 20)))), animated: false)
        needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
