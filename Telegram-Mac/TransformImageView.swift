//
//  TransformImageView.swift
//  TelegramMac
//
//  Created by keepcoder on 18/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit
private let imagesThreadPool = ThreadPool(threadCount: 3, threadPriority: 0.1)

open class TransformImageView: NSView {
    public var imageUpdated: ((Any?) -> Void)?
    private let disposable = MetaDisposable()
    private let cachedDisposable = MetaDisposable()
    public var animatesAlphaOnFirstTransition:Bool = false
    private let argumentsPromise = Promise<TransformImageArguments>()
    private var isFullyLoaded: Bool = false
    public var ignoreFullyLoad:Bool = false
    private var first:Bool = true
    public init() {
        super.init(frame: NSZeroRect)
        self.wantsLayer = true
        self.layer?.disableActions()
        self.background = .clear
        layerContentsRedrawPolicy = .never
    }
    
    
    
    var image: Any? {
        set {
            layer?.contents = newValue
            imageUpdated?(newValue)
        }
        get {
            return layer?.contents
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
        cachedDisposable.dispose()
    }
    
    
    public func dispose() {
        disposable.set(nil)
    }
    
    public func setSignal(signal: Signal<(CGImage?, Bool), NoError>, clearInstantly: Bool = true) {
        self.disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] image, isFullyLoaded in
            if clearInstantly {
                self?.image = image
            } else if let image = image {
                self?.image = image
            }
            self?.isFullyLoaded = isFullyLoaded
        }))
    }
    
    
    public func setSignal(_ signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>, clearInstantly: Bool = false, animate:Bool = false, synchronousLoad: Bool = false, cacheImage:@escaping(Signal<(CGImage?, Bool), NoError>) -> Signal<Void, NoError> = { signal in return signal |> map {_ in return}}) {
        if clearInstantly {
            self.image = nil
        }
        
        if isFullyLoaded && !ignoreFullyLoad {
            disposable.set(nil)
            isFullyLoaded = false
            return
        }
        
        var combine = combineLatest(signal, argumentsPromise.get() |> distinctUntilChanged)
        
        if !synchronousLoad {
            combine = combine |> deliverOn(imagesThreadPool)
        }
        
        let result = combine |> mapToThrottled { transform, arguments -> Signal<(CGImage?, Bool), NoError> in
            return deferred {
                let context = transform(arguments)
                return Signal<(CGImage?, Bool), NoError>.single((context?.generateImage(), context?.isHighQuality ?? true))
            }
        }
        
        self.disposable.set((result |> deliverOnMainQueue |> beforeNext { [weak self] (next, isThumb) in
            if let strongSelf = self  {
                if strongSelf.image == nil && strongSelf.animatesAlphaOnFirstTransition {
                    strongSelf.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                self?.image = next
                if !strongSelf.first && animate {
                    self?.layer?.animateContents()
                }
                strongSelf.first = false
                _ = cacheImage(.single((next, isThumb))).start()
            }
        }).start())

    }
    
    public var hasImage: Bool {
        return image != nil
    }
    
    public func set(arguments:TransformImageArguments) ->Void {
        argumentsPromise.set(.single(arguments))
    }

    
    override open func copy() -> Any {
        let view = NSView()
        view.wantsLayer = true
        
        
        
        
        view.background = .clear
        view.layer?.contents = self.image
        view.frame = self.visibleRect
        view.layer?.masksToBounds = true
   
        
        if bounds != visibleRect {
            if let image = self.layer?.contents {
                view.layer?.contents = generateImage(bounds.size, contextGenerator: { size, ctx in
                    ctx.clear(bounds)
                    ctx.setFillColor(.clear)
                    ctx.fill(bounds)
                    if visibleRect.minY == 0  {
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
