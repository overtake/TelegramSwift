//
//  GifPlayerBufferView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28/05/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramMedia

final class GifPlayerBufferView : TransformImageView {
    var timebase: CMTimebase!
    
    private var videoLayer: (SoftwareVideoLayerFrameManager, SampleBufferLayer)?
    private(set) var imageHolder: CGImage?
    override init() {
        super.init()
        initialize()
    }
    
    private func initialize() {
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        CMTimebaseSetRate(timebase!, rate: 0.0)
        self.timebase = timebase!
    }
    
    private var fileReference: FileMediaReference?
    private var resizeInChat: Bool = false
    
    private(set) var isRendering: Bool = false
    
    func update(_ fileReference: FileMediaReference, context: AccountContext, resizeInChat: Bool = false) -> Void {
        
        let updated = self.fileReference == nil || fileReference.media.fileId != self.fileReference!.media.fileId
        self.fileReference = fileReference
        self.resizeInChat = resizeInChat
        if updated {
            self.isRendering = false
            self.videoLayer?.1.layer.removeFromSuperlayer()
            
            let layerHolder = takeSampleBufferLayer()
            if let gravity = gravity {
                layerHolder.layer.videoGravity = gravity
            } else {
                layerHolder.layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            }
            layerHolder.layer.backgroundColor = NSColor.clear.cgColor
            self.layer?.addSublayer(layerHolder.layer)
            let manager = SoftwareVideoLayerFrameManager(account: context.account, fileReference: fileReference, layerHolder: layerHolder)
            self.videoLayer = (manager, layerHolder)
            
            manager.onRender = { [weak self] in
                if self?.image != nil {
                    self?.imageHolder = self?.image
                    self?.setSignal(signal: .complete())
                    self?.image = nil
                    self?.isRendering = true
                }
            }
            manager.start()
        }
        
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        if let file = fileReference?.media, resizeInChat {
            let dimensions = file.dimensions?.size ?? frame.size
            let size = dimensions.aspectFitted(frame.size)
            let rect = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - size.width) / 2), floorToScreenPixels(backingScaleFactor, (frame.height - size.height) / 2), size.width, size.height)
            videoLayer?.1.layer.frame = rect
        } else {
            videoLayer?.1.layer.frame = bounds
        }
        
    }
    
    private var gravity: AVLayerVideoGravity?
    
    func setVideoLayerGravity(_ gravity: AVLayerVideoGravity) {
        self.gravity = gravity
        videoLayer?.1.layer.videoGravity = gravity
    }
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        initialize()
    }
    
    private var displayLink: ConstantDisplayLinkAnimator?
    var ticking: Bool = false {
        didSet {
            if self.ticking != oldValue {
                if self.ticking {
                    let displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
                        self?.displayLinkEvent()
                    }, fps: 25)
                    self.displayLink = displayLink
                    displayLink.isPaused = false
                    CMTimebaseSetRate(self.timebase, rate: 1.0)
                } else if let displayLink = self.displayLink {
                    self.displayLink = nil
                    displayLink.isPaused = true
                    displayLink.invalidate()
                    CMTimebaseSetRate(self.timebase, rate: 0.0)
                }
            }
        }
    }
    
    
    private func displayLinkEvent() {
        let timestamp = CMTimebaseGetTime(self.timebase).seconds
        self.videoLayer?.0.tick(timestamp: timestamp)
    }
    

    private let maskLayer = CAShapeLayer()
    
    var positionFlags: LayoutPositionFlags? {
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
    
}
