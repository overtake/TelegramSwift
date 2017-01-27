//
//  TextButtonBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 05/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum TextBarAligment {
    case Left
    case Right
    case Center
}

open class TextButtonBarView: BarView {

    private(set) public var button:TitleButton
    
    public var alignment:TextBarAligment = .Center
    
    public init(text:String, style:ControlStyle = navigationButtonStyle, alignment:TextBarAligment = .Center) {
    
        
        button = TitleButton(frame:NSZeroRect)
        button.style = style
        button.set(text: text, for: .Normal)

        super.init()
        
        self.alignment = alignment
        
        
        self.addSubview(button)
        
    }
    
    open override func layout() {
        switch alignment {
        case .Center:
            button.sizeToFit(NSZeroSize,NSMakeSize(frame.width, frame.height - .borderSize))
        case .Left:
            button.sizeToFit(NSZeroSize,NSMakeSize(frame.width, frame.height - .borderSize))
        case .Right:
            button.sizeToFit()
            let f = focus(button.frame.size)
            button.setFrameOrigin(NSMakePoint(frame.width - button.frame.width - 20.0, f.minY))
            
        }
        super.layout()
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}
