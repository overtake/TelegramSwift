//
//  Modal.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac


private class ModalBackground : Control {
    fileprivate override func scrollWheel(with event: NSEvent) {
        
    }
}

private var activeModals:[WeakReference<Modal>] = []

public class ModalInteractions {
    let accept:(()->Void)?
    let cancel:(()->Void)?
    let acceptTitle:String
    let cancelTitle:String?
    let drawBorder:Bool
    let height:CGFloat
    var enables:((Bool)->Void)? = nil
    
    
    var doneUpdatable:(((TitleButton)->Void)->Void)? = nil
    var cancelUpdatable:(((TitleButton)->Void)->Void)? = nil
    
    public init(acceptTitle:String, accept:(()->Void)? = nil, cancelTitle:String? = nil, cancel:(()->Void)? = nil, drawBorder:Bool = false, height:CGFloat = 50)  {
        self.drawBorder = drawBorder
        self.accept = accept
        self.cancel = cancel
        self.acceptTitle = acceptTitle
        self.cancelTitle = cancelTitle
        self.height = height
    }
    
    public func updateEnables(_ enable:Bool) -> Void {
        if let enables = enables {
            enables(enable)
        }
    }
    
    public func updateDone(_ f:@escaping (TitleButton) -> Void) -> Void {
        doneUpdatable?(f)
    }
    public func updateCancel(_ f:@escaping(TitleButton) -> Void) -> Void {
        cancelUpdatable?(f)
    }
    
}

private class ModalInteractionsContainer : View {
    let acceptView:TitleButton
    let cancelView:TitleButton?
    let interactions:ModalInteractions
    let borderView:View?
    
    override func mouseUp(with event: NSEvent) {
        
    }
    override func mouseDown(with event: NSEvent) {
        
    }
    
    init(interactions:ModalInteractions, modal:Modal) {
        self.interactions = interactions
        acceptView = TitleButton()
        acceptView.style = ControlStyle(font:.medium(.text), foregroundColor: presentation.colors.blueUI, backgroundColor: presentation.colors.background)
        acceptView.set(text: interactions.acceptTitle, for: .Normal)
        acceptView.disableActions()
        acceptView.sizeToFit()
        if let cancelTitle = interactions.cancelTitle {
            cancelView = TitleButton()
            cancelView?.style = ControlStyle(font:.medium(.text), foregroundColor: presentation.colors.blueUI, backgroundColor: presentation.colors.background)
            cancelView?.set(text: cancelTitle, for: .Normal)
            cancelView?.sizeToFit()
            
        } else {
            cancelView = nil
        }
        
        if interactions.drawBorder {
            borderView = View()
            borderView?.backgroundColor = presentation.colors.border
        } else {
            borderView = nil
        }
        
       
        
        super.init()
        self.backgroundColor = presentation.colors.background
        if let cancel = interactions.cancel {
            cancelView?.set(handler: { _ in
                cancel()
            }, for: .Click)
        } else {
            cancelView?.set(handler: { [weak modal] _ in
                modal?.close()
            }, for: .Click)
        }
        
        if let accept = interactions.accept {
            acceptView.set(handler: { _ in
                accept()
            }, for: .Click)
        } else {
            acceptView.set(handler: { [weak modal] _ in
                modal?.close()
            }, for: .Click)

        }
        
        addSubview(acceptView)
        if let cancelView = cancelView {
            addSubview(cancelView)
        }
        if let borderView = borderView {
            addSubview(borderView)
        }
        
        interactions.enables = { [weak self] enable in
            self?.acceptView.isEnabled = enable
            self?.acceptView.apply(state: .Normal)
        }
        
        interactions.doneUpdatable = { [weak self] f in
            if let strongSelf = self {
                f(strongSelf.acceptView)
            }
            self?.updateDone()
        }
        interactions.cancelUpdatable = { [weak self] f in
            if let strongSelf = self, let cancelView = strongSelf.cancelView {
                f(cancelView)
            }
            self?.updateCancel()
        }


    }
    
    public func updateDone() {
        acceptView.sizeToFit()
        needsLayout = true
    }
    
    public func updateCancel() {
        cancelView?.sizeToFit()
        needsLayout = true
    }
    public func updateThrid(_ text:String) {
        acceptView.set(text: text, for: .Normal)
        acceptView.sizeToFit()
        
        needsLayout = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    fileprivate override func layout() {
        super.layout()
        
        acceptView.centerY(x:frame.width - acceptView.frame.width - 30)
        if let cancelView = cancelView {
            cancelView.centerY(x:acceptView.frame.minX - cancelView.frame.width - 30)
        }
        borderView?.frame = NSMakeRect(0, 0, frame.width, .borderSize)
    }
    
    
    
}

private class ModalContainerView: View {
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    
    
    fileprivate override func mouseDown(with event: NSEvent) {
        
    }
    
    fileprivate override func mouseUp(with event: NSEvent) {
        
    }
}

public class Modal: NSObject {
    
