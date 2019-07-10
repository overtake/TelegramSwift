//
//  FetchCachedRepresentations.swift
//  Telegram-Mac
//
//  Created by keepcoder on 24/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit
import RLottieMac

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
    } else if let representation = representation as? CachedBlurredWallpaperRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
            |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                if !data.complete {
                    return .complete()
                }
                return fetchCachedBlurredWallpaperRepresentation(account: account, resource: resource, resourceData: data, representation: representation)
        }
    }

    return .never()
}


public func fetchCachedSharedResourceRepresentation(accountManager: AccountManager, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    fatalError()
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
    return account.postbox.mediaBox.resourceData(resource) |> deliverOn(lottieThreadPool) |> map { resourceData -> (CGImage?, Data?, MediaResourceData) in
        if resourceData.complete {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                if !representation.thumb {
                    var dataValue: Data! = TGGUnzipData(data)
                    if dataValue.isEmpty {
                        dataValue = data
                    }
                    if let json = String(data: dataValue, encoding: .utf8), json.length > 0 {
                        let rlottie = RLottieBridge(json: json, key: resourceData.path)
                        
                        let unmanaged = rlottie?.renderFrame(0, width: 240 * 2, height: 240 * 2)
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
                
                if image == nil {
                    if let json = String(data: TGGUnzipData(data)!, encoding: .utf8), json.length > 0 {
                        let rlottie = RLottieBridge(json: json, key: resourceData.path)
                        let unmanaged = rlottie?.renderFrame(0, width: 60 * 2, height: 60 * 2)
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
                let appGroupName = "6N38VWS5BX.ru.keepcoder.Telegram"
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


