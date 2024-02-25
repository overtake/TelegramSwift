//
//  PremiumDemoLegacyPhoneView.swift
//  Telegram
//
//  Created by Mike Renoir on 14.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import AppKit
import SwiftSignalKit
import TelegramMedia

final class PremiumDemoLegacyPhoneView : View {
    private let phoneView = ImageView()
    private let videoView = MediaPlayerView()
    private var player: MediaPlayer?
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        phoneView.image = NSImage(named: "Icon_Premium_Iphone")?.precomposed()
        addSubview(videoView)
        videoView.cornerRadius = 0
        addSubview(phoneView)
        phoneView.sizeToFit()
    }
    
    enum Position {
        case top
        case bottom
    }
    
    private var position: Position = .top
    
    var status: Signal<MediaPlayerStatus, NoError>?
    
    func setup(context: AccountContext, video: TelegramMediaFile?, position: Position) {
        self.position = position
        if let video = video {
                                    
            let mediaPlayer = MediaPlayer(postbox: context.account.postbox, userLocation: .other, userContentType: .video, reference: .standalone(resource: video.resource), streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: true)
            mediaPlayer.attachPlayerView(self.videoView)
            self.player = mediaPlayer
            
            mediaPlayer.play()
            mediaPlayer.actionAtEnd = .loop(nil)
            
            self.status = mediaPlayer.status
        }
        needsLayout = true
        
    }
    
    
    
    override func layout() {
        super.layout()
        
        
        let vsize = NSMakeSize(1170, 1754)
        let videoSize = vsize.aspectFitted(NSMakeSize(phoneView.frame.width - 22, phoneView.frame.height - 22))

        
        switch position {
        case .top:
            self.phoneView.centerX(y: 20)
            self.videoView.frame = NSMakeRect(phoneView.frame.minX + 11, phoneView.frame.minY + 11, videoSize.width, videoSize.height)
            self.videoView.positionFlags = [.top, .left, .right]
        case .bottom:
            self.phoneView.centerX(y: frame.height - phoneView.frame.height - 20)
            self.videoView.frame = NSMakeRect(phoneView.frame.minX + 11, phoneView.frame.maxY - videoSize.height - 11, videoSize.width, videoSize.height)
            self.videoView.positionFlags = [.bottom, .left, .right]
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
