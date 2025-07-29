//
//  PeerInfoSpawnEmojiView.swift
//  Telegram
//
//  Created by Mike Renoir on 16.11.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import LokiRng



struct PositionGenerator {
    struct Position {
        let center: CGPoint
        let scale: CGFloat
    }
    
    let containerSize: CGSize
    let centerFrame: CGRect
    let exclusionZones: [CGRect]
    let minimumDistance: CGFloat
    let edgePadding: CGFloat
    let scaleRange: (min: CGFloat, max: CGFloat)
    
    let innerOrbitRange: (min: CGFloat, max: CGFloat)
    let outerOrbitRange: (min: CGFloat, max: CGFloat)
    let innerOrbitCount: Int
    
    private let lokiRng: LokiRng
    
    init(
        containerSize: CGSize,
        centerFrame: CGRect,
        exclusionZones: [CGRect],
        minimumDistance: CGFloat,
        edgePadding: CGFloat,
        seed: UInt,
        scaleRange: (min: CGFloat, max: CGFloat) = (0.7, 1.15),
        innerOrbitRange: (min: CGFloat, max: CGFloat) = (1.4, 2.2),
        outerOrbitRange: (min: CGFloat, max: CGFloat) = (2.5, 3.6),
        innerOrbitCount: Int = 4
    ) {
        self.containerSize = containerSize
        self.centerFrame = centerFrame
        self.exclusionZones = exclusionZones
        self.minimumDistance = minimumDistance
        self.edgePadding = edgePadding
        self.scaleRange = scaleRange
        self.innerOrbitRange = innerOrbitRange
        self.outerOrbitRange = outerOrbitRange
        self.innerOrbitCount = innerOrbitCount
        self.lokiRng = LokiRng(seed0: seed, seed1: 0, seed2: 0)
    }
    
    func generatePositions(count: Int, itemSize: CGSize) -> [Position] {
        var positions: [Position] = []
        
        let centerPoint = CGPoint(x: self.centerFrame.midX, y: self.centerFrame.midY)
        let centerRadius = min(self.centerFrame.width, self.centerFrame.height) / 2.0
        
        let maxAttempts = count * 200
        var attempts = 0
        
        var leftPositions = 0
        var rightPositions = 0
        
        let innerCount = min(self.innerOrbitCount, count)
        
        while positions.count < innerCount && attempts < maxAttempts {
            attempts += 1
            
            let placeOnLeftSide = rightPositions > leftPositions
            
            let orbitRangeSize = self.innerOrbitRange.max - self.innerOrbitRange.min
            let orbitDistanceFactor = self.innerOrbitRange.min + orbitRangeSize * CGFloat(self.lokiRng.next())
            let orbitDistance = orbitDistanceFactor * centerRadius
            
            let angleRange: CGFloat = placeOnLeftSide ? .pi : .pi
            let angleOffset: CGFloat = placeOnLeftSide ? .pi/2 : -(.pi/2)
            let angle = angleOffset + angleRange * CGFloat(self.lokiRng.next())
            
            let absoluteX = centerPoint.x + orbitDistance * cos(angle)
            let absoluteY = centerPoint.y + orbitDistance * sin(angle)
            let absolutePosition = CGPoint(x: absoluteX, y: absoluteY)
            
            if absolutePosition.x - itemSize.width/2 < self.edgePadding ||
                absolutePosition.x + itemSize.width/2 > self.containerSize.width - self.edgePadding ||
                absolutePosition.y - itemSize.height/2 < self.edgePadding ||
                absolutePosition.y + itemSize.height/2 > self.containerSize.height - self.edgePadding {
                continue
            }
            
            let relativePosition = CGPoint(
                x: absolutePosition.x - centerPoint.x,
                y: absolutePosition.y - centerPoint.y
            )
            
            let itemRect = CGRect(
                x: absolutePosition.x - itemSize.width/2,
                y: absolutePosition.y - itemSize.height/2,
                width: itemSize.width,
                height: itemSize.height
            )
            
            if self.isValidPosition(itemRect, existingPositions: positions.map { self.posToAbsolute($0.center, centerPoint: centerPoint) }, itemSize: itemSize) {
                let scaleRangeSize = max(self.scaleRange.min + 0.1, 0.75) - self.scaleRange.max
                let scale = self.scaleRange.max + scaleRangeSize * CGFloat(self.lokiRng.next())
                positions.append(Position(center: relativePosition, scale: scale))
                
                if absolutePosition.x < centerPoint.x {
                    leftPositions += 1
                } else {
                    rightPositions += 1
                }
            }
        }
        
        let maxPossibleDistance = hypot(self.containerSize.width, self.containerSize.height) / 2
        
        while positions.count < count && attempts < maxAttempts {
            attempts += 1
            
            let placeOnLeftSide = rightPositions >= leftPositions
            
            let orbitRangeSize = self.outerOrbitRange.max - self.outerOrbitRange.min
            let orbitDistanceFactor = self.outerOrbitRange.min + orbitRangeSize * CGFloat(self.lokiRng.next())
            let orbitDistance = orbitDistanceFactor * centerRadius
            
            let angleRange: CGFloat = placeOnLeftSide ? .pi : .pi
            let angleOffset: CGFloat = placeOnLeftSide ? .pi/2 : -(.pi/2)
            let angle = angleOffset + angleRange * CGFloat(self.lokiRng.next())
            
            let absoluteX = centerPoint.x + orbitDistance * cos(angle)
            let absoluteY = centerPoint.y + orbitDistance * sin(angle)
            let absolutePosition = CGPoint(x: absoluteX, y: absoluteY)
            
            if absolutePosition.x - itemSize.width/2 < self.edgePadding ||
                absolutePosition.x + itemSize.width/2 > self.containerSize.width - self.edgePadding ||
                absolutePosition.y - itemSize.height/2 < self.edgePadding ||
                absolutePosition.y + itemSize.height/2 > self.containerSize.height - self.edgePadding {
                continue
            }
            
            let relativePosition = CGPoint(
                x: absolutePosition.x - centerPoint.x,
                y: absolutePosition.y - centerPoint.y
            )
            
            let itemRect = CGRect(
                x: absolutePosition.x - itemSize.width/2,
                y: absolutePosition.y - itemSize.height/2,
                width: itemSize.width,
                height: itemSize.height
            )
            
            if self.isValidPosition(itemRect, existingPositions: positions.map { self.posToAbsolute($0.center, centerPoint: centerPoint) }, itemSize: itemSize) {
                let distance = hypot(absolutePosition.x - centerPoint.x, absolutePosition.y - centerPoint.y)
                
                let normalizedDistance = min(distance / maxPossibleDistance, 1.0)
                let scale = self.scaleRange.max - normalizedDistance * (self.scaleRange.max - self.scaleRange.min)
                positions.append(Position(center: relativePosition, scale: scale))
                
                if absolutePosition.x < centerPoint.x {
                    leftPositions += 1
                } else {
                    rightPositions += 1
                }
            }
        }
        
        return positions
    }
    
