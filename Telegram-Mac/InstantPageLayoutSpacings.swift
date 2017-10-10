//
//  InstantPageLayoutSpacings.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac

func spacingBetweenBlocks(upper: InstantPageBlock?, lower: InstantPageBlock?) -> CGFloat {
    if let upper = upper, let lower = lower {
        switch (upper, lower) {
        case (_, .cover):
            return 0.0
        case (.cover(let block), .channelBanner):
            var hasCaption: Bool = true
            switch block {
            case let .image(_, caption: caption):
                if case .empty = caption {
                    hasCaption = false
                }
            case let .video(_, caption, _, _):
                if case .empty = caption {
                    hasCaption = false
                }
            case let .slideshow(_, caption):
                if case .empty = caption {
                    hasCaption = false
                }
            default:
                hasCaption = false
            }
            
            return hasCaption ? -40 : 0
            
        case (.divider, _), (_, .divider):
            return 25.0
        case (_, .blockQuote), (.blockQuote, _), (_, .pullQuote), (.pullQuote, _):
            return 27.0
        case (_, .title):
            return 20.0
        case (.title, .subtitle):
            return 20.0
        case (.title, .authorDate):
            return 18.0
        case (.subtitle, .authorDate):
            return 20
        case (_, .authorDate):
            return 20.0
        case (.title, .paragraph), (.authorDate, .paragraph):
            return 34.0
        case (.header, .paragraph), (.subheader, .paragraph):
            return 25.0
        case (.list, .paragraph):
            return 31.0
        case (.preformatted, .paragraph):
            return 19.0
        case (.paragraph, .paragraph):
            return 25.0
        case (_, .paragraph):
            return 20.0
        case (.title, .list), (.authorDate, .list):
            return 34.0
        case (.header, .list), (.subheader, .list):
            return 31.0
        case (.preformatted, .list):
            return 19.0
        case (.paragraph, .list), (.list, .list):
            return 31
        case (_, .list):
            return 20.0
        case (.paragraph, .preformatted):
            return 19.0
        case (_, .preformatted):
            return 20.0
        case (_, .header):
            return 32.0
        case (_, .subheader):
            return 32.0
        default:
            return 20.0
        }
    } else if let lower = lower {
        switch lower {
        case .cover, .channelBanner:
            return 0.0
        default:
            return 24.0
        }
    } else {
        return 24.0
    }
}
