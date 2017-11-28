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
    
    func set(item:ChatRowItem, animated:Bool) {
        self.item = item
        self.toolTip = item.fullDate
        if !item.isIncoming && !item.chatInteraction.isLogInteraction {
            if item.isUnsent {
                stateView?.removeFromSuperview()
                stateView = nil
                readImageView?.removeFromSuperview()
                readImageView = nil
                sendingView?.removeFromSuperview()
                sendingView = nil
                
                if sendingView == nil {
                    sendingView = SendingClockProgress()
                    sendingView?.setFrameOrigin(0,2)
                    addSubview(sendingView!)
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
                    let stateImage = item.isFailed ? theme.icons.sentFailed : theme.icons.chatReadMark1
                    
                    if stateView == nil {
                        stateView = ImageView()
                        self.addSubview(stateView!)
                    }
                    
                    if item.isRead && !item.isFailed && item.chatInteraction.peerId != item.account.peerId {
                        if readImageView == nil {
                            readImageView = ImageView(frame: NSMakeRect(0, 0, theme.icons.chatReadMark2.backingSize.width, theme.icons.chatReadMark2.backingSize.height))
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
        readImageView?.image = theme.icons.chatReadMark2
        self.sendingView?.backgroundColor = theme.colors.background
        
        self.needsLayout = true

    }
    

    override func layout() {
        super.layout()
        if let item = item {
            var rightInset:CGFloat = 0
            if let date = item.date {
                rightInset = date.0.size.width + 20
            }
            
            if let stateView = stateView {
                stateView.setFrameOrigin(frame.width - rightInset, item.isFailed ? 0 : 2)
            }
            if let readImageView = readImageView {
                readImageView.setFrameOrigin((frame.width - rightInset) + 4, 2)
            }
        }
        self.setNeedsDisplay()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item {
            if let date = item.date {
                date.1.draw(NSMakeRect(NSWidth(layer.bounds) - date.0.size.width, 0, date.0.size.width, date.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
            }
            if let channelViews = item.channelViews {
                ctx.draw(theme.icons.chatChannelViews, in: NSMakeRect(channelViews.0.size.width + 2, 0, theme.icons.chatChannelViews.backingSize.width, theme.icons.chatChannelViews.backingSize.height))
                
                channelViews.1.draw(NSMakeRect(0, 0, channelViews.0.size.width, channelViews.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
                
                
                if let postAuthor = item.postAuthor {
                    postAuthor.1.draw(NSMakeRect(theme.icons.chatChannelViews.backingSize.width + channelViews.0.size.width + 8, 0, postAuthor.0.size.width, postAuthor.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
                }
                
            } else {
                if let editLabel = item.editedLabel {
                    editLabel.1.draw(NSMakeRect(0, 0, editLabel.0.size.width, editLabel.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
                }
            }
        }
        
    }
    
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
}
