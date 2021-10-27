//
//  SyncCoreExtension.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.11.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import TGUIKit

extension PixelDimensions {
    var size: CGSize {
        return CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }
    init(_ size: CGSize) {
        self.init(width: Int32(abs(size.width)), height: Int32(abs(size.height)))
    }
    init(_ width: Int32, _ height: Int32) {
        self.init(width: width, height: height)
    }
}
extension CGSize {
    var pixel: PixelDimensions {
        return PixelDimensions(self)
    }
}

enum AppLogEvents : String {
    case imageEditor = "image_editor_used"
}

extension TelegramTheme {
    var effectiveSettings: TelegramThemeSettings? {
        return self.settings?.first
    }
    func effectiveSettings(for colors: ColorPalette) -> TelegramThemeSettings? {
        if let settings = self.settings {
            for settings in settings {
                switch settings.baseTheme {
                case .classic:
                    if colors.name == dayClassicPalette.name {
                        return settings
                    }
                case .day:
                    if colors.name == whitePalette.name {
                        return settings
                    }
                case .night, .tinted:
                    if colors.name == nightAccentPalette.name {
                        return settings
                    }
                }
            }

        }
        return nil
    }
    func effectiveSettings(isDark: Bool) -> TelegramThemeSettings? {
        if let settings = self.settings {
            for settings in settings {
                switch settings.baseTheme {
                case .classic:
                    if !isDark {
                        return settings
                    }
                case .day:
                    if !isDark {
                        return settings
                    }
                case .night, .tinted:
                    if isDark {
                        return settings
                    }
                }
            }

        }
        return nil
    }

}



