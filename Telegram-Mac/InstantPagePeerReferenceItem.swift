//
//  InstantPagePeerReferenceItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import SyncCore

final class InstantPagePeerReferenceItem: InstantPageItem {
   

    let hasLinks: Bool = false
    let isInteractive: Bool = false
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    var frame: CGRect
    let wantsView: Bool = true
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia] = []
    
    let initialPeer: Peer
    let safeInset: CGFloat
    let transparent: Bool
    let rtl: Bool
    
    init(frame: CGRect, initialPeer: Peer, safeInset: CGFloat, transparent: Bool, rtl: Bool) {
        self.frame = frame
        self.initialPeer = initialPeer
        self.safeInset = safeInset
        self.transparent = transparent
        self.rtl = rtl
    }
    
    func view(arguments: InstantPageItemArguments, currentExpandedDetails: [Int : Bool]?) -> (InstantPageView & NSView)? {
        return nil
    }
    
    func matchesView(_ node: InstantPageView) -> Bool {
        return false
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func distanceThresholdGroup() -> Int? {
        return 5
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 1000.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    func drawInTile(context: CGContext) {
    }
}
