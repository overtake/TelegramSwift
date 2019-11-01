//
//  AnimatedStickerUtils.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Foundation
import SwiftSignalKit
import AVFoundation
import Lottie
import TGUIKit

private func verifyLottieItems(_ items: [Any]?, shapes: Bool = true) -> Bool {
    if let items = items {
        for case let item as [AnyHashable: Any] in items {
            if let type = item["ty"] as? String {
                if type == "rp" || type == "sr" || type == "mm" || type == "gs" {
                    return false
                }
            }
            
            if shapes, let subitems = item["it"] as? [Any] {
                if !verifyLottieItems(subitems, shapes: false) {
                    return false
                }
            }
        }
    }
    return true;
}

private func verifyLottieLayers(_ layers: [AnyHashable: Any]?) -> Bool {
    return true
}

func validateStickerComposition(json: [AnyHashable: Any]) -> Bool {
    guard let tgs = json["tgs"] as? Int, tgs == 1 else {
        return false
    }
    
    return true
}

private let writeQueue = DispatchQueue(label: "assetWriterQueue")


func convertCompressedLottieToCombinedMp4(data: Data, size: CGSize) -> Signal<String, NoError> {
    return Signal({ subscriber in
        let startTime = CACurrentMediaTime()
        let decompressedData = TGGUnzipData(data, 8 * 1024 * 1024)
        if let decompressedData = decompressedData, let json = (try? JSONSerialization.jsonObject(with: decompressedData, options: [])) as? [AnyHashable: Any] {
            if let _ = json["tgs"], let model = try? JSONDecoder().decode(Animation.self, from: decompressedData) {
                
                let startFrame = Int32(model.startFrame)
                let endFrame = Int32(model.endFrame)
                
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId).mp4"
                let url = URL(fileURLWithPath: path)
                
                let videoSize = CGSize(width: size.width, height: size.height * 2.0)
                let scale = size.width / 512.0
                
                if let assetWriter = try? AVAssetWriter(outputURL: url, fileType: AVFileType.mp4) {
                    let videoSettings: [String: AnyObject] = [AVVideoCodecKey : AVVideoCodecH264 as AnyObject, AVVideoWidthKey : videoSize.width as AnyObject, AVVideoHeightKey : videoSize.height as AnyObject]
                    
                    let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
                    let sourceBufferAttributes = [(kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32ARGB),
                                                  (kCVPixelBufferWidthKey as String): Float(videoSize.width),
                                                  (kCVPixelBufferHeightKey as String): Float(videoSize.height)] as [String : Any]
                    let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: sourceBufferAttributes)
                    
                    assetWriter.add(assetWriterInput)
                    
                    if assetWriter.startWriting() {
                        print("startedWriting at \(CACurrentMediaTime() - startTime)")
                        assetWriter.startSession(atSourceTime: CMTime.zero)
                        
                        var currentFrame: Int32 = 0
                        writeQueue.async {
                            let pointer: Unmanaged<AnimationContainer>
                            CATransaction.begin()
                            CATransaction.lock()
                            pointer = Unmanaged.passRetained(AnimationContainer(animation: model, imageProvider: BundleImageProvider(bundle: Bundle.main, searchPath: nil)))
                            pointer.takeUnretainedValue().frame = NSMakeRect(0, 0, size.width, size.height)
                            CATransaction.unlock()
                            CATransaction.commit()

                            let singleContext = DrawingContext(size: size, scale: 1.0, clear: true)
                            let context = DrawingContext(size: videoSize, scale: 1.0, clear: false)
                            
                            let fps: Int32 = Int32(model.framerate)
                            let frameDuration = CMTimeMake(value: 1, timescale: fps)
                            
                            assetWriterInput.requestMediaDataWhenReady(on: writeQueue) {
                                while assetWriterInput.isReadyForMoreMediaData && startFrame + currentFrame < endFrame {
                                    let lastFrameTime = CMTimeMake(value: Int64(currentFrame - startFrame), timescale: fps)
                                    let presentationTime = currentFrame == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                                    
                                    let renderTime = CACurrentMediaTime()
                                    singleContext.withFlippedContext(vertical: true, { context in
                                        context.clear(CGRect(origin: CGPoint(), size: size))
                                        context.saveGState()
                                        context.scaleBy(x: scale, y: scale)
                                        CATransaction.begin()
                                        pointer.takeUnretainedValue().renderFrame(startFrame + currentFrame, in: context)
                                        CATransaction.commit()
                                        context.restoreGState()
                                    })
                                    
                                    let image = singleContext.generateImage()
                                    let alphaImage = generateTintedImage(image: image, color: .white, backgroundColor: .black, flipVertical: false)
                                    context.withContext { context in
                                        context.setFillColor(NSColor.white.cgColor)
                                        context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height), size: videoSize))
                                        if let image = image {
                                            context.draw(image, in: CGRect(origin: CGPoint(x: 0.0, y: size.height), size: size))
                                        }
                                        if let alphaImage = alphaImage {
                                            context.draw(alphaImage, in: CGRect(origin: CGPoint(), size: size))
                                        }
                                    }
                                    
                                    if let image = context.generateImage() {
                                        if let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                                            let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
                                            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, pixelBufferPointer)
                                            if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                                                fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
                                                
                                                pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                                                pixelBufferPointer.deinitialize(count: 1)
                                            } else {
                                                break
                                            }
                                            
                                            pixelBufferPointer.deallocate()
                                        } else {
                                            break
                                        }
                                    }
                                    currentFrame += 1
                                }
                                
                                if startFrame + currentFrame == endFrame {
                                    assetWriterInput.markAsFinished()
                                    CATransaction.begin()
                                    pointer.release()
                                    CATransaction.commit()
                                    assetWriter.finishWriting {
                                        subscriber.putNext(path)
                                        subscriber.putCompletion()
                                       
                                        print("animation render time \(CACurrentMediaTime() - startTime)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return EmptyDisposable
    })
}

private func fillPixelBufferFromImage(_ image: CGImage, pixelBuffer: CVPixelBuffer) {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    context?.draw(image, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
}
