//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 06.12.2021.
//

import Foundation
import SwiftSignalKit
import AppKit
import KeyboardKey

private final class TopBubbleView : View {
    private let backgroundView: View
    private let visualView: NSVisualEffectView

    required init(frame frameRect: NSRect, presentation: AppMenu.Presentation) {
        self.backgroundView = View(frame: frameRect.size.bounds)
        self.visualView = NSVisualEffectView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        if #available(macOS 11.0, *) {
            addSubview(visualView)
        }
        addSubview(backgroundView)
        self.visualView.wantsLayer = true
        self.visualView.state = .active
        self.visualView.blendingMode = .behindWindow
        self.visualView.autoresizingMask = []
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 2
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowOffset = NSMakeSize(0, 0)
        self.shadow = shadow
        
        
        if presentation.colors.isDark {
            visualView.material = .dark
        } else {
            visualView.material = .light
        }
        if #available(macOS 11.0, *) {
            backgroundView.backgroundColor = presentation.backgroundColor
        } else {
            backgroundView.backgroundColor = presentation.backgroundColor.withAlphaComponent(1.0)
        }
        
        layer?.cornerRadius = frameRect.height / 2
        backgroundView.layer?.cornerRadius = frameRect.height / 2
        visualView.layer?.cornerRadius = frameRect.height / 2
    }
    
    override func layout() {
        super.layout()
        backgroundView.frame = bounds
        visualView.frame = bounds
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

private extension Window {
    var view: MenuView {
        return self.contentView!.subviews.first! as! MenuView
    }
    var weakView: MenuView? {
        return self.contentView?.subviews.first as? MenuView
    }
}

final class MenuView: Control, TableViewDelegate {
    
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    
    struct Entry : Identifiable, Comparable, Equatable {
        static func < (lhs: MenuView.Entry, rhs: MenuView.Entry) -> Bool {
            return lhs.index < rhs.index
        }
        static func == (lhs: MenuView.Entry, rhs: MenuView.Entry) -> Bool {
            return lhs.stableId == rhs.stableId && lhs.index == rhs.index
        }
        let item: ContextMenuItem?
        let index: Int
        var stableId: AnyHashable {
            return item?.id ?? Int64(index)
        }
        
        func makeItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
            if let item = item {
                return item.rowItem(presentation: presentation, interaction: interaction)
            } else {
                return AppMenuBasicItem(.zero, presentation: presentation, menuItem: nil, interaction: interaction)
            }
        }
    }
    
    weak var controller: AppMenuController?
    
    
    let tableView: TableView = TableView(frame: .zero)
    private var contextItems: [Entry] = []
    private let backgroundView: View
    private let visualView: NSVisualEffectView
    required init(frame frameRect: NSRect) {
        self.backgroundView = View(frame: frameRect.size.bounds)
        self.visualView = NSVisualEffectView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        if #available(macOS 11.0, *) {
            addSubview(visualView)
        }
        
        tableView.verticalScroller = nil
        
        addSubview(backgroundView)
        addSubview(tableView)
        self.visualView.wantsLayer = true
        self.visualView.state = .active
        self.visualView.blendingMode = .behindWindow
        self.tableView.delegate = self
        self.visualView.autoresizingMask = []
        self.autoresizesSubviews = false
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 8
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowOffset = NSMakeSize(0, 0)
        self.shadow = shadow
        
        self.layer?.isOpaque = false
        self.layer?.shouldRasterize = true
        self.layer?.rasterizationScale = System.backingScale
        
        self.layer?.cornerRadius = 10
        self.visualView.layer?.cornerRadius = 10
        self.backgroundView.layer?.cornerRadius = 10
        self.tableView.layer?.cornerRadius = 10
        self.backgroundColor = NSColor.black.withAlphaComponent(0.001)
    }
    
    override var canBecomeKeyView: Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        visualView.frame = bounds
        backgroundView.frame = bounds
        tableView.frame = bounds
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    func makeSize(presentation: AppMenu.Presentation, screen: NSScreen, maxHeight: CGFloat? = nil, appearMode: AppMenu.AppearMode) {
        
        var max: CGFloat = 100
        tableView.enumerateItems(with: { item in
            if let item = item as? AppMenuBasicItem {
                if max < item.effectiveSize.width {
                    max = item.effectiveSize.width
                }
            }
            return true
        })
        
        self.setFrameSize(max, min(tableView.listHeight, min(maxHeight ?? appearMode.max, screen.visibleFrame.height - 200)))
        if presentation.colors.isDark {
            visualView.material = .dark
        } else {
            visualView.material = .light
        }
        effectiveSize = max
        
        if #available(macOS 11.0, *) {
            backgroundView.backgroundColor = presentation.backgroundColor
        } else {
            backgroundView.backgroundColor = presentation.backgroundColor.withAlphaComponent(1.0)
        }
        
    }
    
    func insertItems(_ items:[ContextMenuItem], presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) {
        let items:[TableRowItem] = items.compactMap { item in
            return item.rowItem(presentation: presentation, interaction: interaction)
        }
        for item in items {
            _ = item.makeSize(effectiveSize ?? 300, oldWidth: 0)
            _ = tableView.addItem(item: item)
        }
    }
    private var observation:NSKeyValueObservation?
    
    private func purify(_ items:[ContextMenuItem]) -> [ContextMenuItem] {
        var copy = items
        for (i, item) in items.enumerated() {
            let isSeparator = item is ContextSeparatorItem
            if isSeparator, i == 0 {
                copy.removeFirst()
            } else if isSeparator, i == items.count - 1 {
                copy.removeLast()
            }
            if i > 0 && i != items.count - 1 {
                let prev = items[i - 1] is ContextSeparatorItem
                if prev && isSeparator {
                    copy.remove(at: i)
                }
            }
        }
        return copy
    }
    
    func merge(menu: ContextMenu, presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) {
        self.observation = menu.observe(\._items, options: [.new], changeHandler: { [weak self] menu, value in
            let new = value.newValue?.compactMap { $0 as? ContextMenuItem } ?? []
            self?.apply(current: new, presentation: presentation, interaction: interaction)
        })
        self.apply(current: menu.contextItems, presentation: presentation, interaction: interaction)
    }
    
    private var effectiveSize: CGFloat? = nil
    
    private func apply(current: [ContextMenuItem], presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) {
        let items = purify(current)
        
        var entries:[Entry] = []
       
        var index: Int = 0
        entries.append(Entry(item: nil, index: -1))
        
        for item in items {
            entries.append(Entry(item: item, index: index))
            index += 1
        }
        entries.append(Entry(item: nil, index: .max))

        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.contextItems, rightList: entries)

        tableView.beginTableUpdates()
        
        for deleteIndex in deleteIndices.reversed() {
            self.tableView.remove(at: deleteIndex)
        }
        for indicesAndItem in indicesAndItems {
            let item = indicesAndItem.1.makeItem(presentation: presentation, interaction: interaction)
            _ = item.makeSize(effectiveSize ?? 300, oldWidth: 0)
            _ = self.tableView.insert(item: item, at: indicesAndItem.0)
        }
        for updateIndex in updateIndices {
            let item = updateIndex.1.makeItem(presentation: presentation, interaction: interaction)
            _ = item.makeSize(effectiveSize ?? 300, oldWidth: 0)
            self.tableView.replace(item: item, at: updateIndex.0, animated: false)
        }
        self.contextItems = entries
        tableView.endTableUpdates()

    }
    
    deinit {
        self.observation?.invalidate()
    }
    
    func item(for id: AnyHashable) -> TableRowItem? {
        return self.tableView.item(stableId: id)
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        
    }
    func selectionWillChange(row:Int, item:TableRowItem, byClick:Bool) -> Bool {
        if let item = item as? AppMenuBasicItem {
            return item.menuItem != nil
        }
        return false
    }
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        if let item = item as? AppMenuBasicItem {
            return item.menuItem != nil
        }
        return false
    }
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    func longSelect(row:Int, item:TableRowItem) -> Void {
        
    }
    
    func updateScroll() {
        if let item = tableView.selectedItem() {
            self.tableView.scroll(to: .top(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: -2))
        }
    }
    
    var submenuId: Int64?
    weak var parentView: Window?
    weak var childView: Window?
    var dismissed: Bool = false
}

