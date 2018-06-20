//
//  PassportSettingsHeader.swift
//  Telegram
//
//  Created by keepcoder on 12/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class PassportSettingsHeaderItem: GeneralRowItem {

    init(_ initialSize: NSSize, stableId: AnyHashable) {
        super.init(initialSize, height: theme.icons.passportSettings.backingSize.height, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return PassportSettingsHeaderItemView.self
    }
}

private final class PassportSettingsHeaderItemView : TableRowView {
    private let imageView: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        imageView.image = theme.icons.passportSettings
        imageView.sizeToFit()
        imageView.center()
    }
    
    
}
