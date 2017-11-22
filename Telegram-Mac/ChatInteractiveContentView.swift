//
//  ChatMessagePhotoContent.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import TGUIKit


class ChatInteractiveContentView: ChatMediaContentView {

    private let image:TransformImageView = TransformImageView()
    private var videoAccessory: ChatMessageAccessoryView? = nil
    private var progressView:RadialProgressView?
    private var timableProgressView: TimableProgressView? = nil
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        self.addSubview(image)
    }
    
    
    override func open() {
        if let parent = parent, let account = account {
            let parameters = self.parameters as? ChatMediaGalleryParameters
            var type:GalleryAppearType = .history
            if let parameters = parameters, parameters.isWebpage {
                type = .alone
            } else if parent.containsSecretMedia {
                type = .secret
            }
            showChatGallery(account: account,message: parent, table, parameters, type: type)
        }
    }
    
    

    override func layout() {
        super.layout()
        progressView?.center()
        timableProgressView?.center()
        videoAccessory?.setFrameOrigin(5, 5)

        self.image.setFrameSize(frame.size)
    }
    
    private func updateVideoAccessory(_ status: MediaResourceStatus, file: TelegramMediaFile) {
        let maxWidth = frame.width - 20
        if maxWidth > 100 {
            switch status {
            case let .Fetching(_, progress):
                let current = String.prettySized(with: Int(Float(file.elapsedSize) * progress))
                let size = "\(current) / \(String.prettySized(with: file.elapsedSize))"
                videoAccessory?.updateText(size, maxWidth: maxWidth)
            case .Remote:
                videoAccessory?.updateText(String.durationTransformed(elapsed: file.videoDuration) + ", \(String.prettySized(with: file.elapsedSize))", maxWidth: maxWidth)
            case .Local:
                videoAccessory?.updateText(String.durationTransformed(elapsed: file.videoDuration), maxWidth: maxWidth)
            }
        } else {
            videoAccessory?.updateText(String.durationTransformed(elapsed: file.videoDuration), maxWidth: maxWidth)
        }
        
    }

    override func update(with media: Media, size:NSSize, account:Account, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool, positionFlags: GroupLayoutPositionFlags? = nil) {
        
        let mediaUpdated = self.media == nil || !self.media!.isEqual(media) || frame.size != size
        
        super.update(with: media, size: size, account: account, parent:parent, table:table, parameters:parameters, positionFlags: positionFlags)

        
        let topLeftRadius: CGFloat = .cornerRadius
        let bottomLeftRadius: CGFloat = .cornerRadius
        let topRightRadius: CGFloat = .cornerRadius
        let bottomRightRadius: CGFloat = .cornerRadius
        
//        if let positionFlags = positionFlags {
//            if positionFlags.contains(.top) && positionFlags.contains(.left) {
//                topLeftRadius = topLeftRadius * 2
//            }
//            if positionFlags.contains(.top) && positionFlags.contains(.right) {
//                topRightRadius = topRightRadius * 2
//            }
//            if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
//                bottomLeftRadius = topLeftRadius * 2
//            }
//            if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
//                bottomRightRadius = topRightRadius * 2
//            }
//        }
        
//        if (position & TGAttachmentPositionBottom && position & TGAttachmentPositionLeft)
//        bottomLeftRadius = bigRadius;
//        if (position & TGAttachmentPositionBottom && position & TGAttachmentPositionRight)
//        bottomRightRadius = bigRadius;
        

        var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
        
        if mediaUpdated {
            
            var dimensions: NSSize = size
            
            if let image = media as? TelegramMediaImage {
                videoAccessory?.removeFromSuperview()
                videoAccessory = nil
                dimensions = image.representationForDisplayAtSize(size)?.dimensions ?? size
                
                if let parent = parent, parent.containsSecretMedia {
                    updateImageSignal = chatSecretPhoto(account: account, photo: image, scale: backingScaleFactor)
                } else {
                    updateImageSignal = chatMessagePhoto(account: account, photo: image, scale: backingScaleFactor)
                }
                
                if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                    updatedStatusSignal = combineLatest(chatMessagePhotoStatus(account: account, photo: image), account.pendingMessageManager.pendingMessageStatus(parent.id))
                        |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                            if let pendingStatus = pendingStatus {
                                return .Fetching(isActive: true, progress: pendingStatus.progress)
                            } else {
                                return resourceStatus
                            }
                    } |> deliverOnMainQueue
                } else {
                    updatedStatusSignal = chatMessagePhotoStatus(account: account, photo: image) |> deliverOnMainQueue
                }
            
            } else if let file = media as? TelegramMediaFile {
                
                if file.isVideo, size.height > 80 {
                    if videoAccessory == nil {
                        videoAccessory = ChatMessageAccessoryView(frame: NSZeroRect)
                        addSubview(videoAccessory!)
                    }
                    videoAccessory?.updateText(String.durationTransformed(elapsed: file.videoDuration) + ", \(String.prettySized(with: file.elapsedSize))", maxWidth: size.width - 20)
                } else {
                    videoAccessory?.removeFromSuperview()
                    videoAccessory = nil
                }
                
                if let parent = parent, parent.containsSecretMedia {
                    updateImageSignal = chatSecretMessageVideo(account: account, video: file, scale: backingScaleFactor)
                } else {
                    updateImageSignal = chatMessageVideo(account: account, video: file, scale: backingScaleFactor)
                }
                
                dimensions = file.dimensions ?? size
                
                if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                    updatedStatusSignal = combineLatest(chatMessageFileStatus(account: account, file: file), account.pendingMessageManager.pendingMessageStatus(parent.id))
                        |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                            if let pendingStatus = pendingStatus {
                                return .Fetching(isActive: true, progress: pendingStatus.progress)
                            } else {
                                return resourceStatus
                            }
                        } |> deliverOnMainQueue
                } else {
                    updatedStatusSignal = chatMessageFileStatus(account: account, file: file) |> deliverOnMainQueue
                }
            }
            
            let arguments = TransformImageArguments(corners: ImageCorners(topLeft: .Corner(topLeftRadius), topRight: .Corner(topRightRadius), bottomLeft: .Corner(bottomLeftRadius), bottomRight: .Corner(bottomRightRadius)), imageSize: dimensions, boundingSize: size, intrinsicInsets: NSEdgeInsets())
            
             self.image.set(arguments: arguments)
            
            if !animated {
                self.image.setSignal(signal: cachedMedia(media: media, size: arguments.boundingSize, scale: backingScaleFactor))
            }
            
            if let updateImageSignal = updateImageSignal {
                self.image.setSignal( updateImageSignal, clearInstantly: false, animate: true, cacheImage: { [weak self] image in
                    if let strongSelf = self {
                        return cacheMedia(signal: image, media: media, size: arguments.boundingSize, scale: strongSelf.backingScaleFactor)
                    } else {
                        return .complete()
                    }
                })
            }
        }
        
        if let updateStatusSignal = updatedStatusSignal {
            self.statusDisposable.set(updateStatusSignal.start(next: { [weak self] (status) in
                
                if let strongSelf = self {
                    strongSelf.fetchStatus = status
                    if let file = media as? TelegramMediaFile {
                        strongSelf.updateVideoAccessory(status, file: file)
                    }
                    var containsSecretMedia:Bool = false
                    
                    if let message = parent {
                        containsSecretMedia = message.containsSecretMedia
                    }
                    
                    if let _ = parent?.autoremoveAttribute?.countdownBeginTime {
                        strongSelf.progressView?.removeFromSuperview()
                        strongSelf.progressView = nil
                        if strongSelf.timableProgressView == nil {
                            strongSelf.timableProgressView = TimableProgressView()
                            strongSelf.addSubview(strongSelf.timableProgressView!)
                        }
                    } else {
                        strongSelf.timableProgressView?.removeFromSuperview()
                        strongSelf.timableProgressView = nil
                        
                        if case .Local = status, media is TelegramMediaImage, !containsSecretMedia {
                            self?.image.animatesAlphaOnFirstTransition = false
                            
                            if let progressView = strongSelf.progressView {
                                progressView.state = .Fetching(progress:1.0, force: false)
                                progressView.removeFromSuperview()
                                strongSelf.progressView = nil
                            }
                        } else {
                            self?.image.animatesAlphaOnFirstTransition = true
                            strongSelf.progressView?.layer?.removeAllAnimations()
                            if strongSelf.progressView == nil {
                                let progressView = RadialProgressView(theme:RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: playerPlayThumb))
                                progressView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 40.0))
                                strongSelf.progressView = progressView
                                strongSelf.addSubview(progressView)
                                strongSelf.progressView?.center()
                                progressView.fetchControls = strongSelf.fetchControls
                            }
                        }
                    }
                    
                    
                    
                    
                    switch status {
                    case let .Fetching(_, progress):
                        strongSelf.progressView?.state = .Fetching(progress: progress, force: false)
                    case .Local:
                        var state: RadialProgressState = .None
                        if containsSecretMedia {
                            state = .Icon(image: theme.icons.chatSecretThumb, mode:.destinationOut)
                            
                            if let attribute = parent?.autoremoveAttribute, let countdownBeginTime = attribute.countdownBeginTime {
                                let difference:TimeInterval = TimeInterval((countdownBeginTime + attribute.timeout)) - (CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                let start = difference / Double(attribute.timeout) * 100.0
                                strongSelf.timableProgressView?.theme = TimableProgressTheme(outer: 3, seconds: difference, start: start, border: false)
                                strongSelf.timableProgressView?.progress = 0
                                strongSelf.timableProgressView?.startAnimation()
                                
                            }
                        } else {
                            if let file = media as? TelegramMediaFile {
                                if file.isVideo {
                                    state = .Play
                                }
                            }
                        }
                        
                        strongSelf.progressView?.state = state
                    case .Remote:
                        strongSelf.progressView?.state = .Remote
                    }
                    strongSelf.needsLayout = true
                }
                
            }))
           
            if media is TelegramMediaImage {
                fetch()
            }
        }
        
    }
    
    override func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        super._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
        
        image._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    
    override func setContent(size: NSSize) {
        super.setContent(size: size)
    }
    
    override func clean() {
        statusDisposable.dispose()
    }
    
    override func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    override func cancelFetching() {
        if let account = account {
            if let media = media as? TelegramMediaFile {
                chatMessageFileCancelInteractiveFetch(account: account, file: media)
            } else if let media = media as? TelegramMediaImage {
                chatMessagePhotoCancelInteractiveFetch(account: account, photo: media)
            }
        }
        
    }
    override func fetch() {
        if let account = account {
            if let media = media as? TelegramMediaFile {
                fetchDisposable.set(chatMessageFileInteractiveFetched(account: account, file: media).start())
            } else if let media = media as? TelegramMediaImage {
                fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photo: media).start())
            }
        }
    }
    
    
    override func copy() -> Any {
        return image.copy()
    }
    
    
}
