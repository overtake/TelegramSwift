//
//  NavigationViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
public enum ViewControllerStyle {
    case push;
    case pop;
    case none;
}

open class NavigationHeaderView : View {
    public private(set) weak var header:NavigationHeader?
    public let ready:Promise<Bool> = Promise()
    public init(_ header:NavigationHeader) {
        self.header = header
        super.init(frame: NSMakeRect(0, 0, 0, header.height))
        self.autoresizingMask = [.width]
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

open class NavigationHeader {
    fileprivate var callHeader:NavigationHeader?
    public let height:CGFloat
    let initializer:(NavigationHeader)->NavigationHeaderView
    weak var navigation:NavigationViewController?
    fileprivate var _view:NavigationHeaderView?
    fileprivate let disposable:MetaDisposable = MetaDisposable()
    fileprivate var isShown:Bool = false
    public var needShown:Bool = false
    public init(_ height:CGFloat, initializer:@escaping(NavigationHeader)->NavigationHeaderView) {
        self.height = height
        self.initializer = initializer
    }
    
    public var view:NavigationHeaderView {
        if _view == nil {
            _view = initializer(self)
        }
        return _view!
    }
    
    deinit {
        disposable.dispose()
    }
    
    open func show(_ animated:Bool) {
        assert(navigation != nil)
        needShown = true
        if isShown {
            return
        }
        
        isShown = true
        if let navigation = navigation {
            let view = self.view
            let height = self.height
            view.frame = NSMakeRect(0, 0, navigation.containerView.frame.width, height)

            disposable.set((view.ready.get() |> filter {$0} |> take(1)).start(next: { [weak navigation, weak self, weak view] (ready) in
                if let navigation = navigation, let view = view {
                    let contentInset = navigation.controller.bar.height + height
                    
                    navigation.containerView.addSubview(view, positioned: .above, relativeTo: navigation.controller.view)
                    
                    var inset:CGFloat = navigation.controller.bar.height
 
                    if let callHeader = self?.callHeader, callHeader.needShown {
                        inset += callHeader.height
                    }
                    CATransaction.begin()
                    let completion = navigation.controller.navigationHeaderDidNoticeAnimation(height, 0, animated)
                    view.change(pos: NSMakePoint(0, inset), animated: animated, completion: { [weak navigation] completed in
                        if let navigation = navigation, completed {
                            navigation.controller.view.frame = NSMakeRect(0, contentInset, navigation.controller.frame.width, navigation.frame.height - contentInset)
                            navigation.controller.view.needsLayout = true
                            completion()
                        }
                    })
                    CATransaction.commit()
                }
            }))
        }
        
    }
    
    open func hide(_ animated:Bool) {
        assert(navigation != nil)
        if !isShown {
            return
        }
        needShown = false
        isShown = false
        
        if let navigation = navigation {
            CATransaction.begin()
            let completion = navigation.controller.navigationHeaderDidNoticeAnimation(0, height, animated)
            if animated {
                view.change(pos: NSMakePoint(0, 0), animated: animated, removeOnCompletion: true, completion: { [weak self] completed in
                    if completed {
                        self?._view?.removeFromSuperview()
                        self?._view = nil
                        completion()
                    }
                })
            } else {
                view.removeFromSuperview()
                _view = nil
            }
            CATransaction.commit()
            var inset:CGFloat = navigation.controller.bar.height
            
            if let callHeader = callHeader, callHeader.needShown  {
                inset += callHeader.height
            }
            navigation.controller.view.setFrameSize(NSMakeSize(navigation.controller.frame.width, navigation.frame.height - inset))
            navigation.controller.view.setFrameOrigin(NSMakePoint(0, inset))
        }
        
    }
}

public class CallNavigationHeader : NavigationHeader {
    fileprivate weak var simpleHeader:NavigationHeader?
    public override func show(_ animated:Bool) {
        assert(navigation != nil)
        needShown = true
        if isShown {
            return
        }
        isShown = true
        if let navigation = navigation {
            let view = self.view
            let height = self.height
            view.frame = NSMakeRect(0, 0, navigation.containerView.frame.width, height)
            
            disposable.set((view.ready.get() |> take(1)).start(next: { [weak navigation, weak view] (ready) in
                if let navigation = navigation, let view = view {
                    let contentInset = navigation.controller.bar.height + height
                    navigation.containerView.addSubview(view, positioned: .above, relativeTo: navigation.controller.view)
                    
                    navigation.navigationBar.change(pos: NSMakePoint(0, height), animated: animated)
                    
                    self.simpleHeader?.view.change(pos: NSMakePoint(0, height + navigation.controller.bar.height), animated: animated)
                    
                    view.change(pos: NSMakePoint(0, 0), animated: animated, completion: { [weak navigation] completed in
                        if let navigation = navigation, completed {
                            navigation.controller.view.frame = NSMakeRect(0, contentInset, navigation.controller.frame.width, navigation.frame.height - contentInset)
                            navigation.controller.view.needsLayout = true
                        }
                    })
                    
                }
            }))
        }
        
    }
    
    public override func hide(_ animated:Bool) {
        assert(navigation != nil)
        if !isShown {
            return
        }
        needShown = false
        isShown = false
        
        if let navigation = navigation {
            if animated {
                view.change(pos: NSMakePoint(0, -height), animated: animated, removeOnCompletion: false, completion: { [weak self] completed in
                    if completed {
                        self?._view?.removeFromSuperview()
                        self?._view = nil
                    }
                })
            } else {
                view.removeFromSuperview()
                _view = nil
            }
            
            if let header = simpleHeader, header.needShown {
                header.view.change(pos: NSMakePoint(0, navigation.controller.bar.height), animated: animated)
            }
            
            navigation.navigationBar.change(pos: NSZeroPoint, animated: animated)
            navigation.controller.view.frame = NSMakeRect(0, navigation.controller.bar.height, navigation.controller.frame.width, navigation.frame.height - navigation.controller.bar.height)
            navigation.controller.view.needsLayout = true
        }
        
    }
}

enum NavigationShadowDirection {
    case left, right
}

final class NavigationShadowView : View {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    var direction: NavigationShadowDirection = .left {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.clear(NSMakeRect(0, 0, frame.width, frame.height))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let array = [NSColor.clear.cgColor, NSColor.black.withAlphaComponent(0.2).cgColor]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: array), locations: nil)!
        
        ctx.drawLinearGradient(gradient, start: NSMakePoint(0, 0), end: CGPoint(x: frame.width, y: 0), options: CGGradientDrawingOptions())
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

open class NavigationViewController: ViewController, CALayerDelegate,CAAnimationDelegate {

    public private(set) var modalAction:NavigationModalAction?
    let shadowView:NavigationShadowView = NavigationShadowView(frame: NSMakeRect(0, 0, 20, 0))
    var stack:[ViewController] = [ViewController]()
    var lock:Bool = false
    
    public var empty:ViewController {
        didSet {
            empty.navigationController = self
            
            let prev = self.stack.last
            self.stack.remove(at: 0)
            self.stack.insert(empty, at: 0)
            
            
            var controllerInset:CGFloat = 0
            
            if let header = header, header.needShown {
                controllerInset += header.height
            }
            if let header = callHeader, header.needShown {
                controllerInset += header.height
            }
            
            empty.loadViewIfNeeded(NSMakeRect(0, controllerInset, self.bounds.width, self.bounds.height - controllerInset))
            
            if prev == oldValue {
                controller = empty
                oldValue.removeFromSuperview()
                containerView.addSubview(empty.view)

                if let header = header, header.needShown {
                    header.view.removeFromSuperview()
                    containerView.addSubview(header.view)
                }
                if let header = callHeader, header.needShown {
                    header.view.removeFromSuperview()
                    containerView.addSubview(header.view)
                }
            }
            
            empty.view.frame = NSMakeRect(0, controllerInset, self.bounds.width, self.bounds.height - controllerInset - bar.height)

            
        }
    }
    
    open var isLocked:Bool {
        return lock
    }
    
    public private(set) var controller:ViewController {
        didSet {
            currentControllerDidChange()
        }
    }
    
    func _setController(_ controller:ViewController) {
        self.controller = controller
    }
    
    private(set) public var navigationBar:NavigationBarView = NavigationBarView()
    
    let pushDisposable:MetaDisposable = MetaDisposable()
    let popDisposable:MetaDisposable = MetaDisposable()
    
    private(set) public var header:NavigationHeader?
    private(set) public var callHeader:CallNavigationHeader?
    
    var containerView:View = View()
    
    
    public func set(header:NavigationHeader?) {
        self.header?.hide(false)
        header?.navigation = self
        header?.callHeader = callHeader
        callHeader?.simpleHeader = header
        self.header = header
    }
    
    public func set(callHeader:CallNavigationHeader?) {
        self.callHeader?.hide(false)
        callHeader?.navigation = self
        header?.callHeader = callHeader
        callHeader?.simpleHeader = header
        self.callHeader = callHeader
    }
    
    open override func loadView() {
        super.loadView();
        viewDidLoad()
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        containerView.frame = bounds
        self.view.autoresizesSubviews = true
        containerView.autoresizesSubviews = true
        containerView.autoresizingMask = [.width, .height]
        self.view.addSubview(containerView, positioned: .below, relativeTo: self.view.subviews.first)
        controller._frameRect = bounds
        controller.viewWillAppear(false)
        controller.navigationController = self
        
        containerView.addSubview(navigationBar)
        
        navigationBar.frame = NSMakeRect(0, 0, NSWidth(containerView.frame), controller.bar.height)
        controller.view.frame = NSMakeRect(0, controller.bar.height , NSWidth(containerView.frame), NSHeight(containerView.frame) - controller.bar.height)
        
        navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: .none, animationStyle: controller.animationStyle, liveSwiping: false)
        
        containerView.addSubview(controller.view)
        
        Queue.mainQueue().justDispatch {
            self.controller.viewDidAppear(false)
        }

    }
    
    public func cancelCurrentController() {
        pushDisposable.set(nil)
    }
    
    open override var canBecomeResponder: Bool {
        return false
    }
    open func currentControllerDidChange() {
        
    }
    
    public override var backgroundColor: NSColor {
        set {
            self.view.background = newValue
            containerView.backgroundColor = newValue
            navigationBar.backgroundColor = newValue
        }
        get {
            return self.view.background
        }
    }
    
    public init(_ empty:ViewController) {
        self.empty = empty
        self.controller = empty
        self.stack.append(controller)
        
        super.init()
        bar = .init(height: 0)
    }
    
    public var stackCount:Int {
        return stack.count
    }
    
    deinit {
        self.popDisposable.dispose()
        self.pushDisposable.dispose()
        while !stack.isEmpty {
            let value = stack.removeFirst()
            value.removeFromSuperview()
        }
    }
    
    public func stackInsert(_ controller:ViewController, at: Int) -> Void {
        controller.navigationController = self
        controller.loadViewIfNeeded(self.bounds)
        stack.insert(controller, at: at)
    }
    
    open func push(_ controller:ViewController, _ animated:Bool = true, style: ViewControllerStyle? = nil) -> Void {
        
//        if isLocked {
//            return
//        }
        
        
        controller.navigationController = self
        controller.loadViewIfNeeded(self.bounds)
        self.pushDisposable.set((controller.ready.get() |> take(1)).start(next: {[weak self] _ in
            if let strongSelf = self {
                controller.navigationController = strongSelf
                
                if let index = strongSelf.stack.index(of: controller) {
                    strongSelf.stack.remove(at: index)
                }
                
                strongSelf.stack.append(controller)
                
                let newStyle:ViewControllerStyle
                if let style = style {
                    newStyle = style
                } else {
                    newStyle = animated && strongSelf.stack.count > 1 ? .push : .none
                }
                
                strongSelf.show(controller, newStyle)
            }
        }))
    }
    
    
    func show(_ controller:ViewController,_ style:ViewControllerStyle) -> Void {
        lock = true
        let previous:ViewController = self.controller;
        self.controller = controller
        controller.navigationController = self

        guard let window = self.window else {return}
        
        
        
        if(previous === controller && stackCount > 1) {
            previous.viewWillDisappear(false)
            previous.viewDidDisappear(false)
            
            controller.viewWillAppear(false)
            controller.viewDidAppear(false)
            _ = controller.becomeFirstResponder()
            return;
        }
        
        controller.view.disableHierarchyDynamicContent()
        
        var contentInset = controller.bar.height

        var barInset:CGFloat = 0
        if let header = callHeader, header.needShown {
            header.view.frame = NSMakeRect(0, 0, containerView.frame.width, header.height)
            contentInset += header.height
            barInset += header.height
        }
        
        self.navigationBar.frame = NSMakeRect(0, barInset, NSWidth(containerView.frame), controller.bar.height)
        
        
        if let header = header, header.needShown {
            header.view.frame = NSMakeRect(0, contentInset, containerView.frame.width, header.height)
            containerView.addSubview(header.view, positioned: .below, relativeTo: self.navigationBar)
            contentInset += header.height
        }
        
        controller.view.removeFromSuperview()
        
        let popInteractiveInset: CGFloat? = window.inLiveSwiping ? controller.frame.minX : nil
        
        controller.view.frame = NSMakeRect(0, contentInset , NSWidth(containerView.frame), NSHeight(containerView.frame) - contentInset)
        if #available(OSX 10.12, *) {
            
        } else {
            controller.view.needsLayout = true
        }
        
        
        let reloadHeaders = { [weak self] in
            if let header = self?.header, header.needShown {
                header.view.removeFromSuperview()
                self?.containerView.addSubview(header.view, positioned: .above, relativeTo: controller.view)
            }
            
            if let header = self?.callHeader, header.needShown {
                header.view.removeFromSuperview()
                self?.containerView.addSubview(header.view, positioned: .below, relativeTo: self?.navigationBar)
            }
        }
        
        var pfrom:CGFloat = 0, pto:CGFloat = 0, nto:CGFloat = 0, nfrom:CGFloat = 0;
        
        var sto: CGFloat = 0
        
        switch style {
        case .push:
            nfrom = popInteractiveInset != nil ? popInteractiveInset! : containerView.frame.width
            nto = 0
            pfrom = previous.view.frame.minX
            pto = -round(NSWidth(self.frame)/3.0)
            containerView.addSubview(controller.view, positioned: .above, relativeTo: previous.view)
            sto = -shadowView.frame.width
            addShadowView(.right, updateOrigin: shadowView.superview == nil)
        case .pop:
            nfrom = popInteractiveInset != nil ? popInteractiveInset! : -round(containerView.frame.width/3.0)
            nto = 0
            pfrom = previous.view.frame.minX
            pto = containerView.frame.width
            previous.view.setFrameOrigin(NSMakePoint(pto, previous.frame.minY))
            containerView.addSubview(controller.view, positioned: .below, relativeTo: previous.view)
            sto = containerView.frame.width
            addShadowView(.left, updateOrigin: shadowView.superview == nil)
        case .none:
            previous.viewWillDisappear(false);
            previous.view.removeFromSuperview()
            containerView.addSubview(controller.view)
            controller.viewWillAppear(false);
            previous.viewDidDisappear(false);
            controller.viewDidAppear(false);
            _ = controller.becomeFirstResponder();
            
            self.navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: style, animationStyle: controller.animationStyle, liveSwiping: false)
            lock = false
            
            navigationBar.removeFromSuperview()
            containerView.addSubview(navigationBar)
            
            controller.view.restoreHierarchyDynamicContent()

            
            reloadHeaders()
            
            return // without animations
        }
        
        
        
