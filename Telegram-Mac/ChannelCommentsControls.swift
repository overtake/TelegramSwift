//
//  ChatCommentsBubbleControl.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/09/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SyncCore
import Postbox
import SwiftSignalKit


final class ChannelCommentsRenderData {
    let _title: NSAttributedString
    let peers:[Peer]
    let drawBorder: Bool
    let context: AccountContext
    let message: Message?
    let hasUnread: Bool
    fileprivate var titleNode:TextNode?
    fileprivate var title:(TextNodeLayout,TextNode)?
    fileprivate var titleAttributed:NSAttributedString?
    fileprivate let handler: ()->Void
    
    init(context: AccountContext, message: Message?, hasUnread: Bool, title: NSAttributedString, peers: [Peer], drawBorder: Bool, handler: @escaping()->Void = {}) {
        self.context = context
        self.message = message
        self._title = title
        self.peers = peers
        self.drawBorder = drawBorder
        self.hasUnread = hasUnread
        self.handler = handler
    }
    
    func makeSize() {
        if self._title.string != "0" {
            self.title = TextNode.layoutText(maybeNode: titleNode, _title, .clear, 1, .end, NSMakeSize(200, 20), nil, false, .left)
        }
    }
    
    func size(_ bubbled: Bool, _ isOverlay: Bool = false) -> NSSize {
        var width: CGFloat = 0
        var height: CGFloat = 0
        if isOverlay {
            let iconSize = theme.chat_comments_overlay.backingSize
            if let title = title {
                width += title.0.size.width
                width += 10
                width = max(width, 31)
                height = max(iconSize.height + title.0.size.height + 10, width)
            } else {
                width = 31
                height = 31
            }
        } else if bubbled, let title = title {
            width += title.0.size.width
            width += (6 * 4) + 13
            if peers.isEmpty {
                width += theme.icons.channel_comments_bubble.backingSize.width
            } else {
                width += 19 * CGFloat(peers.count)
            }
            width += theme.icons.channel_comments_bubble_next.backingSize.width
            height = ChatRowItem.channelCommentsBubbleHeight
            
            if hasUnread {
                width += 10
            }
        } else if let title = title {
            width += title.0.size.width
            width += 3
            width += theme.icons.channel_comments_list.backingSize.width
            height = ChatRowItem.channelCommentsHeight
        }
        return NSMakeSize(width, height)
    }
}

class ChannelCommentsBubbleControl: Control {
    private var renderData: ChannelCommentsRenderData?
    private var mergedAvatarsView: MergedAvatarsView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
       

        if let render = renderData, let title = render.title {
            
            if render.drawBorder {
                ctx.setFillColor(theme.colors.border.withAlphaComponent(0.4).cgColor)
                ctx.fill(NSMakeRect(0, 0, frame.width, .borderSize))
            }
            
            var rect: CGRect = .zero
            
            if render.peers.isEmpty {
                var f = focus(theme.icons.channel_comments_bubble.backingSize)
                f.origin.x = 13 + 6
                rect = f
                ctx.draw(theme.icons.channel_comments_bubble, in: rect)
            } else {
                rect = focus(NSMakeSize(19 * CGFloat(render.peers.count), 20))
                rect.origin.x = 13 + 6
            }
            
            var f = focus(title.0.size)
            f.origin.x = rect.maxX + 6
            f.origin.y -= 1
            rect = f
            title.1.draw(rect, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
            
            if render.hasUnread {
                ctx.setFillColor(theme.colors.accentIconBubble_incoming.cgColor)
                let size = NSMakeSize(6, 6)
                var f = focus(size)
                f.origin.x = rect.maxX + 6
                ctx.fillEllipse(in: f)
            }
            
            f = focus(theme.icons.channel_comments_bubble_next.backingSize)
            f.origin.x = frame.width - 6 - f.width
            rect = f
            ctx.draw(theme.icons.channel_comments_bubble_next, in: rect)
        }
        

        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(data: ChannelCommentsRenderData) {
        self.renderData = data
        self.removeAllHandlers()
        
        
        self.set(handler: { [weak data] _ in
            data?.handler()
        }, for: .Click)
        
        if data.peers.isEmpty {
            mergedAvatarsView?.removeFromSuperview()
            mergedAvatarsView = nil
        } else {
            let current:MergedAvatarsView
            if let mergedAvatarsView = self.mergedAvatarsView {
                current = mergedAvatarsView
            } else {
                current = MergedAvatarsView(mergedImageSize: 20, mergedImageSpacing: 19, avatarFont: .avatar(10))
                addSubview(current)
                self.mergedAvatarsView = current
            }
            current.setFrameSize(NSMakeSize(current.mergedImageSpacing * CGFloat(data.peers.count) + 2, current.mergedImageSize))
            current.update(context: data.context, peers: data.peers, message: data.message, synchronousLoad: false)
            current.userInteractionEnabled = false
        }
        
        needsDisplay = true
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        self.mergedAvatarsView?.centerY(x: 13 + 6)
    }
    
}




class ChannelCommentsControl: Control {
    private var renderData: ChannelCommentsRenderData?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let render = renderData, let title = render.title {
                        
            var rect: CGRect = .zero
            
            var f = focus(title.0.size)
            f.origin.x = 0
            rect = f
            title.1.draw(rect, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
            
            f = focus(theme.icons.channel_comments_list.backingSize)
            f.origin.x = rect.maxX + 3
            rect = f
            ctx.draw(theme.icons.channel_comments_list, in: rect)
            
          
            
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(data: ChannelCommentsRenderData) {
        self.renderData = data
        
        self.removeAllHandlers()
        
        self.set(handler: { [weak data] _ in
            data?.handler()
        }, for: .Click)
        
        needsDisplay = true
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
    }
    
}


final class ChannelCommentsSmallControl : Control {
    private var renderData: ChannelCommentsRenderData?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let renderData = renderData {
            let size = theme.chat_comments_overlay.backingSize
            if let title = renderData.title {
                var iconFrame = focus(size)
                iconFrame.origin.y = 5
                if theme.bubbled && theme.backgroundMode.hasWallpaper {
                    ctx.draw(theme.chat_comments_overlay, in: iconFrame)
                } else {
                    ctx.draw(theme.icons.channel_comments_overlay, in: iconFrame)
                }
                var titleFrame = focus(title.0.size)
                titleFrame.origin.y = iconFrame.maxY
                title.1.draw(titleFrame, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
            } else {
                let iconFrame = focus(size)
                if theme.bubbled && theme.backgroundMode.hasWallpaper {
                    ctx.draw(theme.chat_comments_overlay, in: iconFrame)
                } else {
                    ctx.draw(theme.icons.channel_comments_overlay, in: iconFrame)
                }
            }
        }
        
    }
    
    func update(data renderData: ChannelCommentsRenderData) {
        self.renderData = renderData
        
        self.removeAllHandlers()
        
        
        self.set(handler: { [weak renderData] _ in
            renderData?.handler()
        }, for: .Click)
        
        layer?.cornerRadius = min(bounds.height, bounds.width) / 2
        needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