final class AppMenuController : NSObject  {
    let menu:ContextMenu
    var parent: Window?
    let presentation: AppMenu.Presentation
    private let betterInside: Bool
    private let appearMode: AppMenu.AppearMode
    
    private var keyDisposable: Disposable?
    private let search = MetaDisposable()
    var onClose:()->Void = {}
    var onShow:()->Void = {}
    
    struct Key : Hashable {
        let submenuId: Int64?
        let timestamp: TimeInterval
    }
    
    private var query: String = ""
    
    private weak var weakHolder: AppMenu?
    private var strongHolder: AppMenu?
    
    private let overlay = OverlayControl()

    private var windows:[Key : Window] = [:]
    
    private var previousCopyHandler: (()->Void)? = nil

    private weak var parentView: NSView?
    private let delayDisposable = MetaDisposable()
    
    
    init(_ menu: ContextMenu, presentation: AppMenu.Presentation, holder: AppMenu, betterInside: Bool, appearMode: AppMenu.AppearMode, parentView: NSView?) {
        self.menu = menu
        self.weakHolder = holder
        self.presentation = presentation
        self.betterInside = betterInside// || appearMode == .hover
        self.appearMode = appearMode
        self.parentView = parentView
        self.strongHolder = holder
    }
    
    func initialize() {
        var isInteracted: Bool = false
        switch self.appearMode {
        case .click:
            self.parent?.set(mouseHandler: { event in
                isInteracted = true
                return .rejected
            }, with: self, for: .leftMouseDown, priority: .modal)
            
            self.parent?.set(mouseHandler: { [weak self] event in
                if isInteracted {
                    self?.closeAll()
                }
                let was = isInteracted
                isInteracted = true
                return !was ? .rejected : .invoked
            }, with: self, for: .leftMouseUp, priority: .modal)

            self.parent?.set(mouseHandler: { event in
                isInteracted = true
                return .rejected
            }, with: self, for: .rightMouseDown, priority: .modal)

            self.parent?.set(mouseHandler: { [weak self] event in
                if isInteracted {
                    self?.closeAll()
                }
                let was = isInteracted
                isInteracted = true
                return !was ? .rejected : .invoked
            }, with: self, for: .rightMouseUp, priority: .modal)
            

        case .hover:
            break
        }
       
        self.parent?.set(mouseHandler: { [weak self] event in
            self?.checkEvent(event)
            return .invoked
        }, with: self, for: .mouseMoved, priority: .supreme)
        
        self.parent?.set(mouseHandler: { [weak self] event in
            self?.checkEvent(event)
            return .invoked
        }, with: self, for: .mouseExited, priority: .supreme)

        self.parent?.set(mouseHandler: { [weak self] event in
            self?.checkEvent(event)
            return .invoked
        }, with: self, for: .mouseEntered, priority: .supreme)



        self.parent?.set(handler: { [weak self] event in
            self?.addStackEvent(event)
            return .invoked
        }, with: self, for: .All, priority: .modal)
        

        self.parent?.set(handler: { [weak self] _ in
            self?.closeAll()
            return .invoked
        }, with: self, for: .Escape, priority: .supreme)
        

    }
    
