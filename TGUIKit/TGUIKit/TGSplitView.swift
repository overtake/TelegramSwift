//
//  TGSplitView.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation


public struct TGSplitProportion {
    var min:CGFloat = 0;
    var max:CGFloat = 0;
    
    public init(min:CGFloat, max:CGFloat) {
        self.min = min;
        self.max = max;
    }
}

public enum TGSplitViewState : Int {
    case NoneLayout = -1;
    case SingleLayout = 0;
    case DualLayout = 1;
    case TripleLayout = 2;
}


public protocol TGSplitControllerDelegate {
    func splitViewDidNeedSwapToLayout(state:TGSplitViewState) -> Void
    func splitViewDidNeedMinimisize(controller:ViewController) -> Void
    func splitViewDidNeedFullsize(controller:ViewController) -> Void
    func splitViewIsMinimisize(controller:ViewController) -> Bool
}






public class TGSplitView : View {
    
    
    private(set) var state: TGSplitViewState = TGSplitViewState.NoneLayout {
        didSet {
            var notify:Bool = state != oldValue;
            assert(notify);
            if(notify) {
                self.delegate?.splitViewDidNeedSwapToLayout(state: state);
            }
        }
    }
    
    
    public var canChangeState:Bool = true;
    public var delegate:TGSplitControllerDelegate?
    
    
    private var _proportions:[Int:TGSplitProportion] = [Int:TGSplitProportion]()
    private var _startSize:[Int:NSSize] = [Int:NSSize]()
    private var _controllers:[ViewController] = [ViewController]()
    private var _isSingleLayout:Bool?
    private var _layoutProportions:[TGSplitViewState:TGSplitProportion] = [TGSplitViewState:TGSplitProportion]()
    
    private var _startPoint:NSPoint?
    private var _splitSuccess:Bool?
    private var _splitIdx:Int?
    
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override required public init(frame frameRect: NSRect)  {
        super.init(frame: frameRect);
        self.autoresizingMask = [NSAutoresizingMaskOptions.viewWidthSizable, NSAutoresizingMaskOptions.viewHeightSizable]
        self.autoresizesSubviews = false
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    public func addController(controller:ViewController, proportion:TGSplitProportion) ->Void {
        controller.viewWillAppear(false)
        self.addSubview(controller.view);
        _controllers.append(controller);
        _startSize.updateValue(controller.view.frame.size, forKey: controller.internalId);
        _proportions.updateValue(proportion, forKey: controller.internalId)
        controller.viewDidAppear(false)
    }
    
    func removeController(controller:ViewController) -> Void {
        
        controller.viewWillDisappear(false)
        let idx = _controllers.index(of: controller)!;
        
       // assert([NSThread isMainThread]);
        
        if(idx != nil) {
            self.subviews[idx].removeFromSuperview();
            _controllers.remove(at: idx);
            _startSize.removeValue(forKey: controller.internalId);
            _proportions.removeValue(forKey: controller.internalId);
        }
        controller.viewDidDisappear(false)
    }
    
    public func removeAllControllers() -> Void {
        
        var copy:[ViewController] = []
        
        
        for controller in _controllers {
            copy.append(controller)
        }
        
        for controller in copy {
            controller.viewWillDisappear(false)
        }
        
        self.removeAllSubviews();
        _controllers.removeAll();
        _startSize.removeAll();
        _proportions.removeAll();
        
        for controller in copy {
            controller.viewDidDisappear(false)
        }
    }
    
    public func setProportion(proportion:TGSplitProportion, state:TGSplitViewState) -> Void {
        _layoutProportions[state] = proportion;
    }
    
    public func removeProportion(state:TGSplitViewState) -> Void {
        _layoutProportions.removeValue(forKey: state);
        if(_controllers.count > state.rawValue) {
            _controllers.remove(at: state.rawValue)
        }
    }
    
    public func updateStartSize(size:NSSize, controller:ViewController) -> Void {
        _startSize[controller.internalId] = size;
        
        _proportions[controller.internalId] = TGSplitProportion(min:size.width, max:size.height);
        
       update();

    }
    
    public func update() -> Void {
        self.setFrameSize(self.frame.size);
    }
    
    override public func setFrameSize(_ newSize: NSSize) {
        
        super.setFrameSize(newSize);
        
        let s = _layoutProportions[TGSplitViewState.SingleLayout]
        
        
        let singleLayout:TGSplitProportion! = _layoutProportions[TGSplitViewState.SingleLayout]
        let dualLayout:TGSplitProportion! = _layoutProportions[TGSplitViewState.DualLayout]
        let tripleLayout:TGSplitProportion! = _layoutProportions[TGSplitViewState.TripleLayout]
    

        
        if(acceptLayout(prop: singleLayout) && self.canChangeState) {
            if(NSWidth(self.frame) < singleLayout.max ) {
                if(self.state != TGSplitViewState.SingleLayout) {
                    self.state = TGSplitViewState.SingleLayout;
                }
            } else if(acceptLayout(prop: dualLayout)) {
                if(acceptLayout(prop: tripleLayout)) {
                    if(NSWidth(self.frame) >= dualLayout.min && NSWidth(self.frame) <= dualLayout.max) {
                        if(self.state != TGSplitViewState.DualLayout) {
                            self.state = TGSplitViewState.DualLayout;
                        }
                    } else if(self.state != TGSplitViewState.TripleLayout) {
                        self.state = TGSplitViewState.TripleLayout;
                    }
                } else {
                    if(self.state != TGSplitViewState.DualLayout && NSWidth(self.frame) > dualLayout.min) {
                        self.state = TGSplitViewState.DualLayout;
                    }
                }
                
            }

        }
        
        var x:CGFloat = 0;
        
        for (index, obj) in _controllers.enumerated() {
            
            var proportion:TGSplitProportion = _proportions[obj.internalId]!;
            var startSize:NSSize = _startSize[obj.internalId]!;
            var size:NSSize = NSMakeSize(x, NSHeight(self.frame));
            var min:CGFloat  = startSize.width;
            
            
            min = proportion.min;
            
           // if(startSize.width < proportion.min) {
          //      min = proportion.min;
          //  } else if(startSize.width > proportion.max) {
           //     min = NSWidth(self.frame) - x;
          //  }
            
            
            if(proportion.max == CGFloat.greatestFiniteMagnitude && index != _controllers.count-1) {
                
                var m2:CGFloat = 0;
                
                for i:Int in index + 1 ..< _controllers.count - index - 1 {
                    
                    var split:ViewController = _controllers[i];
                    
                    var proportion:TGSplitProportion = _proportions[split.internalId]!;
                    
                    m2+=proportion.min;
                }
                
                min = NSWidth(self.frame) - x - m2;

            }
            
            if(index == _controllers.count - 1) {
                min = NSWidth(self.frame) - x;
            }
            
            size = NSMakeSize(x + min > NSWidth(self.frame) ? (NSWidth(self.frame) - x) : min, NSHeight(self.frame));
            
            var rect:NSRect = NSMakeRect(x, 0, size.width, size.height);
            
            if(!NSEqualRects(rect, obj.view.frame)) {
               // [obj splitViewDidNeedResizeController:rect];
                obj.view.frame = rect;
            }
            
            x+=size.width;
            
        }

    }
    
    
    

    func acceptLayout(prop:TGSplitProportion!) -> Bool {
        return prop != nil ? (prop!.min > 0 && prop!.max > 0) : false;
    }
    
}
