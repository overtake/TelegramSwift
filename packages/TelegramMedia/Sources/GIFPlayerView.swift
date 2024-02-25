//
//  GIFPlayerView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 10/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import AVFoundation
import SwiftSignalKit



final class CIStickerContext : CIContext {
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

private class AlphaFrameFilter: CIFilter {
    static var kernel: CIColorKernel? = {
        return CIColorKernel(source: """
kernel vec4 alphaFrame(__sample s, __sample m) {
  return vec4( s.rgb, m.r );
}
""")
    }()
    
    var inputImage: CIImage?
    var maskImage: CIImage?
    
    override var outputImage: CIImage? {
        let kernel = AlphaFrameFilter.kernel!
        guard let inputImage = inputImage, let maskImage = maskImage else {
            return nil
        }
        let args = [inputImage as AnyObject, maskImage as AnyObject]
        return kernel.apply(extent: inputImage.extent, arguments: args)
    }
}

let sampleBufferQueue = DispatchQueue(label: "sampleBufferQueue", qos: .default, attributes: [])

private let veryLongTimeInterval = CFTimeInterval(8073216000)

public struct AVGifData : Equatable {
    let asset: AVURLAsset
    let track: AVAssetTrack
    let animatedSticker: Bool
    let swapOnComplete: Bool
    private init(asset: AVURLAsset, track: AVAssetTrack, animatedSticker: Bool, swapOnComplete: Bool) {
        self.asset = asset
        self.track = track
        self.swapOnComplete = swapOnComplete
        self.animatedSticker = animatedSticker
    }
    
    public static func dataFrom(_ path: String?, animatedSticker: Bool = false, swapOnComplete: Bool = false) -> AVGifData? {
        let new = link(path: path, ext: "mp4")
        if let new = new {
            let avAsset = AVURLAsset(url: URL(fileURLWithPath: new))
            let t = avAsset.tracks(withMediaType: .video).first
            if let t = t {
                return AVGifData(asset: avAsset, track: t, animatedSticker: animatedSticker, swapOnComplete: swapOnComplete)
            }
        }
        return nil
    }
    public static func ==(lhs: AVGifData, rhs: AVGifData) -> Bool {
        return lhs.asset.url == rhs.asset.url && lhs.animatedSticker == rhs.animatedSticker
    }
    
}

private final class TAVSampleBufferDisplayLayer : AVSampleBufferDisplayLayer {
    deinit {
       
    }
}



open class GIFPlayerView: TransformImageView {
    
    public enum LoopActionResult {
        case pause
    }
    
    public var sampleBufferLayer: AVSampleBufferDisplayLayer {
        return sampleLayer
    }
    
    private let sampleLayer:TAVSampleBufferDisplayLayer = TAVSampleBufferDisplayLayer()
    
    private var _reader:Atomic<AVAssetReader?> = Atomic(value:nil)
    private var _asset:Atomic<AVURLAsset?> = Atomic(value:nil)
    private let _output:Atomic<AVAssetReaderTrackOutput?> = Atomic(value:nil)
    private let _track:Atomic<AVAssetTrack?> = Atomic(value:nil)
    private let _needReset:Atomic<Bool> = Atomic(value:false)
    private let _timer:Atomic<CFRunLoopTimer?> = Atomic(value:nil)
    private let _loopAction:Atomic<(()->LoopActionResult)?> = Atomic(value:nil)
    private let _timebase:Atomic<CMTimebase?> = Atomic(value:nil)
    private let _stopRequesting:Atomic<Bool> = Atomic(value:false)
    private let _swapNext:Atomic<Bool> = Atomic(value:true)
    private let _data:Atomic<AVGifData?> = Atomic(value:nil)

    public func setLoopAction(_ action:(()->LoopActionResult)?) {
        _ = _loopAction.swap(action)
    }
    
    
    private let maskLayer = SimpleShapeLayer()
    
