//
//  Modal.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit


private class ModalBackground : Control {
    var isOverlay: Bool = false
    var canRedirectScroll: Bool = false
    fileprivate override func scrollWheel(with event: NSEvent) {
        if canRedirectScroll {
            super.scrollWheel(with: event)
        }
    }
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    
    override func mouseMoved(with event: NSEvent) {
        
    }
    
    override func mouseEntered(with event: NSEvent) {
        
    }
    override func mouseExited(with event: NSEvent) {
        
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return false
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
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
    let alignCancelLeft: Bool
    
    var doneUpdatable:(((TitleButton)->Void)->Void)? = nil
    var cancelUpdatable:(((TitleButton)->Void)->Void)? = nil
    let singleButton: Bool
    public init(acceptTitle:String, accept:(()->Void)? = nil, cancelTitle:String? = nil, cancel:(()->Void)? = nil, drawBorder:Bool = false, height:CGFloat = 50, alignCancelLeft: Bool = false, singleButton: Bool = false)  {
        self.drawBorder = drawBorder
        self.accept = accept
        self.cancel = cancel
        self.acceptTitle = acceptTitle
        self.cancelTitle = cancelTitle
        self.height = height
        self.alignCancelLeft = alignCancelLeft
        self.singleButton = singleButton
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
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        acceptView.style = ControlStyle(font:.medium(.text), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background)
        cancelView?.style = ControlStyle(font:.medium(.text), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background)
        borderView?.backgroundColor = theme.colors.border
        backgroundColor = theme.colors.background
        
        if interactions.singleButton {
            acceptView.set(background: theme.colors.background, for: .Normal)
            acceptView.set(background: theme.colors.grayForeground.withAlphaComponent(0.25), for: .Highlight)
        } else {
            acceptView.set(background: theme.colors.background, for: .Normal)
        }
    }
    
    init(interactions:ModalInteractions, modal:Modal) {
        self.interactions = interactions
        acceptView = TitleButton()
        acceptView.style = ControlStyle(font:.medium(.text), foregroundColor: presentation.colors.accent, backgroundColor: presentation.colors.background)
        acceptView.set(text: interactions.acceptTitle, for: .Normal)
        acceptView.disableActions()
        _ = acceptView.sizeToFit(NSZeroSize, NSMakeSize(0, interactions.height - 10), thatFit: true)
        if let cancelTitle = interactions.cancelTitle {
            cancelView = TitleButton()
            cancelView?.style = ControlStyle(font:.medium(.text), foregroundColor: presentation.colors.accent, backgroundColor: presentation.colors.background)
            cancelView?.set(text: cancelTitle, for: .Normal)
            _ = cancelView?.sizeToFit(NSZeroSize, NSMakeSize(0, interactions.height - 10), thatFit: true)
            
        } else {
            cancelView = nil
        }
        if interactions.singleButton {
            acceptView.set(background: presentation.colors.background, for: .Normal)
            acceptView.set(background: presentation.colors.grayForeground.withAlphaComponent(0.25), for: .Highlight)
        } else {
            acceptView.set(background: presentation.colors.background, for: .Normal)
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
                modal?.controller?.close()
            }, for: .Click)
        }
        
