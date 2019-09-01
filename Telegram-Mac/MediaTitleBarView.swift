//
//  MediaTitleBarView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 14/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


final class PeerMediaTypeInteraction {
    var media:() -> Void = {}
    var files:() -> Void = {}
    var links:() -> Void = {}
    var audio:() -> Void = {}
    
    init(media:@escaping() -> Void, files:@escaping() -> Void, links:@escaping() -> Void, audio:@escaping() -> Void) {
        self.media = media
        self.files = files
        self.links = links
        self.audio = audio
    }
}



class MediaTitleBarView: TitledBarView {

    
    private let segmentController: SegmentController
    
    private let interactions:PeerMediaTypeInteraction
    public init(controller: ViewController, interactions:PeerMediaTypeInteraction) {
        segmentController = SegmentController(frame: NSMakeRect(0, 0, 300, 28))
        self.interactions = interactions
        super.init(controller: controller)

        addSubview(segmentController.view)
       // updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        needsLayout = true
        segmentController.removeAll()
        segmentController.add(segment: SegmentedItem(title: L10n.peerMediaMedia, handler: { [weak self] in
            self?.interactions.media()
        }))
        
        segmentController.add(segment: SegmentedItem(title: L10n.peerMediaFiles, handler: { [weak self] in
            self?.interactions.files()
        }))
        
        segmentController.add(segment: SegmentedItem(title: L10n.peerMediaLinks, handler: { [weak self] in
            self?.interactions.links()
        }))
        
        segmentController.add(segment: SegmentedItem(title: L10n.peerMediaAudio, handler: { [weak self] in
            self?.interactions.audio()
        }))
    }
    
    
    override func layout() {
        super.layout()
        segmentController.view.setFrameSize(frame.width - 20, segmentController.frame.height)
        segmentController.view.center()
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
