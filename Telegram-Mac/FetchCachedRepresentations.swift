//
//  FetchCachedRepresentations.swift
//  Telegram-Mac
//
//  Created by keepcoder on 24/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TGUIKit
import RLottie

private let cacheThreadPool = ThreadPool(threadCount: 1, threadPriority: 0.1)


public func fetchCachedResourceRepresentation(account: Account, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let representation = representation as? CachedStickerAJpegRepresentation {
        return fetchCachedStickerAJpegRepresentation(account: account, resource: resource, representation: representation)
    } else if let representation = representation as? CachedAnimatedStickerRepresentation {
        return fetchCachedAnimatedStickerRepresentation(account: account, resource: resource, representation: representation)
    } else if let representation = representation as? CachedScaledImageRepresentation {
        return fetchCachedScaledImageRepresentation(account: account, resource: resource, representation: representation)
    } else if representation is CachedVideoFirstFrameRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
            |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                if data.complete {
                    return fetchCachedVideoFirstFrameRepresentation(account: account, resource: resource, resourceData: data)
                        |> `catch` { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                            return .complete()
                    }
                } else if let size = resource.size {
                    return videoFirstFrameData(account: account, resource: resource, chunkSize: min(size, 192 * 1024))
                } else {
                    return .complete()
                }
        }
    } else if let representation = representation as? CachedScaledVideoFirstFrameRepresentation {
        return fetchCachedScaledVideoFirstFrameRepresentation(account: account, resource: resource, representation: representation)
    } else if let representation = representation as? CachedDiceRepresentation {
        if let diceCache = account.diceCache {
            return diceCache.interactiveSymbolData(baseSymbol: representation.emoji, side: representation.value, synchronous: false) |> mapToSignal { data in
                return fetchCachedDiceRepresentation(account: account, data: data.0, representation: representation)
            }
        } else {
            return .complete()
        }
    } else if let representation = representation as? CachedBlurredWallpaperRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
            |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                if !data.complete {
                    return .complete()
                }
                return fetchCachedBlurredWallpaperRepresentation(account: account, resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedPatternWallpaperMaskRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
            |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                if !data.complete {
                    return .complete()
                }
                return fetchCachedPatternWallpaperMaskRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    }



    return .never()
}


public func fetchCachedSharedResourceRepresentation(accountManager: AccountManager, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    fatalError()
}


private func fetchCachedPatternWallpaperMaskRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedPatternWallpaperMaskRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            
            var svgPath: String?
            
            let path = NSTemporaryDirectory() + "\(arc4random64())"
            let url = URL(fileURLWithPath: path)
            
            if let data = TGGUnzipData(data, 8 * 1024 * 1024), data.count > 5, let string = String(data: data.subdata(in: 0 ..< 5), encoding: .utf8), string == "<?xml" {
                let size = representation.size ?? CGSize(width: 1440.0, height: 2960.0).aspectFilled(NSMakeSize(800, 800))
                
                if let image = drawSvgImageNano(data, size)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    if let alphaDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                        CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                        
                        let colorQuality: Float = 0.87
                        
                        let options = NSMutableDictionary()
                        options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        
                        CGImageDestinationAddImage(alphaDestination, image, options as CFDictionary)
                        if CGImageDestinationFinalize(alphaDestination) {
                           svgPath = path
                        }
                    }
                }
            } else if let image = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let size = representation.size.flatMap { image.backingSize.aspectFitted($0) } ?? image.size.aspectFilled(NSMakeSize(800, 800))
                
                let alphaImage = generateImage(size, contextGenerator: { size, context in
                    context.setFillColor(NSColor.black.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    context.clip(to: CGRect(origin: CGPoint(), size: size), mask: image)
                    context.setFillColor(NSColor.white.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }, scale: representation.size != nil ? 2.0 : 1.0)
                
                if let alphaImage = alphaImage, let alphaDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.87
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(alphaDestination, alphaImage, options as CFDictionary)
                    if CGImageDestinationFinalize(alphaDestination) {
                        svgPath = path
                    }
                }
            }
            
            if let path = svgPath {
                if let settings = representation.settings {
                    if let image = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        let image = generateImage(image.size, contextGenerator: { size, ctx in
                            let imageRect = NSMakeRect(0, 0, size.width, size.height)
                            let colors:[NSColor]
                            let color: NSColor
                            var intensity: CGFloat = 0.5
                            
                            if let combinedColor = settings.color, settings.bottomColor == nil {
                                let combinedColor = NSColor(UInt32(combinedColor))
                                if let i = settings.intensity {
                                    intensity = CGFloat(i) / 100.0
                                }
                                color = combinedColor.withAlphaComponent(1.0)
                                intensity = combinedColor.alpha
                                colors = [color]
                            } else if let t = settings.color, let b = settings.bottomColor {
                                let top = NSColor(UInt32(t))
                                let bottom = NSColor(UInt32(b))
                                color = top.withAlphaComponent(1.0)
                                if let i = settings.intensity {
                                    intensity = CGFloat(i) / 100.0
                                }
                                colors = [top, bottom].reversed().map { $0.withAlphaComponent(1.0) }
                            } else {
                                colors = [NSColor(rgb: 0xd6e2ee, alpha: 0.5)]
                                color = NSColor(rgb: 0xd6e2ee, alpha: 0.5)
                            }
                            
                            ctx.setBlendMode(.copy)
                            if colors.count == 1 {
                                ctx.setFillColor(color.cgColor)
                                ctx.fill(imageRect)
                            } else {
                                let gradientColors = colors.map { $0.cgColor } as CFArray
                                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                                
                                var locations: [CGFloat] = []
                                for i in 0 ..< colors.count {
                                    locations.append(delta * CGFloat(i))
                                }
                                let colorSpace = CGColorSpaceCreateDeviceRGB()
                                let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                                
                                ctx.saveGState()
                                ctx.translateBy(x: imageRect.width / 2.0, y: imageRect.height / 2.0)
                                ctx.rotate(by: CGFloat(settings.rotation ?? 0) * CGFloat.pi / -180.0)
                                ctx.translateBy(x: -imageRect.width / 2.0, y: -imageRect.height / 2.0)
                                
                                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: imageRect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                                ctx.restoreGState()
                            }
                            
                            ctx.setBlendMode(.normal)
                            ctx.interpolationQuality = .medium
                            
                            ctx.clip(to: imageRect, mask: image)
                            if colors.count == 1 {
                                ctx.setFillColor(patternColor(for: color, intensity: intensity).cgColor)
                                ctx.fill(imageRect)
                            } else {
                                let gradientColors = colors.map { patternColor(for: $0, intensity: intensity).cgColor } as CFArray
                                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                                
                                var locations: [CGFloat] = []
                                for i in 0 ..< colors.count {
                                    locations.append(delta * CGFloat(i))
                                }
                                let colorSpace = CGColorSpaceCreateDeviceRGB()
                                let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                                
                                ctx.translateBy(x: imageRect.width / 2.0, y: imageRect.height / 2.0)
                                ctx.rotate(by: CGFloat(settings.rotation ?? 0) * CGFloat.pi / -180.0)
                                ctx.translateBy(x: -imageRect.width / 2.0, y: -imageRect.height / 2.0)
                                
                                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: imageRect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                            }
                        })!
                        
                        let finalPath = NSTemporaryDirectory() + "\(arc4random64())"
                        let url = URL(fileURLWithPath: finalPath)
                        
                        if let dest = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                            CGImageDestinationSetProperties(dest, [:] as CFDictionary)
                            
                            let colorQuality: Float = 0.87
                            
                            let options = NSMutableDictionary()
                            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                            
                            CGImageDestinationAddImage(dest, image, options as CFDictionary)
                            if CGImageDestinationFinalize(dest) {
                                try? FileManager.default.removeItem(atPath: path)
                                subscriber.putNext(.temporaryPath(finalPath))
                                subscriber.putCompletion()
                            }
                        }
                    }
                } else {
                    subscriber.putNext(.temporaryPath(path))
                    subscriber.putCompletion()
                }
            }
            
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}


private func accountRecordIdPathName(_ id: AccountRecordId) -> String {
    return "account-\(UInt64(bitPattern: id.int64))"
}


public enum FetchVideoFirstFrameError {
    case generic
}


private func videoFirstFrameData(account: Account, resource: MediaResource, chunkSize: Int) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let size = resource.size {
        return account.postbox.mediaBox.resourceData(resource, size: size, in: 0 ..< min(size, chunkSize))
            |> mapToSignal { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                 return account.postbox.mediaBox.resourceData(resource, option: .incremental(waitUntilFetchStatus: false), attemptSynchronously: false)
                    |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                        
                        return fetchCachedVideoFirstFrameRepresentation(account: account, resource: resource, resourceData: data)
                            |> `catch` { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                                if chunkSize > size {
                                    return .complete()
                                } else {
                                    return videoFirstFrameData(account: account, resource: resource, chunkSize: chunkSize + chunkSize)
                                }
                        }
                }
        }
    } else {
        return .complete()
    }
}



private func fetchCachedVideoFirstFrameRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData) -> Signal<CachedMediaResourceRepresentationResult, FetchVideoFirstFrameError> {
    return Signal { subscriber in
        let tempFilePath = NSTemporaryDirectory() + "\(arc4random()).mov"
        do {
            let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
            try FileManager.default.linkItem(atPath: resourceData.path, toPath: tempFilePath)
            
            let asset = AVAsset(url: URL(fileURLWithPath: tempFilePath))
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.maximumSize = CGSize(width: 800.0, height: 800.0)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let fullSizeImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
            
            
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            let path = NSTemporaryDirectory() + "\(randomId)"
            let url = URL(fileURLWithPath: path)
            
            if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                
                let colorQuality: Float = 0.6
                
                let options = NSMutableDictionary()
                options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                
                CGImageDestinationAddImage(colorDestination, fullSizeImage, options as CFDictionary)
                if CGImageDestinationFinalize(colorDestination) {
                    subscriber.putNext(.temporaryPath(path))
                    subscriber.putCompletion()
                }
            }
        } catch {
            let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
            subscriber.putError(.generic)
            subscriber.putCompletion()
        }
        return EmptyDisposable
        } |> runOn(cacheThreadPool)
}


private func fetchCachedAnimatedStickerRepresentation(account: Account, resource: MediaResource, representation: CachedAnimatedStickerRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
   
    let data: Signal<MediaResourceData, NoError>
    if let resource = resource as? LocalBundleResource {
        data = Signal { subscriber in
            if let path = Bundle.main.path(forResource: resource.name, ofType: resource.ext), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                subscriber.putNext(MediaResourceData(path: path, offset: 0, size: data.count, complete: true))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    } else {
        data = account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
    }

    return data |> deliverOn(lottieThreadPool) |> map { resourceData -> (CGImage?, Data?, MediaResourceData) in
        if resourceData.complete {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                if !representation.thumb {
                    var dataValue: Data! = TGGUnzipData(data, 8 * 1024 * 1024)
                    if dataValue == nil {
                        dataValue = data
                    }
                    if let json = String(data: transformedWithFitzModifier(data: dataValue, fitzModifier: representation.fitzModifier), encoding: .utf8), json.length > 0 {
                        let rlottie = RLottieBridge(json: json, key: resourceData.path)
                        
                        let unmanaged = rlottie?.renderFrame(0, width: Int(representation.size.width * 2), height: Int(representation.size.height * 2))
                        let colorImage = unmanaged?.takeRetainedValue()
                        return (colorImage, nil, resourceData)
                    }
                } else {
                    return (nil, data, resourceData)
                }
            }
        }
        return (nil, nil, resourceData)
    } |> runOn(cacheThreadPool) |> mapToSignal { frame, data, resourceData in
        if resourceData.complete {
            if !representation.thumb {
                let path = NSTemporaryDirectory() + "\(arc4random64())"
                let url = URL(fileURLWithPath: path)
                
                let colorData = NSMutableData()
                if let colorImage = frame, let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypePNG, 1, nil){
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float
                    colorQuality = 0.4
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    CGImageDestinationAddImage(colorDestination, colorImage, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination)  {
                        try? colorData.write(to: url, options: .atomic)
                        return .single(.temporaryPath(path))
                    }
                } else {
                    return .complete()
                }
            } else if let data = data {
                
                let path = NSTemporaryDirectory() + "\(arc4random64())"
                let url = URL(fileURLWithPath: path)
                
                let colorData = NSMutableData()
                let umnanaged = convertFromWebP(data)
                var image = umnanaged?.takeUnretainedValue() ?? NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                umnanaged?.release()
                
                if image == nil, let data = TGGUnzipData(data, 8 * 1024 * 1024) {
                    if let json = String(data: transformedWithFitzModifier(data: data, fitzModifier: representation.fitzModifier), encoding: .utf8), json.length > 0 {
                        let rlottie = RLottieBridge(json: json, key: resourceData.path)
                        let unmanaged = rlottie?.renderFrame(0, width: Int(representation.size.width * 2), height: Int(representation.size.height * 2))
                        image = unmanaged?.takeRetainedValue()
                    }
                }
                
                if let image = image, let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypePNG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float
                    colorQuality = 0.4
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    CGImageDestinationAddImage(colorDestination, image, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination)  {
                        try? colorData.write(to: url, options: .atomic)
                        return .single(.temporaryPath(path))
                    }
                } else {
                    return .complete()
                }
            }
        }
        return .never()
    }
}

