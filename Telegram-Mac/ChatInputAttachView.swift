//
//  ChatInputAttachView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox


class ChatInputAttachView: ImageButton, Notifable {
    
    
    
    private var chatInteraction:ChatInteraction
    private var controller:SPopoverViewController?
    private let editMediaAccessory: ImageView = ImageView()
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(frame: frameRect)
        
        
        highlightHovered = true
        
        
        updateLayout()
        
        
        set(handler: { [weak self] control in
            
            guard let `self` = self else {return}
            if let peer = chatInteraction.presentation.peer {
                
                var items:[SPopoverItem] = []
                if let editState = chatInteraction.presentation.interfaceState.editState, let media = editState.originalMedia, media is TelegramMediaFile || media is TelegramMediaImage {
                    
                    items.append(SPopoverItem(L10n.inputAttachPopoverPhotoOrVideo, { [weak self] in
                        self?.chatInteraction.updateEditingMessageMedia(mediaExts, true)
                    }, theme.icons.chatAttachPhoto))
                    
                    if editState.message.groupingKey == nil {
                        items.append(SPopoverItem(L10n.inputAttachPopoverFile, { [weak self] in
                            self?.chatInteraction.updateEditingMessageMedia(nil, false)
                        }, theme.icons.chatAttachFile))
                    }
                    
                    if media is TelegramMediaImage {
                        items.append(SPopoverItem(L10n.editMessageEditCurrentPhoto, { [weak self] in
                            self?.chatInteraction.editEditingMessagePhoto(media as! TelegramMediaImage)
                        }, theme.icons.editMessageCurrentPhoto))
                    }
                    
                    
                } else if chatInteraction.presentation.interfaceState.editState == nil {
                    
                    if let slowMode = self.chatInteraction.presentation.slowMode, slowMode.hasLocked {
                        showSlowModeTimeoutTooltip(slowMode, for: control)
                        return
                    }
                    
                    items.append(SPopoverItem(L10n.inputAttachPopoverPhotoOrVideo, { [weak self] in
                        if let permissionText = permissionText(from: peer, for: .banSendMedia) {
                            alert(for: mainWindow, info: permissionText)
                            return
                        }
                        self?.chatInteraction.attachPhotoOrVideo()
                    }, theme.icons.chatAttachPhoto))
                    
                    items.append(SPopoverItem(L10n.inputAttachPopoverPicture, { [weak self] in
                        guard let `self` = self else {return}
                        if let permissionText = permissionText(from: peer, for: .banSendMedia) {
                            alert(for: mainWindow, info: permissionText)
                            return
                        }
                        self.chatInteraction.attachPicture()
                    }, theme.icons.chatAttachCamera))
                    
                    var canAttachPoll: Bool = false
                    if let peer = chatInteraction.presentation.peer, peer.isGroup || peer.isSupergroup {
                        canAttachPoll = true
                    }
                    if let peer = chatInteraction.presentation.mainPeer, peer.isBot {
                        canAttachPoll = true
                    }
                    
                    if let peer = chatInteraction.presentation.peer as? TelegramChannel {
                        if peer.hasPermission(.sendMessages) {
                            canAttachPoll = true
                        }
                    }
                    if canAttachPoll && permissionText(from: peer, for: .banSendPolls) != nil {
                        canAttachPoll = false
                    }
                   
                    if canAttachPoll {
                        items.append(SPopoverItem(L10n.inputAttachPopoverPoll, { [weak self] in
                            guard let `self` = self else {return}
                            if let permissionText = permissionText(from: peer, for: .banSendPolls) {
                                alert(for: mainWindow, info: permissionText)
                                return
                            }
                            showModal(with: NewPollController(chatInteraction: self.chatInteraction), for: mainWindow)
                        }, theme.icons.chatAttachPoll))
                    }
                    
                    items.append(SPopoverItem(L10n.inputAttachPopoverFile, { [weak self] in
                        if let permissionText = permissionText(from: peer, for: .banSendMedia) {
                            alert(for: mainWindow, info: permissionText)
                            return
                        }
                        self?.chatInteraction.attachFile(false)
                    }, theme.icons.chatAttachFile))
                    
                    items.append(SPopoverItem(L10n.inputAttachPopoverLocation, { [weak self] in
                        self?.chatInteraction.attachLocation()
                    }, theme.icons.chatAttachLocation))
                }
                
                
                if !items.isEmpty {
                    self.controller = SPopoverViewController(items: items, visibility: 10)
                    showPopover(for: self, with: self.controller!, edge: nil, inset: NSMakePoint(0,0))
                }
               
            }
        }, for: .Hover)
        
        set(handler: { [weak self] control in
            guard let `self` = self else {return}
            if let peer = self.chatInteraction.presentation.peer, self.chatInteraction.presentation.interfaceState.editState == nil {
                if let permissionText = permissionText(from: peer, for: .banSendMedia) {
                    alert(for: mainWindow, info: permissionText)
                    return
                }
                self.controller?.popover?.hide()
                Queue.mainQueue().justDispatch {
                    self.chatInteraction.attachFile(true)
                }
            }
        }, for: .Click)

        chatInteraction.add(observer: self)
        addSubview(editMediaAccessory)
        editMediaAccessory.layer?.opacity = 0
        updateLocalizationAndTheme(theme: theme)
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
       
//        if let slowMode = value?.slowMode {
//            if slowMode.hasError  {
//                self.highlightHovered = false
//                self.autohighlight = false
//            }
//        }
    }
    
    override func layout() {
        super.layout()
        editMediaAccessory.setFrameOrigin(46 - editMediaAccessory.frame.width, 23)
    }
    
    deinit {
        chatInteraction.remove(observer: self)
    }

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
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
