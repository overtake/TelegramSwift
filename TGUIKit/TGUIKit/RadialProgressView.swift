//
//  RadialProgressLayer.swift
//  TGUIKit
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
    public init(fetch:@escaping()->Void,cancel:@escaping()->Void) {
        self.fetch = fetch
        self.cancel = cancel
    }
}


private class RadialProgressParameters: NSObject {
    let theme: RadialProgressTheme
    let diameter: CGFloat
    let state: RadialProgressState
    
    init(theme: RadialProgressTheme, diameter: CGFloat, state: RadialProgressState) {
        self.theme = theme
        self.diameter = diameter
        self.state = state
        
        super.init()
    }
}

public struct RadialProgressTheme {
    public let backgroundColor: NSColor
    public let foregroundColor: NSColor
    public let icon: CGImage?
    
    public init(backgroundColor:NSColor, foregroundColor:NSColor, icon:CGImage?) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.icon = icon
    }
}

public enum RadialProgressState {
    case None
    case Remote
    case Fetching(progress: Float)
    case Play
}


private class RadialProgressOverlayLayer: Layer {
    let theme: RadialProgressTheme
    
    var parameters:RadialProgressParameters {
        return RadialProgressParameters(theme: self.theme, diameter: NSWidth(self.frame), state: self.state)
    }
    
    var state: RadialProgressState = .None {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    init(theme: RadialProgressTheme) {
        self.theme = theme
        
        super.init()
        
        self.isOpaque = false
    }
    
    private override func draw(in ctx: CGContext) {
        ctx.setStrokeColor(parameters.theme.foregroundColor.cgColor)
        
        switch parameters.state {
        case .None, .Remote, .Play:
            break
        case let .Fetching(progress):
            let startAngle = -CGFloat(M_PI_2)
            let endAngle = 2.0 * (CGFloat(M_PI)) * CGFloat(progress) - CGFloat(M_PI_2)
            
            let pathDiameter = parameters.diameter - 2.25 - 2.5 * 2.0
            
            ctx.addArc(center: NSMakePoint(parameters.diameter / 2.0, parameters.diameter / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            
            ctx.setLineWidth(2.25);
            ctx.setLineCap(.round);
            ctx.strokePath()
            
        }
    }
    
    override func layerMoved(to superlayer: CALayer?) {
        
        super.layerMoved(to: superlayer)
        
        if let superlayer = superlayer {
            let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            basicAnimation.duration = 2.0
            basicAnimation.fromValue = NSNumber(value: Float(0.0))
            basicAnimation.toValue = NSNumber(value: Float(M_PI * 2.0))
            basicAnimation.repeatCount = Float.infinity
            basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
            self.add(basicAnimation, forKey: "progressRotation")
        } else {
            self.removeAllAnimations()
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
                set(handler: { [weak self] in
                    if let strongSelf = self {
                        switch (strongSelf.state) {
                        case .Fetching(progress: _):
                            fetchControls.cancel()
                        default :
                            fetchControls.fetch()
                        }
                    }   
                }, for: .Click)
            }
        }
    }
    
    private let theme:RadialProgressTheme
    private let overlay: RadialProgressOverlayLayer
    private var parameters:RadialProgressParameters {
        return RadialProgressParameters(theme: self.theme, diameter: NSWidth(self.frame), state: self.state)
    }
    
    public var state: RadialProgressState = .None {
        didSet {
            self.overlay.state = self.state
            if case .Fetching = self.state {
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
            }
        }
    }
    
    public override func viewDidMoveToSuperview() {
        if self.superview == nil {
            self.state = .None
        }
    }
    
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override public var frame: CGRect {
        get {
            return super.frame
        } set(value) {
            let redraw = value.size != self.frame.size
            super.frame = value
            
            if redraw {
                self.overlay.frame = CGRect(origin: CGPoint(), size: value.size)
                self.setNeedsDisplay()
                self.overlay.setNeedsDisplay()
            }
        }
    }
    
    public init(theme: RadialProgressTheme = RadialProgressTheme(backgroundColor: TGColor.blackTransparent, foregroundColor: TGColor.white, icon: nil)) {
        self.theme = theme
        self.overlay = RadialProgressOverlayLayer(theme: theme)
        super.init()
        
        self.frame = NSMakeRect(0, 0, 40, 40)
    
    }
    
    
    public override func draw(_ layer: CALayer, in context: CGContext) {
        context.setFillColor(parameters.theme.backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: parameters.diameter, height: parameters.diameter)))
        
        switch parameters.state {
        case .None:
            break
        case .Fetching:
            context.setStrokeColor(parameters.theme.foregroundColor.cgColor)
            context.setLineWidth(2.0)
            context.setLineCap(.round)
            
            let crossSize: CGFloat = 14.0
            context.move(to: CGPoint(x: parameters.diameter / 2.0 - crossSize / 2.0, y: parameters.diameter / 2.0 - crossSize / 2.0))
            context.addLine(to: CGPoint(x: parameters.diameter / 2.0 + crossSize / 2.0, y: parameters.diameter / 2.0 + crossSize / 2.0))
            context.strokePath()
            context.move(to: CGPoint(x: parameters.diameter / 2.0 + crossSize / 2.0, y: parameters.diameter / 2.0 - crossSize / 2.0))
            context.addLine(to: CGPoint(x: parameters.diameter / 2.0 - crossSize / 2.0, y: parameters.diameter / 2.0 + crossSize / 2.0))
            context.strokePath()
        case .Remote:
            context.setStrokeColor(parameters.theme.foregroundColor.cgColor)
            context.setLineWidth(2.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let arrowHeadSize: CGFloat = 15.0
            let arrowLength: CGFloat = 18.0
            let arrowHeadOffset: CGFloat = 1.0
            
            context.move(to: CGPoint(x: parameters.diameter / 2.0, y: parameters.diameter / 2.0 - arrowLength / 2.0 + arrowHeadOffset))
            context.addLine(to: CGPoint(x: parameters.diameter / 2.0, y: parameters.diameter / 2.0 + arrowLength / 2.0 - 1.0 + arrowHeadOffset))
            context.strokePath()
            
            context.move(to: CGPoint(x: parameters.diameter / 2.0 - arrowHeadSize / 2.0, y: parameters.diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
            context.addLine(to: CGPoint(x: parameters.diameter / 2.0, y: parameters.diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
            context.addLine(to: CGPoint(x: parameters.diameter / 2.0 + arrowHeadSize / 2.0, y: parameters.diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
            context.strokePath()
        case .Play:
            if let icon = parameters.theme.icon {
                
                context.draw(icon, in: NSMakeRect(floor((parameters.diameter - CGFloat(icon.width)) / 2.0), floor((parameters.diameter - CGFloat(icon.height)) / 2.0), CGFloat(icon.width), CGFloat(icon.height)))
            }
        }

    }
    
 
}
