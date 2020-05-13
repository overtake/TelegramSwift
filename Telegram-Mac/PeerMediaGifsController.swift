//
//  PeerMediaGifsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/05/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import SyncCore


final class PeerMediaGifsView : View {
    
}

class PeerMediaGifsController: TelegramGenericViewController<PeerMediaGifsView> {

    private let peerId: PeerId
    init(_ context: AccountContext, peerId: PeerId) {
        self.peerId = peerId
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        chatHistoryViewForLocation(.Initial(count: 100), account: context.account, chatLocation: .peer(peerId), fixedCombinedReadStates: nil, tagMask: .gif, mode: .history)
    }
}
