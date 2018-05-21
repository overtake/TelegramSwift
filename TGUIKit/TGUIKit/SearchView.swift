//
//  SearchView.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac


class SearchTextField: NSTextView {
    
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        return viewEnableTouchBar ? super.makeTouchBar() : nil
    }
    
    override func resignFirstResponder() -> Bool {
        self.delegate?.textDidEndEditing?(Notification(name: NSControl.textDidChangeNotification))
        return super.resignFirstResponder()
    }
    
    override func becomeFirstResponder() -> Bool {
        self.delegate?.textDidBeginEditing?(Notification(name: NSControl.textDidChangeNotification))
        return super.becomeFirstResponder()
    }
    
    override func paste(_ sender: Any?) {
        
        let text = NSPasteboard.general.string(forType: .string)?.nsstring
        if let text = text {
            var modified = text.replacingOccurrences(of: "\n", with: " ")
            modified = text.replacingOccurrences(of: "\n", with: " ")
            appendText(modified)
            self.delegate?.textDidChange?(Notification(name: NSControl.textDidChangeNotification))
        }
    }
    
}

public enum SearchFieldState {
    case None;
    case Focus;
}

public struct SearchState : Equatable {
    public let state:SearchFieldState
    public let request:String
    public init(state:SearchFieldState, request:String?) {
        self.state = state
        self.request = request ?? ""
    }
}

public func ==(lhs:SearchState, rhs:SearchState) -> Bool {
    return lhs.state == rhs.state && lhs.request == rhs.request
}

public final class SearchInteractions {
    public let stateModified:(SearchState) -> Void
    public let textModified:(SearchState) -> Void
    
    public init(_ state:@escaping(SearchState)->Void, _ text:@escaping(SearchState)->Void) {
        stateModified = state
        textModified = text
    }
}

open class SearchView: OverlayControl, NSTextViewDelegate {
    
    public private(set) var state:SearchFieldState = .None
    
    

    private(set) public var input:NSTextView = SearchTextField()
    
    private var lock:Bool = false
    
