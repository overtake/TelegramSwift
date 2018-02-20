//
//  ChatCallRowItem.swift
//  Telegram
//
//  Created by keepcoder on 05/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

class ChatCallRowItem: ChatRowItem {
    
    private(set) var headerLayout:TextViewLayout
    private(set) var timeLayout:TextViewLayout?
    
    let outgoing:Bool
    let failed: Bool
    private let requestSessionId = MetaDisposable()
    override func viewClass() -> AnyClass {
        return ChatCallRowView.self
    }
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        
        let message = object.message!
        let action = message.media[0] as! TelegramMediaAction
        let isIncoming: Bool = message.isIncoming(account, object.renderType == .bubble)
        outgoing = !message.flags.contains(.Incoming)
        headerLayout = TextViewLayout(.initialize(string: outgoing ? tr(L10n.chatCallOutgoing) : tr(L10n.chatCallIncoming), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text)), maximumNumberOfLines: 1)
        switch action.action {
        case let .phoneCall(_, reason, duration):
            let attr = NSMutableAttributedString()
            
           

            if let duration = duration, duration > 0 {
                _ = attr.append(string: String.stringForShortCallDurationSeconds(for: duration), color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                failed = false
            } else if let reason = reason {
                switch reason {
                case .busy:
                    _ = attr.append(string: outgoing ? tr(L10n.chatServiceCallCancelled) : tr(L10n.chatServiceCallMissed), color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                case .disconnect:
                    _ = attr.append(string: outgoing ? tr(L10n.chatServiceCallCancelled) : tr(L10n.chatServiceCallMissed), color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                case .hangup:
                    _ = attr.append(string: outgoing ? tr(L10n.chatServiceCallCancelled) : tr(L10n.chatServiceCallMissed), color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                case .missed:
                    _ = attr.append(string: outgoing ? tr(L10n.chatServiceCallCancelled) : tr(L10n.chatServiceCallMissed), color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text))
                }
                failed = true
            } else {
                failed = true
            }
            timeLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
            break
        default:
            failed = true
        }
        
        super.init(initialSize, chatInteraction, account, object, downloadSettings)
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        timeLayout?.measure(width: width)
        headerLayout.measure(width: width)
        
        let widths:[CGFloat] = [timeLayout?.layoutSize.width ?? width, headerLayout.layoutSize.width]
        
        return NSMakeSize((widths.max() ?? 0) + 60, 36)
    }
    
    func requestCall() {
        if let peerId = message?.id.peerId {
            let account = self.account!
            
            requestSessionId.set((phoneCall(account, peerId: peerId) |> deliverOnMainQueue).start(next: { result in
                applyUIPCallResult(account, result)
            }))
        }
    }
    
    deinit {
        requestSessionId.dispose()
    }
}



private class ChatCallRowView : ChatRowView {
    private let fallbackControl:ImageButton = ImageButton()
    private let imageView:ImageView = ImageView()
    private let headerView: TextView = TextView()
    private let timeView:TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(fallbackControl)
        addSubview(imageView)
        addSubview(headerView)
        addSubview(timeView)
        headerView.userInteractionEnabled = false
        timeView.userInteractionEnabled = false
        fallbackControl.userInteractionEnabled = false
       
    }
    
    override func mouseUp(with event: NSEvent) {
        if contentView.mouseInside() {
            if let item = item as? ChatCallRowItem {
                item.requestCall()
            }
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ChatCallRowItem {
            
            fallbackControl.set(image: theme.chat.chatCallFallbackIcon(item), for: .Normal)
            fallbackControl.sizeToFit()
            
            imageView.image = theme.chat.chatCallIcon(item)
            imageView.sizeToFit()
            headerView.update(item.headerLayout, origin: NSMakePoint(fallbackControl.frame.maxX + 10, 0))
            timeView.update(item.timeLayout, origin: NSMakePoint(fallbackControl.frame.maxX + 14 + imageView.frame.width, item.headerLayout.layoutSize.height + 3))
        }
    }
    
    override func layout() {
        super.layout()
        fallbackControl.centerY(x: 0)
        imageView.setFrameOrigin(fallbackControl.frame.maxX + 10, contentView.frame.height - 4 - imageView.frame.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
