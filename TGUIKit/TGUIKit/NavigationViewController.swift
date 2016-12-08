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
        super.init()
        self.autoresizingMask = [.viewWidthSizable]
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

public final class NavigationHeader {
    let height:CGFloat
    let initializer:(NavigationHeader)->NavigationHeaderView
    weak var navigation:NavigationViewController?
    private var _view:NavigationHeaderView?
    private let disposable:MetaDisposable = MetaDisposable()
    private(set) var isShown:Bool = false
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
    
    public func show(_ animated:Bool) {
        assert(navigation != nil)
        needShown = true
        if isShown {
            return
        }
        isShown = true
        if let navigation = navigation {
            let view = self.view
            let height = self.height
            disposable.set((view.ready.get() |> take(1)).start(next: {[weak self] (ready) in
                var contentInset = navigation.controller.bar.height + height
                view.frame = NSMakeRect(0, navigation.controller.bar.height, navigation.frame.width, height)
                navigation.containerView.addSubview(view, positioned: .below, relativeTo: navigation.navigationBar)
                navigation.controller.view.change(size: NSMakeSize(navigation.frame.width, navigation.frame.height - contentInset), animated: false)
                navigation.controller.view.change(pos: NSMakePoint(0, contentInset), animated: false)
                if animated {
                    view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }))
        }
        
    }
    
    public func hide(_ animated:Bool) {
        assert(navigation != nil)
        if !isShown {
            return
        }
        needShown = false
        isShown = false
        
        if let navigation = navigation {
            if animated {
                view.layer?.zPosition = 10
                view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion:false, completion:{ [weak self] (completed) in
                    self?._view?.removeFromSuperview()
                    self?._view = nil
                })
            } else {
                view.removeFromSuperview()
                _view = nil
            }
            navigation.controller.view.frame = NSMakeRect(0, navigation.controller.bar.height, navigation.frame.width, navigation.frame.height - navigation.controller.bar.height)
        }
        
    }
}

open class NavigationViewController: ViewController, CALayerDelegate,CAAnimationDelegate {

    public private(set) var modalAction:NavigationModalAction?
    
    var stack:[ViewController] = [ViewController]()
    var lock:Bool = false
    