    public var positionFlags: LayoutPositionFlags? {
        didSet {
            if let positionFlags = positionFlags {
                let path = CGMutablePath()
                
                let minx:CGFloat = 0, midx = frame.width/2.0, maxx = frame.width
                let miny:CGFloat = 0, midy = frame.height/2.0, maxy = frame.height
                
                path.move(to: NSMakePoint(minx, midy))
                
                var topLeftRadius: CGFloat = .cornerRadius
                var bottomLeftRadius: CGFloat = .cornerRadius
                var topRightRadius: CGFloat = .cornerRadius
                var bottomRightRadius: CGFloat = .cornerRadius
                
                
                if positionFlags.contains(.top) && positionFlags.contains(.left) {
                    bottomLeftRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.top) && positionFlags.contains(.right) {
                    bottomRightRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                    topLeftRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                    topRightRadius = .cornerRadius * 3 + 2
                }
                
                path.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
                path.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
                path.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topRightRadius)
                path.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topLeftRadius)
                
                maskLayer.path = path
                layer?.mask = maskLayer
            } else {
                layer?.mask = nil
            }
        }
    }
    public override init() {
        super.init()
        sampleLayer.actions = ["onOrderIn":NSNull(),"sublayers":NSNull(),"bounds":NSNull(),"frame":NSNull(),"position":NSNull(),"contents":NSNull(),"opacity":NSNull(), "transform": NSNull()
        ]
        sampleLayer.videoGravity = .resizeAspect
        sampleLayer.backgroundColor = NSColor.clear.cgColor
        

        layer?.addSublayer(sampleLayer)

    }
    
    public func setVideoLayerGravity(_ gravity: AVLayerVideoGravity) {
        sampleLayer.videoGravity = gravity
    }
    
    

    public var controlTimebase: CMTimebase? {
        return sampleLayer.controlTimebase
    }

    public var isHasData: Bool {
        return _data.modify({$0}) != nil
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layout() {
        super.layout()
        sampleLayer.frame = bounds
    }
    
    public func set(data: AVGifData?, timebase:CMTimebase? = nil) -> Void {
        assertOnMainThread()
      
         if data != _data.swap(data) {
            _ = _timebase.swap(timebase)
            let _data = self._data
            let layer:AVSampleBufferDisplayLayer = self.sampleLayer
            let reader = self._reader
            let output = self._output
            let reset = self._needReset
            let stopRequesting = self._stopRequesting
            let swapNext = self._swapNext
            let track = self._track
            let asset = self._asset
            let timer = self._timer
            let timebase = self._timebase
            let loopAction = self._loopAction
            if let data = data {
                let _ = track.swap(data.track)
                let _ = asset.swap(data.asset)
                
                _ = stopRequesting.swap(false)
                if data.swapOnComplete {
                    _ = timebase.swap(self.controlTimebase)
                }
                _ = swapNext.swap(true)
            } else {
                _ = asset.swap(nil)
                _ = track.swap(nil)
                _ = stopRequesting.swap(true)
                _ = swapNext.swap(false)
                return
            }
            
            layer.requestMediaDataWhenReady(on: sampleBufferQueue, using: {
                if stopRequesting.swap(false) {
                    
                    if let controlTimebase = layer.controlTimebase, let current = timer.swap(nil) {
                        CMTimebaseRemoveTimer(controlTimebase, timer: current)
                        _ = timebase.swap(nil)
                    }
                    
                    
                    layer.stopRequestingMediaData()
                    layer.flushAndRemoveImage()
                    var reader = reader.swap(nil)
                    Queue.concurrentBackgroundQueue().async {
                        reader?.cancelReading()
                        reader = nil
                    }
                    
                    return
                }
                
                if swapNext.swap(false) {
                    _ = output.swap(nil)
                    var reader = reader.swap(nil)
                    Queue.concurrentBackgroundQueue().async {
                        reader?.cancelReading()
                        reader = nil
                    }
                }
                
                if  let readerValue = reader.with({ $0 }), let outputValue = output.with({ $0 }) {
                    
                    let affineTransform = track.with { $0?.preferredTransform.inverted() }
                    if let affineTransform = affineTransform {
                        layer.setAffineTransform(affineTransform)
                    }
                    
                    while layer.isReadyForMoreMediaData {
                        if !stopRequesting.with({ $0 }) {
                            
                            if readerValue.status == .reading, let sampleBuffer = outputValue.copyNextSampleBuffer() {
                                layer.enqueue(sampleBuffer)
                                continue
                            }
                            _ = stopRequesting.modify { _ in _data.with { $0 } == nil }
                            break
                        } else {
                            break
                        }
                        
                    }
                    if readerValue.status == .completed || readerValue.status == .cancelled  {
                        if reset.swap(false) {
                            let loopActionResult = loopAction.with({ $0?() })
                            
                            if let loopActionResult = loopActionResult {
                                switch loopActionResult {
                                case .pause:
                                    return
                                }
                            }
                            let result = restartReading(_reader: reader, _asset: asset, _track: track, _output: output, _needReset: reset, _timer: timer, layer: layer, _timebase: timebase)
                            if result {
                                layer.flush()
                            }
                        }
                    }
                } else if !stopRequesting.modify({$0}) {
                    let result = restartReading(_reader: reader, _asset: asset, _track: track, _output: output, _needReset: reset, _timer: timer, layer: layer, _timebase: timebase)
                   
                    if result {
                        layer.flush()
                    }
                }
                
            })
        }
    }
    
    public func reset(with timebase:CMTimebase? = nil, _ resetImage: Bool = true) {
     //   if resetImage {
            sampleLayer.flushAndRemoveImage()
      //  } else {
       //     sampleLayer.flush()
      //  }
        
        _ = _swapNext.swap(true)
        _ = _timebase.swap(timebase)
    }
    
    
    
    deinit {
        _ = _stopRequesting.swap(true)
    }
    
    

    
    public required convenience init(frame frameRect: NSRect) {
        self.init()
        self.frame = frameRect
    }
    
}

