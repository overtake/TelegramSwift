//
//  ShimmerEffect.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.01.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit

final class ShimmerEffectForegroundView: View {
    private var currentBackgroundColor: NSColor?
    private var currentForegroundColor: NSColor?
    private var currentHorizontal: Bool?
    private let imageViewContainer: View = View()
    private let imageView: ImageView = ImageView()
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    public var isStatic: Bool = false
    private var disposable: Disposable?
    
    deinit {
        disposable?.dispose()
    }
    
    override init() {
        super.init()
        
        self.imageViewContainer.addSubview(self.imageView)
        self.addSubview(self.imageViewContainer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.imageViewContainer.addSubview(self.imageView)
        self.addSubview(self.imageViewContainer)
    }
    
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.isCurrentlyInHierarchy = window != nil
        self.updateAnimation()
    }
    
    
    func update(backgroundColor: NSColor, foregroundColor: NSColor, horizontal: Bool = false) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor), self.currentHorizontal == horizontal {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        self.currentHorizontal = horizontal
        
        let image: CGImage?
        if horizontal {
            image = generateImage(CGSize(width: 320.0, height: 16.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(backgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                
                context.clip(to: CGRect(origin: CGPoint(), size: size))
                
                let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
                let peakColor = foregroundColor.cgColor
                
                var locations: [CGFloat] = [0.0, 0.5, 1.0]
                let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
            })
        } else {
            image = generateImage(CGSize(width: 16.0, height: 320.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(backgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                
                context.clip(to: CGRect(origin: CGPoint(), size: size))
                
                let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
                let peakColor = foregroundColor.cgColor
                
                var locations: [CGFloat] = [0.0, 0.5, 1.0]
                let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
        }
        self.imageView.image = image
        self.updateAnimation()
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageView.layer?.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            } else {
                self.updateAnimation()
            }
        }
        
        if frameUpdated {
            self.imageViewContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil && self.currentHorizontal != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageView.layer?.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1, let horizontal = self.currentHorizontal, self.shouldBeAnimating else {
            return
        }
        let animation: CAAnimation
        let duration: Double = isStatic ? 0.7 : 1.5
        if horizontal {
            let gradientHeight: CGFloat = 320.0
            self.imageView.frame = CGRect(origin: CGPoint(x: -gradientHeight, y: 0.0), size: CGSize(width: gradientHeight, height: containerSize.height))
            animation = self.imageView.layer!.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.width + gradientHeight) as NSNumber, keyPath: "position.x", timingFunction: .easeOut, duration: duration, delay: 0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
            if !isStatic {
                animation.repeatCount = Float.infinity
                animation.beginTime = 1.0
            }
        } else {
            let gradientHeight: CGFloat = 250.0
            self.imageView.frame = CGRect(origin: CGPoint(x: 0.0, y: -gradientHeight), size: CGSize(width: containerSize.width, height: gradientHeight))
            animation = self.imageView.layer!.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.height + gradientHeight) as NSNumber, keyPath: "position.y", timingFunction: .easeOut, duration: duration, delay: 0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
            
            if !isStatic {
                animation.repeatCount = Float.infinity
                animation.beginTime = 1.0
            }
        }
        if isStatic {
            animation.delegate = CALayerAnimationDelegate(completion: { [weak self] completed in
                if completed {
                    self?.disposable = delaySignal(2 - duration).startStandalone(completed: {
                        self?.addImageAnimation()
                    })
                }
            })
        }
        
        self.disposable?.dispose()
        self.imageView.layer!.removeAnimation(forKey: "shimmer")
        self.imageView.layer!.add(animation, forKey: "shimmer")

    }
}

public final class ShimmerEffectView: View {
    public enum Shape: Equatable {
        case circle(CGRect)
        case roundedRectLine(startPoint: CGPoint, width: CGFloat, diameter: CGFloat)
        case roundedRect(rect: CGRect, cornerRadius: CGFloat)
        case rect(rect: CGRect)
    }
    
    private let backgroundView: View = View()
    private let effectView: ShimmerEffectForegroundView = ShimmerEffectForegroundView()
    private let foregroundView: ImageView = ImageView()
    
    private var currentShapes: [Shape] = []
    private var currentBackgroundColor: NSColor?
    private var currentForegroundColor: NSColor?
    private var currentShimmeringColor: NSColor?
    private var currentHorizontal: Bool?
    private var currentSize = CGSize()
    
    override public init() {
        
        super.init()
        
        self.addSubview(self.backgroundView)
        self.addSubview(self.effectView)
        self.addSubview(self.foregroundView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.effectView.updateAbsoluteRect(rect, within: containerSize)
    }
    
    public func update(backgroundColor: NSColor, foregroundColor: NSColor, shimmeringColor: NSColor, shapes: [Shape], horizontal: Bool = false, size: CGSize) {
        if self.currentShapes == shapes, let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor), let currentShimmeringColor = self.currentShimmeringColor, currentShimmeringColor.isEqual(shimmeringColor), horizontal == self.currentHorizontal, self.currentSize == size {
            return
        }
        
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        self.currentShimmeringColor = shimmeringColor
        self.currentShapes = shapes
        self.currentHorizontal = horizontal
        self.currentSize = size
        
        self.backgroundView.backgroundColor = foregroundColor
        
        self.effectView.update(backgroundColor: foregroundColor, foregroundColor: shimmeringColor, horizontal: horizontal)
        
        self.foregroundView.image = generateImage(size, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.setBlendMode(.copy)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.setFillColor(NSColor.clear.cgColor)
            for shape in shapes {
                switch shape {
                case let .circle(frame):
                    context.fillEllipse(in: frame)
                case let .roundedRectLine(startPoint, width, diameter):
                    context.fillEllipse(in: CGRect(origin: startPoint, size: CGSize(width: diameter, height: diameter)))
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: startPoint.x + width - diameter, y: startPoint.y), size: CGSize(width: diameter, height: diameter)))
                    context.fill(CGRect(origin: CGPoint(x: startPoint.x + diameter / 2.0, y: startPoint.y), size: CGSize(width: width - diameter, height: diameter)))
                case let .roundedRect(rect, radius):
                    let path = CGMutablePath()
                    path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
                    context.addPath(path)
                    context.fillPath()
                case let .rect(rect):
                    context.fill(rect)
                }
            }
        })
        
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.foregroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.effectView.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    public var isStatic: Bool = false {
        didSet {
            effectView.isStatic = isStatic
        }
    }
}
