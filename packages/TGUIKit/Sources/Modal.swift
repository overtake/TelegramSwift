//
//  Modal.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import AppKit

public enum ModalHeaderActiveState {
    case normal
    case active
}

private class ModalBackground : Control {
    var isOverlay: Bool = false
    var canRedirectScroll: Bool = false
    
    override var sendRightMouseAnyway: Bool {
        return false
    }
    
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
    public var acceptTitle:String
    let cancelTitle:String?
    let drawBorder:Bool
    let height:CGFloat
    var enables:((Bool)->Void)? = nil
    let alignCancelLeft: Bool
    
    var doneUpdatable:(((TextButton)->Void)->Void)? = nil
    var cancelUpdatable:(((TextButton)->Void)->Void)? = nil
    let singleButton: Bool
    let inset: CGFloat
    fileprivate var customTheme: ()->ModalViewController.Theme

    public init(acceptTitle:String, accept:(()->Void)? = nil, cancelTitle:String? = nil, cancel:(()->Void)? = nil, drawBorder:Bool = false, height:CGFloat = 60, inset: CGFloat = 0, alignCancelLeft: Bool = false, singleButton: Bool = false, customTheme: @escaping() -> ModalViewController.Theme = { .init() })  {
        self.drawBorder = drawBorder
        self.accept = accept
        self.cancel = cancel
        self.acceptTitle = acceptTitle
        self.cancelTitle = cancelTitle
        self.height = height
        self.inset = inset
        self.alignCancelLeft = alignCancelLeft
        self.singleButton = singleButton
        self.customTheme = customTheme
    }
    
    public func updateEnables(_ enable:Bool) -> Void {
        if let enables = enables {
            enables(enable)
        }
    }
    
    public func updateDone(_ f:@escaping (TextButton) -> Void) -> Void {
        doneUpdatable?(f)
    }
    public func updateCancel(_ f:@escaping(TextButton) -> Void) -> Void {
        cancelUpdatable?(f)
    }
    
}

private class ModalInteractionsContainer : View {
    let acceptView:TextButton
    let cancelView:TextButton?
    let interactions:ModalInteractions
    let borderView:View?
    
    private let backgroundView = View()
    
    override func mouseUp(with event: NSEvent) {
        
    }
    override func mouseDown(with event: NSEvent) {
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        let pres = interactions.customTheme()
        
        if let cancelView = cancelView {
            cancelView.set(background: .clear, for: .Normal)
            cancelView.set(font: .medium(.text), for: .Normal)
            cancelView.set(color: pres.accent, for: .Normal)
        }
        
        borderView?.backgroundColor = pres.border
        backgroundColor = pres.background
        
        if interactions.singleButton {
            acceptView.set(background: pres.accent, for: .Normal)
            acceptView.set(background: pres.accent.withAlphaComponent(0.8), for: .Highlight)
            let textColor = pres.accent.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
            acceptView.set(color: textColor, for: .Normal)
            acceptView.layer?.cornerRadius = 10
        } else {
            acceptView.set(background: .clear, for: .Normal)
            acceptView.set(color: pres.accent, for: .Normal)
            acceptView.layer?.cornerRadius = 0
        }
        acceptView.set(font: .medium(.text), for: .Normal)
        updateDone()
        updateCancel()
    }
    
