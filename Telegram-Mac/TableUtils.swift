//
//  TableUtils.swift
//  Telegram
//
//  Created by keepcoder on 28/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import TGUIKit
import TelegramCoreMac

protocol TableItemListNodeEntry: Comparable, Identifiable {
    associatedtype ItemGenerationArguments
    
    func item(_ arguments: ItemGenerationArguments, initialSize: NSSize) -> TableRowItem
}

