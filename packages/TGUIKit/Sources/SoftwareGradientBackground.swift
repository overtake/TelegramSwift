//
//  SoftwareGradientBackground.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import Accelerate
import SwiftSignalKit
import AppKit


private func shiftArray(array: [CGPoint], offset: Int) -> [CGPoint] {
    var newArray = array
    var offset = offset
    while offset > 0 {
        let element = newArray.removeFirst()
        newArray.append(element)
        offset -= 1
    }
    return newArray
}

private func gatherPositions(_ list: [CGPoint]) -> [CGPoint] {
    var result: [CGPoint] = []
    for i in 0 ..< list.count / 2 {
        result.append(list[i * 2])
    }
    return result
}

private func interpolateFloat(_ value1: CGFloat, _ value2: CGFloat, at factor: CGFloat) -> CGFloat {
    return value1 * (1.0 - factor) + value2 * factor
}

private func interpolatePoints(_ point1: CGPoint, _ point2: CGPoint, at factor: CGFloat) -> CGPoint {
    return CGPoint(x: interpolateFloat(point1.x, point2.x, at: factor), y: interpolateFloat(point1.y, point2.y, at: factor))
}

public func adjustSaturationInContext(context: DrawingContext, saturation: CGFloat) {
    var buffer = vImage_Buffer()
    buffer.data = context.bytes
    buffer.width = UInt(context.size.width * context.scale)
    buffer.height = UInt(context.size.height * context.scale)
    buffer.rowBytes = context.bytesPerRow

    let divisor: Int32 = 0x1000

    let rwgt: CGFloat = 0.3086
    let gwgt: CGFloat = 0.6094
    let bwgt: CGFloat = 0.0820

    let adjustSaturation = saturation

    let a = (1.0 - adjustSaturation) * rwgt + adjustSaturation
    let b = (1.0 - adjustSaturation) * rwgt
    let c = (1.0 - adjustSaturation) * rwgt
    let d = (1.0 - adjustSaturation) * gwgt
    let e = (1.0 - adjustSaturation) * gwgt + adjustSaturation
    let f = (1.0 - adjustSaturation) * gwgt
    let g = (1.0 - adjustSaturation) * bwgt
    let h = (1.0 - adjustSaturation) * bwgt
    let i = (1.0 - adjustSaturation) * bwgt + adjustSaturation

    let satMatrix: [CGFloat] = [
        a, b, c, 0,
        d, e, f, 0,
        g, h, i, 0,
        0, 0, 0, 1
    ]

    var matrix: [Int16] = satMatrix.map { value in
        return Int16(value * CGFloat(divisor))
    }

    vImageMatrixMultiply_ARGB8888(&buffer, &buffer, &matrix, divisor, nil, nil, vImage_Flags(kvImageDoNotTile))
}

