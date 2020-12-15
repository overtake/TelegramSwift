//
//  VoiceChatActionButton.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


private let white = NSColor(rgb: 0xffffff)
private let greyColor = NSColor(rgb: 0x2c2c2e)
private let secondaryGreyColor = NSColor(rgb: 0x1c1c1e)
private let blue = NSColor(rgb: 0x0078ff)
private let lightBlue = NSColor(rgb: 0x59c7f8)
private let green = NSColor(rgb: 0x33c659)
private let activeBlue = NSColor(rgb: 0x00a0b9)


private let areaSize = CGSize(width: 360, height: 360)
private let blobSize = CGSize(width: 244, height: 244)

private let progressLineWidth: CGFloat = 3.0 + 1
private let buttonSize = CGSize(width: 144.0, height: 144.0)
private let radius = buttonSize.width / 2.0

final class VoiceChatActionButtonBackgroundView: View {
    enum State: Equatable {
        case connecting
        case disabled
        case blob(Bool)
    }

    private var state: State
    private var hasState = false

    private var transition: State?

    var audioLevel: CGFloat = 0.0  {
        didSet {
            self.maskBlobLayer.updateLevel(audioLevel)
        }
    }

    var updatedActive: ((Bool) -> Void)?
    var updatedOuterColor: ((NSColor?) -> Void)?

    private let backgroundCircleLayer = CAShapeLayer()
    private let foregroundCircleLayer = CAShapeLayer()
    private let growingForegroundCircleLayer = CAShapeLayer()

    private let foregroundView = View()
    private let foregroundGradientLayer = CAGradientLayer()

    private let maskLayer = CALayer()
    private let maskGradientLayer = CAGradientLayer()
    private let maskBlobLayer: VoiceChatBlobLayer
    private let maskCircleLayer = CAShapeLayer()

    fileprivate let maskProgressLayer = CAShapeLayer()

    private let maskMediumBlobLayer = CAShapeLayer()
    private let maskBigBlobLayer = CAShapeLayer()

    private var isCurrentlyInHierarchy = false

    override init() {
        self.state = .connecting

        self.maskBlobLayer = VoiceChatBlobLayer(frame: CGRect(origin: CGPoint(x: (areaSize.width - blobSize.width) / 2.0, y: (areaSize.height - blobSize.height) / 2.0), size: blobSize), maxLevel: 1.5, mediumBlobRange: (0.69, 0.87), bigBlobRange: (0.71, 1.0))
        self.maskBlobLayer.setColor(white)
        self.maskBlobLayer.isHidden = true


        super.init()


        let circlePath = CGMutablePath()
        circlePath.addRoundedRect(in: CGRect(origin: CGPoint(), size: buttonSize), cornerWidth: buttonSize.width / 2, cornerHeight: buttonSize.height / 2)


        self.backgroundCircleLayer.fillColor = greyColor.cgColor
        self.backgroundCircleLayer.path = circlePath


        let smallerCirclePath = CGMutablePath()
        let smallerRect = CGRect(origin: CGPoint(), size: CGSize(width: buttonSize.width - progressLineWidth, height: buttonSize.height - progressLineWidth))
        smallerCirclePath.addRoundedRect(in: smallerRect, cornerWidth: smallerRect.width / 2, cornerHeight: smallerRect.height / 2)


        self.foregroundCircleLayer.fillColor = greyColor.cgColor
        self.foregroundCircleLayer.path = smallerCirclePath
        self.foregroundCircleLayer.transform = CATransform3DMakeScale(0.0, 0.0, 1)
        self.foregroundCircleLayer.isHidden = true

        self.growingForegroundCircleLayer.fillColor = greyColor.cgColor
        self.growingForegroundCircleLayer.path = smallerCirclePath
        self.growingForegroundCircleLayer.transform = CATransform3DMakeScale(1.0, 1.0, 1)
        self.growingForegroundCircleLayer.isHidden = true

        self.foregroundGradientLayer.type = .radial
        self.foregroundGradientLayer.colors = [lightBlue.cgColor, blue.cgColor]
        self.foregroundGradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
        self.foregroundGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)

