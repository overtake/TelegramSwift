//
//  ColdStartPasslockController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03.11.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit


class ColdStartPasslockController: ModalViewController {
    private let valueDisposable = MetaDisposable()
    private let logoutDisposable = MetaDisposable()

    private let logoutImpl:() -> Signal<Never, NoError>
    private let checkNextValue: (String)->Bool
    init(checkNextValue:@escaping(String)->Bool, logoutImpl:@escaping()->Signal<Never, NoError>) {
        self.checkNextValue = checkNextValue
        self.logoutImpl = logoutImpl
        super.init(frame: NSMakeRect(0, 0, 350, 350))
        self.bar = .init(height: 0)
    }
    
    override var isVisualEffectBackground: Bool {
        return false
    }
    
    override var isFullScreen: Bool {
        return true
    }
    
    override var background: NSColor {
        return self.containerBackground
    }
    
    private var genericView:PasscodeLockView {
        return self.view as! PasscodeLockView
    }
    
   
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.logoutImpl = { [weak self] in
            guard let window = self?.window else { return }
            
            confirm(for: window, information: L10n.accountConfirmLogoutText, successHandler: { [weak self] _ in
                guard let `self` = self else { return }
                
                _ = showModalProgress(signal: self.logoutImpl(), for: window).start(completed: { [weak self] in
                    delay(0.2, closure: { [weak self] in
                        self?.close()
                    })
                })
            })
        }
        
        var locked = false
        
        valueDisposable.set((genericView.value.get() |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let `self` = self, !locked else {
                return
            }
            if !self.checkNextValue(value) {
                self.genericView.input.shake()
            } else {
                locked = true
            }
        }))
        
        genericView.update(hasTouchId: false)
        readyOnce()
        
        
    }
    
    override var closable: Bool {
        return false
    }
    
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .invoked
    }
    
    override func firstResponder() -> NSResponder? {
        if !(window?.firstResponder is NSText) {
            return genericView.input
        }
        let editor = self.window?.fieldEditor(true, for: genericView.input)
        if window?.firstResponder != editor {
            return genericView.input
        }
        return editor
        
    }
    
    override var containerBackground: NSColor {
        return theme.colors.background.withAlphaComponent(1.0)
    }
    override var handleEvents: Bool {
        return true
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    
    override var responderPriority: HandlerPriority {
        return .supreme
    }
    
    deinit {
        logoutDisposable.dispose()
        valueDisposable.dispose()
        self.window?.removeAllHandlers(for: self)
    }
    
    override func viewClass() -> AnyClass {
        return PasscodeLockView.self
    }
    
}

