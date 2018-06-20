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
        
        self.imageSize = ChatLayoutUtils.contentSize(for: message.media[0], with: 320)
        self.aspectRatio = self.imageSize.width / self.imageSize.height

//        if let image = message.media.first as? TelegramMediaImage {
//            if let representation = image.representationForDisplayAtSize(NSMakeSize(320, 320)) {
//                self.imageSize = representation.dimensions
//            } else if let represenatation = imageRepresentationLargerThan(image.representations, size: NSMakeSize(320, 320)) {
//                self.imageSize = represenatation.dimensions
//                self.aspectRatio = self.imageSize.width / self.imageSize.height
//            } else {
//                 = NSZeroSize
//                self.aspectRatio = 1.0
//            }
//        } else {
//            self.imageSize = NSZeroSize
//            self.aspectRatio = 1.0
//        }
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



class GroupedLayout {

    private(set) var dimensions: NSSize = NSZeroSize
    private var layouts:[MessageId: MessagePhotoInfo] = [:]
    private(set) var messages:[Message]
    
    init(_ messages: [Message]) {
        self.messages = messages
    }
    
    func contentNode(for index: Int) -> ChatMediaContentView.Type {
        return ChatLayoutUtils.contentNode(for: messages[index].media[0])
    }
    
    var count: Int {
        return messages.count
    }
    
    func message(at point: NSPoint) -> Message? {
        for i in 0 ..< messages.count {
            if NSPointInRect(point, frame(at: i)) {
                return messages[i]
            }
        }
        return nil
    }
    
