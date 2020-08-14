//
//  CallReceptionControl.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/08/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class CallReceptionControl: View {
    
    var reception: Int32 = 4 {
        didSet {
            self.needsDisplay = true
        }
    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        
        context.setFillColor(NSColor.white.cgColor)
        
        let width: CGFloat = 3.0
        let spacing: CGFloat = 2.0

        for i in 0 ..< 4 {
            let height = 4.0 + 2.0 * CGFloat(i)
            let rect = CGRect(x: bounds.minX + CGFloat(i) * (width + spacing), y: frame.height - height, width: width, height: height)
            
            if i >= reception {
                context.setAlpha(0.4)
            }
            let path = NSBezierPath(roundedRect: rect, xRadius: 0.5, yRadius: 0.5)
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }
    
}
