//
//  ContextSearchQuickHashtag.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22.10.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import DateUtils
import TGUIKit
import Postbox
import Strings


class ContextSearchQuickHashtagItem: GeneralRowItem {

    let hashtag: String
    let peer: EnginePeer?

    
    fileprivate let selectedTextLayout: TextViewLayout
    fileprivate let textLayout: TextViewLayout
    
    fileprivate let selectedInfoLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout

    
    fileprivate let context: AccountContext
    
    init(_ initialSize: NSSize, stableId: AnyHashable, hashtag:String, peer: EnginePeer?, context: AccountContext) {
        self.context = context
        self.peer = peer
        
        let headerText: String
        if let peer = peer {
            self.hashtag = "#" + hashtag + "@" + peer.addressName!
        } else {
            self.hashtag = "#" + hashtag
        }
        
        headerText = strings().inputContextHashtashHelpUse(self.hashtag)

        
        textLayout = TextViewLayout(.initialize(string: headerText, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        selectedTextLayout = TextViewLayout(.initialize(string: headerText, color: theme.colors.underSelectedColor, font: .medium(.text)), maximumNumberOfLines: 1)
        
        
        let infoText: String
        if let _ = peer {
            infoText = strings().inputContextHashtashHelpChannel
        } else {
            infoText = strings().inputContextHashtashHelpBasic
        }
        
        infoLayout = TextViewLayout(.initialize(string: infoText, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        selectedInfoLayout = TextViewLayout(.initialize(string: infoText, color: theme.colors.underSelectedColor, font: .normal(.text)), maximumNumberOfLines: 1)

        
        super.init(initialSize, height: 44, stableId: stableId)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - 100)
        selectedTextLayout.measure(width: width - 100)
        infoLayout.measure(width: width - 80)
        selectedInfoLayout.measure(width: width - 80)

        return success
    }
    
    override func viewClass() -> AnyClass {
        return ContextSearchQuickHashtagView.self
    }
    
}


private class ContextSearchQuickHashtagView : TableRowView {
    private let textView: TextView = TextView()
    private let infoView = TextView()
    private var imageView: ImageView?
    private var avatarView: AvatarControl?
    private var isNewView: ImageView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(textView)
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        addSubview(infoView)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        avatarView?.centerY(x: 20)
        imageView?.centerY(x: 20)
        textView.centerY(x: 60)
        textView.setFrameOrigin(NSMakePoint(60, 5))
        infoView.setFrameOrigin(NSMakePoint(60, frame.height - infoView.frame.height - 5))
        
        if let isNewView {
            isNewView.setFrameOrigin(NSMakePoint(textView.frame.maxX + 5, textView.frame.minY))
        }

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
        
        guard let item = item as? ContextSearchQuickHashtagItem else {return}
        
        textView.update(item.isSelected ? item.selectedTextLayout : item.textLayout)
        infoView.update(item.isSelected ? item.selectedInfoLayout : item.infoLayout)
        
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
            
            do {
                if !FastSettings.hasHashtagChannelBadge {
                    let current: ImageView
                    if let view = self.isNewView {
                        current = view
                    } else {
                        current = ImageView()
                        self.isNewView = current
                        addSubview(current)
                    }
                    
                    current.image = generateTextIcon_NewBadge(bgColor: item.isSelected ? theme.colors.underSelectedColor : theme.colors.accent, textColor: !item.isSelected ? theme.colors.underSelectedColor : theme.colors.accent)
                    current.sizeToFit()
                } else {
                    if let isNewView = isNewView {
                        performSubviewRemoval(isNewView, animated: animated)
                        self.isNewView = nil
                    }
                }
            }
            
        } else {
            if let avatar = avatarView {
                performSubviewRemoval(avatar, animated: animated)
                self.avatarView = avatar
            }
            if let isNewView = isNewView {
                performSubviewRemoval(isNewView, animated: animated)
                self.isNewView = nil
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
