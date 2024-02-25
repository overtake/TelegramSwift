//
//  NavigationViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import AppKit

public enum ViewControllerStyle {
    case push
    case pop
    case none
}



open class NavigationHeaderView : View {
    public private(set) weak var header:NavigationHeader?
    public let ready:Promise<Bool> = Promise()

    public private(set) var height: CGFloat
    public init(_ header:NavigationHeader) {
        self.header = header
        self.height = header.height
        super.init(frame: NSMakeRect(0, 0, 0, header.height))
        self.autoresizingMask = [.width]
    }

    open func update(with contextObject: Any) {
        self.header?.contextObject = contextObject
    }

    open func destroy() {
        self.header?.contextObject = nil
    }

    open func hide(_ animated: Bool) {
        destroy()
        self.header?.hide(animated)
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

open class NavigationHeader {

    public var contextObject: Any? = nil

    fileprivate weak var supplyHeader:NavigationHeader?
    fileprivate weak var simpleHeader:NavigationHeader?


    public let height:CGFloat
    fileprivate var realHeight: CGFloat = 0
    let initializer:(NavigationHeader, Any, NavigationHeaderView?)->(NavigationHeaderView, CGFloat)
    weak var navigation:NavigationViewController?
    fileprivate let disposable:MetaDisposable = MetaDisposable()
    fileprivate(set) var isShown:Bool = false
    public var needShown:Bool = false
    public init(_ height:CGFloat, initializer:@escaping(NavigationHeader, Any, NavigationHeaderView?)->(NavigationHeaderView, CGFloat)) {
        self.height = height
        self.initializer = initializer
    }
    fileprivate var _view:NavigationHeaderView? 
    public var view:NavigationHeaderView {
        return _view!
    }
    
    deinit {
        disposable.dispose()
    }
    
    open func show(_ animated:Bool, contextObject: Any) {
        assert(navigation != nil)
        self.contextObject = contextObject
        let initialized = initializer(self, contextObject, self._view)
        if isShown {
            if initialized.0 === _view {
                return
            } else if _view != nil {
                hide(animated)
            }
        }
        
        isShown = true
        if let navigation = navigation {
            readyShow(navigation, animated: animated, initialized: initialized)
        }
    }
    
    func readyShow(_ navigation: NavigationViewController, animated: Bool, initialized: (NavigationHeaderView, CGFloat)) {
        self._view = initialized.0
        self.realHeight = initialized.1
        let view = self.view
        let realHeight = self.realHeight
        let height = self.height
        view.frame = NSMakeRect(0, -height, navigation.containerView.frame.width, realHeight)
        disposable.set((view.ready.get() |> filter {$0} |> take(1)).start(next: { [weak navigation, weak self, weak view] (ready) in
            if let navigation = navigation, let view = view {
                var contentInset = height + navigation.controller.barHeight
                self?.needShown = true

                if let header = self?.supplyHeader, header.needShown {
                    navigation.containerView.addSubview(view, positioned: .below, relativeTo: header.view)
                } else {
                    navigation.containerView.addSubview(view, positioned: .above, relativeTo: navigation.controller.view)
                }
                
                var inset:CGFloat = 0
                
                var barInset: CGFloat = height
                
                

                if let supplyHeader = self?.supplyHeader, supplyHeader.needShown {
                    inset += supplyHeader.height
                    contentInset += supplyHeader.height
                    barInset += supplyHeader.height
                }
                let transition: ContainedViewLayoutTransition
                if animated {
                    transition = .animated(duration: 0.2, curve: .easeOut)
                } else {
                    transition = .immediate
                }
                
                let size = navigation.navigationBar.frame.size
                transition.updateFrame(view: navigation.navigationBar, frame: CGRect(origin: NSMakePoint(0, barInset), size: size))

                
                transition.updateFrame(view: view, frame: NSMakeRect(0, inset, view.frame.width, view.frame.height))

                navigation.controller.updateFrame(NSMakeRect(0, contentInset, navigation.controller.frame.width, navigation.frame.height - contentInset), transition: transition)
                
            }
        }))
    }
    
    open func hide(_ animated:Bool) {
        assert(navigation != nil)
        self.contextObject = nil
        if !isShown {
            return
        }
        needShown = false
        isShown = false
        
        if let navigation = navigation, let view = _view {
            _view = nil
            performSubviewPosRemoval(view, pos: NSMakePoint(0, -height), animated: animated, duration: 0.2, timingFunction: .easeOut)

            var barInset: CGFloat = 0
            
            var inset:CGFloat = navigation.controller.barHeight
            if let supplyHeader = supplyHeader, supplyHeader.needShown  {
                inset += supplyHeader.height
                barInset += supplyHeader.height
            }
            
            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.2, curve: .easeOut)
            } else {
                transition = .immediate
            }
            let size = navigation.navigationBar.frame.size
            transition.updateFrame(view: navigation.navigationBar, frame: CGRect(origin: NSMakePoint(0, barInset), size: size))
            navigation.controller.updateFrame(CGRect(origin: NSMakePoint(0, inset), size: NSMakeSize(navigation.controller.frame.width, navigation.frame.height - inset)), transition: transition)
        }
        
    }
}

