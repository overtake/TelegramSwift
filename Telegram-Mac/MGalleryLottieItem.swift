//
//  MGalleryLottieItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Lottie
import TGUIKit


class MGalleryLottieItem: MGalleryItem {
    let animation: Animation
    override init(_ context: AccountContext, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        switch entry {
        case let .lottie(animation, _):
            self.animation = animation
        default:
            preconditionFailure()
        }
        super.init(context, entry, pagerSize)
        

    }
    
    
    override func appear(for view: NSView?) {
        if let view = view as? AnimationView {
            view.play(completion: { completed in
                
            })
        }
    }
    
    
    override var backgroundColor: NSColor {
        return theme.colors.lottieTransparentBackground
    }
    
    override func request(immediately: Bool = true) {
        let view = AnimationView(animation: animation)
        view.background = backgroundColor
        
        //self.image.set(.single(.image(theme.icons.confirmAppAccessoryIcon)))
        self.image.set(.single(.view(view)))
        self.path.set(.single(context.account.postbox.mediaBox.resourcePath(self.entry.file!.resource)))
    }
    
    override func singleView() -> NSView {
        let view = AnimationView(animation: animation)
        view.loopMode = .loop
        view.layerContentsRedrawPolicy = .duringViewResize

        return view //LottieGalleryView(animation)
    }
    
    override var sizeValue: NSSize {
         return animation.bounds.size.fitted(pagerSize)
    }
    
}
