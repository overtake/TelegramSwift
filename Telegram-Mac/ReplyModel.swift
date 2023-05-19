//
//  ReplyModel.swift
//  Telegram-Mac
//
//  Created by keepcoder on 21/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox
class ReplyModel: ChatAccessoryModel {

    private(set) var replyMessage:Message?
    private var disposable:MetaDisposable = MetaDisposable()
    private let isPinned:Bool
    private var previousMedia: Media?
    private var isLoading: Bool = false
    private let fetchDisposable = MetaDisposable()
    private let makesizeCallback:(()->Void)?
    private let autodownload: Bool
    private let headerAsName: Bool
    private let customHeader: String?
    init(replyMessageId:MessageId, context: AccountContext, replyMessage:Message? = nil, isPinned: Bool = false, autodownload: Bool = false, presentation: ChatAccessoryPresentation? = nil, headerAsName: Bool = false, customHeader: String? = nil, drawLine: Bool = true, makesizeCallback: (()->Void)? = nil, dismissReply: (()->Void)? = nil) {
        self.isPinned = isPinned
        self.makesizeCallback = makesizeCallback
        self.autodownload = autodownload
        self.replyMessage = replyMessage
        self.headerAsName = headerAsName
        self.customHeader = customHeader
        super.init(context: context, presentation: presentation, drawLine: drawLine)
        
      
        let messageViewSignal: Signal<Message?, NoError> = context.account.postbox.messageView(replyMessageId)
        |> map {
            $0.message
        } |> deliverOnMainQueue
        
        if let replyMessage = replyMessage {
            make(with :replyMessage, display: false)
            self.nodeReady.set(.single(true))
        } else {
            make(with: nil, display: false)
        }
        if replyMessage == nil {
            nodeReady.set(messageViewSignal |> map { [weak self] message -> Bool in
                self?.make(with: message, isLoading: false, display: true)
                if message == nil {
                    dismissReply?()
                }
                return message != nil
             })
        }
       
    }
    
    override weak var view:ChatAccessoryView? {
        didSet {
            updateImageIfNeeded()
        }
    }
    
    override var frame: NSRect {
        didSet {
            updateImageIfNeeded()
        }
    }
    
    override var leftInset: CGFloat {
        var imageDimensions: CGSize?
        if let message = replyMessage {
            if !message.containsSecretMedia {
                for media in message.media {
                    if let image = media as? TelegramMediaImage {
                        if let representation = largestRepresentationForPhoto(image) {
                            imageDimensions = representation.dimensions.size
                        }
                        break
                    } else if let file = media as? TelegramMediaFile, (file.isVideo || file.isSticker) && !file.isVideoSticker {
                        if let dimensions = file.dimensions {
                            imageDimensions = dimensions.size
                        } else if let representation = largestImageRepresentation(file.previewRepresentations), !file.isStaticSticker {
                            imageDimensions = representation.dimensions.size
                        } else if file.isAnimatedSticker {
                            imageDimensions = NSMakeSize(30, 30)
                        }
                        break
                    }
                }
            }

            
            if let _ = imageDimensions {
                return 30 + super.leftInset * 2
            }
        }
        
        return super.leftInset
    }
    
    deinit {
        disposable.dispose()
        fetchDisposable.dispose()
    }
    
    func update() {
        self.make(with: replyMessage, isLoading: isLoading, display: true)
    }
    
