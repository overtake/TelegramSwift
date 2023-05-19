//
//  DisplayLinkDispatcher.swift
//  TGUIKit
//
//  Created by keepcoder on 15/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Foundation

//public class DisplayLinkDispatcher: NSObject {
//    private var displayLink: CADisplayLink!
//    private var blocksToDispatch: [(Void) -> Void] = []
//    private let limit: Int
//    
//    public init(limit: Int = 0) {
//        self.limit = limit
//        
//        super.init()
//        
//        self.displayLink = CADisplayLink(target: self, selector: #selector(self.run))
//        self.displayLink.preferredFramesPerSecond = 60
//        self.displayLink.isPaused = true
//        self.displayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
//    }
//    
//    public func dispatch(f: @escaping (Void) -> Void) {
//        self.blocksToDispatch.append(f)
//        self.displayLink.isPaused = false
//    }
//    
//    @objc func run() {
//        for _ in 0 ..< (self.limit == 0 ? 1000 : self.limit) {
//            if self.blocksToDispatch.count == 0 {
//                self.displayLink.isPaused = true
//                break
//            } else {
//                let f = self.blocksToDispatch.removeFirst()
//                f()
//            }
//        }
//    }
//}
