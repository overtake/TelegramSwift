//
//  ChatMusicContentView.swift
//  TelegramMac
//
//  Created by keepcoder on 25/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

class ChatMusicContentView: ChatAudioContentView {
    private let imageView: TransformImageView = TransformImageView(frame: NSMakeRect(0, 0, 40, 40))
    private var playAnimationView: PeerMediaPlayerAnimationView?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView, positioned: .below, relativeTo: progressView)
        progressView.theme = RadialProgressTheme(backgroundColor: theme.colors.blackTransparent, foregroundColor: .white, icon: nil)
    }
    
    override var fetchStatus: MediaResourceStatus? {
        didSet {
            if let fetchStatus = fetchStatus {
                switch fetchStatus {
                case let .Fetching(_, progress):
                    progressView.state = .Fetching(progress: progress, force: false)
                    progressView.isHidden = false
                case .Remote:
                    progressView.isHidden = true
                case .Local:
                    progressView.isHidden = true
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(with media: Media, size: NSSize, account: Account, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool, positionFlags: LayoutPositionFlags? = nil) {
        super.update(with: media, size: size, account: account, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags)
        
        if let parameters = parameters as? ChatMediaMusicLayoutParameters {
            textView.update(parameters.nameLayout)
            durationView.update(parameters.durationLayout)
        }
        
        let iconSize = CGSize(width: 40, height: 40)
        let imageCorners = ImageCorners(radius: 20)
        let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: NSEdgeInsets())
        
        let file = media as! TelegramMediaFile
        let resource = ExternalMusicAlbumArtResource(title: file.musicText.0, performer: file.musicText.1, isThumbnail: true)
        imageView.layer?.contents = theme.icons.chatMusicPlaceholder

        
        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: iconSize, resource: resource)], reference: nil, partialReference: nil)
        
        imageView.setSignal(signal: cachedMedia(media: media, size: arguments.imageSize, scale: backingScaleFactor, positionFlags: positionFlags), clearInstantly: false)
        
        imageView.setSignal( chatMessagePhotoThumbnail(account: account, imageReference: parent != nil ? ImageMediaReference.message(message: MessageReference(parent!), media: image) : ImageMediaReference.standalone(media: image)), animate: true, cacheImage: { [weak self] image in
            if let strongSelf = self {
                return cacheMedia(signal: image, media: media, size: arguments.imageSize, scale: strongSelf.backingScaleFactor, positionFlags: positionFlags)
            } else {
                return .complete()
            }
        })
        
        imageView.set(arguments: arguments)
        imageView.layer?.cornerRadius = 20
    }
    
    override func checkState() {
        if let parent = parent, let controller = globalAudio, let song = controller.currentSong {
            if song.entry.isEqual(to: parent) {
                if playAnimationView == nil {
                    playAnimationView = PeerMediaPlayerAnimationView()
    
                    imageView.addSubview(playAnimationView!)
                }
                if case .playing = song.state {
                    playAnimationView?.isPlaying = true
                } else if case .stoped = song.state {
                    playAnimationView?.removeFromSuperview()
                    playAnimationView = nil
                } else  {
                    playAnimationView?.isPlaying = false
                }
            } else {
                playAnimationView?.removeFromSuperview()
                playAnimationView = nil
            }
        } else {
            playAnimationView?.removeFromSuperview()
            playAnimationView = nil
        }
    }
    
    override func layout() {
        super.layout()
        let center = floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2.0)
        textView.setFrameOrigin(leftInset, center - textView.frame.height - 2)
        durationView.setFrameOrigin(leftInset, center + 2)
    }
    
}
