import SwiftSignalKit
import AppKit
import ColorPalette
public final class AppMenu {
    
    public struct Presentation {
        let isDark: Bool
        var textColor: NSColor {
            return PresentationTheme.current.colors.text
        }
        var disabledTextColor: NSColor {
            return PresentationTheme.current.colors.grayText
        }
        var highlightColor: NSColor {
            return PresentationTheme.current.colors.grayIcon.withAlphaComponent(0.1)
        }
        var borderColor: NSColor {
            return PresentationTheme.current.colors.grayIcon.withAlphaComponent(0.1)
        }
        var backgroundColor: NSColor {
            return PresentationTheme.current.colors.background.withAlphaComponent(0.6) 
        }
        var more: CGImage {
            let image = NSImage(named: "Icon_Menu_More")!
            
            return image.precomposed(PresentationTheme.current.colors.text)
        }
        var selected: CGImage {
            let image = NSImage(named: "Icon_Menu_Selected")!
            return image.precomposed(PresentationTheme.current.colors.text)
        }
        public init(isDark: Bool) {
            self.isDark = isDark
        }
        public static var current: Presentation {
            return Presentation(isDark: PresentationTheme.current.colors.isDark)
        }
    }
    
    private let menu: ContextMenu
    private var controller: AppMenuController?
    private let presentation: Presentation
    public init(menu: ContextMenu, presentation: Presentation = Presentation.current) {
        self.menu = menu
        self.presentation = presentation
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
    
    public func show(event: NSEvent, view: NSView) {
        let controller = AppMenuController(self.menu.contextItems, presentation: presentation)
        
        self.controller = controller
        
        controller.onShow = { [weak self] in
            if let menu = self?.menu {
                self?.menu.onShow(menu)
            }
        }
        controller.onClose = { [weak self] in
            self?.menu.onClose()
        }
        controller.present(event: event, view: view)
    }
}
