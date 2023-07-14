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

public final class AvatarStoryIndicatorComponent : Equatable {
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
    
    public init(
        hasUnseen: Bool,
        hasUnseenCloseFriendsItems: Bool,
        theme: PresentationTheme,
        activeLineWidth: CGFloat,
        inactiveLineWidth: CGFloat,
        counters: Counters?
    ) {
        self.hasUnseen = hasUnseen
        self.hasUnseenCloseFriendsItems = hasUnseenCloseFriendsItems
        self.theme = theme
        self.activeLineWidth = activeLineWidth
        self.inactiveLineWidth = inactiveLineWidth
        self.counters = counters
    }
    public convenience init(story: EngineStorySubscriptions.Item, presentation: PresentationTheme, active: Bool = false) {
        let hasUnseen = story.hasUnseen || story.hasUnseenCloseFriends
        self.init(hasUnseen: hasUnseen, hasUnseenCloseFriendsItems: story.hasUnseenCloseFriends, theme: presentation, activeLineWidth: 2.0, inactiveLineWidth: 1.0, counters: .init(totalCount: story.storyCount, unseenCount: active && hasUnseen ? story.storyCount : story.unseenCount))
    }
    
    public convenience init(stats: EngineChatList.StoryStats, presentation: PresentationTheme) {
        let hasUnseen = stats.unseenCount > 0
        self.init(hasUnseen: hasUnseen, hasUnseenCloseFriendsItems: stats.hasUnseenCloseFriends, theme: presentation, activeLineWidth: 2.0, inactiveLineWidth: 1.0, counters: .init(totalCount: stats.totalCount, unseenCount: stats.unseenCount))
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
        
        private final class Drawer: View {
            
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func update(component: AvatarStoryIndicatorComponent, progress: CGFloat, availableSize: CGSize) -> CGSize {
                self.availableSize = availableSize
                self.component = component
                self.progress = progress
                needsDisplay = true
                return availableSize
            }
            
            private var availableSize: NSSize = .zero
            private var component: AvatarStoryIndicatorComponent?
            private var progress: CGFloat = 1.0
            
            override func draw(_ layer: CALayer, in context: CGContext) {
                guard let component = self.component else {
                    return
                }
                
                
                let progress = self.progress
                
                let size = layer.frame.size
                
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
                    activeColors = [
                        NSColor(rgb: 0x7CD636),
                        NSColor(rgb: 0x26B470)
                    ]
                } else {
                    activeColors = [
                        NSColor(rgb: 0x34C76F),
                        NSColor(rgb: 0x3DA1FD)
                    ]
                }
                
                if component.theme.colors.isDark {
                    inactiveColors = [component.theme.colors.grayIcon.withAlphaComponent(1), component.theme.colors.grayIcon.withAlphaComponent(1)]
                } else {
                    inactiveColors = [NSColor(rgb: 0xD8D8E1), NSColor(rgb: 0xD8D8E1)]
                }
                
                
                var locations: [CGFloat] = [0.0, 1.0]
                
                context.setLineWidth(lineWidth)
                context.setLineCap(.round)
                let spacing: CGFloat = 3.0 * progress

                if let counters = component.counters, counters.totalCount > 1, spacing >= 2 {
                                        
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
                let ellipse = CGRect(origin: CGPoint(x: size.width * 0.5 - diameter * 0.5, y: size.height * 0.5 - diameter * 0.5), size: size).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5)
                context.addEllipse(in: ellipse)
                
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
            }
        }
    
        
        private let indicatorView: Drawer = Drawer(frame: .zero)
        
        private var component: AvatarStoryIndicatorComponent?
        private var availableSize: NSSize? = nil
        private var progress: CGFloat? = nil
        
        required init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.indicatorView)
            self.layer?.masksToBounds = false
            self.indicatorView.layer?.masksToBounds = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarStoryIndicatorComponent, availableSize: CGSize, progress: CGFloat = 1.0, transition: ContainedViewLayoutTransition)  {
            
            if component == self.component, availableSize == self.availableSize, progress == self.progress {
                return
            }
            self.component = component
            self.availableSize = availableSize
            self.progress = progress
            let maxOuterInset = component.activeLineWidth + component.activeLineWidth
            let imageDiameter = availableSize.width + 3.0 * 2.0

            let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: imageDiameter, height: imageDiameter))
            transition.updateFrame(view: self.indicatorView, frame: rect)
            
            _ = self.indicatorView.update(component: component, progress: progress, availableSize: availableSize)
        }
    }
    
}

