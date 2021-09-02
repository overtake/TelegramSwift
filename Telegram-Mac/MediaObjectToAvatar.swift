//
//  StickerToMp4.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.08.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import TGUIKit
import RLottie
import CoreMedia
import libwebp

private func buffer(from image: CGImage) -> CVPixelBuffer? {
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer : CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard (status == kCVReturnSuccess) else {
      return nil
    }

    CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

    let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
    
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
    
    context?.clear(rect)
    context?.setFillColor(.white)
    context?.fill(rect)
    context?.draw(image, in: rect)
    CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    return pixelBuffer
}




private final class StickerToMp4Context {
    private let statusPromise: ValuePromise<StickerToMp4.Status> = ValuePromise(ignoreRepeated: true)
    
    var statusValue: Signal<StickerToMp4.Status, NoError> {
        return statusPromise.get()
    }
    
    static let queue: Queue = Queue(name: "org.telegram.sticker-to-mp4")
    
    private var status: StickerToMp4.Status = .initializing("") {
        didSet {
            statusPromise.set(status)
        }
    }
    
    
    final class Export {
        private let writter: AVAssetWriter
        private let writerInput: AVAssetWriterInput
        private let path: String
        private let adaptor: AVAssetWriterInputPixelBufferAdaptor

        init() throws {
            self.path = NSTemporaryDirectory() + "tgs_\(arc4random()).mp4"
            self.writter = try .init(url: URL.init(fileURLWithPath: path), fileType: .mov)
            let settings:[String: Any] = [AVVideoWidthKey: NSNumber(value: 640), AVVideoHeightKey: NSNumber(value: 640), AVVideoCodecKey: AVVideoCodecH264];
            self.writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            self.adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
            self.writter.add(self.writerInput)
        }
        
        func start() {
            writter.startWriting()
            writter.startSession(atSourceTime: CMTime.zero)
        }
        
        func append(_ pixelBuffer: CVPixelBuffer, time: CMTime) {
            while !writerInput.isReadyForMoreMediaData {
                
            }
            self.adaptor.append(pixelBuffer, withPresentationTime: time)

        }
        
        func finish(_ complete:@escaping(String)->Void) {
            writerInput.markAsFinished()
            let path = self.path
            writter.finishWriting {
                complete(path)
            }
        }
    }
    
    private let export: Export?
    
    private let dataDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let fileReference: FileMediaReference
    private let context: AccountContext
    init(context: AccountContext, fileReference: FileMediaReference) {
        self.export = try? Export()
        self.context = context
        self.fileReference = fileReference
    }
    
    deinit {
        dataDisposable.dispose()
        fetchDisposable.dispose()
    }
    
    func start() {
        let signal = context.account.postbox.mediaBox.resourceData(fileReference.media.resource)
            |> deliverOn(StickerToMp4Context.queue)
            |> filter { $0.complete }
            |> map {
                $0.path
            }
        
        dataDisposable.set(signal.start(next: { [weak self] path in
            if let data = try? Data(contentsOf: URL.init(fileURLWithPath: path)) {
                if let data = TGGUnzipData(data, 8 * 1024 * 1024) {
                    if let json = String(data: data, encoding: .utf8) {
                        if let bridge = RLottieBridge(json: json, key: "\(arc4random())") {
                            self?.process(bridge)
                        }
                    }
                }
            }
        }))
        fetchDisposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: fileReference).start())
    }
    
    private func process(_ rlottie: RLottieBridge) -> Void {
        
        let image = rlottie.renderFrame(rlottie.startFrame(), width: 640, height: 640).takeRetainedValue()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        let thumbPath = NSTemporaryDirectory() + "\(randomId)"
        let url = URL(fileURLWithPath: thumbPath)
        
        if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
            CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
            
            let colorQuality: Float = 0.6
            
            let options = NSMutableDictionary()
            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
            
            CGImageDestinationAddImage(colorDestination, image, options as CFDictionary)
            CGImageDestinationFinalize(colorDestination)
        }
        
        self.status = .initializing(thumbPath)
        export?.start()

        let fps = rlottie.fps()
        let effectiveFps = min(30, fps)
        
        let framesCount = rlottie.endFrame() - rlottie.startFrame()
        var frame: Int32 = rlottie.startFrame()
        var index: Int32 = 0
        while true {
            let image = rlottie.renderFrame(frame, width: 640, height: 640).takeRetainedValue()
            let pixelBuffer = buffer(from: image)!
            
            let frameTime: CMTime  = CMTimeMake(value: 20, timescale: 600);
            let lastTime: CMTime = CMTimeMake(value: Int64(index) * 20, timescale: 600);
            var presentTime: CMTime = CMTimeAdd(lastTime, frameTime);
            if frame == rlottie.startFrame() {
                presentTime = CMTimeMake(value: 0, timescale: 600);
            }
            
            export?.append(pixelBuffer, time: presentTime)
            
            if frame % Int32(round(Float(fps) / Float(effectiveFps))) != 0 {
                frame += 1
            }
            frame += 1
            index += 1
            if frame > framesCount {
                break
            }
            self.status = .converting(min((Float(frame) / Float(framesCount)), 1))
        }
        
        export?.finish({ [weak self] path in
            self?.status = .done(path, thumbPath)
        })
    }
    
    func cancel() {
        
    }
        
}

private final class StickerToMp4 {
    
    enum Status : Equatable {
        case initializing(String)
        case converting(Float)
        case done(String, String)
        case failed
    }
    
