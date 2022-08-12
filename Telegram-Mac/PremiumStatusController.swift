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
    

    override init(_ context: AccountContext) {
        self.emojis = .init(context, mode: .status)
        super.init(context)
        bar = .init(height: 0)
        _frameRect = NSMakeRect(0, 0, 350, 300)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emojis._frameRect = self.bounds
        self.view.addSubview(emojis.view)
        self.ready.set(self.emojis.ready.get())
    }
}
