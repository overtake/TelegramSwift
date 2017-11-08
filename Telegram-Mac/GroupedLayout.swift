//
//  GroupedLayout.swift
//  Telegram
//
//  Created by keepcoder on 31/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit
import PostboxMac

private final class MessagePhotoInfo {
    let mid:MessageId
    let imageSize: NSSize
    let aspectRatio: CGFloat
    fileprivate(set) var layoutFrame: NSRect = NSZeroRect
    fileprivate(set) var positionFlags: GroupLayoutPositionFlags = .none
    
    init(_ message: Message) {
        self.mid = message.id
        
        if let image = message.media.first as? TelegramMediaImage {
            if let representation = image.representationForDisplayAtSize(NSMakeSize(1136, 1136)) {
                self.imageSize = representation.dimensions
                self.aspectRatio = self.imageSize.width / self.imageSize.height
            } else if let represenatation = imageRepresentationLargerThan(image.representations, size: NSMakeSize(1000, 1000)) {
                self.imageSize = represenatation.dimensions
                self.aspectRatio = self.imageSize.width / self.imageSize.height
            } else {
                self.imageSize = NSZeroSize
                self.aspectRatio = 1.0
            }
        } else {
            self.imageSize = NSZeroSize
            self.aspectRatio = 1.0
        }
    }
}

private final class GroupedLayoutAttempt {
    let lineCounts:[Int]
    let heights:[CGFloat]
    init(lineCounts:[Int], heights: [CGFloat]) {
        self.lineCounts = lineCounts
        self.heights = heights
    }
}

