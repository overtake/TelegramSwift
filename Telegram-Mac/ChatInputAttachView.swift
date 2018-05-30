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


class ChatInputAttachView: ImageButton {
        
    private var chatInteraction:ChatInteraction
    private var controller:SPopoverViewController?
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
                                return size <= 1500000000
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
                                return size <= 1500000000
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
        
        set(handler: { [weak self] (state) in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.presentation.peer {
                
                if let peer = peer as? TelegramChannel {
                    if peer.hasBannedRights(.banSendMedia) {
                        return
                    }
                }
                
                var items = [SPopoverItem(tr(L10n.inputAttachPopoverPhotoOrVideo), {
                    attachPhotoOrVideo()
                }, theme.icons.chatAttachPhoto), SPopoverItem(tr(L10n.inputAttachPopoverPicture), { [weak strongSelf] in
                    if  let strongSelf = strongSelf, let window = strongSelf.kitWindow {
                        pickImage(for: window, completion: { (image) in
                            if let image = image {
                                strongSelf.chatInteraction.mediaPromise.set(putToTemp(image: image) |> map({[MediaSenderContainer(path:$0)]}))
                            }
                        })
                    }
                    
                }, theme.icons.chatAttachCamera), SPopoverItem(tr(L10n.inputAttachPopoverFile), {
                    attachFile()
                }, theme.icons.chatAttachFile)]
                
                items.append(SPopoverItem(L10n.inputAttachPopoverLocation, {
                    showModal(with: LocationModalController(chatInteraction), for: mainWindow)
                }, theme.icons.chatAttachLocation))
//
                strongSelf.controller = SPopoverViewController(items: items)
                showPopover(for: strongSelf, with: strongSelf.controller!, edge: nil, inset: NSMakePoint(0,0))
            }
        }, for: .Hover)
        
        set(handler: { [weak self] _ in
            if let peer = self?.chatInteraction.presentation.peer {
                if peer.mediaRestricted {
                    alertForMediaRestriction(peer)
                    return
                }
                self?.controller?.popover?.hide()
                Queue.mainQueue().justDispatch {
                    attachFile()
                }
            }
        }, for: .Click)

    }

    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        set(image: theme.icons.chatAttach, for: .Normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    

}