    func measure(_ maxSize: NSSize, spacing: CGFloat = 4.0) {
        
        var photos: [MessagePhotoInfo] = []
        
        if messages.count == 1 {
            let photo = MessagePhotoInfo(messages[0])
            photos.append(photo)
            photos[0].layoutFrame = NSMakeRect(0, 0, photos[0].imageSize.width, photos[0].imageSize.height)
            photos[0].positionFlags = .none
        } else {
            var proportions: String = ""
            var averageAspectRatio: CGFloat = 1.0
            var forceCalc: Bool = false
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
                
                if photo.aspectRatio > 2.0 {
                    forceCalc = true
                }
            }
            
            let minWidth: CGFloat = 70
            let maxAspectRatio = maxSize.width / maxSize.height
            if (photos.count > 0) {
                averageAspectRatio = averageAspectRatio / CGFloat(photos.count)
            }
            
            if !forceCalc {
                if photos.count == 2 {
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
                        var w2: CGFloat = max((maxSize.width - 2 * spacing) * 0.33, h * photos[3].aspectRatio)
                        var w1: CGFloat = w - w0 - w2 - 2 * spacing
                        
                        if w1 < minWidth {
                            w2 -= minWidth - w1
                            w1 = minWidth
                        }
                        
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
                }
            }
            
            if forceCalc || photos.count >= 5 {
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
                
                
                var secondLine:Int = 0
                var thirdLine:Int = 0
                var fourthLine:Int = 0
                
                for firstLine in 1 ..< croppedRatios.count {
                    secondLine = croppedRatios.count - firstLine
                    if firstLine > 3 || secondLine > 3 {
                        continue
                    }
                    
                    addAttempt([firstLine, croppedRatios.count - firstLine], [multiHeight(croppedRatios.subarray(with: NSMakeRange(0, firstLine))), multiHeight(croppedRatios.subarray(with: NSMakeRange(firstLine, croppedRatios.count - firstLine)))])
                }
                
                for firstLine in 1 ..< croppedRatios.count - 1 {
                    for secondLine in 1..<croppedRatios.count - firstLine {
                        thirdLine = croppedRatios.count - firstLine - secondLine;
                        if firstLine > 3 || secondLine > (averageAspectRatio < 0.85 ? 4 : 3) || thirdLine > 3 {
                            continue
                        }
                        addAttempt([firstLine, secondLine, thirdLine], [multiHeight(croppedRatios.subarray(with: NSMakeRange(0, firstLine))), multiHeight(croppedRatios.subarray(with: NSMakeRange(firstLine, croppedRatios.count - firstLine - thirdLine))), multiHeight(croppedRatios.subarray(with: NSMakeRange(firstLine + secondLine, croppedRatios.count - firstLine - secondLine)))])
                        
                    }
                }
                if croppedRatios.count > 2 {
                    for firstLine in 1 ..< croppedRatios.count - 2 {
                        for secondLine in 1 ..< croppedRatios.count - firstLine {
                            for thirdLine in 1 ..< croppedRatios.count - firstLine - secondLine {
                                fourthLine = croppedRatios.count - firstLine - secondLine - thirdLine;
                                if firstLine > 3 || secondLine > 3 || thirdLine > 3 || fourthLine > 3 {
                                    continue
                                }
                                
                                addAttempt([firstLine, secondLine, thirdLine, fourthLine], [multiHeight(croppedRatios.subarray(with: NSMakeRange(0, firstLine))), multiHeight(croppedRatios.subarray(with: NSMakeRange(firstLine, croppedRatios.count - firstLine - thirdLine - fourthLine))), multiHeight(croppedRatios.subarray(with: NSMakeRange(firstLine + secondLine, croppedRatios.count - firstLine - secondLine - fourthLine))), multiHeight(croppedRatios.subarray(with: NSMakeRange(firstLine + secondLine + thirdLine, croppedRatios.count - firstLine - secondLine - thirdLine)))])
                            }
                        }
                    }
                }
                
                
                let maxHeight: CGFloat = maxSize.height / 3 * 4
                var optimal: GroupedLayoutAttempt? = nil
                var optimalDiff: CGFloat = 0.0
                for attempt in attempts {
                    var totalHeight: CGFloat = spacing * (CGFloat(attempt.heights.count) - 1);
                    var minLineHeight: CGFloat = .greatestFiniteMagnitude;
                    var maxLineHeight: CGFloat = 0.0
                    for lineHeight in attempt.heights {
                        totalHeight += lineHeight
                        if lineHeight < minLineHeight {
                            minLineHeight = lineHeight
                        }
                        if lineHeight > maxLineHeight {
                            maxLineHeight = lineHeight;
                        }
                    }
                    
                    var diff: CGFloat = fabs(totalHeight - maxHeight);
                    
                    if (attempt.lineCounts.count > 1) {
                        if (attempt.lineCounts[0] > attempt.lineCounts[1])
                            || (attempt.lineCounts.count > 2 && attempt.lineCounts[1] > attempt.lineCounts[2])
                            || (attempt.lineCounts.count > 3 && attempt.lineCounts[2] > attempt.lineCounts[3]) {
                            diff *= 1.5
                        }
                    }
                    
                    if minLineHeight < minWidth {
                        diff *= 1.5
                    }
                    
                    if (optimal == nil || diff < optimalDiff)
                    {
                        optimal = attempt;
                        optimalDiff = diff;
                    }
                }
                
                var index: Int = 0
                var y: CGFloat = 0.0
                if let optimal = optimal {
                    for i in 0 ..< optimal.lineCounts.count {
                        let count: Int = optimal.lineCounts[i]
                        let lineHeight: CGFloat = optimal.heights[i]
                        var x: CGFloat = 0.0
                        
                        var positionFlags: GroupLayoutPositionFlags  = [.none]
                        if i == 0 {
                            positionFlags.insert(.top)
                        }
                        if i == optimal.lineCounts.count - 1 {
                            positionFlags.insert(.bottom)
                        }
                        
                        for k in 0 ..< count
                        {
                            var innerPositionFlags:GroupLayoutPositionFlags = positionFlags;
                            
                            if k == 0 {
                                innerPositionFlags.insert(.left);
                            }
                            if k == count - 1 {
                                innerPositionFlags.insert(.right)
                            }
                            
                            if positionFlags == .none {
                                innerPositionFlags.insert(.inside)
                            }
                            
                            let ratio: CGFloat = croppedRatios[index];
                            let width: CGFloat = ratio * lineHeight;
                            photos[index].layoutFrame = NSMakeRect(x, y, width, lineHeight);
                            photos[index].positionFlags = innerPositionFlags;
                            
                            x += width + spacing;
                            index += 1
                        }
                        
                        y += lineHeight + spacing;
                    }
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
            layout.layoutFrame = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, layout.layoutFrame.minX), floorToScreenPixels(scaleFactor: System.backingScale, layout.layoutFrame.minY), floorToScreenPixels(scaleFactor: System.backingScale, layout.layoutFrame.width), floorToScreenPixels(scaleFactor: System.backingScale, layout.layoutFrame.height))
        }
        
        self.layouts = layouts
        self.dimensions = NSMakeSize(floorToScreenPixels(scaleFactor: System.backingScale, dimensions.width), floorToScreenPixels(scaleFactor: System.backingScale, dimensions.height))
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
