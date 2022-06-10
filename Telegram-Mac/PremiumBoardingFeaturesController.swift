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
    
    private let headerView = PremiumGradientView(frame: .zero)
    private let bottomView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(bottomView)
    }
    
    override func layout() {
        super.layout()
        bottomView.frame = NSMakeRect(0, frame.height - 174, frame.width, 174)
        headerView.frame = NSMakeRect(0, 0, frame.width, frame.height - bottomView.frame.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PremiumBoardingFeaturesController : TelegramGenericViewController<PremiumBoardingFeaturesView> {
    override init(_ context: AccountContext) {
        super.init(context)
        bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        readyOnce()
    }
}
