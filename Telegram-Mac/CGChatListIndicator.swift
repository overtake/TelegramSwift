//
//  CGChatListIndicator.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit

final class GCChatListIndicator : View {

    var color: NSColor = NSColor.white {
        didSet {
            needsDisplay = true
        }
    }

    init(color: NSColor) {
        self.color = color
        super.init(frame: NSMakeRect(0, 0, 10, 20))
        self.layer = CAShapeLayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    private var animator: DisplayLinkAnimator?

    private let keyDispose = MetaDisposable()

    deinit {
        keyDispose.dispose()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            stopAnimation()
            keyDispose.set(nil)
        } else {
            startAnimation()
            if let window = window as? Window {
                keyDispose.set(window.visibility.start(next: { [weak self] value in
                    if value {
                        self?.startAnimation()
                    } else {
                        self?.stopAnimation()
                    }
                }))
            }
        }
    }
        

    func startAnimation() {
        self.animator = DisplayLinkAnimator(duration: 0.4, from: innerProgress, to: 1, update: { [weak self] value in
            self?.innerProgress = value
        }, completion: { [weak self] in
            self?.startAnimation()
        })
        
    }
    func stopAnimation() {
        self.animator = nil
    }

    private var progressStage: Int = 0
    private var innerProgress: CGFloat = 0 {
        didSet {
            if (innerProgress >= 1.0) {
                progressStage += 1
                if (progressStage >= 8) {
                    progressStage = 0
                }
                innerProgress = 0
            }
            if visibleRect != .zero {
                (self.layer as? CAShapeLayer)?.fillColor = color.cgColor
                (self.layer as? CAShapeLayer)?.path = genPath()
            }
        }
    }
    
    private func genPath() -> CGPath {
        let rect = self.bounds

        var size1: CGFloat = 0;
        var size2: CGFloat = 0;
        if (progressStage == 0) {
            size1 = 2 + 8 * innerProgress
            size2 = 6 - 4 * innerProgress
        } else if (progressStage == 1) {
            size1 = 10 - 8 * innerProgress
            size2 = 2 + 8 * innerProgress
        } else if (progressStage == 2) {
            size1 = 2 + 4 * innerProgress
            size2 = 10 - 8 * innerProgress
        } else if (progressStage == 3) {
            size1 = 6 - 4 * innerProgress
            size2 = 2 + 4 * innerProgress
        } else if (progressStage == 4) {
            size1 = 2 + 8 * innerProgress
            size2 = 6 - 4 * innerProgress
        } else if (progressStage == 5) {
            size1 = 10 - 8 * innerProgress
            size2 = 2 + 8 * innerProgress
        } else if (progressStage == 6) {
            size1 = 2 + 8 * innerProgress
            size2 = 10 - 8 * innerProgress
        } else {
            size1 = 10 - 8 * innerProgress
            size2 = 2 + 4 * innerProgress
        }


        let p1 = CGMutablePath()
        
        p1.addRoundedRect(in: .init(origin: NSMakePoint(0, rect.midY - size2 / 2), size: NSMakeSize(2, size2)), cornerWidth: 1, cornerHeight: 1)
        p1.addRoundedRect(in: .init(origin: NSMakePoint(4, rect.midY - size1 / 2), size: NSMakeSize(2, size1)), cornerWidth: 1, cornerHeight: 1)
        p1.addRoundedRect(in: .init(origin: NSMakePoint(8, rect.midY - size2 / 2), size: NSMakeSize(2, size2)), cornerWidth: 1, cornerHeight: 1)
        
        return p1
    }
    
//    override func draw(_ layer: CALayer, in ctx: CGContext) {
//        super.draw(layer, in: ctx)
//
//        let rect = self.bounds
//
//        var size1: CGFloat = 0;
//        var size2: CGFloat = 0;
//        if (progressStage == 0) {
//            size1 = 2 + 8 * innerProgress
//            size2 = 6 - 4 * innerProgress
//        } else if (progressStage == 1) {
//            size1 = 10 - 8 * innerProgress
//            size2 = 2 + 8 * innerProgress
//        } else if (progressStage == 2) {
//            size1 = 2 + 4 * innerProgress
//            size2 = 10 - 8 * innerProgress
//        } else if (progressStage == 3) {
//            size1 = 6 - 4 * innerProgress
//            size2 = 2 + 4 * innerProgress
//        } else if (progressStage == 4) {
//            size1 = 2 + 8 * innerProgress
//            size2 = 6 - 4 * innerProgress
//        } else if (progressStage == 5) {
//            size1 = 10 - 8 * innerProgress
//            size2 = 2 + 8 * innerProgress
//        } else if (progressStage == 6) {
//            size1 = 2 + 8 * innerProgress
//            size2 = 10 - 8 * innerProgress
//        } else {
//            size1 = 10 - 8 * innerProgress
//            size2 = 2 + 4 * innerProgress
//        }
//
//        ctx.setFillColor(color.cgColor)
//
//        let p1 = CGMutablePath()
//        p1.addRoundedRect(in: .init(origin: NSMakePoint(0, rect.midY - size2 / 2), size: NSMakeSize(2, size2)), cornerWidth: 1, cornerHeight: 1)
//        p1.addRoundedRect(in: .init(origin: NSMakePoint(4, rect.midY - size1 / 2), size: NSMakeSize(2, size1)), cornerWidth: 1, cornerHeight: 1)
//        p1.addRoundedRect(in: .init(origin: NSMakePoint(8, rect.midY - size2 / 2), size: NSMakeSize(2, size2)), cornerWidth: 1, cornerHeight: 1)
//        ctx.addPath(p1)
//        ctx.fillPath()
//
//    }

}

