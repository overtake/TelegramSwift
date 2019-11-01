//
//  LottieTestModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Lottie
private final class LottieTestView : ImageView {
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
//        let animation = Animation.named("archive", bundle: Bundle.main, subdirectory: nil, animationCache: LRUAnimationCache.sharedCache)
//        let starAnimationView = AnimationView(animation: animation)
//        addSubview(starAnimationView)
//        starAnimationView.setFrameSize(50, 50)
//        starAnimationView.center()
//
//
//        starAnimationView.play(completion: { completed in
//
//        })
        
        
       

        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LottieTestModalController: ModalViewController {

    override init() {
        super.init(frame: NSMakeRect(0, 0, 512, 512))
    }
    
    override func viewClass() -> AnyClass {
        return LottieTestView.self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
}
