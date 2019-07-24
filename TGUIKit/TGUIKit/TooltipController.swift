//
//  TooltipController.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 04/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

private final class TooltipCornerView : View {
    
    
//    override var isFlipped: Bool {
//        return false
//    }
//
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(.black)
        
        let width = bounds.width
        let height = bounds.height
        let radius: CGFloat = 3
        
//        ctx.rotate(by: 90 * (.pi / 180))

        
//        let triangleFrame = bounds
//
//        ctx.move(to: CGPoint(x: triangleFrame.minX, y: triangleFrame.midY))
//        ctx.addArc(tangent1End: CGPoint(x: triangleFrame.minX, y: triangleFrame.midY), tangent2End: CGPoint(x: triangleFrame.minX, y: triangleFrame.minY), radius: radius)
//        ctx.addArc(tangent1End: CGPoint(x: triangleFrame.minX, y: triangleFrame.minY), tangent2End: CGPoint(x: triangleFrame.maxX, y: triangleFrame.midY), radius: radius)
//        ctx.addArc(tangent1End: CGPoint(x: triangleFrame.maxX, y: triangleFrame.midY), tangent2End: CGPoint(x: triangleFrame.minX, y: triangleFrame.maxY), radius: radius)
//        ctx.addArc(tangent1End: CGPoint(x: triangleFrame.minX, y: triangleFrame.maxY), tangent2End: CGPoint(x: triangleFrame.minX, y: triangleFrame.midY), radius: radius)
//        ctx.closePath()
       

//
//        let point1 = CGPoint(x: -width / 2, y: height / 2)
//        let point2 = CGPoint(x: 0, y: -height / 2)
//        let point3 = CGPoint(x: width / 2, y: height / 2)
//
//     //   let path = CGMutablePath()
//        ctx.move(to: CGPoint(x: 0, y: height / 2))
//        ctx.addArc(tangent1End: point1, tangent2End: point2, radius: radius)
//        ctx.addArc(tangent1End: point2, tangent2End: point3, radius: radius)
//        ctx.addArc(tangent1End: point3, tangent2End: point1, radius: radius)
//        ctx.closePath()

      //  ctx.addPath(path)
        
        ctx.move(to: NSMakePoint(bounds.midX, bounds.maxY))
        ctx.addLine(to: NSMakePoint(bounds.minX, bounds.minY))
        ctx.addLine(to: NSMakePoint(bounds.maxX, bounds.minY))
        ctx.closePath()
        ctx.fillPath()
    }
    
}

private final class TooltipView: View {
    let textView = TextView()
    let cornerView = TooltipCornerView(frame: NSMakeRect(0, 0, 20, 10))
    var didRemoveFromWindow:(()->Void)?
    weak var view: NSView? {
        didSet {
            oldValue?.removeObserver(self, forKeyPath: "window")
            if let view = view {
                 view.addObserver(self, forKeyPath: "window", options: .new, context: nil)
            }
        }
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if self.view?.window == nil {
            self.didRemoveFromWindow?()
        }
    }
    