    public var empty:ViewController {
        didSet {
            empty.navigationController = self
            empty.loadViewIfNeeded()
            let prev = self.stack.last
            self.stack.remove(at: 0)
            self.stack.insert(empty, at: 0)
            
            if prev == oldValue {
                controller = empty
                oldValue.removeFromSuperview()
                empty.view.frame = self.bounds
                self.addSubview(empty.view)
            }
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
    
    fileprivate var navigationBar:NavigationBarView = NavigationBarView()
    
    var pushDisposable:MetaDisposable = MetaDisposable()
    var popDisposable:MetaDisposable = MetaDisposable()
    
    private(set) public var header:NavigationHeader?
    
    public func set(header:NavigationHeader?) {
        self.header?.hide(false)
        header?.navigation = self
        self.header = header
    }
    
    open override func loadView() {
        super.loadView();
        self.view.autoresizesSubviews = true
        controller._frameRect = bounds
        controller.viewWillAppear(false)
        controller.navigationController = self
        
        containerView.addSubview(navigationBar)
        
        navigationBar.frame = NSMakeRect(0, 0, NSWidth(containerView.frame), controller.bar.height)
        controller.view.frame = NSMakeRect(0, controller.bar.height , NSWidth(containerView.frame), NSHeight(containerView.frame) - controller.bar.height)
        
        navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, style: .none, animationStyle: controller.animationStyle)

        containerView.addSubview(controller.view)
        Queue.mainQueue().justDispatch {
            self.controller.viewDidAppear(false)
        }
        
        viewDidLoad()
        
    }
    
    
    open override var canBecomeResponder: Bool {
        return false
    }
    open func currentControllerDidChange() {
        
    }
    
    public init(_ empty:ViewController) {
        self.empty = empty
        self.controller = empty
        self.stack.append(controller)
        super.init()
    }
    
    public var stackCount:Int {
        return stack.count
    }
    
    deinit {
        self.popDisposable.dispose()
        self.pushDisposable.dispose()
    }
    
    public func push(_ controller:ViewController, _ animated:Bool = true) -> Void {
        
//        if isLocked {
//            return
//        }
        
        
        controller.navigationController = self
        controller.loadViewIfNeeded(self.bounds)
        
        self.pushDisposable.set((controller.ready.get() |> take(1)).start(next: {[weak self] _ in
            if let strongSelf = self {
                strongSelf.lock = true
                controller.navigationController = strongSelf
                
                if let index = strongSelf.stack.index(of: controller) {
                    strongSelf.stack.remove(at: index)
                }
                
                strongSelf.stack.append(controller)
                
                strongSelf.show(controller, animated && strongSelf.stack.count > 1 ? .push : .none)
            }
        }))
    }
    
    
    func show(_ controller:ViewController,_ style:ViewControllerStyle) -> Void {
        
        var previous:ViewController = self.controller;
        self.controller = controller
        controller.navigationController = self

        
        if(previous == controller) {
            previous.viewWillDisappear(false);
            previous.viewDidDisappear(false);
            
            controller.viewWillAppear(false);
            controller.viewDidAppear(false);
            controller.becomeFirstResponder();
            
            return;
        }
        
        self.navigationBar.frame = NSMakeRect(0, 0, NSWidth(containerView.frame), controller.bar.height)
        
        var contentInset = controller.bar.height
        
        if let header = header, header.needShown {
            header.view.frame = NSMakeRect(0, contentInset, containerView.frame.width, header.height)
            containerView.addSubview(header.view)
            contentInset += header.height
        }
        
        controller.view.removeFromSuperview()
        controller.view.frame = NSMakeRect(0, contentInset , NSWidth(containerView.frame), NSHeight(containerView.frame) - contentInset)
        
        
        
        var pfrom:CGFloat = 0, pto:CGFloat = 0, nto:CGFloat = 0, nfrom:CGFloat = 0;
        
        switch style {
        case .push:
            nfrom = NSWidth(containerView.frame) 
            nto = 0
            pfrom = 0
            pto = -100//round(NSWidth(self.frame)/3.0)
            containerView.addSubview(controller.view, positioned: .above, relativeTo: previous.view)
        case .pop:
            nfrom = -round(NSWidth(containerView.frame)/3.0)
            nto = 0
            pfrom = 0
            pto = NSWidth(containerView.frame)
            previous.view.setFrameOrigin(NSMakePoint(pto, previous.frame.minY))
            containerView.addSubview(controller.view, positioned: .below, relativeTo: previous.view)
        case .none:
            previous.viewWillDisappear(false);
            previous.view.removeFromSuperview()
            containerView.addSubview(controller.view)
            controller.viewWillAppear(false);
            previous.viewDidDisappear(false);
            controller.viewDidAppear(false);
            controller.becomeFirstResponder();
            
            self.navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, style: style, animationStyle: controller.animationStyle)
            lock = false
            
            return // without animations
        }
        
        if previous.removeAfterDisapper, let index = stack.index(of: previous) {
            self.stack.remove(at: index)
        }
        
        navigationBar.removeFromSuperview()
        containerView.addSubview(navigationBar)
        
        
        previous.viewWillDisappear(true);
        controller.viewWillAppear(true);
        
        
        CATransaction.begin()

        
        self.navigationBar.switchViews(left: controller.leftBarView, center: controller.centerBarView, right: controller.rightBarView, style: style, animationStyle: controller.animationStyle)
        
         previous.view.layer?.animate(from: pfrom as NSNumber, to: pto as NSNumber, keyPath: "position.x", timingFunction: kCAMediaTimingFunctionSpring, duration: previous.animationStyle.duration, removeOnCompletion: true, additive: false, completion: {[weak self] (completed) in
            
            previous.view.removeFromSuperview()
            previous.viewDidDisappear(true);

            self?.lock = false
        });
        

        controller.view.layer?.animate(from: nfrom as NSNumber, to: nto as NSNumber, keyPath: "position.x", timingFunction: kCAMediaTimingFunctionSpring, duration: controller.animationStyle.duration, removeOnCompletion: true, additive: false, completion: { (completed) in
            
            controller.viewDidAppear(true);
            controller.becomeFirstResponder()
        });
        
        
        CATransaction.commit()
        
    }
    
    public var containerView: NSView {
        return view
    }
    
    public func back(animated:Bool = true) -> Void {
        if stackCount > 1 && !isLocked {
            var controller = stack[stackCount - 2]
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
    
    public func removeModalAction() {
        self.modalAction?.view?.removeFromSuperview()
        self.modalAction = nil
    }
    
    
}
