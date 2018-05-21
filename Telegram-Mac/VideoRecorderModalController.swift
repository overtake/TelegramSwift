//
//  VideoRecorderModalController.swift
//  Telegram
//
//  Created by keepcoder on 27/09/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

class VideoRecorderModalController: ModalViewController {

    private let pipeline: VideoRecorderPipeline
    private let chatInteraction: ChatInteraction
    
    private let disposable = MetaDisposable()
    private let countdownDisposable = MetaDisposable()
    
    override func viewClass() -> AnyClass {
        return VideoRecorderModalView.self
    }
    
    private var genericView: VideoRecorderModalView {
        return view as! VideoRecorderModalView
    }
    
    init(chatInteraction: ChatInteraction, pipeline: VideoRecorderPipeline) {
        self.chatInteraction = chatInteraction
        self.pipeline = pipeline
        super.init(frame: NSMakeRect(0, 0, 220, 220))
        bar = .init(height: 0)
    }
    
    var pathForThumbnail: String {
        return NSTemporaryDirectory() + "video_last_thumbnail.jpg"
    }
    
    
    private func saveThumbnail(_ thumb: CGImage) {
        var blurred: CGImage = thumb
        for _ in 0 ..< 10 {
            blurred = blurred.blurred
        }
        _ = blurred.saveToFile(pathForThumbnail)
    }
    
    override func initializer() -> NSView {
        return VideoRecorderModalView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), thumbnail: .loadFromFile(pathForThumbnail))
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
        genericView.updateWithSession(pipeline.session)
        pipeline.start()
        
        disposable.set((pipeline.statePromise.get() |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                switch status {
                case let .finishRecording(path, _, _, thumb):
                    strongSelf.countdownDisposable.set(nil)
                    strongSelf.genericView.updateForPreview(path, preview: thumb)
                    strongSelf.pipeline.stopCapture()
                case .recording:
                    strongSelf.genericView.didStartedRecording()
                    strongSelf.runTimer()
                case .madeThumbnail(let thumb):
                    strongSelf.saveThumbnail(thumb)
                case let .stopped(thumb):
                    strongSelf.countdownDisposable.set(nil)
                    strongSelf.genericView.updateForPreview(preview: thumb)
                    strongSelf.pipeline.stopCapture()
                default:
                    break
                }
            }
        }))
        
        
    }
    
    private func runTimer() {
        countdownDisposable.set((pipeline.powerAndDuration.get() |> deliverOnMainQueue).start(next: { [weak self] _, duration in
            guard let `self` = self else {return}
            self.genericView.updateProgress(Float(duration / VideoRecorderPipeline.videoMessageMaxDuration))
            
            if duration >= VideoRecorderPipeline.videoMessageMaxDuration {
                self.stopAndMakeRecordedVideo()
                if let stateData = self.chatInteraction.presentation.recordingState?.data {
                    self.chatInteraction.mediaPromise.set(stateData)
                }
                self.chatInteraction.update({$0.withoutRecordingState()})
                self.close()
            }
            
        }))
    }
    
    deinit {
        disposable.dispose()
        countdownDisposable.dispose()
    }
    
    override var handleAllEvents: Bool {
        return false
    }
    
    private func stopAndMakeRecordedVideo() {
        countdownDisposable.set(nil)
        pipeline.stop()
    }
    
    override var handleEvents: Bool {
        return true
    }
    
    
    override func escapeKeyAction() -> KeyHandlerResult {
        close()
        chatInteraction.presentation.recordingState?.stop()
        chatInteraction.update({$0.withoutRecordingState()})
        return .invoked
    }
    

    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override var background: NSColor {
        return .clear
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override var isFullScreen: Bool {
        return false
    }
}
