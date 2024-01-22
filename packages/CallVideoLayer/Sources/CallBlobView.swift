//
//  File.swift
//  
//
//  Created by Mike Renoir on 22.01.2024.
//

import Foundation
import TGUIKit

public class CallBlobView : LayerBackedView {
    private let blob = CallBlobsLayer()
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        blob.frame = frameRect.size.bounds
        self.layer?.addSublayer(blob)
        blob.masksToBounds = false
        blob.isInHierarchy = true
        self.layer?.masksToBounds = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateLevel(_ level: CGFloat) {
        
    }
}
