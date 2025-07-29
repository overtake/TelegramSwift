//
//  DrawingContext.swift
//  TGLibrary
//
//  Created by keepcoder on 18/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit


public final class ImageDataTransformation {
    public let data: ImageRenderData
    public let execute:(TransformImageArguments, ImageRenderData)->DrawingContext?
    public init(data: ImageRenderData = ImageRenderData(nil, nil, false), execute:@escaping(TransformImageArguments, ImageRenderData)->DrawingContext? = { _, _ in return nil}) {
        self.data = data
        self.execute = execute
    }
}

public final class ImageRenderData {
    public let thumbnailData: Data?
    public let fullSizeData:Data?
    public let fullSizeComplete:Bool
    public init(_ thumbnailData: Data?, _ fullSizeData: Data?, _ fullSizeComplete: Bool) {
        self.thumbnailData = thumbnailData
        self.fullSizeData = fullSizeData
        self.fullSizeComplete = fullSizeComplete
    }
}


public func generateImage(_ size: CGSize, contextGenerator: (CGSize, CGContext) -> Void, opaque: Bool = false, scale: CGFloat = System.backingScale) -> CGImage? {
    if size.width.isZero || size.height.isZero {
        return nil
    }
    let context = DrawingContext(size: size, scale: scale, clear: false)
    context.withContext { c in
        contextGenerator(context.size, c)
    }
    return context.generateImage()

}

public func generateImageMask(_ size: CGSize, contextGenerator: (CGSize, CGContext) -> Void, scale: CGFloat = System.backingScale) -> CGImage? {
    let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = malloc(length)!.assumingMemoryBound(to: Int8.self)
    
    guard let provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
        free(bytes)
    })
        else {
            return nil
    }
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
    
    guard let context = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: bitmapInfo.rawValue)
        else {
            return nil
    }
    
    context.scaleBy(x: scale, y: scale)
    
    contextGenerator(size, context)
    
    guard let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else {
            return nil
    }
    
    return image
}

public func generateImage(_ size: CGSize, opaque: Bool = false, scale: CGFloat? = System.backingScale, rotatedContext: (CGSize, CGContext) -> Void) -> CGImage? {
    if size.width.isZero || size.height.isZero {
        return nil
    }
    let context = DrawingContext(size: size, scale: scale ?? 0.0, clear: false)
    context.withFlippedContext(isHighQuality: true, horizontal: false, vertical: true, { ctx in
        rotatedContext(size, ctx)
    })
    return context.generateImage()
}



public let deviceColorSpace: CGColorSpace = {
    return CGColorSpaceCreateDeviceRGB()
//
//    if #available(OSX 10.11.2, *) {
//        if let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
//            return colorSpace
//        } else {
//            return CGColorSpaceCreateDeviceRGB()
//        }
//    } else {
//        return CGColorSpaceCreateDeviceRGB()
//    }
}()





public func generateImagePixel(_ size: CGSize, scale: CGFloat, pixelGenerator: (CGSize, UnsafeMutablePointer<UInt8>, Int) -> Void) -> CGImage? {
    let context = DrawingContext(size: size, scale: scale, clear: false)
    pixelGenerator(CGSize(width: size.width * scale, height: size.height * scale), context.bytes.assumingMemoryBound(to: UInt8.self), context.bytesPerRow)
    return context.generateImage()

}


public enum DrawingContextBltMode {
    case Alpha
}
private var allocCounter: Int = 0
private var deallocCounter: Int = 0


private extension NSImage {
    convenience init(size: CGSize, actions: (CGContext) -> Void) {
        self.init(size: size)
        lockFocusFlipped(false)
        actions(NSGraphicsContext.current!.cgContext)
        unlockFocus()
    }
}

