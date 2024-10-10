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
import GZIP
import Postbox
import ColorPalette
import ThemeSettings
import ObjcUtils
import TelegramMedia

private func buffer(from image: CGImage, zoom: CGFloat = 1.0, offset: CGPoint = .zero, background: CGImage? = nil) -> CVPixelBuffer? {
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
    if let background = background {
        context?.draw(background, in: rect)
    }
    
    var frame = rect.focus(NSMakeSize(rect.width * zoom, rect.height * zoom))
    
    var offset = offset
    offset.x = mappingRange(offset.x, -3, 3, -2 * zoom, 2 * zoom)
    offset.y = mappingRange(offset.y, -3, 3, -2 * zoom, 2 * zoom)

    
    frame.origin.x += frame.origin.x * offset.x
    frame.origin.y -= frame.origin.y * offset.y
    
    context?.draw(image, in: frame)

    CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    return pixelBuffer
}

private func makeImage(from image: CGImage, zoom: CGFloat = 1.0, offset: CGPoint, background: CGImage? = nil) -> CGImage {
    let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
    return generateImage(image.size, contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        if let background = background {
            ctx.draw(background, in: rect)
        }
        
        
        var frame = rect.focus(NSMakeSize(rect.width * zoom, rect.height * zoom))
        
        var offset = offset
        offset.x = mappingRange(offset.x, -3, 3, -2 * zoom, 2 * zoom)
        offset.y = mappingRange(offset.y, -3, 3, -2 * zoom, 2 * zoom)
        frame.origin.x += frame.origin.x * offset.x
        frame.origin.y -= frame.origin.y * offset.y
        
        ctx.draw(image, in: frame)
    })!
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

        init(codec: String) throws {
            self.path = NSTemporaryDirectory() + "tgs_\(arc4random()).mp4"
            self.writter = try .init(url: URL.init(fileURLWithPath: path), fileType: .mov)
            var settings:[String: Any] = [AVVideoWidthKey: NSNumber(value: 640), AVVideoHeightKey: NSNumber(value: 640), AVVideoCodecKey: codec];
            
            if codec == AVVideoCodecH264 {
                let videoCompressionProps: Dictionary<String, Any> = [
                    AVVideoAverageBitRateKey : 1500000,
                    AVVideoMaxKeyFrameIntervalKey : 3,
                ]
                settings[AVVideoCompressionPropertiesKey] = videoCompressionProps
            }
            
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
    private let background: Signal<CGImage, NoError>
    private let zoom: CGFloat
    private let offset: CGPoint
    init(context: AccountContext, background: Signal<CGImage, NoError>, zoom: CGFloat, offset: CGPoint, fileReference: FileMediaReference, codec: String) {
        self.export = try? Export(codec: codec)
        self.context = context
        self.background = background
        self.fileReference = fileReference
        self.zoom = zoom
        self.offset = offset
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
        
        let type: LottieAnimationType
        if fileReference.media.isWebm {
            type = .webm
        } else if fileReference.media.mimeType == "image/webp" {
            type = .webp
        } else {
            type = .lottie
        }
        
        dataDisposable.set(combineLatest(signal, background).start(next: { [weak self] path, background in
            let data: Data?
            switch type {
            case .webm:
                data = path.data(using: .utf8)!
            default:
                data = try? Data(contentsOf: URL(fileURLWithPath: path))
            }
            if let data = data {
                let animation = LottieAnimation(compressed: data, key: .init(key: .bundle("_convert_file_\(path)"), size: NSMakeSize(640, 640)), type: type)
                self?.process(animation, background: background)
            }
        }))
        fetchDisposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: fileReference).start())
    }
    
    private func process(_ lottie: LottieAnimation, background: CGImage) -> Void {
                
        if let renderer = lottie.initialize() {
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            let thumbPath = NSTemporaryDirectory() + "\(randomId)"
            let url = URL(fileURLWithPath: thumbPath)
            
            let image = renderer.render(at: 0, frames: [], previousFrame: nil)?.image
            if let image = image {
                let pixelBuffer = makeImage(from: image, zoom: zoom, offset: offset, background: background)

                if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
        
                    let colorQuality: Float = 0.6
        
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
        
                    CGImageDestinationAddImage(colorDestination, pixelBuffer, options as CFDictionary)
                    CGImageDestinationFinalize(colorDestination)
                }
            }
            
    
            self.status = .initializing(thumbPath)
            export?.start()
    
            let fps = renderer.fps
            let effectiveFps = min(30, fps)
    
            let framesCount = renderer.endFrame - renderer.startFrame
            var frame: Int32 = renderer.startFrame
            var index: Int32 = 0
            while true {
                let image = renderer.render(at: frame, frames: [], previousFrame: nil)?.image
                if let image = image {
                    let pixelBuffer = buffer(from: image, zoom: zoom, offset: offset, background: background)!
        
                    let frameTime: CMTime  = CMTimeMake(value: 20, timescale: 600);
                    let lastTime: CMTime = CMTimeMake(value: Int64(index) * 20, timescale: 600);
                    var presentTime: CMTime = CMTimeAdd(lastTime, frameTime);
                    if frame == renderer.startFrame {
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
                } else {
                    break
                }
                self.status = .converting(min((Float(frame) / Float(framesCount)), 1))
            }
    
            export?.finish({ [weak self] path in
                self?.status = .done(path, thumbPath)
            })
        }
        
        
        
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
    init(context _context: AccountContext, background: Signal<CGImage, NoError>, zoom: CGFloat, offset: CGPoint, fileReference: FileMediaReference, codec: String) {
        self.context = .init(queue: StickerToMp4Context.queue, generate: {
            return StickerToMp4Context(context: _context, background: background, zoom: zoom, offset: offset, fileReference: fileReference, codec: codec)
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
    
    private let background: Signal<CGImage, NoError>
    private let zoom: CGFloat
    private let offset: CGPoint

    
    init(context: AccountContext, background: Signal<CGImage, NoError>, zoom: CGFloat, offset: CGPoint, file: TelegramMediaFile) {
        self.context = context
        self.file = file
        self.background = background
        self.zoom = zoom
        self.offset = offset
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
        
        let zoom = self.zoom
        let offset = self.offset
        
        dataDisposable.set(combineLatest(background, signal).start(next: { [weak self] background, path in
            if let data = try? Data.init(contentsOf: URL(fileURLWithPath: path)) {
                let webp = convertFromWebP(data)?._cgImage
                if let webp = webp {
                    let image = makeImage(from: webp, zoom: zoom, offset: offset, background: background)
                    self?.statusValue.set(NSImage(cgImage: image, size: image.size))
                }
            }
        }))
    }
}

final class MediaObjectToAvatar {
    struct Object {
        struct Foreground {
            enum Source {
                case emoji(String, NSColor)
                case sticker(TelegramMediaFile)
                case animated(TelegramMediaFile)
                case gif(TelegramMediaFile)
            }
            var type: Source
            var zoom: CGFloat
            var offset: CGPoint
        }
        enum Background {
            case colors([NSColor])
            case pattern(Wallpaper, ColorPalette)
        }
        let foreground: Foreground
        let background: Background
    }
    
    struct Result {
        enum Status {
            case initializing(String)
            case converting(Float)
            case done(String, String)
            case failed
        }
        enum Result {
            case image(NSImage)
            case video(String, String)
        }
        var status: Status?
        var result: Result?
    }
    
    
    
    private var animated_c:StickerToMp4?

    private var fetch_v: FetchVideoToFile?
    private var fetch_i: FetchStickerToImage?

    let object: Object
    private let context: AccountContext
    
    private var holder: MediaObjectToAvatar?
    private let codec: String
    
    init(context: AccountContext, object: Object, codec: String = AVVideoCodecH264) {
        self.object = object
        self.context = context
        self.codec = codec
    }
  
    deinit {
        var bp = 0
        bp += 1
    }
    
    func start() -> Signal<Result, NoError> {
        
        holder = self
        
        let background: Signal<CGImage, NoError>
        
        switch object.background {
        case let .colors(colors):
            background = Signal { subscriber in
                let image = generateImage(NSMakeSize(640, 640), contextGenerator: { size, ctx in
                    ctx.clear(size.bounds)
                    let imageRect = size.bounds
                    if colors.count == 1, let color = colors.first {
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(imageRect)
                    } else if colors.count > 1 {
                        let gradientColors = colors.map { $0.cgColor } as CFArray
                        let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                        
                        var locations: [CGFloat] = []
                        for i in 0 ..< colors.count {
                            locations.append(delta * CGFloat(i))
                        }
                        let colorSpace = CGColorSpaceCreateDeviceRGB()
                        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                                            
                        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: imageRect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                    }
                })!
                
                subscriber.putNext(image)
                subscriber.putCompletion()
                
                return ActionDisposable(action: {
                    
                })
            }
        case let .pattern(wallpaper, palette):
            let emptyColor: TransformImageEmptyColor
            
            let colors = wallpaper.settings.colors.compactMap { NSColor($0) }
            
            if colors.count > 1 {
                let colors = colors.map {
                    return $0.withAlphaComponent($0.alpha == 0 ? 0.5 : $0.alpha)
                }
                emptyColor = .gradient(colors: colors, intensity: colors.first!.alpha, rotation: nil)
            } else if let color = colors.first {
                emptyColor = .color(color)
            } else {
                emptyColor = .color(NSColor(rgb: 0xd6e2ee, alpha: 0.5))
            }
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: 0), imageSize: wallpaper.dimensions.aspectFilled(NSMakeSize(640, 640)), boundingSize: NSMakeSize(640, 640), intrinsicInsets: NSEdgeInsets(), emptyColor: emptyColor)
            
            switch wallpaper {
            case let .file(_, file, _, _):
                var representations:[TelegramMediaImageRepresentation] = []
                if let dimensions = file.dimensions {
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                } else {
                    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(NSMakeSize(640, 640)), resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                }

                let updateImageSignal = chatWallpaper(account: context.account, representations: representations, file: file, mode: .thumbnail, isPattern: true, autoFetchFullSize: true, scale: 2, isBlurred: false, synchronousLoad: false, drawPatternOnly: false, palette: palette)

                background = updateImageSignal |> map { value in
                    return value.execute(arguments, value.data)!.generateImage()!
                }
                
            default:
                background = .complete()
            }
        }
        
        let signal: Signal<Result, NoError>
        let zoom = object.foreground.zoom
        switch object.foreground.type {
        case let .animated(file):
            let stickerToMp4: StickerToMp4 = .init(context: context, background: background, zoom: object.foreground.zoom, offset: object.foreground.offset, fileReference: .standalone(media: file), codec: codec)
            self.animated_c = stickerToMp4
            
            signal = stickerToMp4.status |> map { value -> Result in
                switch value {
                case let .initializing(path):
                    return .init(status: .initializing(path), result: nil)
                case .failed:
                    return .init(status: nil, result: nil)
                case let .done(path, thumb):
                    return .init(status: .done(path, thumb), result: .video(path, thumb))
                case let .converting(progress):
                    return .init(status: .converting(progress), result: nil)
                }
            }
            stickerToMp4.start()
        case let .emoji(text, color):
            signal = background |> mapToSignal { value in
                let emoji = generateImage(NSMakeSize(640, 640), scale: 1.0, rotatedContext: { size, ctx in
                    ctx.clear(size.bounds)
                    
                    ctx.setFillColor(.white)
                    ctx.fill(size.bounds)
                    
                    let textNode = TextNode.layoutText(.initialize(string: text, color: color, font: .avatar(150 * zoom + 150)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)

                    ctx.draw(value, in: size.bounds)
                    
                    var rect = size.bounds.focus(textNode.0.size)
                    rect.origin.y += 4
                    textNode.1.draw(rect, in: ctx, backingScaleFactor: 1.0, backgroundColor: .white)
                    
                })!
                return .single(.init(status: nil, result: .image(NSImage(cgImage: emoji, size: emoji.size))))
            }
            
        case let .gif(file):
            let fetch_v = FetchVideoToFile(context: context, file: file)
            self.fetch_v = fetch_v
            signal = fetch_v.status |> map {
                .init(status: nil, result: .video($0, ""))
            }
            fetch_v.start()
        case let .sticker(file):
            let fetch_i = FetchStickerToImage(context: context, background: background, zoom: object.foreground.zoom, offset: object.foreground.offset, file: file)
            self.fetch_i = fetch_i
            signal = fetch_i.status |> map {
                .init(status: nil, result: .image($0))
            }
            fetch_i.start()
        }
        return signal |> afterNext { [weak self] value in
            if value.result != nil {
                DispatchQueue.main.async {
                    self?.holder = nil
                }
            }
        }
    }
}
