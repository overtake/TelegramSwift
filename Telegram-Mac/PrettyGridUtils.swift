//
//  PrettyGridUtils.swift
//  TelegramMac
//
//  Created by keepcoder on 22/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox
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

enum InputMediaContextEntry : Hashable {
    case gif(thumb: ImageMediaReference?, file: FileMediaReference)
    case photo(image:TelegramMediaImage)
    case sticker(thumb: TelegramMediaImage?, file: TelegramMediaFile)

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .gif(_, file):
            hasher.combine(file.media.fileId.hashValue)
        case let .sticker(_, file):
            hasher.combine(file.fileId.hashValue)
        case let .photo(image):
            hasher.combine(image.imageId.hashValue)

        }
    }
    
}


func ==(lhs:InputMediaContextEntry, rhs:InputMediaContextEntry) -> Bool {
    switch lhs {
    case let .gif(lhsThumb, lhsFile):
        if case let .gif(rhsThumb, rhsFile) = rhs {
            if !lhsFile.media.isEqual(to: rhsFile.media) {
                return false
            }
            if (lhsThumb == nil) != (rhsThumb == nil) {
                return false
            } else if let lhsThumb = lhsThumb, let rhsThumb = rhsThumb, lhsThumb.media != rhsThumb.media {
                return false
            }
            return true
        } else {
            return false
        }
    case let .sticker(lhsThumb, lhsFile):
        if case let .sticker(rhsThumb, rhsFile) = rhs {
            if !lhsFile.isEqual(to: rhsFile) {
                return false
            }
            if (lhsThumb == nil) != (rhsThumb == nil) {
                return false
            } else if let lhsThumb = lhsThumb, let rhsThumb = rhsThumb, lhsThumb != rhsThumb {
                return false
            }
            return true
        } else {
            return false
        }
       
    case let .photo(lhsData):
        if case let .photo(rhsData) = rhs {
            if lhsData != rhsData {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

struct InputMediaContextRow : Hashable, Equatable {
    let entries:[InputMediaContextEntry]
    let results:[ChatContextResult]
    let messages:[Message]
    let sizes:[NSSize]
    
    init(entries:[InputMediaContextEntry], results: [ChatContextResult], sizes: [NSSize], messages: [Message] = []) {
        self.entries = entries
        self.results = results
        self.sizes = sizes
        self.messages = messages
    }
    
    func hash(into hasher: inout Hasher) {
        for message in messages {
            hasher.combine(message.id)
        }
        for result in results {
            hasher.combine(result.id)
        }
        for entry in entries {
            hasher.combine(entry.hashValue)
        }
    }
    
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
            var fitted = dimension.aspectFitted(NSMakeSize(floor(perSize.width / 3), maxHeight))
            
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
    var plus: Int = 0
    while true {
        let about = Array(dimensions.prefix(Int(ceil(perSize.width / perSize.height)) + plus))
        if !about.isEmpty {
            rows = sizeup(about)
            
            let width:CGFloat = rows.reduce(0, { (acc, size) -> CGFloat in
                return acc + size.width
            })
            
            if perSize.width < width {
                plus -= 1
                continue
            }
            if (width < perSize.width && !isLastRow) && !fitToHeight {
                maxHeight += CGFloat(6 * dimensions.count)
            } else {
                break
            }
        } else {
            break
        }
        
    }
    return rows
}

func makeStickerEntries(_ stickers:[FoundStickerItem], initialSize:NSSize, maxSize:NSSize = NSMakeSize(80, 80)) -> [InputMediaStickersRow] {
    let s = floorToScreenPixels(System.backingScale, initialSize.width/floor(initialSize.width/maxSize.width))
    let perRow = Int(initialSize.width / s)
    
    var entries:[InputMediaContextEntry] = []
    var sizes:[NSSize] = []
    var items:[FoundStickerItem] = []
    
    var rows:[InputMediaStickersRow] = []
    var stickers = stickers
    
    while !stickers.isEmpty {
        let sticker = stickers[0]
        entries.append(.sticker(thumb: TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: sticker.file.previewRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: []), file: sticker.file))
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

func makeMediaEnties(_ results:[ChatContextResult], isSavedGifs: Bool, initialSize:NSSize) -> [InputMediaContextRow] {
    var entries:[InputMediaContextEntry] = []
    var rows:[InputMediaContextRow] = []
    
    if initialSize.width == 0 {
        var bp = 0
        bp += 1
    }

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
                    var image:ImageMediaReference? = nil
                    if let thumbnail = data.thumbnail, let dimensions = thumbnail.dimensions {
                        let tmp = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnail.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        image = isSavedGifs ? ImageMediaReference.savedGif(media: tmp) : ImageMediaReference.standalone(media: tmp)
                    }
                    let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: content.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/gif", size: content.resource.size, attributes: [TelegramMediaFileAttribute.Animated])
                    entries.append(.gif(thumb: image, file: isSavedGifs ? FileMediaReference.savedGif(media: file) : FileMediaReference.standalone(media: file)))
                } else {
                    removeResultIndexes.append(i)
                }
                
            case kBotInlineTypePhoto:
                var image:TelegramMediaImage? = nil
                if let content = data.content, let dimensions = content.dimensions {
                    var representations: [TelegramMediaImageRepresentation] = []
                    if let thumbnail = data.thumbnail, let dimensions = thumbnail.dimensions {
                        representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnail.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false))
                    }
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: content.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false))
                    image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
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
                        image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: thumbnail.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                    }
                    entries.append(.sticker(thumb: image, file: TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: content.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: nil, attributes: content.attributes)))
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
                    var thumb: ImageMediaReference? = nil
                    if let image = data.image {
                        thumb = ImageMediaReference.standalone(media: image)
                    } else if !file.previewRepresentations.isEmpty {
                        let tmp = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: file.previewRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        thumb =  isSavedGifs ? ImageMediaReference.savedGif(media: tmp) : ImageMediaReference.standalone(media: tmp)
                    }
                    entries.append(.gif(thumb: thumb, file: isSavedGifs ? FileMediaReference.savedGif(media: file) : FileMediaReference.standalone(media: file)))
                } else {
                    removeResultIndexes.append(i)
                }
            
            case kBotInlineTypePhoto:
                if let image = data.image, let representation = image.representations.last {
                    dimension = representation.dimensions.size
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
    
    let rowCount = Int(floor(initialSize.width / 100))
    
    while !dimensions.isEmpty {
        //let row = fitPrettyDimensions(dimensions, isLastRow: f > dimensions.count, fitToHeight: false, perSize:initialSize)
        var row:[NSSize] = []
        
        while !dimensions.isEmpty && row.count < rowCount {
            dimensions.removeFirst()
            row.append(NSMakeSize(floor(initialSize.width / CGFloat(rowCount)), initialSize.height))
        }
        
        fitted.append(row)
    }
    
    
    if fitted.count >= 2, fitted[fitted.count - 1].count == 1 && fitted[fitted.count - 2].reduce(0, { $0 + $1.width}) < (initialSize.width - 50) {
        let width = fitted[fitted.count - 2].reduce(0, { $0 + $1.width})
        let last = fitted.removeLast()
        fitted[fitted.count - 1] = fitted[fitted.count - 1] + [NSMakeSize(initialSize.width - width, last[0].height)]
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



func makeChatGridMediaEnties(_ results:[Message], initialSize:NSSize) -> [InputMediaContextRow] {
    var entries:[InputMediaContextEntry] = []
    var rows:[InputMediaContextRow] = []
    
    var dimensions:[NSSize] = []
    var removeResultIndexes:[Int] = []
    var results = results
    for i in 0 ..< results.count {
        
        let result = results[i]
        
        if let file = result.effectiveMedia as? TelegramMediaFile {
            let dimension:NSSize = file.videoSize
            
            let imageReference: ImageMediaReference?
            if !file.previewRepresentations.isEmpty {
                let img = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: file.previewRepresentations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                imageReference = ImageMediaReference.message(message: MessageReference(result), media: img)
            } else {
                imageReference = nil
            }
            entries.append(.gif(thumb: imageReference, file: FileMediaReference.message(message: MessageReference(result), media: file)))
            
            dimensions.append(dimension)
        } else {
            removeResultIndexes.append(i)
        }
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
    
    if fitted.count >= 2, fitted[fitted.count - 1].count == 1 && fitted[fitted.count - 2].reduce(0, { $0 + $1.width}) < (initialSize.width - 50) {
        let width = fitted[fitted.count - 2].reduce(0, { $0 + $1.width})
        let last = fitted.removeLast()
        fitted[fitted.count - 1] = fitted[fitted.count - 1] + [NSMakeSize(initialSize.width - width, last[0].height)]
    }
    
    for row in fitted {
        let subentries = Array(entries.prefix(row.count))
        let subresult = Array(results.prefix(row.count))
        rows.append(InputMediaContextRow(entries: subentries, results: [], sizes: row, messages: subresult))
        
        if entries.count >= row.count {
            entries.removeSubrange(0 ..< row.count)
        }
        if results.count >= row.count {
            results.removeSubrange(0 ..< row.count)
        }
    }
    
    return rows
}

