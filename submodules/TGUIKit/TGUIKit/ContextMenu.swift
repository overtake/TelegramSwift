//
//  ContextMenu.swift
//  TGUIKit
//
//  Created by keepcoder on 03/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa


public class ContextSeparatorItem : ContextMenuItem {
    public init() {
        super.init("", handler: {}, image: nil)
    }
    
    public override var isSeparatorItem: Bool {
        return true
    }
    
    required public init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class ContextMenuItem : NSMenuItem {
    
    let handler:()->Void
    private let dynamicTitle:(()->String)?
    public init(_ title:String, handler:@escaping()->Void = {}, image:NSImage? = nil, dynamicTitle:(()->String)? = nil, state: NSControl.StateValue? = nil) {
        self.handler = handler
        self.dynamicTitle = dynamicTitle
        super.init(title: title, action: nil, keyEquivalent: "")
        
        self.title = title
        self.action = #selector(click)
        self.target = self
        self.isEnabled = true
        self.image = image
        if let state = state {
            self.state = state
        }
    }
    
    public override var title: String {
        get {
            return self.dynamicTitle?() ?? super.title
        }
        set {
            super.title = newValue
        }
    }
    
    required public init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func click() -> Void {
        handler()
    }
    
}

public final class ContextMenu : NSMenu, NSMenuDelegate {

    var onShow:(ContextMenu)->Void = {(ContextMenu) in}
    var onClose:()->Void = {() in}
    
    weak var view:NSView?
    
    public static func show(items:[ContextMenuItem], view:NSView, event:NSEvent, onShow:@escaping(ContextMenu)->Void = {_ in}, onClose:@escaping()->Void = {}) -> Void {
        
        let menu = ContextMenu.init()
        menu.onShow = onShow
        menu.onClose = onClose
        menu.view = view
        
        for item in items {
            menu.addItem(item)
        }
        
        menu.delegate = menu
        
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
    
    
    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        onShow(self)
    }
    
    public func menuDidClose(_ menu: NSMenu) {
        onClose()
    }
    
}





