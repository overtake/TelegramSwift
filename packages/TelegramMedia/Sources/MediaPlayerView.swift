//
//  MediaPlayerView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/11/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import AVFoundation
import MediaPlayer

private func findContentsLayer(_ sublayers: [CALayer]) -> CALayer? {
    for sublayer in sublayers {
        if let _ = sublayer.contents {
            return sublayer
        } else if let sublayers = sublayer.sublayers, !sublayers.isEmpty {
            return findContentsLayer(sublayers)
        }
    }
    return nil
}

private final class MediaPlayerViewLayer: AVSampleBufferDisplayLayer {
    override func action(forKey event: String) -> CAAction? {
        return NSNull()
    }
    deinit {
    
    }
}

private final class MediaPlayerViewDisplayView: View {
    var updateInHierarchy: ((Bool) -> Void)?
    
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updateInHierarchy?(superview != nil)
    }
}

private enum PollStatus: CustomStringConvertible {
    case delay(Double)
    case finished
    
    var description: String {
        switch self {
        case let .delay(value):
            return "delay(\(value))"
        case .finished:
            return "finished"
        }
    }
}

public final class MediaPlayerView: View {
    var videoInHierarchy: Bool = false
    var updateVideoInHierarchy: ((Bool) -> Void)?
    
    private var videoNode: MediaPlayerViewDisplayView
    
    private var videoLayer: AVSampleBufferDisplayLayer?
        
    
    public var preventsCapture: Bool = false {
        didSet {
            if #available(macOS 10.15, *) {
                videoLayer?.preventsCapture = preventsCapture
            }
        }
    }
    
    public func setVideoLayerGravity(_ gravity: AVLayerVideoGravity) {
        videoLayer?.videoGravity = gravity
    }
    
    var takeFrameAndQueue: (Queue, () -> MediaTrackFrameResult)?
    var timer: SwiftSignalKit.Timer?
    var polling = false
    
    var currentRotationAngle = 0.0
    var currentAspect = 1.0
    
    public var state: (timebase: CMTimebase, requestFrames: Bool, rotationAngle: Double, aspect: Double)? {
        didSet {
            self.updateState()
        }
    }
    
    private let maskLayer = SimpleShapeLayer()
    
    public var cornerRadius: CGFloat = .cornerRadius
    
    public var positionFlags: LayoutPositionFlags? {
        didSet {
            if let positionFlags = positionFlags {
                let path = CGMutablePath()
                
                let minx:CGFloat = 0, midx = frame.width/2.0, maxx = frame.width
                let miny:CGFloat = 0, midy = frame.height/2.0, maxy = frame.height
                
                path.move(to: NSMakePoint(minx, midy))
                
                var topLeftRadius: CGFloat = cornerRadius
                var bottomLeftRadius: CGFloat = cornerRadius
                var topRightRadius: CGFloat = cornerRadius
                var bottomRightRadius: CGFloat = cornerRadius
                
                
                if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                    topLeftRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                    topRightRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.top) && positionFlags.contains(.left) {
                    bottomLeftRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.top) && positionFlags.contains(.right) {
                    bottomRightRadius = .cornerRadius * 3 + 2
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
    
    private func updateState() {
        if let (timebase, requestFrames, rotationAngle, aspect) = self.state {
            if let videoLayer = self.videoLayer {
                if videoLayer.controlTimebase !== timebase || videoLayer.status == .failed {
                    videoLayer.flush()
                    videoLayer.controlTimebase = timebase
                }
                
                if !self.currentRotationAngle.isEqual(to: rotationAngle) || !self.currentAspect.isEqual(to: aspect) {
                    self.currentRotationAngle = rotationAngle
                    self.currentAspect = aspect
                    var transform = CGAffineTransform(rotationAngle: CGFloat(rotationAngle))
                    if abs(rotationAngle).remainder(dividingBy: Double.pi) > 0.1 {
                        transform = transform.scaledBy(x: CGFloat(aspect), y: CGFloat(1.0 / aspect))
                    }

                    videoLayer.setAffineTransform(transform)
                }
                
                if self.videoInHierarchy {
                    if requestFrames {
                        self.startPolling()
                    }
                }
            }
        }
    }
    
    private func startPolling() {
        if !self.polling {
            self.polling = true
            self.poll(completion: { [weak self] status in
                self?.polling = false
                
                if let strongSelf = self, let (_, requestFrames, _, _) = strongSelf.state, requestFrames {
                    strongSelf.timer?.invalidate()
                    switch status {
                    case let .delay(delay):
                        strongSelf.timer = SwiftSignalKit.Timer(timeout: delay, repeat: true, completion: {
                            if let strongSelf = self, let videoLayer = strongSelf.videoLayer, let (_, requestFrames, _, _) = strongSelf.state, requestFrames, strongSelf.videoInHierarchy {
                                if videoLayer.isReadyForMoreMediaData {
                                    strongSelf.timer?.invalidate()
                                    strongSelf.timer = nil
                                    strongSelf.startPolling()
                                }
                            }
                        }, queue: Queue.mainQueue())
                        strongSelf.timer?.start()
                    case .finished:
                        break
                    }
                }
            })
        }
    }
    
    private func poll(completion: @escaping (PollStatus) -> Void) {
        if let (takeFrameQueue, takeFrame) = self.takeFrameAndQueue, let videoLayer = self.videoLayer, let (timebase, _, _, _) = self.state {
            let layerRef = Unmanaged.passRetained(videoLayer)
            takeFrameQueue.async {
                let status: PollStatus
                do {
                    var numFrames = 0
                    let layer = layerRef.takeUnretainedValue()
                    let layerTime = CMTimeGetSeconds(CMTimebaseGetTime(timebase))
                    var maxTakenTime = layerTime + 0.1
                    var finised = false
                    loop: while true {
                        let isReady = layer.isReadyForMoreMediaData
                        
                        if isReady {
                            switch takeFrame() {
                            case let .restoreState(frames, atTime):
                                layer.flush()
                                for i in 0 ..< frames.count {
                                    let frame = frames[i]
                                    let frameTime = CMTimeGetSeconds(frame.position)
                                    maxTakenTime = frameTime
                                    let attachments = CMSampleBufferGetSampleAttachmentsArray(frame.sampleBuffer, createIfNecessary: true)! as NSArray
                                    let dict = attachments[0] as! NSMutableDictionary
                                    if i == 0 {
                                        CMSetAttachment(frame.sampleBuffer, key: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding as NSString, value: kCFBooleanTrue as AnyObject, attachmentMode: kCMAttachmentMode_ShouldPropagate)
                                        CMSetAttachment(frame.sampleBuffer, key: kCMSampleBufferAttachmentKey_EndsPreviousSampleDuration as NSString, value: kCFBooleanTrue as AnyObject, attachmentMode: kCMAttachmentMode_ShouldPropagate)
                                    }
                                    if CMTimeCompare(frame.position, atTime) < 0 {
                                        dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DoNotDisplay as NSString as String)
                                    } else if CMTimeCompare(frame.position, atTime) == 0 {
                                        dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DisplayImmediately as NSString as String)
                                        dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleBufferAttachmentKey_EndsPreviousSampleDuration as NSString as String)
                                        //print("restore state to \(frame.position) -> \(frameTime) at \(layerTime) (\(i + 1) of \(frames.count))")
                                    }
                                    layer.enqueue(frame.sampleBuffer)
                                }

                            case let .frame(frame):
                                numFrames += 1
                                let frameTime = CMTimeGetSeconds(frame.position)
                                if frame.resetDecoder {
                                    layer.flush()
                                }
                                
                                if frame.decoded && frameTime < layerTime {
                                    continue loop
                                }
                                
                                //print("took frame at \(frameTime) current \(layerTime)")
                                maxTakenTime = frameTime
                                layer.enqueue(frame.sampleBuffer)
                                

                            case .skipFrame:
                                break
                            case .noFrames:
                                finised = true
                                break loop
                            case .finished:
                                finised = true
                                break loop
                            }
                        } else {
                            break loop
                        }
                    }
                    if finised {
                        status = .finished
                    } else {
                        status = .delay(max(1.0 / 30.0, maxTakenTime - layerTime))
                    }
                    //print("took \(numFrames) frames, status \(status)")
                }
                DispatchQueue.main.async {
                    layerRef.release()
                    
                    completion(status)
                }
            }
        }
    }
    
    public var transformArguments: TransformImageArguments? {
        didSet {
            self.updateLayout()
        }
    }
    
    public init(backgroundThread: Bool = false) {
        self.videoNode = MediaPlayerViewDisplayView()
        
        
        super.init()
        
        self.videoNode.updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                if strongSelf.videoInHierarchy != value {
                    strongSelf.videoInHierarchy = value
                    if value {
                        strongSelf.updateState()
                    }
                }
                strongSelf.updateVideoInHierarchy?(value)
            }
        }
        self.addSubview(self.videoNode)
        
        let videoLayer = MediaPlayerViewLayer()
        if #available(macOS 10.15, *) {
            videoLayer.preventsCapture = self.preventsCapture
        } 
        videoLayer.videoGravity = .resize
        
       // #if arch(x86_64)
