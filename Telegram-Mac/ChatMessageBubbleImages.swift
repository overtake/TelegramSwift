//
//  ChatMessageBubbleImages.swift
//  Telegram
//
//  Created by keepcoder on 04/12/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



enum MessageBubbleImageNeighbors {
    case none
    case top
    case bottom
    case both
}

func messageSingleBubbleLikeImage(fillColor: NSColor, strokeColor: NSColor) -> CGImage {
    let diameter: CGFloat = 36.0
    return generateImage(CGSize(width: 36.0, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let lineWidth: CGFloat = 0.5
        
        context.setFillColor(strokeColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: lineWidth, y: lineWidth), size: CGSize(width: size.width - lineWidth * 2.0, height: size.height - lineWidth * 2.0)))
    })!
}

func messageBubbleImage(incoming: Bool, fillColor: NSColor, strokeColor: NSColor, neighbors: MessageBubbleImageNeighbors) -> [CGImage] {
    
    let diameter: CGFloat = 36.0
    let corner: CGFloat = 7.0
    
    let image = generateImage(CGSize(width: 42.0, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let additionalOffset: CGFloat
        switch neighbors {
        case .none, .bottom:
            additionalOffset = 0.0
        case .both, .top:
            additionalOffset = 6.0
        }
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: incoming ? 1.0 : -1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0 + 0.5 + additionalOffset, y: -size.height / 2.0 + 0.5)
        
        let lineWidth: CGFloat = 1.0
        
        context.setFillColor(fillColor.cgColor)
        context.setLineWidth(lineWidth)
        context.setStrokeColor(strokeColor.cgColor)
        
        switch neighbors {
        case .none:
            let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
            context.strokePath()
            let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
            context.fillPath()
        case .top:
            let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L17.5,0 C7.83501688,0 0,7.83289181 0,17.5 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
            context.strokePath()
            let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L17.5,0 C7.83501688,0 0,7.83289181 0,17.5 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
            context.fillPath()
        case .bottom:
            let _ = try? drawSvgPath(context, path: "M6,17.5 L6,5.99681848 C6,2.6882755 8.68486709,0 11.9968185,0 L23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41103066e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
            context.strokePath()
            let _ = try? drawSvgPath(context, path: "M6,17.5 L6,5.99681848 C6,2.6882755 8.68486709,0 11.9968185,0 L23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41103066e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
            context.fillPath()
        case .both:
            
            let _ = try? drawSvgPath(context, path: "M17.5,0 C27.1649831,1.94289029e-15 35,7.83501688 35,17.5 C35,27.1649831 27.1649831,35 17.5,35 C7.83501688,35 0,27.1649831 0,17.5 C3.88578059e-15,7.83501688 7.83501688,-1.94289029e-15 17.5,0 Z ")
            context.fillPath()
            
            let _ = try? drawSvgPath(context, path: "M17.5,0 C27.1649831,1.94289029e-15 35,7.83501688 35,17.5 C35,27.1649831 27.1649831,35 17.5,35 C7.83501688,35 0,27.1649831 0,17.5 C3.88578059e-15,7.83501688 7.83501688,-1.94289029e-15 17.5,0 Z ")
            context.strokePath()
            
        }

    })!
    
    
    let leftCapWidth: CGFloat = CGFloat(incoming ? Int(corner + diameter / 2.0) : Int(diameter / 2.0))
    let topCapHeight: CGFloat = diameter / 2.0
    let rightCapWidth: CGFloat = image.backingSize.width - leftCapWidth - 1.0
    let bottomCapHeight: CGFloat = image.backingSize.height - topCapHeight - 1.0

    return ninePartPiecesFromImageWithInsets(image, capInsets: RHEdgeInsetsMake(topCapHeight, leftCapWidth, bottomCapHeight, rightCapWidth))
}

func messageBubbleImageModern(incoming: Bool, fillColor: NSColor, strokeColor: NSColor, neighbors: MessageBubbleImageNeighbors) -> (CGImage, NSEdgeInsets) {
    
    let diameter: CGFloat = 36.0
    let corner: CGFloat = 7.0
    
    let image = generateImage(CGSize(width: 42.0, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let additionalOffset: CGFloat
        switch neighbors {
        case .none, .bottom:
            additionalOffset = 0.0
        case .both, .top:
            additionalOffset = 6.0
        }
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: incoming ? 1.0 : -1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0 + 0.5 + additionalOffset, y: -size.height / 2.0 + 0.5)
        
        let lineWidth: CGFloat = 1.0
        
        context.setFillColor(fillColor.cgColor)
        context.setLineWidth(lineWidth)
        context.setStrokeColor(strokeColor.cgColor)
        
        switch neighbors {
        case .none:
            let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
            context.strokePath()
            let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
            context.fillPath()
        case .top:
            let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L17.5,0 C7.83501688,0 0,7.83289181 0,17.5 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
            context.strokePath()
            let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L17.5,0 C7.83501688,0 0,7.83289181 0,17.5 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
            context.fillPath()
        case .bottom:
            let _ = try? drawSvgPath(context, path: "M6,17.5 L6,5.99681848 C6,2.6882755 8.68486709,0 11.9968185,0 L23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41103066e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
            context.strokePath()
            let _ = try? drawSvgPath(context, path: "M6,17.5 L6,5.99681848 C6,2.6882755 8.68486709,0 11.9968185,0 L23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41103066e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
            context.fillPath()
        case .both:
            
            let _ = try? drawSvgPath(context, path: "M17.5,0 C27.1649831,1.94289029e-15 35,7.83501688 35,17.5 C35,27.1649831 27.1649831,35 17.5,35 C7.83501688,35 0,27.1649831 0,17.5 C3.88578059e-15,7.83501688 7.83501688,-1.94289029e-15 17.5,0 ")
            context.strokePath()
            
            let _ = try? drawSvgPath(context, path: "M17.5,0 C27.1649831,1.94289029e-15 35,7.83501688 35,17.5 C35,27.1649831 27.1649831,35 17.5,35 C7.83501688,35 0,27.1649831 0,17.5 C3.88578059e-15,7.83501688 7.83501688,-1.94289029e-15 17.5,0 ")
            context.fillPath()

        }
        
    })!
    
    
    let leftCapWidth: CGFloat = CGFloat(incoming ? Int(corner + diameter / 2.0) : Int(diameter / 2.0))
    let topCapHeight: CGFloat = diameter / 2.0
    let rightCapWidth: CGFloat = image.backingSize.width - leftCapWidth - 1.0
    let bottomCapHeight: CGFloat = image.backingSize.height - topCapHeight - 1.0
    
    return (image, NSEdgeInsetsMake(topCapHeight, leftCapWidth, bottomCapHeight, rightCapWidth))
}

