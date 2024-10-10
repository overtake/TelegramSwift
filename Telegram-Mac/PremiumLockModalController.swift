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
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override var modalTheme:Theme {
        return Theme(text: .clear, grayText: .clear, background: .clear, border: .clear, accent: .clear, grayForeground: .clear, activeBackground: .clear, activeBorder: .clear, listBackground: .clear)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        readyOnce()
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .invoked
    }
}