private func generateGradient(size: CGSize, colors: [NSColor], positions: [CGPoint], adjustSaturation: CGFloat = 1.0) -> CGImage {
    let width = Int(size.width)
    let height = Int(size.height)


    
//    NSLog("\(size), colors: \(colors.map { $0.hexString })")
    let rgbData = malloc(MemoryLayout<Float>.size * colors.count * 3)!
    defer {
        free(rgbData)
    }
    let rgb = rgbData.assumingMemoryBound(to: Float.self)
    for i in 0 ..< colors.count {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        colors[i].getRed(&r, green: &g, blue: &b, alpha: nil)

        rgb.advanced(by: i * 3 + 0).pointee = Float(r)
        rgb.advanced(by: i * 3 + 1).pointee = Float(g)
        rgb.advanced(by: i * 3 + 2).pointee = Float(b)
    }

    let positionData = malloc(MemoryLayout<Float>.size * positions.count * 2)!
    defer {
        free(positionData)
    }
    let positionFloats = positionData.assumingMemoryBound(to: Float.self)
    for i in 0 ..< positions.count {
        positionFloats.advanced(by: i * 2 + 0).pointee = Float(positions[i].x)
        positionFloats.advanced(by: i * 2 + 1).pointee = Float(1.0 - positions[i].y)
    }

    let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, clear: false)
    let imageBytes = context.bytes.assumingMemoryBound(to: UInt8.self)

    for y in 0 ..< height {
        let directPixelY = Float(y) / Float(height)
        let centerDistanceY = directPixelY - 0.5
        let centerDistanceY2 = centerDistanceY * centerDistanceY

        let lineBytes = imageBytes.advanced(by: context.bytesPerRow * y)
        for x in 0 ..< width {
            let directPixelX = Float(x) / Float(width)

            let centerDistanceX = directPixelX - 0.5
            let centerDistance = sqrt(centerDistanceX * centerDistanceX + centerDistanceY2)
            
            let swirlFactor = 0.35 * centerDistance
            let theta = swirlFactor * swirlFactor * 0.8 * 8.0
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            let pixelX = max(0.0, min(1.0, 0.5 + centerDistanceX * cosTheta - centerDistanceY * sinTheta))
            let pixelY = max(0.0, min(1.0, 0.5 + centerDistanceX * sinTheta + centerDistanceY * cosTheta))

            var distanceSum: Float = 0.0

            var r: Float = 0.0
            var g: Float = 0.0
            var b: Float = 0.0

            for i in 0 ..< colors.count {
                let colorX = positionFloats[i * 2 + 0]
                let colorY = positionFloats[i * 2 + 1]

                let distanceX = pixelX - colorX
                let distanceY = pixelY - colorY

                var distance = max(0.0, 0.92 - sqrt(distanceX * distanceX + distanceY * distanceY))
                distance = distance * distance * distance
                distanceSum += distance

                r = r + distance * rgb[i * 3 + 0]
                g = g + distance * rgb[i * 3 + 1]
                b = b + distance * rgb[i * 3 + 2]
            }

            let pixelBytes = lineBytes.advanced(by: x * 4)
            pixelBytes.advanced(by: 0).pointee = UInt8(min(b / distanceSum * 255.0, 255))
            pixelBytes.advanced(by: 1).pointee = UInt8(min(g / distanceSum * 255.0, 255))
            pixelBytes.advanced(by: 2).pointee = UInt8(min(r / distanceSum * 255.0, 255))
            pixelBytes.advanced(by: 3).pointee = 0xff
        }
    }

    if abs(adjustSaturation - 1.0) > .ulpOfOne {
        adjustSaturationInContext(context: context, saturation: adjustSaturation)
    }

    return context.generateImage()!
}

public final class AnimatedGradientBackgroundView: ImageView {
    public final class CloneView: ImageView {
        private weak var parentView: AnimatedGradientBackgroundView?
        private var index: SparseBag<Weak<CloneView>>.Index?

        public init(parentView: AnimatedGradientBackgroundView) {
            self.parentView = parentView

            super.init(frame: parentView.frame)

            self.index = parentView.cloneViews.add(Weak<CloneView>(self))
            self.image = parentView.dimmedImage
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            if let parentView = self.parentView, let index = self.index {
                parentView.cloneViews.remove(index)
            }
        }
    }

    private static let basePositions: [CGPoint] = [
        CGPoint(x: 0.80, y: 0.10),
        CGPoint(x: 0.60, y: 0.20),
        CGPoint(x: 0.35, y: 0.25),
        CGPoint(x: 0.25, y: 0.60),
        CGPoint(x: 0.20, y: 0.90),
        CGPoint(x: 0.40, y: 0.80),
        CGPoint(x: 0.65, y: 0.75),
        CGPoint(x: 0.75, y: 0.40)
    ]

    public static func generatePreview(size: CGSize, colors: [NSColor]) -> CGImage {
        let positions = gatherPositions(shiftArray(array: AnimatedGradientBackgroundView.basePositions, offset: 0))
        return generateGradient(size: size, colors: colors, positions: positions)
    }

    private var colors: [NSColor]
    private var phase: Int = 0

    public let contentView: ImageView
    private var validPhase: Int?
    private var invalidated: Bool = false

