//
//  ChatInputAttachView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac


class ChatInputAttachView: ImageButton, Notifable {
        
    private var chatInteraction:ChatInteraction
    private var controller:SPopoverViewController?
    private let updateMediaDisposable = MetaDisposable()
    private let editMediaAccessory: ImageView = ImageView()
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(frame: frameRect)
        
        
        highlightHovered = true
        
        
        updateLayout()
        
        set(handler: { (event) in
            
        }, for: .Click)
        
        let attachFile = { [weak self] in
            if let strongSelf = self, let window = strongSelf.kitWindow {
                filePanel(for: window, completion:{ result in
                    if let result = result {
                        
                        let previous = result.count
                        
                        let result = result.filter { path -> Bool in
                            if let size = fs(path) {
                                return size <= 1500 * 1024 * 1024
                            }
                            return false
                        }
                        
                        let afterSizeCheck = result.count
                        
                        if afterSizeCheck == 0 && previous != afterSizeCheck {
                            alert(for: mainWindow, info: tr(L10n.appMaxFileSize))
                        } else {
                            strongSelf.chatInteraction.showPreviewSender(result.map{URL(fileURLWithPath: $0)}, false)
                        }
                        
                    }
                })
            }
        }
        
        let attachPhotoOrVideo = { [weak self] in
            if let strongSelf = self, let window = strongSelf.kitWindow {
                filePanel(with:mediaExts, for: window, completion:{(result) in
                    if let result = result {
                        let previous = result.count
                        
                        let result = result.filter { path -> Bool in
                            if let size = fs(path) {
                                return size <= 1500 * 1024 * 1024
                            }
                            return false
                        }
                        
                        let afterSizeCheck = result.count
                        
                        if afterSizeCheck == 0 && previous != afterSizeCheck {
                            alert(for: mainWindow, info: tr(L10n.appMaxFileSize))
                        } else {
                            strongSelf.chatInteraction.showPreviewSender(result.map{URL(fileURLWithPath: $0)}, true)
                        }
                    }
                })
            }
        }
        
        set(handler: { [weak self] control in
            
            guard let `self` = self else {return}
            if let peer = chatInteraction.presentation.peer {
                
                if let peer = peer as? TelegramChannel {
                    if peer.hasBannedRights(.banSendMedia) {
                        return
                    }
                }
                var items:[SPopoverItem] = []

                let updateMedia:([String]?, Bool)->Void = { [weak self] exts, asMedia in
                    guard let `self` = self else {return}
                    
                    filePanel(with: exts, allowMultiple: false, for: mainWindow, completion: { [weak self] files in
                        guard let `self` = self else {return}
                        if let file = files?.first {
                            self.updateMediaDisposable.set((Sender.generateMedia(for: MediaSenderContainer(path: file, isFile: !asMedia), account: self.chatInteraction.account) |> deliverOnMainQueue).start(next: { [weak self] media, _ in
                                self?.chatInteraction.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                            }))
                        }
                    })
                }
                
                if let editState = chatInteraction.presentation.interfaceState.editState, let media = editState.message.media.first, media is TelegramMediaFile || media is TelegramMediaImage {
                    
                        items.append(SPopoverItem(L10n.inputAttachPopoverPhotoOrVideo, {
                            updateMedia(mediaExts, true)
                        }, theme.icons.chatAttachPhoto))
                        
                        if editState.message.groupingKey == nil {
                            items.append(SPopoverItem(L10n.inputAttachPopoverFile, {
                                updateMedia(nil, false)
                            }, theme.icons.chatAttachFile))
                        }
                } else if chatInteraction.presentation.interfaceState.editState == nil {
                    items.append(SPopoverItem(L10n.inputAttachPopoverPhotoOrVideo, {
                        attachPhotoOrVideo()
                    }, theme.icons.chatAttachPhoto))
                    
                    items.append(SPopoverItem(L10n.inputAttachPopoverPicture, { [weak self] in
                        guard let `self` = self else {return}
                        if let window = self.kitWindow {
                            pickImage(for: window, completion: { (image) in
                                if let image = image {
                                    self.chatInteraction.mediaPromise.set(putToTemp(image: image) |> map({[MediaSenderContainer(path:$0)]}))
                                }
                            })
                        }
                        }, theme.icons.chatAttachCamera))
                    
                    items.append(SPopoverItem(L10n.inputAttachPopoverFile, {
                        attachFile()
                    }, theme.icons.chatAttachFile))
                    
                    items.append(SPopoverItem(L10n.inputAttachPopoverLocation, {
                        showModal(with: LocationModalController(chatInteraction), for: mainWindow)
                    }, theme.icons.chatAttachLocation))
                }
                
                
                if !items.isEmpty {
                    self.controller = SPopoverViewController(items: items)
                    showPopover(for: self, with: self.controller!, edge: nil, inset: NSMakePoint(0,0))
                }
               
            }
        }, for: .Hover)
        
        set(handler: { [weak self] _ in
            guard let `self` = self else {return}
            if let peer = self.chatInteraction.presentation.peer, self.chatInteraction.presentation.interfaceState.editState == nil {
                if peer.mediaRestricted {
                    alertForMediaRestriction(peer)
                    return
                }
                self.controller?.popover?.hide()
                Queue.mainQueue().justDispatch {
                    attachFile()
                }
            }
        }, for: .Click)

        chatInteraction.add(observer: self)
        addSubview(editMediaAccessory)
        editMediaAccessory.layer?.opacity = 0
        updateLocalizationAndTheme()
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let view = other as? ChatInputAttachView {
            return view === self
        } else {
            return false
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        let value = value as? ChatPresentationInterfaceState
        let oldValue = oldValue as? ChatPresentationInterfaceState
        
        if value?.interfaceState.editState != oldValue?.interfaceState.editState {
            if let editState = value?.interfaceState.editState {
                let isMedia = editState.message.media.first is TelegramMediaFile || editState.message.media.first is TelegramMediaImage
                editMediaAccessory.change(opacity: isMedia ? 1 : 0)
                self.highlightHovered = isMedia
                self.autohighlight = isMedia
            } else {
                editMediaAccessory.change(opacity: 0)
                self.highlightHovered = true
                self.autohighlight = true
            }
        }
    }
    
    override func layout() {
        super.layout()
        editMediaAccessory.setFrameOrigin(46 - editMediaAccessory.frame.width, 23)
    }
    
    deinit {
        updateMediaDisposable.dispose()
        chatInteraction.remove(observer: self)
    }

    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        editMediaAccessory.image = theme.icons.editMessageMedia
        editMediaAccessory.sizeToFit()
        set(image: theme.icons.chatAttach, for: .Normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    

}
