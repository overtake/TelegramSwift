//
//  ThumbUtils.swift
//  TelegramMac
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TGUIKit
private let extensionImageCache = Atomic<[String: CGImage]>(value: [:])

private let redColors: (UInt32, UInt32) = (0xf0625d, 0xde524e)
private let greenColors: (UInt32, UInt32) = (0x72ce76, 0x54b658)
private let blueColors: (UInt32, UInt32) = (0x60b0e8, 0x4597d1)
private let yellowColors: (UInt32, UInt32) = (0xf5c565, 0xe5a64e)

private let extensionColorsMap: [String: (UInt32, UInt32)] = [
    "ppt": redColors,
    "pptx": redColors,
    "pdf": redColors,
    "key": redColors,
    
    "xls": greenColors,
    "xlsx": greenColors,
    "csv": greenColors,
    
    "zip": yellowColors,
    "rar": yellowColors,
    "gzip": yellowColors,
    "ai": yellowColors
]

func generateExtensionImage(colors: (UInt32, UInt32), ext:String) -> CGImage? {
    return generateImage(CGSize(width: 42.0, height: 42.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0 + 1.0, y: -size.height / 2.0 + 1.0)
//        
//        let radius: CGFloat = 2.0
//        let cornerSize: CGFloat = 10.0
        let size = CGSize(width: 42.0, height: 42.0)
        
        context.setFillColor(NSColor(colors.0).cgColor)
       // context.beginPath()
        context.fillEllipse(in: NSMakeRect(0, 0, size.width - 2, size.height - 2))
//        context.move(to: CGPoint(x: 0.0, y: radius))
//        if !radius.isZero {
//            context.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: radius, y: 0.0), radius: radius)
//        }
//        context.addLine(to: CGPoint(x: size.width - cornerSize, y: 0.0))
//        context.addLine(to: CGPoint(x: size.width - cornerSize + cornerSize / 4.0, y: cornerSize - cornerSize / 4.0))
//        context.addLine(to: CGPoint(x: size.width, y: cornerSize))
//        context.addLine(to: CGPoint(x: size.width, y: size.height - radius))
//        if !radius.isZero {
//            context.addArc(tangent1End: CGPoint(x: size.width, y: size.height), tangent2End: CGPoint(x: size.width - radius, y: size.height), radius: radius)
//        }
//        context.addLine(to: CGPoint(x: radius, y: size.height))
//        
//        if !radius.isZero {
//            context.addArc(tangent1End: CGPoint(x: 0.0, y: size.height), tangent2End: CGPoint(x: 0.0, y: size.height - radius), radius: radius)
//        }
//        context.closePath()
//        context.fillPath()
//        
//        context.setFillColor(NSColor(colors.1).cgColor)
//        context.beginPath()
//        context.move(to: CGPoint(x: size.width - cornerSize, y: 0.0))
//        context.addLine(to: CGPoint(x: size.width, y: cornerSize))
//        context.addLine(to: CGPoint(x: size.width - cornerSize + radius, y: cornerSize))
//        
//        if !radius.isZero {
//            context.addArc(tangent1End: CGPoint(x: size.width - cornerSize, y: cornerSize), tangent2End: CGPoint(x: size.width - cornerSize, y: cornerSize - radius), radius: radius)
//        }
//        
      //  context.closePath()
      //  context.fillPath()
        
        
        
        let layout = TextViewLayout(.initialize(string: ext, color: .white, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .middle)
        layout.measure(width: size.width - 4)
        if !layout.lines.isEmpty {
            let line = layout.lines[0]
            context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            context.textPosition = NSMakePoint(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - line.frame.width)/2.0) - 1, floorToScreenPixels(scaleFactor: System.backingScale, (size.height )/2.0) + 4)
            
            CTLineDraw(line.line, context)
        } 
    })
}


func generateMediaEmptyLinkThumb(color: NSColor, host:String) -> CGImage? {
    return generateImage(CGSize(width: 50, height: 50), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        let host = host.isEmpty ? "L" : host
        context.round(size, 25)
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        if !host.isEmpty {
            let layout = TextViewLayout(.initialize(string: host, color: .white, font: .normal(16.0)), maximumNumberOfLines: 1, truncationType: .middle)
            layout.measure(width: size.width - 4)
            let line = layout.lines[0]
            
            context.textMatrix = CGAffineTransform(scaleX: 1.0, y: 1.0)
            context.textPosition = NSMakePoint(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - line.frame.width)/2.0) , floorToScreenPixels(scaleFactor: System.backingScale, (size.height - line.frame.width)/2.0))
            CTLineDraw(line.line, context)
        }
    })
}


