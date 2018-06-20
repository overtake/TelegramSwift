//
//  ChatEmptyPeerItem.swift
//  TelegramMac
//
//  Created by keepcoder on 10/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class ChatEmptyPeerItem: TableRowItem {

    private(set) var textViewLayout:TextViewLayout
    
    override var stableId: AnyHashable {
        return 0
    }
    let chatInteraction:ChatInteraction
    
    override var animatable: Bool {
        return false
    }
    
    override var height: CGFloat {
        if let table = table {
            return table.frame.height
        }
        return initialSize.height
    }
    
    private let peerViewDisposable = MetaDisposable()
    
    init(_ initialSize: NSSize, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        
        let attr = NSMutableAttributedString()
        if  chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat {
            _ = attr.append(string: tr(L10n.chatSecretChatEmptyHeader), color: theme.colors.grayText, font: .normal(.text))
            _ = attr.append(string: "\n\n")
            _ = attr.append(string: tr(L10n.chatSecretChat1Feature), color: theme.colors.grayText, font: .normal(.text))
            _ = attr.append(string: "\n")
            _ = attr.append(string: tr(L10n.chatSecretChat2Feature), color: theme.colors.grayText, font: .normal(.text))
            _ = attr.append(string: "\n")
            _ = attr.append(string: tr(L10n.chatSecretChat3Feature), color: theme.colors.grayText, font: .normal(.text))
            _ = attr.append(string: "\n")
            _ = attr.append(string: tr(L10n.chatSecretChat4Feature), color: theme.colors.grayText, font: .normal(.text))

        } else {
            _ = attr.append(string: tr(L10n.chatEmptyChat), color: theme.colors.grayText, font: .normal(.text))
        }
        textViewLayout = TextViewLayout(attr, alignment: .center)
        textViewLayout.interactions = globalLinkExecutor
        
        super.init(initialSize)
        
        
        if chatInteraction.peerId.namespace == Namespaces.Peer.CloudUser {
            peerViewDisposable.set((chatInteraction.account.postbox.peerView(id: chatInteraction.peerId) |> deliverOnMainQueue).start(next: { [weak self] peerView in
                if let cachedData = peerView.cachedData as? CachedUserData, let user = peerView.peers[peerView.peerId], user.isBot {
                    if let about = cachedData.botInfo?.description {
                        guard let `self` = self else {return}
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: about, color: theme.colors.grayText, font: .normal(.text))
                        attr.detectLinks(type: [.Links, .Mentions, .Hashtags, .Commands], account: chatInteraction.account, color: theme.colors.link, openInfo:chatInteraction.openInfo, hashtag: chatInteraction.account.context.globalSearch ?? {_ in }, command: chatInteraction.sendPlainText, applyProxy: chatInteraction.applyProxy, dotInMention: false)
                        self.textViewLayout = TextViewLayout(attr, alignment: .left)
                        self.textViewLayout.interactions = globalLinkExecutor
                        self.textViewLayout.measure(width: self.width / 2)
                        self.redraw()
                    }
                }
            }))
        }
        
    }
    
    deinit {
        peerViewDisposable.dispose()
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        textViewLayout.measure(width: width / 2)
        return super.makeSize(width)
    }
    
    override func viewClass() -> AnyClass {
        return ChatEmptyPeerView.self
    }
    
}


class ChatEmptyPeerView : TableRowView {
    let textView:TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
    }
    
    override func updateColors() {
        super.updateColors()
        textView.background = theme.colors.background
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ChatEmptyPeerItem {
            item.textViewLayout.measure(width: frame.width / 2)
            textView.update(item.textViewLayout)
            textView.setFrameSize(item.textViewLayout.layoutSize.width + 20, item.textViewLayout.layoutSize.height + 8)
            textView.center()
            
            textView.layer?.cornerRadius = item.textViewLayout.lines.count == 1 ? textView.frame.height / 2 : .cornerRadius
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

