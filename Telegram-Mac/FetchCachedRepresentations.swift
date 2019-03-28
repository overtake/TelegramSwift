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

private let cacheThreadPool = ThreadPool(threadCount: 3, threadPriority: 0.1)


public func fetchCachedResourceRepresentation(account: Account, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let representation = representation as? CachedStickerAJpegRepresentation {
        return fetchCachedStickerAJpegRepresentation(account: account, resource: resource, representation: representation)
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
                    subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                    subscriber.putCompletion()
                }
            }
        } catch {
            let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
            subscriber.putError(.generic)
            subscriber.putCompletion()
        }
        return EmptyDisposable
        } |> runOn(Queue.concurrentDefaultQueue())
}




private func fetchCachedStickerAJpegRepresentation(account: Account, resource: MediaResource, representation: CachedStickerAJpegRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return account.postbox.mediaBox.resourceData(resource) |> mapToSignal { resourceData in
        return Signal { subscriber in
            if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
                let image = convertFromWebP(data)?.takeRetainedValue()
                let appGroupName = "6N38VWS5BX.ru.keepcoder.Telegram"
                if let image = image, let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) {
                    var randomId: Int64 = 0
                    arc4random_buf(&randomId, 8)
                    //
                    
                    let directory = "\(containerUrl.path)/\(accountRecordIdPathName(account.id))/cached/"
                    try? FileManager.default.createDirectory(at: URL(fileURLWithPath: directory), withIntermediateDirectories: true, attributes: nil)
                    let path: String = directory + "\(randomId)"
                    //containerUrl + accountRecordIdPathName(account.id)
                    //let path = NSTemporaryDirectory() + "\(randomId)"
                    let url = URL(fileURLWithPath: path)
                    
                    let colorData = NSMutableData()
                    let alphaData = NSMutableData()
                    
                    
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
                    
                    let alphaImage = generateImage(size, contextGenerator: { size, context in
                        context.setFillColor(NSColor.white.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                        context.clip(to: CGRect(origin: CGPoint(), size: size), mask: colorImage)
                        context.setFillColor(NSColor.black.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                    })
                    
                    if let alphaImage = alphaImage, let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypeJPEG, 1, nil), let alphaDestination = CGImageDestinationCreateWithData(alphaData as CFMutableData, kUTTypeJPEG, 1, nil) {
                        CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                        CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                        
                        let colorQuality: Float
                        let alphaQuality: Float
                        if representation.size == nil {
                            colorQuality = 0.6
                            alphaQuality = 0.6
                        } else {
                            colorQuality = 0.5
                            alphaQuality = 0.4
                        }
                        
                        let options = NSMutableDictionary()
                        options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        
                        let optionsAlpha = NSMutableDictionary()
                        optionsAlpha.setObject(alphaQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        
                        CGImageDestinationAddImage(colorDestination, colorImage, options as CFDictionary)
                        CGImageDestinationAddImage(alphaDestination, alphaImage, optionsAlpha as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) && CGImageDestinationFinalize(alphaDestination) {
                            let finalData = NSMutableData()
                            var colorSize: Int32 = Int32(colorData.length)
                            finalData.append(&colorSize, length: 4)
                            finalData.append(colorData as Data)
                            var alphaSize: Int32 = Int32(alphaData.length)
                            finalData.append(&alphaSize, length: 4)
                            finalData.append(alphaData as Data)
                            
                            let _ = try? finalData.write(to: url, options: [.atomic])
                            
                            subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
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
                            subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
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
                return .single(CachedMediaResourceRepresentationResult(temporaryPath: path))
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
                                subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
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
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(cacheThreadPool)
}
