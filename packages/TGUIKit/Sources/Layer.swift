//
//  Layer.swift
//  TGUIKit
//
//  Created by keepcoder on 20/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa


public class Layer: CALayer {

    var s:CALayer?
    
    
    public override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        
        self.layerMoved(to: self.superlayer)
        
        s = self.superlayer
        
    }
    
    public override func removeFromSuperlayer() {
        super.removeFromSuperlayer()
        
        if s != nil {
            s = nil
            self.layerMoved(to: nil)
        }
    }
    
    public func layerMoved(to superlayer:CALayer?) -> Void {
        
    }
    
}
