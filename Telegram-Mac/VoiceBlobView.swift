//
//  VoiceBlobView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16.11.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

final class VoiceBlobView: View {
    
    private let smallBlob: BlobView
    private let mediumBlob: BlobView
    private let bigBlob: BlobView
    
    private let maxLevel: CGFloat
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    private var audioLevel: CGFloat = 0
    private var presentationAudioLevel: CGFloat = 0
    
    private(set) var isAnimating = false
    
    typealias BlobRange = (min: CGFloat, max: CGFloat)
    
    init(
        frame: CGRect,
        maxLevel: CGFloat,
        smallBlobRange: BlobRange,
        mediumBlobRange: BlobRange,
        bigBlobRange: BlobRange
        ) {
        self.maxLevel = maxLevel
        
        self.smallBlob = BlobView(
            pointsCount: 8,
            minRandomness: 0.1,
            maxRandomness: 0.5,
            minSpeed: 0.2,
            maxSpeed: 0.6,
            minScale: smallBlobRange.min,
            maxScale: smallBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: true
        )
        self.mediumBlob = BlobView(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 1.5,
            maxSpeed: 7,
            minScale: mediumBlobRange.min,
            maxScale: mediumBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: false
        )
        self.bigBlob = BlobView(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 1.5,
            maxSpeed: 7,
            minScale: bigBlobRange.min,
            maxScale: bigBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: false
        )
        
        super.init(frame: frame)
        
        addSubview(bigBlob)
        addSubview(mediumBlob)
        addSubview(smallBlob)
        
        displayLinkAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
            guard let strongSelf = self, let window = self?.window, window.isVisible else { return }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
            
            strongSelf.smallBlob.level = strongSelf.presentationAudioLevel
            strongSelf.mediumBlob.level = strongSelf.presentationAudioLevel
            strongSelf.bigBlob.level = strongSelf.presentationAudioLevel
        })
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func setColor(_ color: NSColor) {
        smallBlob.setColor(color)
        mediumBlob.setColor(color.withAlphaComponent(0.3))
        bigBlob.setColor(color.withAlphaComponent(0.15))
    }
    
    func updateLevel(_ level: CGFloat) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        smallBlob.updateSpeedLevel(to: normalizedLevel)
        mediumBlob.updateSpeedLevel(to: normalizedLevel)
        bigBlob.updateSpeedLevel(to: normalizedLevel)
        
        audioLevel = normalizedLevel
    }
    
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        mediumBlob.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.6)
        bigBlob.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.6)
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = false
    }
    
    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        
        mediumBlob.layer?.animateScaleSpring(from: 1.0, to: 0.1, duration: 0.6, removeOnCompletion: false, bounce: false)
        bigBlob.layer?.animateScaleSpring(from: 1.0, to: 0.1, duration: 0.6, removeOnCompletion: false, bounce: false)
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = true
    }
    
    private func updateBlobsState() {
        if isAnimating {
            if smallBlob.frame.size != .zero {
                smallBlob.startAnimating()
                mediumBlob.startAnimating()
                bigBlob.startAnimating()
            }
        } else {
            smallBlob.stopAnimating()
            mediumBlob.stopAnimating()
            bigBlob.stopAnimating()
        }
    }
    
    override func layout() {
        super.layout()
        
        smallBlob.frame = bounds
        mediumBlob.frame = bounds
        bigBlob.frame = bounds
        
        updateBlobsState()
    }
}

final class BlobView: View {
    
    let pointsCount: Int
    let smoothness: CGFloat
    
    let minRandomness: CGFloat
    let maxRandomness: CGFloat
    
    let minSpeed: CGFloat
    let maxSpeed: CGFloat
    
    let minScale: CGFloat
    let maxScale: CGFloat
    let scaleSpeed: CGFloat
    
    var scaleLevelsToBalance = [CGFloat]()
    
    // If true ignores randomness and pointsCount
    let isCircle: Bool
    
