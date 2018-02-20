//
//  VideoRecorderModalView.swift
//  Telegram
//
//  Created by keepcoder on 27/09/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class VideoRecorderModalView: View {
    private let captureLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer()
    private let captureContainer: View = View()
    private let placeholderView: ImageView = ImageView()
    private let progressView:  RadialProgressView
    private let previewPlayer: GIFPlayerView = GIFPlayerView()
    private let shadowView: ImageView = ImageView()
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    init(frame frameRect: NSRect, thumbnail: CGImage?) {
        progressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: theme.colors.blueUI, icon: nil, iconInset: NSEdgeInsets(), lineWidth: 4), twist: false)
        super.init(frame: frameRect)
        addSubview(shadowView)
        addSubview(captureContainer)

        
        
        captureContainer.addSubview(previewPlayer)
        
        backgroundColor = .clear
        captureContainer.setFrameSize(frameRect.width - 36, frameRect.height - 36)
        placeholderView.animates = false
        placeholderView.image = thumbnail ?? #imageLiteral(resourceName: "VideoMessagePlaceholder").precomposed()
        placeholderView.sizeToFit()
        captureContainer.addSubview(placeholderView)
        placeholderView.center()
        
        captureContainer.layer?.addSublayer(captureLayer)
        captureLayer.videoGravity = .resizeAspectFill
        captureLayer.frame = captureContainer.bounds
        captureContainer.layer?.cornerRadius = captureContainer.frame.width/2
        captureLayer.opacity = 0
        
        progressView.frame = NSMakeRect(0, 0, captureContainer.frame.width + 17, captureContainer.frame.height + 17)
        addSubview(progressView)
        
        previewPlayer.frame = captureContainer.bounds
        
        shadowView.image = #imageLiteral(resourceName: "Icon_VideoMessageShadow").precomposed()
        shadowView.setFrameSize(NSMakeSize(frameRect.width, frameRect.height))
    }
    
    func updateWithSession(_ session: AVCaptureSession) {
        captureLayer.session = session
        captureLayer.connection?.automaticallyAdjustsVideoMirroring = false
        captureLayer.connection?.isVideoMirrored = true
    }
    
    func updateForPreview(_ path:String? = nil, preview: CGImage?) -> Void {
        previewPlayer.set(path: path)
        placeholderView.image = preview
        
        previewPlayer.isHidden = path == nil
        
        if let _ = path {
            placeholderView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2)
        } else {
            placeholderView.layer?.opacity = 1
        }
        
        progressView.change(opacity: 0, removeOnCompletion: false) { [weak self] completed in
            if completed {
                self?.progressView.removeFromSuperview()
            }
        }
        captureLayer.removeFromSuperlayer()

    }
    
    func updateProgress(_ progress: Float) {
        progressView.state = .ImpossibleFetching(progress: progress, force: true)
    }
    
    func didStartedRecording() {
        captureLayer.opacity = 1
        placeholderView.change(opacity: 0.0, duration: 1.0)
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        captureContainer.center()
        progressView.center()
        shadowView.center()
    }
    
}
