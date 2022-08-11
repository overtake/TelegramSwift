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
    
    let callback: (TelegramMediaFile)->Void
    init(_ context: AccountContext, callback: @escaping(TelegramMediaFile)->Void) {
        self.emojis = .init(context, mode: .status)
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
        
        interactions.sendAnimatedEmoji = { [weak self] item in
            self?.callback(item.file)
            self?.closePopover()
        }
        
        emojis.update(with: interactions, chatInteraction: chatInteraction)
    }
}
