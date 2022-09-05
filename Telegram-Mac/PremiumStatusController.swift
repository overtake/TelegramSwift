//
//  PremiumStatusController.swift
//  Telegram
//
//  Created by Mike Renoir on 08.08.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox

final class PremiumStatusController : TelegramViewController {
    
    private let emojis: EmojiesController
    
    let callback: (TelegramMediaFile, Int32?)->Void
    init(_ context: AccountContext, callback: @escaping(TelegramMediaFile, Int32?)->Void, peer: TelegramUser) {
        
        
        var selected: [EmojiesSectionRowItem.SelectedItem] = []
        if let fileId = peer.emojiStatus?.fileId {
            selected.append(.init(source: .custom(fileId), type: .normal))
        } else {
            selected.append(.init(source: .custom(0), type: .normal))
        }
        self.emojis = .init(context, mode: .status, selectedItems: selected)
        self.callback = callback
        super.init(context)
        bar = .init(height: 0)
        _frameRect = NSMakeRect(0, 0, 350, 300)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emojis._frameRect = self.bounds
        self.view.addSubview(emojis.view)
        self.ready.set(self.emojis.ready.get())
        
        let chatInteraction = ChatInteraction(chatLocation: .peer(context.peerId), context: context)
        
        let interactions = EntertainmentInteractions(.emoji, peerId: context.peerId)
        
        interactions.sendAnimatedEmoji = { [weak self] item, _, timeout in
            self?.callback(item.file, timeout)
            self?.closePopover()
        }
        
        emojis.update(with: interactions, chatInteraction: chatInteraction)
        
        emojis.animateAppearance = { [weak self] items in
            self?.animateAppearanceItems(items)
        }
    }
    
    private func animateAppearanceItems(_ items: [TableRowItem]) {
        let sections = items.compactMap {
            $0 as? EmojiesSectionRowItem
        }
        let tabs = items.compactMap {
            $0 as? StickerPackRowItem
        }
        let firstTab = items.compactMap {
            $0 as? ETabRowItem
        }
        
        let duration: Double = 0.35
        let itemDelay: Double = duration / Double(sections.count)
        var delay: Double = itemDelay
        
        firstTab.first?.animateAppearance(delay: 0, duration: duration, ignoreCount: 0)
        
        for tab in tabs {
            tab.animateAppearance(delay: 0, duration: duration, ignoreCount: 0)
        }
        
        for (i, section) in sections.enumerated() {
            section.animateAppearance(delay: delay, duration: duration, ignoreCount: i == 0 ? 6 : 0)
            delay += itemDelay
        }
    }
}




final class SetupQuickReactionController : TelegramViewController {
    
    private let emojis: EmojiesController
    
    let callback: (TelegramMediaFile)->Void
    init(_ context: AccountContext, callback: @escaping(TelegramMediaFile)->Void) {
        self.emojis = .init(context, mode: .reactions)
        self.callback = callback
        super.init(context)
        bar = .init(height: 0)
        _frameRect = NSMakeRect(0, 0, 350, 300)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emojis._frameRect = self.bounds
        self.view.addSubview(emojis.view)
        self.ready.set(self.emojis.ready.get())
        
        let chatInteraction = ChatInteraction(chatLocation: .peer(context.peerId), context: context)
        
        let interactions = EntertainmentInteractions(.emoji, peerId: context.peerId)
        
        interactions.sendAnimatedEmoji = { [weak self] item, _, _ in
            self?.callback(item.file)
            self?.closePopover()
        }
        
        emojis.update(with: interactions, chatInteraction: chatInteraction)
        
        emojis.animateAppearance = { [weak self] items in
            self?.animateAppearanceItems(items)
        }
    }
    
    private func animateAppearanceItems(_ items: [TableRowItem]) {
        let sections = items.compactMap {
            $0 as? EmojiesSectionRowItem
        }
        let tabs = items.compactMap {
            $0 as? StickerPackRowItem
        }
        let firstTab = items.compactMap {
            $0 as? ETabRowItem
        }
        
        let duration: Double = 0.35
        let itemDelay: Double = duration / Double(sections.count)
        var delay: Double = itemDelay
        
        firstTab.first?.animateAppearance(delay: 0, duration: duration, ignoreCount: 0)
        
        for tab in tabs {
            tab.animateAppearance(delay: 0, duration: duration, ignoreCount: 0)
        }
        
        for (i, section) in sections.enumerated() {
            section.animateAppearance(delay: delay, duration: duration, ignoreCount: i == 0 ? 6 : 0)
            delay += itemDelay
        }
    }
}
