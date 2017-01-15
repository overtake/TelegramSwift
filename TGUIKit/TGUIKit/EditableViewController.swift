//
//  EditableViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 05/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa


public enum ViewControllerState : Equatable {
    case Edit
    case Normal
    case Some
}

//public func ==(lhs:ViewControllerState, rhs:ViewControllerState) -> Bool {
//    if case let .Normal(ltext) = lhs {
//        if case let .Normal(rtext) = rhs {
//            return ltext == rtext
//        }
//    }
//    if case let .Edit(ltext) = lhs {
//        if case let .Edit(rtext) = rhs {
//            return ltext == rtext
//        }
//    }
//    if case let .Some(ltext) = lhs {
//        if case let .Some(rtext) = rhs {
//            return ltext == rtext
//        }
//    }
//    return false
//}

open class EditableViewController<T>: GenericViewController<T> where T: NSView {
    
    
    var editBar:TextButtonBarView = TextButtonBarView(text: "", style: navigationButtonStyle, alignment:.Right)

    public var state:ViewControllerState = .Normal {
        didSet {
            if state != oldValue {
                updateEditStateTitles()
            }
        }
    }
    
    override open func getRightBarViewOnce() -> BarView {
        return editBar
    }
    
    open override var enableBack: Bool {
        return true
    }
    
    open func changeState() ->Void {
       
        if case .Normal = state {
            self.state = ViewControllerState.Edit
        } else {
            self.state = ViewControllerState.Normal
        }
        
        update(with:state)
    }
    
    func updateEditStateTitles() -> Void {
        switch state {
        case .Edit:
            editBar.button.set(text: localizedString("Navigation.Done"), for: .Normal)
        case .Normal:
            editBar.button.set(text: localizedString("Navigation.Edit"), for: .Normal)
        case .Some:
            editBar.button.set(text: localizedString("Navigation.Some"), for: .Normal)
        }
        
        self.editBar.needsLayout = true
    }
    
    func addHandler() -> Void {
        editBar.button.set (handler:{[weak self] _ in
            if let strongSelf = self {
                strongSelf.changeState()
            }
        }, for:.Click)
    }
    
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addHandler()
    }
    
    override public init() {
        super.init()
        addHandler()
    }
    
    open func update(with state:ViewControllerState) -> Void {
        updateEditStateTitles()
    }
    
    public func set(editable:Bool) ->Void {
        editBar.button.isHidden = !editable
    }
    
    open override func updateNavigation(_ navigation: NavigationViewController?) {
        super.updateNavigation(navigation)
        if let navigation = navigation {
            rightBarView = editBar
            updateEditStateTitles()
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
}
