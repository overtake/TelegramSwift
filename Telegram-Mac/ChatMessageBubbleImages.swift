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


func ninePartPiecesFromImageWithInsets(_ image: CGImage, capInsets: RHEdgeInsets) -> [CGImage] {
    
    let imageWidth: CGFloat  = image.backingSize.width
    let imageHeight: CGFloat = image.backingSize.height
    
    let leftCapWidth: CGFloat = capInsets.left
    let topCapHeight: CGFloat = capInsets.top
    let rightCapWidth: CGFloat = capInsets.right
    let bottomCapHeight: CGFloat = capInsets.bottom
    
    let centerSize: NSSize  = NSMakeSize(imageWidth - leftCapWidth - rightCapWidth, imageHeight - topCapHeight - bottomCapHeight);
    
    let topLeftCorner: CGImage = imageByReferencingRectOfExistingImage(image, NSMakeRect(0.0, imageHeight - topCapHeight, leftCapWidth, topCapHeight))
    let topEdgeFill: CGImage = imageByReferencingRectOfExistingImage(image, NSMakeRect(leftCapWidth, imageHeight - topCapHeight, centerSize.width, topCapHeight))
    let topRightCorner: CGImage = imageByReferencingRectOfExistingImage(image, NSMakeRect(imageWidth - rightCapWidth, imageHeight - topCapHeight, rightCapWidth, topCapHeight))
    
    let leftEdgeFill: CGImage = imageByReferencingRectOfExistingImage(image, NSMakeRect(0.0, bottomCapHeight, leftCapWidth, centerSize.height))
    let centerFill: CGImage = imageByReferencingRectOfExistingImage(image, NSMakeRect(leftCapWidth, bottomCapHeight, centerSize.width, centerSize.height))
    let rightEdgeFill: CGImage = imageByReferencingRectOfExistingImage(image, NSMakeRect(imageWidth - rightCapWidth, bottomCapHeight, rightCapWidth, centerSize.height))
    
    let bottomLeftCorner: CGImage = imageByReferencingRectOfExistingImage(image, NSMakeRect(0.0, 0.0, leftCapWidth, bottomCapHeight))
    let bottomEdgeFill: CGImage = imageByReferencingRectOfExistingImage(image, NSMakeRect(leftCapWidth, 0.0, centerSize.width, bottomCapHeight))
    let bottomRightCorner: CGImage = imageByReferencingRectOfExistingImage(image, NSMakeRect(imageWidth - rightCapWidth, 0.0, rightCapWidth, bottomCapHeight))
    
    return [topLeftCorner, topEdgeFill, topRightCorner, leftEdgeFill, centerFill, rightEdgeFill, bottomLeftCorner, bottomEdgeFill, bottomRightCorner]
}

func drawNinePartImage(_ context: CGContext, frame: NSRect, topLeftCorner: CGImage, topEdgeFill: CGImage, topRightCorner: CGImage, leftEdgeFill: CGImage, centerFill: CGImage, rightEdgeFill: CGImage, bottomLeftCorner: CGImage, bottomEdgeFill: CGImage, bottomRightCorner: CGImage){
    
    let imageWidth: CGFloat = frame.size.width;
    let imageHeight: CGFloat = frame.size.height;
    
    let leftCapWidth: CGFloat = topLeftCorner.backingSize.width;
    let topCapHeight: CGFloat = topLeftCorner.backingSize.height;
    let rightCapWidth: CGFloat = bottomRightCorner.backingSize.width;
    let bottomCapHeight: CGFloat = bottomRightCorner.backingSize.height;
    
    let centerSize = NSMakeSize(imageWidth - leftCapWidth - rightCapWidth, imageHeight - topCapHeight - bottomCapHeight);
    
    let topLeftCornerRect: NSRect = NSMakeRect(0.0, imageHeight - topCapHeight, leftCapWidth, topCapHeight);
    let topEdgeFillRect: NSRect = NSMakeRect(leftCapWidth, imageHeight - topCapHeight, centerSize.width, topCapHeight);
    let topRightCornerRect: NSRect = NSMakeRect(imageWidth - rightCapWidth, imageHeight - topCapHeight, rightCapWidth, topCapHeight);
    
    let leftEdgeFillRect: NSRect = NSMakeRect(0.0, bottomCapHeight, leftCapWidth, centerSize.height);
    let centerFillRect: NSRect = NSMakeRect(leftCapWidth, bottomCapHeight, centerSize.width, centerSize.height);
    let rightEdgeFillRect: NSRect = NSMakeRect(imageWidth - rightCapWidth, bottomCapHeight, rightCapWidth, centerSize.height);
    
    let bottomLeftCornerRect: NSRect = NSMakeRect(0.0, 0.0, leftCapWidth, bottomCapHeight);
    let bottomEdgeFillRect: NSRect = NSMakeRect(leftCapWidth, 0.0, centerSize.width, bottomCapHeight);
    let bottomRightCornerRect: NSRect = NSMakeRect(imageWidth - rightCapWidth, 0.0, rightCapWidth, bottomCapHeight);
    
    
    drawStretchedImageInRect(topLeftCorner, context: context, rect: topLeftCornerRect);
    drawStretchedImageInRect(topEdgeFill, context: context, rect: topEdgeFillRect);
    drawStretchedImageInRect(topRightCorner, context: context, rect: topRightCornerRect);
    
    drawStretchedImageInRect(leftEdgeFill, context: context, rect: leftEdgeFillRect);
    drawStretchedImageInRect(centerFill, context: context, rect: centerFillRect);
    drawStretchedImageInRect(rightEdgeFill, context: context, rect: rightEdgeFillRect);
    
    drawStretchedImageInRect(bottomLeftCorner, context: context, rect: bottomLeftCornerRect);
    drawStretchedImageInRect(bottomEdgeFill, context: context, rect: bottomEdgeFillRect);
    drawStretchedImageInRect(bottomRightCorner, context: context, rect: bottomRightCornerRect);
    
}


func imageByReferencingRectOfExistingImage(_ image: CGImage, _ rect: NSRect) -> CGImage {
    if (!NSIsEmptyRect(rect)){
        
        let pixelsHigh = CGFloat(image.height)
        
        let scaleFactor:CGFloat = pixelsHigh / image.backingSize.height
        var captureRect = NSMakeRect(scaleFactor * rect.origin.x, scaleFactor * rect.origin.y, scaleFactor * rect.size.width, scaleFactor * rect.size.height)
        
        captureRect.origin.y = pixelsHigh - captureRect.origin.y - captureRect.size.height;
        
        return image.cropping(to: captureRect)!
    }
    return image.cropping(to: NSMakeRect(0, 0, image.size.width, image.size.height))!
}

func drawStretchedImageInRect(_ image: CGImage, context: CGContext, rect: NSRect) -> Void {
    context.saveGState()
    context.setBlendMode(.normal) //NSCompositeSourceOver
    context.clip(to: rect)
    
    context.draw(image, in: rect)
    context.restoreGState()
}
