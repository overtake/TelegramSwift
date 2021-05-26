//
//  GroupCallAvatarView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.05.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import SyncCore
import Postbox
import TelegramCore


final class GroupCallAvatarView : View {
    private let playbackAudioLevelView: VoiceBlobView
    private var scaleAnimator: DisplayLinkAnimator?
    private let photoView: AvatarControl = AvatarControl(font: .avatar(20))
    private let audioLevelDisposable = MetaDisposable()
    let photoSize: NSSize
    init(frame frameRect: NSRect, photoSize: NSSize) {
        playbackAudioLevelView = VoiceBlobView(
            frame: frameRect.size.bounds,
            maxLevel: 0.3,
            smallBlobRange: (0, 0),
            mediumBlobRange: (0.7, 0.8),
            bigBlobRange: (0.8, 0.9)
        )
        self.photoSize = photoSize
        super.init(frame: frameRect)
        photoView.setFrameSize(photoSize)
        addSubview(playbackAudioLevelView)
        addSubview(photoView)
        
        self.isEventLess = true
        playbackAudioLevelView.isEventLess = true
        photoView.userInteractionEnabled = false
    }
    
    deinit {
        audioLevelDisposable.dispose()
    }
    
    func update(_ audioLevel:(PeerId)->Signal<Float?, NoError>?, data: PeerGroupCallData, activityColor: NSColor, account: Account, animated: Bool) {
        self.timestamp = nil
        if let audioLevel = audioLevel(data.peer.id) {
            self.audioLevelDisposable.set(audioLevel.start(next: { [weak self] value in
                self?.updateAudioLevel(value, data: data, animated: animated)
            }))
        } else {
            self.audioLevelDisposable.set(nil)
            self.updateAudioLevel(nil, data: data, animated: animated)
        }

        playbackAudioLevelView.setColor(activityColor)
        photoView.setPeer(account: account, peer: data.peer, message: nil, size: NSMakeSize(floor(photoSize.width * 1.5), floor(photoSize.height * 1.5)))
    }
    
    private var value: Float? = nil
    
    private var timestamp: TimeInterval?
    
    private func updateAudioLevel(_ value: Float?, data: PeerGroupCallData, animated: Bool) {
        if let timestamp = self.timestamp {
            if CACurrentMediaTime() - timestamp < 0.100 {
                return
            }
        }
        self.timestamp = CACurrentMediaTime()
        
        if (value != nil || data.isSpeaking)  {
            playbackAudioLevelView.startAnimating()
        } else {
            playbackAudioLevelView.stopAnimating()
        }
        playbackAudioLevelView.change(opacity: (value != nil || data.isSpeaking) ? 1 : 0, animated: animated)
        
        
        if value != self.value {
            let value = value != nil ? Float(truncate(double: Double(value ?? 0), places: 2)) : nil
            
            self.value = value

            playbackAudioLevelView.updateLevel(CGFloat(value ?? 0))
            
            let audioLevel = value ?? 0
            let level = min(1.0, max(0.0, CGFloat(audioLevel)))
            let avatarScale: CGFloat
            if audioLevel > 0.0 {
                avatarScale = 0.9 + level * 0.07
            } else {
                avatarScale = 1.0
            }

            
            let valueScale = CGFloat(truncate(double: Double(avatarScale), places: 2))
                        
            let t = photoView.layer!.transform
            let scale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))

            if animated {
                self.scaleAnimator = DisplayLinkAnimator(duration: 0.1, from: scale, to: valueScale, update: { [weak self] value in
                    guard let `self` = self else {
                        return
                    }
                    let rect = self.photoView.bounds
                    var fr = CATransform3DIdentity
                    fr = CATransform3DTranslate(fr, rect.width / 2, rect.height / 2, 0)
                    fr = CATransform3DScale(fr, value, value, 1)
                    fr = CATransform3DTranslate(fr, -(rect.width / 2), -(rect.height / 2), 0)
                    self.photoView.layer?.transform = fr
                }, completion: {

                })
            } else {
                self.scaleAnimator = nil
                self.photoView.layer?.transform = CATransform3DIdentity
            }
        }
        
        
    }

    
    override func layout() {
        super.layout()
        photoView.center()
        playbackAudioLevelView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
