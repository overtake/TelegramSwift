//
//  AvatarStoryIndicatorComponent.swift
//  Telegram
//
//  Created by Mike Renoir on 30.06.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox



private final class ProgressLayer: SimpleLayer {
    enum Value: Equatable {
        case indefinite
        case progress(Float)
    }
    
    private struct Params: Equatable {
        var size: CGSize
        var lineWidth: CGFloat
        var value: Value
    }
    private var currentParams: Params?
    
    private let uploadProgressLayer = SimpleShapeLayer()
    
    private let indefiniteDashLayer = SimpleShapeLayer()
    private let indefiniteReplicatorLayer = CAReplicatorLayer()
    
    override init() {
        super.init()
        
        self.uploadProgressLayer.fillColor = nil
        self.uploadProgressLayer.strokeColor = NSColor.white.cgColor
        self.uploadProgressLayer.lineCap = .round
        
        self.indefiniteDashLayer.fillColor = nil
        self.indefiniteDashLayer.strokeColor = NSColor.white.cgColor
        self.indefiniteDashLayer.lineCap = .round
        self.indefiniteDashLayer.lineJoin = .round
        self.indefiniteDashLayer.strokeEnd = 0.0333
        
        let count = 1.0 / self.indefiniteDashLayer.strokeEnd
        let angle = (2.0 * Double.pi) / Double(count)
        self.indefiniteReplicatorLayer.addSublayer(self.indefiniteDashLayer)
        self.indefiniteReplicatorLayer.instanceCount = Int(count)
        self.indefiniteReplicatorLayer.instanceTransform = CATransform3DMakeRotation(CGFloat(angle), 0.0, 0.0, 1.0)
        self.indefiniteReplicatorLayer.transform = CATransform3DMakeRotation(-.pi / 2.0, 0.0, 0.0, 1.0)
        self.indefiniteReplicatorLayer.instanceDelay = 0.025
        
        self.didEnterHierarchy = { [weak self] in
            guard let `self` = self else {
                return
            }
            self.updateAnimations(transition: .immediate)
        }
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reset() {
        self.currentParams = nil
        self.indefiniteDashLayer.path = nil
        self.uploadProgressLayer.path = nil
    }
    
    func updateAnimations(transition: ContainedViewLayoutTransition) {
        guard let params = self.currentParams else {
            return
        }
        
        switch params.value {
        case let .progress(progress):
            if self.indefiniteReplicatorLayer.superlayer != nil {
                self.indefiniteReplicatorLayer.removeFromSuperlayer()
            }
            if self.uploadProgressLayer.superlayer == nil {
                self.addSublayer(self.uploadProgressLayer)
            }
            transition.setShapeLayerStrokeEnd(layer: self.uploadProgressLayer, strokeEnd: CGFloat(progress))
            if self.uploadProgressLayer.animation(forKey: "rotation") == nil {
                let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotationAnimation.duration = 2.0
                rotationAnimation.fromValue = NSNumber(value: Float(0.0))
                rotationAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
                rotationAnimation.repeatCount = Float.infinity
                rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                self.uploadProgressLayer.add(rotationAnimation, forKey: "rotation")
            }
        case .indefinite:
            if self.uploadProgressLayer.superlayer == nil {
                self.uploadProgressLayer.removeFromSuperlayer()
            }
            if self.indefiniteReplicatorLayer.superlayer == nil {
                self.addSublayer(self.indefiniteReplicatorLayer)
            }
            if self.indefiniteReplicatorLayer.animation(forKey: "rotation") == nil {
                let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotationAnimation.duration = 4.0
                rotationAnimation.fromValue = NSNumber(value: -.pi / 2.0)
                rotationAnimation.toValue = NSNumber(value: -.pi / 2.0 + Double.pi * 2.0)
                rotationAnimation.repeatCount = Float.infinity
                rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                self.indefiniteReplicatorLayer.add(rotationAnimation, forKey: "rotation")
            }
            if self.indefiniteDashLayer.animation(forKey: "dash") == nil {
                let dashAnimation = CAKeyframeAnimation(keyPath: "strokeStart")
                dashAnimation.keyTimes = [0.0, 0.45, 0.55, 1.0]
                dashAnimation.values = [
                    self.indefiniteDashLayer.strokeStart,
                    self.indefiniteDashLayer.strokeEnd,
                    self.indefiniteDashLayer.strokeEnd,
                    self.indefiniteDashLayer.strokeStart,
                ]
                dashAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
                dashAnimation.duration = 2.5
                dashAnimation.repeatCount = .infinity
                self.indefiniteDashLayer.add(dashAnimation, forKey: "dash")
            }
        }
    }
    
    func update(size: CGSize, radius: CGFloat, lineWidth: CGFloat, value: Value, transition: ContainedViewLayoutTransition) {
        let params = Params(
            size: size,
            lineWidth: lineWidth,
            value: value
        )
        if self.currentParams == params {
            return
        }
        self.currentParams = params
        
        self.indefiniteDashLayer.lineWidth = lineWidth
        self.uploadProgressLayer.lineWidth = lineWidth
        
        let bounds = CGRect(origin: .zero, size: size)
        if self.uploadProgressLayer.path == nil {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(origin: CGPoint(x: (size.width - radius * 2.0) * 0.5, y: (size.height - radius * 2.0) * 0.5), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
            self.uploadProgressLayer.path = path
            self.uploadProgressLayer.frame = bounds
        }
        
        if self.indefiniteDashLayer.path == nil {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(origin: CGPoint(x: (size.width - radius * 2.0) * 0.5, y: (size.height - radius * 2.0) * 0.5), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
            self.indefiniteDashLayer.path = path
            self.indefiniteReplicatorLayer.frame = bounds
            self.indefiniteDashLayer.frame = bounds
        }
        
        self.updateAnimations(transition: transition)
    }
}


public final class AvatarStoryIndicatorComponent : Equatable {
    
    public struct ActiveColors {
        let basic: [NSColor]
        let close: [NSColor]
        public init(basic: [NSColor], close: [NSColor]) {
            self.basic = basic
            self.close = close
        }
        public static var `default`: ActiveColors {
            return ActiveColors(basic: [NSColor(rgb: 0x34C76F), NSColor(rgb: 0x3DA1FD)], close: [NSColor(rgb: 0x7CD636), NSColor(rgb: 0x26B470)])
        }
    }
    public struct Counters: Equatable {
        public var totalCount: Int
        public var unseenCount: Int
        
        public init(totalCount: Int, unseenCount: Int) {
            self.totalCount = totalCount
            self.unseenCount = unseenCount
        }
    }
    
    public let hasUnseen: Bool
    public let hasUnseenCloseFriendsItems: Bool
    public let theme: PresentationTheme
    public let activeLineWidth: CGFloat
    public let inactiveLineWidth: CGFloat
    public let counters: Counters?
    public let activeColors: ActiveColors
    public let isRoundedRect: Bool
    public init(
        hasUnseen: Bool,
        hasUnseenCloseFriendsItems: Bool,
        theme: PresentationTheme,
        activeLineWidth: CGFloat,
        inactiveLineWidth: CGFloat,
        counters: Counters?,
        activeColors: ActiveColors = .default,
        isRoundedRect: Bool = false
    ) {
        self.hasUnseen = hasUnseen
        self.hasUnseenCloseFriendsItems = hasUnseenCloseFriendsItems
        self.theme = theme
        self.activeLineWidth = activeLineWidth
        self.inactiveLineWidth = inactiveLineWidth
        self.counters = counters
        self.activeColors = activeColors
        self.isRoundedRect = isRoundedRect
    }
    public convenience init(story: EngineStorySubscriptions.Item, presentation: PresentationTheme, active: Bool = false, isRoundedRect: Bool? = nil) {
        let hasUnseen = story.hasUnseen || story.hasUnseenCloseFriends
        self.init(hasUnseen: hasUnseen, hasUnseenCloseFriendsItems: story.hasUnseenCloseFriends, theme: presentation, activeLineWidth: 2.0, inactiveLineWidth: 1.0, counters: .init(totalCount: story.storyCount, unseenCount: active && hasUnseen ? story.storyCount : story.unseenCount), isRoundedRect: isRoundedRect ?? story.peer._asPeer().isForum)
    }
    
    public convenience init(stats: EngineChatList.StoryStats, presentation: PresentationTheme, activeColors: ActiveColors = .default, isRoundedRect: Bool = false) {
        let hasUnseen = stats.unseenCount > 0
        self.init(hasUnseen: hasUnseen, hasUnseenCloseFriendsItems: stats.hasUnseenCloseFriends, theme: presentation, activeLineWidth: 2.0, inactiveLineWidth: 1.0, counters: .init(totalCount: stats.totalCount, unseenCount: stats.unseenCount), activeColors: activeColors, isRoundedRect: isRoundedRect)
    }
    
    public convenience init(state storyState: PeerExpiringStoryListContext.State, presentation: PresentationTheme, activeColors: ActiveColors = .default, isRoundedRect: Bool = false) {
        self.init(hasUnseen: storyState.hasUnseen, hasUnseenCloseFriendsItems: storyState.hasUnseenCloseFriends, theme: presentation, activeLineWidth: 2.0, inactiveLineWidth: 1.0, counters: .init(totalCount: storyState.items.count, unseenCount: storyState.unseenCount), activeColors: activeColors, isRoundedRect: isRoundedRect)
    }

    
    public static func ==(lhs: AvatarStoryIndicatorComponent, rhs: AvatarStoryIndicatorComponent) -> Bool {
        if lhs.hasUnseen != rhs.hasUnseen {
            return false
        }
        if lhs.hasUnseenCloseFriendsItems != rhs.hasUnseenCloseFriendsItems {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.activeLineWidth != rhs.activeLineWidth {
            return false
        }
        if lhs.inactiveLineWidth != rhs.inactiveLineWidth {
            return false
        }
        if lhs.counters != rhs.counters {
            return false
        }
        return true
    }
    
    public final class IndicatorView : View {
        
        private final class Drawer: LayerBackedView {
                        
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                layer?.masksToBounds = false
                layer?.contentsScale = System.backingScale
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func update(component: AvatarStoryIndicatorComponent, progress: CGFloat, availableSize: CGSize) -> CGSize {
                self.availableSize = availableSize
                self.component = component
                self.progress = progress
                self.updateContent()
                return availableSize
            }
            
            override func updateLayer() {
                super.updateLayer()
                updateContent()
            }
            
            private func updateContent() {
                self.layer?.contents = generateImage(frame.size, rotatedContext: { size, context in
                    guard let component = self.component else {
                        return
                    }
                    
                    
                    let progress = self.progress
                    
                    
                    let lineWidth: CGFloat
                    let diameter: CGFloat
                    
                    if component.hasUnseen {
                        lineWidth = component.activeLineWidth
                    } else {
                        lineWidth = component.inactiveLineWidth
                    }
                    let maxOuterInset: CGFloat = 3.0
                    diameter = availableSize.width + maxOuterInset * 2.0
                    let imageDiameter = availableSize.width + maxOuterInset * 2.0
                    
                    
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    let activeColors: [NSColor]
                    let inactiveColors: [NSColor]
                    
                    if component.hasUnseenCloseFriendsItems {
                        activeColors = component.activeColors.close
                    } else {
                        activeColors = component.activeColors.basic
                    }
                    
                    if component.theme.colors.isDark {
                        inactiveColors = [component.theme.colors.grayText.withAlphaComponent(0.5), component.theme.colors.grayText.withAlphaComponent(0.5)]
                    } else {
                        inactiveColors = [NSColor(rgb: 0xD8D8E1), NSColor(rgb: 0xD8D8E1)]
                    }
                    
                    
                    var locations: [CGFloat] = [0.0, 1.0]
                    
                    context.setLineWidth(lineWidth)
                    context.setLineCap(.round)
                    let spacing: CGFloat = 3.0 * progress
                    
                    if let counters = component.counters, counters.totalCount > 1, spacing >= 2, counters.totalCount < 50, !component.isRoundedRect {
                        
                        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                        let radius = (diameter - lineWidth) * 0.5
                        let angularSpacing: CGFloat = spacing / radius
                        let circleLength = CGFloat.pi * 2.0 * radius
                        let segmentLength = (circleLength - spacing * CGFloat(counters.totalCount)) / CGFloat(counters.totalCount)
                        let segmentAngle = segmentLength / radius
                        if segmentLength >= 1 {
                            var passCount = 2
                            if counters.unseenCount > 0 {
                                passCount = 3
                            }
                            
                            for pass in 0 ..< passCount {
                                context.resetClip()
                                
                                let startIndex: Int
                                let endIndex: Int
                                if pass == 0 {
                                    startIndex = 0
                                    endIndex = counters.totalCount - counters.unseenCount
                                } else if pass == 1 {
                                    startIndex = counters.totalCount - counters.unseenCount
                                    endIndex = counters.totalCount
                                } else {
                                    startIndex = 0
                                    endIndex = counters.totalCount - counters.unseenCount
                                }
                                if startIndex < endIndex {
                                    for i in startIndex ..< endIndex {
                                        let startAngle = CGFloat(i) * (angularSpacing + segmentAngle) - CGFloat.pi * 0.5 + angularSpacing * 0.5
                                        context.move(to: CGPoint(x: center.x + cos(startAngle) * radius, y: center.y + sin(startAngle) * radius))
                                        context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + segmentAngle, clockwise: false)
                                    }
                                    
                                    context.replacePathWithStrokedPath()
                                    context.clip()
                                    
                                    let colors: [CGColor]
                                    if pass == 1 {
                                        colors = activeColors.map { $0.cgColor }
                                    } else if pass == 0 {
                                        colors = inactiveColors.map { $0.cgColor }
                                    } else {
                                        colors = activeColors.map { $0.withAlphaComponent(1 - progress) }.map { $0.cgColor }
                                    }
                                    
                                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                                    
                                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                                }
                            }
                            return
                        }
                    }
                    
                    if component.isRoundedRect {
                        context.addPath(CGPath(roundedRect: CGRect(origin: CGPoint(x: size.width * 0.5 - diameter * 0.5, y: size.height * 0.5 - diameter * 0.5), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5), cornerWidth: floor(diameter * 0.33), cornerHeight: floor(diameter * 0.33), transform: nil))
                    } else {
                        let ellipse = CGRect(origin: CGPoint(x: size.width * 0.5 - diameter * 0.5, y: size.height * 0.5 - diameter * 0.5), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5)
                        context.addEllipse(in: ellipse)
                    }
                    
                    context.replacePathWithStrokedPath()
                    context.clip()
                    
                    let colors: [CGColor]
                    if component.hasUnseen {
                        colors = activeColors.map { $0.cgColor }
                    } else {
                        colors = inactiveColors.map { $0.cgColor }
                    }
                    
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                    
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                })
            }
            
            private var availableSize: NSSize = .zero
            private var component: AvatarStoryIndicatorComponent?
            private var progress: CGFloat = 1.0
            
        }
    
        
        private let indicatorView: Drawer = Drawer(frame: .zero)
        
        private var colorLayer: SimpleGradientLayer?
        private var progressLayer: ProgressLayer?
        
        
        private(set) var component: AvatarStoryIndicatorComponent?
        private(set) var availableSize: NSSize? = nil
        private(set) var progress: CGFloat? = nil
        private(set) var displayProgress: Bool = false

        required init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.indicatorView)
            self.layer?.masksToBounds = false
            self.indicatorView.layer?.masksToBounds = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarStoryIndicatorComponent, availableSize: CGSize, progress: CGFloat = 1.0, transition: ContainedViewLayoutTransition, displayProgress: Bool = false)  {
            
            if component == self.component, availableSize == self.availableSize, progress == self.progress, displayProgress == self.displayProgress {
                return
            }
            self.component = component
            self.availableSize = availableSize
            self.progress = progress
            self.displayProgress = displayProgress
            let imageDiameter = availableSize.width + 3.0 * 2.0
            
            let indicatorFrame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: imageDiameter, height: imageDiameter))
            transition.updateFrame(view: self.indicatorView, frame: indicatorFrame)
            
            
            if displayProgress {
                let colorLayer: SimpleGradientLayer
                if let current = self.colorLayer {
                    colorLayer = current
                } else {
                    colorLayer = SimpleGradientLayer()
                    self.colorLayer = colorLayer
                    self.layer!.addSublayer(colorLayer)
                    colorLayer.opacity = 0.0
                }
                
                transition.updateAlpha(view: self.indicatorView, alpha: 0.0)
                transition.updateAlpha(layer: colorLayer, alpha: 1.0)
                
                let colors: [CGColor]
                
                if component.hasUnseen {
                    if component.hasUnseenCloseFriendsItems {
                        colors = [
                            NSColor(rgb: 0x7CD636),
                            NSColor(rgb: 0x26B470)
                        ].map(\.cgColor)
                    } else {
                        colors = [
                            NSColor(rgb: 0x34C76F),
                            NSColor(rgb: 0x3DA1FD)
                        ].map(\.cgColor)
                    }
                } else {
                    if component.theme.colors.isDark {
                        colors = [component.theme.colors.grayText.withAlphaComponent(0.5), component.theme.colors.grayText.withAlphaComponent(0.5)].map(\.cgColor)
                    } else {
                        colors = [NSColor(rgb: 0xD8D8E1), NSColor(rgb: 0xD8D8E1)].map(\.cgColor)
                    }
                }
                
                let lineWidth: CGFloat = component.hasUnseen ? component.activeLineWidth : component.inactiveLineWidth
                
                colorLayer.colors = colors
                colorLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
                colorLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
                
                let progressLayer: ProgressLayer
                if let current = self.progressLayer {
                    progressLayer = current
                } else {
                    progressLayer = ProgressLayer()
                    self.progressLayer = progressLayer
                    colorLayer.mask = progressLayer
                }
                
                colorLayer.frame = indicatorFrame
                progressLayer.frame = CGRect(origin: CGPoint(), size: indicatorFrame.size)
                
                let maxOuterInset: CGFloat = 3.0
                let diameter = availableSize.width + maxOuterInset * 2.0
                let radius = (diameter - component.activeLineWidth) * 0.5

                
                progressLayer.update(size: indicatorFrame.size, radius: radius, lineWidth: lineWidth, value: .indefinite, transition: .immediate)
            } else {
                transition.updateAlpha(view: self.indicatorView, alpha: 1.0)
                
                self.progressLayer = nil
                if let colorLayer = self.colorLayer {
                    self.colorLayer = nil
                    
                    transition.updateAlpha(layer: colorLayer, alpha: 0.0, completion: { [weak colorLayer] _ in
                        colorLayer?.removeFromSuperlayer()
                    })
                }
            }

            
            _ = self.indicatorView.update(component: component, progress: progress, availableSize: availableSize)
        }
    }
    deinit {
        var bp = 0
        bp += 1
    }
    
}

