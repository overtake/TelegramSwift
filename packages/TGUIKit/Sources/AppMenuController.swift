//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 06.12.2021.
//

import Foundation
import SwiftSignalKit
import AppKit

private extension Window {
    var view: MenuView {
        return self.contentView!.subviews.first! as! MenuView
    }
}

final class MenuView: View, TableViewDelegate {
    let tableView: TableView = TableView(frame: .zero)
    private let backgroundView = View()
    private let visualView = NSVisualEffectView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(visualView)
        addSubview(backgroundView)
        addSubview(tableView)
        self.visualView.wantsLayer = true
        self.visualView.state = .active
        self.visualView.blendingMode = .behindWindow
        self.tableView.delegate = self
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 4
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowOffset = NSMakeSize(0, 0)
        self.shadow = shadow
        
        self.layer?.cornerRadius = 10
        self.visualView.layer?.cornerRadius = 10
        self.backgroundView.layer?.cornerRadius = 10

        self.backgroundColor = NSColor.black.withAlphaComponent(0.001)
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
    
    func makeSize(presentation: AppMenu.Presentation) {
        
        var max: CGFloat = 0
        tableView.enumerateItems(with: { item in
            if let item = item as? AppMenuBasicItem {
                if max < item.effectiveSize.width {
                    max = item.effectiveSize.width
                }
            }
            return true
        })
        
        guard let screen = NSScreen.main else {
            return
        }
        
        self.setFrameSize(max, min(tableView.listHeight, min(600, screen.visibleFrame.height - 200)))
        if presentation.colors.isDark {
            visualView.material = .dark
        } else {
            visualView.material = .light
        }
        
        backgroundView.backgroundColor = presentation.backgroundColor
    }
    
    func item(for id: AnyHashable) -> TableRowItem? {
        return self.tableView.item(stableId: id)
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        
    }
    func selectionWillChange(row:Int, item:TableRowItem, byClick:Bool) -> Bool {
        return true
    }
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return true
    }
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    func longSelect(row:Int, item:TableRowItem) -> Void {
        
    }
    
    var submenuId: Int64?
    weak var parentView: Window?
}

final class AppMenuController : NSObject  {
    var items:[ContextMenuItem] = []
    var parent: Window?
    let presentation: AppMenu.Presentation
    private let betterInside: Bool
    
    private var keyDisposable: Disposable?
 
    var onClose:()->Void = {}
    var onShow:()->Void = {}
    
    struct Key : Hashable {
        let submenuId: Int64?
    }
    
    private weak var weakHolder: AppMenu?
    private var strongHolder: AppMenu?
    
    private let overlay = OverlayControl()

    private var windows:[Key : Window] = [:]

    init(_ items: [ContextMenuItem], presentation: AppMenu.Presentation, holder: AppMenu, betterInside: Bool) {
        self.items = items
        self.weakHolder = holder
        self.presentation = presentation
        self.betterInside = betterInside
    }
    
    func initialize() {
        var isInteracted: Bool = false
        self.parent?.set(mouseHandler: { event in
            isInteracted = true
            return .invoked
        }, with: self, for: .leftMouseDown, priority: .supreme)
        
        self.parent?.set(mouseHandler: { [weak self] event in
            if isInteracted {
                self?.close()
            }
            isInteracted = true
            return .invoked
        }, with: self, for: .leftMouseUp, priority: .supreme)

        self.parent?.set(mouseHandler: { event in
            isInteracted = true
            return .invoked
        }, with: self, for: .rightMouseDown, priority: .supreme)

        self.parent?.set(mouseHandler: { [weak self] event in
            if isInteracted {
                self?.close()
            }
            isInteracted = true
            return .invoked
        }, with: self, for: .rightMouseUp, priority: .supreme)
        
        self.parent?.set(mouseHandler: { event in
            return .invoked
        }, with: self, for: .mouseMoved, priority: .supreme)
        
        self.parent?.set(mouseHandler: { event in
            return .invoked
        }, with: self, for: .mouseExited, priority: .supreme)

        self.parent?.set(mouseHandler: { event in
            return .invoked
        }, with: self, for: .mouseEntered, priority: .supreme)


        self.parent?.set(mouseHandler: { event in
            return .invoked
        }, with: self, for: .leftMouseDragged, priority: .supreme)

        self.parent?.set(handler: { [weak self] event in
            self?.close()
            return .invoked
        }, with: self, for: .All, priority: .supreme)
        

        self.parent?.set(handler: { [weak self] _ in
            self?.close()
            return .invoked
        }, with: self, for: .Escape, priority: .supreme)
    }
    
