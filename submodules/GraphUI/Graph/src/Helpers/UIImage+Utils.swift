//
//  NSImage+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/8/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore


extension NSImage {
    static let arrowRight = NSImage(named: "arrow_right")
    static let arrowLeft = NSImage(named: "arrow_left")

    public convenience init?(color: NSColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        
        
        let image = generateImage(size, contextGenerator: { size, ctx in
            ctx.clear(rect)
            ctx.setFillColor(color.cgColor)
            ctx.fill(rect)
        })
        
        guard let cgImage = image else { return nil }
        self.init(cgImage: cgImage, size: size)
    }
    
    
}
