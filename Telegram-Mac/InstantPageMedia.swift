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
    let caption: String?
    
    var stableId: Int {
        return index
    }
    
    static func ==(lhs: InstantPageMedia, rhs: InstantPageMedia) -> Bool {
        return lhs.index == rhs.index && lhs.media.isEqual(rhs.media) && lhs.caption == rhs.caption
    }
}
