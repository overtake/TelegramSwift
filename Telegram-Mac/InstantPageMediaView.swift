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
    private let context: AccountContext
    let media: InstantPageMedia
    private let arguments: InstantPageMediaArguments
    private var iconView:ImageView?

    private let imageView: TransformImageView
    private let progressView = RadialProgressView(theme:RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: playerPlayThumb))
    private var currentSize: CGSize?
    
    private let fetchedDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private let playerDisposable = MetaDisposable()
    private let videoDataDisposable = MetaDisposable()
    private var videoData:AVGifData? {
        didSet {
            updatePlayerIfNeeded()
        }
    }
    
    @objc private func updatePlayerIfNeeded() {
        
        var s:Signal<Void, NoError> = .single(Void())
        s = s |> delay(0.01, queue: Queue.mainQueue())
        playerDisposable.set(s.start(next: { [weak self] in
            if let strongSelf = self {
                 let accept = strongSelf.window != nil && strongSelf.window!.isKeyWindow
                (strongSelf.imageView as? GIFPlayerView)?.set(data: accept ? strongSelf.videoData : nil)
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
    
    init(context: AccountContext, media: InstantPageMedia, arguments: InstantPageMediaArguments) {
        self.context = context
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
        case .map:
            self.imageView = TransformImageView()
        }
        
        
        super.init()
        
        progressView.isHidden = true
        
        self.imageView.animatesAlphaOnFirstTransition = true
        self.addSubview(self.imageView)
        addSubview(progressView)
        

        
        let updateProgressState:(MediaResourceStatus)->Void = { [weak self] status in
            guard let `self` = self else {return}
            
            self.progressView.fetchControls = FetchControls(fetch: { [weak self] in
                guard let `self` = self else {return}

                switch status {
                case .Remote:
                    if let image = media.media as? TelegramMediaImage {
                        self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: context.account, imageReference: ImageMediaReference.webPage(webPage: WebpageReference(media.webpage), media: image)).start())
                    } else if let file = media.media as? TelegramMediaFile {
                        self.fetchedDisposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.webPage(webPage: WebpageReference(media.webpage), media: file)).start())
                    }
                case .Fetching:
                    if let image = media.media as? TelegramMediaImage {
                        chatMessagePhotoCancelInteractiveFetch(account: context.account, photo: image)
                    } else if let file = media.media as? TelegramMediaFile {
                        cancelFreeMediaFileInteractiveFetch(context: context, resource: file.resource)
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
            
            self.imageView.setSignal( chatMessagePhoto(account: context.account, imageReference: ImageMediaReference.webPage(webPage: WebpageReference(media.webpage), media: image), scale: backingScaleFactor))
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: context.account, imageReference: ImageMediaReference.webPage(webPage: WebpageReference(media.webpage), media: image)).start())
            if let largest = largestImageRepresentation(image.representations) {
                if arguments.isInteractive {
                    statusDisposable.set((context.account.postbox.mediaBox.resourceStatus(largest.resource) |> deliverOnMainQueue).start(next: updateProgressState))
                }
            }
            
        } else if let file = media.media as? TelegramMediaFile {
            if arguments.isInteractive {
                statusDisposable.set((context.account.postbox.mediaBox.resourceStatus(file.resource) |> deliverOnMainQueue).start(next: updateProgressState))
            }
            self.fetchedDisposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.webPage(webPage: WebpageReference(media.webpage), media: file)).start())
            
            if file.mimeType.hasPrefix("image/") && !file.mimeType.hasSuffix("gif") {
                self.imageView.setSignal(instantPageImageFile(account: context.account, fileReference: .webPage(webPage: WebpageReference(media.webpage), media: file), scale: backingScaleFactor, fetched: true))
            } else {
                self.imageView.setSignal(chatMessageVideo(postbox: context.account.postbox, fileReference: .webPage(webPage: WebpageReference(media.webpage), media: file), scale: backingScaleFactor))
            }

            switch arguments {
            case let .video(_, autoplay):
                if autoplay {
                    videoDataDisposable.set((context.account.postbox.mediaBox.resourceData(file.resource) |> deliverOnResourceQueue |> map { data in return data.complete ?  AVGifData.dataFrom(data.path) : nil} |> deliverOnMainQueue).start(next: { [weak self] data in
                        self?.videoData = data
                    }))
                }
            default:
                break
            }
        } else if let map = media.media as? TelegramMediaMap {
            
            let iconView = ImageView()
            iconView.image = theme.icons.chatMapPin
            iconView.sizeToFit()
            addSubview(iconView)
            
            self.iconView = iconView
            
            var zoom: Int32 = 12
            var dimensions = CGSize(width: 200.0, height: 100.0)
            switch arguments {
            case let .map(attribute):
                zoom = attribute.zoom
                dimensions = attribute.dimensions
            default:
                break
            }

            let resource = MapSnapshotMediaResource(latitude: map.latitude, longitude: map.longitude, width: Int32(dimensions.width), height: Int32(dimensions.height), zoom: zoom)
            
            let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource)], immediateThumbnailData: nil, reference: nil, partialReference: nil)
            let imageReference = ImageMediaReference.webPage(webPage: WebpageReference(media.webpage), media: image)
            let signal = chatWebpageSnippetPhoto(account: context.account, imageReference: imageReference, scale: backingScaleFactor, small: false)
            self.imageView.setSignal(signal)
        } else if let webPage = media.media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content, let image = content.image {
            let imageReference = ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
            let signal = chatWebpageSnippetPhoto(account: context.account, imageReference: imageReference, scale: backingScaleFactor, small: false)
            self.imageView.setSignal(signal)
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: context.account, imageReference: imageReference).start())
            statusDisposable.set((context.account.postbox.mediaBox.resourceStatus(image.representations.last!.resource) |> deliverOnMainQueue).start(next: updateProgressState))
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
        
        iconView?.center()
        
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
            } else if let _ = self.media.media as? TelegramMediaMap {
                var imageSize = size

                var boundingSize = size
                switch arguments {
                case let .map(attribute):
                    boundingSize = attribute.dimensions
                    imageSize = attribute.dimensions.aspectFilled(size)
                default:
                    break
                }

                
                imageView.set(arguments: TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets()))
            } else if let webPage = media.media as? TelegramMediaWebpage, case let .Loaded(content) = webPage.content, let image = content.image, let largest = largestImageRepresentation(image.representations) {
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
            }

        }
        progressView.center()
    }
}
