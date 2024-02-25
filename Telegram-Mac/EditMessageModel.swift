//
//  EditMessageModel.swift
//  Telegram-Mac
//
//  Created by keepcoder on 02/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox
class EditMessageModel: ChatAccessoryModel {
    
    private(set) var state:ChatEditState
    private let fetchDisposable = MetaDisposable()
    private var previousMedia: Media?
    init(state:ChatEditState, context: AccountContext) {
        self.state = state
        super.init(context: context)
        make(with: state.message)
    }
    
    override var modelType: ChatAccessoryModel.ModelType {
        return .classic
    }
    
    override var view: ChatAccessoryView? {
        didSet {
            updateImageIfNeeded()
        }
    }
    
    override var size:NSSize {
        didSet {
            updateImageIfNeeded()
        }
    }
    
    override var frame: NSRect {
        didSet {
            updateImageIfNeeded()
        }
    }
    
    override var mediaInset: CGFloat {
        return updatedMedia != nil ? 30 + 6 : 0
    }
    
    override var updatedMedia: Media? {
        var updatedMedia: Media?
        if !self.state.message.containsSecretMedia {
            for media in self.state.message.media {
                if let image = media as? TelegramMediaImage {
                    updatedMedia = image
                    break
                } else if let file = media as? TelegramMediaFile, file.isVideo {
                    updatedMedia = file
                    break
                }
            }
        }
        return updatedMedia
    }
    

    
    func make(with message:Message) -> Void {
        let attr = NSMutableAttributedString()
        _ = attr.append(string: strings().chatInputAccessoryEditMessage, color: theme.colors.accent, font: .medium(.text))

        self.header = .init(attr, maximumNumberOfLines: 1)
        
        let messageAttr = NSMutableAttributedString()
        let text = chatListText(account: context.account, for: message, isPremium: context.isPremium, isReplied: true)
        
        messageAttr.append(text)
//        messageAttr.addAttribute(.foregroundColor, value: message.media.isEmpty ? theme.colors.text : theme.colors.grayText, range: messageAttr.range)
        messageAttr.addAttribute(.font, value: NSFont.normal(.text), range: messageAttr.range)
        
        self.message = .init(messageAttr, maximumNumberOfLines: 1, cutout: self.cutout)
        nodeReady.set(.single(true))
        updateImageIfNeeded()
        self.setNeedDisplay()
    }
    private func updateImageIfNeeded() {
        if let view = self.view, let updatedMedia = self.updatedMedia {
            let account = context.account
            let message = self.state.message
            var imageDimensions: CGSize?
            var hasRoundImage = false
            if let image = updatedMedia as? TelegramMediaImage {
                if let representation = largestRepresentationForPhoto(image) {
                    imageDimensions = representation.dimensions.size
                }
            } else if let file = updatedMedia as? TelegramMediaFile, file.isVideo {
                if let dimensions = file.dimensions {
                    imageDimensions = dimensions.size
                } else if let representation = largestImageRepresentation(file.previewRepresentations), !file.isStaticSticker {
                    imageDimensions = representation.dimensions.size
                }
                if file.isInstantVideo {
                    hasRoundImage = true
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
                view.imageView?.setFrameOrigin(super.leftInset, mediaTopInset)
                
                
                let mediaUpdated = true
                
                
                var updateImageSignal: Signal<ImageDataTransformation, NoError>?
                if mediaUpdated {
                    if let image = updatedMedia as? TelegramMediaImage {
                        updateImageSignal = chatMessagePhotoThumbnail(account: account, imageReference: ImageMediaReference.message(message: MessageReference(message), media: image), scale: view.backingScaleFactor)
                    } else if let file = updatedMedia as? TelegramMediaFile {
                        if file.isVideo {
                            updateImageSignal = chatMessageVideoThumbnail(account: account, fileReference: FileMediaReference.message(message: MessageReference(message), media: file), scale: view.backingScaleFactor)
                        } else if let iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations) {
                            let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                            updateImageSignal = chatWebpageSnippetPhoto(account: account, imageReference: ImageMediaReference.message(message: MessageReference(message), media: tmpImage), scale: view.backingScaleFactor, small: true)
                        }
                    }
                }
                
                if let updateImageSignal = updateImageSignal {
                    view.imageView?.setSignal(signal: cachedMedia(media: updatedMedia, arguments: arguments, scale: view.backingScaleFactor), clearInstantly: false)
                    if view.imageView?.isFullyLoaded == false {
                        view.imageView?.setSignal(updateImageSignal, animate: true, cacheImage: { [weak updatedMedia] result in
                            if let updatedMedia = updatedMedia {
                                cacheMedia(result, media: updatedMedia, arguments: arguments, scale: System.backingScale)
                            }
                        })
                        if let media = updatedMedia as? TelegramMediaImage, !media.isLocalResource {
                            self.fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: account, imageReference: ImageMediaReference.message(message: MessageReference(message), media: media)).start())
                        }
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
    
    
    deinit {
        fetchDisposable.dispose()
    }
}