fileprivate func restartReading(_reader:Atomic<AVAssetReader?>, _asset:Atomic<AVURLAsset?>, _track:Atomic<AVAssetTrack?>, _output:Atomic<AVAssetReaderTrackOutput?>, _needReset:Atomic<Bool>, _timer:Atomic<CFRunLoopTimer?>, layer: AVSampleBufferDisplayLayer, _timebase:Atomic<CMTimebase?>) -> Bool {
    
    if let timebase = layer.controlTimebase, let timer = _timer.modify({$0}) {
        _ = _timer.swap(nil)
        CMTimebaseRemoveTimer(timebase, timer: timer)
    }
    
    if let asset = _asset.modify({$0}), let track = _track.modify({$0}) {
        let _ = _reader.swap(try? AVAssetReader(asset: asset))
        
        if let reader = _reader.modify({$0}) {
            
            var params:[String:Any] = [:]
            params[kCVPixelBufferPixelFormatTypeKey as String] = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            let _ = _output.swap(AVAssetReaderTrackOutput(track: track, outputSettings: params))
            if let output = _output.modify({$0}) {
                output.alwaysCopiesSampleData = false
                
                if reader.canAdd(output) {
                    reader.add(output)
                    
                    var timebase:CMTimebase? = _timebase.swap(nil)
                    if timebase == nil {
                        CMTimebaseCreateWithSourceClock( allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase )
                        CMTimebaseSetRate(timebase!, rate: 1.0)
                    }
                    
         
                    if let timebase = timebase {
                        reader.timeRange = CMTimeRangeMake(start: CMTimebaseGetTime(timebase), duration: asset.duration)

                        let runLoop = CFRunLoopGetMain()
                        var context = CFRunLoopTimerContext()
                        context.info = UnsafeMutableRawPointer(Unmanaged.passRetained(_needReset).toOpaque())
                        
                        let timer = CFRunLoopTimerCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent(), veryLongTimeInterval, 0, 0, {
                            (cfRunloopTimer, info) -> Void in
                            if let info = info {
                                let s = Unmanaged<Atomic<Bool>>.fromOpaque(info).takeUnretainedValue()
                                _ = s.swap(true)
                            }
                        }, &context);
                        
                        if let timer = timer, let runLoop = runLoop {
                            _ = _timer.swap(timer)
                            
                            
                            CMTimebaseAddTimer(timebase, timer: timer, runloop: runLoop)
                            CFRunLoopAddTimer(runLoop, timer, CFRunLoopMode.defaultMode);
                            CMTimebaseSetTimerNextFireTime(timebase, timer: timer, fireTime: asset.duration, flags: 0)
                        }
                        layer.controlTimebase = timebase
                        
                    }
                    
                    reader.startReading()

                    
                    return true
                }
            }
        }
        
        
    }
    return false
    
}