    var cornerX: CGFloat? = nil {
        didSet {
            needsLayout = true
        }
    }
    
    
    func move(corner cornerX: CGFloat, animated: Bool) {
        self.cornerX = cornerX
        cornerView.change(pos: NSMakePoint(max(min(cornerX - cornerView.frame.width / 2, frame.width - cornerView.frame.width - .cornerRadius), .cornerRadius), textView.frame.maxY), animated: animated)
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.backgroundColor = .black
        addSubview(textView)
        addSubview(cornerView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.layer?.cornerRadius = .cornerRadius
    }
    
    func update(text: String, maxWidth: CGFloat, animated: Bool) {
        let layout = TextViewLayout(.initialize(string: text, color: .white, font: .medium(.text)), alignment: .center, alwaysStaticItems: true)
        layout.measure(width: maxWidth)
        textView.change(size: NSMakeSize(layout.layoutSize.width + 20, layout.layoutSize.height + 10), animated: animated)
        textView.set(layout: layout)
        change(size: NSMakeSize(textView.frame.width, textView.frame.height + 15), animated: animated)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        textView.centerX(y: 0)
        if let cornerX = cornerX {
            cornerView.setFrameOrigin(max(min(cornerX - cornerView.frame.width / 2, frame.width - cornerView.frame.width - .cornerRadius), .cornerRadius), textView.frame.maxY)
        } else {
            cornerView.centerX(y: textView.frame.maxY)
        }
    }
    
    deinit {
        DispatchQueue.main.async {
            removeShownAnimation = false
        }
        view?.removeObserver(self, forKeyPath: "window")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TooltipController: ViewController {

  
    
}

private var removeShownAnimation:Bool = false


private let delayDisposable = MetaDisposable()
private var shouldRemoveTooltip: Bool = true
public func tooltip(for view: NSView, text: String, maxWidth: CGFloat = 350, autoCorner: Bool = true) -> Void {
    guard let window = view.window as? Window else { return }
    
    
    let tooltip: TooltipView
    let isExists: Bool
    if let exists = window.contentView?.subviews.first(where: { $0 is TooltipView }) as? TooltipView {
        tooltip = exists
        isExists = true
        shouldRemoveTooltip = false
    } else {
        tooltip = TooltipView(frame: NSZeroRect)
        isExists = false
        shouldRemoveTooltip = (NSEvent.pressedMouseButtons & (1 << 0)) == 0
    }
    
    tooltip.view = view
    

    window.contentView?.addSubview(tooltip)
    
    let location = window.mouseLocationOutsideOfEventStream
    
    
    tooltip.update(text: text, maxWidth: maxWidth, animated: isExists)
    
    let point = view.convert(NSZeroPoint, to: nil)
    tooltip.change(pos: NSMakePoint(min(max(point.x - (tooltip.frame.width - view.frame.width) / 2, 10), window.frame.width - tooltip.frame.width - 10), point.y), animated: isExists)
    
    
    if autoCorner {
        let point = tooltip.convert(NSMakePoint(view.frame.width / 2, 0), from: view)
        tooltip.move(corner: point.x, animated: isExists)
    } else {
        let mousePoint = tooltip.convert(location, from: nil)
        tooltip.move(corner: mousePoint.x, animated: isExists)
    }
    

    
    
    if !isExists && !removeShownAnimation {
        CATransaction.begin()
        tooltip.layer?.animateAlpha(from: 0.3, to: 1, duration: 0.2)
        tooltip.layer?.animatePosition(from: NSMakePoint(tooltip.frame.minX, tooltip.frame.minY - 5), to: tooltip.frame.origin)
        CATransaction.commit()
    }
    let removeTooltip:(Bool) -> Void = { [weak tooltip] animated in
        guard let tooltip = tooltip else { return }
        if animated {
            CATransaction.begin()
            tooltip.layer?.animatePosition(from: tooltip.frame.origin, to: NSMakePoint(tooltip.frame.minX, tooltip.frame.minY - 5), removeOnCompletion: false)
            //tooltip.change(pos: NSMakePoint(tooltip.frame.minX, tooltip.frame.minY - 5), animated: true)
            tooltip.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak tooltip] _ in
                if let tooltip = tooltip {
                    tooltip.removeFromSuperview()
                    window.removeAllHandlers(for: tooltip)
                }
            })
//            tooltip.change(opacity: 0, true, removeOnCompletion: false, duration: 0.2, completion: { [weak tooltip] _ in
//                if let tooltip = tooltip {
//                    tooltip.removeFromSuperview()
//                    window.removeAllHandlers(for: tooltip)
//                }
//            })
            CATransaction.commit()
        } else {
            removeShownAnimation = true
            tooltip.removeFromSuperview()
            window.removeAllHandlers(for: tooltip)
        }
    }
    
    tooltip.didRemoveFromWindow = {
        removeTooltip(true)
    }
    
    delayDisposable.set((Signal<Never, NoError>.complete() |> delay(3.0, queue: .mainQueue())).start(completed: {
        removeTooltip(true)
    }))
    

    window.set(mouseHandler: { _ -> KeyHandlerResult in
        DispatchQueue.main.async {
            if shouldRemoveTooltip {
                removeTooltip(true)
            }
            shouldRemoveTooltip = !isExists
        }
        return .rejected
    }, with: tooltip, for: .leftMouseUp, priority: .supreme)
    

    
    window.set(mouseHandler: { _ -> KeyHandlerResult in
        removeTooltip(false)
        return .rejected
    }, with: tooltip, for: .scrollWheel, priority: .supreme)
    
    
    window.set(handler: { () -> KeyHandlerResult in
        removeTooltip(false)
        return .rejected
    }, with: tooltip, for: .All, priority: .supreme)
}

public func removeAllTooltips(_ window: Window) {
    for subview in window.contentView!.subviews.reversed() {
        if subview is TooltipView {
            subview.removeFromSuperview()
        }
    }
}
