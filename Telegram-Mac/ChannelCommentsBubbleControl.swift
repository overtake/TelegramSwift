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
    
    let context: AccountContext
    let message: Message?
    
    fileprivate var titleNode:TextNode?
    fileprivate var title:(TextNodeLayout,TextNode)?
    fileprivate var titleAttributed:NSAttributedString?

    fileprivate let handler: ()->Void
    
    init(context: AccountContext, message: Message?, title: NSAttributedString, peers: [Peer], handler: @escaping()->Void = {}) {
        self.context = context
        self.message = message
        self._title = title
        self.peers = peers
        self.handler = handler
    }
    
    func makeSize() {
        self.title = TextNode.layoutText(maybeNode: titleNode, _title, .clear, 1, .end, NSMakeSize(200, 20), nil, false, .left)
    }
    
    func size(_ bubbled: Bool) -> NSSize {
        if let title = self.title {
            var width: CGFloat = 0
            if bubbled {
                width += title.0.size.width
                width += (6 * 4) + 13
                if peers.isEmpty {
                    width += theme.icons.channel_comments_bubble.backingSize.width
                } else {
                    width += 19 * CGFloat(peers.count)
                }
                width += theme.icons.channel_comments_bubble_next.backingSize.width
            } else {
                width += title.0.size.width
                width += 6
                width += theme.icons.channel_comments_list.backingSize.width
            }
            
            return NSMakeSize(width, bubbled ? ChatRowItem.channelCommentsBubbleHeight: ChatRowItem.channelCommentsHeight)
        }
        return .zero
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
            
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(0, 0, frame.width, .borderSize))
            
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
            f.origin.x = rect.maxX + 6
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
