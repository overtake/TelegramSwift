//
//  ETabRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class ETabRowItem: TableRowItem {
    
    let icon:CGImage
    let iconSelected:CGImage
    
    let clickHandler:(AnyHashable)->Void
    
    override func viewClass() -> AnyClass {
        return ETabRowView.self
    }
    
    let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    let _height:CGFloat
    override var height: CGFloat {
        return _height
    }
    
    init(_ initialSize:NSSize, icon:CGImage, iconSelected:CGImage, stableId:AnyHashable, width:CGFloat, clickHandler:@escaping(AnyHashable)->Void) {
        self.icon = icon
        self.iconSelected = iconSelected
        self.clickHandler = clickHandler
        self._height = width
        self._stableId = stableId
        super.init(initialSize)
    }
    
}
