//
//  InstantPageSlideshowItem.swift
//  Telegram
//
//  Created by keepcoder on 17/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit

class InstantPageSlideshowItem: InstantPageItem {
    var frame: CGRect
    
    let medias: [InstantPageMedia]
    let wantsNode: Bool = true
    let hasLinks: Bool = false
    let isInteractive: Bool = true
    
    init(frame: CGRect, medias:[InstantPageMedia]) {
        self.frame = frame
        self.medias = medias
    }
    
    func drawInTile(context: CGContext) {
        
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageView) -> Bool {
        if let view = node as? InstantPageSlideshowView {
            return self.medias == view.medias
        }
        return false
    }

    
    func node(account: Account) -> InstantPageView? {
        return InstantPageSlideshowView(frameRect: frame, medias: medias, account: account)
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    func distanceThresholdGroup() -> Int? {
        return 1
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 1000
    }

}

class InstantPageSlideshowView : View, InstantPageView {
    fileprivate let medias: [InstantPageMedia]
    private let slideView: MIHSliderView
    init(frameRect: NSRect, medias: [InstantPageMedia], account: Account) {
        self.medias = medias
        slideView = MIHSliderView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(slideView)
        
        for media in medias {
            var arguments: InstantPageMediaArguments = .image(interactive: true, roundCorners: false, fit: false)
            if let media = media.media as? TelegramMediaFile {
                if media.isVideo {
                    arguments = .video(interactive: true, autoplay: media.isAnimated)
                }
            }
            let view = InstantPageMediaView(account: account, media: media, arguments: arguments)
            slideView.addSlide(view)
        }
        
    }
    
    override func layout() {
        super.layout()
        slideView.center()
    }
    
    var indexOfDisplayedSlide: Int {
        return Int(slideView.indexOfDisplayedSlide)
    }
    
    override func copy() -> Any {
        
        return slideView.displayedSlide.copy()
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
