//
//  NativeMediaPlayer.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramMediaPlayer
import TelegramMedia
import RangeSet
import TelegramCore

final class NativeMediaPlayer : View, UniversalVideoContentView {
    
    
    var duration: Double {
        return reference.media.duration ?? 0
    }
    
    private let mediaPlayerView: MediaPlayerView = MediaPlayerView()
    private let mediaPlayer: MediaPlayer
    private let postbox: Postbox
    private let reference: FileMediaReference
    private let playbackCompletedListeners = Bag<() -> Void>()
    private let fetchDisposable = MetaDisposable()
    
    public var fileRef: FileMediaReference {
        return self.reference
    }

    init(postbox: Postbox, reference: FileMediaReference, fetchAutomatically: Bool = false) {
        self.postbox = postbox
        self.reference = reference
        mediaPlayer = MediaPlayer(postbox: postbox, userLocation: reference.userLocation, userContentType: reference.userContentType, reference: reference.resourceReference(reference.media.resource), streamable: reference.media.isStreamable, video: true, preferSoftwareDecoding: false, enableSound: true, baseRate: FastSettings.playingVideoRate, volume: FastSettings.volumeRate, fetchAutomatically: fetchAutomatically)
        super.init()
        
        mediaPlayer.attachPlayerView(mediaPlayerView)
        
        addSubview(mediaPlayerView)
        
        mediaPlayer.actionAtEnd = .action({ [weak self] in
            self?.performActionAtEnd()
        })
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    var ready: Signal<Void, NoError> {
        return .single(Void())
    }
    
    var status: Signal<MediaPlayerStatus, NoError> {
        return mediaPlayer.status
    }
    
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        let size = reference.media.resource.size ?? 0
        return postbox.mediaBox.resourceRangesStatus(reference.media.resource)
            |> map { ranges -> (RangeSet<Int64>, Int64)? in
                return (ranges, size)
        } |> deliverOnMainQueue
        
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: mediaPlayerView, frame: size.bounds)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func play() {
        mediaPlayer.play()
    }
    
    func pause() {
        mediaPlayer.pause()
    }
    
    func togglePlayPause() {
        mediaPlayer.togglePlayPause()
    }
    
    func setSoundEnabled(_ value: Bool) {
        if value {
            mediaPlayer.toggleSoundEnabled()
        }
    }
    
    func seek(_ timestamp: Double) {
        mediaPlayer.seek(timestamp: timestamp)
    }
    
    func playOnceWithSound(playAndRecord: Bool, actionAtEnd: MediaPlayerActionAtEnd) {
        
    }
    
    func setSoundMuted(soundMuted: Bool) {
        
    }
    
    
    func setBaseRate(_ baseRate: Double) {
        self.mediaPlayer.setBaseRate(baseRate)
    }
    
    func setVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        
    }
    
    func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        return nil
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }

    
    func fetchControl(_ control: UniversalVideoNodeFetchControl) {
        switch control {
        case .fetch:
            self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.postbox.mediaBox, userLocation: self.reference.userLocation, userContentType: .video, reference: self.reference.resourceReference(self.reference.media.resource), statsCategory: statsCategoryForFileWithAttributes(self.reference.media.attributes)).start())
        case .cancel:
            self.postbox.mediaBox.cancelInteractiveResourceFetch(self.reference.media.resource)
        }
    }
    
    func setVolume(_ value: Float) {
        self.mediaPlayer.setVolume(value)
    }
    
    func setVideoLayerGravity(_ gravity: AVLayerVideoGravity) {
        self.mediaPlayerView.setVideoLayerGravity(gravity)
    }

    
    deinit {
        fetchDisposable.dispose()
    }
    
}
