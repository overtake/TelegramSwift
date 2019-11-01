//
//  RadialProgressLayer.swift
//  TGUIKit
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit

private func progressInteractiveThumb(backgroundColor: NSColor, foregroundColor: NSColor) -> CGImage {
    
    let context = DrawingContext(size: NSMakeSize(40, 40), scale: 1.0, clear: true)
    
    context.withContext { (ctx) in
        
        ctx.round(context.size, context.size.height/2.0)
        ctx.setFillColor(backgroundColor.cgColor)
        
        let image = #imageLiteral(resourceName: "Icon_MessageFile").precomposed(foregroundColor)
        
        ctx.fill(NSMakeRect(0, 0, context.size.width, context.size.height))
        ctx.draw(image, in: NSMakeRect(floorToScreenPixels(System.backingScale, (context.size.width - image.backingSize.width) / 2.0), floorToScreenPixels(System.backingScale, (context.size.height - image.backingSize.height) / 2.0), image.backingSize.width, image.backingSize.height))
        
    }
    
    return context.generateImage()!
    
}

public struct FetchControls {
    public let fetch: () -> Void
    public init(fetch:@escaping()->Void) {
        self.fetch = fetch
    }
}


private class RadialProgressParameters: NSObject {
    let theme: RadialProgressTheme
    let diameter: CGFloat
    let twist: Bool
    let state: RadialProgressState
    let clockwise: Bool
    init(theme: RadialProgressTheme, diameter: CGFloat, state: RadialProgressState, twist: Bool = true) {
        self.theme = theme
        self.diameter = diameter
        self.state = state
        self.twist = twist
        self.clockwise = theme.clockwise
        super.init()
    }
}

public struct RadialProgressTheme : Equatable {
    public let backgroundColor: NSColor
    public let foregroundColor: NSColor
    public let icon: CGImage?
    public let cancelFetchingIcon: CGImage?
    public let iconInset:NSEdgeInsets
    public let diameter:CGFloat?
    public let lineWidth: CGFloat
    public let clockwise: Bool
    public init(backgroundColor:NSColor, foregroundColor:NSColor, icon:CGImage? = nil, cancelFetchingIcon: CGImage? = nil, iconInset:NSEdgeInsets = NSEdgeInsets(), diameter: CGFloat? = nil, lineWidth: CGFloat = 2, clockwise: Bool = true) {
        self.iconInset = iconInset
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.icon = icon
        self.cancelFetchingIcon = cancelFetchingIcon
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.clockwise = clockwise
    }
}

public func ==(lhs:RadialProgressTheme, rhs:RadialProgressTheme) -> Bool {
    return lhs.backgroundColor == rhs.backgroundColor && lhs.foregroundColor == rhs.foregroundColor && ((lhs.icon == nil) == (rhs.icon == nil))
}

public enum RadialProgressState: Equatable {
    case None
    case Remote
    case Fetching(progress: Float, force: Bool)
    case ImpossibleFetching(progress: Float, force: Bool)
    case Play
    case Icon(image:CGImage, mode:CGBlendMode)
    case Success
}

public func ==(lhs:RadialProgressState, rhs:RadialProgressState) -> Bool {
    switch lhs {
    case .None:
        if case .None = rhs {
            return true
        } else {
            return false
        }
    case .Remote:
        if case .Remote = rhs {
            return true
        } else {
            return false
        }
    case .Success:
        if case .Success = rhs {
            return true
        } else {
            return false
        }
    case .Play:
        if case .Play = rhs {
            return true
        } else {
            return false
        }
    case let .Fetching(lhsProgress):
        if case let .Fetching(rhsProgress) = rhs, lhsProgress == rhsProgress {
            return true
        } else {
            return false
        }
    case let .ImpossibleFetching(lhsProgress):
            if case let .ImpossibleFetching(rhsProgress) = rhs, lhsProgress == rhsProgress {
                return true
            } else {
                return false
        }
    case .Icon:
        if case .Icon = rhs {
            return true
        } else {
            return false
        }
    }
}


