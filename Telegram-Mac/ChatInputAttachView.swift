
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

import Postbox


class ChatInputAttachView: ImageButton, Notifable {
    
    
    
    private var chatInteraction:ChatInteraction
    private var controller:SPopoverViewController?
    private let editMediaAccessory: ImageView = ImageView()
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(frame: frameRect)
        
        
        highlightHovered = false
        
        
        updateLayout()
        
        let context = chatInteraction.context
        
        self.contextMenu = { [weak self] in
            guard let `self` = self else {
                return nil
            }
            let chatInteraction = self.chatInteraction
            if let peer = chatInteraction.presentation.peer {
                
                var items:[ContextMenuItem] = []
                if let editState = chatInteraction.presentation.interfaceState.editState, let media = editState.originalMedia, media is TelegramMediaFile || media is TelegramMediaImage {
                    if editState.message.groupingKey == nil {
                        items.append(ContextMenuItem(strings().inputAttachPopoverPhotoOrVideo, handler: { [weak self] in
                            self?.chatInteraction.updateEditingMessageMedia(nil, true)
                        }, itemImage: MenuAnimation.menu_shared_media.value))
                        
                        items.append(ContextMenuItem(strings().inputAttachPopoverFile, handler: { [weak self] in
                            self?.chatInteraction.updateEditingMessageMedia(nil, false)
                        }, itemImage: MenuAnimation.menu_file.value))
                        
                        if media is TelegramMediaImage {
                            items.append(ContextMenuItem(strings().editMessageEditCurrentPhoto, handler: { [weak self] in
                                self?.chatInteraction.editEditingMessagePhoto(media as! TelegramMediaImage)
                            }, itemImage: MenuAnimation.menu_edit.value))
                        }
                    } else {
                        if let _ = editState.message.effectiveMedia as? TelegramMediaImage {
                            items.append(ContextMenuItem(strings().inputAttachPopoverPhotoOrVideo, handler: { [weak self] in
                                self?.chatInteraction.updateEditingMessageMedia(mediaExts, true)
                            }, itemImage: MenuAnimation.menu_edit.value))
                        } else if let file = editState.message.effectiveMedia as? TelegramMediaFile {
                            if file.isVideoFile {
                                items.append(ContextMenuItem(strings().inputAttachPopoverPhotoOrVideo, handler: { [weak self] in
                                    self?.chatInteraction.updateEditingMessageMedia(mediaExts, true)
                                }, itemImage: MenuAnimation.menu_shared_media.value))
                            }
                            if file.isMusic {
                                items.append(ContextMenuItem(strings().inputAttachPopoverMusic, handler: { [weak self] in
                                    self?.chatInteraction.updateEditingMessageMedia(audioExts, false)
                                }, itemImage: MenuAnimation.menu_music.value))
                            } else {
                                items.append(ContextMenuItem(strings().inputAttachPopoverFile, handler: { [weak self] in
                                    self?.chatInteraction.updateEditingMessageMedia(nil, false)
                                }, itemImage: MenuAnimation.menu_file.value))
                            }
                        }
                    }
                } else if chatInteraction.presentation.interfaceState.editState == nil {
                    
                    let peerId = chatInteraction.peerId
                    
                    if let slowMode = self.chatInteraction.presentation.slowMode, slowMode.hasLocked {
                        showSlowModeTimeoutTooltip(slowMode, for: self)
                        return nil
                    }
                    
                    items.append(ContextMenuItem(strings().inputAttachPopoverPhotoOrVideo, handler: { [weak self] in
                        if let permissionText = permissionText(from: peer, for: .banSendMedia) {
                            alert(for: context.window, info: permissionText)
                            return
                        }
                        self?.chatInteraction.attachPhotoOrVideo()
                    }, itemImage: MenuAnimation.menu_shared_media.value))
                    
                    let chatMode = chatInteraction.presentation.chatMode

                    let replyTo = chatInteraction.presentation.interfaceState.replyMessageId ?? chatMode.threadId
                    
                    let threadId = chatInteraction.presentation.chatLocation.threadId

                    let acceptMode = chatMode == .history || (chatMode.isThreadMode || chatMode.isTopicMode)
                    
                    if acceptMode, let peer = chatInteraction.presentation.peer {
                        for attach in chatInteraction.presentation.attachItems {
                            
                            let thumbFile: TelegramMediaFile
                            var value: (NSColor, ContextMenuItem)-> AppMenuItemImageDrawable
                            if let file = attach.icons[.macOSAnimated] {
                                value = MenuRemoteAnimation(context, file: file, bot: attach.peer, thumb: MenuAnimation.menu_webapp_placeholder).value
                                thumbFile = file
                            } else {
                                value = MenuAnimation.menu_folder_bot.value
                                thumbFile = MenuAnimation.menu_folder_bot.file
                            }
                            let canAddAttach: Bool
                            if peer.isUser {
                                canAddAttach = attach.peerTypes.contains(.all) || attach.peerTypes.contains(.user)
                            } else if peer.isBot {
                                canAddAttach = attach.peerTypes.contains(.all) || attach.peerTypes.contains(.bot) || (attach.peerTypes.contains(.sameBot) && attach.peer.id == peer.id)
                            } else if peer.isGroup || peer.isSupergroup {
                                canAddAttach = attach.peerTypes.contains(.all) || attach.peerTypes.contains(.group)
                            } else if peer.isChannel {
                                canAddAttach = attach.peerTypes.contains(.all) || attach.peerTypes.contains(.channel)
                            } else {
                                canAddAttach = false
                            }
                            
                            if canAddAttach {
                                items.append(ContextMenuItem(attach.shortName, handler: { [weak self] in
                                    let invoke:()->Void = { [weak self] in
                                        showModal(with: WebpageModalController(context: context, url: "", title: attach.peer.displayTitle, requestData: .normal(url: nil, peerId: peerId, threadId: threadId, bot: attach.peer, replyTo: replyTo, buttonText: "", payload: nil, fromMenu: false, hasSettings: attach.hasSettings, complete: chatInteraction.afterSentTransition), chatInteraction: self?.chatInteraction, thumbFile: thumbFile), for: context.window)
                                    }
                                    invoke()
                                }, itemImage: value))
                            }
                        }
                    }
                    
                    items.append(ContextMenuItem(strings().inputAttachPopoverFile, handler: { [weak self] in
                        if let permissionText = permissionText(from: peer, for: .banSendMedia) {
                            alert(for: context.window, info: permissionText)
                            return
                        }
                        self?.chatInteraction.attachFile(false)
                    }, itemImage: MenuAnimation.menu_file.value))
                    
                    items.append(ContextMenuItem(strings().inputAttachPopoverPicture, handler: { [weak self] in
                        guard let `self` = self else {return}
                        if let permissionText = permissionText(from: peer, for: .banSendMedia) {
                            alert(for: self.chatInteraction.context.window, info: permissionText)
                            return
                        }
                        self.chatInteraction.attachPicture()
                    }, itemImage: MenuAnimation.menu_camera.value))
                    
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
                        items.append(ContextMenuItem(strings().inputAttachPopoverPoll, handler: { [weak self] in
                            guard let `self` = self else {return}
                            if let permissionText = permissionText(from: peer, for: .banSendPolls) {
                                alert(for: context.window, info: permissionText)
                                return
                            }
                            showModal(with: NewPollController(chatInteraction: self.chatInteraction), for: self.chatInteraction.context.window)
                        }, itemImage: MenuAnimation.menu_poll.value))
                    }
                    
                    
                    
                    items.append(ContextMenuItem(strings().inputAttachPopoverLocation, handler: { [weak self] in
                        self?.chatInteraction.attachLocation()
                    }, itemImage: MenuAnimation.menu_location.value))
                }
                
                
                if !items.isEmpty {
                    let menu = ContextMenu(betterInside: true)
                    for item in items {
                        menu.addItem(item)
                    }
                    return menu
                }
            }
            return nil
        }
        
//
//        set(handler: { [weak self] control in
//
//
//        }, for: .Hover)
//
//        set(handler: { [weak self] control in
//            guard let `self` = self else {return}
//
//            if let _ = chatInteraction.presentation.interfaceState.editState {
//                return
//            }
//
//            if let peer = self.chatInteraction.presentation.peer {
//                if let permissionText = permissionText(from: peer, for: .banSendMedia) {
//                    alert(for: self.chatInteraction.context.window, info: permissionText)
//                    return
//                }
//                self.controller?.popover?.hide()
//              //  Queue.mainQueue().justDispatch {
//                    if self.chatInteraction.presentation.interfaceState.editState != nil {
//                        self.chatInteraction.updateEditingMessageMedia(nil, true)
//                    } else {
//                        self.chatInteraction.attachFile(true)
//                    }
//             //   }
//            }
//        }, for: .Click)

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
                let isMedia = editState.message.effectiveMedia is TelegramMediaFile || editState.message.effectiveMedia is TelegramMediaImage
                editMediaAccessory.change(opacity: isMedia ? 1 : 0)
                self.highlightHovered = false
                self.autohighlight = false
            } else {
                editMediaAccessory.change(opacity: 0)
                self.highlightHovered = false
                self.autohighlight = false
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