    var level: CGFloat = 0 {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let lv = minScale + (maxScale - minScale) * level
            shapeLayer.transform = CATransform3DMakeScale(lv, lv, 1)
            CATransaction.commit()
        }
    }
    
    private var blobAnimation: DisplayLinkAnimator?
    
    private var speedLevel: CGFloat = 0
    private var scaleLevel: CGFloat = 0
    
    private var lastSpeedLevel: CGFloat = 0
    private var lastScaleLevel: CGFloat = 0
    
    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = nil
        return layer
    }()
    
    private var transition: CGFloat = 0 {
        didSet {
            guard let currentPoints = currentPoints else { return }
            shapeLayer.path = CGPath.smoothCurve(through: currentPoints, length: bounds.width, smoothness: smoothness)
        }
    }
    
    private var fromPoints: [CGPoint]?
    private var toPoints: [CGPoint]?
    
    private var currentPoints: [CGPoint]? {
        guard let fromPoints = fromPoints, let toPoints = toPoints else { return nil }
        
        return fromPoints.enumerated().map { offset, fromPoint in
            let toPoint = toPoints[offset]
            return CGPoint(
                x: fromPoint.x + (toPoint.x - fromPoint.x) * transition,
                y: fromPoint.y + (toPoint.y - fromPoint.y) * transition
            )
        }
    }
    
    init(
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat,
        scaleSpeed: CGFloat,
        isCircle: Bool
        ) {
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minScale = minScale
        self.maxScale = maxScale
        self.scaleSpeed = scaleSpeed
        self.isCircle = isCircle
        
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        self.smoothness = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2
        
        super.init(frame: .zero)
        
        layer?.addSublayer(shapeLayer)
        
        shapeLayer.transform = CATransform3DMakeScale(minScale, minScale, 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func setColor(_ color: NSColor) {
        shapeLayer.fillColor = color.cgColor
    }
    
    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        speedLevel = max(speedLevel, newSpeedLevel)
        
//        if abs(lastSpeedLevel - newSpeedLevel) > 0.5 {
//            animateToNewShape()
//        }
    }
    
    func startAnimating() {
        animateToNewShape()
    }
    
    func stopAnimating() {
        fromPoints = currentPoints
        toPoints = nil
        blobAnimation = nil
    }
    
    private func animateToNewShape() {
        guard !isCircle else { return }
        
        if blobAnimation != nil {
            fromPoints = currentPoints
            toPoints = nil
            blobAnimation = nil
        }
        
        if fromPoints == nil {
            fromPoints = generateNextBlob(for: bounds.size)
        }
        if toPoints == nil {
            toPoints = generateNextBlob(for: bounds.size)
        }
        
        let duration = CGFloat(1 / (minSpeed + (maxSpeed - minSpeed) * speedLevel))
        let fromValue: CGFloat = 0
        let toValue: CGFloat = 1

        let animation = DisplayLinkAnimator(duration: Double(duration), from: fromValue, to: toValue, update: { [weak self] value in
            self?.transition = value
        }, completion: { [weak self] in
            guard let `self` = self else {
                return
            }
            self.fromPoints = self.currentPoints
            self.toPoints = nil
            self.blobAnimation = nil
            self.animateToNewShape()
        })
        self.blobAnimation = animation
        
        lastSpeedLevel = speedLevel
        speedLevel = 0
    }

    private func generateNextBlob(for size: CGSize) -> [CGPoint] {
        let randomness = minRandomness + (maxRandomness - minRandomness) * speedLevel
        return blob(pointsCount: pointsCount, randomness: randomness)
            .map {
                return CGPoint(
                    x: $0.x * CGFloat(size.width),
                    y: $0.y * CGFloat(size.height)
                )
        }
    }
    
    func blob(pointsCount: Int, randomness: CGFloat) -> [CGPoint] {
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        
        let rgen = { () -> CGFloat in
            let accuracy: UInt32 = 1000
            let random = arc4random_uniform(accuracy)
            return CGFloat(random) / CGFloat(accuracy)
        }
        let rangeStart: CGFloat = 1 / (1 + randomness / 10)
        
        let startAngle = angle * CGFloat(arc4random_uniform(100)) / CGFloat(100)
        
        let points = (0 ..< pointsCount).map { i -> CGPoint in
            let randPointOffset = (rangeStart + CGFloat(rgen()) * (1 - rangeStart)) / 2
            let angleRandomness: CGFloat = angle * 0.1
            let randAngle = angle + angle * ((angleRandomness * CGFloat(arc4random_uniform(100)) / CGFloat(100)) - angleRandomness * 0.5)
            let pointX = sin(startAngle + CGFloat(i) * randAngle)
            let pointY = cos(startAngle + CGFloat(i) * randAngle)
            return CGPoint(
                x: pointX * randPointOffset,
                y: pointY * randPointOffset
            )
        }
        
        return points
    }
    
    override func layout() {
        super.layout()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        if isCircle {
            let halfWidth = bounds.width * 0.5
            shapeLayer.path = CGPath(roundedRect: bounds.offsetBy(dx: -halfWidth, dy: -halfWidth), cornerWidth: halfWidth, cornerHeight: halfWidth, transform: nil)
        }
        CATransaction.commit()
    }
}