    private var background:ModalBackground
    fileprivate var controller:ModalViewController?
    private var container:ModalContainerView!
    let window:Window
    private let disposable:MetaDisposable = MetaDisposable()
    private var interactionsView:ModalInteractionsContainer?
    public let interactions:ModalInteractions?
    fileprivate let animated: Bool
    private let isOverlay: Bool
    public init(controller:ModalViewController, for window:Window, animated: Bool = true, isOverlay: Bool) {
        
        self.controller = controller
        self.window = window
        self.animated = animated
        self.isOverlay = isOverlay
        background = ModalBackground()
        background.backgroundColor = controller.background
        background.layer?.disableActions()
        self.interactions = controller.modalInteractions
        super.init()

        if let interactions = interactions {
            interactionsView = ModalInteractionsContainer(interactions: interactions, modal:self)
            interactionsView?.frame = NSMakeRect(0, controller.bounds.height, controller.bounds.width, interactions.height)
        }
       
        if controller.isFullScreen {
            controller._frameRect = window.contentView!.bounds
        }
        
        container = ModalContainerView(frame: containerRect)
        container.layer?.cornerRadius = .cornerRadius
        container.layer?.shouldRasterize = true
        container.layer?.rasterizationScale = CGFloat(System.backingScale)
        container.backgroundColor = controller.containerBackground
        
        container.addSubview(controller.view)
        
        if let interactionsView = interactionsView {
            container.addSubview(interactionsView)
        }
        
        background.addSubview(container)
        
        background.userInteractionEnabled = controller.handleEvents
        
        if controller.handleEvents {
            window.set(responder: { [weak controller] () -> NSResponder? in
                return controller?.firstResponder()
                }, with: self, priority: .modal)
            
            if controller.handleAllEvents {
                window.set(handler: { () -> KeyHandlerResult in
                    return .invokeNext
                }, with: self, for: .All, priority: .modal)
            }
           
            
            window.set(escape: {[weak self] () -> KeyHandlerResult in
                if self?.controller?.escapeKeyAction() == .rejected {
                    self?.close()
                }
                return .invoked
                }, with: self, priority: .modal)
            
            window.set(handler: { [weak self] () -> KeyHandlerResult in
                if let controller = self?.controller {
                    return controller.returnKeyAction()
                }
                return .invokeNext
            }, with: self, for: .Return, priority: .modal)
        }
        
       
        
        background.set(handler: { [weak self] _ in
            if let closable = self?.controller?.closable, closable {
                self?.close()
            }
        }, for: .Click)
        
        if controller.dynamicSize {
            background.customHandler.size = { [weak self] (size) in
                self?.controller?.measure(size: size)
            }
        }
        activeModals.append(WeakReference(value: self))
    }
    
    
    public func resize(with size:NSSize, animated:Bool = true) {
        
        let focus:NSRect
        if let interactions = controller?.modalInteractions {
            focus = background.focus(NSMakeSize(size.width, size.height + interactions.height))
            interactionsView?.change(pos: NSMakePoint(0, size.height), animated: animated)
        } else {
            focus = background.focus(size)
        }
        container.change(size: focus.size, animated: animated)
        container.change(pos: focus.origin, animated: animated)
        
        controller?.view._change(size: size, animated: animated)
    }
    
    private var containerRect:NSRect {
        if let controller = controller {
            var containerRect = controller.bounds
            if let interactions = controller.modalInteractions {
                containerRect.size.height += interactions.height
            }
            return containerRect
        }
       return NSZeroRect
    }
    
    public func close(_ callAcceptInteraction:Bool = false) ->Void {
        window.removeAllHandlers(for: self)
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
        for i in stride(from: activeModals.count - 1, to: -1, by: -1) {
            if activeModals[i].value == self {
                activeModals.remove(at: i)
                break
            }
        }

    }
    
    func show() -> Void {
        // if let view
        if let controller = controller {
            disposable.set((controller.ready.get() |> take(1)).start(next: { [weak self, weak controller] ready in
                if let strongSelf = self, let view = (strongSelf.isOverlay ? strongSelf.window.contentView?.superview : strongSelf.window.contentView), let controller = controller {
                    strongSelf.controller?.viewWillAppear(true)
                    strongSelf.background.frame = view.bounds
                    strongSelf.container.center()
                    strongSelf.background.background = controller.isFullScreen ? controller.containerBackground : controller.background
                    if strongSelf.animated {
                        if !controller.isFullScreen {
                            strongSelf.container.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.3)
                        } else {
                            strongSelf.container.layer?.animateAlpha(from: 0.1, to: 1.0, duration: 0.3)
                        }
                    }
                    
                    strongSelf.background.autoresizingMask = [.width,.height]
                    strongSelf.background.customHandler.layout = { [weak strongSelf] view in
                        strongSelf?.container.center()
                    }
                    
                    if controller.isFullScreen {
                        strongSelf.background.customHandler.size = { [weak strongSelf] size in
                            strongSelf?.container.setFrameSize(size)
                        }
                    }
    
                    view.addSubview(strongSelf.background)
                    if let value = strongSelf.controller?.becomeFirstResponder(), value {
                        strongSelf.window.makeFirstResponder(strongSelf.controller?.firstResponder())
                    }
                    
                    if strongSelf.animated {
                        strongSelf.background.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, completion:{[weak strongSelf] (completed) in
                            strongSelf?.controller?.viewDidAppear(true)
                        })
                    } else {
                        strongSelf.controller?.viewDidAppear(false)
                    }                    
                }
            }))
        }
        
    }
    
}

public func hasModals() -> Bool {
    
    for i in stride(from: activeModals.count - 1, to: -1, by: -1) {
        if activeModals[i].value == nil {
            activeModals.remove(at: i)
        }
    }
    
    return !activeModals.isEmpty
}

public func closeAllModals() {
    for modal in activeModals {
        modal.value?.close()
    }
}

public func showModal(with controller:ModalViewController, for window:Window, isOverlay: Bool = false) -> Void {
    assert(controller.modal == nil)
    for weakModal in activeModals {
        if weakModal.value?.controller?.className == controller.className {
            weakModal.value?.close()
        }
    }
    
    controller.modal = Modal(controller: controller, for: window, isOverlay: isOverlay)
    controller.modal?.show()
}