private class RadialProgressOverlayLayer: CALayer {
    var theme: RadialProgressTheme
    let twist: Bool
    private var timer: SwiftSignalKit.Timer?
    private var _progress: Float = 0
    private var progress: Float = 0
    var parameters:RadialProgressParameters {
        return RadialProgressParameters(theme: self.theme, diameter: theme.diameter ?? frame.width, state: self.state, twist: twist)
    }

    
    var state: RadialProgressState = .None {
        didSet {
            switch state {
            case .None, .Play, .Remote, .Icon, .Success:
                self.progress = 0
                self._progress = 0
                 mayAnimate(false)
            case let .Fetching(progress, f), let  .ImpossibleFetching(progress, f):
                self.progress = twist ? max(progress, 0.05) : progress
                if f {
                    _progress = progress
                }
                mayAnimate(true)
            }
            let fps: Float = 60
            let difference = progress - _progress
            let tick: Float = Float(difference / (fps * 0.2))
            
            let clockwise = theme.clockwise
            
            if (clockwise && difference > 0) || (!clockwise && difference != 0)  {
                timer = SwiftSignalKit.Timer(timeout: TimeInterval(1 / fps), repeat: true, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf._progress += tick
                        strongSelf.setNeedsDisplay()
                        if strongSelf._progress == strongSelf.progress || strongSelf._progress < 0 || (strongSelf._progress >= 1 && !clockwise) || (strongSelf._progress > strongSelf.progress && clockwise) {
                            strongSelf.stopAnimation()
                        }
                    }
                    }, queue: Queue.mainQueue())
                timer?.start()
            } else {
                stopAnimation()
                _progress = progress
            }
           
