//
//  JoinLinkPreviewModalController.swift
//  Telegram
//
//  Created by keepcoder on 04/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private class JoinLinkPreviewView : View {
    private let imageView:AvatarControl = AvatarControl(font: .avatar(.huge))
    private let titleView:TextView = TextView()
    private let basicContainer:View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = theme.colors.background
        imageView.setFrameSize(70,70)
        addSubview(basicContainer)
        basicContainer.backgroundColor = theme.colors.background
        titleView.backgroundColor = theme.colors.background
        basicContainer.addSubview(imageView)
        basicContainer.addSubview(titleView)
    }
    
    func update(with peer:TelegramGroup, account:Account, participants:[Peer] = []) -> Void {
        imageView.setPeer(account: account, peer: peer)
        let attr = NSMutableAttributedString()
        _ = attr.append(string: peer.displayTitle, color: theme.colors.text, font: .normal(.title))
        _ = attr.append(string: "\n")
        
        _ = attr.append(string: tr(L10n.peerStatusMemberCountable(peer.participantCount)), color: theme.colors.grayText, font: .normal(.text))
        let titleLayout = TextViewLayout(attr, alignment: .center)
        titleLayout.measure(width: frame.width - 40)
        titleView.update(titleLayout)
        
        basicContainer.setFrameSize(frame.width, imageView.frame.height + titleView.frame.height + 10)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        basicContainer.center()
        imageView.centerX(y: 0)
        titleView.centerX(y: 80)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class JoinLinkPreviewModalController: ModalViewController {

    private let account:Account
    private let join:ExternalJoiningChatState
    private let joinhash:String
    private let interaction:(PeerId?)->Void
    override func viewDidLoad() {
        super.viewDidLoad()
        switch join {
        case let .invite(data):
            let peer = TelegramGroup(id: PeerId(namespace: 0, id: 0), title: data.title, photo: data.photoRepresentation != nil ? [data.photoRepresentation!] : [], participantCount: Int(data.participantsCount), role: .member, membership: .Left, flags: [], migrationReference: nil, creationDate: 0, version: 0)
            
            genericView.update(with: peer, account: account)
        default:
            break
        }
        readyOnce()
    }
    
    private var genericView:JoinLinkPreviewView {
        return self.view as! JoinLinkPreviewView
    }
    
    override func viewClass() -> AnyClass {
        return JoinLinkPreviewView.self
    }
    
    init(_ account:Account, hash:String, join:ExternalJoiningChatState, interaction:@escaping(PeerId?)->Void) {
        self.account = account
        self.join = join
        self.joinhash = hash
        self.interaction = interaction
        super.init(frame: NSMakeRect(0, 0, 250, 200))
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.joinLinkJoin), accept: { [weak self] in
            if let strongSelf = self, let window = strongSelf.window {
                _ = showModalProgress(signal: joinChatInteractively(with: strongSelf.joinhash, account: strongSelf.account), for: window).start(next: { [weak strongSelf] (peerId) in
                    strongSelf?.interaction(peerId)
                    self?.close()
                })
            }
        }, cancelTitle: tr(L10n.modalCancel))
        
    }
    
}
