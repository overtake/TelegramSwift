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
import SwiftSignalKitMac

let sampleBufferQueue = DispatchQueue(label: "samplebuffer")

private let veryLongTimeInterval = CFTimeInterval(256.0 * 365.0 * 24.0 * 60.0 * 60.0)



class GIFPlayerView: TransformImageView {
    
    private var sampleLayer:AVSampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    
    private var _reader:Atomic<AVAssetReader?> = Atomic(value:nil)

    
    private var _asset:Atomic<AVURLAsset?> = Atomic(value:nil)

    
    private let _output:Atomic<AVAssetReaderTrackOutput?> = Atomic(value:nil)

    
    private let _track:Atomic<AVAssetTrack?> = Atomic(value:nil)

    
    private let _needReset:Atomic<Bool> = Atomic(value:false)

    
    private let _timer:Atomic<CFRunLoopTimer?> = Atomic(value:nil)

    
    private let _timebase:Atomic<CMTimebase?> = Atomic(value:nil)

    private let _stopRequesting:Atomic<Bool> = Atomic(value:false)
    private let _swapNext:Atomic<Bool> = Atomic(value:true)
    private let _path:Atomic<String?> = Atomic(value:nil)
    
    private let maskLayer = CAShapeLayer()
    
    var followWindow:Bool = true
    var positionFlags: GroupLayoutPositionFlags? {
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
                    topLeftRadius = topLeftRadius * 3 + 2
                }
                if positionFlags.contains(.top) && positionFlags.contains(.right) {
                    topRightRadius = topRightRadius * 3 + 2
                }
                if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                    bottomLeftRadius = bottomLeftRadius * 3 + 2
                }
                if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                    bottomRightRadius = bottomRightRadius * 3 + 2
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
    override init() {
        super.init()
        sampleLayer.actions = ["onOrderIn":NSNull(),"sublayers":NSNull(),"bounds":NSNull(),"frame":NSNull(),"position":NSNull(),"contents":NSNull(),"opacity":NSNull(), "transform": NSNull()
        ]
        sampleLayer.videoGravity = .resizeAspectFill
        sampleLayer.backgroundColor = NSColor.clear.cgColor
        

        layer?.addSublayer(sampleLayer)


    }

    

    var isHasPath: Bool {
        return _path.modify({$0}) != nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        sampleLayer.frame = bounds
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        sampleLayer.frame = bounds
    }
    
    func pause() {
        sampleLayer.stopRequestingMediaData()
    }
    
    func set(path:String?, timebase:CMTimebase? = nil) -> Void {
        assertOnMainThread()
        
        let realPath:String? = link(path:path, ext:"mp4")
        
        
        if realPath != self._path.modify({$0}) {
            _ = _path.swap(realPath)
            _ = _timebase.swap(timebase)
            let path = self._path
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
            
            if let path = realPath {
                let avAsset = AVURLAsset(url: URL(fileURLWithPath: path))
                let _ = asset.swap(avAsset)
                let t = avAsset.tracks(withMediaType: .video).first
                if let track = t {
                    layer.setAffineTransform(track.preferredTransform.inverted())
                }

                let _ = track.swap(t)
                _ = stopRequesting.swap(t == nil)
                _ = swapNext.swap(t != nil)
            } else {
                _ = asset.swap(nil)
                _ = track.swap(nil)
                _ = stopRequesting.swap(true)
                _ = swapNext.swap(false)
                return
            }
            
            layer.requestMediaDataWhenReady(on: sampleBufferQueue, using: {
                if stopRequesting.modify({$0}) {
                    
                    layer.stopRequestingMediaData()
                    layer.flushAndRemoveImage()
                    reader.modify({$0})?.cancelReading()
                    _ = reader.swap(nil)
                    _ = stopRequesting.swap(false)
                    return
                }
                
                if swapNext.swap(false) {
                    _ = reader.modify({$0})?.cancelReading()
                    _ = reader.swap(nil)
                    _ = output.swap(nil)
                }
                
                if  let readerValue = reader.modify({$0}), let outputValue = output.modify({$0}) {
                    while layer.isReadyForMoreMediaData {
                        if !stopRequesting.modify({$0}) {
                            if let sampleVideo = outputValue.copyNextSampleBuffer() {
                                layer.enqueue(sampleVideo)
                                
                                continue
                            }
                            _ = stopRequesting.modify({_ in path.modify({$0}) == nil})
                            break
                        } else {
                            break
                        }
                        
                    }
                    if readerValue.status == .completed || readerValue.status == .cancelled  {
                        if reset.modify({$0}) {
                            _ = reset.swap(false)

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
    
    func reset(with timebase:CMTimebase? = nil, _ resetImage: Bool = true) {
     //   if resetImage {
            sampleLayer.flushAndRemoveImage()
      //  } else {
       //     sampleLayer.flush()
      //  }
        
        clear(false)
        _ = _swapNext.swap(true)
        _ = _timebase.swap(timebase)
    }
    
    
    
    deinit {
        clear(true)
        _ = _path.swap(nil)
        sampleLayer.flushAndRemoveImage()
    }
    
    
    private func clear(_ stopRequesting:Bool = false) {
        _ = _stopRequesting.swap(stopRequesting)
        
        if let timebase = sampleLayer.controlTimebase, let timer = _timer.modify({$0}) {
            _ = _timer.swap(nil)
            _ = _reader.swap(nil)
            CMTimebaseRemoveTimer(timebase, timer)
        }
        
    }
    
    
    required convenience init(frame frameRect: NSRect) {
        self.init()
    }
    
}

fileprivate func restartReading(_reader:Atomic<AVAssetReader?>, _asset:Atomic<AVURLAsset?>, _track:Atomic<AVAssetTrack?>, _output:Atomic<AVAssetReaderTrackOutput?>, _needReset:Atomic<Bool>, _timer:Atomic<CFRunLoopTimer?>, layer: AVSampleBufferDisplayLayer, _timebase:Atomic<CMTimebase?>) -> Bool {
    
    if let timebase = layer.controlTimebase, let timer = _timer.modify({$0}) {
        _ = _timer.swap(nil)
        CMTimebaseRemoveTimer(timebase, timer)
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
                    
                    var timebase:CMTimebase?
                    if let tb = _timebase.modify({$0}) {
                        timebase = tb
                        _ = _timebase.swap(nil)
                    } else {
                        CMTimebaseCreateWithMasterClock( kCFAllocatorDefault, CMClockGetHostTimeClock(), &timebase )
                    }
                    
         
                    if let timebase = timebase {
                        reader.timeRange = CMTimeRangeMake(CMTimebaseGetTime(timebase), asset.duration)

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
                            CMTimebaseSetRate(timebase, 1.0);
                            CMTimebaseAddTimer(timebase, timer, runLoop)
                            CFRunLoopAddTimer(runLoop, timer, CFRunLoopMode.defaultMode);
                            CMTimebaseSetTimerNextFireTime(timebase, timer, asset.duration, 0)
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

