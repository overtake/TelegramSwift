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
    let wantsView: Bool = true
    let hasLinks: Bool = false
    let isInteractive: Bool = true
    let separatesTiles: Bool = false

    let webPage: TelegramMediaWebpage
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, medias: [InstantPageMedia]) {
        self.frame = frame
        self.webPage = webPage
        self.medias = medias
    }
    
    func drawInTile(context: CGContext) {
        
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesView(_ node: InstantPageView) -> Bool {
        if let view = node as? InstantPageSlideshowView {
            return self.medias == view.medias
        }
        return false
    }

    
    func view(arguments: InstantPageItemArguments, currentExpandedDetails: [Int : Bool]?) -> (InstantPageView & NSView)? {
        return InstantPageSlideshowView(frameRect: frame, medias: medias, context: arguments.context)
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
    private let slideView: SliderView
    init(frameRect: NSRect, medias: [InstantPageMedia], context: AccountContext) {
        self.medias = medias
        slideView = SliderView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(slideView)
        
        for media in medias {
            var arguments: InstantPageMediaArguments = .image(interactive: true, roundCorners: false, fit: false)
            if let media = media.media as? TelegramMediaFile {
                if media.isVideo {
                    arguments = .video(interactive: true, autoplay: media.isAnimated)
                }
            }
            let view = InstantPageMediaView(context: context, media: media, arguments: arguments)
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
        
        return slideView.displayedSlide?.copy() ?? super.copy()
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
