//
//  ImageTransparency.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27/12/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import Accelerate
import TGUIKit


private func generateHistogram(cgImage: CGImage) -> ([[vImagePixelCount]], Int)? {
    var sourceBuffer = vImage_Buffer()
    defer {
        free(sourceBuffer.data)
    }
    
    var cgImageFormat = vImage_CGImageFormat(
        bitsPerComponent: UInt32(cgImage.bitsPerComponent),
        bitsPerPixel: UInt32(cgImage.bitsPerPixel),
        colorSpace: Unmanaged.passUnretained(cgImage.colorSpace!),
        bitmapInfo: cgImage.bitmapInfo,
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent
    )
    
    let noFlags = vImage_Flags(kvImageNoFlags)
    var error = vImageBuffer_InitWithCGImage(&sourceBuffer, &cgImageFormat, nil, cgImage, noFlags)
    assert(error == kvImageNoError)
    
    if cgImage.alphaInfo == .premultipliedLast {
        error = vImageUnpremultiplyData_RGBA8888(&sourceBuffer, &sourceBuffer, noFlags)
    } else if cgImage.alphaInfo == .premultipliedFirst {
        error = vImageUnpremultiplyData_ARGB8888(&sourceBuffer, &sourceBuffer, noFlags)
    }
    assert(error == kvImageNoError)
    
    let histogramBins = (0...3).map { _ in
        return [vImagePixelCount](repeating: 0, count: 256)
    }
    var mutableHistogram: [UnsafeMutablePointer<vImagePixelCount>?] = histogramBins.map {
        return UnsafeMutablePointer<vImagePixelCount>(mutating: $0)
    }
    error = vImageHistogramCalculation_ARGB8888(&sourceBuffer, &mutableHistogram, noFlags)
    assert(error == kvImageNoError)
    
    let alphaBinIndex = [.last, .premultipliedLast].contains(cgImage.alphaInfo) ? 3 : 0
    return (histogramBins, alphaBinIndex)
}

func imageHasTransparency(_ cgImage: CGImage) -> Bool {
    guard cgImage.bitsPerComponent == 8, cgImage.bitsPerPixel == 32 else {
        return false
    }
    guard [.first, .last, .premultipliedFirst, .premultipliedLast].contains(cgImage.alphaInfo) else {
        return false
    }
    if let (histogramBins, alphaBinIndex) = generateHistogram(cgImage: cgImage) {
        for i in 0 ..< 255 {
            if histogramBins[alphaBinIndex][i] > 0 {
                return true
            }
        }
    }
    return false
}

private func scaledDrawingContext(_ cgImage: CGImage, maxSize: CGSize) -> DrawingContext {
    var size = CGSize(width: cgImage.width, height: cgImage.height)
    if (size.width > maxSize.width && size.height > maxSize.height) {
        size = size.aspectFilled(maxSize)
    }
    let context = DrawingContext(size: size, scale: 1.0, clear: true)
    context.withFlippedContext { context in
        context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
    }
    return context
}

func imageRequiresInversion(_ cgImage: CGImage) -> Bool {
    guard cgImage.bitsPerComponent == 8, cgImage.bitsPerPixel == 32 else {
        return false
    }
    guard [.first, .last, .premultipliedFirst, .premultipliedLast].contains(cgImage.alphaInfo) else {
        return false
    }
    
    let context = scaledDrawingContext(cgImage, maxSize: CGSize(width: 128.0, height: 128.0))
    if let cgImage = context.generateImage(), let (histogramBins, alphaBinIndex) = generateHistogram(cgImage: cgImage) {
        var hasAlpha = false
        for i in 0 ..< 255 {
            if histogramBins[alphaBinIndex][i] > 0 {
                hasAlpha = true
                break
            }
        }
        
        if hasAlpha {
            var matching: Int = 0
            var total: Int = 0
            for y in 0 ..< Int(context.size.height) {
                for x in 0 ..< Int(context.size.width) {
                    var saturation: CGFloat = 0.0
                    var brightness: CGFloat = 0.0
                    var alpha: CGFloat = 0.0
                    context.colorAt(CGPoint(x: x, y: y)).getHue(nil, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                    if alpha < 1.0 {
                        hasAlpha = true
                    }
                    
                    if alpha > 0.0 {
                        total += 1
                        if saturation < 0.1 && brightness < 0.25 {
                            matching += 1
                        }
                    }
                }
            }
            return CGFloat(matching) / CGFloat(total) > 0.85
        }
    }
    return false
}


func generateTintedImage(image: CGImage?, color: NSColor, backgroundColor: NSColor? = nil, flipVertical: Bool = true) -> CGImage? {
    guard let image = image else {
        return nil
    }
    let imageSize = image.size
    return generateImage(imageSize, contextGenerator: { size, context in
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: imageSize))
        }
        
        let imageRect = CGRect(origin: CGPoint(), size: imageSize)
        context.saveGState()
        if flipVertical {
            context.translateBy(x: imageRect.midX, y: imageRect.midY)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
        }
        context.clip(to: imageRect, mask: image)
        context.setFillColor(color.cgColor)
        context.fill(imageRect)
        context.restoreGState()
    })
}



private func orientationFromExif(orientation: Int) -> ImageOrientation {
    switch orientation {
    case 1:
        return .up;
    case 3:
        return .down;
    case 8:
        return .left;
    case 6:
        return .right;
    case 2:
        return .upMirrored;
    case 4:
        return .downMirrored;
    case 5:
        return .leftMirrored;
    case 7:
        return .rightMirrored;
    default:
        return .up
    }
}

func imageOrientationFromSource(_ source: CGImageSource) -> ImageOrientation {
    if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) {
        let dict = properties as NSDictionary
        if let value = dict.object(forKey: kCGImagePropertyOrientation) as? NSNumber {
            return orientationFromExif(orientation: value.intValue)
        }
    }
    
    return .up
}