        if let accept = interactions.accept {
            acceptView.set(handler: { _ in
                accept()
            }, for: .Click)
        } else {
            acceptView.set(handler: { [weak modal] _ in
                modal?.controller?.close()
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
        _ = acceptView.sizeToFit(NSZeroSize, NSMakeSize(0, interactions.height - 10), thatFit: true)
        needsLayout = true
    }
    
    public func updateCancel() {
        _ = cancelView?.sizeToFit(NSZeroSize, NSMakeSize(0, interactions.height - 10), thatFit: true)
        needsLayout = true
    }
    public func updateThrid(_ text:String) {
        acceptView.set(text: text, for: .Normal)
        _ = acceptView.sizeToFit(NSZeroSize, NSMakeSize(0, interactions.height - 10), thatFit: true)
        
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
        
        if self.interactions.singleButton {
            acceptView.frame = bounds
        } else {
            acceptView.centerY(x:frame.width - acceptView.frame.width - 30)
            if let cancelView = cancelView {
                if interactions.alignCancelLeft {
                    cancelView.centerY(x: 30)
                } else {
                    cancelView.centerY(x:acceptView.frame.minX - cancelView.frame.width - 30)
                }
            }
        }
        
        
        borderView?.frame = NSMakeRect(0, 0, frame.width, .borderSize)
    }
    
    
    
}


private final class ModalHeaderView: View {
    let titleView: TextView = TextView()
    private var  subtitleView: TextView?
    var leftButton: ImageButton?
    var rightButton: ImageButton?
    weak var controller:ModalViewController?
    required init(frame frameRect: NSRect, data: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)) {
        super.init(frame: frameRect)
        
        titleView.update(TextViewLayout(.initialize(string: data.center?.title, color: presentation.colors.text, font: .medium(.title)), maximumNumberOfLines: 1))
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        border = [.Bottom]
        
        if let subtitle = data.center?.subtitle {
            subtitleView = TextView()
            subtitleView!.update(TextViewLayout(.initialize(string: subtitle, color: presentation.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1))
            subtitleView!.userInteractionEnabled = false
            subtitleView!.isSelectable = false
            addSubview(subtitleView!)
        }
        
        if let right = data.right {
            rightButton = ImageButton()
            if let image = right.image {
                rightButton?.set(image: image, for: .Normal)
            }
            rightButton?.set(handler: { _ in
                right.handler?()
            }, for: .Click)
            
            _ = rightButton?.sizeToFit()
            addSubview(rightButton!)
        }
        
        if let left = data.left {
            leftButton = ImageButton()
            if let image = left.image {
                leftButton?.set(image: image, for: .Normal)
            }
            leftButton?.set(handler: { _ in
                left.handler?()
            }, for: .Click)
            
            _ = leftButton?.sizeToFit()
            addSubview(leftButton!)
        }
        
        addSubview(titleView)
    }
    
    override func layout() {
        super.layout()
        var additionalSize: CGFloat = 0
        if let rightButton = rightButton {
            additionalSize += rightButton.frame.width * 2
            rightButton.centerY(x: frame.width - rightButton.frame.width - 20)
        }
        
        if let leftButton = leftButton {
            additionalSize += leftButton.frame.width * 2
            leftButton.centerY(x: 20)
        }
        
        titleView.layout?.measure(width: frame.width - 40 - additionalSize)
        titleView.update(titleView.layout)
        
        subtitleView?.layout?.measure(width: frame.width - 40 - additionalSize)
        subtitleView?.update(subtitleView?.layout)
        
        if let subtitleView = subtitleView {
            let center = frame.midY
            titleView.centerX(y: center - titleView.frame.height - 1)
            subtitleView.centerX(y: center + 1)
        } else {
            titleView.center()
        }
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        guard let controller = controller else {
            return
        }
        
        background = theme.colors.background
        borderColor = theme.colors.border

        let header = controller.modalHeader
        if let header = header {
            titleView.update(TextViewLayout(.initialize(string: header.center?.title, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1))
            subtitleView?.update(TextViewLayout(.initialize(string: header.center?.subtitle, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1))

            if let image = header.right?.image {
                rightButton?.set(image: image, for: .Normal)
            }
            if let image = header.left?.image {
                leftButton?.set(image: image, for: .Normal)
            }
        }
        needsLayout = true
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

private class ModalContainerView: View {
    
    
    override func mouseMoved(with event: NSEvent) {
        
    }
    
    override func mouseEntered(with event: NSEvent) {
        
    }
    override func mouseExited(with event: NSEvent) {
        
    }
    fileprivate override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    fileprivate override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
    }
}

extension Modal : ObservableViewDelegate {
    
}

public class Modal: NSObject {
    private let visualEffectView: NSVisualEffectView?
    fileprivate let background:ModalBackground
    fileprivate var controller:ModalViewController?
    private var container:ModalContainerView!
    public let window:Window
    private let disposable:MetaDisposable = MetaDisposable()
    private var interactionsView:ModalInteractionsContainer?
    private var headerView:ModalHeaderView?

    public let interactions:ModalInteractions?
    fileprivate let animated: Bool
    private let isOverlay: Bool
    private let animationType: ModalAnimationType
    private let parentView: NSView?
    public init(controller:ModalViewController, for window:Window, animated: Bool = true, isOverlay: Bool, animationType: ModalAnimationType, parentView: NSView? = nil) {
        self.parentView = parentView
        self.animationType = animationType
        self.controller = controller
        self.window = window
        self.animated = animated
        self.isOverlay = isOverlay
        background = ModalBackground()
        background.isOverlay = isOverlay
        background.canRedirectScroll = controller.redirectMouseAfterClosing
        background.backgroundColor = controller.background
        background.layer?.disableActions()
        self.interactions = controller.modalInteractions
        if controller.isVisualEffectBackground {
            self.visualEffectView = NSVisualEffectView(frame: NSZeroRect)
            self.visualEffectView!.material = .ultraDark
            self.visualEffectView!.blendingMode = .withinWindow
            self.visualEffectView!.state = .active
            self.visualEffectView?.wantsLayer = true
        } else {
            self.visualEffectView = nil
        }
        super.init()
        controller.modal = self
        if let interactions = interactions {
            interactionsView = ModalInteractionsContainer(interactions: interactions, modal:self)
            interactionsView?.frame = NSMakeRect(0, controller.bounds.height, controller.bounds.width, interactions.height)
        }
        if let header = controller.modalHeader {
            headerView = ModalHeaderView(frame: NSMakeRect(0, 0, controller.bounds.width, 50), data: header)
            headerView?.backgroundColor = controller.headerBackground
            headerView?.controller = controller
        }
       
        if controller.isFullScreen {
            controller._frameRect = topView.bounds
        }
        
        container = ModalContainerView(frame: containerRect)
        container.autoresizingMask = []
        container.autoresizesSubviews = true
        container.layer?.cornerRadius = 10
        container.layer?.shouldRasterize = true
        container.layer?.rasterizationScale = CGFloat(System.backingScale)
        container.backgroundColor = controller.containerBackground
        
        if !controller.contentBelowBackground {
            container.addSubview(controller.view)
        } else {
            controller.loadViewIfNeeded()
        }
        
        if let headerView = headerView {
            container.addSubview(headerView)
        }
        
        if let interactionsView = interactionsView {
            container.addSubview(interactionsView)
        }
        

        background.addSubview(container)
        
        background.userInteractionEnabled = controller.handleEvents
        
        if controller.handleEvents {
            window.set(responder: { [weak controller] () -> NSResponder? in
                return controller?.firstResponder()
            }, with: self, priority: controller.responderPriority)
            
            if controller.handleAllEvents {
                window.set(handler: { [weak controller] () -> KeyHandlerResult in
                    if let controller = controller, controller.redirectMouseAfterClosing {
                        controller.close()
                        return .rejected
                    }
                    return .invokeNext
                }, with: self, for: .All, priority: controller.responderPriority)
            }
            
            window.set(escape: {[weak self] () -> KeyHandlerResult in
                if self?.controller?.escapeKeyAction() == .rejected {
                    self?.controller?.close()
                }
                return .invoked
            }, with: self, priority: controller.responderPriority)
            
            window.set(handler: { [weak self] () -> KeyHandlerResult in
                if let controller = self?.controller {
                    return controller.returnKeyAction()
                }
                return .invokeNext
            }, with: self, for: .Return, priority: controller.responderPriority)
        }
        
        var isDown: Bool = false
        
        background.set(handler: { [weak self] control in
            guard let controller = self?.controller, let `self` = self else { return }
            
            if control.mouseInside() && !controller.view._mouseInside() && !self.container.mouseInside() {
                isDown = true
            }
            
            if controller.redirectMouseAfterClosing, let event = NSApp.currentEvent {
                control.performSuperMouseDown(event)
            }
        }, for: .Down)
        
        background.set(handler: { [weak self] control in
            guard let controller = self?.controller, let `self` = self else { return }
            if controller.closable, !controller.view._mouseInside() && !self.container.mouseInside(), isDown {
                controller.close()
            }
            if controller.redirectMouseAfterClosing, let event = NSApp.currentEvent {
                control.performSuperMouseUp(event)
            }
            
            isDown = false

        }, for: .Click)
        
        if controller.dynamicSize {
            background.customHandler.size = { [weak self] (size) in
                self?.controller?.measure(size: size)
            }
        }
        
        activeModals.append(WeakReference(value: self))
    }
    
    private var topView: NSView {
        if let parentView = self.parentView {
            return parentView
        } else {
            return self.window.contentView!
        }
    }
    
    public var containerView: NSView {
        return self.container
    }
    
    func observableView(_ view: NSView, didAddSubview: NSView) {
        if isOverlay {
            var subviews = self.window.contentView!.subviews
            if let index = subviews.firstIndex(of: self.background) {
                subviews.remove(at: index)
                subviews.append(self.background)
            }
            self.window.contentView?.subviews = subviews
        }
    }
    
    func observableview(_ view: NSView, willRemoveSubview: NSView) {
        
    }
    
    public func resize(with size:NSSize, animated:Bool = true) {
        let focus:NSRect
        
        var headerOffset: CGFloat = 0
        if let headerView = headerView {
            headerOffset += headerView.frame.height
            headerView.setFrameSize(size.width, headerView.frame.height)
        }
        
        if let interactions = controller?.modalInteractions {
            focus = background.focus(NSMakeSize(size.width, size.height + interactions.height + headerOffset))
            interactionsView?.change(pos: NSMakePoint(0, size.height + headerOffset), animated: animated)
            interactionsView?.setFrameSize(NSMakeSize(size.width, interactions.height))
        } else {
            focus = background.focus(NSMakeSize(size.width, size.height + headerOffset))
        }
        
        
        if focus != container.frame {
            CATransaction.begin()
            container.change(size: focus.size, animated: animated)
            container.change(pos: focus.origin, animated: animated)
            
            controller?.view._change(size: size, animated: animated)
            controller?.view._change(pos: NSMakePoint(0, headerOffset), animated: animated)
            CATransaction.commit()
        }
        controller?.didResizeView(size, animated: animated)
       
    }
    
    public func updateLocalizationAndTheme(theme: PresentationTheme) {
        self.interactionsView?.updateLocalizationAndTheme(theme: theme)
        self.headerView?.updateLocalizationAndTheme(theme: theme)
    }
    
    private var containerRect:NSRect {
        if let controller = controller {
            var containerRect = controller.bounds
            if let interactions = controller.modalInteractions {
                containerRect.size.height += interactions.height
            }
            if let headerView = headerView {
                containerRect.size.height += headerView.frame.height
            }
            return containerRect
        }
       return NSZeroRect
    }
    
    public func close(_ callAcceptInteraction:Bool = false, animationType: ModalAnimationCloseBehaviour = .common) ->Void {
        window.removeAllHandlers(for: self)
        controller?.viewWillDisappear(true)
        
        for i in stride(from: activeModals.count - 1, to: -1, by: -1) {
            if activeModals[i].value == self {
                activeModals.remove(at: i)
                break
            }
        }
        
        let animateBackground = !unhideModalIfNeeded() || self.controller?.containerBackground == .clear
        
        if callAcceptInteraction, let interactionsView = interactionsView {
            interactionsView.interactions.accept?()
        }
        let background: NSView
        if let visualEffectView = self.visualEffectView {
            background = visualEffectView
        } else {
            background = self.background
        }
        if let controller = controller, controller.contentBelowBackground {
            controller.view._change(opacity: 0, animated: true, removeOnCompletion: false, duration: 0.2, timingFunction: .spring, completion: { [weak self] _ in
                self?.controller?.view.removeFromSuperview()
            })
        }
        
        if animateBackground {
            background.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: {[weak self, weak background] complete in
                if let stongSelf = self {
                    background?.removeFromSuperview()
                    stongSelf.controller?.view.removeFromSuperview()
                    stongSelf.controller?.viewDidDisappear(true)
                    stongSelf.controller?.modal = nil
                    stongSelf.controller = nil
                }
            })
        } else if let lastActive = activeModals.last?.value {
            background.removeFromSuperview()
            self.controller?.view.removeFromSuperview()
            self.controller?.viewDidDisappear(true)
            self.controller?.modal = nil
            self.controller = nil
            lastActive.containerView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        }
       
       
        switch animationType {
        case .common:
            break
        case let .scaleToRect(newRect):
            let view = self.container!
            let oldRect = self.container.frame
            view.layer?.animatePosition(from: oldRect.origin, to: newRect.origin, duration: 0.25, timingFunction: .spring, removeOnCompletion: false)
            view.layer?.animateScaleX(from: 1, to: newRect.width / oldRect.width, duration: 0.25, timingFunction: .spring, removeOnCompletion: false)
            view.layer?.animateScaleY(from: 1, to: newRect.height / oldRect.height, duration: 0.25, timingFunction: .spring, removeOnCompletion: false)
        }
    }
    
    private var subview: NSView?
    
    public func removeSubview(animated: Bool) {
        if let subview = self.subview {
            if animated {
                subview.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak subview] _ in
                    subview?.removeFromSuperview()
                })
            } else {
                subview.removeFromSuperview()
            }
        }
        self.subview = nil
    }
    
    public func addSubview(_ view: NSView, animated: Bool) {
        if let subview = self.subview {
            if animated {
                subview.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak subview] _ in
                    subview?.removeFromSuperview()
                })
            } else {
                subview.removeFromSuperview()
            }
        }
        
        view.frame = container.bounds
        self.container.addSubview(view)
        if animated {
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        }
        self.subview = view
    }
    
    deinit {
        disposable.dispose()
        (window.contentView as? ObervableView)?.remove(listener: self)
        for i in stride(from: activeModals.count - 1, to: -1, by: -1) {
            if activeModals[i].value == self {
                activeModals.remove(at: i)
                break
            }
        }

    }
    
    static func topModalController(_ window: Window) -> ModalViewController? {
        for i in stride(from: activeModals.count - 1, to: -1, by: -1) {
            if let modal = activeModals[i].value, modal.window === window {
                return modal.controller
            }
        }
        return nil
    }
    
    public func show() -> Void {
        // if let view
        if let controller = controller {
            disposable.set((controller.ready.get() |> take(1)).start(next: { [weak self, weak controller] ready in
                if let strongSelf = self, let controller = controller {
                    let view = strongSelf.topView
                    if controller.contentBelowBackground {
                        view.addSubview(controller.view)
                        controller.view.center()
                        if strongSelf.animated {
                            controller.view.layer?.animateAlpha(from: 0.1, to: 1, duration: 0.4, timingFunction: .spring)
                        }
                    }
                    strongSelf.controller?.viewWillAppear(true)
                    strongSelf.visualEffectView?.frame = view.bounds
                    strongSelf.background.frame = view.bounds
                    if controller.isFullScreen {
                        strongSelf.container.frame = view.bounds
                    } else {
                        strongSelf.container.center()
                    }
                    strongSelf.background.background = controller.isFullScreen ? controller.containerBackground : controller.background
                    if strongSelf.animated {
                        if case .alpha = strongSelf.animationType {
                        } else {
                            strongSelf.container.layer?.animateAlpha(from: 0.1, to: 1.0, duration: 0.15, timingFunction: .spring)
                        }
                        if !controller.isFullScreen {
                            switch strongSelf.animationType {
                            case .bottomToCenter:
                                let origin = strongSelf.container.frame.origin
                                strongSelf.container.layer?.animatePosition(from: NSMakePoint(origin.x, origin.y + 100), to: origin, timingFunction: .spring)
                            case .scaleCenter:
                                strongSelf.container.layer?.animateScaleSpring(from: 0.7, to: 1.0, duration: 0.2, bounce: false)
                            case let .scaleFrom(oldRect):
                                let view = strongSelf.container!
                                let newRect = view.frame
                                view.layer?.animateAlpha(from: 0.1, to: 1.0, duration: 0.15, timingFunction: .spring)
                                view.layer?.animatePosition(from: oldRect.origin, to: newRect.origin, duration: 0.3, timingFunction: .spring)
                                view.layer?.animateScaleX(from: oldRect.width / newRect.width, to: 1, duration: 0.3, timingFunction: .spring)
                                view.layer?.animateScaleY(from: oldRect.height / newRect.height, to: 1, duration: 0.3, timingFunction: .spring)
                            case .alpha:
                                view.layer?.animateAlpha(from: 1.0, to: 1.0, duration: 0.15, timingFunction: .spring)
                            }
                        }
                    }
                    strongSelf.visualEffectView?.autoresizingMask = [.width,.height]
                    strongSelf.background.autoresizingMask = [.width,.height]
                    strongSelf.background.customHandler.layout = { [weak strongSelf] view in
                        strongSelf?.container.center()
                    }
                    
                    if controller.isFullScreen {
                        strongSelf.background.customHandler.size = { [weak strongSelf] size in
                            strongSelf?.container.setFrameSize(size)
                        }
                    }
                    
                    var belowView: NSView?
                    
                    for subview in view.subviews.reversed() {
                        if let subview = subview as? ModalBackground {
                            if subview.isOverlay {
                                belowView = subview

                            }
                        }
                    }
                    
                    let background: NSView
                    if let visualEffectView = strongSelf.visualEffectView {
                        background = visualEffectView
                        visualEffectView.addSubview(strongSelf.background)
                    } else {
                        background = strongSelf.background
                    }
                    
                    if let belowView = belowView {
                        view.addSubview(background, positioned: .below, relativeTo: belowView)
                    } else {
                        view.addSubview(background)
                    }
                    if let value = strongSelf.controller?.becomeFirstResponder() {
                        if value {
                            _ = strongSelf.window.makeFirstResponder(strongSelf.controller?.firstResponder())
                        } else {
                            _ = strongSelf.window.makeFirstResponder(nil)
                        }
                    }
                    let animatedBackground = strongSelf.animated && !hideBelowModalsIfNeeded(except: strongSelf)
                    
                    if animatedBackground {
                        strongSelf.background.layer?.animateAlpha(from: 0, to: 1, duration: 0.15, completion:{[weak strongSelf] (completed) in
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

public func hasModals(_ window: Window) -> Bool {
    
    for i in stride(from: activeModals.count - 1, to: -1, by: -1) {
        if activeModals[i].value == nil {
            activeModals.remove(at: i)
        }
    }
    
    return !activeModals.filter { $0.value?.window === window}.isEmpty
}


public func closeAllModals() {
    for modal in activeModals {
        if let controller = modal.value?.controller, controller.closable {
            modal.value?.close()
        }
    }
}

public enum ModalAnimationType {
    case bottomToCenter
    case scaleCenter
    case scaleFrom(NSRect)
    case alpha
}
public enum ModalAnimationCloseBehaviour {
    case common
    case scaleToRect(NSRect)
}

public func showModal(with controller:ModalViewController, for window:Window, isOverlay: Bool = false, animated: Bool = true, animationType: ModalAnimationType = .bottomToCenter) -> Void {
    assert(controller.modal == nil)
    for weakModal in activeModals {
        if weakModal.value?.controller?.className == controller.className, weakModal.value?.controller?.shouldCloseAllTheSameModals == true {
            weakModal.value?.close()
        }
    }
    
    controller.modal = Modal(controller: controller, for: window, animated: animated, isOverlay: isOverlay, animationType: animationType)
    if #available(OSX 10.12.2, *) {
        window.touchBar = nil
    }
    controller.modal?.show()
}

public func closeModal(_ type: ModalViewController.Type) -> Void {
    for i in stride(from: activeModals.count - 1, to: -1 , by: -1) {
        let weakModal = activeModals[i]
        if let controller = weakModal.value?.controller, controller.isKind(of: type) {
            weakModal.value?.close()
        }
    }
}

public func showModal(with controller: NavigationViewController, for window:Window, isOverlay: Bool = false, animated: Bool = true, animationType: ModalAnimationType = .bottomToCenter) -> Void {
    assert(controller.modal == nil)
    for weakModal in activeModals {
        if weakModal.value?.controller?.className == controller.className {
            weakModal.value?.close()
        }
    }
    
    controller.modal = Modal(controller: ModalController(controller), for: window, animated: animated, isOverlay: isOverlay, animationType: animationType)
    controller.modal?.show()
    
}


private func hideBelowModalsIfNeeded(except: Modal) -> Bool {
//    var hided: Bool = false
//    if let exceptController = except.controller, exceptController.containerBackground != .clear {
//        for modal in activeModals {
//            if modal.value != except, let controller = modal.value?.controller, !controller.isFullScreen {
//                modal.value?.background.isHidden = true
//                hided = true
//            }
//        }
//    }
//
//    return hided
    return false
}

private func unhideModalIfNeeded() -> Bool {
//    activeModals.last?.value?.background.isHidden = false
    return false
}
