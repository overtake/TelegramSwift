//
//  TableUtils.swift
//  Telegram
//
//  Created by keepcoder on 28/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import TGUIKit
import TelegramCore
import SyncCore

protocol TableItemListNodeEntry: Comparable, Identifiable {
    associatedtype ItemGenerationArguments
    
    func item(_ arguments: ItemGenerationArguments, initialSize: NSSize) -> TableRowItem
}

protocol ItemListItemTag {
    func isEqual(to other: ItemListItemTag) -> Bool
}

