//
//  InstantPageMedia.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import SyncCore
import TGUIKit



struct InstantPageMedia: Equatable, Identifiable {
    let index: Int
    let media: Media
    let webpage:TelegramMediaWebpage
    let url: InstantPageUrlItem?
    let caption: RichText?
    let credit: RichText?

    var stableId: Int {
        return index
    }
    
    func withUpdatedIndex(_ index: Int) -> InstantPageMedia {
        return InstantPageMedia(index: index, media: self.media, webpage: webpage, url: self.url, caption: self.caption, credit: self.credit)
    }
    
    
    static func ==(lhs: InstantPageMedia, rhs: InstantPageMedia) -> Bool {
        return lhs.index == rhs.index && lhs.media.isEqual(to: rhs.media) && lhs.url == rhs.url && lhs.caption == rhs.caption && lhs.credit == rhs.credit
    }
}