//        if let sublayers = videoLayer.sublayers {
//            findContentsLayer(sublayers)?.minificationFilter = .nearest
//        }
       // #endif
        
        self.videoLayer = videoLayer
        self.updateLayout()
        self.layer?.addSublayer(videoLayer)
        self.updateState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.videoLayer?.removeFromSuperlayer()
        self.videoLayer?.flushAndRemoveImage()
    }
    
    public override var frame: CGRect {
        didSet {
            if !oldValue.size.equalTo(self.frame.size) {
                self.updateLayout()
            }
        }
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        let oldValue = self.frame
        super.setFrameSize(newSize)
        if !oldValue.size.equalTo(self.frame.size) {
            self.updateLayout()
        }
    }
    
    public func updateLayout() {
        let bounds = self.bounds
        
        let fittedRect: CGRect
        if let arguments = self.transformArguments {
            let drawingRect = bounds
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - bounds.size.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = bounds.size.width
            }
            if abs(fittedSize.height - bounds.size.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = bounds.size.height
            }
            
            fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
        } else {
            fittedRect = bounds
        }
        
        if let videoLayer = self.videoLayer {
            videoLayer.position = CGPoint(x: fittedRect.midX, y: fittedRect.midY)
            videoLayer.bounds = CGRect(origin: CGPoint(), size: fittedRect.size)
        }
    }
    
    public func reset() {
        self.videoLayer?.flush()
    }
}
