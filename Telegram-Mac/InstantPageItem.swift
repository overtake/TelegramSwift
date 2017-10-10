//
//  InstantPageItem.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac

protocol InstantPageItem {
    var frame: CGRect { get set }
    var hasLinks: Bool { get }
    var wantsNode: Bool { get }
    var medias: [InstantPageMedia] { get }
    
    var isInteractive: Bool { get }
    
    func matchesAnchor(_ anchor: String) -> Bool
    func drawInTile(context: CGContext)
    func node(account: Account) -> InstantPageView?
    func matchesNode(_ node: InstantPageView) -> Bool
    func linkSelectionViews() -> [InstantPageLinkSelectionView]
    
    func distanceThresholdGroup() -> Int?
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat
}
