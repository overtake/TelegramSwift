//
//  InstantPageMediaView.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

final class InstantPageMediaView: View, InstantPageView {
    private let account: Account
    let media: InstantPageMedia
    private let arguments: InstantPageMediaArguments
    
    private let imageView: TransformImageView
    private let progressView = RadialProgressView(theme:RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: playerPlayThumb))
    private var currentSize: CGSize?
    
    private let fetchedDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private let playerDisposable = MetaDisposable()
    private let videoDataDisposable = MetaDisposable()
    private var videoPath:String? {
        didSet {
            updatePlayerIfNeeded()
        }
    }
    
    @objc private func updatePlayerIfNeeded() {
        
        var s:Signal<Void, Void> = .single(Void())
        s = s |> delay(0.01, queue: Queue.mainQueue())
        playerDisposable.set(s.start(next: { [weak self] in
            if let strongSelf = self {
                 let accept = strongSelf.window != nil && strongSelf.window!.isKeyWindow
                (strongSelf.imageView as? GIFPlayerView)?.set(path: accept ? strongSelf.videoPath : nil)
            }
        }))
    }
    
    private func updatePlayerListenters() {
        removeNotificationListeners()
        if let window = window {
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
        }
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidMoveToWindow() {
        updatePlayerListenters()
    }
    
    init(account: Account, media: InstantPageMedia, arguments: InstantPageMediaArguments) {
        self.account = account
        self.media = media
        self.arguments = arguments
        
        switch arguments {
        case .image:
             self.imageView = TransformImageView()
        case let .video(_, autoplay):
            if autoplay {
                self.imageView = GIFPlayerView()
            } else {
                self.imageView = TransformImageView()
            }
        }
        
        
        super.init()
        
        progressView.isHidden = true
        
        self.imageView.alphaTransitionOnFirstUpdate = true
        self.addSubview(self.imageView)
        addSubview(progressView)
        

        
        let updateProgressState:(MediaResourceStatus)->Void = { [weak self] status in
            guard let `self` = self else {return}
            
            self.progressView.fetchControls = FetchControls(fetch: { [weak self] in
                guard let `self` = self else {return}

                switch status {
                case .Remote:
                    if let image = media.media as? TelegramMediaImage {
                        self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photo: image).start())
                    } else if let file = media.media as? TelegramMediaFile {
                        self.fetchedDisposable.set(freeMediaFileInteractiveFetched(account: account, file: file).start())
                    }
                case .Fetching:
                    if let image = media.media as? TelegramMediaImage {
                        chatMessagePhotoCancelInteractiveFetch(account: account, photo: image)
                    } else if let file = media.media as? TelegramMediaFile {
                        cancelFreeMediaFileInteractiveFetch(account: account, file: file)
                    }
                default:
                    break
                }
            })
            
            switch status {
            case let .Fetching(_, progress):
                self.progressView.isHidden = false
                self.progressView.state = .Fetching(progress: progress, force: false)
            case .Local:
                self.progressView.isHidden = media.media is TelegramMediaImage || self.imageView is GIFPlayerView
                self.progressView.state = media.media is TelegramMediaImage || self.imageView is GIFPlayerView ? .None : .Play
            case .Remote:
                self.progressView.state = .Remote
            }
        }
        
        if let image = media.media as? TelegramMediaImage {
            
            self.imageView.setSignal( chatMessagePhoto(account: account, photo: image, scale: backingScaleFactor))

           
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photo: image).start())
            if let largest = largestImageRepresentation(image.representations) {
                statusDisposable.set((account.postbox.mediaBox.resourceStatus(largest.resource) |> deliverOnMainQueue).start(next: updateProgressState))
            }
            
        } else if let file = media.media as? TelegramMediaFile {
            statusDisposable.set((account.postbox.mediaBox.resourceStatus(file.resource) |> deliverOnMainQueue).start(next: updateProgressState))
            self.fetchedDisposable.set(freeMediaFileInteractiveFetched(account: account, file: file).start())
            
            self.imageView.setSignal( chatMessageVideoThumbnail(account: account, file: file, scale: backingScaleFactor))

            switch arguments {
            case let .video(_, autoplay):
                if autoplay {
                    videoDataDisposable.set((account.postbox.mediaBox.resourceData(file.resource) |> deliverOnMainQueue).start(next: { [weak self] data in
                        if data.complete {
                            self?.videoPath = data.path
                        } else {
                            self?.videoPath = nil
                        }
                    }))
                }
            default:
                break
            }
        }
        
    }
    
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        removeNotificationListeners()
        self.fetchedDisposable.dispose()
        self.playerDisposable.dispose()
        videoDataDisposable.dispose()
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    override func copy() -> Any {
        return imageView.copy()
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        if self.currentSize != size {
            self.currentSize = size
            
            self.imageView.frame = CGRect(origin: CGPoint(), size: size)
            
            if let image = self.media.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                var imageSize = largest.dimensions.aspectFilled(size)
                var boundingSize = size
                var radius: CGFloat = 0.0
                
                switch arguments {
                case let .image(_, roundCorners, fit):
                    radius = roundCorners ? floor(min(size.width, size.height) / 2.0) : 0.0
                    
                    if fit {
                        imageSize = largest.dimensions.fitted(size)
                        boundingSize = imageSize;
                    }
                default:
                    break
                }
                
           
                imageView.set(arguments: TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets()))

            } else if let file = self.media.media as? TelegramMediaFile {
                let imageSize = file.dimensions?.aspectFilled(size) ?? size
                let boundingSize = size
                
                imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets()))
            }
        }
        progressView.center()
    }
}