        if previous.removeAfterDisapper, let index = stack.index(of: previous) {
            self.stack.remove(at: index)
        }
        
        navigationBar.removeFromSuperview()
        containerView.addSubview(navigationBar)
        
        reloadHeaders()
        
        previous.viewWillDisappear(true);
        controller.viewWillAppear(true);
        
       
        
        
        CATransaction.begin()
        
        shadowView.change(opacity: shadowView.direction == .left ? 0.2 : 1, animated: true, duration: previous.animationStyle.duration, timingFunction: previous.animationStyle.function)
        
        shadowView.change(pos: NSMakePoint(sto, shadowView.frame.minY), animated: true, duration: previous.animationStyle.duration, timingFunction: previous.animationStyle.function, completion: { [weak self] completed in
            if completed {
                self?.shadowView.removeFromSuperview()
            }
        })
        
        self.navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: style, animationStyle: controller.animationStyle, liveSwiping: window.inLiveSwiping)

        
         previous.view.layer?.animate(from: pfrom as NSNumber, to: pto as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.spring, duration: previous.animationStyle.duration, removeOnCompletion: true, additive: false, completion: { [weak self] completed in
            if completed {
                previous.view.removeFromSuperview()
                previous.viewDidDisappear(true);
            }
            controller.view.restoreHierarchyDynamicContent()
        
            self?.lock = false
        });
        

        controller.view.layer?.animate(from: nfrom as NSNumber, to: nto as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.spring, duration: controller.animationStyle.duration, removeOnCompletion: true, additive: false, completion: {  completed in
            if completed {
                controller.viewDidAppear(true);
                _ = controller.becomeFirstResponder()
            }

        });
        
        CATransaction.commit()
        
    }
    
    public func first(_ f:(ViewController)->Bool) -> ViewController? {
        return self.stack.first(where: f)
    }
    
    func addShadowView(_ shadowDirection: NavigationShadowDirection, updateOrigin: Bool = true) {
        if updateOrigin {
            shadowView.layer?.opacity = shadowDirection == .left ? 1.0 : 0.0
        }
        shadowView.layer?.removeAllAnimations()
        shadowView.direction = shadowDirection
        shadowView.frame = NSMakeRect(updateOrigin ? (shadowDirection == .left ? -shadowView.frame.width : containerView.frame.width) : shadowView.frame.minX, 0, shadowView.frame.width, containerView.frame.height)
        containerView.addSubview(shadowView, positioned: .below, relativeTo: navigationBar)
    }
    
    open override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        navigationBar.updateLocalizationAndTheme()
    }
    

    open func back(animated:Bool = true, forceAnimated: Bool = false, animationStyle: ViewControllerStyle = .pop) -> Void {
        if stackCount > 1 && !isLocked, let last = stack.last, last.invokeNavigationBack() {
            let controller = stack[stackCount - 2]
            last.didRemovedFromStack()
            stack.removeLast()
            show(controller, animated || forceAnimated ? animationStyle : .none)
        }
    }
    

    
    public func to( index:Int? = nil) -> Void {
        if stackCount > 1, let index = index {
            if index < 0 {
                gotoEmpty(false)
            } else {
                let controller = stack[index]
                stack.removeSubrange(min(max(1, index + 1), stackCount) ..< stackCount)
                show(controller, .none)
            }
        }
    }
    
    public func gotoEmpty(_ animated:Bool = true) -> Void {
        if controller != empty {
            stack.removeSubrange(1 ..< stackCount - 1)
            show(empty, animated ? .pop : .none)
        }
    }
    
    public func close(animated:Bool = true) ->Void {
        if stackCount > 1 && !isLocked {
            let controller = stack[0]
            stack.last?.didRemovedFromStack()
            stack.removeLast()
            show(controller, animated ? .pop : .none)
        }
    }
    
    public func set(modalAction:NavigationModalAction, _ showView:Bool = true) {
        self.modalAction?.view?.removeFromSuperview()
        self.modalAction = modalAction
        modalAction.navigation = self
        if showView {
            let actionView = NavigationModalView(action: modalAction, viewController: self)
            modalAction.view = actionView
            actionView.frame = bounds
            view.addSubview(actionView)
        }  
    }
    
    public func removeUntil(_ controllerType: ViewController.Type) {
        let index = stack.index(where: { current in
            return current.className == NSStringFromClass(controllerType)
        })
        if let index = index {
            while stack.count - 1 > index {
                stack.removeLast()
            }
        } else {
            while stack.count > 1 {
                stack.removeLast()
            }
        }
    }
    
    public func removeModalAction() {
        self.modalAction?.view?.removeFromSuperview()
        self.modalAction = nil
    }
    
    public func enumerateControllers(_ f:(ViewController, Int)->Bool) {
        for i in stride(from: stack.count - 1, to: -1, by: -1) {
            if f(stack[i], i) {
                break
            }
        }
    }
    
}
