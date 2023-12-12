//
//  CustomizeAccountController.swift
//  Telegram
//
//  Created by Mike Renoir on 20.11.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit

private final class CenterView : TitledBarView {
    let segment: CatalinaStyledSegmentController
    var select:((Int)->Void)? = nil
    init(controller: ViewController) {
        self.segment = CatalinaStyledSegmentController(frame: NSMakeRect(0, 0, 240, 30))
        super.init(controller: controller)
        
        segment.add(segment: .init(title: strings().customizeNameTitle, handler: { [weak self] in
            self?.select?(0)
        }))
        
        segment.add(segment: .init(title: strings().customizeProfileTitle, handler: { [weak self] in
            self?.select?(1)
        }))
        
        self.addSubview(segment.view)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        segment.theme = CatalinaSegmentTheme(backgroundColor: theme.colors.listBackground, foregroundColor: theme.colors.background, activeTextColor: theme.colors.text, inactiveTextColor: theme.colors.listGrayText)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        segment.view.frame = focus(NSMakeSize(min(frame.width - 40, 600), 30))
    }
}

final class CustomizeAccountController : SectionViewController {
    private let name: ViewController
    private let profile: ViewController
    private let context: AccountContext
    private let peerId: PeerId
    private let peer: Peer
    private let profileState: SelectColorCallback = .init()
    private let nameState: SelectColorCallback = .init()
    init(_ context: AccountContext, peer: Peer) {
        self.context = context
        self.peerId = peer.id
        self.peer = peer
        self.name = SelectColorController(context: context, source: peer.isChannel ? .channel(peer) : .account(peer), type: .name, callback: nameState)
        self.profile = SelectColorController(context: context, source: peer.isChannel ? .channel(peer) : .account(peer), type: .profile, callback: profileState)

        var items:[SectionControllerItem] = []
        items.append(SectionControllerItem(title: { "" }, controller: name))
        items.append(SectionControllerItem(title: { "" }, controller: profile))

        super.init(sections: items, selected: 0, hasHeaderView: false, hasBar: true)

    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return CenterView(controller: self)
    }
    
    override func getRightBarViewOnce() -> BarView {
        return TextButtonBarView(controller: self, text: strings().selectColorApply, style: barPresentation, alignment:.Right)
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override var supportSwipes: Bool {
        return self.selectedIndex == 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centerView.select = { [weak self] index in
            self?.select(index, true)
        }
        
        self.selectionUpdateHandler = { [weak self] index in
            self?.centerView.segment.set(selected: index, animated: true)
        }
        let context = self.context
        
        let channel_color_level_min = context.appConfiguration.getGeneralValue("channel_color_level_min", orElse: 1)

        
        let invoke:()->Void = { [weak self] in
            let nameState = self?.nameState.getState?()
            let profileState = self?.profileState.getState?()
            
            
            let nameColor = nameState?.0 ?? .blue
            let backgroundEmojiId = nameState?.1
            let profileColor = profileState?.0
            let profileBackgroundEmojiId = profileState?.1
            
            if let peer = self?.peer, peer.isChannel {
                let peerId = peer.id
                let signal = showModalProgress(signal: combineLatest(context.engine.peers.getChannelBoostStatus(peerId: peerId), context.engine.peers.getMyBoostStatus()), for: context.window)
                
                _ = signal.start(next: { stats, myStatus in
                    if let stats = stats {
                        if stats.level < channel_color_level_min {
                            showModal(with: BoostChannelModalController(context: context, peer: peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .color(channel_color_level_min)), for: context.window)
                        } else {
                            _ = context.engine.peers.updatePeerNameColorAndEmoji(peerId: peerId, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId).start()
                            self?.navigationController?.back()
                            showModalText(for: context.window, text: strings().selectColorSuccessChannel)
                        }
                    }
                })
            } else {
                if context.isPremium {
                    _ = context.engine.accountData.updateNameColorAndEmoji(nameColor: nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId).start()
                    showModalText(for: context.window, text: strings().selectColorSuccessUser)
                    self?.navigationController?.back()
                } else {
                    showModalText(for: context.window, text: strings().selectColorPremium, callback: { _ in
                        showModal(with: PremiumBoardingController(context: context), for: context.window)
                    })
                }
            }
        }
        
        self.rightBarView.set(handler:{ _ in
            invoke()
        }, for: .Click)
        
        nameState.validate = {
            invoke()
        }
        profileState.validate = {
            invoke()
        }
    }
    
    private var centerView: CenterView {
        return self.centerBarView as! CenterView
    }
}