public func getSharedDevideGraphicsContextSettings(context: CGContext?) -> DeviceGraphicsContextSettings {
    struct OpaqueSettings {
        let rowAlignment: Int
        let bitsPerPixel: Int
        let bitsPerComponent: Int
        let opaqueBitmapInfo: CGBitmapInfo
        let colorSpace: CGColorSpace

        public init(context: CGContext?) {
            
            let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
            self.rowAlignment =  context?.bytesPerRow ?? 32 /// Int(System.backingScale)
            self.bitsPerPixel = context?.bitsPerPixel ?? 32// / Int(System.backingScale)
            self.bitsPerComponent = context?.bitsPerComponent ?? 8// / Int(System.backingScale)
            self.opaqueBitmapInfo = context?.bitmapInfo ?? bitmapInfo
            self.colorSpace = context?.colorSpace ?? deviceColorSpace
         
//            assert(self.rowAlignment == 32)
//            assert(self.bitsPerPixel == 32)
//            assert(self.bitsPerComponent == 8)
        }
    }
    

    let opaqueSettings: OpaqueSettings = .init(context: context)
    

    return DeviceGraphicsContextSettings(
        rowAlignment: opaqueSettings.rowAlignment,
        bitsPerPixel: opaqueSettings.bitsPerPixel,
        bitsPerComponent: opaqueSettings.bitsPerComponent,
        opaqueBitmapInfo: opaqueSettings.opaqueBitmapInfo,
        colorSpace: opaqueSettings.colorSpace
    )
}

public struct DeviceGraphicsContextSettings : Equatable {
    private static let installed: Atomic<DeviceGraphicsContextSettings?> = Atomic(value: nil)
    
    public static func install(_ context: CGContext?) {
        if let context = context {
            let size = NSMakeSize(CGFloat(1), CGFloat(1))
            
            let baseValue = context.bitsPerPixel * Int(size.width) / 8
            let bytesPerRow = (baseValue + 31) & ~0x1F
            let length = bytesPerRow * 2
            let bytes = malloc(length)!
            
            if context.colorSpace?.model != .rgb {
                _ = installed.swap(getSharedDevideGraphicsContextSettings(context: nil))
            } else {
                let ctx = CGContext(
                     data: bytes,
                     width: context.width,
                     height: context.height,
                     bitsPerComponent: context.bitsPerComponent,
                     bytesPerRow: bytesPerRow,
                     space: context.colorSpace ?? deviceColorSpace,
                     bitmapInfo: context.bitmapInfo.rawValue,
                     releaseCallback: nil,
                     releaseInfo: nil
                 )
                _ = installed.swap(getSharedDevideGraphicsContextSettings(context: ctx))
            }
        } else {
            _ = installed.swap(getSharedDevideGraphicsContextSettings(context: nil))
        }
    }
    
    public static var shared: DeviceGraphicsContextSettings {
        if let installed = installed.with ({ $0 }) {
            return installed
        } else {
            return getSharedDevideGraphicsContextSettings(context: nil)
        }
    }

    public let rowAlignment: Int
    public let bitsPerPixel: Int
    public let bitsPerComponent: Int
    public let opaqueBitmapInfo: CGBitmapInfo
    public let colorSpace: CGColorSpace

    public func bytesPerRow(forWidth width: Int) -> Int {
        let baseValue = self.bitsPerPixel * width / 8
        return (baseValue + 31) & ~0x1F
    }
}



public class DrawingContext {
    public let size: CGSize
    public let scale: CGFloat
    public let scaledSize: CGSize
    public let bytesPerRow: Int
    private let bitmapInfo: CGBitmapInfo
    public let length: Int
    
    public let bytes: UnsafeMutableRawPointer
    let provider: CGDataProvider?
    
    private let context: CGContext
    public private(set) var isHighQuality: Bool = true
    
    public func withContext(isHighQuality: Bool = true, _ f: (CGContext) -> ()) {
        
        self.isHighQuality = isHighQuality
        
        f(self.context)
    }
    
    deinit {
    }
    
