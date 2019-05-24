//
//  MajorBackNavigationBar.swift
//  TelegramMac
//
//  Created by keepcoder on 06/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac
class MajorBackNavigationBar: BackNavigationBar {
    private let disposable:MetaDisposable = MetaDisposable()
    private let context:AccountContext
    private let peerId:PeerId
    private let badgeNode:GlobalBadgeNode
    init(_ controller: ViewController, context: AccountContext, excludePeerId:PeerId) {
        self.context = context
        self.peerId = excludePeerId
        
        var layoutChanged:(()->Void)? = nil
        badgeNode = GlobalBadgeNode(context.account, sharedContext: context.sharedContext, excludeGroupId: Namespaces.PeerGroup.archive, view: View(), layoutChanged: {
            layoutChanged?()
        })
        badgeNode.xInset = 0
        
        
        super.init(controller)
        
        addSubview(badgeNode.view!)

        
        layoutChanged = { [weak self] in
           self?.needsLayout = true
        }
        
    }
    
    override func layout() {
        super.layout()
        
        self.badgeNode.view!.setFrameOrigin(NSMakePoint(min(frame.width == minWidth ? 30 : 22, frame.width - self.badgeNode.view!.frame.width - 4), 4))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    
}
