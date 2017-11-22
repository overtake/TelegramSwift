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
private let imagesThreadPool = ThreadPool(threadCount: 10, threadPriority: 0.1)

open class TransformImageView: NSView {
    public var imageUpdated: (() -> Void)?
    public var alphaTransitionOnFirstUpdate = false
    private let disposable = MetaDisposable()
    private let cachedDisposable = MetaDisposable()
    public var animatesAlphaOnFirstTransition:Bool = false
    private let argumentsPromise = Promise<TransformImageArguments>()
    private var first:Bool = true
    public init() {
        super.init(frame: NSZeroRect)
        self.wantsLayer = true
        self.layer?.disableActions()
        self.background = .clear
    }
    
    required public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.disableActions()
        self.background = .clear
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
    
    public func setSignal(signal: Signal<CGImage?, Void>) {
        self.disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] image in
            self?.layer?.contents = image
        }))
    }
    
    
    public func setSignal(_ signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>, clearInstantly: Bool = true, animate:Bool = false, cacheImage:(Signal<CGImage?, Void>) -> Signal<Void, Void> = {_ in return .single(Void())}) {
        if clearInstantly {
            self.layer?.contents = nil
        }
        let result = combineLatest(signal, argumentsPromise.get() |> distinctUntilChanged) |> deliverOn(imagesThreadPool) |> mapToThrottled { transform, arguments -> Signal<CGImage?, NoError> in
            return deferred {
                return Signal<CGImage?, NoError>.single(transform(arguments)?.generateImage())
            }
        }
        
        cachedDisposable.set(cacheImage(result).start())
        
        self.disposable.set((result |> deliverOnMainQueue).start(next: {[weak self] next in
            
            if let strongSelf = self  {
                if strongSelf.layer?.contents == nil && strongSelf.animatesAlphaOnFirstTransition {
                    strongSelf.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                
                self?.layer?.contents = next
                
                if !strongSelf.first && animate {
                    self?.layer?.animateContents()
                }
                strongSelf.first = false
            }
            
        }))
    }
    
    public func set(arguments:TransformImageArguments) ->Void {
        argumentsPromise.set(.single(arguments))
    }

    
    override open func copy() -> Any {
        let view = NSView()
        view.wantsLayer = true
        view.background = .clear
        view.layer?.frame = NSMakeRect(0, visibleRect.minY == 0 ? 0 : visibleRect.height - frame.height, frame.width,  frame.height)
        view.layer?.contents = self.layer?.contents
        view.layer?.masksToBounds = true
        view.frame = self.visibleRect
        view.layer?.shouldRasterize = true
        view.layer?.rasterizationScale = backingScaleFactor
        return view
    }
    
    
}
