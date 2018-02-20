//
//  ChatBackgroundView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/01/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class ChatBackgroundView: View {
    private var backgroundView: ImageView?
    public var backgroundMode:TableBackgroundMode = .plain {
        didSet {
            switch backgroundMode {
            case let .background(image: image):
                if backgroundView == nil {
                    let frame = self.frame
                    let size = image.size.aspectFilled(frame.size)
                    backgroundView = ImageView(frame: NSMakeRect(0, 0, size.width, size.height))
                    self.addSubview(backgroundView!, positioned: .below, relativeTo: subviews.first)
                    backgroundView?.centerX(y: 0)
                }
                backgroundColor = .clear

                backgroundView?.layer?.contents = image
                backgroundView?.layer?.contentsScale = backingScaleFactor
            case let .color(color):
                backgroundView?.removeFromSuperview()
                backgroundView = nil
                backgroundColor = color
                needsDisplay = true
            default:
                backgroundView?.removeFromSuperview()
                backgroundView = nil
                backgroundColor = theme.colors.background
                needsDisplay = true
            }
            updateBackgroundColor()
        }
    }
    
    func updateBackgroundColor() {
        switch backgroundMode {
        case .background:
            backgroundColor = .clear
        case let .color(color):
            backgroundColor = color
        default:
            backgroundColor = theme.colors.background
        }
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateLayout()
    }
    
    private func updateLayout() {
        if let superview = superview {
            let frame = superview.frame
            
            switch backgroundMode {
            case let .background(image: image):
                let size = image.size.aspectFilled(frame.size)
                backgroundView?.setFrameSize(size)
                backgroundView?.centerX(y: self.frame.height - superview.frame.height)
                
            default:
                break
            }
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateLayout()
    }

    
}
