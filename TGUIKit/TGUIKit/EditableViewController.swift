//
//  EditableViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 05/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa


public enum ViewControllerState : Equatable {
    case Edit(String)
    case Normal(String)
    case Some(String)
}

public func ==(lhs:ViewControllerState, rhs:ViewControllerState) -> Bool {
    if case let .Normal(ltext) = lhs {
        if case let .Normal(rtext) = rhs {
            return ltext == rtext
        }
    }
    if case let .Edit(ltext) = lhs {
        if case let .Edit(rtext) = rhs {
            return ltext == rtext
        }
    }
    if case let .Some(ltext) = lhs {
        if case let .Some(rtext) = rhs {
            return ltext == rtext
        }
    }
    return false
}

open class EditableViewController: ViewController {
    
    var editBar:TextButtonBarView = TextButtonBarView(text: "", style: navigationButtonStyle, alignment:.Right)

    public var state:ViewControllerState! {
        didSet {
            if state != oldValue {
                update(with: state)
            }
        }
    }
    
    open func change(state:ViewControllerState) ->Void {
        if case let .Normal(text) = state {
            self.state = ViewControllerState.Edit(NSLocalizedString("Navigation.Done", comment:""))
        } else {
            self.state = ViewControllerState.Normal(NSLocalizedString("Navigation.Edit", comment:""))
        }
    }
    
    func addHandler() -> Void {
        editBar.button.set (handler:{[weak self] in
            if let strongSelf = self {
                strongSelf.change(state:strongSelf.state)
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
    
    func update(with state:ViewControllerState) -> Void {
        
        switch state {
        case let .Edit(text):
            editBar.button.set(text: text, for: .Normal)
        case let .Normal(text):
            editBar.button.set(text: text, for: .Normal)
        case let .Some(text):
            editBar.button.set(text: text, for: .Normal)
        }
        
        self.editBar.setFrameSize(self.editBar.frame.size)
        
        
    }
    
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rightBarView = editBar
        self.state = .Normal(NSLocalizedString("Navigation.Edit", comment:""))
    }
    
}