    public func withFlippedContext(isHighQuality: Bool = true, horizontal: Bool = false, vertical: Bool = false, _ f: (CGContext) -> ()) {
        self.isHighQuality = isHighQuality
        
        let _context = self.context
        
        _context.translateBy(x: self.size.width / 2.0, y: self.size.height / 2.0)
        _context.scaleBy(x: horizontal ? -1.0 : 1.0, y: vertical ? -1.0 : 1.0)
        _context.translateBy(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
        
        f(_context)
        
        _context.translateBy(x: self.size.width / 2.0, y: self.size.height / 2.0)
        _context.scaleBy(x: horizontal ? -1.0 : 1.0, y: vertical ? -1.0 : 1.0)
        _context.translateBy(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
    }
    
    public init(size: CGSize, scale: CGFloat, clear: Bool = false) {
        let size = NSMakeSize(max(size.width, 1), max(size.height, 1))
        self.size = size
        
        let actualScale: CGFloat
        if scale.isZero {
            actualScale = System.backingScale
        } else {
            actualScale = scale
        }

        
        self.scale = scale
        self.scaledSize = CGSize(width: size.width * actualScale, height: size.height * actualScale)
        
        self.bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: Int(scaledSize.width))
        self.length = self.bytesPerRow * Int(scaledSize.height)

        self.bitmapInfo = DeviceGraphicsContextSettings.shared.opaqueBitmapInfo

        self.bytes = malloc(length)!
        
        let ctx = CGContext(
            data: self.bytes,
             width: Int(self.scaledSize.width),
             height: Int(self.scaledSize.height),
             bitsPerComponent: DeviceGraphicsContextSettings.shared.bitsPerComponent,
             bytesPerRow: self.bytesPerRow,
             space: DeviceGraphicsContextSettings.shared.colorSpace,
             bitmapInfo: self.bitmapInfo.rawValue,
             releaseCallback: nil,
             releaseInfo: nil
         )
        
        self.context = ctx!
                
        self.context.scaleBy(x: actualScale, y: actualScale)

        
        if clear {
            memset(self.bytes, 0, self.length)
        }
        self.provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
            free(bytes)
        })
    }
    
    public func generateImage() -> CGImage? {
        if let image = CGImage(width: Int(scaledSize.width),
                               height: Int(scaledSize.height),
                               bitsPerComponent: self.context.bitsPerComponent,
                               bitsPerPixel: self.context.bitsPerPixel,
                               bytesPerRow: self.context.bytesPerRow,
                               space: DeviceGraphicsContextSettings.shared.colorSpace,
                               bitmapInfo: self.context.bitmapInfo,
                               provider: provider!,
                               decode: nil,
                               shouldInterpolate: true,
                               intent: .defaultIntent) {
            return image
        } else {
            return nil
        }
    }
    
    public func colorAt(_ point: CGPoint) -> NSColor {
        let x = Int(point.x * self.scale)
        let y = Int(point.y * self.scale)
        if x >= 0 && x < Int(self.scaledSize.width) && y >= 0 && y < Int(self.scaledSize.height) {
            let srcLine = self.bytes.advanced(by: y * self.bytesPerRow).assumingMemoryBound(to: UInt32.self)
            let pixel = srcLine + x
            let colorValue = pixel.pointee
            return NSColor(UInt32(colorValue))
        } else {
            return NSColor.clear
        }
    }
    
    public func blt(_ other: DrawingContext, at: CGPoint, mode: DrawingContextBltMode = .Alpha) {
        if abs(other.scale - self.scale) < CGFloat.ulpOfOne {
            let srcX = 0
            var srcY = 0
            let dstX = Int(at.x * self.scale)
            var dstY = Int(at.y * self.scale)
            
            let width = min(Int(self.size.width * self.scale) - dstX, Int(other.size.width * self.scale))
            let height = min(Int(self.size.height * self.scale) - dstY, Int(other.size.height * self.scale))
            
            let maxDstX = dstX + width
            let maxDstY = dstY + height
            
            switch mode {
            case .Alpha:
                while dstY < maxDstY {
                    let srcLine = other.bytes.advanced(by: max(0, srcY) * other.bytesPerRow).assumingMemoryBound(to: UInt32.self)
                    let dstLine = self.bytes.advanced(by: max(0, dstY) * self.bytesPerRow).assumingMemoryBound(to: UInt32.self)
                    
                    var dx = dstX
                    var sx = srcX
                    while dx < maxDstX {
                        let srcPixel = srcLine + sx
                        let dstPixel = dstLine + dx
                        
                        let baseColor = dstPixel.pointee
                        let baseAlpha = (baseColor >> 24) & 0xff
                        let baseR = (baseColor >> 16) & 0xff
                        let baseG = (baseColor >> 8) & 0xff
                        let baseB = baseColor & 0xff
                        
                        let alpha = min(baseAlpha, srcPixel.pointee >> 24)
                        
                        let r = (baseR * alpha) / 255
                        let g = (baseG * alpha) / 255
                        let b = (baseB * alpha) / 255
                        
                        dstPixel.pointee = (alpha << 24) | (r << 16) | (g << 8) | b
                        
                        dx += 1
                        sx += 1
                    }
                    
                    dstY += 1
                    srcY += 1
                }
            }
        }
    }
}

