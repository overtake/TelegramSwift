//
//  MetalVideoRenderView.swift
//  Telegram
//
//  Created by Mike Renoir on 15.01.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import CallVideoLayer
import TgVoipWebrtc
import SwiftSignalKit
import MetalEngine
import TelegramVoip


private func copyI420BufferToNV12Buffer(buffer: OngoingGroupCallContext.VideoFrameData.I420Buffer, pixelBuffer: CVPixelBuffer) -> Bool {
    guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange else {
        return false
    }
    guard CVPixelBufferGetWidthOfPlane(pixelBuffer, 0) == buffer.width else {
        return false
    }
    guard CVPixelBufferGetHeightOfPlane(pixelBuffer, 0) == buffer.height else {
        return false
    }
    
    

    let cvRet = CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if cvRet != kCVReturnSuccess {
        return false
    }
    defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }

    guard let dstY = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
        return false
    }
    let dstStrideY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

    guard let dstUV = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
        return false
    }
    let dstStrideUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

    
    
    buffer.y.withUnsafeBytes { srcYBuffer in
        guard let srcY = srcYBuffer.baseAddress else {
            return
        }
        buffer.u.withUnsafeBytes { srcUBuffer in
            guard let srcU = srcUBuffer.baseAddress else {
                return
            }
            buffer.v.withUnsafeBytes { srcVBuffer in
                guard let srcV = srcVBuffer.baseAddress else {
                    return
                }
                LibYUVConverter.i420ToNV12(withSrcY: srcY.assumingMemoryBound(to: UInt8.self), srcStrideY: Int32(buffer.strideY), srcU: srcU.assumingMemoryBound(to: UInt8.self), srcStrideU: Int32(buffer.strideU), srcV: srcV.assumingMemoryBound(to: UInt8.self), srcStrideV: Int32(buffer.strideV), dstY: dstY.assumingMemoryBound(to: UInt8.self), dstStrideY: Int32(dstStrideY), dstUV: dstUV.assumingMemoryBound(to: UInt8.self), dstStrideUV: Int32(dstStrideUV), width: Int32(buffer.width), height: Int32(buffer.height))
            }
        }
    }

    return true
}

private final class AdaptedCallVideoSource: VideoSource {
    final class I420DataBuffer: Output.DataBuffer {
        private let buffer: OngoingGroupCallContext.VideoFrameData.I420Buffer
        
        override var pixelBuffer: CVPixelBuffer? {
            let ioSurfaceProperties = NSMutableDictionary()
            let options = NSMutableDictionary()
            options.setObject(ioSurfaceProperties, forKey: kCVPixelBufferIOSurfacePropertiesKey as NSString)
            
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                self.buffer.width,
                self.buffer.height,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                options,
                &pixelBuffer
            )
            if let pixelBuffer, copyI420BufferToNV12Buffer(buffer: buffer, pixelBuffer: pixelBuffer) {
                return pixelBuffer
            } else {
                return nil
            }
        }
        