    private func posToAbsolute(_ relativePos: CGPoint, centerPoint: CGPoint) -> CGPoint {
        return CGPoint(x: relativePos.x + centerPoint.x, y: relativePos.y + centerPoint.y)
    }
    
    private func isValidPosition(_ rect: CGRect, existingPositions: [CGPoint], itemSize: CGSize) -> Bool {
        if rect.minX < self.edgePadding || rect.maxX > self.containerSize.width - self.edgePadding ||
            rect.minY < self.edgePadding || rect.maxY > self.containerSize.height - self.edgePadding {
            return false
        }
        
        for zone in self.exclusionZones {
            if rect.intersects(zone) {
                return false
            }
        }
        
        let effectiveMinDistance = existingPositions.count > 5 ? max(self.minimumDistance * 0.7, 10.0) : self.minimumDistance
        
        for existingPosition in existingPositions {
            let distance = hypot(existingPosition.x - rect.midX, existingPosition.y - rect.midY)
            if distance < effectiveMinDistance {
                return false
            }
        }
        
        return true
    }
}


private func windowFunction(t: CGFloat) -> CGFloat {
    return bezierPoint(0.6, 0.0, 0.4, 1.0, t)
}

func patternScaleValueAt(fraction: CGFloat, t: CGFloat, reverse: Bool) -> CGFloat {
    let windowSize: CGFloat = 0.8

    let effectiveT: CGFloat
    let windowStartOffset: CGFloat
    let windowEndOffset: CGFloat
    if reverse {
        effectiveT = 1.0 - t
        windowStartOffset = 1.0
        windowEndOffset = -windowSize
    } else {
        effectiveT = t
        windowStartOffset = -windowSize
        windowEndOffset = 1.0
    }

    let windowPosition = (1.0 - fraction) * windowStartOffset + fraction * windowEndOffset
    let windowT = max(0.0, min(windowSize, effectiveT - windowPosition)) / windowSize
    let localT = 1.0 - windowFunction(t: windowT)

    return localT
}

