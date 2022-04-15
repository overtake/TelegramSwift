//
//  Avatar_BgListView.swift
//  Telegram
//
//  Created by Mike Renoir on 15.04.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class Avatar_BgListView : View {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = .random
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
