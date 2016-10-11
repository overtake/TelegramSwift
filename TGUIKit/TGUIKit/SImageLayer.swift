//
//  SImageLayer.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
open class SImageLayer: CALayer {

    private let disposable = MetaDisposable()
    
    deinit {
        self.cancel()
    }
    
    public override init() {
        super.init();
        self.drawsAsynchronously = System.drawAsync
    }
//    
//    open override func action(forKey event: String) -> CAAction? {
//        return nil
//    }
    
    public override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func cancel(_ erase:Bool = false) -> Void {
        disposable.dispose()
        if(erase) {
            self.contents = nil
        }
    }
    
    public func load(_ signal:Signal<CGImage?,NoError>?) -> Void {
        
        self.contents = nil
        
        if let signal = signal {
             disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] (image) in
                self?.contents = image
                self?.animate()

             }))

 
        }
        
    }
    
    public func animate() -> Void {
        let  animation = CABasicAnimation(keyPath: "contents")
        animation.duration = 0.2
        add(animation, forKey: "contents")
    }
    
}
