//
//  PremiumBoardingFeaturesController.swift
//  Telegram
//
//  Created by Mike Renoir on 03.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class PremiumBoardingFeaturesView: View {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PremiumBoardingFeaturesController : TelegramGenericViewController<PremiumBoardingFeaturesView> {
    override init(_ context: AccountContext) {
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        readyOnce()
    }
}
