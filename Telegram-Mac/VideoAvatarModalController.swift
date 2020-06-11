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
    private let captureLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer()
    private let captureContainer = View(frame: NSMakeRect(0, 0, 300, 400))
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        captureContainer.layer?.addSublayer(captureLayer)
        captureLayer.videoGravity = .resizeAspectFill
        captureLayer.frame = captureContainer.bounds
        addSubview(captureContainer)
    }
    
    func updateWithSession(_ session: AVCaptureSession) {
        captureLayer.session = session
        captureLayer.connection?.automaticallyAdjustsVideoMirroring = false
        captureLayer.connection?.isVideoMirrored = true
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
    private let pipeline: VideoRecorderPipeline
    private let path: URL = URL(fileURLWithPath: NSTemporaryDirectory() + "\(arc4random64()).mp4")
    init(context: AccountContext) {
        self.context = context
        self.pipeline = VideoRecorderPipeline(url: path, liveUploading: nil)
        super.init(frame: NSMakeRect(0, 0, 300, 400))
    }
    
    override func viewClass() -> AnyClass {
        return VideoAvatarModalView.self
    }
    
    private var genericView: VideoAvatarModalView {
        return self.view as! VideoAvatarModalView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.updateWithSession(pipeline.session)
        pipeline.start()

        
        readyOnce()
    }
}