    private var dimmedImageParams: (size: CGSize, colors: [NSColor], positions: [CGPoint])?
    private var _dimmedImage: CGImage?
    private var dimmedImage: CGImage? {
        if let current = self._dimmedImage {
            return current
        } else if let (size, colors, positions) = self.dimmedImageParams {
            self._dimmedImage = generateGradient(size: size, colors: colors, positions: positions, adjustSaturation: 1.7)
            return self._dimmedImage
        } else {
            return nil
        }
    }

    private var validLayout: CGSize?

    private struct PhaseTransitionKey: Hashable {
        var width: Int
        var height: Int
        var fromPhase: Int
        var toPhase: Int
        var numberOfFrames: Int
        var curve: ContainedViewLayoutTransitionCurve
    }

    private let cloneViews = SparseBag<Weak<CloneView>>()

    private let useSharedAnimationPhase: Bool
    static var sharedPhase: Int = 0

    public init(colors: [NSColor]? = nil, useSharedAnimationPhase: Bool = false) {
        self.useSharedAnimationPhase = useSharedAnimationPhase
        self.contentView = ImageView()
        let defaultColors: [NSColor] = [
            NSColor(rgb: 0x7FA381),
            NSColor(rgb: 0xFFF5C5),
            NSColor(rgb: 0x336F55),
            NSColor(rgb: 0xFBE37D)
        ]
        self.colors = colors ?? defaultColors

        super.init(frame: .zero)

        self.addSubview(self.contentView)

        if useSharedAnimationPhase {
            self.phase = AnimatedGradientBackgroundView.sharedPhase
        } else {
            self.phase = 0
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    deinit {
    }

    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, extendAnimation: Bool = false) {
        let sizeUpdated = self.validLayout != size
        self.validLayout = size

        let imageSize = size.fitted(CGSize(width: 16, height: 16)).integralFloor

        let positions = gatherPositions(shiftArray(array: AnimatedGradientBackgroundView.basePositions, offset: self.phase % 8))

        if let validPhase = self.validPhase {
            if validPhase != self.phase || self.invalidated {
                self.validPhase = self.phase
                self.invalidated = false

                var steps: [[CGPoint]] = []
                if extendAnimation {
                    let phaseCount = 4
                    var stepPhase = (self.phase + phaseCount) % 8
                    for _ in 0 ... phaseCount {
                        steps.append(gatherPositions(shiftArray(array: AnimatedGradientBackgroundView.basePositions, offset: stepPhase)))
                        stepPhase = stepPhase - 1
                        if stepPhase < 0 {
                            stepPhase = 7
                        }
                    }
                } else {
                    steps.append(gatherPositions(shiftArray(array: AnimatedGradientBackgroundView.basePositions, offset: validPhase % 8)))
                    steps.append(positions)
                }

                if case let .animated(duration, curve) = transition, duration > 0.001 {
                    var images: [CGImage] = []

                    var dimmedImages: [CGImage] = []
                    let needDimmedImages = !self.cloneViews.isEmpty

                    let stepCount = steps.count - 1

                    let fps: Double = extendAnimation ? 60 : 30
                    let maxFrame = Int(duration * fps)
                    let framesPerAnyStep = maxFrame / stepCount

                    for frameIndex in 0 ..< maxFrame {
                        let t = curve.solve(at: CGFloat(frameIndex) / CGFloat(maxFrame - 1))
                        let globalStep = Int(t * CGFloat(maxFrame))
                        let stepIndex = min(stepCount - 1, globalStep / framesPerAnyStep)

                        let stepFrameIndex = globalStep - stepIndex * framesPerAnyStep
                        let stepFrames: Int
                        if stepIndex == stepCount - 1 {
                            stepFrames = maxFrame - framesPerAnyStep * (stepCount - 1)
                        } else {
                            stepFrames = framesPerAnyStep
                        }
                        let stepT = CGFloat(stepFrameIndex) / CGFloat(stepFrames - 1)

                        var morphedPositions: [CGPoint] = []
                        for i in 0 ..< steps[0].count {
                            morphedPositions.append(interpolatePoints(steps[stepIndex][i], steps[stepIndex + 1][i], at: stepT))
                        }

                        images.append(generateGradient(size: imageSize, colors: self.colors, positions: morphedPositions))
                        if needDimmedImages {
                            dimmedImages.append(generateGradient(size: imageSize, colors: self.colors, positions: morphedPositions, adjustSaturation: 1.7))
                        }
                    }

                    self.dimmedImageParams = (imageSize, self.colors, gatherPositions(shiftArray(array: AnimatedGradientBackgroundView.basePositions, offset: self.phase % 8)))

                    self.contentView.image = images.last

                    let animation = CAKeyframeAnimation(keyPath: "contents")
                    animation.values = images.map { $0 }
                    animation.duration = duration
                    if extendAnimation {
                        animation.calculationMode = .discrete
                    } else {
                        animation.calculationMode = .linear
                    }
                    animation.isRemovedOnCompletion = true
                    if extendAnimation {
                        animation.fillMode = .backwards
                        animation.beginTime = self.contentView.layer!.convertTime(CACurrentMediaTime(), from: nil) + 0.25
                    }

                    self.contentView.layer!.removeAnimation(forKey: "contents")
                    self.contentView.layer!.add(animation, forKey: "contents")

                    if !self.cloneViews.isEmpty {
                        let animation = CAKeyframeAnimation(keyPath: "contents")
                        animation.values = dimmedImages.map { $0 }
                        animation.duration = duration
                        if extendAnimation {
                            animation.calculationMode = .discrete
                        } else {
                            animation.calculationMode = .linear
                        }
                        animation.isRemovedOnCompletion = true
                        if extendAnimation {
                            animation.fillMode = .backwards
                            animation.beginTime = self.contentView.layer!.convertTime(CACurrentMediaTime(), from: nil) + 0.25
                        }

                        self._dimmedImage = dimmedImages.last

                        for cloneView in self.cloneViews {
                            if let value = cloneView.value {
                                value.image = dimmedImages.last
                                value.layer!.removeAnimation(forKey: "contents")
                                value.layer!.add(animation, forKey: "contents")
                            }
                        }
                    }
                } else {
                    let image = generateGradient(size: imageSize, colors: self.colors, positions: positions)
                    self.contentView.image = image

                    let dimmedImage = generateGradient(size: imageSize, colors: self.colors, positions: positions, adjustSaturation: 1.7)
                    self._dimmedImage = dimmedImage
                    self.dimmedImageParams = (imageSize, self.colors, positions)

                    for cloneView in self.cloneViews {
                        cloneView.value?.image = dimmedImage
                    }
                }
            }
        } else if sizeUpdated {
            let image = generateGradient(size: imageSize, colors: self.colors, positions: positions)
            self.contentView.image = image

            let dimmedImage = generateGradient(size: imageSize, colors: self.colors, positions: positions, adjustSaturation: 1.7)
            self.dimmedImageParams = (imageSize, self.colors, positions)

            for cloneView in self.cloneViews {
                cloneView.value?.image = dimmedImage
            }

            self.validPhase = self.phase
        }

        transition.updateFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: size))
    }

    public func updateColors(colors: [NSColor]) {
        var updated = false
        if self.colors.count != colors.count {
            updated = true
        } else {
            for i in 0 ..< self.colors.count {
                if !self.colors[i].isEqual(colors[i]) {
                    updated = true
                    break
                }
            }
        }
        if updated {
            self.colors = colors
            self.invalidated = true
            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate)
            }
        }
    }

    public override func layout() {
        super.layout()
        if frame.size != .zero {
            self.updateLayout(size: frame.size, transition: .immediate)
        }
    }
    
    public func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool = false) {
        guard case let .animated(duration, _) = transition, duration > 0.001 else {
            return
        }

        if extendAnimation {
            self.invalidated = true
        } else {
            if self.phase == 0 {
                self.phase = 7
            } else {
                self.phase = self.phase - 1
            }
        }
        if self.useSharedAnimationPhase {
            AnimatedGradientBackgroundView.sharedPhase = self.phase
        }
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: transition, extendAnimation: extendAnimation)
        }
    }
}
