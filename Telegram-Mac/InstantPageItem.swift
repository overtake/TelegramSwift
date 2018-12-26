//
//  InstantPageItem.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac


final class InstantPageItemArguments {
    let account: Account
    let theme: InstantPageTheme
    let openMedia:(InstantPageMedia)->Void
    let openPeer:(PeerId) -> Void
    let openUrl:(InstantPageUrlItem) -> Void
    let updateWebEmbedHeight:(CGFloat) -> Void
    let updateDetailsExpanded: (Bool) -> Void
    init(account: Account, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void) {
        self.account = account
        self.theme = theme
        self.openMedia = openMedia
        self.openPeer = openPeer
        self.openUrl = openUrl
        self.updateWebEmbedHeight = updateWebEmbedHeight
        self.updateDetailsExpanded = updateDetailsExpanded
    }
}

protocol InstantPageItem {
    var frame: CGRect { get set }
    var hasLinks: Bool { get }
    var wantsNode: Bool { get }
    var medias: [InstantPageMedia] { get }
    
    var isInteractive: Bool { get }
    
    func matchesAnchor(_ anchor: String) -> Bool
    func drawInTile(context: CGContext)
    func node(arguments: InstantPageItemArguments, currentExpandedDetails: [Int : Bool]?) -> InstantPageView?
    func matchesNode(_ node: InstantPageView) -> Bool
    func linkSelectionViews() -> [InstantPageLinkSelectionView]
    
    func distanceThresholdGroup() -> Int?
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat
}

