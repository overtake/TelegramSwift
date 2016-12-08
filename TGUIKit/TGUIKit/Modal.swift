//
//  Modal.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
open class ModalViewController : ViewController {
    
    open var closable:Bool {
        return true
    }
    
    open var background:NSColor {
        return .blackTransparent
    }
    
    open var containerBackground: NSColor {
        return .white
    }
    
    open var dynamicSize:Bool {
        return false
    }
    
    open func measure(size:NSSize) {
        
    }

    open var modalInteractions:ModalInteractions? {
        return nil
    }
    
    open override var responderPriority: HandlerPriority {
        return .modal
    }
    
    open override func firstResponder() -> NSResponder? {
        return self.view
    }
    
    open func close() {
        modal?.close()
    }
}

private class ModalBackground : Control {
    fileprivate override func scrollWheel(with event: NSEvent) {
        
    }
}

public class ModalInteractions {
    let accept:(()->Void)?
    let cancel:(()->Void)?
    let acceptTitle:String
    let cancelTitle:String?
    public init(acceptTitle:String, accept:(()->Void)? = nil, cancelTitle:String? = nil, cancel:(()->Void)? = nil)  {
        self.accept = accept
        self.cancel = cancel
        self.acceptTitle = acceptTitle
        self.cancelTitle = cancelTitle
    }
    
}

private class ModalInteractionsContainer : View {
    let acceptView:TitleButton
    let cancelView:TitleButton?
    let modal:Modal
    let interactions:ModalInteractions
    init(interactions:ModalInteractions, modal:Modal) {
        self.modal = modal
        self.interactions = interactions
        acceptView = TitleButton()
        acceptView.style = ControlStyle(font:.medium(.text),foregroundColor:.blueUI)
        acceptView.set(text: interactions.acceptTitle, for: .Normal)
        acceptView.sizeToFit()
        if let cancelTitle = interactions.cancelTitle {
            cancelView = TitleButton()
            cancelView?.style = ControlStyle(font:.medium(.text),foregroundColor:.blueUI)
            cancelView?.set(text: cancelTitle, for: .Normal)
            cancelView?.sizeToFit()
            
        } else {
            cancelView = nil
        }
        
        super.init()
        
        if let cancel = interactions.cancel {
            cancelView?.set(handler: cancel, for: .Click)
        } else {
            cancelView?.set(handler: {
                modal.close()
            }, for: .Click)
        }
        
        if let accept = interactions.accept {
            acceptView.set(handler: {
                accept()
                modal.close()
            }, for: .Click)
        } else {
            acceptView.set(handler: {
                modal.close()
            }, for: .Click)

        }
        
        addSubview(acceptView)
        if let cancelView = cancelView {
            addSubview(cancelView)
        }

    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    fileprivate override func layout() {
        super.layout()
        
        acceptView.centerY(x:frame.width - acceptView.frame.width - 30)
        if let cancelView = cancelView {
            cancelView.centerY(x:acceptView.frame.minX - cancelView.frame.width - 30)
        }
        
    }
    
    
}

public class Modal: NSObject {
    
    private var background:ModalBackground
    private var controller:ModalViewController?
    private var container:View!
    private var window:Window
    private let disposable:MetaDisposable = MetaDisposable()
    private var interactionsView:ModalInteractionsContainer?

    public init(controller:ModalViewController, for window:Window) {
        self.controller = controller
        self.window = window
        background = ModalBackground()
        background.backgroundColor = controller.background
        background.layer?.disableActions()
        
        super.init()

        
        
        if let interactions = controller.modalInteractions {
            interactionsView = ModalInteractionsContainer(interactions: interactions, modal:self)
            interactionsView?.frame = NSMakeRect(0, controller.bounds.height, controller.bounds.width, 60.0)
        }
       
        
        container = View(frame: containerRect)
        container.layer?.cornerRadius = .cornerRadius
        container.backgroundColor = controller.containerBackground
        container.addSubview(controller.view)
        
        if let interactionsView = interactionsView {
            container.addSubview(interactionsView)
        }
        
        background.addSubview(container)
        
        window.set(escape: {[weak self] () -> KeyHandlerResult in
            self?.close()
            return .invoked
        }, with: self, priority: .high)
        
        background.set(handler: { [weak self] in
            self?.close()
        }, for: .Click)
        
        if controller.dynamicSize {
            background.customHandler.size = {[weak self] (size) in
                if let strongSelf = self {
                    controller.measure(size: size)
                    strongSelf.container.setFrameSize(strongSelf.containerRect.size)
                    strongSelf.container.center()
                }
            }
        }
        
    }
    
    private var containerRect:NSRect {
        if let controller = controller {
            var containerRect = controller.bounds
            if let interactions = controller.modalInteractions {
                containerRect.size.height += 60.0
            }
            return containerRect
        }
       return NSZeroRect
    }
    
    public func close(_ callAcceptInteraction:Bool = false) ->Void {
        
        window.remove(object: self, for: .Escape)
        controller?.viewWillDisappear(true)
        
        if callAcceptInteraction, let interactionsView = interactionsView {
            interactionsView.interactions.accept?()
        }
        
        background.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: {[weak self] (complete) in
            if let stongSelf = self {
                stongSelf.background.removeFromSuperview()
                stongSelf.controller?.viewDidDisappear(true)
                stongSelf.controller?.modal = nil
                stongSelf.controller = nil
            }
        })
       
    }
    
    deinit {
        disposable.dispose()
    }
    
    func show() -> Void {
       // if let view
        if let controller = controller {
            disposable.set((controller.ready.get() |> take(1)).start(next: {[weak self] (ready) in
                if let strongSelf = self, let view = self?.window.contentView?.subviews.first {
                    strongSelf.controller?.viewWillAppear(true)
                    strongSelf.background.frame = view.bounds
                    strongSelf.container.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.3)
                    strongSelf.background.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, completion:{[weak strongSelf] (completed) in
                        strongSelf?.controller?.viewDidAppear(true)
                    })
                    strongSelf.background.autoresizingMask = [.viewWidthSizable,.viewHeightSizable]
                    strongSelf.container.center()
                    strongSelf.container.autoresizingMask = [.viewMinXMargin,.viewMaxXMargin,.viewMinYMargin,.viewMaxYMargin]
                    view.addSubview(strongSelf.background)
                    
                }
            }))
        }

    }
    
}

public func showModal(with controller:ModalViewController, for window:Window) -> Void {
    assert(controller.modal == nil)
    
    controller.modal = Modal(controller: controller, for: window)
    controller.modal?.show()
}