    private func checkEvent(_ event: NSEvent) {
        
        switch appearMode {
        case .hover:
            if let window = event.window {
                if let parentView = parentView, let superview = parentView.superview {
                    let s_v_rect = window.convertToScreen(superview.convert(parentView.frame, to: nil))
                    let s_m_point = window.convertToScreen(CGRect(origin: event.locationInWindow, size: .zero)).origin
                    let mouseInMenu = self.activeMenu?.mouseInside() == true
                    if NSPointInRect(s_m_point, s_v_rect) || mouseInMenu {
                        delayDisposable.set(nil)
                    } else {
                        delayDisposable.set(delaySignal(0.1).start(completed: { [weak self] in
                            self?.closeAll()
                        }))
                    }
                }
            }
            
        case .click:
            break
        }
        
    }
    
    private func invokeKeyEquivalent(_ keyEquivalent: ContextMenuItem.KeyEquiavalent) {
        guard let activeMenu = self.activeMenu else {
            return
        }
        var found: AppMenuBasicItem?
        activeMenu.tableView.enumerateItems(with: { item in
            if let item = item as? AppMenuBasicItem, let contextItem = item.menuItem {
                if contextItem.keyEquivalentValue == keyEquivalent {
                    found = item
                }
            }
            return true
        })
        if let found = found, let item = found.menuItem {
            _ = activeMenu.tableView.select(item: found)
            delay(0.02, closure: {
                found.interaction?.action(item)
            })
        }
    }
    