            self.setNeedsDisplay()
        }
    }
    
    func stopAnimation() {
        timer?.invalidate()
        timer = nil
        self.setNeedsDisplay()
    }
    
    init(theme: RadialProgressTheme, twist: Bool) {
        self.theme = theme
        self.twist = twist
        super.init()
        
    }
    
    
    override func removeAllAnimations() {
        super.removeAllAnimations()
    }
    
    override init(layer: Any) {
        let layer = layer as! RadialProgressOverlayLayer
        self.theme = layer.theme
        self.twist = layer.twist
        super.init(layer: layer)
    }
    
    fileprivate override func draw(in ctx: CGContext) {
        ctx.setStrokeColor(theme.foregroundColor.cgColor)
        let startAngle = 2.0 * (CGFloat.pi) * CGFloat(_progress) - CGFloat.pi / 2
        let endAngle = -(CGFloat.pi / 2)
        
        let pathDiameter = !twist ? parameters.diameter - parameters.theme.lineWidth : parameters.diameter - parameters.theme.lineWidth - parameters.theme.lineWidth * parameters.theme.lineWidth
        ctx.addArc(center: NSMakePoint(parameters.diameter / 2.0, floorToScreenPixels(System.backingScale, parameters.diameter / 2.0)), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: parameters.clockwise)
        
        ctx.setLineWidth(parameters.theme.lineWidth);
        ctx.setLineCap(.round);
        ctx.strokePath()
    }
    
    
    fileprivate func mayAnimate(_ animate: Bool) {
        
        
        if animate, parameters.twist {
            let fromValue: Float = 0
            
            if animation(forKey: "progressRotation") != nil {
                return
            }
            removeAllAnimations()
            CATransaction.begin()
            
            let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            basicAnimation.duration = 2.0
            basicAnimation.fromValue = NSNumber(value: fromValue)
            basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
            basicAnimation.repeatCount = .infinity
            basicAnimation.isRemovedOnCompletion = false

            basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
            self.add(basicAnimation, forKey: "progressRotation")
            CATransaction.commit()
        } else {
            removeAllAnimations()
        }
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


public class RadialProgressView: Control {
    
    
    public var fetchControls:FetchControls? {
        didSet {
            self.removeAllHandlers()
            if let fetchControls = fetchControls {
                set(handler: { _ in
                    fetchControls.fetch()
                }, for: .Click)
            }
        }
    }
    
    public var theme:RadialProgressTheme {
        didSet {
            overlay.theme = theme
            self.setNeedsDisplay()
        }
    }
    private let overlay: RadialProgressOverlayLayer
    private var parameters:RadialProgressParameters {
        return RadialProgressParameters(theme: self.theme, diameter: NSWidth(self.frame), state: self.state)
    }
    
    
    
    
    public var state: RadialProgressState = .None {
        didSet {
            self.overlay.state = self.state
            if case .Fetching = state {
                if self.overlay.superlayer == nil {
                    self.layer?.addSublayer(self.overlay)
                }
            } else if case .ImpossibleFetching = state {
                if self.overlay.superlayer == nil {
                    self.layer?.addSublayer(self.overlay)
                }
            } else {
                if self.overlay.superlayer != nil {
                    self.overlay.removeFromSuperlayer()
                }
            }
            switch oldValue {
            case .Fetching:
                switch self.state {
                case .Fetching:
                    break
                default:
                    self.setNeedsDisplay()
                }
            case .ImpossibleFetching:
                switch self.state {
                case .ImpossibleFetching:
                    break
                default:
                    self.setNeedsDisplay()
                }
            case .Remote:
                switch self.state {
                case .Remote:
                    break
                default:
                    self.setNeedsDisplay()
                }
            case .None:
                switch self.state {
                case .None:
                    break
                default:
                    self.setNeedsDisplay()
                }
            case .Play:
                switch self.state {
                case .Play:
                    break
                default:
                    self.setNeedsDisplay()
                }
            case .Success:
                switch self.state {
                case .Success:
                    break
                default:
                    self.setNeedsDisplay()
                }
            case .Icon:
                switch self.state {
                case .Icon:
                    self.setNeedsDisplay()
                default:
                    self.setNeedsDisplay()
                }
            }
            
        }
    }
    
    public override func viewDidMoveToSuperview() {
        overlay.mayAnimate(superview != nil)
    }
    
    
    
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override public var frame: CGRect {
        get {
            return super.frame
        } set (value) {
            let redraw = value.size != self.frame.size
            super.frame = value
            
            if redraw {
                self.overlay.frame = CGRect(origin: CGPoint(), size: value.size)
                self.setNeedsDisplay()
                self.overlay.setNeedsDisplay()
            }
        }
    }
    
    public init(theme: RadialProgressTheme = RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: nil), twist: Bool = true, size: NSSize = NSMakeSize(40, 40)) {
        self.theme = theme
        self.overlay = RadialProgressOverlayLayer(theme: theme, twist: twist)
        super.init()
        self.overlay.contentsScale = backingScaleFactor
        self.frame = NSMakeRect(0, 0, size.width, size.height)
    
    }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
    //    overlay.mayAnimate(superview != nil && window != nil)
    }
    
    
    
    
    public override func draw(_ layer: CALayer, in context: CGContext) {
        context.setFillColor(parameters.theme.backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: parameters.diameter, height: parameters.diameter)))
        
        switch parameters.state {
        case .None:
            break
        case .Success:
            let diameter = bounds.size.width
            
            let progress: CGFloat = 1.0
            
            var pathLineWidth: CGFloat = 2.0
            var pathDiameter: CGFloat = diameter - pathLineWidth
            
            if (abs(diameter - 37.0) < 0.1) {
                pathLineWidth = 2.5
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5
            } else if (abs(diameter - 32.0) < 0.1) {
                pathLineWidth = 2.0
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5
            } else {
                pathLineWidth = 2.5
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5
            }
            
            let center = CGPoint(x: diameter / 2.0, y: diameter / 2.0)
            
            context.setStrokeColor(parameters.theme.foregroundColor.cgColor)
            context.setLineWidth(pathLineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setMiterLimit(10.0)
            
            let firstSegment: CGFloat = max(0.0, min(1.0, progress * 3.0))
            
            var s = CGPoint(x: center.x - 10.0, y: center.y + 1.0)
            var p1 = CGPoint(x: 7.0, y: 7.0)
            var p2 = CGPoint(x: 15.0, y: -16.0)
            
            if diameter < 36.0 {
                s = CGPoint(x: center.x - 7.0, y: center.y + 1.0)
                p1 = CGPoint(x: 4.5, y: 4.5)
                p2 = CGPoint(x: 10.0, y: -11.0)
            }
            
            if !firstSegment.isZero {
                if firstSegment < 1.0 {
                    context.move(to: CGPoint(x: s.x + p1.x * firstSegment, y: s.y + p1.y * firstSegment))
                    context.addLine(to: s)
                } else {
                    let secondSegment = (progress - 0.33) * 1.5
                    context.move(to: CGPoint(x: s.x + p1.x + p2.x * secondSegment, y: s.y + p1.y + p2.y * secondSegment))
                    context.addLine(to: CGPoint(x: s.x + p1.x, y: s.y + p1.y))
                    context.addLine(to: s)
                }
            }
            context.strokePath()
        case .Fetching:
            if let icon = parameters.theme.cancelFetchingIcon {
                var f = focus(icon.backingSize)
                f.origin.x += parameters.theme.iconInset.left
                f.origin.x -= parameters.theme.iconInset.right
                f.origin.y += parameters.theme.iconInset.top
                f.origin.y -= parameters.theme.iconInset.bottom
                context.draw(icon, in: f)
            } else {
                context.setStrokeColor(parameters.theme.foregroundColor.cgColor)
                context.setLineWidth(2.0)
                context.setLineCap(.round)
                
                
                let crossSize: CGFloat = parameters.diameter < 40 ? 9 : 14.0
                
                context.move(to: CGPoint(x: parameters.diameter / 2.0 - crossSize / 2.0, y: parameters.diameter / 2.0 - crossSize / 2.0))
                context.addLine(to: CGPoint(x: parameters.diameter / 2.0 + crossSize / 2.0, y: parameters.diameter / 2.0 + crossSize / 2.0))
                context.strokePath()
                context.move(to: CGPoint(x: parameters.diameter / 2.0 + crossSize / 2.0, y: parameters.diameter / 2.0 - crossSize / 2.0))
                context.addLine(to: CGPoint(x: parameters.diameter / 2.0 - crossSize / 2.0, y: parameters.diameter / 2.0 + crossSize / 2.0))
                context.strokePath()
                

            }
           
        case .Remote:
            let color = parameters.theme.foregroundColor
            let diameter = layer.frame.height
            
            context.setStrokeColor(color.cgColor)
            var lineWidth: CGFloat = 2.0
            if diameter < 24.0 {
                lineWidth = 1.3
            }
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let factor = diameter / 50.0
            
            let arrowHeadSize: CGFloat = 15.0 * factor
            let arrowLength: CGFloat = 18.0 * factor
            let arrowHeadOffset: CGFloat = 1.0 * factor
            
            context.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 - arrowLength / 2.0 + arrowHeadOffset))
            context.addLine(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - 1.0 + arrowHeadOffset))
            context.strokePath()
            
            context.move(to: CGPoint(x: diameter / 2.0 - arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
            context.addLine(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
            context.addLine(to: CGPoint(x: diameter / 2.0 + arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
            context.strokePath()
        case .Play:
            let color = parameters.theme.foregroundColor
            let diameter = layer.frame.height
            context.setFillColor(color.cgColor)
            
            let factor = diameter / 50.0
            
            let size = CGSize(width: 15.0, height: 18.0)
            context.translateBy(x: (diameter - size.width) / 2.0 + 1.5, y: (diameter - size.height) / 2.0)
            if (diameter < 40.0) {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: factor, y: factor)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            }
            let _ = try? drawSvgPath(context, path: "M1.71891969,0.209353049 C0.769586558,-0.350676705 0,0.0908839327 0,1.18800046 L0,16.8564753 C0,17.9569971 0.750549162,18.357187 1.67393713,17.7519379 L14.1073836,9.60224049 C15.0318735,8.99626906 15.0094718,8.04970371 14.062401,7.49100858 L1.71891969,0.209353049 ")
            context.fillPath()
            if (diameter < 40.0) {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            }
            context.translateBy(x: -(diameter - size.width) / 2.0 - 1.5, y: -(diameter - size.height) / 2.0)
        case .ImpossibleFetching:
            break
        case let .Icon(image: icon, mode:blendMode):
            var f = focus(icon.backingSize)
            f.origin.x += parameters.theme.iconInset.left
            f.origin.x -= parameters.theme.iconInset.right
            f.origin.y += parameters.theme.iconInset.top
            f.origin.y -= parameters.theme.iconInset.bottom
            context.setBlendMode(blendMode)
            context.draw(icon, in: f)
        }

    }
    
    public override func copy() -> Any {
        let view = NSView()
        view.wantsLayer = true
        view.frame = self.frame
        view.layer?.contents = progressInteractiveThumb(backgroundColor: parameters.theme.backgroundColor, foregroundColor: parameters.theme.foregroundColor)
        return view

    }
    
    public override func apply(state: ControlState) {
        
    }
 
}