public class CallNavigationHeader : NavigationHeader {

    override func readyShow(_ navigation: NavigationViewController, animated: Bool, initialized: (NavigationHeaderView, CGFloat)) {
        self._view = initialized.0
        self.realHeight = initialized.1
        self._view = initialized.0
        self.realHeight = initialized.1
        let view = self.view
        let realHeight = self.realHeight
        let height = self.height
        view.frame = NSMakeRect(0, -realHeight, navigation.containerView.frame.width, realHeight)
        
        
        disposable.set((view.ready.get() |> take(1)).start(next: { [weak navigation, weak view, weak self] (ready) in
            if let navigation = navigation, let view = view {
                self?.needShown = true
                var contentInset = height + navigation.controller.barHeight
                
                if let simpleHeader = self?.simpleHeader, simpleHeader.needShown {
                    navigation.containerView.addSubview(view, positioned: .above, relativeTo: simpleHeader.view)
                } else {
                    navigation.containerView.addSubview(view, positioned: .above, relativeTo: navigation.controller.view)
                }
                
                var barInset: CGFloat = height
                
                let transition: ContainedViewLayoutTransition
                if animated {
                    transition = .animated(duration: 0.2, curve: .easeOut)
                } else {
                    transition = .immediate
                }
                
                if let simpleHeader = self?.simpleHeader, simpleHeader.needShown {
                    let view = simpleHeader.view
                    let size = view.frame.size
                    transition.updateFrame(view: view, frame: CGRect(origin: NSMakePoint(0, height), size: size))
                    contentInset += simpleHeader.height
                    barInset += simpleHeader.height
                }
                
                let size = navigation.navigationBar.frame.size
                transition.updateFrame(view: navigation.navigationBar, frame: CGRect(origin: NSMakePoint(0, barInset), size: size))
                transition.updateFrame(view: view, frame: CGRect(origin: .zero, size: view.frame.size))

                navigation.controller.updateFrame(NSMakeRect(0, contentInset, navigation.controller.frame.width, navigation.frame.height - contentInset), transition: transition)
                
            }
        }))
    }
    
    public override func hide(_ animated:Bool) {
        assert(navigation != nil)
        if !isShown {
            return
        }
        needShown = false
        isShown = false
        
        if let navigation = navigation, let view = _view {
            _view = nil
            performSubviewPosRemoval(view, pos: NSMakePoint(0, -realHeight), animated: animated, duration: 0.2, timingFunction: .easeOut)

            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.2, curve: .easeOut)
            } else {
                transition = .immediate
            }
            var contentInset: CGFloat = navigation.controller.barHeight
            if let header = simpleHeader, header.needShown {
                transition.updateFrame(view: header.view, frame: CGRect.init(origin: NSMakePoint(0, 0), size: header.view.frame.size))
                contentInset += header.height
            }
                                    
            transition.updateFrame(view: navigation.navigationBar, frame: CGRect.init(origin: NSMakePoint(0, contentInset - navigation.navigationBar.frame.height), size: navigation.navigationBar.frame.size))
            
            navigation.controller.updateFrame(NSMakeRect(0, contentInset, navigation.controller.frame.width, navigation.frame.height - contentInset), transition: transition)
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

    var getColor:()->NSColor = { presentation.colors.background }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.clear(NSMakeRect(0, 0, frame.width, frame.height))
        ctx.setStrokeColor(getColor().cgColor)
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

    public var applyAppearOnLoad: Bool = true
    public var canAddControllers: Bool = true
    public private(set) var modalAction:NavigationModalAction?
    let shadowView:NavigationShadowView = NavigationShadowView(frame: NSMakeRect(0, 0, 20, 0))
    let navigationRightBorder: View = View()
    let navigationLeftBorder: View = View()
    var stack:[ViewController] = [ViewController]()
    
    public var cleanupAfterDeinit: Bool = true
    
    var lock:Bool = false {
        didSet {
            var bp:Int = 0
            bp += 1
        }
    }
    
