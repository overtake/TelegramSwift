//
//  SearchView.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

let searchImage = #imageLiteral(resourceName: "Icon_SearchField").precomposed()
let clearImage = #imageLiteral(resourceName: "Icon_SearchClear").precomposed()


class SearchTextField: NSTextField {
    
}

public enum SearchFieldState {
    case None;
    case Focus;
}

public final class SearchInteractions {
    var stateModified:(SearchFieldState) -> Void
    var textModified:(String?) -> Void
    
    public init(_ state:@escaping(SearchFieldState)->Void, _ text:@escaping(String?)->Void) {
        stateModified = state
        textModified = text
    }
}

public class SearchView: OverlayControl, NSTextFieldDelegate {
    
    public private(set) var state:SearchFieldState = .None

    private var input:SearchTextField = SearchTextField()
    
    private var lock:Bool = false
    
    private var clear:ImageButton = ImageButton()
    private var search:ImageView = ImageView()
    
    private var placeholder:TextViewLabel = TextViewLabel()
    
    private var animateContainer:View = View()
    
    private let inset:CGFloat = 6.0
    private let leftInset:CGFloat = 10.0
    
    public var searchInteractions:SearchInteractions?
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = TGColor.grayBackground
        self.layer?.cornerRadius = TGColor.cornerRadius
        
        
        input.isBordered = false
        input.isBezeled = false
        input.focusRingType = .none
        input.frame = self.bounds
        input.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        input.backgroundColor = NSColor.clear
        input.delegate = self
        
        input.placeholderAttributedString = NSAttributedString.initialize(string: localizedString("SearchField.Search"), color: TGColor.grayText, font: systemFont(TGFont.textSize), coreText: false)
        
        input.font = systemFont(TGFont.textSize)
        input.textColor = TGColor.textColor
        input.isHidden = true

        
        animateContainer.backgroundColor = TGColor.clear
        
        placeholder.attributedString = input.placeholderAttributedString
        placeholder.backgroundColor = TGColor.grayBackground
        placeholder.sizeToFit()
        animateContainer.addSubview(placeholder)
        
        search.frame = NSMakeRect(0, 0, searchImage.backingSize.width, searchImage.backingSize.height)
        search.image = searchImage
        animateContainer.addSubview(search)
        
        self.animateContainer.setFrameSize(NSMakeSize(NSWidth(placeholder.frame) + NSWidth(search.frame) + inset, max(NSHeight(placeholder.frame), NSHeight(search.frame))))
        
        placeholder.centerY(nil, x: NSWidth(search.frame) + inset)
        search.centerY()
        
        addSubview(animateContainer)
        addSubview(input)
        
        
        clear.set(image: clearImage, for: .Normal)
        clear.backgroundColor = TGColor.clear
        
        
        clear.set(handler: {[weak self] (event) in
            
            self?.change(state: .None, true)
            
        }, for: .Click)
        
        clear.frame = NSMakeRect(NSWidth(self.frame) - inset - clearImage.backingSize.width, 0, clearImage.backingSize.width, clearImage.backingSize.height)
        addSubview(clear)
        clear.centerY()
        clear.isHidden = true

        animateContainer.center()
        
        self.set(handler: {[weak self] (event) in
            
            if let strongSelf = self {
                strongSelf.change(state:strongSelf.state == .None ? .Focus : .None,true)
            }
            
        }, for: .Click)
    }
    
    
    public override func controlTextDidChange(_ obj: Notification) {
        
        if let searchInteractions = searchInteractions {
            searchInteractions.textModified(input.stringValue)
        }
    }
    
    public override func controlTextDidEndEditing(_ obj: Notification) {
        change(state: .None, true)
    }
    
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
    }
    
    func change(state:SearchFieldState, _ animated:Bool) -> Void {
        
        if state != self.state && !lock {
            self.state = state
            
            if let searchInteractions = searchInteractions {
                searchInteractions.stateModified(state)
            }
            
            lock = true
            
            if state == .Focus {
                
                self.kitWindow?.set(escape: {[weak self] () -> Bool in
                    if let strongSelf = self {
                        return strongSelf.changeResponder()
                    }
                    return false
                    
                }, with: self, priority:.high)
                
                let inputInset = leftInset + NSWidth(search.frame) + inset - 2
                
                self.input.frame = NSMakeRect(inputInset, NSMinY(self.animateContainer.frame) - 1, NSWidth(self.frame) - inputInset - inset, NSHeight(placeholder.frame))
                
                animateContainer.layer?.animate(from: NSMinX(animateContainer.frame) as NSNumber, to: leftInset as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion: true, additive: false, completion: {[weak self] (complete) in
                    self?.input.isHidden = false
                    self?.input.becomeFirstResponder()
                    self?.placeholder.isHidden = true
                    self?.lock = false
                })
                
                animateContainer.setFrameOrigin(NSMakePoint(leftInset, NSMinY(self.animateContainer.frame)))
                
                clear.isHidden = false
                clear.layer?.opacity = 1.0
                clear.layer?.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration)
            }
            
            if state == .None {
                
                self.kitWindow?.remove(object: self, for: .Escape)
                
                self.input.isHidden = true
                self.input.stringValue = ""
                self.input.resignFirstResponder()
                self.placeholder.isHidden = false
                
                animateContainer.center()
                
                animateContainer.layer?.animate(from: leftInset as NSNumber, to: NSMinX(animateContainer.frame) as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion: true)
                
                clear.layer?.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion:true, additive:false, completion: {[weak self] (complete) in
                    self?.clear.isHidden = true
                    self?.lock = false
                })
                
                clear.layer?.opacity = 0.0

            }

        }
  
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        switch state {
        case .None:
            animateContainer.center()
         case .Focus:
            animateContainer.setFrameOrigin(NSMakePoint(leftInset, NSMinY(self.animateContainer.frame)))
        }
    }

    public func changeResponder() -> Bool {
        change(state: state == .None ? .Focus : .None, true)
        return true
    }
    
    public func cancel(_ animated:Bool) -> Void {
        change(state: .None, animated)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