class PeerInfoSpawnEmojiView : View {
    private var patternTarget: InlineStickerItemLayer?

    private let avatarBackgroundPatternContainer: CALayer = SimpleLayer()
    
    private var avatarPatternContentLayers:[SimpleLayer] = []
    private var patternColor: NSColor = .clear
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.addSublayer(avatarBackgroundPatternContainer)
        avatarBackgroundPatternContainer.frame = NSMakeRect(frameRect.width / 2, frameRect.height / 2 - 30, frameRect.width, frameRect.height)
        
        self.layer?.masksToBounds = false
        avatarBackgroundPatternContainer.masksToBounds = false
        
    }
    
    func set(fileId: Int64, color: NSColor, context: AccountContext, animated: Bool) {
        self.patternColor = color
        if patternTarget?.fileId != fileId || patternTarget?.textColor != color {
            let patternTarget:InlineStickerItemLayer = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: clown), size: NSMakeSize(64, 64), playPolicy: .loop, textColor: color)
            patternTarget.noDelayBeforeplay = true
            patternTarget.isPlayable = true

            patternTarget.contentDidUpdate = { [weak self] content in
                self?.updatePatternLayerImages(content)
            }
            self.patternTarget = patternTarget
        }
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        updateLayout(size: frame.size, transition: transition)
    }
    
    var fraction: CGFloat = 0 {
        didSet {
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        avatarBackgroundPatternContainer.frame = NSMakeRect(size.width / 2, size.height / 2 - 30, size.width, size.height)
        var avatarBackgroundPatternLayerCount = 0
        let lokiRng = LokiRng(seed0: 123, seed1: 0, seed2: 0)
        for row in 0 ..< 4 {
            let avatarPatternCount = row % 2 == 0 ? 9 : 9
            let avatarPatternAngleSpan: CGFloat = CGFloat.pi * 2.0 / CGFloat(avatarPatternCount - 1)
            
            for i in 0 ..< avatarPatternCount - 1 {
                let baseItemDistance: CGFloat = 80 + CGFloat(row) * 28.0
                
                let itemDistanceFraction = max(0.0, min(1.0, baseItemDistance / 140.0))
                let itemScaleFraction = patternScaleValueAt(fraction: fraction, t: itemDistanceFraction, reverse: false)
                let itemDistance = baseItemDistance * (1.0 - itemScaleFraction) + 20.0 * itemScaleFraction
                
                var itemAngle = -CGFloat.pi * 0.5 + CGFloat(i) * avatarPatternAngleSpan
                if row % 2 != 0 {
                    itemAngle += avatarPatternAngleSpan * 0.5
                }
                let itemPosition = CGPoint(x: cos(itemAngle) * itemDistance, y: sin(itemAngle) * itemDistance)
                
                let itemScale: CGFloat = 0.7 + CGFloat(lokiRng.next()) * (1.0 - 0.7)
                let itemSize: CGFloat = floor(26.0 * itemScale)
                let itemFrame = CGSize(width: itemSize, height: itemSize).centered(around: itemPosition)
                
                let itemLayer: SimpleLayer
                if self.avatarPatternContentLayers.count > avatarBackgroundPatternLayerCount {
                    itemLayer = self.avatarPatternContentLayers[avatarBackgroundPatternLayerCount]
                } else {
                    itemLayer = SimpleLayer()
                    itemLayer.contents = self.patternTarget?.contents
                    self.avatarBackgroundPatternContainer.addSublayer(itemLayer)
                    self.avatarPatternContentLayers.append(itemLayer)
                }
                
                itemLayer.frame = itemFrame
                itemLayer.layerTintColor = patternColor.cgColor
                transition.updateAlpha(layer: itemLayer, alpha: (1.0 - CGFloat(row) / 5.0) * (1.0 - itemScaleFraction))
                
                avatarBackgroundPatternLayerCount += 1
            }
        }
        if avatarBackgroundPatternLayerCount > self.avatarPatternContentLayers.count {
            for i in avatarBackgroundPatternLayerCount ..< self.avatarPatternContentLayers.count {
                self.avatarPatternContentLayers[i].removeFromSuperlayer()
            }
            self.avatarPatternContentLayers.removeSubrange(avatarBackgroundPatternLayerCount ..< self.avatarPatternContentLayers.count)
        }
    }
    
    private func updatePatternLayerImages(_ image: CGImage) {
        for layer in avatarPatternContentLayers {
            layer.contents = image
        }
    }
    
   
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
