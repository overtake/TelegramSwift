//
//  PrettyGridUtils.swift
//  TelegramMac
//
//  Created by keepcoder on 22/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import TGUIKit


let kBotInlineTypeAudio:String = "audio";
let kBotInlineTypeVideo:String = "video";
let kBotInlineTypeSticker:String = "sticker";
let kBotInlineTypeGif:String = "gif";
let kBotInlineTypeGame:String = "game";
let kBotInlineTypePhoto:String = "photo";
let kBotInlineTypeContact:String = "contact";
let kBotInlineTypeVenue:String = "venue";
let kBotInlineTypeGeo:String = "geo";
let kBotInlineTypeFile:String = "file";
let kBotInlineTypeVoice:String = "voice";

enum InputMediaContextEntry : Equatable {
    case gif(thumb:TelegramMediaImage?, file:TelegramMediaResource)
    case photo(image:TelegramMediaImage)
    case sticker(thumb: TelegramMediaImage?, file:TelegramMediaFile)

}


func ==(lhs:InputMediaContextEntry, rhs:InputMediaContextEntry) -> Bool {
    switch lhs {
    case let .gif(lhsData):
        if case let .gif(rhsData) = rhs {
            if !lhsData.file.isEqual(to: rhsData.file) {
                return false
            }
            if (lhsData.thumb == nil) != (lhsData.thumb == nil) {
                return false
            } else if let lhsThumb = lhsData.thumb, let rhsThumb = rhsData.thumb, lhsThumb != rhsThumb {
                return false
            }
            
            
            return true
        } else {
            return false
        }
    case let .sticker(lhsData):
        if case let .sticker(rhsData) = rhs {
            if lhsData.file != rhsData.file {
                return false
            }
            if (lhsData.thumb == nil) != (lhsData.thumb == nil) {
                return false
            } else if let lhsThumb = lhsData.thumb, let rhsThumb = rhsData.thumb, lhsThumb != rhsThumb {
                return false
            }
            
            
            return true
        } else {
            return false
        }
       
    case let .photo(lhsData):
        if case let .photo(rhsData) = rhs {
            if lhsData == rhsData {
                return false
            }
            
            return true
        } else {
            return false
        }
    }
}

struct InputMediaContextRow :Equatable {
    let entries:[InputMediaContextEntry]
    let results:[ChatContextResult]
    let sizes:[NSSize]
    
    func isFilled(for width:CGFloat) -> Bool {
        let sum:CGFloat = sizes.reduce(0, { (acc, size) -> CGFloat in
            return acc + size.width
        })
        if sum >= width {
            return true
        } else {
            return false
        }
    }
}
func ==(lhs:InputMediaContextRow, rhs:InputMediaContextRow) -> Bool {
    return lhs.entries == rhs.entries && lhs.results == rhs.results && lhs.sizes == rhs.sizes
}


struct InputMediaStickersRow :Equatable {
    let entries:[InputMediaContextEntry]
    let results:[FoundStickerItem]
    let sizes:[NSSize]
    let maxCount:Int
    
}
func ==(lhs:InputMediaStickersRow, rhs:InputMediaStickersRow) -> Bool {
    return lhs.entries == rhs.entries && lhs.results == rhs.results && lhs.sizes == rhs.sizes
}

func fitPrettyDimensions(_ dimensions:[NSSize], isLastRow:Bool, fitToHeight:Bool, perSize:NSSize) -> [NSSize] {
    
    var dimensions = dimensions
    
    var maxHeight:CGFloat = perSize.height
    func sizeup(_ dimensions:[NSSize]) -> [NSSize] {
        var row:[NSSize] = []
        var idx:Int = 0
        for dimension in dimensions {
            var fitted = dimension.aspectFitted(NSMakeSize(80, maxHeight))
            
            if fitted.width < maxHeight || fitted.height < maxHeight {
                let more: CGFloat = max(maxHeight - fitted.width, maxHeight - fitted.height)
                fitted.width += more
                fitted.height += more
            }
            
            if !isLastRow && idx == dimensions.count - 1 {
                let width:CGFloat = row.reduce(0, { (acc, size) -> CGFloat in
                    return acc + size.width
                })
                if width + fitted.width < perSize.width {
                    let dif = perSize.width - (width + fitted.width);
                    
                    fitted.width += dif;
                    fitted.height += dif;
                }
            }
            
            row.append(fitted)
            idx += 1
        }
        return row
    }
    var rows:[NSSize] = []
    while true {
        rows = sizeup(dimensions)
        let width:CGFloat = rows.reduce(0, { (acc, size) -> CGFloat in
            return acc + size.width
        })
        
        if width - perSize.width > 0 && dimensions.count > 1 {
            dimensions.removeLast()
            continue
        }
        if (width < perSize.width && !isLastRow) && !dimensions.isEmpty && !fitToHeight {
            maxHeight += CGFloat(6 * dimensions.count)
        } else {
            break
        }
    }
    
    return rows
}

