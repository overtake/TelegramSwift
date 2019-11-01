//
//  InstantPageItem.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox


final class InstantPageItemArguments {
    let context: AccountContext
    let theme: InstantPageTheme
    let openMedia:(InstantPageMedia)->Void
    let openPeer:(PeerId) -> Void
    let openUrl:(InstantPageUrlItem) -> Void
    let updateWebEmbedHeight:(CGFloat) -> Void
    let updateDetailsExpanded: (Bool) -> Void
    let isExpandedItem: (InstantPageDetailsItem) -> Bool
    let effectiveRectForItem: (InstantPageItem) -> NSRect
    init(context: AccountContext, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, isExpandedItem: @escaping(InstantPageDetailsItem) -> Bool, effectiveRectForItem: @escaping(InstantPageItem) -> NSRect) {
        self.context = context
        self.theme = theme
        self.openMedia = openMedia
        self.openPeer = openPeer
        self.openUrl = openUrl
        self.updateWebEmbedHeight = updateWebEmbedHeight
        self.updateDetailsExpanded = updateDetailsExpanded
        self.isExpandedItem = isExpandedItem
        self.effectiveRectForItem = effectiveRectForItem
    }
}

protocol InstantPageItem {
    var frame: CGRect { get set }
    var hasLinks: Bool { get }
    var wantsView: Bool { get }
    var medias: [InstantPageMedia] { get }
    var separatesTiles: Bool { get }

    var isInteractive: Bool { get }
    
    func matchesAnchor(_ anchor: String) -> Bool
    func drawInTile(context: CGContext)
    func view(arguments: InstantPageItemArguments, currentExpandedDetails: [Int : Bool]?) -> (InstantPageView & NSView)?
    func matchesView(_ node: InstantPageView) -> Bool
    func linkSelectionViews() -> [InstantPageLinkSelectionView]
    
    func distanceThresholdGroup() -> Int?
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat
}

