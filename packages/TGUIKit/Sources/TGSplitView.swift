//
//  SplitView.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import AppKit

fileprivate class SplitMinimisizeView : Control {
    
    private var startPoint:NSPoint = NSZeroPoint
    private var startDragging: NSPoint = .zero
    private var acceptAllDrags: Bool = false
    weak var splitView:SplitView?
    override init() {
        super.init()
        userInteractionEnabled = false
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    fileprivate override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        checkCursor()
    }
    
    
    func checkCursor() {
        if let splitView = splitView {
            if let minimisize = splitView.delegate?.splitViewIsCanMinimisize(), minimisize {
                if mouseInside() || (NSEvent.pressedMouseButtons & (1 << 0)) != 0  {
                    if let cursor = splitView.delegate?.splitResizeCursor(at: self.frame.origin.offsetBy(dx: 5, dy: 0)) {
                        cursor.set()
                    } else {
                        if splitView.state == .minimisize {
                            NSCursor.resizeRight.set()
                        } else {
                            NSCursor.resizeLeft.set()
                        }
                    }
                  
                } else {
                    NSCursor.arrow.set()
                }
            }
        }
    }
    
    fileprivate override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        checkCursor()
    }
    
    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        checkCursor()
    }
    
    
    fileprivate override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        checkCursor()
    }
    
    fileprivate override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        if let splitView = splitView {
            if let minimisize = splitView.delegate?.splitViewIsCanMinimisize(), minimisize {
                checkCursor()
                
                let current = splitView.convert(event.locationInWindow, from: nil)
                
                if startDragging == .zero {
                    startDragging = current
                    acceptAllDrags = false
                }
                
                if abs(startDragging.x - current.x) > frame.width / 2 || abs(startDragging.y - current.y) > frame.width / 2 || acceptAllDrags {
                    acceptAllDrags = true
                    splitView.delegate?.splitViewShouldResize(at: current)
                    
                    if current.x <= 100, splitView.state != .minimisize {
                        splitView.needMinimisize()
                        startPoint = current
                    } else if current.x >= 100, splitView.state == .minimisize {
                        splitView.needFullsize()
                        startPoint = current
                    } else {
                        splitView.resize(to: current)
                    }
                }
            }
            
        }
    }
    
    private func notifyTableEndResize(in view: NSView) {
        for view in view.subviews {
            if let view = view as? TableView {
                view.layoutItems()
            } else {
                notifyTableEndResize(in: view)
            }
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
        startPoint = .zero
        startDragging = .zero
        acceptAllDrags = false
    }
    
    fileprivate override func mouseUp(with event: NSEvent) {
        startPoint = .zero
        startDragging = .zero
        acceptAllDrags = false
        if let splitView = splitView {
            notifyTableEndResize(in: splitView)
        }
    }
    
    fileprivate override func mouseDown(with event: NSEvent) {
        if let splitView = splitView {
            startPoint = splitView.convert(event.locationInWindow, from: nil)
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let splitView = splitView {
            if let drawBorder = splitView.delegate?.splitViewDrawBorder(), drawBorder {
                ctx.setFillColor(presentation.colors.border.cgColor)
                ctx.fill(NSMakeRect(floorToScreenPixels(backingScaleFactor, frame.width / 2), 0, .borderSize, frame.height))
            }
        }
    }
}

public struct SplitProportion {
    var min:CGFloat = 0;
    var max:CGFloat = 0;
    
    public init(min:CGFloat, max:CGFloat) {
        self.min = min;
        self.max = max;
    }
}

public enum SplitViewState : Int {
    case none = -1;
    case single = 0;
    case dual = 1;
    case triple = 2;
    case minimisize = 3
}


public protocol SplitViewDelegate : class {
    func splitViewDidNeedSwapToLayout(state:SplitViewState) -> Void
    func splitViewDidNeedMinimisize(controller:ViewController) -> Void
    func splitViewDidNeedFullsize(controller:ViewController) -> Void
    func splitViewIsCanMinimisize() -> Bool
    func splitViewDrawBorder() -> Bool
    
    func splitViewShouldResize(at point: NSPoint) -> Void
    
    func splitResizeCursor(at point: NSPoint) -> NSCursor?
}

public extension SplitViewDelegate {
    func splitViewShouldResize(at point: NSPoint) -> Void {
        
    }
    func splitResizeCursor(at point: NSPoint) -> NSCursor? {
        return nil
    }
}


public class SplitView : View {
    
    private let minimisizeOverlay:SplitMinimisizeView = SplitMinimisizeView()
    private let container:View
    private var forceNotice:Bool = false
    public var state: SplitViewState = .none {
        didSet {
            let notify:Bool = state != oldValue;
           // assert(notify);
            if(notify) {
                self.delegate?.splitViewDidNeedSwapToLayout(state: state);
            }
            if state != .none {
                if state == .dual || state == .minimisize {
                    if let _ = container.subviews.first {
                        if minimisizeOverlay.superview == nil {
                            addSubview(minimisizeOverlay)
                        }
                    }
                } else {
                    minimisizeOverlay.removeFromSuperview()
                }
            } else {
                minimisizeOverlay.removeFromSuperview()
            }
        }
    }
    
    public var mustMinimisize: Bool = false
    
    public var canChangeState:Bool = true;
    public weak var delegate:SplitViewDelegate?
    
    
    private var _proportions:[Int:SplitProportion] = [:]
    private var _startSize:[Int:NSSize] = [Int:NSSize]()
    fileprivate var _controllers:[WeakReference<ViewController>] = []
    private var _issingle:Bool?
    private var _layoutProportions:[SplitViewState:SplitProportion] = [:]
    
    private var _splitIdx:Int?
    
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    required public init(frame frameRect: NSRect)  {
        container = View(frame: NSMakeRect(0,0,frameRect.width, frameRect.height))
        super.init(frame: frameRect);
        self.autoresizesSubviews = true
        self.autoresizingMask = [.width, .height]
        container.autoresizesSubviews = false
        container.autoresizingMask = [.width, .height]
        addSubview(container)
        minimisizeOverlay.splitView = self

    }
    
    public override var backgroundColor: NSColor {
        didSet {
            container.backgroundColor = backgroundColor
            minimisizeOverlay.needsDisplay = true
        }
    }

    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    public func addController(controller:ViewController, proportion:SplitProportion) ->Void {
        controller._frameRect = NSMakeRect(0, 0, proportion.min, frame.height)
        container.addSubview(controller.view);
        controller.viewWillAppear(false)
        _controllers.append(WeakReference(value: controller));
        _startSize.updateValue(controller.view.frame.size, forKey: controller.internalId);
        _proportions.updateValue(proportion, forKey: controller.internalId)
        controller.viewDidAppear(false)
    }
    
    func removeController(controller:ViewController) -> Void {
        
        controller.viewWillDisappear(false)
        let idx = _controllers.firstIndex(where: { $0.value == controller });
        if let idx = idx {
            container.subviews[idx].removeFromSuperview();
            _controllers.remove(at: idx);
            _startSize.removeValue(forKey: controller.internalId);
            _proportions.removeValue(forKey: controller.internalId);
        }
        controller.viewDidDisappear(false)
    }
    
    public func removeAllControllers() -> Void {
        
        var copy:[ViewController] = []
        
        
        for controller in _controllers {
            if let value = controller.value {
                copy.append(value)
            }
        }
        
        for controller in copy {
            controller.viewWillDisappear(false)
        }
        
        container.removeAllSubviews();
        _controllers.removeAll();
        _startSize.removeAll();
        _proportions.removeAll();
        
        for controller in copy {
            controller.viewDidDisappear(false)
        }
    }
    
    public func setProportion(proportion:SplitProportion, state:SplitViewState) -> Void {
        _layoutProportions[state] = proportion;
    }
    
    public func removeProportion(state:SplitViewState) -> Void {
        _layoutProportions.removeValue(forKey: state);
        if(_controllers.count > state.rawValue) {
            _controllers.remove(at: state.rawValue)
        }
    }
    
    public func updateStartSize(size:NSSize, controller:ViewController) -> Void {
        _startSize[controller.internalId] = size;
        _proportions[controller.internalId] = SplitProportion(min:size.width, max:size.height);
        needsLayout = true
    }
    
    public func update(_ forceNotice:Bool = false) -> Void {
        Queue.mainQueue().justDispatch {
            self.forceNotice = forceNotice
            self.needsLayout = true
        }
    }
    
    public var nextLayout: SplitViewState {
        
        let single:SplitProportion! = _layoutProportions[.single]
        let dual:SplitProportion! = _layoutProportions[.dual]
        let triple:SplitProportion! = _layoutProportions[.triple]
        
        if acceptLayout(prop: single) && canChangeState && !mustMinimisize {
            if frame.width < single.max  {
                if self.state != .single {
                    return .single;
                }
            } else if acceptLayout(prop: dual) {
                if acceptLayout(prop: triple) {
                    if frame.width >= dual.min && frame.width <= dual.max {
                        if state != .dual {
                            return .dual;
                        }
                    } else if state != .triple {
                        return .triple;
                    }
                } else {
                    if state != .dual && frame.width >= dual.min {
                        return .dual;
                    }
                }
                
            }
        } else if mustMinimisize, self.state != .minimisize {
            return .minimisize
        }
        return self.state
    }
    
    public override func layout() {
        super.layout()
        
        //assert(!_controllers.isEmpty)
        
        let single:SplitProportion! = _layoutProportions[.single]
        let dual:SplitProportion! = _layoutProportions[.dual]
        let triple:SplitProportion! = _layoutProportions[.triple]
        
        
        
        if acceptLayout(prop: single) && canChangeState && !mustMinimisize {
            if frame.width < single.max  {
                if self.state != .single {
                    self.state = .single;
                }
            } else if acceptLayout(prop: dual) {
                if acceptLayout(prop: triple) {
                    if frame.width >= dual.min && frame.width <= dual.max {
                        if state != .dual {
                            state = .dual;
                        }
                    } else if state != .triple {
                        self.state = .triple;
                    }
                } else {
                    if state != .dual && frame.width >= dual.min {
                        self.state = .dual;
                    }
                }
                
            }
        } else if mustMinimisize, self.state != .minimisize {
            self.state = .minimisize
        }
        
        if forceNotice {
            forceNotice = false
            self.delegate?.splitViewDidNeedSwapToLayout(state: state)
        }
        
        var x:CGFloat = 0;
        
        for (index, obj) in _controllers.enumerated() {
            if let obj = obj.value {
                let proportion:SplitProportion = _proportions[obj.internalId]!;
                let startSize:NSSize = _startSize[obj.internalId]!;
                var size:NSSize = NSMakeSize(x, frame.height);
                var _min:CGFloat  = startSize.width;
                _min = proportion.min;
                if(proportion.max == CGFloat.greatestFiniteMagnitude && index != _controllers.count-1) {
                    var m2:CGFloat = 0;
                    for i:Int in index + 1 ..< _controllers.count - index  {
                        let split:ViewController? = _controllers[i].value;
                        if let split = split {
                            let proportion:SplitProportion = _proportions[split.internalId]!;
                            m2+=proportion.min;
                        }
                    }
                    _min = frame.width - x - m2;
                }
                if index < _controllers.count - 1, state != .minimisize {
                    _min = min(_min, frame.width - 350)
                }
                if(index == _controllers.count - 1) {
                    _min = frame.width - x;
                }
                
                size = NSMakeSize(x + _min > frame.width ? (frame.width - x) : _min, frame.height);
                let rect:NSRect = NSMakeRect(x, 0, size.width, size.height);
                
                if(!NSEqualRects(rect, obj.view.frame)) {
                    obj.view.frame = rect;
                }
                
                x+=size.width;
            }
        }
        
        //assert(state != .none)
        if state != .none {
            if state == .dual || state == .minimisize {
                if let first = container.subviews.first {
                    minimisizeOverlay.frame = NSMakeRect(first.frame.maxX - 5, 0, 10, frame.height)
                }
                
            }
        }
    }
    
    
    
    public func needFullsize() {
        self.state = .none
        self.needsLayout = true
    }
    
    public func needMinimisize() {
        self.state = .minimisize
        self.needsLayout = true
        
    }
    
    func resize(to point: NSPoint) {
        //NSLog("\(point)")
    }
    

    func acceptLayout(prop:SplitProportion!) -> Bool {
        return prop != nil ? (prop!.min > 0 && prop!.max > 0) : false;
    }
    
}
