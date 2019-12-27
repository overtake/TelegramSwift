//
//  NavigationViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
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
    fileprivate var additionalHeader:NavigationHeader?
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
            view.frame = NSMakeRect(0, navigation.controller.bar.height - height, navigation.containerView.frame.width, height)

            disposable.set((view.ready.get() |> filter {$0} |> take(1)).start(next: { [weak navigation, weak self, weak view] (ready) in
                if let navigation = navigation, let view = view {
                    let contentInset = navigation.controller.bar.height + height
                    
                    navigation.containerView.addSubview(view, positioned: .above, relativeTo: navigation.controller.view)
                    
                    var inset:CGFloat = navigation.controller.bar.height
 
                    if let additionalHeader = self?.additionalHeader, additionalHeader.needShown {
                        inset += additionalHeader.height
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
                view.change(pos: NSMakePoint(0, navigation.controller.bar.height - height), animated: animated, removeOnCompletion: true, completion: { [weak self] completed in
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
            
            if let additionalHeader = additionalHeader, additionalHeader.needShown  {
                inset += additionalHeader.height
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


public class UndoNavigationHeader : NavigationHeader {
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
            view.frame = NSMakeRect(0, -height, navigation.containerView.frame.width, height)
            
            disposable.set((view.ready.get() |> take(1)).start(next: { [weak navigation, weak view] (ready) in
                if let navigation = navigation, let view = view {
                    let contentInset = navigation.controller.bar.height > 0 ? height : 0
                    navigation.containerView.addSubview(view, positioned: .above, relativeTo: navigation.controller.view)
                    CATransaction.begin()
                    if navigation.navigationBar.layer?.animation(forKey: "position") == nil {
                        navigation.navigationBar.change(pos: NSMakePoint(navigation.navigationBar.frame.minX, height), animated: animated)
                    }
                    
                    self.simpleHeader?.view.change(pos: NSMakePoint(0, height + navigation.controller.bar.height), animated: animated)
                    let completion = navigation.controller.navigationUndoHeaderDidNoticeAnimation(height, 0, animated)
                    
                    view.change(pos: NSMakePoint(0, 0), animated: animated, completion: { [weak navigation] completed in
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
    
    public override func hide(_ animated:Bool) {
        assert(navigation != nil)
        if !isShown {
            return
        }
        needShown = false
        isShown = false
        
        if let navigation = navigation {
            CATransaction.begin()
            
            let completion = navigation.controller.navigationUndoHeaderDidNoticeAnimation(0, height, animated)
            
            if animated {
                view.change(pos: NSMakePoint(0, -height), animated: animated, removeOnCompletion: false, completion: { [weak self] completed in
                    if completed {
                        self?._view?.removeFromSuperview()
                        self?._view = nil
                        completion()
                    }
                })
            } else {
                view.removeFromSuperview()
                _view = nil
                completion()
            }
            
            if let header = simpleHeader, header.needShown {
                header.view.change(pos: NSMakePoint(0, navigation.controller.bar.height), animated: animated)
            }
            
            navigation.navigationBar.change(pos: NSZeroPoint, animated: animated)
            navigation.controller.view.frame = NSMakeRect(0, navigation.controller.bar.height, navigation.controller.frame.width, navigation.frame.height - navigation.controller.bar.height)
            navigation.controller.view.needsLayout = true
            CATransaction.commit()
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
        ctx.setStrokeColor(presentation.colors.background.cgColor)
        ctx.setShadow(offset: CGSize.zero, blur: 8, color: .black)
        ctx.setBlendMode(.multiply)
        ctx.strokeLineSegments(between: [CGPoint(x: bounds.width, y: 0), CGPoint(x: bounds.width, y: bounds.height)])

//        let colorSpace = CGColorSpaceCreateDeviceRGB()
//        let array = [NSColor.clear.cgColor, NSColor.black.withAlphaComponent(0.2).cgColor]
//        let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: array), locations: nil)!
//
//        ctx.drawLinearGradient(gradient, start: NSMakePoint(0, 0), end: CGPoint(x: frame.width, y: 0), options: CGGradientDrawingOptions())
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

open class NavigationViewController: ViewController, CALayerDelegate,CAAnimationDelegate {

    public private(set) var modalAction:NavigationModalAction?
    let shadowView:NavigationShadowView = NavigationShadowView(frame: NSMakeRect(0, 0, 20, 0))
    let navigationRightBorder: View = View()
    var stack:[ViewController] = [ViewController]()
    var lock:Bool = false {
        didSet {
            var bp:Int = 0
            bp += 1
        }
    }
    
    public var hasBarRightBorder: Bool = false {
        didSet {
            navigationRightBorder.isHidden = !hasBarRightBorder
            navigationRightBorder.backgroundColor = presentation.colors.border
        }
    }
    
    private let _window: Window
    
    open override var window: Window? {
        return _window
    }
    
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
            } else if let header = undoHeader, header.needShown {
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
                if let header = undoHeader, header.needShown {
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
    private(set) public var undoHeader: UndoNavigationHeader?
    var containerView:BackgroundView = BackgroundView(frame: NSZeroRect)
    
    public var backgroundMode: TableBackgroundMode {
        get {
            return containerView.backgroundMode
        }
        set {
            containerView.backgroundMode = newValue
        }
    }
    
    
    public func set(header:NavigationHeader?) {
        self.header?.hide(false)
        header?.navigation = self
        header?.additionalHeader = callHeader
        callHeader?.simpleHeader = header
        self.header = header
    }
    
    public func set(callHeader:CallNavigationHeader?) {
        self.callHeader?.hide(false)
        callHeader?.navigation = self
        header?.additionalHeader = callHeader
        callHeader?.simpleHeader = header
        self.callHeader = callHeader
    }
    
    public func set(undoHeader:UndoNavigationHeader?) {
        self.undoHeader?.hide(false)
        undoHeader?.navigation = self
        header?.additionalHeader = undoHeader
        undoHeader?.simpleHeader = header
        self.undoHeader = undoHeader
    }
    
    open override func loadView() {
        super.loadView();
        viewDidLoad()
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        containerView.frame = bounds
        //self.view.autoresizesSubviews = true
        //containerView.autoresizesSubviews = true
        //containerView.autoresizingMask = [.width, .height]
        self.view.addSubview(containerView, positioned: .below, relativeTo: self.view.subviews.first)
        controller._frameRect = bounds
        controller.viewWillAppear(false)
        controller.navigationController = self
        
        containerView.addSubview(navigationBar)
        
        navigationBar.frame = NSMakeRect(0, 0, NSWidth(containerView.frame), controller.bar.height)
        controller.view.frame = NSMakeRect(0, controller.bar.height , NSWidth(containerView.frame), NSHeight(containerView.frame) - controller.bar.height)
        
        navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: .none, animationStyle: controller.animationStyle, liveSwiping: false)
        
        containerView.addSubview(controller.view)
        
        self.view.addSubview(navigationRightBorder)
        navigationRightBorder.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, 50)

        
        Queue.mainQueue().justDispatch {
            self.controller.viewDidAppear(false)
        }

    }
    
    open override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        containerView.frame = bounds
        navigationBar.frame = NSMakeRect(0, navigationBar.frame.minY, containerView.frame.width, controller.bar.height)
        navigationRightBorder.frame = NSMakeRect(size.width - .borderSize, 0, .borderSize, navigationBar.frame.height)
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
            navigationBar.backgroundColor = newValue
        }
        get {
            return self.view.background
        }
    }
    
    public init(_ empty:ViewController, _ window: Window) {
        self.empty = empty
        self.controller = empty
        self._window = window
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
                
                if let index = strongSelf.stack.firstIndex(of: controller) {
                    strongSelf.stack.remove(at: index)
                }
                
                strongSelf.stack.append(controller)
                
                let newStyle:ViewControllerStyle
                if let style = style {
                    newStyle = style
                } else {
                    newStyle = animated && strongSelf.stack.count > 1 ? .push : .none
                }
                CATransaction.begin()
                strongSelf.show(controller, newStyle)
                CATransaction.commit()
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
            lock = false
            
            navigationRightBorder.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, navigationBar.frame.height)
            
            return;
        }
        
        controller.view.disableHierarchyDynamicContent()
        
        var contentInset = controller.bar.height

        var barInset:CGFloat = 0
        if let header = callHeader, header.needShown {
            header.view.frame = NSMakeRect(0, 0, containerView.frame.width, header.height)
            contentInset += header.height
            barInset += header.height
        } else if let header = undoHeader, header.needShown {
            header.view.frame = NSMakeRect(0, 0, containerView.frame.width, header.height)
            contentInset += header.height
            barInset += header.height
        }
        

        let animatePosBar: Bool = controller.bar.height != previous.bar.height && style != .none
        self.navigationBar.frame = NSMakeRect(0, barInset, containerView.frame.width, animatePosBar && controller.bar.height == 0 ? previous.bar.height : controller.bar.height)
        
        if !animatePosBar {
            var bp: Int = 0
            bp += 1
        }
        
        
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
            if let header = self?.undoHeader, header.needShown {
                header.view.removeFromSuperview()
                self?.containerView.addSubview(header.view, positioned: .below, relativeTo: self?.navigationBar)
            }
        }
        
        var pfrom:CGFloat = 0, pto:CGFloat = 0, nto:CGFloat = 0, nfrom:CGFloat = 0;
        
        var sto: CGFloat = 0
        
        switch style {
        case .push:
            
            previous.viewWillDisappear(true);
            controller.viewWillAppear(true);
            
            nfrom = popInteractiveInset != nil ? popInteractiveInset! : frame.width
            nto = 0
            pfrom = previous.view.frame.minX
            pto = -round(NSWidth(self.frame)/3.0)
            containerView.addSubview(controller.view, positioned: .above, relativeTo: previous.view)
            
            sto = -shadowView.frame.width
            if controller.isOpaque {
                addShadowView(.right, updateOrigin: shadowView.superview == nil)
            }
            
            if animatePosBar {
                navigationBar.layer?.animatePosition(from: NSMakePoint(nfrom, 0), to: NSMakePoint(nto, 0), duration: previous.animationStyle.duration, timingFunction: .spring)
            }
            
            navigationRightBorder.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
            
        case .pop:
            
            previous.viewWillDisappear(true);
            controller.viewWillAppear(true);
            
            nfrom = popInteractiveInset != nil ? popInteractiveInset! : -round(frame.width/3.0)
            nto = 0
            pfrom = previous.view.frame.minX
            pto = frame.width
            previous.view.setFrameOrigin(NSMakePoint(pto, previous.frame.minY))
            containerView.addSubview(controller.view, positioned: .below, relativeTo: previous.view)
            
            
            if animatePosBar {
                navigationBar.layer?.animatePosition(from: NSMakePoint(pfrom, barInset), to: NSMakePoint(pto, barInset), duration: previous.animationStyle.duration, timingFunction: .spring, removeOnCompletion: false, completion: { [weak controller, weak navigationBar] completed in
                    if let controller = controller, completed {
                        navigationBar?.frame = NSMakeRect(0, barInset, controller.frame.width, controller.bar.height)
                        navigationBar?.layer?.removeAllAnimations()
                    }

                })
            }
            
            navigationRightBorder.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)

            
            sto = frame.width
            if controller.isOpaque {
                addShadowView(.left, updateOrigin: shadowView.superview == nil)
            }
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
            navigationBar.frame = NSMakeRect(0, barInset, controller.frame.width, controller.bar.height)
            containerView.addSubview(navigationBar)
            
            controller.view.restoreHierarchyDynamicContent()

            
            reloadHeaders()
            
            navigationRightBorder.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, navigationBar.frame.height)
            
            return // without animations
        }
        
        let prevBackgroundView = containerView.copy() as! NSView
        let nextBackgroundView = containerView.copy() as! NSView
        
        if !previous.isOpaque {
            previous.view.addSubview(prevBackgroundView, positioned: .below, relativeTo: previous.view.subviews.first)
            prevBackgroundView.setFrameOrigin(NSMakePoint(prevBackgroundView.frame.minX, -previous.view.frame.minY))
        }
        if !controller.isOpaque {
            controller.view.addSubview(nextBackgroundView, positioned: .below, relativeTo: controller.view.subviews.first)
            nextBackgroundView.setFrameOrigin(NSMakePoint(nextBackgroundView.frame.minX, -controller.view.frame.minY))
        }

        
        
        if previous.removeAfterDisapper, let index = stack.firstIndex(of: previous) {
            self.stack.remove(at: index)
        }
        
        navigationBar.removeFromSuperview()
        containerView.addSubview(navigationBar)
        
        reloadHeaders()
        
       
        
       
        
        
        CATransaction.begin()
        
        shadowView.change(opacity: shadowView.direction == .left ? 0.2 : 1, animated: true, duration: previous.animationStyle.duration, timingFunction: previous.animationStyle.function)
        
        shadowView.change(pos: NSMakePoint(sto, shadowView.frame.minY), animated: true, duration: previous.animationStyle.duration, timingFunction: previous.animationStyle.function, completion: { [weak self] completed in
            if completed {
                self?.shadowView.removeFromSuperview()
            }
        })
        if !animatePosBar || (animatePosBar && style == .push) {
            self.navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: animatePosBar ? .none : style, animationStyle: controller.animationStyle, liveSwiping: window.inLiveSwiping)
        }

        
         previous.view.layer?.animate(from: pfrom as NSNumber, to: pto as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.spring, duration: previous.animationStyle.duration, removeOnCompletion: false, additive: false, completion: { [weak prevBackgroundView] completed in
            if completed {
                previous.view.removeFromSuperview()
                previous.view.layer?.removeAnimation(forKey: "position.x")
                previous.viewDidDisappear(true);
                prevBackgroundView?.removeFromSuperview()
            }
        });
        

        controller.view.layer?.animate(from: nfrom as NSNumber, to: nto as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.spring, duration: controller.animationStyle.duration, removeOnCompletion: true, additive: false, completion: { [weak nextBackgroundView, weak self] completed in
            guard let `self` = self else { return }
            if completed {
                controller.viewDidAppear(true);
                _ = controller.becomeFirstResponder()
                nextBackgroundView?.removeFromSuperview()
            }
            self.navigationRightBorder.frame = NSMakeRect(self.frame.width - .borderSize, 0, .borderSize, controller.bar.height)
            self.lock = false
            controller.view.restoreHierarchyDynamicContent()

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
    
    open override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        navigationBar.updateLocalizationAndTheme(theme: theme)
        callHeader?.view.updateLocalizationAndTheme(theme: theme)
        header?.view.updateLocalizationAndTheme(theme: theme)
        undoHeader?.view.updateLocalizationAndTheme(theme: theme)
        navigationRightBorder.backgroundColor = presentation.colors.border
        
        for controller in self.stack {
            if controller != self.controller, controller.isLoaded() {
                controller.leftBarView.updateLocalizationAndTheme(theme: theme)
                controller.centerBarView.updateLocalizationAndTheme(theme: theme)
                controller.rightBarView.updateLocalizationAndTheme(theme: theme)
            }
        }
    }
    

    open func back(animated:Bool = true, forceAnimated: Bool = false, animationStyle: ViewControllerStyle = .pop) -> Void {
        if !isLocked, let last = stack.last, last.invokeNavigationBack() {
            if stackCount > 1 {
                let controller = stack[stackCount - 2]
                last.didRemovedFromStack()
                stack.removeLast()
                show(controller, animated || forceAnimated ? animationStyle : .none)
            } else {
                doSomethingOnEmptyBack?()
            }
        }
    }
    
    
    public var doSomethingOnEmptyBack: (()->Void)? = nil


    
    public func to( index:Int? = nil) -> Void {
        if stackCount > 1, let index = index {
            if index < 0 {
                gotoEmpty(false)
            } else {
                let controller = stack[index]
                let range = min(max(1, index + 1), stackCount) ..< stackCount
                for i in range.lowerBound ..< range.upperBound {
                    stack[i].didRemovedFromStack()
                }
                stack.removeSubrange(range)
                show(controller, .none)
            }
        }
    }
    
    public func gotoEmpty(_ animated:Bool = true) -> Void {
        if controller != empty {
            let range = 1 ..< stackCount - 1
            for i in range.lowerBound ..< range.upperBound {
                stack[i].didRemovedFromStack()
            }
            stack.removeSubrange(1 ..< stackCount - 1)
            show(empty, animated ? .pop : .none)
        }
    }
    
    public func close(animated:Bool = true) ->Void {
        if stackCount > 1 && !isLocked {
            let controller = stack[0]
            while stack.count != 1 {
                stack.removeLast().didRemovedFromStack()
            }
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
        let index = stack.firstIndex(where: { current in
            return current.className == NSStringFromClass(controllerType)
        })
        if let index = index {
            while stack.count - 1 > index {
                let controller = stack.removeLast()
                controller.didRemovedFromStack()
            }
        } else {
            while stack.count > 1 {
                let controller = stack.removeLast()
                controller.didRemovedFromStack()
            }
        }
    }
    
    public func removeAll() {
        stack.removeAll()
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
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if controller.redirectUserInterfaceCalls {
            controller.viewWillAppear(animated)
        }
    }
    
    
    open var previousController: ViewController? {
        if stackCount > 1 {
            return stack[stackCount - 2]
        }
        return nil
    }
    
    open var canSwipeBack: Bool {
        return self.stackCount > 1 // (self.genericView.state == .single || self.stackCount > 2)
    }
    
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.window?.add(swipe: { [weak self] direction -> SwipeHandlerResult in
            guard let `self` = self, self.controller.view.layer?.animationKeys() == nil, let window = self.window else {return .failed}
            
            if let view = window.contentView!.hitTest(window.contentView!.convert(window.mouseLocationOutsideOfEventStream, from: nil))?.superview {
                if view is HorizontalRowView || view.superview is HorizontalRowView {
                    return .failed
                }
            }
            
            switch direction {
            case let .left(state):
                switch state {
                case .start:
                    
                    guard let previous = self.previousController, self.controller.supportSwipes, self.stackCount > 1 && !self.isLocked, self.canSwipeBack else {return .failed}
                    
                    previous.view.frame = NSMakeRect(0, previous.bar.height, self.frame.width, self.frame.height - previous.bar.height)
                    
                    self.containerView.addSubview(previous.view, positioned: .below, relativeTo: self.controller.view)
                    
                    
                    let prevBackgroundView = self.containerView.copy() as! NSView
                    let nextBackgroundView = self.containerView.copy() as! NSView
                    
                    if !previous.isOpaque {
                        previous.view.addSubview(prevBackgroundView, positioned: .below, relativeTo: previous.view.subviews.first)
                        prevBackgroundView.setFrameOrigin(NSMakePoint(prevBackgroundView.frame.minX, -previous.view.frame.minY))
                    }
                    if !self.controller.isOpaque {
                        self.controller.view.addSubview(nextBackgroundView, positioned: .below, relativeTo: self.controller.view.subviews.first)
                        nextBackgroundView.setFrameOrigin(NSMakePoint(nextBackgroundView.frame.minX, -self.controller.view.frame.minY))
                    }
                    
                    self.addShadowView(.left)
                    if previous.bar.has {
                        self.navigationBar.startMoveViews(left: previous.leftBarView, center: previous.centerBarView, right: previous.rightBarView, direction: direction)
                    }
                    self.lock = true
                    return .success(previous)
                case let .swiping(delta, previous):
                    
                    
                    let nPosition = min(max(0, delta), self.containerView.frame.width)
                    self.controller.view._change(pos: NSMakePoint(nPosition, self.controller.view.frame.minY), animated: false)
                    let previousStart = -round(NSWidth(self.containerView.frame)/3.0)
                    previous.view._change(pos: NSMakePoint(min(previousStart + delta / 3.0, 0), previous.view.frame.minY), animated: false)
                    
                    self.shadowView.setFrameOrigin(nPosition - self.shadowView.frame.width, self.shadowView.frame.minY)
                    self.shadowView.layer?.opacity = min(1.0 - Float(nPosition / self.containerView.frame.width) + 0.2, 1.0)
                    
                    if previous.bar.has {
                        self.navigationBar.moveViews(left: previous.leftBarView, center: previous.centerBarView, right: previous.rightBarView, direction: direction, percent: nPosition / self.containerView.frame.width)
                    } else {
                        self.navigationBar.setFrameOrigin(nPosition, self.navigationBar.frame.minY)
                    }
                    return .deltaUpdated(available: nPosition)
                    
                case let .success(_, controller):
                    self.lock = false
                    
                    controller.removeBackgroundCap()
                    self.controller.removeBackgroundCap()
                    
                    self.back(forceAnimated: true)
                case let .failed(_, previous):
                    //   CATransaction.begin()
                    let animationStyle = previous.animationStyle
                    self.controller.view._change(pos: NSMakePoint(0, self.controller.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    self.containerView.subviews[0]._change(pos: NSMakePoint(-round(self.containerView.frame.width / 3), self.containerView.subviews[0].frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self, weak previous] completed in
                        if completed {
                            self?.containerView.subviews[0].removeFromSuperview()
                            self?.controller.removeBackgroundCap()
                            previous?.removeBackgroundCap()
                        }
                    })
                    self.shadowView.change(pos: NSMakePoint(-self.shadowView.frame.width, self.shadowView.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self] completed in
                        self?.shadowView.removeFromSuperview()
                    })
                    self.shadowView.change(opacity: 1, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    if previous.bar.has {
                        self.navigationBar.moveViews(left: previous.leftBarView, center: previous.centerBarView, right: previous.rightBarView, direction: direction, percent: 0, animationStyle: animationStyle)
                    } else {
                        self.navigationBar.change(pos: NSMakePoint(0, self.navigationBar.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    }
                    self.lock = false
                    //  CATransaction.commit()
                }
            case let .right(state):
                
                switch state {
                case .start:
                    guard let new = self.controller.rightSwipeController, !self.isLocked else {return .failed}
                    new._frameRect = self.containerView.bounds
                    new.view.setFrameOrigin(NSMakePoint(self.containerView.frame.width, self.controller.frame.minY))
                    
                    
                    let prevBackgroundView = self.containerView.copy() as! NSView
                    let nextBackgroundView = self.containerView.copy() as! NSView
                    
                    if !new.isOpaque {
                        new.view.addSubview(prevBackgroundView, positioned: .below, relativeTo: new.view.subviews.first)
                        prevBackgroundView.setFrameOrigin(NSMakePoint(prevBackgroundView.frame.minX, -new.view.frame.minY))
                    }
                    if !self.controller.isOpaque {
                        self.controller.view.addSubview(nextBackgroundView, positioned: .below, relativeTo: self.controller.view.subviews.first)
                        nextBackgroundView.setFrameOrigin(NSMakePoint(nextBackgroundView.frame.minX, -self.controller.view.frame.minY))
                    }
                    
                    self.containerView.addSubview(new.view, positioned: .above, relativeTo: self.controller.view)
                    self.addShadowView(.right)
                    self.navigationBar.startMoveViews(left: new.leftBarView, center: new.centerBarView, right: new.rightBarView, direction: direction)
                    self.lock = true
                    return .success(new)
                case let .swiping(delta, new):
                    let delta = min(max(0, delta), self.containerView.frame.width)
                    
                    let nPosition = self.containerView.frame.width - delta
                    // NSLog("\(nPosition)")
                    new.view._change(pos: NSMakePoint(nPosition, new.frame.minY), animated: false)
                    
                    self.controller.view._change(pos: NSMakePoint(min(-delta / 3.0, 0), self.controller.view.frame.minY), animated: false)
                    
                    self.shadowView.setFrameOrigin(nPosition - self.shadowView.frame.width, self.shadowView.frame.minY)
                    self.shadowView.layer?.opacity = min(1.0 - Float(nPosition / self.containerView.frame.width) + 0.2, 1.0)
                    
                    self.navigationBar.moveViews(left: new.leftBarView, center: new.centerBarView, right: new.rightBarView, direction: direction, percent: delta / self.containerView.frame.width)
                    
                    return .deltaUpdated(available: delta)
                case let .success(_, controller):
                    self.lock = false
                    
                    controller.removeBackgroundCap()
                    self.controller.removeBackgroundCap()
                    
                    self.push(controller, true, style: .push)
                case let .failed(_, new):
                    // CATransaction.begin()
                    let animationStyle = new.animationStyle
                    var _new:ViewController? = new
                    
                    
                    _new?.view._change(pos: NSMakePoint(self.containerView.frame.width, self.controller.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    self.containerView.subviews[0]._change(pos: NSMakePoint(0, self.containerView.subviews[0].frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak new, weak self] completed in
                        self?.controller.removeBackgroundCap()
                        new?.view.removeFromSuperview()
                        _new = nil
                    })
                    self.shadowView.change(pos: NSMakePoint(self.containerView.frame.width, self.shadowView.frame.minY), animated: true, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self] completed in
                        self?.shadowView.removeFromSuperview()
                    })
                    self.shadowView.change(opacity: 1, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    self.navigationBar.moveViews(left: new.leftBarView, center: new.centerBarView, right: new.rightBarView, direction: direction, percent: 0, animationStyle: animationStyle)
                    self.lock = false
                    // CATransaction.commit()
                }
            default:
                break
            }
            
            return .nothing
        }, with: self.containerView, identifier: "\(self.description)")
        
        if controller.redirectUserInterfaceCalls {
            controller.viewDidAppear(animated)
        }
    }
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.window?.removeAllHandlers(for: self)
        if controller.redirectUserInterfaceCalls {
            controller.viewWillDisappear(animated)
        }
    }
    
    open override func scrollup() {
        super.scrollup()
        if controller.redirectUserInterfaceCalls {
            controller.scrollup()
        }
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if controller.redirectUserInterfaceCalls {
            controller.viewDidDisappear(animated)
        }
    }
    
    open override func focusSearch(animated: Bool) {
        super.focusSearch(animated: animated)
        if controller.redirectUserInterfaceCalls {
            controller.focusSearch(animated: animated)
        }
    }
}
