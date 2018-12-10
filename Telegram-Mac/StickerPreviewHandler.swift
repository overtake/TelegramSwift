//
//  ModalPreviewHandler.swift
//  Telegram
//
//  Created by keepcoder on 02/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac


extension GridNode : ModalPreviewProtocol {
    func fileAtLocationInWindow(_ point: NSPoint) -> FileMediaReference? {
        let point = self.documentView!.convert(point, from: nil)
        var reference: FileMediaReference? = nil
        self.forEachItemNode { node in
            if NSPointInRect(point, node.frame) {
                if let c = node as? ModalPreviewRowViewProtocol {
                    reference = c.fileAtPoint(node.convert(point, from: nil))
                    return
                }
            }
        }
        return reference
    }
}

extension TableView : ModalPreviewProtocol {
    func fileAtLocationInWindow(_ point: NSPoint) -> FileMediaReference? {
        let index = self.row(at: documentView!.convert(point, from: nil))
        if index != -1 {
            let item = self.item(at: index)
            if let view = self.viewNecessary(at: item.index), let c = view as? ModalPreviewRowViewProtocol {
                return c.fileAtPoint(view.convert(point, from: nil))
            }
        }
       
        return nil
    }
}

protocol ModalPreviewRowViewProtocol {
    func fileAtPoint(_ point:NSPoint) -> FileMediaReference?
}

protocol ModalPreviewProtocol {
    func fileAtLocationInWindow(_ point:NSPoint) -> FileMediaReference?
    
}

protocol ModalPreviewControllerView : class {
    func update(with reference: FileMediaReference, account:Account)
}

fileprivate var handler:ModalPreviewHandler?



func startModalPreviewHandle(_ global:ModalPreviewProtocol, viewType: ModalPreviewControllerView.Type, window:Window, account:Account) {
    handler = ModalPreviewHandler(global, viewType: viewType, window: window, account: account)
    handler?.startHandler()
}

class ModalPreviewHandler : NSObject {
    private let global:ModalPreviewProtocol
    private let account:Account
    private let window:Window
    private let modal:PreviewModalController
    init(_ global:ModalPreviewProtocol, viewType: ModalPreviewControllerView.Type, window:Window, account:Account) {
        self.global = global
        self.window = window
        self.account = account
        self.modal = PreviewModalController(account, viewType: viewType)
    }
    
    func startHandler() {
        
        modal.update(with: global.fileAtLocationInWindow(window.mouseLocationOutsideOfEventStream))
        showModal(with: modal, for: window)
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let strongSelf = self, let reference = strongSelf.global.fileAtLocationInWindow(strongSelf.window.mouseLocationOutsideOfEventStream) {
                strongSelf.modal.update(with: reference)
            }
            return .invokeNext
            }, with: self, for: .leftMouseDragged, priority: .modal)
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            self?.stopHandler()
            return .invokeNext
        }, with: self, for: .leftMouseUp, priority: .modal)
    }
    
    func stopHandler() {
        window.remove(object: self, for: .leftMouseDragged)
        window.remove(object: self, for: .leftMouseUp)
        modal.close()
        handler = nil
    }
    
    deinit {
        stopHandler()
    }
    
}


class PreviewModalController: ModalViewController {
    fileprivate let account:Account
    fileprivate var reference:FileMediaReference?
    private let viewType: ModalPreviewControllerView.Type
    init(_ account:Account, viewType: ModalPreviewControllerView.Type) {
        self.viewType = viewType
        self.account = account
        
        super.init(frame: NSMakeRect(0, 0, 360, 400))
        bar = .init(height: 0)
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override var handleEvents:Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let reference = reference {
            genericView.update(with: reference, account: account)
        }
        readyOnce()
    }
    
    func update(with reference:FileMediaReference?) {
        if self.reference?.media != reference?.media {
            self.reference = reference
            if isLoaded(), let reference = reference {
                genericView.update(with: reference, account: account)
            }
        }
    }
    
    fileprivate var genericView:ModalPreviewControllerView {
        return view as! ModalPreviewControllerView
    }
    
    override func viewClass() -> AnyClass {
        return viewType
    }
    
    //    override var isFullScreen: Bool {
    //        return true
    //    }
    
}