    private func updateImageIfNeeded() {
        if let message = self.replyMessage, let view = self.view {
            var updatedMedia: Media?
            var imageDimensions: CGSize?
            var hasRoundImage = false
            if !message.containsSecretMedia {
                for media in message.media {
                    if let image = media as? TelegramMediaImage {
                        updatedMedia = image
                        if let representation = largestRepresentationForPhoto(image) {
                            imageDimensions = representation.dimensions.size
                        }
                        break
                    } else if let file = media as? TelegramMediaFile, (file.isVideo || file.isSticker) && !file.isVideoSticker {
                        updatedMedia = file
                        
                        if let dimensions = file.dimensions?.size {
                            imageDimensions = dimensions
                        } else if let representation = largestImageRepresentation(file.previewRepresentations) {
                            imageDimensions = representation.dimensions.size
                        } else if file.isAnimatedSticker {
                            imageDimensions = NSMakeSize(30, 30)
                        }
                        if file.isInstantVideo {
                            hasRoundImage = true
                        }
                        break
                    }
                }
            }
            
            
            if let imageDimensions = imageDimensions {
                let boundingSize = CGSize(width: 30.0, height: 30.0)
                let arguments = TransformImageArguments(corners: ImageCorners(radius: 2.0), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: NSEdgeInsets())
                
                if view.imageView == nil {
                    view.imageView = TransformImageView()
                }
                view.imageView?.setFrameSize(boundingSize)
                if view.imageView?.superview == nil {
                    view.addSubview(view.imageView!)
                }
                
                view.imageView?.setFrameOrigin(super.leftInset + (self.isSideAccessory ? 10 : 0), floorToScreenPixels(System.backingScale, self.topOffset + (max(34, self.size.height) - self.topOffset - boundingSize.height)/2))
                
                
                let mediaUpdated = true
                
                
                var updateImageSignal: Signal<ImageDataTransformation, NoError>?
                if mediaUpdated {
                    if let image = updatedMedia as? TelegramMediaImage {
                        updateImageSignal = chatMessagePhotoThumbnail(account: self.context.account, imageReference: ImageMediaReference.message(message: MessageReference(message), media: image), scale: view.backingScaleFactor, synchronousLoad: true)
                    } else if let file = updatedMedia as? TelegramMediaFile {
                        if file.isVideo {
                            updateImageSignal = chatMessageVideoThumbnail(account: self.context.account, fileReference: FileMediaReference.message(message: MessageReference(message), media: file), scale: view.backingScaleFactor, synchronousLoad: false)
                        } else if file.isAnimatedSticker {
                            updateImageSignal = chatMessageAnimatedSticker(postbox: self.context.account.postbox, file: FileMediaReference.message(message: MessageReference(message), media: file), small: true, scale: view.backingScaleFactor, size: imageDimensions.aspectFitted(boundingSize), fetched: true, isVideo: file.isVideoSticker)
                        } else if file.isSticker {
                            updateImageSignal = chatMessageSticker(postbox: self.context.account.postbox, file: FileMediaReference.message(message: MessageReference(message), media: file), small: true, scale: view.backingScaleFactor, fetched: true)
                        } else if let iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations) {
                            let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                            updateImageSignal = chatWebpageSnippetPhoto(account: self.context.account, imageReference: ImageMediaReference.message(message: MessageReference(message), media: tmpImage), scale: view.backingScaleFactor, small: true, synchronousLoad: true)
                        }
                    }
                }
                
                
                if let updateImageSignal = updateImageSignal, let media = updatedMedia {
                    
                    view.imageView?.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: System.backingScale), clearInstantly: false)

                    
                    view.imageView?.setSignal(updateImageSignal, animate: true, synchronousLoad: true, cacheImage: { [weak media] result in
                        if let media = media {
                            cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
                        }
                    })
                    
                    if let media = media as? TelegramMediaImage {
                        self.fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: self.context.account, imageReference: ImageMediaReference.message(message: MessageReference(message), media: media)).start())
                    }
                    
                    view.imageView?.set(arguments: arguments)
                    if hasRoundImage {
                        view.imageView!.layer?.cornerRadius = 15
                    } else {
                        view.imageView?.layer?.cornerRadius = 0
                    }
                }
            } else {
                view.imageView?.removeFromSuperview()
                view.imageView = nil
            }
            
            self.previousMedia = updatedMedia
        } else {
            self.view?.imageView?.removeFromSuperview()
            self.view?.imageView = nil
        }
        self.view?.updateModel(self, animated: false)
    }
    
    func make(with message:Message?, isLoading: Bool = true, display: Bool) -> Void {
        self.replyMessage = message
        self.isLoading = isLoading
        
        var display: Bool = display
        updateImageIfNeeded()

        if let message = message {
            
            var title: String? = message.effectiveAuthor?.displayTitle
            if let info = message.forwardInfo {
                title = info.authorTitle
            }
            for attr in message.attributes {
                if let _ = attr as? SourceReferenceMessageAttribute {
                    if let info = message.forwardInfo {
                        title = info.authorTitle
                    }
                    break
                }
            }
            
            
            let text = chatListText(account: context.account, for: message, isPremium: context.isPremium, isReplied: true)
            if let header = customHeader {
                self.header = .init(.initialize(string: header, color: presentation.title, font: .medium(.text)), maximumNumberOfLines: 1)
            } else {
                self.header = .init(.initialize(string: !isPinned || headerAsName ? title : strings().chatHeaderPinnedMessage, color: presentation.title, font: .medium(.text)), maximumNumberOfLines: 1)
            }
            let attr = NSMutableAttributedString()
            attr.append(text)
            attr.addAttribute(.foregroundColor, value: message.media.isEmpty || message.effectiveMedia is TelegramMediaWebpage ? presentation.enabledText : presentation.disabledText, range: attr.range)
            attr.addAttribute(.font, value: NSFont.normal(.text), range: attr.range)
            
            attr.fixUndefinedEmojies()
            self.message = .init(attr, maximumNumberOfLines: 1)
        } else {
            self.header = nil
            self.message = .init(.initialize(string: isLoading ? strings().messagesReplyLoadingLoading : strings().messagesDeletedMessage, color: presentation.disabledText, font: .normal(.text)), maximumNumberOfLines: 1)
            display = true
        }
        
        if !isLoading {
            measureSize(width, sizeToFit: sizeToFit)
            display = true
        }
        if display {
            self.view?.setFrameSize(self.size)
            self.setNeedDisplay()
        }
    }

    
}
