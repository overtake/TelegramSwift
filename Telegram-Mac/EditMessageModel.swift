//
//  EditMessageModel.swift
//  Telegram-Mac
//
//  Created by keepcoder on 02/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
class EditMessageModel: ChatAccessoryModel {
    
    private var account:Account
    private(set) var state:ChatEditState
    private let fetchDisposable = MetaDisposable()
    private var previousMedia: Media?
    init(state:ChatEditState, account:Account) {
        self.account = account
        self.state = state
        super.init()
        make(with: state.message)
    }
    
    override var view: ChatAccessoryView? {
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
        let message = state.message
        if !message.containsSecretMedia {
            for media in message.media {
                if let image = media as? TelegramMediaImage {
                    if let representation = largestRepresentationForPhoto(image) {
                        imageDimensions = representation.dimensions
                    }
                    break
                } else if let file = media as? TelegramMediaFile, file.isVideo {
                    if let dimensions = file.dimensions {
                        imageDimensions = dimensions
                    } else if let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                        imageDimensions = representation.dimensions
                    }
                    break
                }
            }
        }
        
        
        if let _ = imageDimensions {
            return 30 + super.leftInset * 2
        }
        
        return super.leftInset
    }
    

    
    func make(with message:Message) -> Void {
        let attr = NSMutableAttributedString()
        _ = attr.append(string: L10n.chatInputAccessoryEditMessage, color: theme.colors.blueUI, font: .medium(.text))
        if message.media.first is TelegramMediaFile || message.media.first is TelegramMediaImage {
            _ = attr.append(string: " (\(L10n.chatEditMessageMedia))", color: theme.colors.grayText, font: .normal(.text))
        }
        self.headerAttr = attr
        self.messageAttr = .initialize(string: pullText(from:message) as String, color: message.media.isEmpty ? theme.colors.text : theme.colors.grayText, font: .normal(.text))
        nodeReady.set(.single(true))
        updateImageIfNeeded()
        self.setNeedDisplay()
    }
    private func updateImageIfNeeded() {
        Queue.mainQueue().async {
            if let view = self.view, view.frame != NSZeroRect {
                let message = self.state.message
                var updatedMedia: Media?
                var imageDimensions: CGSize?
                var hasRoundImage = false
                if !message.containsSecretMedia {
                    for media in message.media {
                        if let image = media as? TelegramMediaImage {
                            updatedMedia = image
                            if let representation = largestRepresentationForPhoto(image) {
                                imageDimensions = representation.dimensions
                            }
                            break
                        } else if let file = media as? TelegramMediaFile, file.isVideo {
                            updatedMedia = file
                            
                            if let dimensions = file.dimensions {
                                imageDimensions = dimensions
                            } else if let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                                imageDimensions = representation.dimensions
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
                    view.addSubview(view.imageView!)
                    
                    view.imageView?.setFrameOrigin(super.leftInset + (self.isSideAccessory ? 10 : 0), floorToScreenPixels(scaleFactor: System.backingScale, self.topOffset + (self.size.height - self.topOffset - boundingSize.height)/2))
                    
                    
                    let mediaUpdated = true
                    
                    
                    var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                    if mediaUpdated {
                        if let image = updatedMedia as? TelegramMediaImage {
                            updateImageSignal = chatMessagePhotoThumbnail(account: self.account, photo: image, scale: view.backingScaleFactor)
                        } else if let file = updatedMedia as? TelegramMediaFile {
                            if file.isVideo {
                                updateImageSignal = chatMessageVideoThumbnail(account: self.account, file: file, scale: view.backingScaleFactor)
                            } else if let iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations) {
                                let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], reference: nil)
                                updateImageSignal = chatWebpageSnippetPhoto(account: self.account, photo: tmpImage, scale: view.backingScaleFactor, small: true)
                            }
                        }
                    }
                    
                    if let updateImageSignal = updateImageSignal, let media = updatedMedia {
                        view.imageView?.setSignal(signal: cachedMedia(media: media, size: arguments.imageSize, scale: view.backingScaleFactor))
                        view.imageView?.setSignal(updateImageSignal, animate: true, cacheImage: { image in
                            return cacheMedia(signal: image, media: media, size: arguments.imageSize, scale: System.backingScale)
                        })
                        if let media = media as? TelegramMediaImage {
                            self.fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: self.account, photo: media).start())
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
        }
    }
    
    
    deinit {
        fetchDisposable.dispose()
    }
}