        init(buffer: OngoingGroupCallContext.VideoFrameData.I420Buffer) {
            self.buffer = buffer
            
            super.init()
        }
    }
    
    final class PixelBufferPool {
        let width: Int
        let height: Int
        let pool: CVPixelBufferPool
        
        init?(width: Int, height: Int) {
            self.width = width
            self.height = height
            
            let bufferOptions: [String: Any] = [
                kCVPixelBufferPoolMinimumBufferCountKey as String: 4 as NSNumber
            ]
            let pixelBufferOptions: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as NSNumber,
                kCVPixelBufferWidthKey as String: width as NSNumber,
                kCVPixelBufferHeightKey as String: height as NSNumber,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary
            ]
            
            var pool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, bufferOptions as CFDictionary, pixelBufferOptions as CFDictionary, &pool)
            guard let pool else {
                return nil
            }
            self.pool = pool
        }
    }
    
    final class PixelBufferPoolState {
        var pool: PixelBufferPool?
    }
    
    private static let queue = Queue(name: "AdaptedCallVideoSource")
    private var onUpdatedListeners = Bag<() -> Void>()
    private(set) var currentOutput: Output?
    
    private var textureCache: CVMetalTextureCache?
    private var pixelBufferPoolState: QueueLocalObject<PixelBufferPoolState>
    
    private var videoFrameDisposable: Disposable?
    
    init(videoStreamSignal: Signal<OngoingGroupCallContext.VideoFrameData, NoError>) {
        let pixelBufferPoolState = QueueLocalObject(queue: AdaptedCallVideoSource.queue, generate: {
            return PixelBufferPoolState()
        })
        self.pixelBufferPoolState = pixelBufferPoolState
        
        CVMetalTextureCacheCreate(nil, nil, MetalEngine.shared.device, nil, &self.textureCache)
        
        self.videoFrameDisposable = (videoStreamSignal
        |> deliverOnMainQueue).start(next: { [weak self] videoFrameData in
            guard let self, let textureCache = self.textureCache else {
                return
            }
            
            let rotationAngle: Float
            switch videoFrameData.deviceRelativeOrientation ?? videoFrameData.orientation {
            case .rotation0:
                rotationAngle = 0.0
            case .rotation90:
                rotationAngle = Float.pi * 0.5
            case .rotation180:
                rotationAngle = Float.pi
            case .rotation270:
                rotationAngle = Float.pi * 3.0 / 2.0
            }
            
            let followsDeviceOrientation = videoFrameData.deviceRelativeOrientation != nil
            
            var mirrorDirection: Output.MirrorDirection = []
            
            var sourceId: Int = 0
            if videoFrameData.mirrorHorizontally || videoFrameData.mirrorVertically {
                sourceId = 1
            }
            
            if let deviceRelativeOrientation = videoFrameData.deviceRelativeOrientation, deviceRelativeOrientation != videoFrameData.orientation {
                let shouldMirror = videoFrameData.mirrorHorizontally || videoFrameData.mirrorVertically
                
                var mirrorHorizontally = false
                var mirrorVertically = false
                
                if shouldMirror {
                    switch deviceRelativeOrientation {
                    case .rotation0:
                        mirrorHorizontally = true
                    case .rotation90:
                        mirrorVertically = true
                    case .rotation180:
                        mirrorHorizontally = true
                    case .rotation270:
                        mirrorVertically = true
                    }
                }
                
                if mirrorHorizontally {
                    mirrorDirection.insert(.horizontal)
                }
                if mirrorVertically {
                    mirrorDirection.insert(.vertical)
                }
            } else {
                if videoFrameData.mirrorHorizontally {
                    mirrorDirection.insert(.horizontal)
                }
                if videoFrameData.mirrorVertically {
                    mirrorDirection.insert(.vertical)
                }
            }
            
            AdaptedCallVideoSource.queue.async { [weak self] in
                let output: Output
                switch videoFrameData.buffer {
                case let .argb(nativeBuffer):
                    let width = CVPixelBufferGetWidth(nativeBuffer.pixelBuffer)
                    let height = CVPixelBufferGetHeight(nativeBuffer.pixelBuffer)
                    
                    var cvMetalTexture: CVMetalTexture?
                    var status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, nativeBuffer.pixelBuffer, nil, .rgba8Unorm, width, height, 0, &cvMetalTexture)
                    guard status == kCVReturnSuccess, let rgbaTexture = CVMetalTextureGetTexture(cvMetalTexture!) else {
                        return
                    }
                    output = Output(
                        resolution: CGSize(width: CGFloat(rgbaTexture.width), height: CGFloat(rgbaTexture.height)),
                        textureLayout: .bgra(Output.BGRATextureLayout(bgra: rgbaTexture)),
                        dataBuffer: Output.NativeDataBuffer(pixelBuffer: nativeBuffer.pixelBuffer),
                        rotationAngle: rotationAngle,
                        followsDeviceOrientation: followsDeviceOrientation,
                        mirrorDirection: mirrorDirection,
                        sourceId: sourceId
                    )
                case let .bgra(nativeBuffer):
                    let width = CVPixelBufferGetWidth(nativeBuffer.pixelBuffer)
                    let height = CVPixelBufferGetHeight(nativeBuffer.pixelBuffer)
                    
                    var cvMetalTexture: CVMetalTexture?
                    var status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, nativeBuffer.pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvMetalTexture)
                    guard status == kCVReturnSuccess, let bgraTexture = CVMetalTextureGetTexture(cvMetalTexture!) else {
                        return
                    }
                    output = Output(
                        resolution: CGSize(width: CGFloat(bgraTexture.width), height: CGFloat(bgraTexture.height)),
                        textureLayout: .bgra(Output.BGRATextureLayout(bgra: bgraTexture)),
                        dataBuffer: Output.NativeDataBuffer(pixelBuffer: nativeBuffer.pixelBuffer),
                        rotationAngle: rotationAngle,
                        followsDeviceOrientation: followsDeviceOrientation,
                        mirrorDirection: mirrorDirection,
                        sourceId: sourceId
                    )
                case let .native(nativeBuffer):
                    let width = CVPixelBufferGetWidth(nativeBuffer.pixelBuffer)
                    let height = CVPixelBufferGetHeight(nativeBuffer.pixelBuffer)
                    
                    var cvMetalTextureY: CVMetalTexture?
                    var status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, nativeBuffer.pixelBuffer, nil, .r8Unorm, width, height, 0, &cvMetalTextureY)
                    guard status == kCVReturnSuccess, let yTexture = CVMetalTextureGetTexture(cvMetalTextureY!) else {
                        return
                    }
                    var cvMetalTextureUV: CVMetalTexture?
                    status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, nativeBuffer.pixelBuffer, nil, .rg8Unorm, width / 2, height / 2, 1, &cvMetalTextureUV)
                    guard status == kCVReturnSuccess, let uvTexture = CVMetalTextureGetTexture(cvMetalTextureUV!) else {
                        return
                    }
                    
                    output = Output(
                        resolution: CGSize(width: CGFloat(yTexture.width), height: CGFloat(yTexture.height)),
                        textureLayout: .biPlanar(Output.BiPlanarTextureLayout(
                            y: yTexture,
                            uv: uvTexture
                        )),
                        dataBuffer: Output.NativeDataBuffer(pixelBuffer: nativeBuffer.pixelBuffer),
                        rotationAngle: rotationAngle,
                        followsDeviceOrientation: followsDeviceOrientation,
                        mirrorDirection: mirrorDirection,
                        sourceId: sourceId
                    )
                case let .i420(i420Buffer):
                    guard let pixelBufferPoolState = pixelBufferPoolState.unsafeGet() else {
                        return
                    }
                    
                    let width = i420Buffer.width
                    let height = i420Buffer.height
                    
                    let pool: PixelBufferPool?
                    if let current = pixelBufferPoolState.pool, current.width == width, current.height == height {
                        pool = current
                    } else {
                        pool = PixelBufferPool(width: width, height: height)
                        pixelBufferPoolState.pool = pool
                    }
                    guard let pool else {
                        return
                    }
                    
                    let auxAttributes: [String: Any] = [kCVPixelBufferPoolAllocationThresholdKey as String: 5 as NSNumber]
                    var pixelBuffer: CVPixelBuffer?
                    let result = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool.pool, auxAttributes as CFDictionary, &pixelBuffer)
                    if result == kCVReturnWouldExceedAllocationThreshold {
                        print("kCVReturnWouldExceedAllocationThreshold, dropping frame")
                        return
                    }
                    guard let pixelBuffer else {
                        return
                    }
                    
                    if !copyI420BufferToNV12Buffer(buffer: i420Buffer, pixelBuffer: pixelBuffer) {
                        return
                    }
                    
                    var cvMetalTextureY: CVMetalTexture?
                    var status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .r8Unorm, width, height, 0, &cvMetalTextureY)
                    guard status == kCVReturnSuccess, let yTexture = CVMetalTextureGetTexture(cvMetalTextureY!) else {
                        return
                    }
                    var cvMetalTextureUV: CVMetalTexture?
                    status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .rg8Unorm, width / 2, height / 2, 1, &cvMetalTextureUV)
                    guard status == kCVReturnSuccess, let uvTexture = CVMetalTextureGetTexture(cvMetalTextureUV!) else {
                        return
                    }
                    
                    output = Output(
                        resolution: CGSize(width: CGFloat(yTexture.width), height: CGFloat(yTexture.height)),
                        textureLayout: .biPlanar(Output.BiPlanarTextureLayout(
                            y: yTexture,
                            uv: uvTexture
                        )),
                        dataBuffer: Output.NativeDataBuffer(pixelBuffer: pixelBuffer),
                        rotationAngle: rotationAngle,
                        followsDeviceOrientation: followsDeviceOrientation,
                        mirrorDirection: mirrorDirection,
                        sourceId: sourceId
                    )
                default:
                    return
                }
                
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.currentOutput = output
                    for onUpdated in self.onUpdatedListeners.copyItems() {
                        onUpdated()
                    }
                }
            }
        })
    }
    
    func addOnUpdated(_ f: @escaping () -> Void) -> Disposable {
        let index = self.onUpdatedListeners.add(f)
        
        return ActionDisposable { [weak self] in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.onUpdatedListeners.remove(index)
            }
        }
    }
    
    deinit {
        self.videoFrameDisposable?.dispose()
    }
}

public func MetalVideoMakeView(videoStreamSignal: Signal<OngoingGroupCallContext.VideoFrameData, NoError>) -> MetalCallVideoView {
    let view = MetalCallVideoView(frame: NSMakeRect(0, 0, 300, 300))
    
    let adapter = AdaptedCallVideoSource(videoStreamSignal: videoStreamSignal)
    view.video = adapter
    return view
}
