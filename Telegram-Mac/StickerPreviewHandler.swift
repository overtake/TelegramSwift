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


enum QuickPreviewMedia : Equatable {
    case file(FileMediaReference, ModalPreviewControllerView.Type)
    case image(ImageMediaReference, ModalPreviewControllerView.Type)
    
    static func ==(lhs: QuickPreviewMedia, rhs: QuickPreviewMedia) -> Bool {
        switch lhs {
        case let .file(lhsReference, _):
            if case let .file(rhsReference, _) = rhs {
                return lhsReference.media.isEqual(to: rhsReference.media)
            } else {
                return false
            }
        case let .image(lhsReference, _):
            if case let .image(rhsReference, _) = rhs {
                return lhsReference.media.isEqual(to: rhsReference.media)
            } else {
                return false
            }
        }
    }
    
    var fileReference: FileMediaReference? {
        switch self {
        case let .file(reference, _):
            return reference
        default:
            return nil
        }
    }
    var imageReference: ImageMediaReference? {
        switch self {
        case let .image(reference, _):
            return reference
        default:
            return nil
        }
    }
    
    var viewType: ModalPreviewControllerView.Type {
        switch self {
        case let .file(_, type), let .image(_, type):
            return type
        }
    }
}

extension GridNode : ModalPreviewProtocol {
    func fileAtLocationInWindow(_ point: NSPoint) -> QuickPreviewMedia? {
        let point = self.documentView!.convert(point, from: nil)
        var reference: QuickPreviewMedia? = nil
        self.forEachItemNode { node in
            if NSPointInRect(point, node.frame) {
                if let c = node as? ModalPreviewRowViewProtocol {
                    reference = c.fileAtPoint(node.convert(point, from: nil))
                }
            }
        }
        return reference
    }
}

extension TableView : ModalPreviewProtocol {
    func fileAtLocationInWindow(_ point: NSPoint) -> QuickPreviewMedia? {
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
    func fileAtPoint(_ point:NSPoint) -> QuickPreviewMedia?
}

protocol ModalPreviewProtocol {
    func fileAtLocationInWindow(_ point:NSPoint) -> QuickPreviewMedia?
    
}

protocol ModalPreviewControllerView : class {
    func update(with reference: QuickPreviewMedia, context: AccountContext, animated: Bool)
}

fileprivate var handler:ModalPreviewHandler?



func startModalPreviewHandle(_ global:ModalPreviewProtocol, window:Window, context: AccountContext) {
    handler = ModalPreviewHandler(global, window: window, context: context)
    handler?.startHandler()
}

class ModalPreviewHandler : NSObject {
    private let global:ModalPreviewProtocol
    private let context:AccountContext
    private let window:Window
    private let modal:PreviewModalController
    init(_ global:ModalPreviewProtocol, window:Window, context: AccountContext) {
        self.global = global
        self.window = window
        self.context = context
        
        self.modal = PreviewModalController(context)
    }
    
    func startHandler() {
        
        modal.update(with: global.fileAtLocationInWindow(window.mouseLocationOutsideOfEventStream))
        showModal(with: modal, for: window)
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            if let strongSelf = self, let reference = strongSelf.global.fileAtLocationInWindow(strongSelf.window.mouseLocationOutsideOfEventStream) {
                strongSelf.modal.update(with: reference)
            }
            return .invoked
        }, with: self, for: .leftMouseDragged, priority: .modal)
        
        window.set(mouseHandler: { [weak self] (_) -> KeyHandlerResult in
            self?.stopHandler()
            return .invoked
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


private final class PreviewModalView: View {
    private var contentView: NSView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func layout() {
        super.layout()
    }
    
    func update(with preview: QuickPreviewMedia, context: AccountContext, animated: Bool) {
        
        let viewType = preview.viewType
        var changed = false
        if contentView == nil || !contentView!.isKind(of: viewType)  {
            if animated {
                let current = self.contentView
                current?.layer?.animateScaleSpring(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak current] completed in
                    if completed {
                        current?.removeFromSuperview()
                    }
                })
            } else {
                self.contentView?.removeFromSuperview()
            }
            
            self.contentView = (viewType as! NSView.Type).init(frame:NSZeroRect)
            self.addSubview(self.contentView!)
            changed = true
        }
        contentView?.frame = bounds
        (contentView as? ModalPreviewControllerView)?.update(with: preview, context: context, animated: animated && !changed)
        
        if animated {
            contentView?.layer?.animateScaleSpring(from: 0.5, to: 1.0, duration: 0.2)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PreviewModalController: ModalViewController {
    fileprivate let context:AccountContext
    fileprivate var reference:QuickPreviewMedia?
    init(_ context: AccountContext) {
        self.context = context
        
        super.init(frame: NSMakeRect(0, 0, min(context.window.frame.width - 60, 450), min(450, context.window.frame.height - 60)))
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
            genericView.update(with: reference, context: context, animated: false)
        }
        readyOnce()
    }
    
    func update(with reference:QuickPreviewMedia?) {
        if self.reference != reference {
            self.reference = reference
            if isLoaded(), let reference = reference {
                genericView.update(with: reference, context: context, animated: true)
            }
        }
    }
    
    fileprivate var genericView:PreviewModalView {
        return view as! PreviewModalView
    }
    
    override func viewClass() -> AnyClass {
        return PreviewModalView.self
    }
    
    //    override var isFullScreen: Bool {
    //        return true
    //    }
    
}
