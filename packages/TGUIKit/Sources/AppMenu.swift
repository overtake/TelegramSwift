import SwiftSignalKit
import AppKit
import ColorPalette
public final class AppMenu {
    
    public enum ItemMode {
        case normal
        case destruct
    }
    
    public struct Presentation {
        let colors: ColorPalette
        var textColor: NSColor {
            return colors.text
        }
        var disabledTextColor: NSColor {
            return colors.grayText
        }
        var highlightColor: NSColor {
            return colors.grayIcon.withAlphaComponent(0.15)
        }
        var borderColor: NSColor {
            return colors.grayIcon.withAlphaComponent(0.1)
        }
        var backgroundColor: NSColor {
            return colors.background.withAlphaComponent(0.7)
        }
        var destructColor: NSColor {
            return colors.redUI
        }
        var more: CGImage {
            let image = NSImage(named: "Icon_Menu_More")!
            return image.precomposed(colors.text)
        }
        var selected: CGImage {
            let image = NSImage(named: "Icon_Menu_Selected")!
            return image.precomposed(colors.text)
        }
        public init(colors: ColorPalette) {
            self.colors = colors
        }
        public static func current(_ palette: ColorPalette) -> Presentation {
            return Presentation(colors: palette)
        }
        func primaryColor(_ item: ContextMenuItem) -> NSColor {
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
    }
    
    private let menu: ContextMenu
    private var controller: AppMenuController?
    private let presentation: Presentation
    public init(menu: ContextMenu, presentation: Presentation = Presentation.current(PresentationTheme.current.colors)) {
        self.menu = menu
        self.presentation = presentation
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
    
    public static func show(menu: ContextMenu, event: NSEvent, for view: NSView) {
        let appMenu = AppMenu(menu: menu, presentation: menu.presentation)
        appMenu.show(event: event, view: view)
    }
    
    public func show(event: NSEvent, view: NSView) {
        guard !self.menu.contextItems.isEmpty else {
            return
        }
        let controller = AppMenuController(self.menu.contextItems, presentation: presentation, holder: self, betterInside: menu.betterInside)
        
        self.controller = controller
        
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
        controller.present(event: event, view: view)
        
    }
}
