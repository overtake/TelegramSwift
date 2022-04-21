//
//  Auth_Insets.swift
//  Telegram
//
//  Created by Mike Renoir on 15.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import AppKit


struct Auth_Insets {
    static let betweenNextView: CGFloat = 15 + 15 + 10
    static let betweenError: CGFloat = 10
    static let betweenHeader: CGFloat = 20
    static let nextHeight: CGFloat = 36
    static let logoSize: NSSize = NSMakeSize(140, 140)
    static let qrSize: NSSize = NSMakeSize(210, 210)
    static let qrAnimSize: NSSize = NSMakeSize(186, 186)
    static let headerFont: NSFont = .medium(22)
    static let infoFont: NSFont = .normal(13.5)
    static let infoFontBold: NSFont = .medium(13.5)
}
