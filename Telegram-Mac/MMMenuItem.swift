//
//  MMMenuItem.swift
//  Telegram
//
//  Created by keepcoder on 28/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

class MMMenuItem: NSMenuItem {
    override var title: String {
        get {
            if let identifier = identifier?.rawValue {
                return _NSLocalizedString("\(identifier).title")
            }
            return super.title
        }
        set {
            super.title = newValue
        }
    }
}


class MMMenu : NSMenu {
    override var title: String {
       
        get {
            if let identifier = identifier?.rawValue {
                return _NSLocalizedString("\(identifier).title")
            }
            return super.title
        }
        set {
            super.title = newValue
        }
        
    }
}