    public var hasBarRightBorder: Bool = false {
        didSet {
            navigationRightBorder.isEventLess = true
            navigationRightBorder.isHidden = !hasBarRightBorder
            navigationRightBorder.backgroundColor = presentation.colors.border
        }
    }
    public var hasBarLeftBorder: Bool = false {
        didSet {
            navigationLeftBorder.isEventLess = true
            navigationLeftBorder.isHidden = !hasBarLeftBorder
            navigationLeftBorder.backgroundColor = presentation.colors.border
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
            }
            
            let rect = NSMakeRect(0, controllerInset, self.bounds.width, self.bounds.height - controllerInset - bar.height)
            
            empty.loadViewIfNeeded(rect)
                        
            if prev == oldValue {
                controller = empty
                oldValue.removeFromSuperview()
                containerView.addSubview(empty.view)

                if let header = header, header.needShown {
                    header.view.removeFromSuperview()
                    containerView.addSubview(header.view, positioned: .below, relativeTo: navigationBar)
                }
                if let header = callHeader, header.needShown {
                    header.view.removeFromSuperview()
                    containerView.addSubview(header.view, positioned: .below, relativeTo: navigationBar)
                }
            }
            
            empty.view.frame = rect

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
    var containerView:BackgroundView = BackgroundView(frame: NSZeroRect)
    
    public var backgroundMode: TableBackgroundMode {
        get {
            return containerView.backgroundMode
        }
        set {
            containerView.backgroundMode = newValue
        }
    }
    
    public func doBackgroundAction() {
        DispatchQueue.main.async { [weak self] in
            self?.containerView.doAction()
        }
    }
    
    public func set(header:NavigationHeader?) {
        self.header?.hide(false)
        header?.navigation = self
        header?.supplyHeader = callHeader
        callHeader?.simpleHeader = header
        self.header = header
    }
    
    public func set(callHeader:CallNavigationHeader?) {
        self.callHeader?.hide(false)
        callHeader?.navigation = self
        header?.supplyHeader = callHeader
        callHeader?.simpleHeader = header
        self.callHeader = callHeader
    }

    
    open override func loadView() {
        super.loadView();
    }
    
    public var navigationBarLeftPosition: CGFloat = 0 {
        didSet {
            navigationBar.needsLayout = true
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        
        containerView.frame = bounds
        //self.view.autoresizesSubviews = true
        //containerView.autoresizesSubviews = true
        //containerView.autoresizingMask = [.width, .height]
        self.view.addSubview(containerView, positioned: .below, relativeTo: self.view.subviews.first)
        controller._frameRect = bounds
        if self.applyAppearOnLoad {
            controller.viewWillAppear(false)
        }
        controller.navigationController = self
        
        containerView.addSubview(navigationBar)
        
        navigationBar.frame = NSMakeRect(0, 0, NSWidth(containerView.frame), controller.barHeight)
        controller.view.frame = NSMakeRect(0, controller.barHeight , NSWidth(containerView.frame), NSHeight(containerView.frame) - controller.barHeight)
        
        navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: .none, animationStyle: controller.animationStyle, liveSwiping: false)
        
        containerView.addSubview(controller.view)
        self.view.addSubview(navigationRightBorder)
        self.view.addSubview(navigationLeftBorder)
//        self.view.addSubview(navigationLeftBorder)
        navigationRightBorder.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
        
        navigationLeftBorder.frame = NSMakeRect(-.borderSize, 0, .borderSize, frame.height)

        if self.applyAppearOnLoad {
            Queue.mainQueue().justDispatch {
                self.controller.viewDidAppear(false)
            }
        }
        

    }
    
    var barInset: CGFloat {
        var barInset:CGFloat = 0
        if let header = header, header.needShown {
            barInset += header.height
        }
        if let header = callHeader, header.needShown {
            barInset += header.height
        }
        return barInset
    }
    
    override open func swapNavigationBar(leftView: BarView?, centerView: BarView?, rightView: BarView?, animation: NavigationBarSwapAnimation) {
        
        navigationBar.frame = NSMakeRect(0, self.navigationBar.frame.minY, containerView.frame.width, controller.barHeight)
        
        if let leftView = leftView {
            navigationBar.switchLeftView(leftView, animation: animation)
        }
        if let centerView = centerView {
            navigationBar.switchCenterView(centerView, animation: animation)
        }
        if let rightView = rightView {
            navigationBar.switchRightView(rightView, animation: animation)
        }
    }
    
    var containerSize: NSSize {
        return frame.size
    }
    
    open override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        let settings = self.controller.stake
        
        let keepLeft: CGFloat = size.width == settings.keepLeft ? 0 : settings.keepLeft
        
        let keepTop = size.width == settings.keepLeft ? 0 : settings.keepTop()
        
        let width = containerSize.width - keepLeft
        let point = NSMakePoint(keepLeft, 0)

        
        containerView.frame = NSMakeRect(0, 0, containerSize.width, containerSize.height)
        
        
        navigationBar.frame = NSMakeRect(point.x, navigationBar.frame.minY, width, controller.bar.height)
        navigationRightBorder.frame = NSMakeRect(size.width - .borderSize, keepTop, .borderSize, frame.height)
        
        
        navigationLeftBorder.frame = NSMakeRect(point.x - .borderSize, keepTop, .borderSize, size.height)
        
        if let header = callHeader, header.needShown {
            header.view.setFrameSize(NSMakeSize(width, header.realHeight))
        }
        if let header = header, header.needShown {
            header.view.setFrameSize(NSMakeSize(width, header.realHeight))
        }
        
        if controller.isLoaded() {
            controller.frame = NSMakeRect(point.x, barInset + controller.barHeight + keepTop, width, containerSize.height - barInset - controller.barHeight)
            
            if let tied = controller.tied {
                containerView.addSubview(tied.view, positioned: .below, relativeTo: controller.view)
                tied.view.frame = NSMakeRect(0, barInset + tied.bar.height, containerSize.width, containerSize.height - barInset - tied.bar.height)
                if tied.widthOnDisappear != nil {
                    tied.widthOnDisappear = containerSize.width
                }
            }

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
        navigationBar.navigation = self
        bar = .init(height: 0)
        shadowView.getColor = { [weak self] in
            self?.controller.backgroundColor ?? presentation.colors.background
        }
    }
    
    public var stackCount:Int {
        return stack.count
    }
    
    deinit {
        self.popDisposable.dispose()
        self.pushDisposable.dispose()
        if cleanupAfterDeinit {
            while !stack.isEmpty {
                let value = stack.removeFirst()
                
                value.removeFromSuperview()
            }
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
        
        if !self.canAddControllers {
            return
        }
        
        if controller.abolishWhenNavigationSame, controller.className == self.controller.className {
            return
        }

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
      

        guard let window = self.window else {return}
        if style == .none {
            window.abortSwiping()
        }
        defer {
            CATransaction.commit()
        }
        
        CATransaction.begin()
        
        let keepLeft = frame.width == controller.stake.keepLeft ? 0 : controller.stake.keepLeft

        
        let previous:ViewController = self.controller;
        controller.navigationController = self
        
        
        
        previous.setToNextController(controller, style: style)
        controller.setToPreviousController(previous, style: style)

        
        let keepTop = frame.width == controller.stake.keepLeft ? 0 : controller.stake.keepTop()
        var contentInset = controller.barHeight + keepTop

        let size = CGSize(width: containerView.frame.width - keepLeft, height: containerView.frame.height)
        let point = NSMakePoint(keepLeft, contentInset)

        
        if(previous === controller && stackCount > 1) {
            previous.viewWillDisappear(false)
            previous.viewDidDisappear(false)
            
            controller.viewWillAppear(false)
            controller.viewDidAppear(false)
            _ = controller.becomeFirstResponder()
            lock = false
            
            navigationRightBorder.frame = NSMakeRect(frame.width - .borderSize, keepTop, .borderSize, frame.height)
            
            navigationLeftBorder.frame = NSMakeRect(keepLeft - .borderSize, keepTop, .borderSize, frame.height)

            
            return;
        }
        
        
        

        var barInset:CGFloat = 0
        if let header = callHeader, header.needShown {
            header.view.frame = NSMakeRect(point.x, 0, size.width, header.realHeight)
            contentInset += header.height
            barInset += header.height
        }
        
        if let header = header, header.needShown {
            header.view.frame = NSMakeRect(point.x, barInset, size.width, header.realHeight)
            containerView.addSubview(header.view, positioned: .below, relativeTo: self.navigationBar)
            contentInset += header.height
            barInset += header.height
        }

        let animatePosBar: Bool = controller.bar.height != previous.bar.height && style != .none
        self.navigationBar.frame = NSMakeRect(point.x, barInset, size.width, animatePosBar && controller.bar.height == 0 ? previous.bar.height : controller.bar.height)
        
        self.navigationBar.layer?.removeAllAnimations()

        
     
        
        if keepLeft > 0 || previous.stake.keepIn {
            controller.tied = previous
        } else {
            controller.tied = nil
        }
        previous.tied = nil
        
       // controller.view.removeFromSuperview()
        
        let popInteractiveInset: CGFloat? = window.inLiveSwiping ? controller.frame.minX : nil
        
        controller.view.frame = NSMakeRect(point.x, contentInset, size.width, size.height - contentInset)
       
        
        let reloadHeaders = { [weak self] in
            if let header = self?.callHeader, header.needShown {
                self?.containerView.addSubview(header.view, positioned: .above, relativeTo: controller.view)
            }
            if let header = self?.header, header.needShown {
                self?.containerView.addSubview(header.view, positioned: .above, relativeTo: controller.view)
            }
        }
        
        var pfrom:CGFloat = 0, pto:CGFloat = 0, nto:CGFloat = 0, nfrom:CGFloat = 0;
        
        var sto: CGFloat = 0
        
        
        
        switch style {
        case .push:
            
            controller.view.disableHierarchyDynamicContent()
            
            previous.viewWillDisappear(true);
            controller.viewWillAppear(true);
            
            nfrom = popInteractiveInset != nil ? popInteractiveInset! : frame.width
            nto = keepLeft
            pfrom = previous.view.frame.minX
            if previous.stake.keepLeft > 0 && previous.stake.keepLeft != frame.width {
                pto = frame.maxX
            } else if keepLeft > 0 {
                pto = 0
            } else {
                pto = -round(NSWidth(self.frame)/3.0)
            }
            
            previous.view.setFrameOrigin(NSMakePoint(pfrom, previous.frame.minY))
            controller.view.setFrameOrigin(NSMakePoint(nfrom, controller.frame.minY))

            
            containerView.addSubview(controller.view, positioned: .above, relativeTo: previous.view)

            
            sto = -shadowView.frame.width + keepLeft
            if controller.isOpaque {
                addShadowView(.right, controller: controller, updateOrigin: shadowView.superview == nil)
            }
            
            if animatePosBar {
                navigationBar.layer?.animatePosition(from: NSMakePoint(nfrom, navigationBar.frame.minY), to: NSMakePoint(nto, barInset), duration: previous.animationStyle.duration, timingFunction: previous.animationStyle.function)
            }
            
            
        case .pop:
            
            controller.view.disableHierarchyDynamicContent()
            
            previous.viewWillDisappear(true);
            controller.viewWillAppear(true);
            
            if let popInteractiveInset = popInteractiveInset {
                nfrom = popInteractiveInset
            } else if previous.stake.keepLeft > 0 && previous.stake.keepLeft != frame.width {
                nfrom = 0
            } else {
                nfrom = -round(frame.width/3.0)
            }
            
            nto = 0
            pfrom = previous.view.frame.minX
            pto = frame.width
            
            previous.view.setFrameOrigin(NSMakePoint(pfrom, previous.frame.minY))
            controller.view.setFrameOrigin(NSMakePoint(nfrom, controller.frame.minY))

            containerView.addSubview(controller.view, positioned: .below, relativeTo: previous.view)
            
            
            if animatePosBar {
                navigationBar.layer?.animatePosition(from: NSMakePoint(pfrom, barInset), to: NSMakePoint(pto, barInset), duration: previous.animationStyle.duration, timingFunction: previous.animationStyle.function, removeOnCompletion: false, completion: { [weak controller, weak navigationBar] completed in
                    if let controller = controller {
                        navigationBar?.frame = NSMakeRect(0, barInset, controller.frame.width, controller.bar.height)
                    }
                    navigationBar?.layer?.removeAllAnimations()
                })
            }
            

            
            sto = frame.width
            if controller.isOpaque {
                addShadowView(.left, controller: previous, updateOrigin: shadowView.superview == nil)
            }
        case .none:
            
            
            previous.viewWillDisappear(false);
            previous.view.removeFromSuperview()
            containerView.addSubview(controller.view)

            self.controller = controller
            
            controller.viewWillAppear(false);
            previous.viewDidDisappear(false);
            controller.viewDidAppear(false);
            _ = controller.becomeFirstResponder();
            
            self.navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: style, animationStyle: controller.animationStyle, liveSwiping: false)
            lock = false
            
            navigationBar.removeFromSuperview()
            navigationBar.frame = NSMakeRect(point.x, barInset, controller.frame.width, controller.bar.height)

            navigationBar.removeFromSuperview()
            containerView.addSubview(navigationBar, positioned: .below, relativeTo: self.controller.view)


            reloadHeaders()
            
            navigationRightBorder.frame = NSMakeRect(frame.width - .borderSize, keepTop, .borderSize, frame.height)
            navigationLeftBorder.frame = NSMakeRect(keepLeft - .borderSize, keepTop, .borderSize, frame.height)

            return // without animations
        }
        
        self.controller = controller
        
        
        let prevBackgroundView: NSView = containerView.copy(previous.bgMode)
        let nextBackgroundView: NSView = containerView.copy(controller.bgMode)
        
        
        if !controller.isOpaque {
            controller.view.addSubview(nextBackgroundView, positioned: .below, relativeTo: controller.view.subviews.first)
            nextBackgroundView.setFrameOrigin(NSMakePoint(nextBackgroundView.frame.minX, -controller.view.frame.minY))
        }
        if !previous.isOpaque {
            previous.view.addSubview(prevBackgroundView, positioned: .below, relativeTo: previous.view.subviews.first)
            prevBackgroundView.setFrameOrigin(NSMakePoint(prevBackgroundView.frame.minX, -previous.view.frame.minY))
        }
        
        
        if let index = stack.firstIndex(of: previous) {
            if previous.removeAfterDisapper {
                self.stack.remove(at: index)
            } else if previous.stake.keepLeft > 0 {
                self.stack.remove(at: index)
            }
        }
        
        
        containerView.addSubview(navigationBar, positioned: .below, relativeTo: self.controller.view)

        reloadHeaders()
                
              
        
        navigationRightBorder.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
       
        let n_left_previous = navigationLeftBorder.frame.minY
        if keepLeft > 0 {
            navigationLeftBorder.frame = NSMakeRect(keepLeft - .borderSize, keepTop, .borderSize, frame.height)
            navigationLeftBorder.layer?.animatePosition(from: NSMakePoint(nfrom, keepTop), to: navigationLeftBorder.frame.origin, duration: controller.animationStyle.duration, timingFunction: controller.animationStyle.function)
        } else {
            navigationLeftBorder.frame = NSMakeRect(pto - .borderSize, n_left_previous, .borderSize, frame.height)
            navigationLeftBorder.layer?.animatePosition(from: NSMakePoint(pfrom, n_left_previous), to: navigationLeftBorder.frame.origin, duration: controller.animationStyle.duration, timingFunction: controller.animationStyle.function)
        }
        



        
        shadowView.change(opacity: shadowView.direction == .left || keepLeft > 0 ? 0.2 : 1, animated: true, duration: previous.animationStyle.duration, timingFunction: previous.animationStyle.function)
        
        shadowView.change(pos: NSMakePoint(sto, shadowView.frame.minY), animated: true, duration: previous.animationStyle.duration, timingFunction: previous.animationStyle.function, completion: { [weak self] completed in
            if completed {
                self?.shadowView.removeFromSuperview()
            }
        })
        if !animatePosBar || (animatePosBar && style == .push) {
            self.navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, controller: controller, style: animatePosBar ? .none : style, animationStyle: controller.animationStyle, liveSwiping: window.inLiveSwiping)
        }

        
        
        previous.view._change(pos: NSMakePoint(pto, previous.frame.minY), animated: true, duration: controller.animationStyle.duration, timingFunction: .spring, completion: { [weak prevBackgroundView] completed in
            if completed, keepLeft == 0 || previous.stake.keepLeft > 0 {
                previous.view.removeFromSuperview()
                previous.viewDidDisappear(true);
                prevBackgroundView?.removeFromSuperview()
            }
        });
        

        controller.view._change(pos: NSMakePoint(nto, controller.frame.minY), animated: true, duration: controller.animationStyle.duration, timingFunction: .spring, completion: { [weak nextBackgroundView, weak self] completed in
            guard let `self` = self else { return }
            if completed {
                controller.viewDidAppear(true);
                _ = controller.becomeFirstResponder()
                nextBackgroundView?.removeFromSuperview()
            }
            self.navigationRightBorder.frame = NSMakeRect(self.frame.width - .borderSize, 0, .borderSize, self.frame.height)
            self.lock = false
            controller.view.restoreHierarchyDynamicContent()

        })

    }
    
