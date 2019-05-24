//
//  PasswordWindow.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class PassportWindowArguments {
    let back:()->Void
    init(back:@escaping()->Void) {
        self.back = back
    }
}


private(set) var passport: PassportWindowController? = nil


class PassportWindowController  {
    let window: Window
    let controller: PassportController
    let navigationController: NavigationViewController
    init(context: AccountContext, peer: Peer, request: inAppSecureIdRequest, form: EncryptedSecureIdForm) {
        
        
        let screen = NSScreen.main!
        let size = NSMakeSize(390, 600)
        let center = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (screen.frame.width - size.width)/2), floorToScreenPixels(scaleFactor: System.backingScale, (screen.frame.height - size.height)/2), size.width, size.height)

        
        
        window = Window(contentRect: center, styleMask: [.closable, .resizable, .miniaturizable, .fullSizeContentView, .titled, .unifiedTitleAndToolbar, .texturedBackground], backing: .buffered, defer: true)
        

        
        controller = PassportController(context, peer, request: request, form)
        navigationController = NavigationViewController(controller, window)
        
        
        window.isMovableByWindowBackground = true
        window.name = "Telegram.PassportWindow"
        //window.initSaver()
        navigationController._frameRect = NSMakeRect(0, 0, size.width, size.height - 50)
        window.titlebarAppearsTransparent = true
        window.minSize = size
        window.maxSize = size
        window.contentView = navigationController.view
        
        window.closeInterceptor = { [weak self] in
            guard let `self` = self else {return true}
            self.window.orderOut(nil)
            passport = nil
            return true
        }
        (navigationController.view as? View)?.customHandler.layout = { [weak self] _ in
            self?.windowDidNeedSaveState(Notification(name: Notification.Name(rawValue: "")))
        }
        
        windowDidNeedSaveState(Notification(name: Notification.Name(rawValue: "")))

        if let titleView = window.titleView {
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidNeedSaveState(_:)), name: NSView.frameDidChangeNotification, object: titleView)
        }
        
        navigationController.viewDidAppear(false)
        
        navigationController.doSomethingOnEmptyBack = { [weak self] in
            guard let `self` = self else {return}
            self.window.orderOut(nil)
            passport = nil
        }
        
        controller.viewDidAppear(false)
    }
    
    var barHeight: CGFloat {
        return 50
    }
    
    
    @objc func windowDidNeedSaveState(_ notification: Notification) {
        if let titleView = window.titleView {
            let frame = NSMakeRect(0, window.frame.height - barHeight, titleView.frame.width, barHeight)
            if !NSEqualRects(frame, titleView.frame) {
                titleView.frame = frame
            }
            if let controls = (HackUtils.findElements(byClass: "NSTitlebarView", in: titleView)?.first as? NSView)?.subviews {
                var xs:[CGFloat] = [18, 58, 38]
                for i in 0 ..< min(controls.count, xs.count) {
                    let view = controls[i]
                    view.isHidden = true
                    view.setFrameOrigin(xs[i], floorToScreenPixels(scaleFactor: System.backingScale, (barHeight - view.frame.height)/2))
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        window.orderOut(nil)
        if let titleView = window.titleView {
            NotificationCenter.default.removeObserver(titleView)
        }
    }
    
    func show() {
        passport = self
        window.makeKeyAndOrderFront(nil)
    }
}