    private var activeMenu: MenuView? {
        return self.windows.sorted(by: { $0.key.timestamp > $1.key.timestamp }).first?.value.view
    }
    
    private func addStackEvent(_ event: NSEvent) {
        let chars = event.characters
        if let chars = chars?.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), !chars.isEmpty {
            
            if event.modifierFlags.contains(.command) {
                if event.keyCode == KeyboardKey.S.rawValue {
                    invokeKeyEquivalent(.cmds)
                    return
                }
                if event.keyCode == KeyboardKey.C.rawValue {
                    invokeKeyEquivalent(.cmdc)
                    return
                }
                if event.keyCode == KeyboardKey.R.rawValue {
                    invokeKeyEquivalent(.cmdr)
                    return
                }
                if event.keyCode == KeyboardKey.E.rawValue {
                    invokeKeyEquivalent(.cmde)
                    return
                }
            }
            self.query += chars
            let signal = delaySignal(0.3)
            search.set(signal.start(completed: { [weak self] in
                self?.query = ""
            }))
            
            searchItem(self.query)
        } else {
            if event.keyCode == KeyboardKey.Return.rawValue || event.keyCode == KeyboardKey.KeypadEnter.rawValue {
                if let item = self.activeMenu?.tableView.selectedItem() as? AppMenuRowItem {
                    if let _ = item.item.submenu {
                        item.interaction?.presentSubmenu(item.item)
                        if let view = findSubmenu(item.item.id)?.view {
                            view.tableView.selectNext()
                            view.updateScroll()
                        }
                    } else {
                        item.interaction?.action(item.item)
                    }
                }
            } else if event.keyCode == KeyboardKey.UpArrow.rawValue {
                if let activeMenu = self.activeMenu {
                    activeMenu.tableView.selectPrev()
                    activeMenu.updateScroll()
                }
            } else if event.keyCode == KeyboardKey.DownArrow.rawValue {
                if let activeMenu = self.activeMenu {
                    activeMenu.tableView.selectNext()
                    activeMenu.updateScroll()
                }
            }
        }
    }
    
    private func searchItem(_ query: String) {
        guard let current = self.activeMenu else {
            return
        }
        var found: AppMenuBasicItem?
        current.tableView.enumerateItems(with: { item in
            if let item = item as? AppMenuBasicItem {
                
                let searchText = item.searchable.lowercased().unicodeScalars
                    .filter { value in
                        if #available(macOS 10.12.2, *) {
                            if !value.properties.isEmojiPresentation {
                                return true
                            } else {
                                return false
                            }
                        } else {
                            return true
                        }
                    }
                    .reduce("") { $0 + String($1) }
                    .trimmed
                                
                if searchText.hasPrefix(query.lowercased()) {
                    found = item
                    return false
                }
            }
            return true
        })
        if let found = found {
            _ = current.tableView.select(item: found)
            current.updateScroll()
        }
        self.foundItem = found
    }
    
    private var foundItem: TableRowItem? = nil
    
    private var isClosed = false
    func close() {
        
        let duration: Double = 0.2
        if !isClosed {
            for (_, panel) in self.windows {
                var panel: Window? = panel
                panel?.view.layer?.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { _ in
                    panel?.orderOut(nil)
                    panel = nil
                })
            }
            
            self.onClose()
            
            self.windows.removeAll()
            self.parent?.removeAllHandlers(for: self)
            self.strongHolder = nil
            self.overlay.removeFromSuperview()
            self.parent?.copyhandler = self.previousCopyHandler

            if let window = self.menu.topWindow, let view = window.contentView {
                view.layer?.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { [weak view, weak window] completed in
                    if completed {
                        view?.removeFromSuperview()
                    }
                    window?.orderOut(nil)
                })
            }
            
        }
        self.menu.isShown = false
        self.isClosed = true
    }
    

    
    private func getView(for menu: ContextMenu, screen: NSScreen, parentView: Window?, submenuId: Int64?) -> Window {
        let panel = Window(contentRect: .zero, styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
        panel._canBecomeMain = false
        panel._canBecomeKey = false
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        
        
        let contentView = View()
        panel.contentView = contentView
        
        contentView.backgroundColor = .clear
        contentView.flip = false
        contentView.layer?.isOpaque = false


        let view = MenuView(frame: .zero)
        view.submenuId = submenuId
        view.parentView = parentView
        
                
        let presentation = self.presentation
        
        let interaction = AppMenuBasicItem.Interaction(action: { [weak self] item in
            if let handler = item.handler {
                handler()
                self?.closeAll()
            }
        }, presentSubmenu: { [weak self, weak panel, weak menu] item in
            if let submenu = item.submenu as? ContextMenu, let parentView = panel, self?.findSubmenu(item.id) == nil {
                self?.presentSubmenu(submenu, parentView: parentView, for: item.id)
            }
            if let menu = menu {
                for value in menu.contextItems {
                    if value.id != item.id {
                        self?.cancelSubmenu(value.id, true)

                    }
                }
            }
        }, cancelSubmenu: { [weak self] item in
            self?.cancelSubmenu(item.id)
        }, hover: { item in
            item.hover?()
        }, close: { [weak self] in
            self?.closeAll()
        })
        
        
        view.merge(menu: menu, presentation: presentation, interaction: interaction)
        
        view.controller = self
        
        view.makeSize(presentation: presentation, screen: screen, maxHeight: self.menu.maxHeight, appearMode: appearMode)
        
        view.tableView.needUpdateVisibleAfterScroll = true
        view.tableView.getBackgroundColor = {
            .clear
        }
        
        view.tableView.verticalScrollElasticity = .none

        
        panel.setFrame(view.frame.insetBy(dx: -20, dy: -20), display: false)
        panel.contentView?.addSubview(view)
        
        
        panel.set(mouseHandler: { [weak view, weak self] _ in
            if view?.mouseInside() == false {
                self?.closeAll()
            }
            return .rejected
        }, with: self, for: .leftMouseDown)
        
        panel.set(mouseHandler: { [weak self] _ in
            if let windows = self?.windows {
                
                if let _ = self?.foundItem, let menu = self?.activeMenu {
                    if menu.mouseInside() {
                        menu.tableView.cancelSelection()
                        self?.foundItem = nil
                    }
                }
                
                for (_, window) in windows {
                    window.view.tableView.enumerateViews(with: { view in
                        view.updateMouse(animated: true)
                        return true
                    })
                }
            }
            return .rejected
        }, with: self, for: .mouseMoved)
        
        view.center()
        
        self.windows[.init(submenuId: submenuId, timestamp: Date().timeIntervalSince1970)] = panel
        
        view.tableView.setScrollHandler { [weak menu] position in
            switch position.direction {
            case .bottom:
                menu?.loadMore?()
            default:
                break
            }
        }
        
        return panel
        
    }
    
    private func findSubmenu(_ id: Int64) -> Window? {
        return self.windows.first(where: {
            $0.value.view.submenuId == id
        })?.value
    }
    
    private func cancelSubmenuNow(_ submenu: Window) {
        self.windows = self.windows.filter({
            $0.key.submenuId != submenu.view.submenuId
        })
        submenu.view.parentView?.view.tableView.cancelSelection()
        
        submenu.view.parentView?.view.childView = nil
        submenu.view.parentView = nil
        
        submenu.view.dismissed = true
        
        submenu.view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak submenu] _ in
            if let submenu = submenu {
                submenu.orderOut(nil)
            }
        })
        
        if let childView = submenu.view.childView {
            cancelSubmenuNow(childView)
        }
    }
    
    private func cancelSubmenu(_ itemId: Int64, _ force: Bool = false) {
        delay(0.1, closure: { [weak self] in
            guard let `self` = self else {
                return
            }
            let submenu = self.findSubmenu(itemId)
            let tableItem = submenu?.view.parentView?.view.tableView.item(stableId: AnyHashable(itemId))
            let insideItem = tableItem?.view?.mouseInside() ?? false
            
            if let submenu = submenu, (!submenu.view.mouseInside() && !insideItem) {
                if let child = submenu.view.childView {
                    self.cancelSubmenuNow(child)
                } else {
                    self.cancelSubmenuNow(submenu)
                }
            }
        })
        
    }
    
    private func presentSubmenu(_ menu: ContextMenu, parentView: Window, for id: Int64) {
        guard self.findSubmenu(id) == nil, let screen = self.parent?.screen else {
            return
        }
        
        if let active = self.activeMenu, active.submenuId != nil {
            if active.parentView == parentView, let window = active._window {
                self.cancelSubmenuNow(window)
                parentView.view.childView = nil
            }
        }
        if parentView.view.childView != nil {
            return
        }
        if parentView.view.dismissed {
            return
        }
        
        let view = self.getView(for: menu, screen: screen, parentView: parentView, submenuId: id)
        guard let parentItem = parentView.view.item(for: id), let parentItemView = parentItem.view else {
            return
        }
        _ = parentView.view.tableView.select(item: parentItem)
        
        parentView.view.childView = view

        
        var point = parentItemView.convert(NSMakePoint(parentItemView.frame.width - 5, -parentItemView.frame.height), to: nil)
        point = parentView.convertToScreen(CGRect(origin: point, size: .zero)).origin
        
        point.y -= view.frame.height
        point.x -= 20
        
        let rect = self.adjust(CGRect(origin: point, size: view.frame.size), parent: parentView)
        
        view.setFrame(rect, display: true)
        view.makeKeyAndOrderFront(nil)
        
        view.view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
    }
    
    
    func activate(event: NSEvent, view: NSView, animated: Bool) {
        guard let window = event.window as? Window, let screen = window.screen else {
            return
        }
        
        let view = getView(for: self.menu, screen: screen, parentView: nil, submenuId: nil)
        
        var rect: NSRect
        switch self.appearMode {
        case .hover:
            if let parentView = parentView, let superview = parentView.superview {
                let v_rect = window.convertToScreen(superview.convert(parentView.frame, to: nil))
                rect = CGRect(origin: NSMakePoint(v_rect.minX, v_rect.minY - 5), size: view.frame.size)
            } else {
                rect = window.convertToScreen(CGRect(origin: event.locationInWindow, size: view.frame.size))
            }
        case .click:
            rect = window.convertToScreen(CGRect(origin: event.locationInWindow, size: view.frame.size))
        }
        
        rect.origin = rect.origin.offsetBy(dx: -18, dy: -rect.height + 20)
        
        if menu.bottomAnchor {
            rect.origin.y += (rect.height - 40)
        }
        
        rect = adjust(rect)
        
        view.setFrame(rect, display: true)
        view.makeKeyAndOrderFront(nil)
                
        var anchor = view.view.convert(view.mouseLocationOutsideOfEventStream, to: nil)
        anchor.y = rect.height - anchor.y
        
        anchor.x -= 20
        anchor.y -= 20
        
        
        switch appearMode {
        case .click:
            view.view.layer?.animateScaleSpringFrom(anchor: anchor, from: 0.1, to: 1, duration: 0.2, bounce: false)
            overlay.frame = window.bounds
            window.contentView?.addSubview(overlay)
        default:
            break
        }
        view.view.layer?.animateAlpha(from: 0.1, to: 1, duration: 0.2)

        window.copyhandler = { [weak self] in
            self?.invokeKeyEquivalent(.cmdc)
        }
        self.menu.isShown = true
        
        if let window = menu.topWindow {
            
            let width = window.frame.width
            let rect = NSMakeRect(rect.maxX - width + 40, rect.maxY - 25, width, window.frame.height)
            window.setFrame(rect, display: true)
            window.makeKeyAndOrderFront(nil)
            
            let view = window.contentView!.subviews.first!
            
            view.frame = NSMakeRect(rect.focus(view.frame.size).minX, 0, view.frame.width, view.frame.height)
            
            window.contentView?.layer?.animateAlpha(from: 0.1, to: 1, duration: 0.2)
            window.contentView?.layer?.animateScaleSpringFrom(anchor: NSMakePoint(anchor.x, rect.height / 2), from: 0.1, to: 1, duration: 0.2, bounce: false)
            
            window.set(mouseHandler: { [weak self] event in
                if self?.menu.closeOutside == true {
                    self?.closeAll()
                }
                return .rejected
            }, with: self, for: .leftMouseUp, priority: .supreme)
            
        }
    }
    
    private func adjust(_ rect: NSRect, parent: Window? = nil) -> NSRect {
        guard let owner = self.parent, let screen = owner.screen else {
            return rect
        }
        var rect = rect
        
        let visible = parent != nil || !self.betterInside ? screen.visibleFrame : owner.frame
        
        if rect.minY < visible.minY {
            rect.origin.y = visible.minY
        } else if rect.maxY > visible.maxY {
            rect.origin.y = visible.maxY
        }
        
        if rect.minX < visible.minX {
            if let parent = parent {
                rect.origin.x = parent.frame.maxX - 40
            } else {
                rect.origin.x = visible.minX + 40
            }
        } else if rect.maxX > visible.maxX {
            if let parent = parent {
                rect.origin.x = parent.frame.minX - rect.width + 40 + 5
            } else {
                rect.origin.x = rect.minX - rect.width + 40
            }
        }

        return rect
    }
    
    func present(event: NSEvent, view: NSView) {
        
        self.parent = event.window as? Window
        self.weakHolder = nil
        self.initialize()
        self.activate(event: event, view: view, animated: true)
        self.onShow()
        self.previousCopyHandler = self.parent?.masterCopyhandler
        var skippedFirst: Bool = false
        
        self.keyDisposable = self.parent?.keyWindowUpdater.start(next: { [weak self] value in
            if !value && skippedFirst {
                let isKey = NSApp.mainWindow != nil
                if !isKey {
                    self?.closeAll()
                }
            }
            skippedFirst = true
        })
    }
    
    private func closeAll() {
        for window in NSApp.windows {
            if let window = window as? Window, let view = window.weakView {
                view.controller?.close()
            }
        }
    }
    static func closeAll() {
        for window in NSApp.windows {
            if let window = window as? Window, let view = window.weakView {
                view.controller?.close()
            }
        }
    }
    
    deinit {
        self.delayDisposable.dispose()
        self.keyDisposable?.dispose()
    }
}


public func contextMenuOnScreen(filterNames: [String] = [])->Bool {
    for window in NSApp.windows {
        if let window = window as? Window, let weakView = window.weakView {
            if let name = weakView.controller?.menu.name, filterNames.contains(name) {
                return false
            }
            return true
        }
    }
    return false
}


public func contextOnScreen()->Window? {
    for window in NSApp.windows {
        if let window = window as? Window, let _ = window.weakView {
            return window
        }
    }
    return nil
}

public extension Window {
    var isContextMenu: Bool {
        return self.weakView != nil
    }
}
