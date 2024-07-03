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
        let screen = NSScreen.main!
        
        self.controller.viewWillAppear(true)
        self.controller.measure(size: screen.frame.size)
        
        let rect = screen.frame.focus(controller.view.frame.insetBy(dx: -10, dy: -10).size)
        
        super.init(contentRect: rect, styleMask: [.fullSizeContentView, .titled, .borderless], backing: .buffered, defer: true)
        
        self.contentView?.wantsLayer = true
        self.contentView?.autoresizesSubviews = false
        
        
        
        controller.view.layer?.cornerRadius = 10
        
       
        self.contentView?.addSubview(controller.view)
        
        self.isOpaque = false
        self.hasShadow = false
        self.backgroundColor = NSColor.clear
       // self.contentView?.layer?.cornerRadius = 10
        self.isMovableByWindowBackground = true
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

    }
    
    func show() {

        let shadow = SimpleShapeLayer()
        shadow.cornerRadius = 10
        shadow.masksToBounds = false
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4).cgColor
        shadow.shadowOffset = CGSize(width: 0.0, height: 1)
        shadow.shadowRadius = 5
        shadow.shadowOpacity = 0.7
        shadow.fillColor = controller.view.background.cgColor
        shadow.path = CGPath(roundedRect: controller.view.bounds, cornerWidth: 10, cornerHeight: 10, transform: nil)
        shadow.frame = self.controller.frame
        
        self.contentView?.layer?.addSublayer(shadow)
        
        self.makeKeyAndOrderFront(nil)
        
        self.contentView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, removeOnCompletion: false)
        self.contentView?.layer?.animateScaleSpring(from: 0.8, to: 1.0, duration: 0.2)
        
        
        self.controller.viewDidAppear(true)
        
    }
    
    override func close() {
        super.close()
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
}



final class WebappWindow {
    fileprivate let window: Webapp
    private init(controller: WebpageModalController) {
        self.window = Webapp(controller: controller)
        
        controller._window = window
    }
    
    static func makeAndOrderFront(_ controller: WebpageModalController) {
        
//        var found: WebpageModalController?
//        enumerateWebpages { current in
//            if controller.bot?.id == current.bot?.id {
//                found = current
//                return true
//            }
//            return false
//        }
//        
//        if let found {
//            found.window?.makeKeyAndOrderFront(nil)
//            return
//        }
        
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
//        var found: WebpageModalController?
//        enumerateWebpages { current in
//            if current.bot?.id == botId {
//                found = current
//                return true
//            }
//            return false
//        }
//        
//        if let found {
//            found.window?.makeKeyAndOrderFront(nil)
//            return true
//        }
        
        return false
    }
    
}
