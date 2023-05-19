//
//  Auth_NextView.swift
//  Telegram
//
//  Created by Mike Renoir on 15.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class Auth_NextView: TitleButton {
    
    private var locked: Bool = false
    private var string: String = strings().loginNext
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.scaleOnClick = true
        self.set(font: .medium(.title), for: .Normal)
        self.style = ControlStyle(font: .medium(15.0), foregroundColor: theme.colors.underSelectedColor, backgroundColor: locked ? theme.colors.grayText : theme.colors.accent)
        self.set(text: string, for: .Normal)
        self.sizeToFit(NSMakeSize(30, 0), NSMakeSize(0, Auth_Insets.nextHeight), thatFit: true)
        self.layer?.cornerRadius = self.frame.height / 2
    }
    
    func updateLocked(_ locked: Bool, string: String = strings().loginNext) {
        self.locked = locked
        self.string = string
        userInteractionEnabled = !locked
        updateLocalizationAndTheme(theme: theme)
       // self.isEnabled = !locked
    }
}
