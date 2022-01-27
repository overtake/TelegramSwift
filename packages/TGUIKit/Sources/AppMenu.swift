import SwiftSignalKit
import AppKit
import ColorPalette
public final class AppMenu {
    
    public enum ItemMode {
        case normal
        case destruct
    }
    public enum AppearMode {
        case click
        case hover
        var max: CGFloat {
            switch self {
            case .click:
                return 600
            case .hover:
                return 288
            }
        }
    }
    
    public struct Presentation {
        public let colors: ColorPalette
        public var textColor: NSColor {
            return colors.text
        }
        public var disabledTextColor: NSColor {
            return colors.grayText.withAlphaComponent(0.75)
        }
        public var highlightColor: NSColor {
            return colors.grayIcon.withAlphaComponent(0.15)
        }
        public var borderColor: NSColor {
            return colors.grayIcon.withAlphaComponent(0.1)
        }
        public var backgroundColor: NSColor {
            return colors.background.withAlphaComponent(0.7)
        }
        public var destructColor: NSColor {
            return colors.redUI
        }
        public var more: CGImage {
            let image = NSImage(named: "Icon_Menu_More")!
            return image.precomposed(colors.text, scale: System.backingScale)
        }
        public var selected: CGImage {
            let image = NSImage(named: "Icon_Menu_Selected")!
            return image.precomposed(colors.text, scale: System.backingScale)
        }
        public init(colors: ColorPalette) {
            self.colors = colors
        }
        public static func current(_ palette: ColorPalette) -> Presentation {
            return Presentation(colors: palette)
        }
        public func primaryColor(_ item: ContextMenuItem) -> NSColor {
            if item.isEnabled {
                switch item.itemMode {
                case .normal:
                    return self.textColor
                case .destruct:
                    return self.destructColor
                }
            } else {
                return self.disabledTextColor
            }
        }
        
        public func secondaryColor(_ item: ContextMenuItem) -> NSColor {
            return self.disabledTextColor
        }
    }
    
    private let menu: ContextMenu
    private var controller: AppMenuController?
    private let appearMode: AppearMode
    private var observation:NSKeyValueObservation?
    private var timerDisposable: Disposable?
    public init(menu: ContextMenu, appearMode: AppearMode = .click) {
        self.menu = menu
        self.appearMode = appearMode
    }
    
    deinit {
        self.observation?.invalidate()
    }
    
    public static func show(menu: ContextMenu, event: NSEvent, for view: NSView, appearMode: AppearMode = .click) {
        if !menu.isShown {
            let appMenu = AppMenu(menu: menu, appearMode: appearMode)
            appMenu.show(event: event, view: view)
        }
    }
    
    public func show(event: NSEvent, view: NSView) {
        
        
        if System.legacyMenu || self.menu.isLegacy {
            NSMenu.popUpContextMenu(self.menu, with: event, for: view)
        } else {
            let controller = AppMenuController(self.menu, presentation: menu.presentation, holder: self, betterInside: menu.betterInside, appearMode: self.appearMode, parentView: view)
            
            self.controller = controller
            self.observation?.invalidate()
            self.observation = nil
            
            controller.onShow = { [weak self, weak view] in
                if let menu = self?.menu {
                    self?.menu.onShow(menu)
                }
                (view as? Control)?.isSelected = true
            }
            controller.onClose = { [weak self, weak view] in
                self?.menu.onClose()
                (view as? Control)?.isSelected = false
            }
            
            if !self.menu.contextItems.isEmpty {
                self.presentIfNeeded(event: event, view: view)
                timerDisposable?.dispose()
            } else {
                self.observation = self.menu.observe(\._items, options: [.new], changeHandler: { [weak view, weak self] menu, value in
                    if !menu.isShown, let view = view, !menu.contextItems.isEmpty {
                        self?.presentIfNeeded(event: event, view: view)
                        self?.timerDisposable?.dispose()
                    }
                })
                self.timerDisposable = delaySignal(3.0).start(completed: { [weak self] in
                    self?.observation?.invalidate()
                    self?.controller?.close()
                })
            }
        }
        
        
    }
    private func presentIfNeeded(event: NSEvent, view: NSView) {
        self.controller?.present(event: event, view: view)
    }
}
