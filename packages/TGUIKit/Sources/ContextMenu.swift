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
    
    public override func rowItem(presentation: AppMenu.Presentation, interaction interactions: AppMenuBasicItem.Interaction) -> TableRowItem {
        return AppMenuSeparatorItem(.zero, presentation: presentation)
    }
}

open class ContextMenuItem : NSMenuItem {
    private var _id: Int64?
    open var id: Int64 {
        if _id == nil {
            _id = arc4random64()
        }
        return _id!
    }

    public enum KeyEquiavalent: String {
        case none = ""
        case cmds = "⌘S"
        case cmdc = "⌘C"
        case cmde = "⌘E"
        case cmdr = "⌘R"
    }
    
    open func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return AppMenuRowItem.init(.zero, item: self, interaction: interaction, presentation: presentation)
    }

    open func stickClass() -> AnyClass? {
        return nil
    }
    
    public var handler:(()->Void)?
    private let dynamicTitle:(()->String)?
    
    public var contextObject: Any? = nil
    
    public let itemImage: ((NSColor, ContextMenuItem)->AppMenuItemImageDrawable)?
    public let itemMode: AppMenu.ItemMode
    
    public let keyEquivalentValue: KeyEquiavalent
    
    public init(_ title:String, handler: (()->Void)? = nil, image:NSImage? = nil, dynamicTitle:(()->String)? = nil, state: NSControl.StateValue? = nil, itemMode: AppMenu.ItemMode = .normal, itemImage: ((NSColor, ContextMenuItem)->AppMenuItemImageDrawable)? = nil, keyEquivalent: KeyEquiavalent = .none) {
        self.handler = handler
        self.dynamicTitle = dynamicTitle
        self.itemMode = itemMode
        self.itemImage = itemImage
        self.keyEquivalentValue = keyEquivalent
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
        handler?()
    }
    
}

public final class ContextMenu : NSMenu, NSMenuDelegate {

    let presentation: AppMenu.Presentation
    let betterInside: Bool
    let maxHeight: CGFloat
    let isLegacy: Bool
    public internal(set) var isShown: Bool = false
    public init(presentation: AppMenu.Presentation = .current(PresentationTheme.current.colors), betterInside: Bool = false, maxHeight: CGFloat = 600, isLegacy: Bool = false) {
        self.presentation = presentation
        self.betterInside = betterInside
        self.maxHeight = maxHeight
        self.isLegacy = isLegacy
        super.init(title: "")
    }
    
    public var loadMore: (()->Void)? = nil

    @objc dynamic internal var _items:[NSMenuItem] = [] {
        didSet {
            self.removeAllItems()
            for item in _items {
                super.addItem(item)
            }
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func addItem(_ newItem: NSMenuItem) {
        _items.append(newItem)
    }
    
    public override var items: [NSMenuItem] {
        get {
            return _items
        }
        set {
            _items = newValue
        }
    }
    
    public var contextItems: [ContextMenuItem] {
        return self.items.compactMap {
            $0 as? ContextMenuItem
        }
    }
    
    public var onShow:(ContextMenu)->Void = {(ContextMenu) in}
    public var onClose:()->Void = {() in}
        
    
    public static func show(items:[ContextMenuItem], view:NSView, event:NSEvent, onShow:@escaping(ContextMenu)->Void = {_ in}, onClose:@escaping()->Void = {}, presentation: AppMenu.Presentation = .current(PresentationTheme.current.colors), isLegacy: Bool = false) -> Void {
        
        let menu = ContextMenu(presentation: presentation, isLegacy: isLegacy)
        menu.onShow = onShow
        menu.onClose = onClose
        
        for item in items {
            menu.addItem(item)
        }
        let app = AppMenu(menu: menu)
        app.show(event: event, view: view)
    }
    
    
    public override class func popUpContextMenu(_ menu: NSMenu, with event: NSEvent, for view: NSView) {
        show(items: menu.items.compactMap {
            $0 as? ContextMenuItem
        }, view: view, event: event)
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





