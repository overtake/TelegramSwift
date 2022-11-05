//
//  PremiumLockModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 02.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class PremiumLockModalController : ModalViewController {
    
    
    override var closable: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        readyOnce()
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .invoked
    }
}