    private let clear:ImageButton = ImageButton()
    private let search:ImageView = ImageView()
    private let progressIndicator:ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 18, 18))
    private let placeholder:TextViewLabel = TextViewLabel()
    
    private let animateContainer:View = View()
    
    public let inset:CGFloat = 6
    public let leftInset:CGFloat = 10.0
    
    public var searchInteractions:SearchInteractions?

    
    private let inputContainer = View()
    
    public var isLoading:Bool = false {
        didSet {
            if oldValue != isLoading {
                self.updateLoading()
                needsLayout = true
            }
        }
    }
    
    override open func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        inputContainer.backgroundColor = .clear
        input.textColor = presentation.search.textColor
        input.backgroundColor = presentation.colors.background
        placeholder.attributedString = .initialize(string: presentation.search.placeholder(), color: presentation.search.placeholderColor, font: .normal(.text))
        placeholder.backgroundColor = presentation.search.backgroundColor
        self.backgroundColor = presentation.search.backgroundColor
        placeholder.sizeToFit()
        search.frame = NSMakeRect(0, 0, presentation.search.searchImage.backingSize.width, presentation.search.searchImage.backingSize.height)
        search.image = presentation.search.searchImage
        animateContainer.setFrameSize(NSMakeSize(placeholder.frame.width + placeholderTextInset, max(21, search.frame.height)))
        
        clear.set(image: presentation.search.clearImage, for: .Normal)
       _ =  clear.sizeToFit()
        
        placeholder.centerY(x: placeholderTextInset + 2)
        search.centerY()
        input.insertionPointColor = presentation.search.textColor
        
        needsLayout = true

    }
    
    open var startTextInset: CGFloat {
        return search.frame.width + inset
    }
    
    open var placeholderTextInset: CGFloat {
        return startTextInset
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = .grayBackground
        self.layer?.cornerRadius = .cornerRadius

        progressIndicator.isHidden = true
//        progressIndicator.numberOfLines = 8
//        progressIndicator.innerMargin = 3;
//        progressIndicator.widthOfLine = 3;
//        progressIndicator.lengthOfLine = 6;
       // input.isBordered = false
       // input.isBezeled = false
        input.focusRingType = .none
        input.frame = self.bounds
        input.autoresizingMask = [.width, .height]
        input.backgroundColor = NSColor.clear
        input.delegate = self
        input.isRichText = false
        
        input.textContainer?.widthTracksTextView = true
        input.textContainer?.heightTracksTextView = false
        
      //  input.maxSize = NSMakeSize(100, .greatestFiniteMagnitude)
        input.isHorizontallyResizable = false
        input.isVerticallyResizable = false

        
        //input.placeholderAttributedString = NSAttributedString.initialize(string: localizedString("SearchField.Search"), color: .grayText, font: .normal(.text), coreText: false)
        
        input.font = .normal(.text)
        input.textColor = .text
        input.isHidden = true
        input.drawsBackground = false
        
        animateContainer.backgroundColor = .clear
        
        placeholder.sizeToFit()
        animateContainer.addSubview(placeholder)
        
        animateContainer.addSubview(search)
        
        self.animateContainer.setFrameSize(NSMakeSize(NSWidth(placeholder.frame) + search.frame.width + inset, max(21, search.frame.height)))
        
        placeholder.centerY(nil, x: NSWidth(search.frame) + inset)
        search.centerY()
        
        inputContainer.addSubview(input)
        addSubview(animateContainer)
        addSubview(inputContainer)
        inputContainer.backgroundColor = .clear
        clear.backgroundColor = .clear
        
        
        clear.set(handler: { [weak self] _ in
            self?.cancelSearch()
        }, for: .Click)
        
        addSubview(clear)
        
        clear.isHidden = true

        animateContainer.center()
        
        self.set(handler: {[weak self] (event) in
            if let strongSelf = self {
                strongSelf.change(state: .Focus , true)
            }
        }, for: .Click)
        
        updateLocalizationAndTheme()
       
    }
    
    open func cancelSearch() {
        change(state: .None, true)
    }
    
    open func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if let trimmed = replacementString?.trimmed, trimmed.isEmpty, affectedCharRange.min == 0 && affectedCharRange.max == 0, textView.string.isEmpty {
            return false
        }
        if replacementString == "\n" {
            return false
        }
        return true
    }
    
    
    
    open func textDidChange(_ notification: Notification) {
        
        let trimmed = input.string.trimmingCharacters(in: CharacterSet(charactersIn: "\n\r"))
        if trimmed != input.string {
            self.setString(trimmed)
            return
        }
        
        if let searchInteractions = searchInteractions {
            searchInteractions.textModified(SearchState(state: state, request: trimmed))
        }
        let pHidden = !input.string.isEmpty
        if placeholder.isHidden != pHidden {
            placeholder.isHidden = pHidden
        }
        
        needsLayout = true
        
        let iHidden = !(state == .Focus && !input.string.isEmpty)
        if input.isHidden != iHidden {
          //  input.isHidden = iHidden
            window?.makeFirstResponder(input)
        }
    }
    
    open override func mouseUp(with event: NSEvent) {
        if isLoading {
            let point = convert(event.locationInWindow, from: nil)
            if NSPointInRect(point, progressIndicator.frame) {
                setString("")
            } else {
                super.mouseUp(with: event)
            }
        } else {
            super.mouseUp(with: event)
        }
    }
    
    
    public func textViewDidChangeSelection(_ notification: Notification) {
        if let storage = input.textStorage {
            let size = storage.size()
            
            let inputInset = placeholderTextInset + 8
            
            let defWidth = frame.width - inputInset - inset - clear.frame.width - 10
          //  input.sizeToFit()
            input.setFrameSize(max(size.width + 10, defWidth), input.frame.height)
           // inputContainer.setFrameSize(inputContainer.frame.width, input.frame.height)
            if let layout = input.layoutManager, !input.string.isEmpty {
                let index = max(0, input.selectedRange().max - 1)
                let point = layout.location(forGlyphAt: layout.glyphIndexForCharacter(at: index))
                
                let additionalInset: CGFloat
                if index + 2 < input.string.length {
                    let nextPoint = layout.location(forGlyphAt: layout.glyphIndexForCharacter(at: index + 2))
                    additionalInset = nextPoint.x - point.x
                } else {
                    additionalInset = 8
                }
                
                if defWidth < size.width && point.x > defWidth {
                    input.setFrameOrigin(floorToScreenPixels(scaleFactor: backingScaleFactor, defWidth - point.x - additionalInset), input.frame.minY)
                    if input.frame.maxX < inputContainer.frame.width {
                        input.setFrameOrigin(inputContainer.frame.width - input.frame.width + 4, input.frame.minY)
                    }
                } else {
                    input.setFrameOrigin(0, input.frame.minY)
                }
            } else {
                input.setFrameOrigin(0, input.frame.minY)
            }
            needsLayout = true
        }
    }
    
    open func textDidEndEditing(_ notification: Notification) {
        didResignResponder()
    }
    
    open func textDidBeginEditing(_ notification: Notification) {
        didBecomeResponder()
    }

    open var isEmpty: Bool {
        return query.isEmpty
    }
    
    open func didResignResponder() {
        if isEmpty {
            change(state: .None, true)
        }
        self.kitWindow?.removeAllHandlers(for: self)
        self.kitWindow?.removeObserver(for: self)
    }
    
    open func didBecomeResponder() {
        change(state: .Focus, true)
        
        self.kitWindow?.set(escape: {[weak self] () -> KeyHandlerResult in
            if let strongSelf = self {
                return strongSelf.changeResponder() ? .invoked : .rejected
            }
            return .rejected
            
        }, with: self, priority: .modal)
        
        self.kitWindow?.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.state == .Focus {
                return .invokeNext
            }
            return .rejected
        }, with: self, for: .RightArrow, priority: .modal)
        
        self.kitWindow?.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.state == .Focus {
                return .invokeNext
            }
            return .rejected
            }, with: self, for: .LeftArrow, priority: .modal)
        
        self.kitWindow?.set(responder: {[weak self] () -> NSResponder? in
            return self?.input
        }, with: self, priority: .modal)
    }
    
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    

    
    open func change(state:SearchFieldState, _ animated:Bool) -> Void {
        
        if state != self.state && !lock {
            self.state = state
            
            if let searchInteractions = searchInteractions {
                let text = input.string.trimmingCharacters(in: CharacterSet(charactersIn: "\n\r"))
                searchInteractions.stateModified(SearchState(state: state, request: state == .None ? nil : text))
            }
            
            lock = true
            
            if state == .Focus {
                
               window?.makeFirstResponder(input)
                
                let inputInset = placeholderTextInset + 8
                
                let fromX:CGFloat = animateContainer.frame.minX
                animateContainer.centerY(x: leftInset)

                inputContainer.frame = NSMakeRect(inputInset, animateContainer.frame.minY + 2, frame.width - inputInset - inset - clear.frame.width - 6, animateContainer.frame.height)
                input.frame = inputContainer.bounds
                
                input.isHidden = false
                
                if  animated {
                    
                    inputContainer.layer?.animate(from: fromX as NSNumber, to: inputContainer.frame.minX as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration)
                    
                    animateContainer.layer?.animate(from: fromX as NSNumber, to: leftInset as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion: true, additive: false, completion: {[weak self] (complete) in
                        self?.input.isHidden = false
                        self?.window?.makeFirstResponder(self?.input)
                        self?.lock = false
                    })
                } else {
                    self.input.isHidden = false
                    self.window?.makeFirstResponder(self.input)
                    self.lock = false
                }
               

                clear.isHidden = false
                clear.layer?.opacity = 1.0
                if animated {
                    clear.layer?.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration)
                }
            }
            
            if state == .None {
                
                self.kitWindow?.removeAllHandlers(for: self)
                self.kitWindow?.removeObserver(for: self)
               
                self.input.isHidden = true
                self.input.string = ""
                self.window?.makeFirstResponder(nil)
                self.placeholder.isHidden = false
                
                animateContainer.center()
                if animated {
                    animateContainer.layer?.animate(from: leftInset as NSNumber, to: NSMinX(animateContainer.frame) as NSNumber, keyPath: "position.x", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion: true)
                    
                    clear.layer?.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion:true, additive:false, completion: {[weak self] (complete) in
                        self?.clear.isHidden = true
                        self?.lock = false
                    })
                } else {
                    clear.isHidden = true
                    lock = false
                }
                
                clear.layer?.opacity = 0.0
            }
            updateLoading()
            self.needsLayout = true
        }
  
    }
    
    open override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            if isEmpty {
                change(state: .None, false)
            }
            self.kitWindow?.removeAllHandlers(for: self)
            self.kitWindow?.removeObserver(for: self)
        }
    }
    
    
    func updateLoading() {
        if isLoading && state == .Focus {
            if progressIndicator.superview == nil {
                addSubview(progressIndicator)
            }
            progressIndicator.isHidden = false
            clear.isHidden = true
            rightAccessory.isHidden = true
            progressIndicator.animates = true
        } else {
            progressIndicator.animates = false
            progressIndicator.removeFromSuperview()
            progressIndicator.isHidden = true
            clear.isHidden = self.state == .None || !clearVisibility
            rightAccessory.isHidden = self.state == .None
        }
        if window?.firstResponder == input {
            window?.makeFirstResponder(input)
        }
    }
    private var clearVisibility: Bool = true
    
    public func updateClearVisibility(_ visible: Bool) {
        clearVisibility = visible
        clear.isHidden = !visible || isLoading
    }
    
    open var rightAccessory: NSView {
        return clear
    }
    
    
    open override func layout() {
        super.layout()
        switch state {
        case .None:
            animateContainer.center()
        case .Focus:
            animateContainer.centerY(x: leftInset)
        }
        placeholder.centerY()
        clear.centerY(x: frame.width - inset - clear.frame.width)
        progressIndicator.centerY(x: frame.width - inset - progressIndicator.frame.width + 2)
        inputContainer.setFrameOrigin(placeholderTextInset + 8, inputContainer.frame.minY)
        search.centerY()
    }

    public func changeResponder(_ animated:Bool = true) -> Bool {
        if state == .Focus {
            cancelSearch()
        } else {
            change(state: .Focus, animated)
        }
        return true
    }
    
    deinit {
        self.kitWindow?.removeAllHandlers(for: self)
        self.kitWindow?.removeObserver(for: self)
    }
    
    public var query:String {
        return self.input.string
    }
    
    open override func change(size: NSSize, animated: Bool = true, _ save: Bool = true, removeOnCompletion: Bool = false, duration: Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion: ((Bool) -> Void)? = nil) {
        super.change(size: size, animated: animated, save, duration: duration, timingFunction: timingFunction)
        clear.change(pos: NSMakePoint(frame.width - inset - clear.frame.width, clear.frame.minY), animated: animated)
    }
    

    public func setString(_ string:String) {
        self.input.string = string
        textDidChange(Notification(name: NSText.didChangeNotification))
        needsLayout = true
    }
    
    public func cancel(_ animated:Bool) -> Void {
        change(state: .None, animated)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
