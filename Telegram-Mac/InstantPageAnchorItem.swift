//
//  InstantPageAnchorItem.swift
//  Telegram
//
//  Created by keepcoder on 14/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac

final class InstantPageAnchorItem: InstantPageItem {
    var frame: CGRect

    let medias: [InstantPageMedia] = []
    let wantsNode: Bool = false
    let hasLinks: Bool = false
    let isInteractive: Bool = false
    
    private let anchor: String
    
    init(frame: CGRect, anchor: String) {
        self.anchor = anchor
        self.frame = frame
    }
    
    func drawInTile(context: CGContext) {
        
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return self.anchor == anchor
    }
    
    func matchesNode(_ node: InstantPageView) -> Bool {
        return false
    }
    
    func node(account: Account) -> InstantPageView? {
        return nil
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
    
}