public enum ParsingError: Error {
    case Generic
}

public func readCGFloat(_ index: inout UnsafePointer<UInt8>, end: UnsafePointer<UInt8>, separator: UInt8) throws -> CGFloat {
    let begin = index
    var seenPoint = false
    while index <= end {
        let c = index.pointee
        index = index.successor()
        
        if c == 46 { // .
            if seenPoint {
                throw ParsingError.Generic
            } else {
                seenPoint = true
            }
        } else if c == separator {
            break
        } else if !((c >= 48 && c <= 57) || c == 45 || c == 101 || c == 69) {
            throw ParsingError.Generic
        }
    }
    
    if index == begin {
        throw ParsingError.Generic
    }
    
    if let value = NSString(bytes: UnsafeRawPointer(begin), length: index - begin, encoding: String.Encoding.utf8.rawValue)?.floatValue {
        return CGFloat(value)
    } else {
        throw ParsingError.Generic
    }
}
public func drawSvgPath(_ context: CGContext, path: StaticString, strokeOnMove: Bool = false) throws {
    var index: UnsafePointer<UInt8> = path.utf8Start
    let end = path.utf8Start.advanced(by: path.utf8CodeUnitCount)
    while index < end {
        let c = index.pointee
        index = index.successor()
        
        if c == 77 { // M
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Move to \(x), \(y)")
            context.move(to: CGPoint(x: x, y: y))
        } else if c == 76 { // L
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Line to \(x), \(y)")
            context.addLine(to: CGPoint(x: x, y: y))
            
            if strokeOnMove {
                context.strokePath()
                context.move(to: CGPoint(x: x, y: y))
            }
        } else if c == 67 { // C
            let x1 = try readCGFloat(&index, end: end, separator: 44)
            let y1 = try readCGFloat(&index, end: end, separator: 32)
            let x2 = try readCGFloat(&index, end: end, separator: 44)
            let y2 = try readCGFloat(&index, end: end, separator: 32)
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            context.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
            
            //print("Line to \(x), \(y)")
            if strokeOnMove {
                context.strokePath()
                context.move(to: CGPoint(x: x, y: y))
            }
        } else if c == 90 { // Z
            if index != end && index.pointee != 32 {
                throw ParsingError.Generic
            }
            
            //CGContextClosePath(context)
            context.fillPath()
            //CGContextBeginPath(context)
            //print("Close")
        } else if c == 83 { // S
            if index != end && index.pointee != 32 {
                throw ParsingError.Generic
            }
            
            //CGContextClosePath(context)
            context.strokePath()
            //CGContextBeginPath(context)
            //print("Close")
        } else if c == 32 { // space
            continue
        } else {
            throw ParsingError.Generic
        }
    }
}


