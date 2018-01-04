//
//  AlertController.swift
//  Telegram
//
//  Created by keepcoder on 07/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

private var global:AlertController? = nil

private class AlertBackgroundModalViewController : ModalViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
}
class AlertController: ViewController {

    fileprivate let alert: Window
    private let _window: NSWindow
    private let header: String
    private let text: String
    private let okTitle:String
    private let cancelTitle:String?
    private let thridTitle:String?
    private let swapColors: Bool
    init(_ window: NSWindow, header: String, text:String, okTitle: String? = nil, cancelTitle: String? = nil, thridTitle: String? = nil, swapColors: Bool = false) {
        self._window = window
        self.header = header
        self.text = text
        self.swapColors = swapColors
        self.okTitle = okTitle ?? tr(L10n.alertOK)
        self.cancelTitle = cancelTitle
        self.thridTitle = thridTitle
        alert = Window(contentRect: NSMakeRect(0, 0, 380, 130), styleMask: [], backing: .buffered, defer: true)
        alert.backgroundColor = .clear
        super.init(frame: NSMakeRect(0, 0, 380, 130))
    }
    
    override func viewClass() -> AnyClass {
        return AlertControllerView.self
    }
    
    func close(_ reason: NSApplication.ModalResponse = .abort) {
        _window.endSheet(alert, returnCode: reason)
        global = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let maxWidth = genericView.layoutButtons(okTitle: okTitle, cancelTitle: cancelTitle, thridTitle: thridTitle, swapColors: swapColors, okHandler: { [weak self] in
            self?.close(.OK)
            }, cancelHandler: { [weak self] in
                self?.close(.cancel)
            }, thridHandler: { [weak self] in
                self?.close(.alertThirdButtonReturn)
        })
        genericView.layoutTexts(with: self.header, information: text, maxWidth: maxWidth)
        alert.setFrame(NSMakeRect(0, 0, maxWidth, view.frame.height), display: true)
        view.frame = NSMakeRect(0, 0, maxWidth, view.frame.height)
        view.needsLayout = true
    }
    
    func show(completionHandler: @escaping(NSApplication.ModalResponse)->Void) {
        
        global = self
        loadViewIfNeeded()
        viewDidLoad()
        let modal = AlertBackgroundModalViewController(frame: NSZeroRect)
        if let _window = _window as? Window {
            showModal(with: modal, for: _window)
        }
        alert.setFrame(view.bounds, display: false)
        alert.contentView = self.view
        _window.beginSheet(alert) { [weak modal] response in
            global = nil
            modal?.close()
            completionHandler(response)
        }
        
        alert.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.close()
            return .invoked
        }, with: self, for: .Escape)
        
        alert.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.close()
            return .invoked
        }, with: self, for: .Space)
        
        alert.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.close(.OK)
            return .invoked
        }, with: self, for: .Return)
    }
    
    deinit {
        alert.removeAllHandlers(for: self)
    }
    
    private var genericView: AlertControllerView {
        return view as! AlertControllerView
    }
    
}
