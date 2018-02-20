//
//  RIghtView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 22/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac


class ChatRightView: View {
    
    private var stateView:ImageView?
    private var readImageView:ImageView?
    private var sendingView:SendingClockProgress?
    private var channelsViewsImage:ImageView?

    private weak var item:ChatRowItem?
    
    var isReversed: Bool {
        guard let item = item else {return false}
        
        return item.isBubbled && !item.isIncoming
    }
    
    func set(item:ChatRowItem, animated:Bool) {
        self.item = item
        self.toolTip = item.fullDate
        if !item.isIncoming
            && !item.chatInteraction.isLogInteraction {
            if item.isUnsent {
                stateView?.removeFromSuperview()
                stateView = nil
                readImageView?.removeFromSuperview()
                readImageView = nil
                if sendingView == nil {
                    sendingView = SendingClockProgress()
                    addSubview(sendingView!)
                    needsLayout = true
                }
            } else {
                
                sendingView?.removeFromSuperview()
                sendingView = nil
                
                
                if let peer = item.peer as? TelegramChannel, case .broadcast = peer.info {
                    stateView?.removeFromSuperview()
                    stateView = nil
                    readImageView?.removeFromSuperview()
                    readImageView = nil
                } else {
                    let stateImage = theme.chat.stateStateIcon(item)
                    
                    if stateView == nil {
                        stateView = ImageView()
                        self.addSubview(stateView!)
                    }
                    
                    if item.isRead && !item.isFailed && !item.isStorage {
                        if readImageView == nil {
                            readImageView = ImageView()
                            addSubview(readImageView!)
                        }
                        
                    } else {
                        readImageView?.removeFromSuperview()
                        readImageView = nil
                    }
                    
                    stateView?.image = stateImage
                    stateView?.setFrameSize(NSMakeSize(stateImage.backingSize.width, stateImage.backingSize.height))
                }
                
            }
        } else {
            stateView?.removeFromSuperview()
            stateView = nil
            readImageView?.removeFromSuperview()
            readImageView = nil
            sendingView?.removeFromSuperview()
            sendingView = nil
        }
        readImageView?.image = theme.chat.readStateIcon(item)
        readImageView?.sizeToFit()
        sendingView?.set(item: item)
        self.needsLayout = true

    }
    

    override func layout() {
        super.layout()
        if let item = item {
            var rightInset:CGFloat = 0
            if let date = item.date {
                if !isReversed {
                    rightInset = date.0.size.width + (item.isBubbled ? 16 : 20)
                }
            }
            
            if let stateView = stateView {
                rightInset += (isReversed ? stateView.frame.width : 0)
                if isReversed {
                    rightInset += 3
                }
                if item.isFailed {
                    rightInset -= 2
                }
                stateView.setFrameOrigin(frame.width - rightInset - item.stateOverlayAdditionCorner, item.isFailed ? (item.isStateOverlayLayout ? 2 : 1) : (item.isStateOverlayLayout ? 3 : 2))
            }
            
            if let sendingView = sendingView {
                if isReversed {
                    sendingView.setFrameOrigin(frame.width - sendingView.frame.width - item.stateOverlayAdditionCorner, (item.isStateOverlayLayout ? 3 : 2))
                } else {
                    sendingView.setFrameOrigin(frame.width - rightInset - item.stateOverlayAdditionCorner, (item.isStateOverlayLayout ? 3 : 2))
                }
            }

            
            if let readImageView = readImageView {
                readImageView.setFrameOrigin((frame.width - rightInset) + 4 - item.stateOverlayAdditionCorner, (item.isStateOverlayLayout ? 3 : 2))
            }
        }
        self.setNeedsDisplay()
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let item = item {
            
            if item.isStateOverlayLayout {
                ctx.round(frame.size, frame.height/2)
                ctx.setFillColor(theme.colors.blackTransparent.cgColor)
                ctx.fill(layer.bounds)
            }
            
           // super.draw(layer, in: ctx)

            let additional: CGFloat = 0
            
            if let date = item.date {
                date.1.draw(NSMakeRect(frame.width - date.0.size.width - (isReversed ? 16 : 0) - item.stateOverlayAdditionCorner - additional, item.isBubbled ? (item.isStateOverlayLayout ? 2 : 1) : 0, date.0.size.width, date.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                
                if let editLabel = item.editedLabel {
                    editLabel.1.draw(NSMakeRect(frame.width - date.0.size.width - editLabel.0.size.width - item.stateOverlayAdditionCorner - (isReversed || (stateView != nil) ? 23 : 5), item.isBubbled ? (item.isStateOverlayLayout ? 2 : 1) : 0, editLabel.0.size.width, editLabel.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                }
            }
            if let channelViews = item.channelViews {
                let icon = theme.chat.channelViewsIcon(item)
                ctx.draw(icon, in: NSMakeRect(channelViews.0.size.width + 2 + item.stateOverlayAdditionCorner, item.isBubbled ? (item.isStateOverlayLayout ? 1 : 0) : 0, icon.backingSize.width, icon.backingSize.height))
                
                channelViews.1.draw(NSMakeRect(item.stateOverlayAdditionCorner, item.isBubbled ? (item.isStateOverlayLayout ? 2 : 0) : 0, channelViews.0.size.width, channelViews.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                
                
                if let postAuthor = item.postAuthor {
                    postAuthor.1.draw(NSMakeRect(icon.backingSize.width + channelViews.0.size.width + 8 + item.stateOverlayAdditionCorner, item.isBubbled ? (item.isStateOverlayLayout ? 2 : 1) : 0, postAuthor.0.size.width, postAuthor.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                }
                
            }
            
        }
        
    }
    
    override func mouseUp(with event: NSEvent) {
        superview?.mouseUp(with: event)
    }
    
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
}