private func fetchCachedStickerAJpegRepresentation(account: Account, resource: MediaResource, representation: CachedStickerAJpegRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return account.postbox.mediaBox.resourceData(resource) |> mapToSignal { resourceData in
        return Signal { subscriber in
            if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                let unmanaged = convertFromWebP(data)
                let image = unmanaged?.takeUnretainedValue()
                unmanaged?.release()
                let appGroupName = ApiEnvironment.group
                if let image = image, let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) {
                    var randomId: Int64 = 0
                    arc4random_buf(&randomId, 8)
                    let directory = "\(containerUrl.path)/\(accountRecordIdPathName(account.id))/cached/"
                    try? FileManager.default.createDirectory(at: URL(fileURLWithPath: directory), withIntermediateDirectories: true, attributes: nil)
                    let path: String = directory + "\(randomId)"
                    let url = URL(fileURLWithPath: path)
                    
                    let colorData = NSMutableData()
                    
                    
                    let size:CGSize
                    if let s = representation.size {
                        size = s
                    } else {
                        size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                    }
                    
                    let colorImage: CGImage
                    if let _ = representation.size {
                        colorImage = generateImage(size, contextGenerator: { size, context in
                            context.setBlendMode(.copy)
                            context.draw(image, in: CGRect(origin: CGPoint(), size: size))
                        })!
                    } else {
                        colorImage = image
                    }
                    if let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypePNG, 1, nil) {
                        CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                        
                        let colorQuality: Float
                        if representation.size == nil {
                            colorQuality = 0.6
                        } else {
                            colorQuality = 0.3
                        }
                        
                        let options = NSMutableDictionary()
                        options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        
                        CGImageDestinationAddImage(colorDestination, colorImage, options as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) {
                            let _ = try? colorData.write(to: url, options: [.atomic])
                            subscriber.putNext(.temporaryPath(path))
                            subscriber.putCompletion()
                        }
                    } else {
                        subscriber.putCompletion()
                    }
                }
            }
            return EmptyDisposable
        } |> runOn(cacheThreadPool)
    }
}

private func fetchCachedScaledImageRepresentation(account: Account, resource: MediaResource, representation: CachedScaledImageRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return account.postbox.mediaBox.resourceData(resource) |> mapToSignal { resourceData in
        return Signal { subscriber in
            if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                if let image = NSImage(data: data) {
                    var randomId: Int64 = 0
                    arc4random_buf(&randomId, 8)
                    let path = NSTemporaryDirectory() + "\(randomId)"
                    let url = URL(fileURLWithPath: path)
                    
                    let size = representation.size
                    
                    let colorImage = generateImage(size, contextGenerator: { size, context in
                        context.setBlendMode(.copy)
                        if let image = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                            context.draw(image, in: CGRect(origin: CGPoint(), size: size))
                        }
                    })!
                    
                    if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                        CGImageDestinationSetProperties(colorDestination, nil)
                        
                        let colorQuality: Float = 0.5
                        
                        let options = NSMutableDictionary()
                        options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        
                        CGImageDestinationAddImage(colorDestination, colorImage, options as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) {
                            subscriber.putNext(.temporaryPath(path))
                            subscriber.putCompletion()
                        }
                    }
                }
            }
            return EmptyDisposable
        } |> runOn(cacheThreadPool)
    }
}

private func fetchCachedVideoFirstFrameRepresentation(account: Account, resource: MediaResource, representation: CachedVideoFirstFrameRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return account.postbox.mediaBox.resourceRangesStatus(resource) |> mapToSignal { _ in
        return account.postbox.mediaBox.resourceData(resource) |> take(1)
    } |> runOn(cacheThreadPool) |> mapToSignal { resourceData in
        let tempFilePath = NSTemporaryDirectory() + "\(resourceData.path.nsstring.lastPathComponent).mp4"
        let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
        try? FileManager.default.linkItem(atPath: resourceData.path, toPath: tempFilePath)
        
        let asset = AVAsset(url: URL(fileURLWithPath: tempFilePath))
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.maximumSize = CGSize(width: 800.0, height: 800.0)
        imageGenerator.appliesPreferredTrackTransform = true
        let fullSizeImage = try? imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        let path = NSTemporaryDirectory() + "\(randomId)"
        let url = URL(fileURLWithPath: path)
        
        if let fullSizeImage = fullSizeImage, let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
            CGImageDestinationSetProperties(colorDestination, nil)
            
            let colorQuality: Float = 0.6
            
            let options = NSMutableDictionary()
            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
            
            CGImageDestinationAddImage(colorDestination, fullSizeImage, options as CFDictionary)
            if CGImageDestinationFinalize(colorDestination) {
                return .single(.temporaryPath(path))
            }
        }
        return .never()
    }
}


