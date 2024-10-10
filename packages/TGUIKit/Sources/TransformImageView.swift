//
//  TransformImageView.swift
//  TelegramMac
//
//  Created by keepcoder on 18/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import AVFoundation
import SwiftSignalKit

private let threadPool = ThreadPool(threadCount: 1, threadPriority: 0.1)

public class CaptureProtectedContentLayer: AVSampleBufferDisplayLayer {
    public override func action(forKey event: String) -> CAAction? {
        return nullAction
    }
}


open class TransformImageView: NSView {
    public var imageUpdated: ((Any?) -> Void)?
    private let disposable = MetaDisposable()
    public var animatesAlphaOnFirstTransition:Bool = false
    private let argumentsPromise = Promise<TransformImageArguments>()
    public private(set) var isFullyLoaded: Bool = false
    public var ignoreFullyLoad:Bool = false
    private var first:Bool = true
    public init() {
        super.init(frame: NSZeroRect)
        self.wantsLayer = true
        self.layer?.disableActions()
        self.background = .clear
        layerContentsRedrawPolicy = .never
    }
    
    public func clear() {
        self.isFullyLoaded = false
        self.image = nil
        self.disposable.set(nil)
    }
    
    open override var isFlipped: Bool {
        return true
    }
    private var _image: CGImage? = nil
    private var sampleBuffer: CMSampleBuffer? {
        didSet {
            if sampleBuffer != nil {
                var bp = 0
                bp += 1
            }
        }
    }
    
    public var image: CGImage? {
        set {
            layer?.contents = newValue
            if _image != newValue {
                imageUpdated?(newValue)
                _image = newValue
            }
            
           
            
            let preventsCapture = self.preventsCapture
            self.preventsCapture = preventsCapture
  
        }
        get {
            return _image
        }
    }
    
    
    open override var bounds: CGRect {
        didSet {
            if let captureProtectedContentLayer = self.captureProtectedContentLayer {
                captureProtectedContentLayer.frame = super.bounds
            }
        }
    }

    open override var frame: CGRect {
        didSet {
            if let captureProtectedContentLayer = self.captureProtectedContentLayer {
                captureProtectedContentLayer.frame = super.bounds
            }
        }
    }

    
    private var captureProtectedContentLayer: CaptureProtectedContentLayer?

    
    public var preventsCapture: Bool = false {
        didSet {
            if self.preventsCapture {
                if self.captureProtectedContentLayer == nil {
                    let captureProtectedContentLayer = CaptureProtectedContentLayer()

                    captureProtectedContentLayer.frame = self.bounds
                    
                    if #available(macOS 10.15, *) {
                        captureProtectedContentLayer.preventsCapture = true
                    }
                    
                    self.layer?.addSublayer(captureProtectedContentLayer)
                    
                    self.captureProtectedContentLayer = captureProtectedContentLayer
                }
                self.layer?.contents = nil
                if let sampleBuffer = self.sampleBuffer {
                    self.captureProtectedContentLayer?.enqueue(sampleBuffer)
                }
            } else {
                if let captureProtectedContentLayer = self.captureProtectedContentLayer {
                    self.captureProtectedContentLayer = nil
                    captureProtectedContentLayer.removeFromSuperlayer()
                }
                self.layer?.contents = self.image
            }
        }
    }

    
    required public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.disableActions()
        self.background = .clear
        layerContentsRedrawPolicy = .never
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    
    public func dispose() {
        disposable.set(nil)
    }
    
    public func setSignal(signal: Signal<TransformImageResult?, NoError>, clearInstantly: Bool = true, animate: Bool = false) {
        self.disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] result in
            
            let hasImage = self?.image != nil
            self?.sampleBuffer = result?.sampleBuffer
            if clearInstantly {
                self?.image = result?.image
            } else if let image = result?.image {
                self?.image = image
            }
            if !hasImage && animate {
                self?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            } else if animate {
                self?.layer?.animateContents()
            }
            self?.isFullyLoaded = result?.highQuality ?? false
        }))
    }
    
    open override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    
    public func setSignal(_ signal: Signal<ImageDataTransformation, NoError>, clearInstantly: Bool = false, animate:Bool = false, synchronousLoad: Bool = false, cacheImage:@escaping(TransformImageResult) -> Void = { _ in }, isProtected: Bool = false) {
        if clearInstantly {
            self.image = nil
        }
        
        if !isProtected {
            var bp = 0
            bp += 1
        }
        
        if isFullyLoaded && !ignoreFullyLoad {
            disposable.set(nil)
            isFullyLoaded = false
            return
        }
        
        var combine = combineLatest(signal, argumentsPromise.get() |> distinctUntilChanged)
        
        if !synchronousLoad {
            combine = combine |> deliverOn(threadPool)
        }
        
        let result = combine |> map { data, arguments -> TransformImageResult in
            let context = data.execute(arguments, data.data)
            let image = context?.generateImage()
            return TransformImageResult(image, context?.isHighQuality ?? false, isProtected ? image?.cmSampleBuffer : nil)
        } |> deliverOnMainQueue
        
        self.disposable.set(result.start(next: { [weak self] result in
            if let strongSelf = self  {
                if strongSelf.image == nil && strongSelf.animatesAlphaOnFirstTransition {
                    strongSelf.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                self?.sampleBuffer = result.sampleBuffer
                self?.image = result.image
                if !strongSelf.first && animate {
                    self?.layer?.animateContents()
                }
                strongSelf.first = false
                cacheImage(result)
            }
        }))

    }
    
    
    open override var isHidden: Bool {
        didSet {
           
        }
    }
    
    public var hasImage: Bool {
        return image != nil
    }
    
    public func set(arguments:TransformImageArguments) ->Void {
        argumentsPromise.set(.single(arguments))
    }

    
    override open func copy() -> Any {
        
        let visibleRect = self.effectiveVisibleRect
        
        let view = NSView()
        view.wantsLayer = true
        view.background = .clear
        view.layer?.contents = self.image
        view.frame = visibleRect
        view.layer?.masksToBounds = true
   
        
        if bounds != visibleRect {
            if let image = self.layer?.contents {
                view.layer?.contents = generateImage(bounds.size, contextGenerator: { size, ctx in
                    ctx.clear(bounds)
                    ctx.setFillColor(.clear)
                    ctx.fill(bounds)
                    if visibleRect.minY != 0  {
                        ctx.clip(to: NSMakeRect(0, 0, bounds.width, bounds.height - ( bounds.height - visibleRect.height)))
                    } else {
                        ctx.clip(to: NSMakeRect(0, (bounds.height - visibleRect.height), bounds.width, bounds.height - ( bounds.height - visibleRect.height)))
                    }
                    ctx.draw(image as! CGImage, in: bounds)
                }, opaque: false)
            }
        }

        view.layer?.shouldRasterize = true
        view.layer?.rasterizationScale = backingScaleFactor

        return view
    }
    
    
}
