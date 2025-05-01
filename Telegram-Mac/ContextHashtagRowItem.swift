//
//  ContextHashtagRowItem.swift
//  Telegram
//
//  Created by keepcoder on 24/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

class ContextHashtagRowItem: TableRowItem {

    let hashtag: String
    let peer: EnginePeer?
    fileprivate let selectedTextLayout: TextViewLayout
    fileprivate let textLayout: TextViewLayout
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, hashtag:String, context: AccountContext, peer: EnginePeer? = nil) {
        self.hashtag = hashtag
        self.context = context
        self.peer = peer
        textLayout = TextViewLayout(.initialize(string: hashtag, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        selectedTextLayout = TextViewLayout(.initialize(string: hashtag, color: theme.colors.underSelectedColor, font: .normal(.text)), maximumNumberOfLines: 1)
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override var height: CGFloat {
        return 44
    }
    
    override var stableId: AnyHashable {
        return "hashtag_\(hashtag)".hashValue
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - 80)
        selectedTextLayout.measure(width: width - 80)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return ContextHashtagRowView.self
    }
    
}


private class ContextHashtagRowView : TableRowView {
    private let textView: TextView = TextView()
    
    private var imageView: ImageView?
    private var avatarView: AvatarControl?

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        avatarView?.centerY(x: 20)
        imageView?.centerY(x: 20)
        textView.centerY(x: 60)
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let item = item, !item.isSelected, !item.isLast {
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(60, frame.height - .borderSize, frame.width - 20, .borderSize))
        }
    }
    
    override var backdorColor: NSColor {
        if let item = item {
            return item.isSelected ? theme.colors.accentSelect : theme.colors.background
        } else {
            return theme.colors.background
        }
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ContextHashtagRowItem else {return}
        
        textView.update(item.isSelected ? item.selectedTextLayout : item.textLayout)
        if let peer = item.peer {
            if let avatar = imageView {
                performSubviewRemoval(avatar, animated: animated)
                self.imageView = avatar
            }
            let current: AvatarControl
            if let view = self.avatarView {
                current = view
            } else {
                current = AvatarControl(font: .avatar(13))
                current.setFrameSize(28, 28)
                self.avatarView = current
                addSubview(current)
            }
            
            current.setPeer(account: item.context.account, peer: peer._asPeer())
            
        } else {
            if let avatar = avatarView {
                performSubviewRemoval(avatar, animated: animated)
                self.avatarView = avatar
            }
            let current: ImageView
            if let view = self.imageView {
                current = view
            } else {
                current = ImageView()
                current.setFrameSize(28, 28)
                self.imageView = current
                addSubview(current)
            }
            
            let textNode = TextNode.layoutText(.initialize(string: "#", color: theme.colors.underSelectedColor, font: .medium(.text)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
            
            current.image = generateImage(current.frame.size, rotatedContext: { size, ctx in
                ctx.clear(size.bounds)
                ctx.setFillColor(theme.colors.accent.cgColor)
                ctx.round(size, size.height / 2)
                ctx.fill(size.bounds)
                textNode.1.draw(size.bounds.focus(textNode.0.size), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
            })
        }
        
     
        needsLayout = true
        needsDisplay = true
    }
}
