//
//  GalleryControls.swift
//  Telegram-Mac
//
//  Created by keepcoder on 07/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac

private let prevImage = #imageLiteral(resourceName: "Icon_GalleryLeft").precomposed()
private let nextImage = #imageLiteral(resourceName: "Icon_GalleryRight").precomposed()
private let moreImage = #imageLiteral(resourceName: "Icon_GalleryMore").precomposed()
private let dismissImage = #imageLiteral(resourceName: "Icon_GalleryDismiss").precomposed()





class GalleryControls: Node {
    
    let index:Promise<(Int,Int)> = Promise()
    private let interactions:GalleryInteractions
    private var thumbsView: GalleryThumbsControlView?
    fileprivate let counter:TitleButton = TitleButton()
    override var backgroundColor: NSColor? {
        return .blackTransparent
    }
    
    init(_ view: View? = nil, interactions:GalleryInteractions) {
        self.interactions = interactions
        super.init(view)
        view?.layer?.opacity = 0.0
        
        interactions.showThumbsControl = { [weak self] view, animated in
            view.change(opacity: 1.0, animated: animated)
            self?.view?.addSubview(view)
            view.center()
            self?.counter.change(opacity: 0.0)
            
        }
        interactions.hideThumbsControl = { [weak self] view, animated in
            view.change(opacity: 0, animated: animated, completion: { [weak view] completed in
                if completed {
                    view?.removeFromSuperview()
                }
            })
            self?.counter.change(opacity: 1.0)
        }
    }
    
    func animateIn() -> Void {
        self.setNeedDisplay()
        if let view = view {
            
            view.centerX(y: 10.0)
            view.layer?.opacity = 1.0
            view.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            view.layer?.animatePosition(from: NSMakePoint(view.frame.minX, -view.frame.height), to: NSMakePoint(view.frame.minX, 10), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
    }
    
    func animateOut() -> Void {
        self.setNeedDisplay()
        
        if let view = view {
            
            
            view.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
            view.layer?.animatePosition(from: view.frame.origin, to: NSMakePoint(view.frame.minX, -view.frame.height), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion:false)
        }
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.round(layer.frame.size,.cornerRadius)
        super.draw(layer, in: ctx)
    }
    

    
}

class GalleryGeneralControls : GalleryControls {
    
    private let previous:ImageButton = ImageButton()
    private let next:ImageButton = ImageButton()
    private let more:ImageButton = ImageButton()
    private let dismiss:ImageButton = ImageButton()
    
    
    
    private let disposable:MetaDisposable = MetaDisposable()
    
    override var backgroundColor: NSColor? {
        return NSColor(0x000000, 0.95)
    }
    
    override init(_ view: View? = nil, interactions:GalleryInteractions) {
        
        
        super.init(view, interactions: interactions)
        
        counter.style = galleryButtonStyle
        previous.style = galleryButtonStyle
        next.style = galleryButtonStyle
        more.style = galleryButtonStyle
        dismiss.style = galleryButtonStyle
        
        previous.set(image: prevImage, for: .Normal)
        next.set(image: nextImage, for: .Normal)
        more.set(image: moreImage, for: .Normal)
        dismiss.set(image: dismissImage, for: .Normal)
        
        previous.set(handler: {_ in _ = interactions.previous()}, for: .Click)
        next.set(handler: {_ in _ = interactions.next()}, for: .Click)
        more.set(handler: { control in _ = interactions.showActions(control)}, for: .Click)
        dismiss.set(handler: {_ in _ = interactions.dismiss()}, for: .Click)
        
        if let view = view {
            counter.set(text: "1 of 5", for: .Normal)
            _ = counter.sizeToFit(NSZeroSize, NSMakeSize(190, view.frame.height), thatFit: true)
            counter.center(view)
            
            let bwidth = (view.frame.width - counter.frame.width) / 4.0
            
            previous.frame = NSMakeRect(0, 0, bwidth, view.frame.height)
            next.frame = NSMakeRect(previous.frame.maxX, 0, bwidth, view.frame.height)
            more.frame = NSMakeRect(counter.frame.maxX, 0, bwidth, view.frame.height)
            dismiss.frame = NSMakeRect(more.frame.maxX, 0, bwidth, view.frame.height)
            
            view.addSubview(previous)
            view.addSubview(next)
            view.addSubview(counter)
            view.addSubview(more)
            view.addSubview(dismiss)
        }
        
        disposable.set(index.get().start(next: {[weak self] (current, total) in
            guard let `self` = self else {return}
            self.counter.set(text: tr(L10n.galleryCounter(current, total)), for: .Normal)
            if let view = self.view {
                _ = self.counter.sizeToFit(NSZeroSize, NSMakeSize(190, view.frame.height), thatFit: true)
            }
        }))
        
        
    }
    
    deinit {
        disposable.dispose()
    }
}


class GallerySecretControls : GalleryControls {
    private let progress:TimableProgressView = TimableProgressView(TimableProgressTheme(seconds: 20))
    private let duration: TitleButton = TitleButton()
    private let dismiss:ImageButton = ImageButton()
    private var timer:SwiftSignalKitMac.Timer? = nil
    override init(_ view: View?, interactions: GalleryInteractions) {
        super.init(view, interactions: interactions)
        if let view = view {
            duration.set(font: .bold(.header), for: .Normal)
            duration.set(color: .white, for: .Normal)
            duration.set(text: "20 sec", for: .Normal)
            dismiss.set(image: dismissImage, for: .Normal)
            _ = dismiss.sizeToFit()
            dismiss.set(handler: {_ in _ = interactions.dismiss()}, for: .Click)
            view.addSubview(progress)
            view.addSubview(duration)
            view.addSubview(dismiss)
            
        }
    }
    
    func update(with attribute: AutoremoveTimeoutMessageAttribute, outgoing: Bool) {
        timer?.invalidate()
        if !outgoing {
            progress.isHidden = false
            duration.isHidden = false
            dismiss.centerY(x: frame.width - dismiss.frame.width - 20)
            progress.centerY(x: 20)
            duration.center()
            if let countdownBeginTime = attribute.countdownBeginTime {
                
                let difference:()->TimeInterval = {
                    return TimeInterval((countdownBeginTime + attribute.timeout)) - (CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                }
                let start = difference() / Double(attribute.timeout) * 100.0
                progress.theme = TimableProgressTheme(seconds: difference(), start: start)
                
                let updateTitle:()->Void = { [weak self] in
                    self?.duration.set(text: String.stringForShortCallDurationSeconds(for: Int32(difference())), for: .Normal)
                    self?.duration.center()
                }
                updateTitle()
                timer = SwiftSignalKitMac.Timer(timeout: 1, repeat: true, completion: updateTitle, queue: Queue.mainQueue())
                timer?.start()
            } else {
                progress.theme = TimableProgressTheme(seconds: TimeInterval(attribute.timeout))
                duration.set(text: String.stringForShortCallDurationSeconds(for: attribute.timeout), for: .Normal)
                duration.center()
            }
            progress.progress = 0
            progress.startAnimation()
        } else {
            progress.isHidden = true
            duration.isHidden = true
            dismiss.center()
        }
        
    }
    
    override func animateIn() {
        super.animateIn()
    }
    
    override func animateOut() {
        super.animateOut()
        progress.stopAnimation()
    }
    
}