        self.maskLayer.backgroundColor = .clear

        self.maskGradientLayer.type = .radial
        self.maskGradientLayer.colors = [NSColor(rgb: 0xffffff, alpha: 0.4).cgColor, NSColor(rgb: 0xffffff, alpha: 0.0).cgColor]
        self.maskGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.maskGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.maskGradientLayer.transform = CATransform3DMakeScale(0.3, 0.3, 1.0)
        self.maskGradientLayer.isHidden = true

        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: (buttonSize.width + 6.0) / 2.0, y: (buttonSize.height + 6.0) / 2.0), radius: radius, startAngle: 0.0, endAngle: CGFloat.pi * 2.0, clockwise: true)

        self.maskProgressLayer.strokeColor = white.cgColor
        self.maskProgressLayer.fillColor = NSColor.clear.cgColor
        self.maskProgressLayer.lineWidth = progressLineWidth
        self.maskProgressLayer.lineCap = .round
        self.maskProgressLayer.path = path

        let largerCirclePath = CGMutablePath()
        let largerCircleRect = CGRect(origin: CGPoint(), size: CGSize(width: buttonSize.width + progressLineWidth, height: buttonSize.height + progressLineWidth))
        largerCirclePath.addRoundedRect(in: largerCircleRect, cornerWidth: largerCircleRect.width / 2, cornerHeight: largerCircleRect.height / 2)

        self.maskCircleLayer.fillColor = white.cgColor
        self.maskCircleLayer.path = largerCirclePath
        self.maskCircleLayer.isHidden = true


        self.layer?.addSublayer(self.backgroundCircleLayer)

        self.addSubview(self.foregroundView)
        self.layer?.addSublayer(self.foregroundCircleLayer)
        self.layer?.addSublayer(self.growingForegroundCircleLayer)

        self.foregroundView.layer?.addSublayer(self.foregroundGradientLayer)
        self.foregroundView.layer?.mask = self.maskLayer

        self.maskLayer.addSublayer(self.maskGradientLayer)
        self.maskLayer.addSublayer(self.maskProgressLayer)
        self.maskLayer.addSublayer(self.maskBlobLayer)
        self.maskLayer.addSublayer(self.maskCircleLayer)

        self.maskBlobLayer.scaleUpdated = { [weak self] scale in
            if let strongSelf = self {
                strongSelf.updateGlowScale(strongSelf.isActive ? scale : nil)
            }
        }
        isEventLess = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.isCurrentlyInHierarchy = window != nil
        self.updateAnimations()

    }


    private func setupGradientAnimations() {
        if let _ = self.foregroundGradientLayer.animation(forKey: "movement") {
        } else {
            let previousValue = self.foregroundGradientLayer.startPoint
            let newValue: CGPoint
            if self.maskBlobLayer.presentationAudioLevel > 0.22 {
                newValue = CGPoint(x: CGFloat.random(in: 0.9 ..< 1.0), y: CGFloat.random(in: 0.1 ..< 0.35))
            } else if self.maskBlobLayer.presentationAudioLevel > 0.01 {
                newValue = CGPoint(x: CGFloat.random(in: 0.77 ..< 0.95), y: CGFloat.random(in: 0.1 ..< 0.35))
            } else {
                newValue = CGPoint(x: CGFloat.random(in: 0.65 ..< 0.85), y: CGFloat.random(in: 0.1 ..< 0.45))
            }
            self.foregroundGradientLayer.startPoint = newValue

            CATransaction.begin()

            let animation = CABasicAnimation(keyPath: "startPoint")
            animation.duration = Double.random(in: 0.8 ..< 1.4)
            animation.fromValue = previousValue
            animation.toValue = newValue

            CATransaction.setCompletionBlock { [weak self] in
                if let isCurrentlyInHierarchy = self?.isCurrentlyInHierarchy, isCurrentlyInHierarchy {
                    self?.setupGradientAnimations()
                }
            }

            self.foregroundGradientLayer.add(animation, forKey: "movement")
            CATransaction.commit()
        }
    }

    private func setupProgressAnimations() {
        if let _ = self.maskProgressLayer.animation(forKey: "progressRotation") {
        } else {
            self.maskProgressLayer.isHidden = false

            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
            animation.duration = 1.0
            animation.fromValue = NSNumber(value: Float(0.0))
            animation.toValue = NSNumber(value: Float.pi * 2.0)
            animation.repeatCount = Float.infinity
            animation.beginTime = 0.0
            self.maskProgressLayer.add(animation, forKey: "progressRotation")

            let shrinkAnimation = CABasicAnimation(keyPath: "strokeEnd")
            shrinkAnimation.fromValue = 1.0
            shrinkAnimation.toValue = 0.0
            shrinkAnimation.duration = 1.0
            shrinkAnimation.beginTime = 0.0

            let growthAnimation = CABasicAnimation(keyPath: "strokeEnd")
            growthAnimation.fromValue = 0.0
            growthAnimation.toValue = 1.0
            growthAnimation.duration = 1.0
            growthAnimation.beginTime = 1.0

            let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotateAnimation.fromValue = 0.0
            rotateAnimation.toValue = CGFloat.pi * 2
            rotateAnimation.isAdditive = true
            rotateAnimation.duration = 1.0
            rotateAnimation.beginTime = 1.0

            let groupAnimation = CAAnimationGroup()
            groupAnimation.repeatCount = Float.infinity
            groupAnimation.animations = [shrinkAnimation, growthAnimation, rotateAnimation]
            groupAnimation.duration = 2.0

            self.maskProgressLayer.add(groupAnimation, forKey: "progressGrowth")
        }
    }

    var glowHidden: Bool = false {
        didSet {
            if self.glowHidden != oldValue {
                let initialAlpha = CGFloat(self.maskProgressLayer.opacity)
                let targetAlpha: CGFloat = self.glowHidden ? 0.0 : 1.0
                self.maskGradientLayer.opacity = Float(targetAlpha)
                self.maskGradientLayer.animateAlpha(from: initialAlpha, to: targetAlpha, duration: 0.2)
            }
        }
    }

    var disableGlowAnimations = false
    func updateGlowScale(_ scale: CGFloat?) {
        if self.disableGlowAnimations {
            return
        }
        if let scale = scale {
            self.maskGradientLayer.transform = CATransform3DMakeScale(0.89 + 0.11 * scale, 0.89 + 0.11 * scale, 1.0)
        } else {
            let initialScale: CGFloat = ((self.maskGradientLayer.value(forKeyPath: "presentationLayer.transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? (((self.maskGradientLayer.value(forKeyPath: "transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? (0.89))
            let targetScale: CGFloat = self.isActive ? 0.89 : 0.85
            if abs(targetScale - initialScale) > 0.03 {
                self.maskGradientLayer.transform = CATransform3DMakeScale(targetScale, targetScale, 1.0)
                self.maskGradientLayer.animateScale(from: initialScale, to: targetScale, duration: 0.3)
            }
        }
    }

    func updateGlowAndGradientAnimations(active: Bool?, previousActive: Bool? = nil) {
        let effectivePreviousActive = previousActive ?? false

        let initialScale: CGFloat = ((self.maskGradientLayer.value(forKeyPath: "presentationLayer.transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? (((self.maskGradientLayer.value(forKeyPath: "transform.scale.x") as? NSNumber)?.floatValue).flatMap({ CGFloat($0) }) ?? (effectivePreviousActive ? 0.95 : 0.8))
        let initialColors = self.foregroundGradientLayer.colors

        let outerColor: NSColor?
        let targetColors: [CGColor]
        let targetScale: CGFloat
        if let active = active {
            if active {
                targetColors = [activeBlue.cgColor, green.cgColor]
                targetScale = 0.89
                outerColor = NSColor(rgb: 0x21674f)
            } else {
                targetColors = [lightBlue.cgColor, blue.cgColor]
                targetScale = 0.85
                outerColor = NSColor(rgb: 0x1d588d)
            }
        } else {
            targetColors = [lightBlue.cgColor, blue.cgColor]
            targetScale = 0.3
            outerColor = nil
        }
        self.updatedOuterColor?(outerColor)

        self.maskGradientLayer.transform = CATransform3DMakeScale(targetScale, targetScale, 1.0)
        if let _ = previousActive {
            self.maskGradientLayer.animateScale(from: initialScale, to: targetScale, duration: 0.3)
        } else {
            self.maskGradientLayer.animateSpring(from: initialScale as NSNumber, to: targetScale as NSNumber, keyPath: "transform.scale", duration: 0.45)
        }

        self.foregroundGradientLayer.colors = targetColors
        self.foregroundGradientLayer.animate(from: initialColors as AnyObject, to: targetColors as AnyObject, keyPath: "colors", timingFunction: .linear, duration: 0.3)
    }

    private func playConnectionDisappearanceAnimation() {
        let initialRotation: CGFloat = CGFloat((self.maskProgressLayer.value(forKeyPath: "presentationLayer.transform.rotation.z") as? NSNumber)?.floatValue ?? 0.0)
        let initialStrokeEnd: CGFloat = CGFloat((self.maskProgressLayer.value(forKeyPath: "presentationLayer.strokeEnd") as? NSNumber)?.floatValue ?? 1.0)
        CATransaction.begin()

        let maskProgressLayer = self.maskProgressLayer

        maskProgressLayer.removeAnimation(forKey: "progressGrowth")
        maskProgressLayer.removeAnimation(forKey: "progressRotation")

        let duration: Double = (1.0 - Double(initialStrokeEnd)) * 0.6

        let growthAnimation = CABasicAnimation(keyPath: "strokeEnd")
        growthAnimation.fromValue = initialStrokeEnd
        growthAnimation.toValue = 0.0
        growthAnimation.duration = duration
        growthAnimation.isRemovedOnCompletion = false
        growthAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotateAnimation.fromValue = initialRotation
        rotateAnimation.toValue = initialRotation + CGFloat.pi * 2
        rotateAnimation.isAdditive = true
        rotateAnimation.duration = duration
        rotateAnimation.isRemovedOnCompletion = false
        rotateAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [growthAnimation, rotateAnimation]
        groupAnimation.duration = duration
        groupAnimation.isRemovedOnCompletion = false


        self.maskProgressLayer.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { [weak maskProgressLayer] _ in
            maskProgressLayer?.isHidden = true
            maskProgressLayer?.removeAllAnimations()
        })

        self.maskProgressLayer.add(groupAnimation, forKey: "progressDisappearance")
        CATransaction.commit()
    }

    var animatingDisappearance = false
    private func playBlobsDisappearanceAnimation() {
        if self.animatingDisappearance {
            return
        }
        self.animatingDisappearance = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.growingForegroundCircleLayer.isHidden = false
        CATransaction.commit()

        self.disableGlowAnimations = true
        self.maskGradientLayer.removeAllAnimations()
        self.updateGlowAndGradientAnimations(active: nil, previousActive: nil)

        self.maskBlobLayer.startAnimating()
        self.maskBlobLayer.animateScale(from: 1.0, to: 0, duration: 0.15, removeOnCompletion: false, completion: { [weak self] _ in
            self?.maskBlobLayer.isHidden = true
            self?.maskBlobLayer.stopAnimating()
            self?.maskBlobLayer.removeAllAnimations()
        })

        CATransaction.begin()
        let growthAnimation = CABasicAnimation(keyPath: "transform.scale")
        growthAnimation.fromValue = 0.0
        growthAnimation.toValue = 1.0
        growthAnimation.duration = 0.15
        growthAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        growthAnimation.isRemovedOnCompletion = false

        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.disableGlowAnimations = false
            self.maskGradientLayer.isHidden = true
            self.maskCircleLayer.isHidden = true
            self.growingForegroundCircleLayer.isHidden = true
            self.growingForegroundCircleLayer.removeAllAnimations()
            self.animatingDisappearance = false
            CATransaction.commit()
        }

      //  self.growingForegroundCircleLayer.add(growthAnimation, forKey: "insideGrowth")
        CATransaction.commit()
    }

    private func playBlobsAppearanceAnimation(active: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.foregroundCircleLayer.isHidden = false
        self.maskCircleLayer.isHidden = false
        self.maskProgressLayer.isHidden = true
        self.maskGradientLayer.isHidden = false
        CATransaction.commit()

        self.disableGlowAnimations = true
        self.maskGradientLayer.removeAllAnimations()
        self.updateGlowAndGradientAnimations(active: active, previousActive: nil)

        self.maskBlobLayer.isHidden = false
        self.maskBlobLayer.startAnimating()
        self.maskBlobLayer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)

        CATransaction.begin()
        let shrinkAnimation = CABasicAnimation(keyPath: "transform.scale")
        shrinkAnimation.fromValue = 1.0
        shrinkAnimation.toValue = 0.0
        shrinkAnimation.duration = 0.15
        shrinkAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)

        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.disableGlowAnimations = false
            self.foregroundCircleLayer.isHidden = true
            CATransaction.commit()
        }

        self.foregroundCircleLayer.add(shrinkAnimation, forKey: "insideShrink")
        CATransaction.commit()
    }

    private func playConnectionAnimation(active: Bool, completion: @escaping () -> Void) {
        CATransaction.begin()
        let initialRotation: CGFloat = CGFloat((self.maskProgressLayer.value(forKeyPath: "presentationLayer.transform.rotation.z") as? NSNumber)?.floatValue ?? 0.0)
        let initialStrokeEnd: CGFloat = CGFloat((self.maskProgressLayer.value(forKeyPath: "presentationLayer.strokeEnd") as? NSNumber)?.floatValue ?? 1.0)

        self.maskProgressLayer.removeAnimation(forKey: "progressGrowth")
        self.maskProgressLayer.removeAnimation(forKey: "progressRotation")

        let duration: Double = (1.0 - Double(initialStrokeEnd)) * 0.3

        let growthAnimation = CABasicAnimation(keyPath: "strokeEnd")
        growthAnimation.fromValue = initialStrokeEnd
        growthAnimation.toValue = 1.0
        growthAnimation.duration = duration
        growthAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)

        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotateAnimation.fromValue = initialRotation
        rotateAnimation.toValue = initialRotation + CGFloat.pi * 2
        rotateAnimation.isAdditive = true
        rotateAnimation.duration = duration
        rotateAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)

        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [growthAnimation, rotateAnimation]
        groupAnimation.duration = duration

        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.foregroundCircleLayer.isHidden = false
            self.maskCircleLayer.isHidden = false
            self.maskProgressLayer.isHidden = true
            self.maskGradientLayer.isHidden = false
            CATransaction.commit()

            completion()

            self.updateGlowAndGradientAnimations(active: active, previousActive: nil)

            self.maskBlobLayer.isHidden = false
            self.maskBlobLayer.startAnimating()
            self.maskBlobLayer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.45)

            self.updatedActive?(true)

            CATransaction.begin()
            let shrinkAnimation = CABasicAnimation(keyPath: "transform.scale")
            shrinkAnimation.fromValue = 1.0
            shrinkAnimation.toValue = 0.0
            shrinkAnimation.duration = 0.15
            shrinkAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)

            CATransaction.setCompletionBlock {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.foregroundCircleLayer.isHidden = true
                CATransaction.commit()
            }

            self.foregroundCircleLayer.add(shrinkAnimation, forKey: "insideShrink")
            CATransaction.commit()
        }

        self.maskProgressLayer.add(groupAnimation, forKey: "progressCompletion")
        CATransaction.commit()
    }

    var isActive = false
    func updateAnimations() {
        if !self.isCurrentlyInHierarchy {
            self.foregroundGradientLayer.removeAllAnimations()
            self.maskGradientLayer.removeAllAnimations()
            self.maskProgressLayer.removeAllAnimations()
            self.maskBlobLayer.stopAnimating()
            return
        }
        self.setupGradientAnimations()

        switch self.state {
            case .connecting:
                self.updatedActive?(false)
                if let transition = self.transition {
                    self.updateGlowScale(nil)
                    if case .blob = transition {
                        playBlobsDisappearanceAnimation()
                    }
                    self.transition = nil
                }
                self.setupProgressAnimations()
                self.isActive = false
            case let .blob(newActive):
                if let transition = self.transition {
                    if transition == .connecting {
                        self.playConnectionAnimation(active: newActive) { [weak self] in
                            self?.isActive = newActive
                        }
                    } else if transition == .disabled {
                        self.playBlobsAppearanceAnimation(active: newActive)
                        self.transition = nil
                        self.isActive = newActive
                        self.updatedActive?(true)
                    } else if case let .blob(previousActive) = transition {
                        updateGlowAndGradientAnimations(active: newActive, previousActive: previousActive)
                        self.transition = nil
                        self.isActive = newActive
                    }
                    self.transition = nil
                } else {
                    self.maskBlobLayer.startAnimating()
                }
            case .disabled:
                self.updatedActive?(true)
                self.isActive = false
                self.updateGlowScale(nil)

                if let transition = self.transition {
                    if case .connecting = transition {
                        playConnectionDisappearanceAnimation()
                    } else if case .blob = transition {
                        playBlobsDisappearanceAnimation()
                    }
                    self.transition = nil
                }
                break
        }
    }

    var isDark: Bool = false {
        didSet {
            if self.isDark != oldValue {
                self.updateColors()
            }
        }
    }

    var isSnap: Bool = false {
        didSet {
            if self.isSnap != oldValue {
                self.updateColors()
            }
        }
    }

    var connectingColor: NSColor = NSColor(rgb: 0xb6b6bb) {
        didSet {
            if self.connectingColor.rgb != oldValue.rgb {
                self.updateColors()
            }
        }
    }

    func updateColors() {
        let previousColor: CGColor = self.backgroundCircleLayer.fillColor ?? greyColor.cgColor
        let targetColor: CGColor
        if self.isSnap {
            targetColor = self.connectingColor.cgColor
        } else if self.isDark {
            targetColor = secondaryGreyColor.cgColor
        } else {
            targetColor = greyColor.cgColor
        }
        self.backgroundCircleLayer.fillColor = targetColor
        self.foregroundCircleLayer.fillColor = targetColor
        self.growingForegroundCircleLayer.fillColor = targetColor
        self.backgroundCircleLayer.animate(from: previousColor, to: targetColor, keyPath: "fillColor", timingFunction: .linear, duration: 0.3)
        self.foregroundCircleLayer.animate(from: previousColor, to: targetColor, keyPath: "fillColor", timingFunction: .linear, duration: 0.3)
        self.growingForegroundCircleLayer.animate(from: previousColor, to: targetColor, keyPath: "fillColor", timingFunction: .linear, duration: 0.3)
    }

    func update(state: State, animated: Bool) {
        var animated = animated
        var hadState = true
        if !self.hasState {
            hadState = false
            self.hasState = true
            animated = false
        }

        if state != self.state || !hadState {
            if animated {
                self.transition = self.state
            }
            self.state = state

            self.updateAnimations()
        }

    }

    override func layout() {
        super.layout()

        let center = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
        let circleFrame = CGRect(origin: CGPoint(x: (self.bounds.width - buttonSize.width) / 2.0, y: (self.bounds.height - buttonSize.height) / 2.0), size: buttonSize)
        self.backgroundCircleLayer.frame = circleFrame
        self.foregroundCircleLayer.position = center
        self.foregroundCircleLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: circleFrame.width - progressLineWidth, height: circleFrame.height - progressLineWidth))
        self.growingForegroundCircleLayer.position = center
        self.growingForegroundCircleLayer.bounds = self.foregroundCircleLayer.bounds
        self.maskCircleLayer.frame = circleFrame.insetBy(dx: -progressLineWidth / 2.0, dy: -progressLineWidth / 2.0)
        self.maskProgressLayer.frame = circleFrame.insetBy(dx: -3.0, dy: -3.0)
        self.foregroundView.frame = self.bounds
        self.foregroundGradientLayer.frame = self.bounds
        self.maskGradientLayer.position = center
        self.maskGradientLayer.bounds = self.bounds
        self.maskLayer.frame = self.bounds

//        self.maskBlobLayer.bounds = .init(origin: <#T##CGPoint#>, size: <#T##CGSize#>)
    }
}
