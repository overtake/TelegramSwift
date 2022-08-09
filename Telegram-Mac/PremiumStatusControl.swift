//
//  PremiumStatusControl.swift
//  Telegram
//
//  Created by Mike Renoir on 09.08.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import QuartzCore

final class PremiumStatusControl : View {
    private var imageLayer: SimpleLayer?
    private var animateLayer: InlineStickerItemLayer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = .random
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(_ peer: Peer, animated: Bool) {
        
    }
}
