//
//  File.swift
//  
//
//  Created by Mike Renoir on 15.01.2024.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import MetalEngine
import AppKit

private func resolveVideoRotationAngle(angle: Float, followsDeviceOrientation: Bool) -> Float {
    return angle
}


public class MetalCallVideoView : LayerBackedView {
    
    struct VideoMetrics: Equatable {
           var resolution: CGSize
           var rotationAngle: Float
           var followsDeviceOrientation: Bool
           var sourceId: Int
           
           init(resolution: CGSize, rotationAngle: Float, followsDeviceOrientation: Bool, sourceId: Int) {
               self.resolution = resolution
               self.rotationAngle = rotationAngle
               self.followsDeviceOrientation = followsDeviceOrientation
               self.sourceId = sourceId
           }
       }

    
    private let videoLayer: PrivateCallVideoLayer = .init()
    //private let visual = VisualEffect
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.addSublayer(videoLayer.blurredLayer)
        videoLayer.blurredLayer.opacity = 0.2
        self.layer?.addSublayer(videoLayer)
        videoLayer.frame = frameRect
        videoLayer.isDoubleSided = false
        videoLayer.contentsGravity = .resizeAspect
        videoLayer.blurredLayer.contentsGravity = .resizeAspectFill
        
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private var videoOnUpdatedListener: Disposable?
    private var videoMetrics: VideoMetrics? {
        didSet {
            if oldValue != videoMetrics {
                updateLayout(size: self.frame.size, transition: .immediate)
            }
        }
    }

    public var firstFrameRendered: (()->Void)?

    public var video: VideoSource? {
        didSet {
            if let video = video {
                self.videoOnUpdatedListener?.dispose()
                
                
                self.videoOnUpdatedListener = video.addOnUpdated { [weak self] in
                    guard let self else {
                        return
                    }
                    if let currentOutput = self.video?.currentOutput {
                        
                        var aspect = currentOutput.resolution.aspectFitted(self.frame.size) * System.backingScale
                        
                        if currentOutput.rotationAngle == Float.pi * 0.5 || currentOutput.rotationAngle == Float.pi * 3.0 / 2.0 {
                            aspect = NSMakeSize(aspect.height, aspect.width)
                        }

                        self.videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(aspect.width), height: Int(aspect.height)), edgeInset: 0)
                        self.videoLayer.video = currentOutput
                        
                        self.videoMetrics = VideoMetrics(resolution: currentOutput.resolution, rotationAngle: currentOutput.rotationAngle, followsDeviceOrientation: currentOutput.followsDeviceOrientation, sourceId: currentOutput.sourceId)

                    } else {
                        self.videoLayer.renderSpec = nil
                        self.videoLayer.video = nil
                        self.videoMetrics = nil
                    }
                    
                    if self.firstFrameRendered != nil {
                        self.firstFrameRendered?()
                        self.firstFrameRendered = nil
                    }

                    
                    self.videoLayer.setNeedsUpdate()
                }
            } else {
                videoOnUpdatedListener?.dispose()
                self.videoLayer.renderSpec = nil
                self.videoLayer.video = nil

            }
            
        }
    }
    
    deinit {
        videoOnUpdatedListener?.dispose()
    }
    
    public override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    public func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
                
        let frame = NSMakeRect(size.width * 0.5, size.height * 0.5, size.width, size.height)
        
        transition.updateFrame(layer: self.videoLayer, frame: frame)
        transition.updateFrame(layer: self.videoLayer.blurredLayer, frame: frame)
     
        self.videoLayer.blurredLayer.frame = size.bounds
        self.videoLayer.frame = size.bounds
    }
    
    public func setGravity(_ gravity: CALayerContentsGravity) {
        self.videoLayer.contentsGravity = gravity
    }
}

