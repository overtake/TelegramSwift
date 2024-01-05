//
//  SampleBufferPool.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26/05/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import Foundation
import AVFoundation
import SwiftSignalKit


private final class SampleBufferLayerImplNullAction: NSObject, CAAction {
    @objc func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

private final class SampleBufferLayerImpl: AVSampleBufferDisplayLayer {
    override func action(forKey event: String) -> CAAction? {
        return SampleBufferLayerImplNullAction()
    }
}

public final class SampleBufferLayer {
    public let layer: AVSampleBufferDisplayLayer
    private let enqueue: (AVSampleBufferDisplayLayer) -> Void
    
    
    var isFreed: Bool = false
    public init(layer: AVSampleBufferDisplayLayer, enqueue: @escaping (AVSampleBufferDisplayLayer) -> Void) {
        self.layer = layer
        self.enqueue = enqueue
    }
    
    deinit {
        if !isFreed {
            self.enqueue(self.layer)
        }
    }
}

private let pool = Atomic<[AVSampleBufferDisplayLayer]>(value: [])

func clearSampleBufferLayerPoll() {
    let _ = pool.modify { _ in return [] }
}

public func takeSampleBufferLayer() -> SampleBufferLayer {
    var layer: AVSampleBufferDisplayLayer?
    if layer == nil {
        layer = SampleBufferLayerImpl()
    }
    return SampleBufferLayer(layer: layer!, enqueue: { layer in
        Queue.mainQueue().async {
            layer.flushAndRemoveImage()
            layer.setAffineTransform(CGAffineTransform.identity)
        }
    })
}
