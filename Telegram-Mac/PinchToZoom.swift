//
//  PinchToZoom.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 15.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit

protocol PinchableView : NSView {
    func update(size: NSSize)
        
}

final class PinchToZoom {
    
    private weak var parentView: NSView?
    private var view: PinchableView?
    private var magnify: NSMagnificationGestureRecognizer!
    private var initialSize: NSSize = .zero
    private var initialOrigin: NSPoint {
        guard let parent = parentView, let window = parent.window else {
            return .zero
        }
        var point = window.contentView!.convert(NSZeroPoint, from: parent)
        point = point.offset(dx: 0, dy: -parent.frame.height)
        return point
    }
    private var currentMagnify: CGFloat = 0
    private var animation: DisplayLinkAnimator?
    private let disposable = MetaDisposable()
    init(parentView: NSView?) {
        self.parentView = parentView
        self.magnify = NSMagnificationGestureRecognizer(target: self, action: #selector(zoomIn(_:)))
    }
    
    func add(to view: PinchableView, size: NSSize) {
        self.initialSize = size
        if view.isEqual(to: view) {
            self.view?.removeGestureRecognizer(magnify)
            self.view = view
            view.addGestureRecognizer(magnify)
        }
    }
    
    func remove() {
        self.initialSize = .zero
        self.view?.removeGestureRecognizer(magnify)
    }
    
    deinit {
        view?.removeGestureRecognizer(magnify)
        disposable.dispose()
    }
    
    
    @objc func zoomIn(_ gesture: NSMagnificationGestureRecognizer) {
        
        guard let parentView = parentView, let view = self.view, let window = parentView.window as? Window else {
            return
        }
        
        if view.visibleRect == .zero {
            return
        }
        
        let maxMagnification: CGFloat = 2

        self.currentMagnify = min(max(1, 1 + gesture.magnification), maxMagnification)

        disposable.set(nil)
        
        let updateMagnify:(CGFloat)->Void = { [weak self, weak view] magnifyValue in
            guard let `self` = self, let view = view else {
                return
            }
            let updatedSize = NSMakeSize(round(self.initialSize.width * magnifyValue), round(self.initialSize.height * magnifyValue))
                        
            let lastPoint = window.contentView!.focus(NSMakeSize(self.initialSize.width * maxMagnification, self.initialSize.height * maxMagnification)).origin
            
            let x = lastPoint.x - self.initialOrigin.x
            let y = lastPoint.y - self.initialOrigin.y
            
            let coef = min((magnifyValue - 1), 1)
            let bestPoint = NSMakePoint(round(self.initialOrigin.x + x * coef), round(self.initialOrigin.y + y * coef))
            
            view.frame = CGRect(origin: bestPoint, size: updatedSize)
            
          
            self.currentMagnify = magnifyValue
        }
        
        self.animation = nil
        
        let returnView:(Bool)->Void = { [weak self, weak view] animated in
            guard let strongSelf = self else {
                return
            }
            
            view?.update(size: strongSelf.initialSize)

            
            strongSelf.animation = DisplayLinkAnimator(duration: 0.2, from: strongSelf.currentMagnify, to: 1, update: { current in
                updateMagnify(current)
            }, completion: { [weak view] in
                if let view = view {
                    view.setFrameOrigin(.zero)
                    strongSelf.parentView?.addSubview(view)
                }
            })
        }
        
        
        switch gesture.state {
        case .began:
            var point = window.contentView!.convert(NSZeroPoint, from: view)
            point = point.offset(dx: 0, dy: -view.frame.height)
            view.setFrameOrigin(point)
            window.contentView?.addSubview(view)
            
            let updatedSize = NSMakeSize(round(self.initialSize.width * maxMagnification), round(self.initialSize.height * maxMagnification))
            view.update(size: updatedSize)
        case .possible:
            break
        case .changed:
            let magnifyValue = min(max(1, 1 + gesture.magnification), maxMagnification)
            updateMagnify(magnifyValue)
        case .ended:
            returnView(true)
        case .cancelled:
            returnView(true)
        case .failed:
            returnView(true)
        @unknown default:
            break
        }
    }

}
