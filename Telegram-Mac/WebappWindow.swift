//
//  WebappWindow.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox

private final class Webapp : Window {
    fileprivate let controller: WebpageModalController
    init(controller: WebpageModalController) {
        self.controller = controller
        super.init(contentRect: .zero, styleMask: [.fullSizeContentView, .utilityWindow, .borderless], backing: .buffered, defer: true)
        self.contentView?.autoresizesSubviews = false
        self.contentView?.addSubview(controller.view)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 10
        self.isMovableByWindowBackground = true
    }
    
    func show() {
        guard let screen = NSScreen.main else {
            return
        }
        
        self.controller.measure(size: screen.frame.size)
        self.setFrame(screen.frame.focus(controller.view.frame.size), display: true)
        self.makeKeyAndOrderFront(nil)
        
        self.controller.view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        self.controller.view.layer?.animateScaleSpring(from: 0.8, to: 1.0, duration: 0.2)
    }
    
    deinit {
        
    }
}



final class WebappWindow {
    fileprivate let window: Webapp
    private init(controller: WebpageModalController) {
        self.window = Webapp(controller: controller)
        
        controller._window = window
    }
    
    static func makeAndOrderFront(_ controller: WebpageModalController) {
        
        var found: WebpageModalController?
        enumerateWebpages { current in
            if controller.bot?.id == current.bot?.id {
                found = current
                return true
            }
            return false
        }
        
        if let found {
            found.window?.makeKeyAndOrderFront(nil)
            return
        }
        
        let w = WebappWindow(controller: controller)
        
        let ready = controller.ready.get() |> deliverOnMainQueue |> take(1)
        _ = ready.startStandalone(next: { [weak w] ready in
            w?.window.show()
        })
    }
    
    static func enumerateWebpages(_ f:(WebpageModalController)->Bool) {
        let windows = NSApp.windows.compactMap { $0 as? Webapp }
        
        for window in windows {
            if f(window.controller) {
                break
            }
        }
    }
    
    static func focus(botId: PeerId) -> Bool {
        var found: WebpageModalController?
        enumerateWebpages { current in
            if current.bot?.id == botId {
                found = current
                return true
            }
            return false
        }
        
        if let found {
            found.window?.makeKeyAndOrderFront(nil)
            return true
        }
        
        return false
    }
    
}
