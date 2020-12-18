//
//  GroupCallSpeakButton.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore


final class GroupCallSpeakButton : Control {
    private let button: VoiceChatMicrophoneView = VoiceChatMicrophoneView()
    required init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
        addSubview(button)

        button.userInteractionEnabled = false


    }

    override var mouseDownCanMoveWindow: Bool {
        return false
    }
    
    override func layout() {
        super.layout()
        button.frame = focus(NSMakeSize(90, 90))
    }
    
    func update(with state: PresentationGroupCallState, isMuted: Bool, audioLevel: Float?, animated: Bool) {
        let color: NSColor
        let white = NSColor(rgb: 0xffffff)
        switch state.networkState {
        case .connecting:
            userInteractionEnabled = false
            color = white
        case .connected:
            if isMuted {
                if let muteState = state.muteState {
                    if muteState.canUnmute {
                        color = white
                    } else {
                        color = white
                    }
                    userInteractionEnabled = true
                } else {
                    userInteractionEnabled = true
                    color = white
                }
            } else {
                userInteractionEnabled = true
                color = white
            }
        }

        button.update(state: .init(muted: isMuted, color: color), animated: animated)

    }

    
    private var previousState: ControlState?
    
    override func stateDidUpdated( _ state: ControlState) {
        switch controlState {
        case .Highlight:
            self.layer?.animateScaleCenter(from: 1, to: 0.95, duration: 0.2, removeOnCompletion: false)
        default:
            if let previousState = previousState, previousState == .Highlight {
                self.layer?.animateScaleCenter(from: 0.95, to: 1.0, duration: 0.2)
            }
        }
        previousState = state
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}





final class VoiceChatBlobLayer: CALayer {
    private let mediumBlob: BlobLayer
    private let bigBlob: BlobLayer

    private let maxLevel: CGFloat

    private var displayLinkAnimator: ConstantDisplayLinkAnimator?

    private var audioLevel: CGFloat = 0.0
    var presentationAudioLevel: CGFloat = 0.0

    var scaleUpdated: ((CGFloat) -> Void)? {
        didSet {
            self.bigBlob.scaleUpdated = self.scaleUpdated
        }
    }

    private(set) var isAnimating = false

    public typealias BlobRange = (min: CGFloat, max: CGFloat)

    public init(
        frame: CGRect,
        maxLevel: CGFloat,
        mediumBlobRange: BlobRange,
        bigBlobRange: BlobRange
    ) {
        self.maxLevel = maxLevel

        self.mediumBlob = BlobLayer(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 0.9,
            maxSpeed: 4.0,
            minScale: mediumBlobRange.min,
            maxScale: mediumBlobRange.max
        )
        self.bigBlob = BlobLayer(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 1.0,
            maxSpeed: 4.4,
            minScale: bigBlobRange.min,
            maxScale: bigBlobRange.max
        )

        super.init()

        addSublayer(bigBlob)
        addSublayer(mediumBlob)

        self.frame = frame
        

        displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1

            strongSelf.mediumBlob.level = strongSelf.presentationAudioLevel
            strongSelf.bigBlob.level = strongSelf.presentationAudioLevel
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setColor(_ color: NSColor) {
        mediumBlob.setColor(color.withAlphaComponent(0.55))
        bigBlob.setColor(color.withAlphaComponent(0.35))
    }

    public func updateLevel(_ level: CGFloat) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))

        mediumBlob.updateSpeedLevel(to: normalizedLevel)
        bigBlob.updateSpeedLevel(to: normalizedLevel)

        audioLevel = normalizedLevel
    }

    public func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true

        updateBlobsState()

        displayLinkAnimator?.isPaused = false
    }

    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }

    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        isAnimating = false

        updateBlobsState()

        displayLinkAnimator?.isPaused = true
    }

    private func updateBlobsState() {
        if isAnimating {
            if mediumBlob.frame.size != .zero {
                mediumBlob.startAnimating()
                bigBlob.startAnimating()
            }
        } else {
            mediumBlob.stopAnimating()
            bigBlob.stopAnimating()
        }
    }

    override var frame: CGRect {
        didSet {
            mediumBlob.frame = bounds
            bigBlob.frame = bounds

            updateBlobsState()
        }
    }
}

final class BlobLayer: CAShapeLayer {
    let pointsCount: Int
    let smoothness: CGFloat

    let minRandomness: CGFloat
    let maxRandomness: CGFloat

    let minSpeed: CGFloat
    let maxSpeed: CGFloat

    let minScale: CGFloat
    let maxScale: CGFloat

    var scaleUpdated: ((CGFloat) -> Void)?

    private var blobAnimation: DisplayLinkAnimator?


    private let shapeLayer: CAShapeLayer = {
            let layer = CAShapeLayer()
            layer.strokeColor = nil
            return layer
        }()


    var level: CGFloat = 0 {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let lv = minScale + (maxScale - minScale) * level
            shapeLayer.transform = CATransform3DMakeScale(lv, lv, 1)
            if level != oldValue {
                self.scaleUpdated?(level)
            }
            CATransaction.commit()
        }
    }

    private var speedLevel: CGFloat = 0
    private var lastSpeedLevel: CGFloat = 0


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
        maxScale: CGFloat
    ) {
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minScale = minScale
        self.maxScale = maxScale

        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        self.smoothness = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2

        super.init()
        
        self.addSublayer(shapeLayer)
        shapeLayer.transform = CATransform3DMakeScale(minScale, minScale, 1)

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setColor(_ color: NSColor) {
        shapeLayer.fillColor = color.cgColor
    }

    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        speedLevel = max(speedLevel, newSpeedLevel)

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


    override var frame: CGRect {
        didSet {
            shapeLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        }
    }
}