struct GroupLayoutPositionFlags : OptionSet {
    
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public init(_ flags: GroupLayoutPositionFlags) {
        var rawValue: UInt32 = 0
        
        if flags.contains(GroupLayoutPositionFlags.none) {
            rawValue |= GroupLayoutPositionFlags.none.rawValue
        }
        
        if flags.contains(GroupLayoutPositionFlags.top) {
            rawValue |= GroupLayoutPositionFlags.top.rawValue
        }
        
        if flags.contains(GroupLayoutPositionFlags.bottom) {
            rawValue |= GroupLayoutPositionFlags.bottom.rawValue
        }
        
        if flags.contains(GroupLayoutPositionFlags.left) {
            rawValue |= GroupLayoutPositionFlags.left.rawValue
        }
        if flags.contains(GroupLayoutPositionFlags.right) {
            rawValue |= GroupLayoutPositionFlags.right.rawValue
        }
        if flags.contains(GroupLayoutPositionFlags.inside) {
            rawValue |= GroupLayoutPositionFlags.inside.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    static let none = GroupLayoutPositionFlags(rawValue: 0)
    static let top = GroupLayoutPositionFlags(rawValue: 1 << 0)
    static let bottom = GroupLayoutPositionFlags(rawValue: 1 << 1)
    static let left = GroupLayoutPositionFlags(rawValue: 1 << 2)
    static let right = GroupLayoutPositionFlags(rawValue: 1 << 3)
    static let inside = GroupLayoutPositionFlags(rawValue: 1 << 4)
}

class GroupedLayout {

    private(set) var dimensions: NSSize = NSZeroSize
    private var layouts:[MessageId: MessagePhotoInfo] = [:]
    private(set) var messages:[Message]
    
    init(_ messages: [Message]) {
        self.messages = messages
    }
    
    var count: Int {
        return messages.count
    }
    
    func measure(_ maxSize: NSSize) {
        let spacing: CGFloat = 4.0
        
        var proportions: String = ""
        var averageAspectRatio: CGFloat = 1.0
        
        var photos: [MessagePhotoInfo] = []
        for message in messages {
            let photo = MessagePhotoInfo(message)
            photos.append(photo)
            
            if photo.aspectRatio > 1.2 {
                proportions += "w"
            } else if photo.aspectRatio < 0.8 {
                proportions += "n"
            } else {
                proportions += "q"
            }
            averageAspectRatio += photo.aspectRatio
        }
        
        let maxAspectRatio = maxSize.width / maxSize.height
        if (photos.count > 0) {
            averageAspectRatio = averageAspectRatio / CGFloat(photos.count)
        }
        
        if photos.count == 1 {
            let maxWidth = min(maxSize.width, photos[0].imageSize.width)
            var size: NSSize
            if photos[0].aspectRatio > 0.5 {
                size = NSMakeSize(maxWidth, round(maxWidth / photos[0].aspectRatio))
            } else {
                size = NSMakeSize(maxSize.width, photos[0].imageSize.width)
            }
            photos[0].layoutFrame = NSMakeRect(0, 0, size.width, size.height)
            photos[0].positionFlags = .none
        } else if photos.count == 2 {
            if proportions == "ww" && averageAspectRatio > 1.4 * maxAspectRatio && photos[1].aspectRatio - photos[0].aspectRatio < 0.2 {
                let width: CGFloat = maxSize.width
                let height:CGFloat = round(min(width / photos[0].aspectRatio, min(width / photos[1].aspectRatio, (maxSize.height - spacing) / 2.0)))
                
                photos[0].layoutFrame = NSMakeRect(0.0, 0.0, width, height)
                photos[0].positionFlags = [.top, .left, .right]
                
                photos[1].layoutFrame = NSMakeRect(0.0, height + spacing, width, height)
                photos[1].positionFlags = [.bottom, .left, .right]
            } else if proportions == "ww" || proportions == "qq" {
                let width: CGFloat = (maxSize.width - spacing) / 2.0
                let height: CGFloat = round(min(width / photos[0].aspectRatio, min(width / photos[1].aspectRatio, maxSize.height)))
                
                photos[0].layoutFrame = NSMakeRect(0.0, 0.0, width, height)
                photos[0].positionFlags = [.top, .left, .bottom]
                
                photos[1].layoutFrame = NSMakeRect(width + spacing, 0.0, width, height)
                photos[1].positionFlags = [.top, .right, .bottom]
            } else {
                let firstWidth: CGFloat = round((maxSize.width - spacing) / photos[1].aspectRatio / (1.0 / photos[0].aspectRatio + 1.0 / photos[1].aspectRatio))
                let secondWidth: CGFloat = maxSize.width - firstWidth - spacing
                let height: CGFloat = min(maxSize.height, round(min(firstWidth / photos[0].aspectRatio, secondWidth / photos[1].aspectRatio)))
                
                photos[0].layoutFrame = NSMakeRect(0.0, 0.0, firstWidth, height)
                photos[0].positionFlags = [.top, .left, .bottom]
                
                photos[1].layoutFrame = NSMakeRect(firstWidth + spacing, 0.0, secondWidth, height)
                photos[1].positionFlags = [.top, .right, .bottom]
            }
        } else if photos.count == 3 {
            if proportions == "www" {
                var width: CGFloat = maxSize.width
                let firstHeight: CGFloat = round(min(width / photos[0].aspectRatio, (maxSize.height - spacing) * 0.66))
                photos[0].layoutFrame = NSMakeRect(0.0, 0.0, width, firstHeight)
                photos[0].positionFlags = [.top, .left, .right]
                
                width = (maxSize.width - spacing) / 2.0
                let secondHeight: CGFloat = min(maxSize.height - firstHeight - spacing, round(min(width / photos[1].aspectRatio, width / photos[2].aspectRatio)))
                photos[1].layoutFrame = NSMakeRect(0.0, firstHeight + spacing, width, secondHeight)
                photos[1].positionFlags = [.left, .bottom]
                
                photos[2].layoutFrame = NSMakeRect(width + spacing, firstHeight + spacing, width, secondHeight)
                photos[2].positionFlags = [.right, .bottom]
            } else {
                let firstHeight: CGFloat = maxSize.height
                let leftWidth: CGFloat = round(min(firstHeight * photos[0].aspectRatio, (maxSize.width - spacing) * 0.6))
                photos[0].layoutFrame = NSMakeRect(0.0, 0.0, leftWidth, firstHeight)
                photos[0].positionFlags = [.top, .left, .bottom]
                
                
                let thirdHeight: CGFloat = min((maxSize.height - spacing) * 0.66, round(photos[1].aspectRatio * (maxSize.width - spacing) / (photos[2].aspectRatio + photos[1].aspectRatio)))
                let secondHeight: CGFloat = maxSize.height - thirdHeight - spacing
                let rightWidth: CGFloat = min(maxSize.width - leftWidth - spacing, round(min(thirdHeight * photos[2].aspectRatio, secondHeight * photos[1].aspectRatio)))
                photos[1].layoutFrame = NSMakeRect(leftWidth + spacing, 0.0, rightWidth, secondHeight)
                photos[1].positionFlags = [.right, .top]
                
                photos[2].layoutFrame = NSMakeRect(leftWidth + spacing, secondHeight + spacing, rightWidth, thirdHeight)
                photos[2].positionFlags = [.right, .bottom]
            }
        } else if photos.count == 4 {
            if proportions == "www" || proportions.hasPrefix("w") {
                let w: CGFloat = maxSize.width
                let h0: CGFloat = round(min(w / photos[0].aspectRatio, (maxSize.height - spacing) * 0.66))
                photos[0].layoutFrame = NSMakeRect(0.0, 0.0, w, h0)
                photos[0].positionFlags = [.top, .left, .right]
                
                var h: CGFloat = round((maxSize.width - 2 * spacing) / (photos[1].aspectRatio + photos[2].aspectRatio + photos[3].aspectRatio))
                let w0: CGFloat = max((maxSize.width - 2 * spacing) * 0.33, h * photos[1].aspectRatio)
                let w2: CGFloat = max((maxSize.width - 2 * spacing) * 0.33, h * photos[3].aspectRatio)
                let w1: CGFloat = w - w0 - w2 - 2 * spacing
                h = min(maxSize.height - h0 - spacing, h)
                photos[1].layoutFrame = NSMakeRect(0.0, h0 + spacing, w0, h)
                photos[1].positionFlags = [.left, .bottom]
                
                photos[2].layoutFrame = NSMakeRect(w0 + spacing, h0 + spacing, w1, h)
                photos[2].positionFlags = [.bottom]
                
                photos[3].layoutFrame = NSMakeRect(w0 + w1 + 2 * spacing, h0 + spacing, w2, h)
                photos[3].positionFlags = [.right, .bottom]
            } else {
                let h: CGFloat = maxSize.height
                let w0: CGFloat = round(min(h * photos[0].aspectRatio, (maxSize.width - spacing) * 0.6))
                photos[0].layoutFrame = NSMakeRect(0.0, 0.0, w0, h)
                photos[0].positionFlags = [.top, .left, .bottom]
                
                var w: CGFloat  = round((maxSize.height - 2 * spacing) / (1.0 / photos[1].aspectRatio + 1.0 /  photos[2].aspectRatio + 1.0 / photos[3].aspectRatio))
                let h0: CGFloat = w / photos[1].aspectRatio
                let h1: CGFloat = w / photos[2].aspectRatio
                let h2: CGFloat = w / photos[3].aspectRatio
                w = min(maxSize.width - w0 - spacing, w)
                photos[1].layoutFrame = NSMakeRect(w0 + spacing, 0.0, w, h0)
                photos[1].positionFlags = [.right, .top]
                
                photos[2].layoutFrame = NSMakeRect(w0 + spacing, h0 + spacing, w, h1)
                photos[2].positionFlags = [.right]
                
                photos[3].layoutFrame = NSMakeRect(w0 + spacing, h0 + h1 + 2 * spacing, w, h2)
                photos[3].positionFlags = [.right, .bottom]
            }
        } else {
            var croppedRatios:[CGFloat] = []
            for photo in photos {
                if averageAspectRatio > 1.1 {
                    croppedRatios.append(max(1.0, photo.aspectRatio))
                } else {
                    croppedRatios.append(min(1.0, photo.aspectRatio))
                }
            }
            
            func multiHeight(_ ratios: [CGFloat]) -> CGFloat {
                var ratioSum: CGFloat = 0
                for ratio in ratios {
                    ratioSum += ratio
                }
                return (maxSize.width - (CGFloat(ratios.count) - 1) * spacing) / ratioSum
            }
            
            var attempts: [GroupedLayoutAttempt] = []
            
            func addAttempt(_ lineCounts:[Int], _ heights:[CGFloat])  {
                attempts.append(GroupedLayoutAttempt(lineCounts: lineCounts, heights: heights))
            }
            
            
            addAttempt([croppedRatios.count], [multiHeight(croppedRatios)])
            
            var thirdLine: Int = 0
            
            for firstLine in 1...croppedRatios.count {
                let firstSub = Array(croppedRatios[0 ..< firstLine])
                let secSub = Array(croppedRatios[firstLine ..< firstLine + croppedRatios.count - firstLine])
                addAttempt([firstLine, croppedRatios.count - firstLine], [multiHeight(firstSub), multiHeight(secSub)])
                
            }
            
            for firstLine in 1...croppedRatios.count - 2 {
                for secondLine in 1...croppedRatios.count - firstLine - 1 {
                    thirdLine = croppedRatios.count - firstLine - secondLine
                    addAttempt([firstLine, secondLine, (croppedRatios.count - firstLine - secondLine)], [multiHeight(croppedRatios.subarray(with: NSRange(location: 0, length: firstLine))), multiHeight(croppedRatios.subarray(with: NSRange(location: firstLine, length: croppedRatios.count - firstLine - thirdLine))), multiHeight(croppedRatios.subarray(with: NSRange(location: firstLine + secondLine, length: croppedRatios.count - firstLine - secondLine)))])
                }
            }
            
            
            var optimal: GroupedLayoutAttempt? = nil
            var optimalDiff: CGFloat = 0.0
            for attempt in attempts {
                var height: CGFloat = spacing * (CGFloat(attempt.heights.count) - 1)
                for h in attempt.heights {
                    height += h
                }
                
                var diff: CGFloat = fabs(height - maxSize.height)
                if (attempt.lineCounts.count > 1)
                {
                    if attempt.lineCounts[0] > attempt.lineCounts[1] || (attempt.lineCounts.count > 2 && attempt.lineCounts[1] > attempt.lineCounts[2]) {
                        diff *= 1.1
                    }
                }
                
                if (optimal == nil || diff < optimalDiff)
                {
                    optimal = attempt
                    optimalDiff = diff
                }
            }
            
            var index: Int = 0
            var y: CGFloat = 0.0
            if let optimal = optimal {
                for i in 0 ..< optimal.lineCounts.count
                {
                    let count: Int = optimal.lineCounts[i]
                    let lineHeight: CGFloat  = optimal.heights[i]
                    var x: CGFloat = 0.0
                    
                    var positionFlags: GroupLayoutPositionFlags = [.none]
                    if (i == 0) {
                        positionFlags.insert(.top)
                    }
                    if (i == optimal.lineCounts.count - 1) {
                        positionFlags.insert(.bottom)
                    }
                    
                    for k in 0 ..< count
                    {
                        var innerPositionFlags: GroupLayoutPositionFlags = positionFlags
                        
                        if (k == 0) {
                            innerPositionFlags.insert(.left)
                        }
                        if (k == count - 1) {
                            innerPositionFlags.insert(.right)
                        }
                        
                        if positionFlags == .none {
                            innerPositionFlags.insert(.inside)
                        }
                        
                        let ratio: CGFloat = croppedRatios[index]
                        let width: CGFloat = ratio * lineHeight
                        photos[index].layoutFrame = NSMakeRect(x, y, width, lineHeight)
                        photos[index].positionFlags = innerPositionFlags
                        
                        x += width + spacing
                        index += 1
                    }
                    
                    y += lineHeight + spacing
                }
            }
            
        }
        
        var dimensions: CGSize  = NSZeroSize
        var layouts: [MessageId: MessagePhotoInfo] = [:]
        for photo in photos {
            layouts[photo.mid] = photo
            
            if photo.layoutFrame.maxX > dimensions.width {
                dimensions.width = photo.layoutFrame.maxX
            }
            if photo.layoutFrame.maxY > dimensions.height {
                dimensions.height = photo.layoutFrame.maxY
            }
        }
        
        
        for (_, layout) in layouts {
            layout.layoutFrame = NSMakeRect(floorToScreenPixels(layout.layoutFrame.minX), floorToScreenPixels(layout.layoutFrame.minY), floorToScreenPixels(layout.layoutFrame.width), floorToScreenPixels(layout.layoutFrame.height))
        }
        
        self.layouts = layouts
        self.dimensions = NSMakeSize(floorToScreenPixels(dimensions.width), floorToScreenPixels(dimensions.height))
    }
    
    func frame(for messageId: MessageId) -> NSRect {
        guard let photo = layouts[messageId] else {
            return NSZeroRect
        }
        return photo.layoutFrame
    }
    
    func frame(at index: Int) -> NSRect {
        return frame(for: messages[index].id)
    }
    
    func position(for messageId: MessageId) -> GroupLayoutPositionFlags {
        guard let photo = layouts[messageId] else {
            return .none
        }
        return photo.positionFlags
    }
    
    
    func moveItemIfNeeded(at index:Int, point: NSPoint) -> Int? {
        
        for i in 0 ..< count {
            let frame = self.frame(at: i)
            if NSPointInRect(point, frame) && i != index {
                let current = messages[index]
                messages.remove(at: index)
                messages.insert(current, at: i)
                return i
            }
        }
        
        return nil
    }
    
    func isNeedMoveItem(at index:Int, point: NSPoint) -> Bool {
        
        for i in 0 ..< count {
            let frame = self.frame(at: i)
            if NSPointInRect(point, frame) && i != index {
                return true
            }
        }
        
        return false
    }
    
    func position(at index: Int) -> GroupLayoutPositionFlags {
        return position(for: messages[index].id)
    }
    
}
