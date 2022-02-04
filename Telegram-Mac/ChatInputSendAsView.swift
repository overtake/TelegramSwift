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

        
        
        self.contextMenu = { [weak self] in
            
            let menu = ContextMenu(betterInside: true)
            
            guard let list = self?.peers else {
                return nil
            }
            guard let chatInteraction = self?.chatInteraction else {
                return nil
            }
            let currentPeerId = self?.currentPeerId
            
            let context = chatInteraction.context
            
            var items:[ContextMenuItem] = []
            
            var peers = list
            if let index = peers.firstIndex(where: { $0.peer.id == currentPeerId }) {
                peers.move(at: index, to: 0)
            }
            let header = ContextMenuItem(strings().chatSendAsHeader)
            header.isEnabled = false
            items.append(header)
            
            for (i, peer) in peers.enumerated() {
                items.append(ContextSendAsMenuItem(peer: peer, context: context, isSelected: i == 0, handler: { [weak self] in
                    self?.toggleSendAs(peer.peer.id)
                }))
            }
                    
            for item in items {
                menu.addItem(item)
            }
            return menu
        }
        
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
    
    private var first: Bool = true
    
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
            
            if animated, !first {
                avatar.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.3)
            }
            first = false
        }
    }
}