    private var isClosed = false
    func close() {
        if !isClosed {
            for (_, panel) in self.windows {
                panel.view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak panel] _ in
                    if let panel = panel {
                        panel.parent?.removeChildWindow(panel)
                    }
                })
            }
            self.windows.removeAll()
            self.parent?.removeAllHandlers(for: self)
            self.strongHolder = nil
            self.overlay.removeFromSuperview()
            self.onClose()
        }
        self.isClosed = true
    }
    

    
    private func getView(for items: [ContextMenuItem], parentView: Window?, submenuId: Int64?) -> Window {
        
        let panel = Window(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        panel._canBecomeMain = false
        panel._canBecomeKey = false
        panel.level = parent?.level ?? .normal
        panel.backgroundColor = .clear


        let view = MenuView(frame: .zero)
        view.submenuId = submenuId
        view.parentView = parentView
        
        
        view.tableView.beginUpdates()
        view.tableView.removeAll()
        
        let presentation = self.presentation
        
        let interaction = AppMenuBasicItem.Interaction(action: { [weak self] item in
            if let handler = item.handler {
                handler()
                self?.close()
            }
        }, presentSubmenu: { [weak self, weak panel] item in
            let submenu = item.submenu?.items.compactMap { $0 as? ContextMenuItem } ?? []
            if !submenu.isEmpty, let parentView = panel {
                self?.presentSubmenu(submenu, parentView: parentView, for: item.id)
            }
            for value in items {
                if value.id != item.id {
                    self?.cancelSubmenu(value)
                }
            }
            
        }, cancelSubmenu: { [weak self] item in
            self?.cancelSubmenu(item)
        })
        
        var items:[TableRowItem] = items.compactMap { item in
            return item.rowItem(presentation: presentation, interaction: interaction)
        }
        
        var copy = items
        for (i, item) in items.enumerated() {
            let isSeparator = item is AppMenuSeparatorItem
            if isSeparator, i == 0 {
                copy.removeFirst()
            } else if isSeparator, i == items.count - 1 {
                copy.removeFirst()
            }
            if i > 0 && i != items.count - 1 {
                let prev = items[i - 1] is AppMenuSeparatorItem
                if prev && isSeparator {
                    copy.remove(at: i)
                }
            }
        }
        items = copy
        
        _ = view.tableView.addItem(item: AppMenuBasicItem(.zero))
        for item in items {
            _ = item.makeSize(300, oldWidth: 0)
            _ = view.tableView.addItem(item: item)
        }
        _ = view.tableView.addItem(item: AppMenuBasicItem(.zero))

        view.tableView.endUpdates()
        
        view.makeSize(presentation: presentation)
        
        view.tableView.needUpdateVisibleAfterScroll = true
        view.tableView.getBackgroundColor = {
            .clear
        }
        panel.setFrame(view.frame.insetBy(dx: -10, dy: -10), display: false)
        panel.contentView?.addSubview(view)
        view.center()
        
        self.windows[.init(submenuId: submenuId)] = panel
        
        return panel
        
    }
    
    private func findSubmenu(_ id: Int64) -> Window? {
        return self.windows.first(where: {
            $0.value.view.submenuId == id
        })?.value
    }
    
    private func cancelSubmenu(_ item: ContextMenuItem) {
        let submenu = findSubmenu(item.id)
        self.windows.removeValue(forKey: .init(submenuId: item.id))
        if let submenu = submenu {
            submenu.view.parentView?.view.tableView.cancelSelection()
            submenu.view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak submenu] _ in
                if let submenu = submenu {
                    submenu.parent?.removeChildWindow(submenu)
                }
            })
        }
    }
    
    private func presentSubmenu(_ items: [ContextMenuItem], parentView: Window, for id: Int64) {
        
        guard findSubmenu(id) == nil else {
            return
        }
        
        let view = getView(for: items, parentView: parentView, submenuId: id)
        guard let parentItem = parentView.view.item(for: id), let parentItemView = parentItem.view else {
            return
        }
        _ = parentView.view.tableView.select(item: parentItem)
        
        var point = parentItemView.convert(NSMakePoint(parentItemView.frame.width - 5, -parentItemView.frame.height), to: nil)
        point = parentView.convertToScreen(CGRect(origin: point, size: .zero)).origin
        
        point.y -= view.frame.height
        point.x -= 10
        
        let rect = adjust(CGRect(origin: point, size: view.frame.size), parent: parentView)
        
        view.setFrame(rect, display: true)
        parent?.addChildWindow(view, ordered: .above)
        
        view.view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
    }
    
    
    func activate(event: NSEvent, view: NSView, animated: Bool) {
        guard let window = event.window else {
            return
        }
        
        let view = getView(for: self.items, parentView: nil, submenuId: nil)
        
        var rect = window.convertToScreen(CGRect(origin: event.locationInWindow, size: view.frame.size))
        rect.origin = rect.origin.offsetBy(dx: -8, dy: -rect.height + 10)
        rect = adjust(rect)
        
        view.setFrame(rect, display: true)
        parent?.addChildWindow(view, ordered: .above)
                
        var anchor = view.view.convert(view.mouseLocationOutsideOfEventStream, to: nil)
        anchor.y = rect.height - anchor.y
        
        view.view.layer?.animateScaleSpringFrom(anchor: anchor, from: 0.1, to: 1, duration: 0.35)
        
        overlay.frame = window.bounds
        window.contentView?.addSubview(overlay)
    }
    
    private func adjust(_ rect: NSRect, parent: Window? = nil) -> NSRect {
        guard let screen = NSScreen.main, let owner = self.parent else {
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
                rect.origin.x = parent.frame.maxX - 10
            } else {
                rect.origin.x = visible.minX + 10
            }
        } else if rect.maxX > visible.maxX {
            if let parent = parent {
                rect.origin.x = parent.frame.minX - rect.width + 20 + 5
            } else {
                rect.origin.x = visible.maxX - rect.width
            }
        }


        
        return rect
    }
    
    func present(event: NSEvent, view: NSView) {
        self.parent = event.window as? Window
        self.strongHolder = self.weakHolder
        self.weakHolder = nil
        self.initialize()
        self.activate(event: event, view: view, animated: true)
        self.onShow()
        
        var skippedFirst: Bool = false
        
        self.keyDisposable = self.parent?.keyWindowUpdater.start(next: { [weak self] value in
            if !value && skippedFirst {
                self?.close()
            }
            skippedFirst = true
        })
    }
}
