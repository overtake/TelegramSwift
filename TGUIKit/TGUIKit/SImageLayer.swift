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
      //  self.drawsAsynchronously = System.drawAsync
        self.disableActions()
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
    

    
    public func setSignal(_ signal: Signal<CGImage?, NoError>) {
        var first = true
        self.disposable.set((signal |> deliverOnMainQueue).start(next: {[weak self] next in
           // dispatcher.dispatch {
                if let strongSelf = self {
                    strongSelf.contents = next
                    if first {
                        first = false
                       // if strongSelf.isNodeLoaded {
                          //  strongSelf.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                       // }
                    }
                }
          //  }
        }))
    }
    
    open override func removeFromSuperlayer() {
        super.removeFromSuperlayer()
        disposable.set(nil)
    }
    

    
    public func animate() -> Void {
        let  animation = CABasicAnimation(keyPath: "contents")
        animation.duration = 0.2
        add(animation, forKey: "contents")
    }
    
}
