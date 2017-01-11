//
//  SearchView.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa


public struct SearchTheme {
    let searchImage:CGImage
    let clearImage:CGImage
    let placeholder:String
    public init(_ searchImage:CGImage, _ clearImage:CGImage, _ placeholder:String) {
        self.searchImage = searchImage
        self.clearImage = clearImage
        self.placeholder = placeholder
    }
}

class SearchTextField: NSTextView {

    
    
    override func resignFirstResponder() -> Bool {
        self.delegate?.textDidEndEditing!(Notification(name: Notification.Name.NSControlTextDidChange))
        return super.resignFirstResponder()
    }
    
    override func becomeFirstResponder() -> Bool {
        self.delegate?.textDidBeginEditing!(Notification(name: Notification.Name.NSControlTextDidChange))
        return super.becomeFirstResponder()
    }
    
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

public class SearchView: OverlayControl, NSTextViewDelegate {
    
    public private(set) var state:SearchFieldState = .None

    private(set) public var input:NSTextView = SearchTextField()
    
    private var lock:Bool = false
    
    private var clear:ImageButton = ImageButton()
    private var search:ImageView = ImageView()
    
    private var placeholder:TextViewLabel = TextViewLabel()
    
    private var animateContainer:View = View()
    
    private let inset:CGFloat = 6
    private let leftInset:CGFloat = 10.0
    
    public var searchInteractions:SearchInteractions?
    private let theme:SearchTheme
    
    required public init(frame frameRect: NSRect, theme:SearchTheme) {
        self.theme = theme
        super.init(frame: frameRect)
        self.backgroundColor = .grayBackground
        self.layer?.cornerRadius = .cornerRadius
        
        
       // input.isBordered = false
       // input.isBezeled = false
        input.focusRingType = .none
        input.frame = self.bounds
        input.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        input.backgroundColor = NSColor.clear
        input.delegate = self
        input.isRichText = false
        //input.placeholderAttributedString = NSAttributedString.initialize(string: localizedString("SearchField.Search"), color: .grayText, font: .normal(.text), coreText: false)
        
        input.font = .normal(.text)
        input.textColor = .textColor
        input.isHidden = true

        
        animateContainer.backgroundColor = .clear
        
        placeholder.attributedString = NSAttributedString.initialize(string: theme.placeholder, color: .grayText, font: .normal(.text), coreText: true)
        placeholder.backgroundColor = .grayBackground
        placeholder.sizeToFit()
        animateContainer.addSubview(placeholder)
        
        search.frame = NSMakeRect(0, 0, theme.searchImage.backingSize.width, theme.searchImage.backingSize.height)
        search.image = theme.searchImage
        animateContainer.addSubview(search)
        
        self.animateContainer.setFrameSize(NSMakeSize(NSWidth(placeholder.frame) + NSWidth(search.frame) + inset, max(NSHeight(placeholder.frame), NSHeight(search.frame))))
        
        placeholder.centerY(nil, x: NSWidth(search.frame) + inset)
        search.centerY()
        
        addSubview(animateContainer)
        addSubview(input)
        
        
        clear.set(image: theme.clearImage, for: .Normal)
        clear.backgroundColor = .clear
        
        
        clear.set(handler: {[weak self] (event) in
            
            self?.change(state: .None, true)
            
        }, for: .Click)
        
        clear.frame = NSMakeRect(NSWidth(self.frame) - inset - theme.clearImage.backingSize.width, 0, theme.clearImage.backingSize.width, theme.clearImage.backingSize.height)
        addSubview(clear)
        
        clear.isHidden = true

        animateContainer.center()
        
        self.set(handler: {[weak self] (event) in
            
            if let strongSelf = self {
                strongSelf.change(state:strongSelf.state == .None ? .Focus : .None,true)
            }
            
        }, for: .Click)
    }
    
    public func textDidChange(_ notification: Notification) {
        input.string = input.string?.trimmingCharacters(in: CharacterSet(charactersIn: "\n\r"))
        if let searchInteractions = searchInteractions {
            searchInteractions.textModified(input.string?.trimmingCharacters(in: CharacterSet(charactersIn: "\n\r")))
        }
        placeholder.isHidden = input.string != nil && !input.string!.isEmpty
    }
    
    public func textDidEndEditing(_ notification: Notification) {
        didResignResponder()
    }
    
    public func textDidBeginEditing(_ notification: Notification) {
        didBecomeResponder()
    }

    public func didResignResponder() {
        change(state: .None, true)
    }
    
    public func didBecomeResponder() {
        change(state: .Focus, true)
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
                
                self.kitWindow?.set(escape: {[weak self] () -> KeyHandlerResult in
                    if let strongSelf = self {
                        return strongSelf.changeResponder() ? .invoked : .rejected
                    }
                    return .rejected
                    
                }, with: self, priority: .high)
                
                self.kitWindow?.set(responder: {[weak self] () -> NSResponder? in
                    return self?.input
                }, with: self, priority: .high)
                
                let inputInset = leftInset + NSWidth(search.frame) + inset - 5
                
                self.input.frame = NSMakeRect(inputInset, NSMinY(self.animateContainer.frame) - 1, NSWidth(self.frame) - inputInset - inset, NSHeight(placeholder.frame))
                
                animateContainer.layer?.animate(from: NSMinX(animateContainer.frame) as NSNumber, to: leftInset as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion: true, additive: false, completion: {[weak self] (complete) in
                    self?.input.isHidden = false
                    self?.window?.makeFirstResponder(self?.input)
                    self?.lock = false
                })
                
                animateContainer.setFrameOrigin(NSMakePoint(leftInset, NSMinY(self.animateContainer.frame)))
                
                clear.isHidden = false
                clear.layer?.opacity = 1.0
                clear.layer?.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration)
            }
            
            if state == .None {
                
                self.kitWindow?.remove(object: self, for: .Escape)
                self.kitWindow?.removeObserver(for: self)
                self.input.isHidden = true
                self.input.string = ""
                self.window?.makeFirstResponder(nil)
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
    
    
    public override func layout() {
        super.layout()
        switch state {
        case .None:
            animateContainer.center()
        case .Focus:
            animateContainer.setFrameOrigin(NSMakePoint(leftInset, NSMinY(self.animateContainer.frame)))
        }
        clear.frame = NSMakeRect(frame.width - inset - theme.clearImage.backingSize.width, clear.frame.minY, theme.clearImage.backingSize.width, theme.clearImage.backingSize.height)
        clear.centerY()
    }

    public func changeResponder() -> Bool {
        change(state: state == .None ? .Focus : .None, true)
        return true
    }
    
    public var query:String {
        return self.input.string ?? ""
    }
    
    public func cancel(_ animated:Bool) -> Void {
        change(state: .None, animated)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}
