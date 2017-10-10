//
//  StickerPreviewHandler.swift
//  Telegram
//
//  Created by keepcoder on 02/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac


extension GridNode : StickerPreviewProtocol {
    func stickerAtLocationInWindow(_ point: NSPoint) -> TelegramMediaFile? {
        let point = self.documentView!.convert(point, from: nil)
        var file:TelegramMediaFile? = nil
        self.forEachItemNode { node in
            if NSPointInRect(point, node.frame) {
                if let c = node as? StickerPreviewRowViewProtocol {
                    file = c.fileAtPoint(node.convert(point, from: nil))
                    return
                }
            }
        }
        return file
    }
}

extension TableView : StickerPreviewProtocol {
    func stickerAtLocationInWindow(_ point: NSPoint) -> TelegramMediaFile? {
        let index = self.row(at: documentView!.convert(point, from: nil))
        if index != -1 {
            let item = self.item(at: index)
            if let view = self.viewNecessary(at: item.index), let c = view as? StickerPreviewRowViewProtocol {
                return c.fileAtPoint(view.convert(point, from: nil))
            }
        }
       
        return nil
    }
}

protocol StickerPreviewRowViewProtocol {
    func fileAtPoint(_ point:NSPoint) -> TelegramMediaFile?
}

protocol StickerPreviewProtocol {
    func stickerAtLocationInWindow(_ point:NSPoint) -> TelegramMediaFile?
}

fileprivate var handler:StickerPreviewHandler?

func startStickerPreviewHandle(_ global:StickerPreviewProtocol, window:Window, account:Account) {
    handler = StickerPreviewHandler(global, window: window, account: account)
    handler?.startHandler()
}

class StickerPreviewHandler : NSObject {
    private let global:StickerPreviewProtocol
    private let account:Account
    private let window:Window
    private let modal:StickerPreviewModalController
    init(_ global:StickerPreviewProtocol, window:Window, account:Account) {
        self.global = global
        self.window = window
        self.account = account
        self.modal = StickerPreviewModalController(account)
    }
    
    func startHandler() {
        
        modal.update(with: global.stickerAtLocationInWindow(window.mouseLocationOutsideOfEventStream))
        showModal(with: modal, for: window)
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let strongSelf = self, let file = strongSelf.global.stickerAtLocationInWindow(strongSelf.window.mouseLocationOutsideOfEventStream) {
                strongSelf.modal.update(with: file)
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
