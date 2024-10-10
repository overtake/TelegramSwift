//
//  PresentationTheme.swift
//  Telegram
//
//  Created by keepcoder on 22/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import ColorPalette

private var _theme:Atomic<PresentationTheme> = Atomic(value: defaultPresentation)

private let defaultPresentation = PresentationTheme(colors: whitePalette, search: SearchTheme(.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(), {localizedString("SearchField.Search")}, .text, .grayText), inputTheme: .init(quote: .init(foreground: .init(main: NSColor.accent), icon: NSImage(named: "Icon_Quote")!, collapse: NSImage(named: "Icon_Quote_Collapse")!, expand: NSImage(named: "Icon_Quote_Expand")!), indicatorColor: NSColor.accent, backgroundColor: NSColor.grayBackground, selectingColor: NSColor.selectText, textColor: NSColor.textColor, accentColor: NSColor.accent, grayTextColor: NSColor.grayText, fontSize: 13))



public var presentation:PresentationTheme {
    return _theme.modify {$0}
}

public func updateTheme(_ theme:PresentationTheme) {
    assertOnMainThread()
    _ = _theme.swap(theme)
}

open class PresentationTheme : Equatable {
    
    public let colors:ColorPalette
    public let search: SearchTheme
    public let inputTheme: InputViewTheme
    
    public let resourceCache = PresentationsResourceCache()
    
    public init(colors: ColorPalette, search: SearchTheme, inputTheme: InputViewTheme) {
        self.colors = colors
        self.search = search
        self.inputTheme = inputTheme
    }
    
    public static var current: PresentationTheme {
        return presentation
    }
    
    public static func ==(lhs: PresentationTheme, rhs: PresentationTheme) -> Bool {
        return lhs === rhs
    }
}


public extension PresentationTheme {
    var appearance: NSAppearance {
        return colors.appearance
    }
}
