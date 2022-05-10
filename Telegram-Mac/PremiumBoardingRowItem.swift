//
//  PremiumBoardingRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 10.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation


final class PremiumBoardingRowItem : GeneralRowItem {
    fileprivate let value : PremiumValue
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, value: PremiumValue) {
        self.value = value
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return PremiumBoardingRowView.self
    }
}


private final class PremiumBoardingRowView: GeneralContainableRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
