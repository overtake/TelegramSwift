//
//  InlineAvatarLayer.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24.04.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

final class InlineAvatarLayer: SimpleLayer {
    private var disposable: Disposable?
    init(context: AccountContext, frame: NSRect, peer: EnginePeer) {
        
        super.init()
        self.frame = frame
        let size = frame.size
                
        let signal: Signal<(CGImage?, Bool), NoError> = peerAvatarImage(account: context.account, photo: .peer(peer._asPeer(), peer._asPeer().smallProfileImage, peer._asPeer().nameColor, peer.displayLetters, nil), displayDimensions: size, scale: System.backingScale, font: .avatar(size.height / 3 + 3), genCap: true, synchronousLoad: false) |> deliverOnMainQueue
        
        let disposable = signal.start(next: { [weak self] values in
            self?.contents = values.0
        })
        self.disposable = disposable
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }

    deinit {
        disposable?.dispose()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