func extensionImage(fileExtension: String) -> CGImage? {
    let colors: (UInt32, UInt32)
    if let extensionColors = extensionColorsMap[fileExtension] {
        colors = extensionColors
    } else {
        colors = blueColors
    }
    
    if let cachedImage = (extensionImageCache.with { dict in
        return dict[fileExtension]
    }) {
        return cachedImage
    } else if let image = generateExtensionImage(colors: colors, ext: fileExtension) {
        let _ = extensionImageCache.modify { dict in
            var dict = dict
            dict[fileExtension] = image
            return dict
        }
        return image
    } else {
        return nil
    }
}

func capIcon(for text:NSAttributedString, size:NSSize = NSMakeSize(50, 50), cornerRadius:CGFloat = 4, background:NSColor = .border) -> CGImage? {
    return generateImage(size, contextGenerator: { (size, ctx) in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, cornerRadius)
        ctx.setFillColor(background.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        
        let line = CTLineCreateWithAttributedString(text)
        
        let rect = CTLineGetBoundsWithOptions(line, [.excludeTypographicLeading])
        

        ctx.textMatrix = CGAffineTransform(scaleX: 1.0, y: 1.0)
        ctx.textPosition = NSMakePoint(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - rect.width)/2.0), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - rect.height)/2.0) + 6 )
        
        CTLineDraw(line, ctx)
        
    })
}

let playerPlayThumb = generateImage(NSMakeSize(40.0,40.0), contextGenerator: { size, context in
    
    context.clear(NSMakeRect(0.0,0.0,size.width,size.height))
    
    let position:NSPoint = NSMakePoint(14.0, 10.0)
    context.move(to: position)
    context.addLine(to: NSMakePoint(position.x, position.y + 20.0))
    context.addLine(to: NSMakePoint(position.x + 15.0, position.y + 10.0 ))
    context.setFillColor(NSColor.white.cgColor)
    context.fillPath()
    
})

let playerPauseThumb = generateImage(CGSize(width: 40, height: 40), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    
    context.setFillColor(NSColor.white.cgColor)
    //20 - 2
    context.fill(CGRect(x: 14, y: 12, width: 4.0, height: 16))
    context.fill(CGRect(x: 22, y: 12, width: 4.0, height: 16))
})



public struct PreviewOptions: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public init(_ flags: PreviewOptions) {
        var rawValue: UInt32 = 0
        
        
        if flags.contains(PreviewOptions.file) {
            rawValue |= PreviewOptions.file.rawValue
        }
        
