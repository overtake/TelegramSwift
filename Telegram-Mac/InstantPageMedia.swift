//
//  InstantPageMedia.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac

struct InstantPageMedia: Equatable, Identifiable {
    let index: Int
    let media: Media
    let webpage:TelegramMediaWebpage
    let caption: String?
    
    var stableId: Int {
        return index
    }
    
    func withUpdatedIndex(_ index: Int) -> InstantPageMedia {
        return InstantPageMedia(index: index, media: self.media, webpage: webpage, caption: self.caption)
    }
    
    static func ==(lhs: InstantPageMedia, rhs: InstantPageMedia) -> Bool {
        return lhs.index == rhs.index && lhs.media.isEqual(rhs.media) && lhs.caption == rhs.caption
    }
}