    public func first(_ f:(ViewController)->Bool) -> ViewController? {
        return self.stack.first(where: f)
    }
    
    func addShadowView(_ shadowDirection: NavigationShadowDirection, controller: ViewController, updateOrigin: Bool = true) {
        if updateOrigin {
            shadowView.layer?.opacity = shadowDirection == .left ? 1.0 : 0.0
        }
        shadowView.layer?.removeAllAnimations()
        
        
        var shadowInset: CGFloat = 0
        
        if let callHeader = callHeader, callHeader.isShown {
            shadowInset += callHeader.height
        }
        let keepTop = frame.width == controller.stake.keepLeft ? 0 : controller.stake.keepTop()
        let keepLeft = frame.width == controller.stake.keepLeft ? 0 : controller.stake.keepLeft

        shadowInset += keepTop
        
        let leftInset: CGFloat = keepLeft
        
        shadowView.direction = shadowDirection
        shadowView.frame = NSMakeRect(updateOrigin ? (shadowDirection == .left ? -shadowView.frame.width + leftInset : containerView.frame.width) : shadowView.frame.minX, shadowInset, shadowView.frame.width, containerView.frame.height - shadowInset)
        containerView.addSubview(shadowView, positioned: .below, relativeTo: navigationBar)
    }
    
    open override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        navigationBar.updateLocalizationAndTheme(theme: theme)
        if let callHeader = callHeader, callHeader.needShown {
            callHeader.view.updateLocalizationAndTheme(theme: theme)
        }
        if let header = header, header.needShown {
            header.view.updateLocalizationAndTheme(theme: theme)
        }
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
                stack.removeLast()
                last.didRemovedFromStack()
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
                let copy = stack[range]
                stack.removeSubrange(range)
                for controller in copy {
                    controller.didRemovedFromStack()
                }
                show(controller, .none)
            }
        }
    }
    
    public func gotoEmpty(_ animated:Bool = true) -> Void {
        if controller != empty {
            for controller in stack {
                controller.viewWillDisappear(false)
                controller.didRemovedFromStack()
                controller.viewDidDisappear(false)
            }
            while stack.count != 1 {
                stack.removeLast()
            }
            show(empty, animated ? .pop : .none)
        }
    }
    
    public func close(animated:Bool = true) ->Void {
        if stackCount > 1 && !isLocked {
            let controller = stack[0]
            while stack.last != self.empty {
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
    
    public func removeImmediately(_ controller: ViewController, upNext: Bool = true) {
        if let index = self.stack.firstIndex(where: { $0.internalId == controller.internalId }) {
            if index == self.stack.count - 1, upNext {
                if self.stack.count > index {
                    show(self.stack[index - 1], .none)
                } else {
                    show(self.empty, .none)
                }
            } else {
                controller.view.removeFromSuperview()
            }
            self.stack.remove(at: index)
            controller.didRemovedFromStack()
        }
    }
    
    public func index(of controller: ViewController) -> Int? {
        return self.stack.firstIndex(of: controller)
    }
    
    private let depencyReadyDisposable = MetaDisposable()
    
    public func removeImmediately(_ controller: ViewController, depencyReady: ViewController) {
        let ready = depencyReady.ready.get() |> take(1) |> deliverOnMainQueue
        depencyReadyDisposable.set(ready.start(completed: { [weak controller, weak self] in
            guard let controller = controller else {
                return
            }
            self?.removeImmediately(controller)
        }))
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
        
        self.window?.add(swipe: { [weak self] direction, animated -> SwipeHandlerResult in
                        
            guard let `self` = self, self.controller.view.layer?.animationKeys() == nil, let window = self.window else {
                return .failed
            }
            
            if let view = window.contentView!.hitTest(window.contentView!.convert(window.mouseLocationOutsideOfEventStream, from: nil))?.superview {
                if view is HorizontalRowView || view.superview is HorizontalRowView {
                    return .failed
                } else if view.enclosingScrollView is HorizontalScrollView || view.enclosingScrollView is HorizontalTableView {
                    return .failed
                }
            }
            if hasPopover(window) {
                return .failed
            }
            
            
            switch direction {
            case let .left(state):
                
                self.controller.updateSwipingState(state, controller: self.controller, isPrevious: false)
                self.previousController?.updateSwipingState(state, controller: self.controller, isPrevious: true)

                switch state {
                case .start:
                    
                    guard let previous = self.previousController, self.controller.supportSwipes, self.stackCount > 1 && !self.isLocked, self.canSwipeBack else {return .failed}
                    
                    previous.view.frame = NSMakeRect(0, previous.barHeight, self.frame.width, self.frame.height - previous.barHeight)
                    
                    self.containerView.addSubview(previous.view, positioned: .below, relativeTo: self.navigationBar)
                    
                    
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
                    
                    self.addShadowView(.left, controller: self.controller)
                    if previous.bar.has {
                        self.navigationBar.startMoveViews(left: previous.leftBarView, center: previous.centerBarView, right: previous.rightBarView, direction: direction)
                    }
                    self.lock = true
                    return .success(previous)
                case let .swiping(delta, previous):
                    let settings = self.controller.stake
                                        
                    let keepLeft: CGFloat = self.frame.width == settings.keepLeft ? 0 : settings.keepLeft
                    
                    
                    let nPosition = min(max(keepLeft, delta + keepLeft), self.containerView.frame.width)
                    self.controller.view._change(pos: NSMakePoint(nPosition, self.controller.view.frame.minY), animated: false)
                    let previousStart = keepLeft > 0 ? 0 : -round(NSWidth(self.containerView.frame)/3.0)
                    
                    
                    previous.view._change(pos: NSMakePoint(min(previousStart + max(delta, 0) / 3.0, 0), previous.view.frame.minY), animated: false)
                    
                    self.shadowView.setFrameOrigin(nPosition - self.shadowView.frame.width, self.shadowView.frame.minY)
                    
                    self.navigationLeftBorder.setFrameOrigin(nPosition - self.navigationLeftBorder.frame.width, self.navigationLeftBorder.frame.minY)
                    
                    self.shadowView.layer?.opacity = min(1.0 - Float(nPosition / self.containerView.frame.width) + 0.2, 1.0)
                    
                    
                    if previous.bar.has {
                        self.navigationBar.moveViews(left: previous.leftBarView, center: previous.centerBarView, right: previous.rightBarView, direction: direction, percent: nPosition / self.containerView.frame.width)
                    } else {
                        self.navigationBar.setFrameOrigin(nPosition, self.navigationBar.frame.minY)
                    }
                    return .deltaUpdated(available: nPosition - keepLeft)
                    
                case let .success(_, controller):
                    self.lock = false
                    
                    controller.removeBackgroundCap()
                    self.controller.removeBackgroundCap()
                    
                    self.back(forceAnimated: true)
                case let .failed(_, previous):
                    //   CATransaction.begin()
                    let animationStyle = previous.animationStyle
                    let settings = self.controller.stake

                    let keepLeft: CGFloat = self.frame.width == settings.keepLeft ? 0 : settings.keepLeft

                    
                    self.controller.view._change(pos: NSMakePoint(keepLeft, self.controller.frame.minY), animated: animated, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    
                    let previousStart = keepLeft > 0 ? 0 : -round(NSWidth(self.containerView.frame)/3.0)

                    previous.view._change(pos: NSMakePoint(previousStart, previous.view.frame.minY), animated: animated, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self, weak previous] completed in
                        if completed, keepLeft == 0 {
                            previous?.view.removeFromSuperview()
                            self?.controller.removeBackgroundCap()
                            previous?.removeBackgroundCap()
                        }
                    })
                    self.shadowView.change(pos: NSMakePoint(-self.shadowView.frame.width + keepLeft, self.shadowView.frame.minY), animated: animated, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self] completed in
                        self?.shadowView.removeFromSuperview()
                    })
                    
                    self.navigationLeftBorder.change(pos: NSMakePoint(keepLeft - .borderSize, self.navigationLeftBorder.frame.minY), animated: animated, duration: animationStyle.duration, timingFunction: animationStyle.function)

                    
                    self.shadowView.change(opacity: 0, animated: animated, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    if previous.bar.has {
                        self.navigationBar.moveViews(left: previous.leftBarView, center: previous.centerBarView, right: previous.rightBarView, direction: direction, percent: 0, animationStyle: animationStyle)
                    } else {
                        self.navigationBar.change(pos: NSMakePoint(keepLeft, self.navigationBar.frame.minY), animated: animated, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    }
                    self.lock = false
                    //  CATransaction.commit()
                }
            case let .right(state):
                
                self.controller.updateSwipingState(state, controller: self.controller, isPrevious: false)
                self.previousController?.updateSwipingState(state, controller: self.controller, isPrevious: true)

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
                    self.addShadowView(.right, controller: self.controller)
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
                    
                    
                    _new?.view._change(pos: NSMakePoint(self.containerView.frame.width, self.controller.frame.minY), animated: animated, duration: animationStyle.duration, timingFunction: animationStyle.function)
                    self.containerView.contentViews[1]._change(pos: NSMakePoint(0, self.containerView.contentViews[1].frame.minY), animated: animated, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak new, weak self] completed in
                        self?.controller.removeBackgroundCap()
                        new?.view.removeFromSuperview()
                        _new = nil
                    })
                    self.shadowView.change(pos: NSMakePoint(self.containerView.frame.width, self.shadowView.frame.minY), animated: animated, duration: animationStyle.duration, timingFunction: animationStyle.function, completion: { [weak self] completed in
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
    
    open override func scrollup(force: Bool = false) {
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
    
    open override func focusSearch(animated: Bool, text: String? = nil) {
        super.focusSearch(animated: animated)
        if controller.redirectUserInterfaceCalls {
            controller.focusSearch(animated: animated, text: text)
        }
    }
}
