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

public func fetchCachedResourceRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let representation = representation as? CachedStickerAJpegRepresentation {
        return fetchCachedStickerAJpegRepresentation(account: account, resource: resource, resourceData: resourceData, representation: representation)
    } else if let representation = representation as? CachedScaledImageRepresentation {
        return fetchCachedScaledImageRepresentation(account: account, resource: resource, resourceData: resourceData, representation: representation)
    } else if let representation = representation as? CachedVideoFirstFrameRepresentation {
        return fetchCachedVideoFirstFrameRepresentation(account: account, resource: resource, resourceData: resourceData, representation: representation)
    } else if let representation = representation as? CachedScaledVideoFirstFrameRepresentation {
        return fetchCachedScaledVideoFirstFrameRepresentation(account: account, resource: resource, resourceData: resourceData, representation: representation)
    }
    return .never()
}

private func accountRecordIdPathName(_ id: AccountRecordId) -> String {
    return "account-\(UInt64(bitPattern: id.int64))"
}

private func fetchCachedStickerAJpegRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedStickerAJpegRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
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
    }) |> runOn(account.graphicsThreadPool)
}

private func fetchCachedScaledImageRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedScaledImageRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
  
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = NSImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = representation.size
                
                let colorImage = generateImage(size, contextGenerator: { size, context in
                    context.setBlendMode(.copy)
                    context.draw(image.precomposed(), in: CGRect(origin: CGPoint(), size: size))
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
    }) |> runOn(account.graphicsThreadPool)
}

private func fetchCachedVideoFirstFrameRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedVideoFirstFrameRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal { subscriber in
        if resourceData.complete {
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
                    CGImageDestinationSetProperties(colorDestination, nil)
                    
                    let colorQuality: Float = 0.6
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, fullSizeImage, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
                
                subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                subscriber.putCompletion()
            } catch (let e) {
                print("\(e)")
            }
        }
        return EmptyDisposable
        } |> runOn(account.graphicsThreadPool)
}


private func fetchCachedScaledVideoFirstFrameRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedScaledVideoFirstFrameRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedVideoFirstFrameRepresentation(), complete: true) |> mapToSignal { firstFrame -> Signal<CachedMediaResourceRepresentationResult, NoError> in
        return Signal({ subscriber in
            if let data = try? Data(contentsOf: URL(fileURLWithPath: firstFrame.path), options: [.mappedIfSafe]) {
                if let image = NSImage(data: data)?.precomposed() {
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
        }) |> runOn(account.graphicsThreadPool)
    }
}