extension CGPath {


    static func smoothCurve(through points: [CGPoint], length: CGFloat, smoothness: CGFloat, curve: Bool = false) -> CGPath {
       var smoothPoints = [SmoothPoint]()
       for index in (0 ..< points.count) {
           let prevIndex = index - 1
           let prev = points[prevIndex >= 0 ? prevIndex : points.count + prevIndex]
           let curr = points[index]
           let next = points[(index + 1) % points.count]

           let angle: CGFloat = {
               let dx = next.x - prev.x
               let dy = -next.y + prev.y
               let angle = atan2(dy, dx)
               if angle < 0 {
                   return abs(angle)
               } else {
                   return 2 * .pi - angle
               }
           }()

           smoothPoints.append(
               SmoothPoint(
                   point: curr,
                   inAngle: angle + .pi,
                   inLength: smoothness * distance(from: curr, to: prev),
                   outAngle: angle,
                   outLength: smoothness * distance(from: curr, to: next)
               )
           )
       }

       let resultPath = CGMutablePath()
       if curve {
           resultPath.move(to: CGPoint())
           resultPath.addLine(to: smoothPoints[0].point)
       } else {
           resultPath.move(to: smoothPoints[0].point)
       }

       let smoothCount = curve ? smoothPoints.count - 1 : smoothPoints.count
       for index in (0 ..< smoothCount) {
           let curr = smoothPoints[index]
           let next = smoothPoints[(index + 1) % points.count]
           let currSmoothOut = curr.smoothOut()
           let nextSmoothIn = next.smoothIn()
           resultPath.addCurve(to: next.point, control1: currSmoothOut, control2: nextSmoothIn)
       }
       if curve {
           resultPath.addLine(to: CGPoint(x: length, y: 0.0))
       }
       resultPath.closeSubpath()
       return resultPath
   }

    
    static private func distance(from fromPoint: CGPoint, to toPoint: CGPoint) -> CGFloat {
        return sqrt((fromPoint.x - toPoint.x) * (fromPoint.x - toPoint.x) + (fromPoint.y - toPoint.y) * (fromPoint.y - toPoint.y))
    }
    
    struct SmoothPoint {
        
        let point: CGPoint
        
        let inAngle: CGFloat
        let inLength: CGFloat
        
        let outAngle: CGFloat
        let outLength: CGFloat
        
        func smoothIn() -> CGPoint {
            return smooth(angle: inAngle, length: inLength)
        }
        
        func smoothOut() -> CGPoint {
            return smooth(angle: outAngle, length: outLength)
        }
        
        private func smooth(angle: CGFloat, length: CGFloat) -> CGPoint {
            return CGPoint(
                x: point.x + length * cos(angle),
                y: point.y + length * sin(angle)
            )
        }
    }
}