private func fetchCachedScaledVideoFirstFrameRepresentation(account: Account, resource: MediaResource, representation: CachedScaledVideoFirstFrameRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return account.postbox.mediaBox.resourceData(resource) |> mapToSignal { resourceData in
        return account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedVideoFirstFrameRepresentation(), complete: true) |> mapToSignal { firstFrame -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return Signal({ subscriber in
                if let data = try? Data(contentsOf: URL(fileURLWithPath: firstFrame.path), options: [.mappedIfSafe]) {
                    if let image = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        var randomId: Int64 = 0
                        arc4random_buf(&randomId, 8)
                        let path = NSTemporaryDirectory() + "\(randomId)"
                        let url = URL(fileURLWithPath: path)
                        
                        let size = representation.size
                        
                        let colorImage = generateImage(size, contextGenerator: { size, context in
                            context.setBlendMode(.copy)
                            context.draw(image, in: CGRect(origin: CGPoint(), size: size))
                        })!
                        
                        if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                            CGImageDestinationSetProperties(colorDestination, nil)
                            
                            let colorQuality: Float = 0.5
                            
                            let options = NSMutableDictionary()
                            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                            
                            CGImageDestinationAddImage(colorDestination, colorImage, options as CFDictionary)
                            if CGImageDestinationFinalize(colorDestination) {
                                subscriber.putNext(.temporaryPath(path))
                                subscriber.putCompletion()
                            }
                        }
                    }
                }
                return EmptyDisposable
            }) |> runOn(cacheThreadPool)
        }
    }
    
}



private func fetchCachedBlurredWallpaperRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedBlurredWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                if let colorImage = blurredImage(image, radius: 70), let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.5
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(.temporaryPath(path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(cacheThreadPool)
}


private func fetchCachedDiceRepresentation(account: Account, data: Data, representation: CachedDiceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal { subscriber in
        
        var dataValue: Data! = TGGUnzipData(data, 8 * 1024 * 1024)
        if dataValue == nil {
            dataValue = data
        }
        if let json = String(data: dataValue, encoding: .utf8) {
            let rlottie = RLottieBridge(json: json, key: representation.emoji + representation.value)
            if let rlottie = rlottie {
                let unmanaged = rlottie.renderFrame(rlottie.endFrame() - 1, width: Int(representation.size.width * 2), height: Int(representation.size.height * 2))
                let colorImage = unmanaged.takeRetainedValue()
                
                let path = NSTemporaryDirectory() + "\(arc4random64())"
                let url = URL(fileURLWithPath: path)
                
                let colorData = NSMutableData()
                if let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypePNG, 1, nil){
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    let colorQuality: Float
                    colorQuality = 0.4
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    CGImageDestinationAddImage(colorDestination, colorImage, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination)  {
                        try? colorData.write(to: url, options: .atomic)
                        subscriber.putNext(.temporaryPath(path))
                        subscriber.putCompletion()
                    }
                } else {
                    subscriber.putCompletion()
                }
            } else {
                subscriber.putCompletion()
            }
            
        }
        
        return ActionDisposable {
            
        }
    } |> runOn(lottieThreadPool)
}

func getAnimatedStickerThumb(data: Data) -> Signal<String?, NoError> {
    
    return .single(data) |> deliverOn(lottieThreadPool) |> map { data -> String? in
        var dataValue: Data! = TGGUnzipData(data, 8 * 1024 * 1024)
        if dataValue == nil {
            dataValue = data
        }
        if let json = String(data: transformedWithFitzModifier(data: dataValue, fitzModifier: nil), encoding: .utf8), json.length > 0 {
            let rlottie = RLottieBridge(json: json, key: "\(arc4random())")
            let unmanaged = rlottie?.renderFrame(0, width: Int(512 * 2), height: Int(512 * 2))
            let colorImage = unmanaged?.takeRetainedValue()
            
            if let image = colorImage {
                let rep = NSBitmapImageRep(cgImage: image)
                let data = rep.representation(using: .png, properties: [:])
                let path = NSTemporaryDirectory() + "temp_as_\(arc4random64()).png"
                try? data?.write(to: URL(fileURLWithPath: path))
                return path
            }
        }
        return nil
    } |> deliverOnMainQueue
}
