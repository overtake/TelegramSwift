//
//  ChatLayoutUtils.swift
//  Telegram-Mac
//
//  Created by keepcoder on 19/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox

class ChatLayoutUtils: NSObject {

    static func contentSize(for media:Media, with width: CGFloat, hasText: Bool = false, webpIsFile: Bool = false) -> NSSize {
        
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
                } else if case .Audio = attr, !file.isVideo {
                    return NSMakeSize(width, 40)
                }
            }
            if file.isWebm || file.isVideoSticker {
                let dimensions = file.dimensions?.size
                size = NSMakeSize(208, 208)
                if file.isEmojiAnimatedSticker {
                    size = NSMakeSize(112, 112)
                }
                if let dimensions = dimensions {
                    size = dimensions.aspectFitted(size)
                }
            } else if file.isAnimatedSticker && !webpIsFile {
                let dimensions = file.dimensions?.size
                size = NSMakeSize(208, 208)
                if file.isEmojiAnimatedSticker {
                    size = NSMakeSize(112, 112)
                }
                if let dimensions = dimensions {
                    size = dimensions.aspectFitted(size)
                }
            } else if file.isStaticSticker && !webpIsFile {
                
                var sz = NSMakeSize(208, 208)
                if file.fileName == "telegram-animoji.tgs" {
                    sz = NSMakeSize(112, 112)
                }
                if contentSize == NSZeroSize {
                    return sz
                }
                size = contentSize.aspectFitted(sz)
                size = NSMakeSize(max(size.width, 40), max(size.height, 40))
            } else if file.isInstantVideo {
                size = NSMakeSize(280, 280)
            } else if file.isVideo || (file.isAnimated && !file.mimeType.lowercased().hasSuffix("gif")) {

                var contentSize = contentSize
                
                
                if contentSize.width == 0 || contentSize.height == 0 {
                    contentSize = NSMakeSize(300, 300)
                }
                
                let aspectRatio = contentSize.width / contentSize.height
                let addition = max(300 - contentSize.width, 300 - contentSize.height)
                
                if addition > 0 {
                    contentSize.width += addition * aspectRatio
                    contentSize.height += addition
                }
                
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
        } else if media is TelegramMediaDice {
            size = NSMakeSize(128, 128)
        }
        
        return size
    }
    
    static func contentNode(for media:Media, packs: Bool = false, webpIsFile: Bool = false) -> ChatMediaContentView.Type {
        
        if media is TelegramMediaImage {
            return ChatInteractiveContentView.self
        } else if let file = media as? TelegramMediaFile {
            if file.probablySticker {
                return StickerMediaContentView.self
            } else if file.isInstantVideo {
                return ChatVideoMessageContentView.self
            } else if file.isVideo && !file.isAnimated {
                return ChatInteractiveContentView.self
            }  else if file.isAnimated && !file.mimeType.lowercased().hasSuffix("gif") {
                return ChatInteractiveContentView.self
            } else if file.isVoice {
                return ChatVoiceContentView.self
            } else if file.isMusic {
                return ChatMusicContentView.self
            } else {
                return ChatFileContentView.self
            }
        } else if media is TelegramMediaMap {
            return ChatMapContentView.self
        } else if let media = media as? TelegramMediaDice {
            if media.emoji == slotsEmoji {
                return SlotsMediaContentView.self
            } else {
                return ChatDiceContentView.self
            }
        } else if let media = media as? TelegramMediaGame {
            if let file = media.file {
                return contentNode(for: file)
            }
        }
        
        return ChatMediaContentView.self
    }

    
    
}