func makeStickerEntries(_ stickers:[FoundStickerItem], initialSize:NSSize, maxSize:NSSize = NSMakeSize(80, 80)) -> [InputMediaStickersRow] {
    let s = floorToScreenPixels(scaleFactor: System.backingScale, initialSize.width/floor(initialSize.width/maxSize.width))
    let perRow = Int(initialSize.width / s)
    
    var entries:[InputMediaContextEntry] = []
    var sizes:[NSSize] = []
    var items:[FoundStickerItem] = []
    
    var rows:[InputMediaStickersRow] = []
    var stickers = stickers
    
    while !stickers.isEmpty {
        let sticker = stickers[0]
        entries.append(.sticker(thumb: TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: sticker.file.previewRepresentations, reference: nil), file: sticker.file))
        sizes.append(NSMakeSize(s, s))
        items.append(sticker)
        if entries.count == perRow {
            rows.append(InputMediaStickersRow(entries: entries, results: items, sizes: sizes, maxCount: perRow))
            entries = []
            sizes = []
            items = []
        }
        stickers.removeFirst()
    }
    
    if !entries.isEmpty {
        rows.append(InputMediaStickersRow(entries: entries, results: items, sizes: sizes, maxCount: perRow))
    }
    
    return rows
}

func makeMediaEnties(_ results:[ChatContextResult], initialSize:NSSize) -> [InputMediaContextRow] {
    var entries:[InputMediaContextEntry] = []
    var rows:[InputMediaContextRow] = []

    var dimensions:[NSSize] = []
    var removeResultIndexes:[Int] = []
    var results = results
    for i in 0 ..< results.count {
        let result = results[i]
        
        var dimension:NSSize = NSZeroSize
        switch result  {
        case let .externalReference(data):
            switch data.type {
            case kBotInlineTypeGif:
                if let content = data.content {
                    var image:TelegramMediaImage? = nil
                    if let thumbnail = data.thumbnail, let dimensions = thumbnail.dimensions {
                        image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnail.resource)], reference: nil)
                    }
                    entries.append(.gif(thumb: image, file: content.resource))
                } else {
                    removeResultIndexes.append(i)
                }
                
            case kBotInlineTypePhoto:
                var image:TelegramMediaImage? = nil
                if let content = data.content, let dimensions = content.dimensions {
                    var representations: [TelegramMediaImageRepresentation] = []
                    if let thumbnail = data.thumbnail, let dimensions = thumbnail.dimensions {
                        representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnail.resource))
                    }
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: content.resource))
                    image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, reference: nil)
                }
                if let image = image {
                    entries.append(.photo(image: image))
                } else {
                    removeResultIndexes.append(i)
                }
            case kBotInlineTypeSticker:
                if let content = data.content {
                    var image:TelegramMediaImage? = nil
                    if let thumbnail = data.thumbnail, let dimensions = thumbnail.dimensions {
                        image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnail.resource)], reference: nil)
                    }
                    entries.append(.sticker(thumb: image, file: TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), resource: content.resource, previewRepresentations: [], mimeType: "image/webp", size: nil, attributes: content.attributes)))
                } else {
                    removeResultIndexes.append(i)
                }
            default:
                removeResultIndexes.append(i)
            }
        case let .internalReference(data):
            switch data.type {
            case kBotInlineTypeGif:
                if let file = data.file {
                    dimension = file.videoSize
                    var thumb: TelegramMediaImage? = nil
                    if let image = data.image {
                        thumb = image
                    } else if !file.previewRepresentations.isEmpty {
                        thumb = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: file.previewRepresentations, reference: nil)
                    }
                    entries.append(.gif(thumb: thumb, file: file.resource))
                } else {
                    removeResultIndexes.append(i)
                }
            
            case kBotInlineTypePhoto:
                if let image = data.image, let representation = image.representations.last {
                    dimension = representation.dimensions
                    entries.append(.photo(image: image))
                } else {
                    removeResultIndexes.append(i)
                }
                
            case kBotInlineTypeSticker:
                if let file = data.file {
                    dimension = file.imageSize
                    entries.append(.sticker(thumb: data.image, file: file))
                } else {
                    removeResultIndexes.append(i)
                }
                
            default:
                removeResultIndexes.append(i)
            }
        }
        dimensions.append(dimension)
    }
    
    for i in removeResultIndexes.reversed() {
        results.remove(at: i)
    }
    
    var fitted:[[NSSize]] = []
    let f:Int = Int(round(initialSize.width / initialSize.height))
    while !dimensions.isEmpty {
        let row = fitPrettyDimensions(dimensions, isLastRow: f > dimensions.count, fitToHeight: false, perSize:initialSize)
        fitted.append(row)
        dimensions.removeSubrange(0 ..< row.count)
    }
    
    for row in fitted {
        let subentries = Array(entries.prefix(row.count))
        let subresult = Array(results.prefix(row.count))
        rows.append(InputMediaContextRow(entries: subentries, results: subresult, sizes: row))
        
        if entries.count >= row.count {
            entries.removeSubrange(0 ..< row.count)
        }
        if results.count >= row.count {
            results.removeSubrange(0 ..< row.count)
        }

    }
    
    return rows
}



