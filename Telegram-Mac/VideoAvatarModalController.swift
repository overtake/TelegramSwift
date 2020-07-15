//
//  VideoAvatarModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/06/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SyncCore


private final class VideoAvatarModalView : View {
    private let captureContainer = View(frame: NSMakeRect(0, 0, 300, 400))
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(captureContainer)
    }
    
    func updateWithSession(_ session: AVCaptureSession) {
    }
    
    
    
    func didStartedRecording() {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    override func layout() {
        super.layout()
        captureContainer.center()
    }
}

class VideoAvatarModalController: ModalViewController {
    private let context: AccountContext
    init(context: AccountContext, asset: AVURLAsset, track: AVAssetTrack) {
        self.context = context
        
        super.init(frame: NSMakeRect(0, 0, 300, 400))
        
        guard let track = asset.tracks(withMediaType: .video).first else {
            return
        }
        let size = track.naturalSize.applying(track.preferredTransform)
        
        
    }
    
    override var background: NSColor {
        return .clear
    }
    override var isVisualEffectBackground: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return VideoAvatarModalView.self
    }
    
    private var genericView: VideoAvatarModalView {
        return self.view as! VideoAvatarModalView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        
        readyOnce()
    }
}