public func createPath(_ svgPath: String) -> CGPath {
    let path = CGMutablePath()
    var currentPoint = CGPoint.zero
    var startPoint = CGPoint.zero

    // Split the SVG path into commands and parameters
    let scanner = Scanner(string: svgPath)
    scanner.charactersToBeSkipped = .whitespacesAndNewlines
    var command: NSString?
    
    while !scanner.isAtEnd {
        if scanner.scanCharacters(from: CharacterSet.letters, into: &command) {
            let commandString = command! as String
            
            switch commandString {
            case "M":
                // Move to command
                var x: Double = 0, y: Double = 0
                scanner.scanDouble(&x)
                scanner.scanDouble(&y)
                currentPoint = CGPoint(x: x, y: y)
                startPoint = currentPoint
                path.move(to: currentPoint)
                
            case "C":
                // Cubic Bezier curve command
                var control1X: Double = 0, control1Y: Double = 0, control2X: Double = 0, control2Y: Double = 0, endPointX: Double = 0, endPointY: Double = 0
                scanner.scanDouble(&control1X)
                scanner.scanDouble(&control1Y)
                scanner.scanDouble(&control2X)
                scanner.scanDouble(&control2Y)
                scanner.scanDouble(&endPointX)
                scanner.scanDouble(&endPointY)
                path.addCurve(to: CGPoint(x: endPointX, y: endPointY),
                              control1: CGPoint(x: control1X, y: control1Y),
                              control2: CGPoint(x: control2X, y: control2Y))
                currentPoint = CGPoint(x: endPointX, y: endPointY)
                
            case "H":
                // Horizontal line command
                var x: Double = 0
                scanner.scanDouble(&x)
                currentPoint = CGPoint(x: x, y: currentPoint.y)
                path.addLine(to: currentPoint)
                
            case "V":
                // Vertical line command
                var y: Double = 0
                scanner.scanDouble(&y)
                currentPoint = CGPoint(x: currentPoint.x, y: y)
                path.addLine(to: currentPoint)
                
            case "L":
                // Line to command
                var x: Double = 0, y: Double = 0
                scanner.scanDouble(&x)
                scanner.scanDouble(&y)
                currentPoint = CGPoint(x: x, y: y)
                path.addLine(to: currentPoint)
                
            case "Z":
                // Close path command
                path.addLine(to: startPoint)
                
            default:
                fatalError("Unknown command: \(commandString)")
            }
        }
    }
    
    return path
}



public func convertSvgPath(_ path: StaticString) throws -> CGPath {
    var index: UnsafePointer<UInt8> = path.utf8Start
    let end = path.utf8Start.advanced(by: path.utf8CodeUnitCount)
    var currentPoint = CGPoint()
    
    let result = CGMutablePath()
    
    while index < end {
        let c = index.pointee
        index = index.successor()
        
        if c == 77 { // M
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Move to \(x), \(y)")
            currentPoint = CGPoint(x: x, y: y)
            result.move(to: currentPoint)
        } else if c == 76 { // L
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Line to \(x), \(y)")
            currentPoint = CGPoint(x: x, y: y)
            result.addLine(to: currentPoint)
        } else if c == 72 { // H
            let x = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Move to \(x), \(y)")
            currentPoint = CGPoint(x: x, y: currentPoint.y)
            result.addLine(to: currentPoint)
        } else if c == 86 { // V
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Move to \(x), \(y)")
            currentPoint = CGPoint(x: currentPoint.x, y: y)
            result.addLine(to: currentPoint)
        } else if c == 67 { // C
            let x1 = try readCGFloat(&index, end: end, separator: 44)
            let y1 = try readCGFloat(&index, end: end, separator: 32)
            let x2 = try readCGFloat(&index, end: end, separator: 44)
            let y2 = try readCGFloat(&index, end: end, separator: 32)
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            currentPoint = CGPoint(x: x, y: y)
            result.addCurve(to: currentPoint, control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
        } else if c == 90 { // Z
            if index != end && index.pointee != 32 {
                throw ParsingError.Generic
            }
        } else if c == 83 { // S
            if index != end && index.pointee != 32 {
                throw ParsingError.Generic
            }
        } else if c == 32 { // space
            continue
        } else {
            throw ParsingError.Generic
        }
    }
    
    return result
}
