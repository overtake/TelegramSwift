//
//  ChatLayoutUtils.swift
//  Telegram-Mac
//
//  Created by keepcoder on 19/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac

class ChatLayoutUtils: NSObject {

    static func contentSize(for media:Media, with width: CGFloat, hasText: Bool = false) -> NSSize {
        
        var size:NSSize = NSMakeSize(width, 40.0)
        
        let maxSize = NSMakeSize(min(width,320), min(width,320))
        
        if let image = media as? TelegramMediaImage {
            size = image.representationForDisplayAtSize(maxSize)?.dimensions.fitted(maxSize) ?? maxSize
            if size.width < 100 && size.height < 100 {
                size = size.aspectFitted(NSMakeSize(200, 200))
            }
            if hasText {
                size.width = max(200, size.width)
            }
            size.width = max(size.width, 100)
            //size = NSMakeSize(max(40, size.width), max(40, size.height))
        } else if let file = media as? TelegramMediaFile {
            
            var contentSize:NSSize = NSZeroSize
            for attr in file.attributes {
                if case let .ImageSize(size) = attr {
                    contentSize = size
                } else if case let .Video(_,video, _) = attr {
                    contentSize = video
                    if contentSize.width < 50 && contentSize.height < 50 {
                        contentSize = maxSize
                    }
                }
            }
            
            if file.isSticker {
                size = contentSize.aspectFitted(NSMakeSize(180, 180))
            } else if file.isInstantVideo {
                size = NSMakeSize(200, 200)
            } else if file.isVideo || file.isAnimated {
                size = contentSize.fitted(maxSize)
            } else if contentSize.height > 0 {
                size = NSMakeSize(width, 70)
            } else if !file.previewRepresentations.isEmpty {
                size = NSMakeSize(width, 70)
            }
            
        } else if let media = media as? TelegramMediaMap {
            if media.venue != nil {
                return NSMakeSize(width, 60)
            } else {
                return NSMakeSize(maxSize.width, 120)
            }
        } else if let media = media as? TelegramMediaGame {
            if let file = media.file {
                return contentSize(for: file, with: width)
            }
        }
        
        return size
    }
    
    static func contentNode(for media:Media) -> ChatMediaContentView.Type {
        
        if media is TelegramMediaImage {
            return ChatInteractiveContentView.self
        } else if let file = media as? TelegramMediaFile {
            if file.isSticker {
                return ChatStickerContentView.self
            } else if file.isInstantVideo {
                return ChatVideoMessageContentView.self
            } else if file.isVideo && !file.isAnimated {
                return ChatInteractiveContentView.self
            }  else if file.isAnimated {
                return ChatGIFContentView.self
            } else if file.isVoice {
                return ChatVoiceContentView.self
            } else if file.isMusic {
                return ChatMusicContentView.self
            } else {
                return ChatFileContentView.self
            }
        } else if media is TelegramMediaMap {
            return ChatMapContentView.self
        } else if let media = media as? TelegramMediaGame {
            if let file = media.file {
                return contentNode(for: file)
            }
        }
        
        return ChatMediaContentView.self
    }

    
    
}