    private let context:QueueLocalObject<StickerToMp4Context>
    init(context _context: AccountContext, fileReference: FileMediaReference) {
        self.context = .init(queue: StickerToMp4Context.queue, generate: {
            return StickerToMp4Context(context: _context, fileReference: fileReference)
        })
    }
    
    
    func start() {
        self.context.with {
            $0.start()
        }
    }
    
    func cancel() {
        self.context.with {
            $0.cancel()
        }
    }
    
    var status:Signal<Status, NoError> {
        return self.context.signalWith { context, subscriber in
            return context.statusValue.start(next: { next in
                subscriber.putNext(next)
            }, completed: {
                subscriber.putCompletion()
            })
        }
    }
}

private final class FetchVideoToFile {
    
    private let statusValue: ValuePromise<String> = ValuePromise()
    var status:Signal<String, NoError> {
        return statusValue.get()
    }
    private let context: AccountContext
    private let file: TelegramMediaFile
    
    private let disposable = MetaDisposable()
    private let dataDisposable = MetaDisposable()
    init(context: AccountContext, file: TelegramMediaFile) {
        self.context = context
        self.file = file
    }
    
    deinit {
        disposable.dispose()
        dataDisposable.dispose()
    }
    
    func start() {
        disposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: file)).start())
        
        let signal = context.account.postbox.mediaBox.resourceData(file.resource) |> filter {
            $0.complete
        } |> map {
            return $0.path
        }
        
        dataDisposable.set(signal.start(next: { [weak self] path in
            let temp = NSTemporaryDirectory() + "tgs_\(arc4random()).mp4"
            try? FileManager.default.copyItem(atPath: path, toPath: temp)
            self?.statusValue.set(temp)
        }))
    }
}

private final class FetchStickerToImage {
    
    private let statusValue: ValuePromise<NSImage> = ValuePromise()
    var status:Signal<NSImage, NoError> {
        return statusValue.get()
    }
    private let context: AccountContext
    private let file: TelegramMediaFile
    
    private let disposable = MetaDisposable()
    private let dataDisposable = MetaDisposable()
    init(context: AccountContext, file: TelegramMediaFile) {
        self.context = context
        self.file = file
    }
    
    deinit {
        disposable.dispose()
        dataDisposable.dispose()
    }
    
    func start() {
        disposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: file)).start())
        
        let signal = context.account.postbox.mediaBox.resourceData(file.resource) |> filter {
            $0.complete
        } |> map {
            return $0.path
        }
        
        dataDisposable.set(signal.start(next: { [weak self] path in
            if let data = try? Data.init(contentsOf: URL(fileURLWithPath: path)) {
                let webp = convertFromWebP(data)?._cgImage
                if let webp = webp {
                    let image = generateImage(NSMakeSize(640, 640), contextGenerator: { size, ctx in
                        ctx.clear(size.bounds)
                        ctx.setFillColor(.white)
                        ctx.fill(size.bounds)
                        ctx.draw(webp, in: size.bounds.focus(size))
                    }, scale: 1.0)!
                    self?.statusValue.set(NSImage(cgImage: image, size: image.size))
                }
            }
        }))
    }
}

final class MediaObjectToAvatar {
    enum Object {
        case emoji(String)
        case sticker(TelegramMediaFile)
        case animated(TelegramMediaFile)
        case gif(TelegramMediaFile)
    }
    
    enum Result {
        case image(NSImage)
        case video(String)
    }
    
    private var animated_c:StickerToMp4?
    private var fetch_v: FetchVideoToFile?
    private var fetch_i: FetchStickerToImage?

    private let object: Object
    private let context: AccountContext
    init(context: AccountContext, object: Object) {
        self.object = object
        self.context = context
    }
  
    deinit {
        var bp = 0
        bp += 1
    }
    
    func start() -> Signal<Result, NoError> {
        
        let signal: Signal<Result, NoError>
        switch object {
        case let .animated(file):
            let stickerToMp4: StickerToMp4 = .init(context: context, fileReference: .standalone(media: file))
            self.animated_c = stickerToMp4
            
            signal = stickerToMp4.status |> map { value -> String? in
                switch value {
                case let .done(path, _):
                    return path
                default:
                    return nil
                }
            } |> filter {
                $0 != nil
            } |> map { value -> Result in 
                return .video(value!)
            }
            
            stickerToMp4.start()

        case let .emoji(text):
            signal = Signal { subscriber in
                let emoji = generateImage(NSMakeSize(640, 640), scale: 1.0, rotatedContext: { size, ctx in
                    ctx.clear(size.bounds)
                    
                    ctx.setFillColor(.white)
                    ctx.fill(size.bounds)
                    
                    let textNode = TextNode.layoutText(.initialize(string: text, color: .black, font: .normal(300)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)

                    textNode.1.draw(size.bounds.focus(textNode.0.size), in: ctx, backingScaleFactor: 1.0, backgroundColor: .white)
                    
                })!
                subscriber.putNext(.image(NSImage(cgImage: emoji, size: emoji.size)))
                subscriber.putCompletion()
                
                return EmptyDisposable
            } |> runOn(.concurrentDefaultQueue())
            
        case let .gif(file):
            let fetch_v = FetchVideoToFile(context: context, file: file)
            self.fetch_v = fetch_v
            signal = fetch_v.status |> map {
                .video($0)
            }
            fetch_v.start()
        case let .sticker(file):
            let fetch_i = FetchStickerToImage(context: context, file: file)
            self.fetch_i = fetch_i
            signal = fetch_i.status |> map {
                .image($0)
            }
            fetch_i.start()
        }
        return signal |> take(1)
    }
}
