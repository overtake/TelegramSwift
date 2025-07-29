
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
                return ContextMenu()
            }
            let chatInteraction = self.chatInteraction
            if let peer = chatInteraction.presentation.peer {
                
                var items:[ContextMenuItem] = []
                if let editState = chatInteraction.presentation.interfaceState.editState, editState.message.pendingProcessingAttribute == nil {
                    if let media = editState.originalMedia, media is TelegramMediaFile || media is TelegramMediaImage {
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
                            if let _ = editState.message.anyMedia as? TelegramMediaImage {
                                items.append(ContextMenuItem(strings().inputAttachPopoverPhotoOrVideo, handler: { [weak self] in
                                    self?.chatInteraction.updateEditingMessageMedia(mediaExts, true)
                                }, itemImage: MenuAnimation.menu_edit.value))
                            } else if let file = editState.message.anyMedia as? TelegramMediaFile {
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
                    } else if editState.message.pendingProcessingAttribute == nil {
                        if editState.message.media.isEmpty {
                            items.append(ContextMenuItem(strings().inputAttachPopoverPhotoOrVideo, handler: { [weak self] in
                                self?.chatInteraction.updateEditingMessageMedia(nil, true)
                            }, itemImage: MenuAnimation.menu_shared_media.value))
                            
                            items.append(ContextMenuItem(strings().inputAttachPopoverFile, handler: { [weak self] in
                                self?.chatInteraction.updateEditingMessageMedia(nil, false)
                            }, itemImage: MenuAnimation.menu_file.value))
                        }
                    }
                } else if chatInteraction.presentation.interfaceState.editState == nil {
                    
                    let peerId = chatInteraction.peerId
                    
                    if let slowMode = self.chatInteraction.presentation.slowMode, slowMode.hasLocked {
                        showSlowModeTimeoutTooltip(slowMode, for: self)
                        return ContextMenu()
                    }
                    
                    if let channel = peer as? TelegramChannel {
                        if channel.hasPermission(.sendPhoto) && channel.hasPermission(.sendVideo) {
                            items.append(ContextMenuItem(strings().inputAttachPopoverPhotoOrVideo, handler: { [weak self] in
                                self?.chatInteraction.attachPhotoOrVideo(nil)
                            }, itemImage: MenuAnimation.menu_shared_media.value))
                        } else {
                            if channel.hasPermission(.sendPhoto) {
                                items.append(ContextMenuItem(strings().inputAttachPopoverPhoto, handler: { [weak self] in
                                    self?.chatInteraction.attachPhotoOrVideo(.photo)
                                }, itemImage: MenuAnimation.menu_shared_media.value))
                            } else if channel.hasPermission(.sendVideo) {
                                items.append(ContextMenuItem(strings().inputAttachPopoverVideo, handler: { [weak self] in
                                    self?.chatInteraction.attachPhotoOrVideo(.video)
                                }, itemImage: MenuAnimation.menu_shared_media.value))
                            }
                        }
                    } else {
                        items.append(ContextMenuItem(strings().inputAttachPopoverPhotoOrVideo, handler: { [weak self] in
                            self?.chatInteraction.attachPhotoOrVideo(nil)
                        }, itemImage: MenuAnimation.menu_shared_media.value))
                    }
                    
                    if let shortcuts = chatInteraction.presentation.shortcuts, let peer = chatInteraction.peer, chatInteraction.presentation.chatMode == .history {
                        if peer.isUser && !peer.isBot {
                            if !shortcuts.items.isEmpty, context.isPremium {
                                items.append(ContextMenuItem(strings().chatInputAttachQuickReply, handler: { [weak self] in
                                    self?.chatInteraction.clearInput()
                                    self?.chatInteraction.appendText(.initialize(string: "/"))
                                }, itemImage: MenuAnimation.menu_reply.value))
                            }
                        }
                    }
                    
                    let chatMode = chatInteraction.presentation.chatMode

                    let replyTo = chatInteraction.presentation.interfaceState.replyMessageId?.messageId ?? chatInteraction.chatLocation.threadMsgId
                    
                    let threadId = chatInteraction.presentation.chatLocation.threadId
                    
                    let acceptMode = chatMode == .history || (chatMode.isThreadMode || chatMode.isTopicMode)
                    
                    
                    if let peer = chatInteraction.presentation.mainPeer {
                        if context.premiumLimits.show_premium_gift_in_attach_menu, !peer.isPremium, peer.isUser {
                            items.append(ContextMenuItem(strings().inputAttachPopoverGift, handler: {
                                showModal(with: GiftingController(context: context, peerId: peerId, isBirthday: false), for: context.window)
                            }, itemImage: MenuAnimation.menu_gift.value))
                        }
                    }
                    
                    if acceptMode, let peer = chatInteraction.presentation.peer {
                        for attach in chatInteraction.presentation.attachItems {
                            
                            var value: (NSColor, ContextMenuItem)-> AppMenuItemImageDrawable
                            if let file = attach.icons[.macOSAnimated] {
                                value = MenuRemoteAnimation(context, file: file, bot: attach.peer._asPeer(), thumb: MenuAnimation.menu_webapp_placeholder).value
                            } else {
                                value = MenuAnimation.menu_folder_bot.value
                            }
                            var canAddAttach: Bool
                            if peer.isUser {
                                canAddAttach = attach.peerTypes.contains(.all) || attach.peerTypes.contains(.user)
                            } else if peer.isBot {
                                canAddAttach = attach.peerTypes.contains(.all) || attach.peerTypes.contains(.bot) || (attach.peerTypes.contains(.sameBot) && attach.peer.id == peer.id)
                            } else if peer.isGroup || peer.isSupergroup {
                                canAddAttach = attach.peerTypes.contains(.all) || attach.peerTypes.contains(.group)
                            } else if peer.isChannel, !peer.hasBannedRights(.banSendText) {
                                canAddAttach = attach.peerTypes.contains(.all) || attach.peerTypes.contains(.channel)
                            } else {
                                canAddAttach = false
                            }
                            
                            canAddAttach = canAddAttach && attach.flags.contains(.showInAttachMenu)
                            
                            if canAddAttach {
                                let bot = attach
                                items.append(ContextMenuItem(attach.shortName, handler: {
                                    let open:()->Void = {
                                        BrowserStateContext.get(context).open(tab: .webapp(bot: bot.peer, peerId: peerId, buttonText: "", url: nil, payload: nil, threadId: threadId, replyTo: replyTo, fromMenu: false))
                                        
                                    }
                                    if bot.flags.contains(.showInSettingsDisclaimer) || bot.flags.contains(.notActivated) { //
                                        var options: [ModalAlertData.Option] = []
                                        options.append(.init(string: strings().webBotAccountDisclaimerThird, isSelected: false, mandatory: true))
                                        
                                       
                                        var description: ModalAlertData.Description? = nil
                                        let installBot = !bot.flags.contains(.notActivated) && bot.peer._asPeer().botInfo?.flags.contains(.canBeAddedToAttachMenu) == true && !bot.flags.contains(.showInAttachMenu)
                                        
                                        if installBot {
                                            description = .init(string: strings().webBotAccountDesclaimerDesc(bot.shortName), onlyWhenEnabled: false)
                                        }
                                        
                                        let data = ModalAlertData(title: strings().webBotAccountDisclaimerTitle, info: strings().webBotAccountDisclaimerText, description: description, ok: strings().webBotAccountDisclaimerOK, options: options)
                                        showModalAlert(for: context.window, data: data, completion: { result in
                                            
                                            _ = context.engine.messages.acceptAttachMenuBotDisclaimer(botId: bot.peer.id).start()
                                            installAttachMenuBot(context: context, peer: bot.peer._asPeer(), completion: { value in
                                                if value, installBot {
                                                    showModalText(for: context.window, text: strings().webAppAttachSuccess(bot.peer._asPeer().displayTitle))
                                                }
                                                open()
                                            })
                                        })
                                    } else {
                                        open()
                                    }
                                    
                                }, itemImage: value))
                            }
                        }
                    }
                    if let channel = peer as? TelegramChannel {
                        if permissionText(from: channel, for: .banSendFiles) == nil {
                            items.append(ContextMenuItem(strings().inputAttachPopoverFile, handler: { [weak self] in
                                self?.chatInteraction.attachFile(false)
                            }, itemImage: MenuAnimation.menu_file.value))
                        }
                    } else {
                        items.append(ContextMenuItem(strings().inputAttachPopoverFile, handler: { [weak self] in
                            self?.chatInteraction.attachFile(false)
                        }, itemImage: MenuAnimation.menu_file.value))
                    }
                    
                    
                    if let channel = peer as? TelegramChannel {
                        if channel.hasPermission(.sendPhoto) {
                            items.append(ContextMenuItem(strings().inputAttachPopoverPicture, handler: { [weak self] in
                                guard let `self` = self else {return}
                                self.chatInteraction.attachPicture()
                            }, itemImage: MenuAnimation.menu_camera.value))
                        }
                    } else {
                        items.append(ContextMenuItem(strings().inputAttachPopoverPicture, handler: { [weak self] in
                            guard let `self` = self else {return}
                            self.chatInteraction.attachPicture()
                        }, itemImage: MenuAnimation.menu_camera.value))
                    }
                    
                    
                    
                    var canAttachPoll: Bool = false
                    var canAttachLocation: Bool = true
                    var canAttachTodo: Bool = true
                    
                    if let peer = chatInteraction.presentation.peer, peer.isChannel {
                        canAttachTodo = false
                    }
                    
                    if let peer = chatInteraction.presentation.peer, peer.isGroup || peer.isSupergroup, !peer.isMonoForum {
                        canAttachPoll = true
                    }
                    if let peer = chatInteraction.presentation.mainPeer, peer.isBot {
                        canAttachPoll = true
                    }
                    
                    if let peer = chatInteraction.presentation.peer as? TelegramChannel {
                        if peer.hasPermission(.sendText) {
                            canAttachPoll = true
                        } else {
                            canAttachLocation = false
                        }
                    }
                    if canAttachPoll && permissionText(from: peer, for: .banSendPolls) != nil {
                        canAttachPoll = false
                    }
                   
                    if canAttachPoll {
                        items.append(ContextMenuItem(strings().inputAttachPopoverPoll, handler: { [weak self] in
                            guard let `self` = self else {return}
                            if let permissionText = permissionText(from: peer, for: .banSendPolls) {
                                showModalText(for: context.window, text: permissionText)
                                return
                            }
                            showModal(with: NewPollController(chatInteraction: self.chatInteraction), for: self.chatInteraction.context.window)
                        }, itemImage: MenuAnimation.menu_poll.value))
                    }
                    
                    if canAttachTodo, context.isPremium {
                        let item = ContextMenuItem(strings().inputAttachPopoverChecklist, handler: { [weak self] in
                            guard let `self` = self else {return}
                            if let permissionText = permissionText(from: peer, for: .banSendPolls) {
                                showModalText(for: context.window, text: permissionText)
                                return
                            }
                            if !context.isPremium {
                                prem(with: PremiumBoardingController(context: context, source: .todo, openFeatures: true), for: context.window)
                            } else {
                                showModal(with: NewTodoController(chatInteraction: self.chatInteraction), for: self.chatInteraction.context.window)
                            }
                        }, itemImage: MenuAnimation.menu_list.value, locked: !context.isPremium)
                        items.append(item)
                    }
                    
                    if canAttachLocation {
                        items.append(ContextMenuItem(strings().inputAttachPopoverLocation, handler: { [weak self] in
                            if let permissionText = permissionText(from: peer, for: .banSendText) {
                                showModalText(for: context.window, text: permissionText)
                                return
                            }
                            self?.chatInteraction.attachLocation()
                        }, itemImage: MenuAnimation.menu_location.value))
                    }
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
                let isMedia = editState.message.anyMedia is TelegramMediaFile || editState.message.anyMedia is TelegramMediaImage
                editMediaAccessory.change(opacity: isMedia && editState.canEditMedia ? 1 : 0)
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
