//
//  ChatInputSendAsView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.11.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox



final class ChatInputSendAsView : Control {
    private weak var chatInteraction: ChatInteraction?
    private var peers: [FoundPeer]?
    private var currentPeerId: PeerId?
    private var avatar: AvatarControl?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.scaleOnClick = true

        
        
        set(handler: { [weak self] control in
            self?.showOptions(control)
        }, for: .Down)
    }
    
    private func showOptions(_ control: Control) {
        if let popover = self.popover {
            popover.hide()
            return
        }
        
        guard let list = self.peers else {
            return
        }
        guard let chatInteraction = self.chatInteraction else {
            return
        }
        
        let account = chatInteraction.context.account
        
        let items:[SPopoverItem] = []
        var headerItems: [TableRowItem] = []
        headerItems.append(SeparatorRowItem.init(NSZeroSize, 0, string: strings().chatSendAsHeader))
        
        var peers = list
        if let index = peers.firstIndex(where: { $0.peer.id == currentPeerId }) {
            peers.move(at: index, to: 0)
        }
        
        for peer in peers {
            
            let status: String
            if peer.peer.isUser {
                status = strings().chatSendAsPersonalAccount
            } else {
                if peer.peer.isGroup || peer.peer.isSupergroup {
                    status = strings().chatSendAsGroupCountable(Int(peer.subscribers ?? 0))
                } else {
                    status = strings().chatSendAsChannelCountable(Int(peer.subscribers ?? 0))
                }
            }
            
            let item = ShortPeerRowItem(NSZeroSize, peer: peer.peer, account: account, height: 45, photoSize: NSMakeSize(30, 30), titleStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.text, highlightColor: .white), statusStyle: ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status: status, drawCustomSeparator: peer != peers.last, inset: NSEdgeInsets(left: 10), action: { [weak self] in
                
                self?.toggleSendAs(peer.peer.id)
                
            }, highlightOnHover: true, drawPhotoOuter: peer.peer.id == currentPeerId)
            
            headerItems.append(item)
           
        }
                
        let controller = SPopoverViewController(items: items, visibility: 10, headerItems: headerItems)
        showPopover(for: control, with: controller)
    }
    
    private func toggleSendAs(_ peerId: PeerId) {
        self.popover?.hide()
        
        self.chatInteraction?.toggleSendAs(peerId)
    }
    
    override func layout() {
        super.layout()
        guard let avatar = self.avatar else {
            return
        }
        avatar.centerY(x: frame.width - avatar.frame.width)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ peers: [FoundPeer], currentPeerId: PeerId, chatInteraction: ChatInteraction, animated: Bool) {
        let currentIsUpdated = self.currentPeerId != currentPeerId
        self.currentPeerId = currentPeerId
        self.peers = peers
        self.chatInteraction = chatInteraction
        
        let currentPeer = peers.first(where: { $0.peer.id == currentPeerId })
        if currentIsUpdated {
            
            if let view = self.avatar {
                if animated {
                    view.layer?.animateScaleSpring(from: 1, to: 0.1, duration: 0.3, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                } else {
                    view.removeFromSuperview()
                }
            }
            let avatar = AvatarControl(font: .avatar(18))
            avatar.frame = NSMakeRect(0, 0, 30, 30)
            avatar.userInteractionEnabled = false
            avatar.setPeer(account: chatInteraction.context.account, peer: currentPeer?.peer)
            self.addSubview(avatar)
            avatar.centerY(x: frame.width - avatar.frame.width)
            self.avatar = avatar
            
            if animated {
                avatar.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.3)
            }
        }
    }
}
