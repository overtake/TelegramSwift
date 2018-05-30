//
//  InstantPageAudioItem.swift
//  Telegram
//
//  Created by keepcoder on 11/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac

final class InstantPageAudioItem: InstantPageItem {
    let wantsNode: Bool = true
    let hasLinks: Bool = false
    var isInteractive: Bool {
        return true
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    var frame: CGRect
    let medias: [InstantPageMedia]
    
    let media: InstantPageMedia
    
    init(frame: CGRect, media: InstantPageMedia) {
        self.frame = frame
        self.media = media
        self.medias = [media]
    }
    
    func node(account: Account) -> InstantPageView? {
        return InstantPageAudioView(account: account, media: media)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageView) -> Bool {
        if let node = node as? InstantPageAudioView {
            return self.media == node.media
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 4
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
