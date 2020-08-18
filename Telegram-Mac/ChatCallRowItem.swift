//
//  ChatCallRowItem.swift
//  Telegram
//
//  Created by keepcoder on 05/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

class ChatCallRowItem: ChatRowItem {
    
    private(set) var headerLayout:TextViewLayout
    private(set) var timeLayout:TextViewLayout?
    
    let outgoing:Bool
    let failed: Bool
    let isVideo: Bool
    private let requestSessionId = MetaDisposable()
    override func viewClass() -> AnyClass {
        return ChatCallRowView.self
    }
    
    private let callId: Int64?
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        
        let message = object.message!
        let action = message.media[0] as! TelegramMediaAction
        let isIncoming: Bool = message.isIncoming(context.account, object.renderType == .bubble)
        outgoing = !message.flags.contains(.Incoming)
        
        let video: Bool
        switch action.action {
        case let .phoneCall(callId, _, _, isVideo):
            video = isVideo
            self.callId = callId
        default:
            video = false
            self.callId = nil
        }
        self.isVideo = video
        
        headerLayout = TextViewLayout(.initialize(string: outgoing ? (video ? L10n.chatVideoCallOutgoing : L10n.chatCallOutgoing) : (video ? L10n.chatVideoCallIncoming : L10n.chatCallIncoming), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text)), maximumNumberOfLines: 1)
        switch action.action {
        case let .phoneCall(_, reason, duration, _):
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
        
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        timeLayout?.measure(width: width)
        headerLayout.measure(width: width)
        
        let widths:[CGFloat] = [timeLayout?.layoutSize.width ?? width, headerLayout.layoutSize.width]
        
        return NSMakeSize((widths.max() ?? 0) + 60, 36)
    }
    
    func requestCall() {
        if let peerId = message?.id.peerId {
            let context = self.context
            
            requestSessionId.set((phoneCall(account: context.account, sharedContext: context.sharedContext, peerId: peerId, isVideo: isVideo) |> deliverOnMainQueue).start(next: { result in
                applyUIPCallResult(context.sharedContext, result)
            }))
        }
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        
        let context = self.context
        let callId = self.callId ?? 0
        
        return super.menuItems(in: location) |> map { items in
            var items = items
            
            
            let logPath = callLogsPath(account: context.account)
            
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: logPath), includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsSubdirectoryDescendants], errorHandler: nil) else {
                return items
            }
            
            var foundLog: String? = nil
            
            while let item = enumerator.nextObject() {
                guard let url = item as? NSURL else {
                    continue
                }
                guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else {
                    continue
                }
                if let value = resourceValues[.isDirectoryKey] as? Bool, value {
                    continue
                }
                if let file = url.path {
                    if file.contains("\(callId)") {
                        foundLog = file
                        break
                    }
                }
            }
            if let foundLog = foundLog {
                items.append(ContextSeparatorItem())
                items.append(.init(L10n.shareCallLogs, handler: {
                    showModal(with: ShareModalController(ShareUrlObject(context, url: foundLog)), for: context.window)
                }))
            }
            
            
            return items
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
        
        fallbackControl.animates = false
        
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
            _ = fallbackControl.sizeToFit()
            
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