    init(interactions:ModalInteractions, modal:Modal) {
        self.interactions = interactions
        acceptView = TextButton()
        acceptView.disableActions()
        acceptView.scaleOnClick = true

        if let cancelTitle = interactions.cancelTitle {
            let cancelView = TextButton()
            self.cancelView = cancelView
            cancelView.set(font: .medium(.text), for: .Normal)
            cancelView.set(text: cancelTitle, for: .Normal)
            _ = cancelView.sizeToFit(NSZeroSize, NSMakeSize(0, interactions.height - 10), thatFit: true)
            cancelView.scaleOnClick = true
        } else {
            cancelView = nil
        }
        

        
        if interactions.drawBorder {
            borderView = View()
            borderView?.backgroundColor = interactions.customTheme().border
        } else {
            borderView = nil
        }
        
       
        
        super.init()
        self.backgroundColor = interactions.customTheme().background
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
        
        self.layer?.masksToBounds = false
        backgroundView.backgroundColor = interactions.customTheme().listBackground
        
        
        if interactions.singleButton {
            addSubview(backgroundView)
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
        
        acceptView.set(text: interactions.acceptTitle, for: .Normal)
        
        updateLocalizationAndTheme(theme: presentation)
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    public func updateDone() {
        if interactions.singleButton {
            _ = acceptView.sizeToFit(NSZeroSize, NSMakeSize(frame.width - 40, 40), thatFit: true)
        } else {
            if cancelView == nil {
                _ = acceptView.sizeToFit(NSZeroSize, frame.size, thatFit: true)
            } else {
                _ = acceptView.sizeToFit(NSZeroSize, NSMakeSize(0, interactions.height - 10), thatFit: true)
            }
        }
        needsLayout = true
    }
    
    public func updateCancel() {
        _ = cancelView?.sizeToFit(NSZeroSize, NSMakeSize(0, interactions.height - 10), thatFit: true)
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
            backgroundView.frame = bounds
            acceptView.frame = CGRect(origin: NSMakePoint(20, self.interactions.inset), size: NSMakeSize(frame.width - 40, 40))
        } else {
            self.backgroundView.frame = bounds
            if cancelView == nil {
                acceptView.frame = bounds
            } else {
                acceptView.centerY(x:frame.width - acceptView.frame.width - 30)
            }
            if let cancelView = cancelView {
                if interactions.alignCancelLeft {
                    cancelView.centerY(x: 20)
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
    fileprivate var customTheme: ()->ModalViewController.Theme
    required init(frame frameRect: NSRect, data: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?), customTheme: @escaping()->ModalViewController.Theme) {
        self.customTheme = customTheme
        super.init(frame: frameRect)
        
        self.customTheme = customTheme
        
        
        titleView.update(TextViewLayout(.initialize(string: data.center?.title, color: customTheme().text, font: .medium(.title)), maximumNumberOfLines: 2))
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        backgroundColor = .clear
        borderColor = customTheme().border
        border = [.Bottom]
        
        if let subtitle = data.center?.subtitle {
            subtitleView = TextView()
            subtitleView!.update(TextViewLayout(.initialize(string: subtitle, color: customTheme().grayText, font: .normal(.text)), maximumNumberOfLines: 1))
            subtitleView!.userInteractionEnabled = false
            subtitleView!.isSelectable = false
            addSubview(subtitleView!)
        }
        
        if let right = data.right {
            rightButton = ImageButton()
            if let image = right.image {
                rightButton?.set(image: image, for: .Normal)
            }
            if right.contextMenu != nil {
                rightButton?.contextMenu = {
                    let menu = ContextMenu()
                    if let items = right.contextMenu?() {
                        for item in items {
                            menu.addItem(item)
                        }
                    }
                    return menu
                }
            } else {
                rightButton?.set(handler: { _ in
                    right.handler?()
                }, for: .Click)
            }
            
            
            
            _ = rightButton?.sizeToFit()
            addSubview(rightButton!)
        }
        
        if let left = data.left {
            leftButton = ImageButton()
            if let image = left.image {
                leftButton?.set(image: image, for: .Normal)
            }
            if left.contextMenu != nil {
                leftButton?.contextMenu = { [weak self] in
                    guard let left = self?.controller?.modalHeader?.left else {
                        return nil
                    }
                    let menu = ContextMenu()
                    if let items = left.contextMenu?() {
                        for item in items {
                            menu.addItem(item)
                        }
                    }
                    return menu
                }
            } else {
                leftButton?.set(handler: { [weak self] _ in
                    guard let left = self?.controller?.modalHeader?.left else {
                        return
                    }
                    left.handler?()
                }, for: .Click)
            }
            
            _ = leftButton?.sizeToFit()
            addSubview(leftButton!)
        }
        
        leftButton?.autohighlight = false
        leftButton?.scaleOnClick = true

        rightButton?.autohighlight = false
        rightButton?.scaleOnClick = true

        
        leftButton?.disableActions()
        rightButton?.disableActions()

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
        
        titleView.textLayout?.measure(width: frame.width - 40 - additionalSize)
        titleView.update(titleView.textLayout)
        
        subtitleView?.textLayout?.measure(width: frame.width - 40 - additionalSize)
        subtitleView?.update(subtitleView?.textLayout)
        
        if let subtitleView = subtitleView {
            let center = frame.midY
            titleView.centerX(y: center - titleView.frame.height - 1)
            subtitleView.centerX(y: center + 1)
        } else {
            titleView.center()
        }
        
    }
    
    private func updateBackground(animated: Bool) {
        switch self.state {
        case .active:
            background = customTheme().activeBackground
            borderColor = customTheme().activeBorder
        case .normal:
            background = .clear
            borderColor = customTheme().border
        }
        if customTheme().hideUnactiveText {
            self.titleView.change(opacity: state == .normal ? 0 : 1, animated: animated)
        } else {
            self.titleView.change(opacity: 1, animated: animated)
        }
        if animated, self.layer?.animation(forKey: "backgroundColor") == nil {
            self.layer?.animateBackground()
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        guard let controller = controller else {
            return
        }
        
        self.updateBackground(animated: false)

        let header = controller.modalHeader
        if let header = header {
            titleView.update(TextViewLayout(.initialize(string: header.center?.title, color: customTheme().text, font: .medium(.title)), maximumNumberOfLines: 2, alignment: .center))
            subtitleView?.update(TextViewLayout(.initialize(string: header.center?.subtitle, color: customTheme().grayText, font: .normal(.text)), maximumNumberOfLines: 1))

            if let image = header.right?.image {
                rightButton?.set(image: image, for: .Normal)
                rightButton?.sizeToFit()
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
    
    private var state: ModalHeaderActiveState = .normal
    
    func makeHeaderState(state: ModalHeaderActiveState,  animated: Bool) {
        self.state = state
        self.updateBackground(animated: animated)
    }
    
}

private class ModalContainerView: View {
    
    let container: View
    let borderView = View()
    required init(frame frameRect: NSRect) {
        container = View(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        super.addSubview(borderView)
        super.addSubview(container)
        borderView.layer?.borderWidth = System.pixel
        container.layer?.masksToBounds = true
    }
    
    override func addSubview(_ view: NSView) {
        container.addSubview(view)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        NSCursor.arrow.set()
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: container, frame: !borderView.isHidden ? size.bounds.insetBy(dx: 1, dy: 1) : size.bounds)
        transition.updateFrame(view: borderView, frame: size.bounds)
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
            interactionsView?.frame = NSMakeRect(0, controller.bounds.height + controller.bar.height, controller.bounds.width, interactions.height)
        }
        if let header = controller.modalHeader {
            headerView = ModalHeaderView(frame: NSMakeRect(0, 0, controller.bounds.width, 50), data: header, customTheme: { [weak controller] in
                return controller?.modalTheme ?? ModalViewController.Theme()
            })
            headerView?.controller = controller
        }
       
        if controller.isFullScreen {
            controller._frameRect = topView.bounds
        }
        
        let noBorder = controller.contentBelowBackground || controller.containerBackground == .clear || controller.isFullScreen || !controller.hasBorder
        
        container = ModalContainerView(frame: noBorder ? containerRect : containerRect.insetBy(dx: -1, dy: -1))
        container.layer?.cornerRadius = controller.cornerRadius
        container.background = controller.containerBackground
                
        
        self.container.layer?.shouldRasterize = true
        self.container.layer?.rasterizationScale = CGFloat(System.backingScale)
        self.container.layer?.isOpaque = false

        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 20
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSMakeSize(0, 0)
        
        self.container.shadow = shadow
        
        container.layer?.masksToBounds = false
        container.container.layer?.masksToBounds = true
        container.container.layer?.cornerRadius = controller.cornerRadius
        container.borderView.layer?.borderColor = controller.modalTheme.grayText.withAlphaComponent(0.1).cgColor
        container.borderView.layer?.cornerRadius = controller.cornerRadius
        
        container.borderView.isHidden = noBorder
        
        controller._window = window

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
                window.set(handler: { [weak controller] _ -> KeyHandlerResult in
                    if let controller = controller, controller.redirectMouseAfterClosing {
                        controller.close()
                        return .rejected
                    }
                    return .invokeNext
                }, with: self, for: .All, priority: controller.responderPriority)
            }
            
            window.set(escape: { [weak self] _ -> KeyHandlerResult in
                if self?.controller?.escapeKeyAction() == .rejected {
                    if self?.controller?.closable == true {
                        self?.controller?.close()
                    }
                }
                return .invoked
            }, with: self, priority: controller.responderPriority)
            
            window.set(handler: { [weak self] _ -> KeyHandlerResult in
                if let controller = self?.controller {
                    return controller.returnKeyAction()
                }
                return .invokeNext
            }, with: self, for: .Return, priority: controller.responderPriority)
            
            window.set(handler: { [weak self] _ -> KeyHandlerResult in
                if let controller = self?.controller {
                    return controller.returnKeyAction()
                }
                return .invokeNext
            }, with: self, for: .KeypadEnter, priority: controller.responderPriority)
        }
        
        if controller.redirectMouseAfterClosing {
            window.set(mouseHandler: { [weak self] _ in
                self?.controller?.close()
                return .rejected
            }, with: self, for: .leftMouseDown, priority: controller.responderPriority)
        }
        
        var isDown: Bool = false
        background.isEventLess = controller.redirectMouseAfterClosing
        background.set(handler: { [weak self] control in
            guard let controller = self?.controller, let `self` = self else { return }
            
            if control.mouseInside() && !controller.view._mouseInside() && !self.container._mouseInside() {
                isDown = true
            }
            
            if controller.redirectMouseAfterClosing, let event = NSApp.currentEvent {
                control.performSuperMouseDown(event)
            }
        }, for: .Down)
        
        background.set(handler: { [weak self] control in
            guard let controller = self?.controller, let `self` = self else { return }
            if controller.closable, !controller.view._mouseInside() && !self.container._mouseInside(), isDown {
                controller.close()
            }
            if controller.redirectMouseAfterClosing, let event = NSApp.currentEvent {
                control.performSuperMouseUp(event)
            }
            
            isDown = false

        }, for: .Up)
        
        if controller.dynamicSize {
            background.customHandler.size = { [weak self] (size) in
                self?.controller?.measure(size: size)
            }
        } else if controller.isFullScreen {
            background.customHandler.size = { [weak self] (size) in
                self?.resize(with: size)
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
        var focus:NSRect
        
        let size = NSMakeSize(max(size.width, 2), max(size.height, 2))
        
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
        
        if controller?.hasBorder == true {
            focus = focus.insetBy(dx: -1, dy: -1)
        }


        if focus != container.frame {
           // CATransaction.begin()
            
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate

            transition.updateFrame(view: container, frame: focus)
            container.updateLayout(size: focus.size, transition: transition)
            
            let frame = CGRect(origin: NSMakePoint(0, headerOffset), size: size)
            controller?.updateFrame(frame, transition: transition)
           // CATransaction.commit()
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
    
    private var markedAsClosed: Bool = false
    
    public func close(_ callAcceptInteraction:Bool = false, animationType: ModalAnimationCloseBehaviour = .common) ->Void {
        
        if markedAsClosed {
            return
        }
        
        markedAsClosed = true
        
        window.removeAllHandlers(for: self)
        controller?.viewWillDisappear(true)
        
        for i in stride(from: activeModals.count - 1, to: -1, by: -1) {
            if activeModals[i].value == self {
                activeModals.remove(at: i)
                break
            }
        }
        
        let animateBackground = !unhideModalIfNeeded() || self.controller?.containerBackground == .clear || animationType == .animateBackground
        
        if callAcceptInteraction, let interactionsView = interactionsView {
            interactionsView.interactions.accept?()
        }
        let background: NSView
        if let visualEffectView = self.visualEffectView {
            background = visualEffectView
        } else {
            background = self.background
        }
        switch animationType {
        case let .noneDelayed(duration):
            delay(duration, closure: { [weak self, weak background] in
                background?.removeFromSuperview()
                self?.controller?.view.removeFromSuperview()
                self?.controller?.view.removeFromSuperview()
                self?.controller?.viewDidDisappear(true)
                self?.controller?.modal = nil
                self?.controller = nil
            })
        default:
            if let controller = controller, controller.contentBelowBackground, !animateBackground {
                controller.view._change(opacity: 0, animated: true, removeOnCompletion: false, duration: 0.25, timingFunction: .spring, completion: { [weak self, weak background] _ in
                    background?.removeFromSuperview()
                    self?.controller?.view.removeFromSuperview()
                    self?.controller?.view.removeFromSuperview()
                    self?.controller?.viewDidDisappear(true)
                    self?.controller?.modal = nil
                    self?.controller = nil
                })

            } else if animateBackground {
                background.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: {[weak self, weak background] complete in
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
        }
        
       
       
       
        switch animationType {
        case .common, .noneDelayed, .animateBackground:
            break
        case let .scaleToRect(newRect, contentView):
            let oldRect = contentView.convert(contentView.bounds, to: background)
            background.addSubview(contentView)
            contentView.layer?.animatePosition(from: oldRect.origin, to: newRect.origin, duration: 0.25, timingFunction: .spring, removeOnCompletion: false)
            contentView.layer?.animateScaleX(from: 1, to: newRect.width / oldRect.width, duration: 0.25, timingFunction: .spring, removeOnCompletion: false)
            contentView.layer?.animateScaleY(from: 1, to: newRect.height / oldRect.height, duration: 0.25, timingFunction: .spring, removeOnCompletion: false)
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
    
    public func makeHeaderState(state: ModalHeaderActiveState,  animated: Bool) {
        self.headerView?.makeHeaderState(state: state, animated: animated)
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
                NSCursor.arrow.set()
                
                
                if let strongSelf = self, let controller = controller {
                    let view = strongSelf.topView
                    if controller.contentBelowBackground {
                        view.addSubview(controller.view)
                        controller.view.center()
                        if strongSelf.animated {
                            controller.view.layer?.animateAlpha(from: 0.1, to: 1, duration: 0.4, timingFunction: .spring)
                        }
                    }
                    let bounds = view.bounds.insetBy(dx: strongSelf.window.modalInset, dy: strongSelf.window.modalInset)

                    strongSelf.background.layer?.cornerRadius = strongSelf.window.modalInset

                    
                    strongSelf.controller?.viewWillAppear(true)
                    strongSelf.visualEffectView?.frame = bounds
                    strongSelf.background.frame = bounds
                    if controller.isFullScreen {
                        strongSelf.container.frame = bounds
                    } else {
                        strongSelf.container.center()
                    }
                    strongSelf.background.background = controller.isFullScreen ? controller.containerBackground : controller.background
                    if strongSelf.animated {
                        if case .alpha = strongSelf.animationType {
                        } else if case .animateBackground = strongSelf.animationType {
                        } else {
                            strongSelf.container.layer?.animateAlpha(from: 0.1, to: 1.0, duration: 0.25, timingFunction: .spring)
                        }
                        if !controller.isFullScreen {
                            switch strongSelf.animationType {
                            case .bottomToCenter:
                                let origin = strongSelf.container.frame.origin
                                strongSelf.container.layer?.animatePosition(from: NSMakePoint(origin.x, origin.y + 100), to: origin, timingFunction: .spring)
                            case .scaleCenter:
                                strongSelf.container.layer?.animateScaleSpring(from: 0.5, to: 1.0, duration: 0.35, bounce: true)
                            case let .scaleFrom(oldRect):
                                let view = strongSelf.container!
                                let newRect = view.frame
                                view.layer?.animateAlpha(from: 0.1, to: 1.0, duration: 0.15, timingFunction: .spring)
                                view.layer?.animatePosition(from: oldRect.origin, to: newRect.origin, duration: 0.3, timingFunction: .spring)
                                view.layer?.animateScaleX(from: oldRect.width / newRect.width, to: 1, duration: 0.3, timingFunction: .spring)
                                view.layer?.animateScaleY(from: oldRect.height / newRect.height, to: 1, duration: 0.3, timingFunction: .spring)
                            case .alpha:
                                view.layer?.animateAlpha(from: 1.0, to: 1.0, duration: 0.15, timingFunction: .spring)
                            case .animateBackground:
                                strongSelf.visualEffectView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                            case .none:
                                break
                            }
                        }
                    }
                    strongSelf.visualEffectView?.autoresizingMask = [.width,.height]
                    strongSelf.background.autoresizingMask = [.width,.height]
                    strongSelf.background.customHandler.layout = { [weak strongSelf] view in
                        strongSelf?.container.center()
                    }
                    
                    if controller.isFullScreen {
                        
                        if case .animateBackground = strongSelf.animationType {
                            strongSelf.visualEffectView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        }
                        
                        strongSelf.background.customHandler.size = { [weak strongSelf] size in
                            strongSelf?.resize(with: size, animated: false)
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


public func closeAllModals(window: Window? = nil) {
    for modal in activeModals {
        if let controller = modal.value?.controller, controller.closable {
            if let window = window, window == modal.value?.window {
                modal.value?.close()
            } else if window == nil {
                modal.value?.close()
            }
        }
    }
}

public func findModal<T>(_ t: T.Type, isAboveTo: ModalViewController? = nil) -> T? where T:ModalViewController {
    let index = activeModals.firstIndex(where: {
        $0.value?.controller === isAboveTo
    })
    for (i, modal) in activeModals.enumerated() {
        if let controller = modal.value?.controller, type(of: controller) == t {
            if let index = index {
                if index >= i {
                    continue
                }
            }
            return controller as? T
        }
    }
    return nil
}

public enum ModalAnimationType {
    case bottomToCenter
    case scaleCenter
    case scaleFrom(NSRect)
    case alpha
    case none
    case animateBackground
}
public enum ModalAnimationCloseBehaviour : Equatable {
    case common
    case noneDelayed(duration: CGFloat)
    case animateBackground
    case scaleToRect(NSRect, NSView)
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
    window.makeKeyAndOrderFront(nil)
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
