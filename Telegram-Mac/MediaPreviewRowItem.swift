//
//  MediaPreviewRowItem.swift
//  Telegram
//
//  Created by keepcoder on 19/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac
import PostboxMac

class MediaPreviewRowItem: TableRowItem {

    fileprivate let media: Media
    fileprivate let account: Account
    private let _stableId = arc4random()
    fileprivate let parameters: ChatMediaLayoutParameters?
    fileprivate let chatInteraction: ChatInteraction
    init(_ initialSize: NSSize, media: Media, account: Account) {
        self.media = media
        self.account = account
        self.chatInteraction = ChatInteraction(peerId: PeerId(0), account: account)
        if let media = media as? TelegramMediaFile {
            parameters = ChatMediaLayoutParameters.layout(for: media, isWebpage: false, chatInteraction: chatInteraction)
        } else {
            parameters = nil
        }
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        parameters?.makeLabelsForWidth(width - 20)
        
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var identifier: String {
        return super.identifier + "\(stableId)"
    }
    
    override var height: CGFloat {
        return contentSize.height + 12
    }
    
    var contentSize: NSSize {
        return ChatLayoutUtils.contentSize(for: media, with: initialSize.width - 20)
    }
    
    public func contentNode() -> ChatMediaContentView.Type {
        return ChatLayoutUtils.contentNode(for: media)
    }
    
    override func viewClass() -> AnyClass {
        return MediaPreviewRowView.self
    }
}

fileprivate class MediaPreviewRowView : TableRowView {
    
    var contentNode:ChatMediaContentView?
    
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = true
            contentNode?.needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? MediaPreviewRowItem else { return }
        
        if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
            self.contentNode?.removeFromSuperview()
            let node = item.contentNode()
            self.contentNode = node.init(frame:NSZeroRect)
            self.addSubview(self.contentNode!)
        }
        
        
        self.contentNode?.update(with: item.media, size: item.contentSize, account: item.account, parent: nil, table: item.table, parameters: item.parameters, animated: animated)
    }
    
    override func layout() {
        super.layout()
        self.contentNode?.setFrameOrigin(10, 6)
    }
    
    open override var interactionContentView:NSView {
        if let content = self.contentNode?.interactionContentView {
            return content
        }
        return self
    }
    
    
    override var backgroundColor: NSColor {
        didSet {
            contentNode?.backgroundColor = backdorColor
        }
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }
    
}


