//
//  ChatLayoutUtils.swift
//  Telegram-Mac
//
//  Created by keepcoder on 19/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox

class ChatLayoutUtils: NSObject {

    static func contentSize(for media:Media, with width: CGFloat, hasText: Bool = false) -> NSSize {
        
        var size:NSSize = NSMakeSize(width, 40.0)
        
        let maxSize = NSMakeSize(min(width,320), min(width,320))
        
        if let image = media as? TelegramMediaImage {
            size = image.representationForDisplayAtSize(PixelDimensions(maxSize))?.dimensions.size.fitted(maxSize) ?? maxSize
            if size.width < 100 && size.height < 100 {
                size = size.aspectFitted(NSMakeSize(200, 200))
            }
            if hasText {
                size.width = max(maxSize.width, size.width)
            }
            size.width = max(size.width, 100)
            size = NSMakeSize(max(46, size.width), max(46, size.height))
        } else if let file = media as? TelegramMediaFile {
            
            var contentSize:NSSize = NSZeroSize
            for attr in file.attributes {
                if case let .ImageSize(size) = attr {
                    contentSize = size.size
                } else if case let .Video(_,video, _) = attr {
                    contentSize = video.size
                    if contentSize.width < 50 && contentSize.height < 50 {
                        contentSize = maxSize
                    }
                } else if case .Audio = attr {
                    return NSMakeSize(width, 40)
                }
            }
            if file.isAnimatedSticker {
                let dimensions = file.dimensions?.size
                size = NSMakeSize(240, 240)
                if file.isEmojiAnimatedSticker {
                    size = NSMakeSize(112, 112)
                }
                if let dimensions = dimensions {
                    size = dimensions.aspectFitted(size)
                }
            } else if file.isStaticSticker {
                if contentSize == NSZeroSize {
                    return NSMakeSize(210, 210)
                }
                size = contentSize.aspectFitted(NSMakeSize(210, 210))
            } else if file.isInstantVideo {
                size = NSMakeSize(200, 200)
            } else if file.isVideo || (file.isAnimated && !file.mimeType.lowercased().hasSuffix("gif")) {

                if file.isVideo && contentSize.width > contentSize.height {
                    size = contentSize.aspectFitted(NSMakeSize(min(420, width), contentSize.height))
                } else {
                    size = contentSize.fitted(maxSize)
                    if hasText {
                      //  size.width = max(maxSize.width, size.width)
                    }
                }
                if hasText {
                    size.width = max(maxSize.width, size.width)
                }
                
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
            if file.isAnimatedSticker {
                return MediaAnimatedStickerView.self
            } else if file.isStaticSticker {
                return ChatStickerContentView.self
            } else if file.isInstantVideo {
                return ChatVideoMessageContentView.self
            } else if file.isVideo && !file.isAnimated {
                return ChatInteractiveContentView.self
            }  else if file.isAnimated && !file.mimeType.lowercased().hasSuffix("gif") {
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