        if flags.contains(PreviewOptions.media) {
            rawValue |= PreviewOptions.media.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let media = PreviewOptions(rawValue: 1)
    public static let file = PreviewOptions(rawValue: 8)
}

func takeSenderOptions(for urls:[URL]) -> [PreviewOptions] {
    var options:[PreviewOptions] = []
    for url in urls {
        let mime = MIMEType(url.path.nsstring.pathExtension)
        
        if mime.hasPrefix("image"), let image = NSImage(contentsOf: url) {
            if image.size.width / 10 > image.size.height || image.size.height < 40 {
                continue
            }
        }
        
        let media = mime.hasPrefix("image") || mime.hasSuffix("gif") || mime.hasPrefix("video/mp4")

        if media {
            if !options.contains(.media) {
                options.append(.media)
            }
        } else {
            if !options.contains(.file) {
                options.append(.file)
            }
        }
    }
    
    if options.isEmpty {
        options.append(.file)
    }
    
    return options
}



fileprivate let minDiameter: CGFloat = 3.5
fileprivate let maxDiameter: CGFloat = 8.0

func interpolate(from: CGFloat, to: CGFloat, value: CGFloat) -> CGFloat {
    return (1.0 - value) * from + value * to
}

func radiusFunction(_ value: CGFloat, timeOffset: CGFloat) -> CGFloat {
    var clampedValue: CGFloat = value + timeOffset
    if clampedValue > 1.0 {
        clampedValue = clampedValue - floor(clampedValue)
    }
    if clampedValue < 0.4 {
        return interpolate(from: minDiameter, to: maxDiameter, value: clampedValue / 0.4)
    }
    else if clampedValue < 0.8 {
        return interpolate(from: maxDiameter, to: minDiameter, value: (clampedValue - 0.4) / 0.4)
    }
    else {
        return minDiameter
    }
}

private func generateTextAnimatedImage(_ animationValue:CGFloat, color:UInt32) -> CGImage {
    return generateImage(NSMakeSize(26, 20), contextGenerator: { (size, context) in
        context.clear(NSMakeRect(0,0,size.width, size.height))
        let leftPadding: CGFloat = 5.0
        let topPadding: CGFloat = 7
        let distance: CGFloat = 12.0 / 2.0
        let minAlpha: CGFloat = 0.75
        let deltaAlpha: CGFloat = 1.0 - minAlpha
        var radius: CGFloat = 0.0
        var ellipse:NSRect = NSZeroRect
        radius =  radiusFunction(animationValue, timeOffset: 0.4)
        radius = (max(minDiameter, radius) - minDiameter) / (maxDiameter - minDiameter)
        radius = radius * 1.5
        var dotsColor: NSColor = NSColor(color, (radius * deltaAlpha + minAlpha))
        context.setFillColor(dotsColor.cgColor)
        ellipse = NSMakeRect(leftPadding - minDiameter / 2.0 - radius / 2.0, topPadding - minDiameter / 2.0 - radius / 2.0, minDiameter + radius, minDiameter + radius)
        context.fillEllipse(in: ellipse)
        radius = radiusFunction(animationValue, timeOffset: 0.2)
        radius = (max(minDiameter, radius) - minDiameter) / (maxDiameter - minDiameter)
        radius = radius * 1.5
        dotsColor = NSColor(color, (radius * deltaAlpha + minAlpha))
        context.setFillColor(dotsColor.cgColor)
        ellipse = NSMakeRect(leftPadding + distance - minDiameter / 2.0 - radius / 2.0, topPadding - minDiameter / 2.0 - radius / 2.0, minDiameter + radius, minDiameter + radius)
        context.fillEllipse(in: ellipse)
        radius = radiusFunction(animationValue, timeOffset: 0.0)
        radius = (max(minDiameter, radius) - minDiameter) / (maxDiameter - minDiameter)
        radius = radius * 1.5
        
        dotsColor = NSColor(color, (radius * deltaAlpha + minAlpha))
        context.setFillColor(dotsColor.cgColor)
        ellipse = NSMakeRect(leftPadding + distance * 2.0 - minDiameter / 2.0 - radius / 2.0, topPadding - minDiameter / 2.0 - radius / 2.0, minDiameter + radius, minDiameter + radius)
                
        context.fillEllipse(in: ellipse)
    })!
    
}

private func generateRecordingAnimatedImage(_ animationValue:CGFloat, color:UInt32) -> CGImage {
    return generateImage(NSMakeSize(26, 20), contextGenerator: { (size, context) in
        context.clear(NSMakeRect(0,0,size.width, size.height))
        context.setStrokeColor(NSColor(color).cgColor)
        context.setLineCap(.round)
        context.setLineWidth(3)
        
        let delta: CGFloat = 5.0
        let x: CGFloat = 4
        let y: CGFloat = 7.0
        let angle = CGFloat(18.0 * .pi / 180.0)
        let animationValue: CGFloat = animationValue * delta
        var radius: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        radius = animationValue
        
        alpha = radius/(3*delta);
        alpha = 1.0 - pow(cos(alpha * (CGFloat.pi/2)), 50);
        context.setAlpha(alpha);
        
        context.beginPath();
        context.addArc(center: NSMakePoint(x, y), radius: radius, startAngle: -angle, endAngle: angle, clockwise: false)
        context.strokePath();
        
        radius = animationValue + delta;
        
        alpha = radius / (3.0 * delta);
        alpha = 1.0 - pow(cos(alpha * CGFloat.pi), 10);
        context.setAlpha(alpha);
        
        context.beginPath();
        context.addArc(center: NSMakePoint(x, y), radius: radius, startAngle: -angle, endAngle: angle, clockwise: false)
        context.strokePath();
        
        radius = animationValue + delta*2;
        
        alpha = radius / (3.0 * delta);
        alpha = 1.0 - pow(cos(alpha * CGFloat.pi), 10);
        context.setAlpha(alpha);
        
        context.beginPath();
        context.addArc(center: NSMakePoint(x, y), radius: radius, startAngle: -angle, endAngle: angle, clockwise: false)
        context.strokePath();
        
    })!
    
}

private func generateUploadFileAnimatedImage(_ animationValue:CGFloat, backgroundColor:UInt32, foregroundColor: UInt32) -> CGImage {
    return generateImage(NSMakeSize(26, 20), contextGenerator: { (size, context) in
        context.clear(NSMakeRect(0,0,size.width, size.height))
        let leftPadding: CGFloat = 7.0
        let topPadding: CGFloat = 4.0
        let progressWidth: CGFloat = 26.0 / 2.0
        let progressHeight: CGFloat = 10.0 / 2.0
        var progress: CGFloat = 0.0
       // let round: CGFloat = 1.25
        var dotsColor = NSColor(backgroundColor)
        context.setFillColor(dotsColor.cgColor)
        context.fill(CGRect(x: leftPadding, y: topPadding, width: progressWidth, height: progressHeight))
        dotsColor = NSColor(foregroundColor, 0.3)
        context.setFillColor(dotsColor.cgColor)
        context.fill(CGRect(x: leftPadding, y: topPadding, width: progressWidth, height: progressHeight))
        progress = interpolate(from: 0.0, to: progressWidth * 2.0, value: animationValue)
        dotsColor = NSColor(foregroundColor, 1.0)
        context.setFillColor(dotsColor.cgColor)
        context.setBlendMode(.sourceIn)
        context.fill(CGRect(x: CGFloat(leftPadding - progressWidth + progress), y: topPadding, width: progressWidth, height: progressHeight))
        
    })!
    
}

let recordVoiceActivityAnimationBlue:[CGImage] = {
    var steps:[CGImage] = []
    var animationValue:CGFloat = 0
    
    for i in 0 ..< 42 {
        steps.append(generateRecordingAnimatedImage( CGFloat(i) / 42, color: 0x2481cc))
    }
    return steps
}()



let textActivityAnimationBlue:[CGImage] = {
    var steps:[CGImage] = []
    var animationValue:CGFloat = 0
    
    for i in 0 ..< 42 {
        steps.append(generateTextAnimatedImage( CGFloat(i) / 42, color: 0x2481cc))
    }
    return steps
}()

let recordVoiceActivityAnimationWhite:[CGImage] = {
    var steps:[CGImage] = []
    var animationValue:CGFloat = 0
    
    for i in 0 ..< 42 {
        steps.append(generateRecordingAnimatedImage( CGFloat(i) / 42, color: 0xffffff))
    }
    return steps
}()


let textActivityAnimationWhite:[CGImage] = {
    var steps:[CGImage] = []
    
    for i in 0 ..< 42 {
        steps.append(generateTextAnimatedImage( CGFloat(i) / 42, color: 0xffffff))
    }
    return steps
}()



func recordVoiceActivityAnimation(_ color: NSColor) -> [CGImage] {
    var steps:[CGImage] = []
    
    for i in 0 ..< 42 {
        steps.append(generateRecordingAnimatedImage( CGFloat(i) / 42, color: color.rgb))
    }
    return steps
}

func uploadFileActivityAnimation(_ foregroundColor: NSColor, _ backgroundColor: NSColor) -> [CGImage] {
    var steps:[CGImage] = []
    
    for i in 0 ..< 105 {
        steps.append(generateUploadFileAnimatedImage( CGFloat(i) / 105, backgroundColor: backgroundColor.rgb, foregroundColor: foregroundColor.rgb))
    }
    return steps
}

func textActivityAnimation(_ color: NSColor) -> [CGImage] {
    var steps:[CGImage] = []
    
    for i in 0 ..< 42 {
        steps.append(generateTextAnimatedImage( CGFloat(i) / 42, color: color.rgb))
    }
    return steps
}

