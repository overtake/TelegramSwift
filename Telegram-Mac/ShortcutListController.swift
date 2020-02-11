//
//  ShortcutListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

private func shortcutEntires() -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    return entries
}

func ShortcutListController(context: AccountContext) -> ViewController {
    
    let controller = InputDataController(dataSignal: .single(InputDataSignalValue(entries: shortcutEntires())), title: "Shortcuts", validateData: { data in
        return .fail(.none)
    }, removeAfterDisappear: true, hasDone: false, identifier: "shortcuts")
    
    controller._abolishWhenNavigationSame = true
    
    return controller
}
