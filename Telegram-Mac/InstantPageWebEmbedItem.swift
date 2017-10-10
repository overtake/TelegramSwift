//
//  InstantPageWebEmbedItem.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac

final class InstantPageWebEmbedItem: InstantPageItem {
    var frame: CGRect
    let hasLinks: Bool = false
    let wantsNode: Bool = true
    let medias: [InstantPageMedia] = []
    
    let url: String?
    let html: String?
    let enableScrolling: Bool
    
    let isInteractive: Bool = false
    
    init(frame: CGRect, url: String?, html: String?, enableScrolling: Bool) {
        self.frame = frame
        self.url = url
        self.html = html
        self.enableScrolling = enableScrolling
    }
    
    func node(account: Account) -> InstantPageView? {
        return instantPageWebEmbedView(frame: self.frame, url: self.url, html: self.html, enableScrolling: self.enableScrolling)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageView) -> Bool {
        if let node = node as? instantPageWebEmbedView {
            return self.url == node.url && self.html == node.html
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 3
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 1000.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    func drawInTile(context: CGContext) {
    }
}
