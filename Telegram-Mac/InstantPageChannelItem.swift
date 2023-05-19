//
//  InstantPageChannelItem.swift
//  Telegram
//
//  Created by keepcoder on 14/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox
import TGUIKit

class InstantPageChannelItem: InstantPageItem {
    var frame: CGRect
    
    let medias: [InstantPageMedia] = []
    let wantsView: Bool = true
    let hasLinks: Bool = false
    let isInteractive: Bool = false
    let separatesTiles: Bool = false

    let channel: TelegramChannel
    let overlay: Bool
    private let joinChannel:(TelegramChannel)->Void
    private let openChannel:(TelegramChannel)->Void

    init(frame: CGRect, channel: TelegramChannel, overlay: Bool, openChannel: @escaping(TelegramChannel)->Void, joinChannel: @escaping(TelegramChannel)->Void) {
        self.frame = frame
        self.channel = channel
        self.overlay = overlay
        self.openChannel = openChannel
        self.joinChannel = joinChannel
    }
    
    func drawInTile(context: CGContext) {
        
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesView(_ node: InstantPageView) -> Bool {
        return node is InstantPageChannelView
    }
    
    func view(arguments: InstantPageItemArguments, currentExpandedDetails: [Int : Bool]?) -> (InstantPageView & NSView)? {
        return InstantPageChannelView(frameRect: frame, channel: channel, overlay: overlay, openChannel: openChannel, joinChannel: joinChannel)
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    func distanceThresholdGroup() -> Int? {
        return 1000
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 1000
    }
    
}
