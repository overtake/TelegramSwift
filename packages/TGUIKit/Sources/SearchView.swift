//
//  SearchView.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import ColorPalette


public class SearchTextField: NSTextView {

    
    public init() {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.autoresizingMask = []
        self.autoresizesSubviews = false
        textContainer?.maximumNumberOfLines = 1
        
    }
    public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        textContainer?.maximumNumberOfLines = 1
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func resignFirstResponder() -> Bool {
        self.delegate?.textDidEndEditing?(Notification(name: NSControl.textDidChangeNotification))
        return super.resignFirstResponder()
    }
    
    override public func becomeFirstResponder() -> Bool {
        self.delegate?.textDidBeginEditing?(Notification(name: NSControl.textDidChangeNotification))
        return super.becomeFirstResponder()
    }
    
    override public func paste(_ sender: Any?) {
        
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
    public let responder: Bool
    public init(state:SearchFieldState, request:String?, responder: Bool = false) {
        self.state = state
        self.request = request ?? ""
        self.responder = responder
    }
}

public final class SearchInteractions {
    public let stateModified:(SearchState, Bool) -> Void
    public let textModified:(SearchState) -> Void
    public let responderModified:(SearchState) -> Void
    public init(_ state:@escaping(SearchState, Bool)->Void, _ text:@escaping(SearchState)->Void, responderModified:@escaping(SearchState) -> Void = {_ in}) {
        self.stateModified = state
        self.textModified = text
        self.responderModified = responderModified
    }
}

public final class CustomSearchController {
    
    fileprivate var clickHandlerIdentifier: UInt32 = 0
    fileprivate let icon: CGImage
    public let clickHandler:(Control, @escaping([String], CGImage)->Void)->Void
    fileprivate let deleteTag:(Int)->Void
    public init(clickHandler:@escaping(Control, @escaping([String], CGImage)->Void)->Void, deleteTag:@escaping(Int)->Void, icon: CGImage) {
        self.clickHandler = clickHandler
        self.icon = icon
        self.deleteTag = deleteTag
    }
    
}

open class SearchView: OverlayControl, NSTextViewDelegate {
    
    public private(set) var state:SearchFieldState = .None
    
    
    public func updateTags(_ tags: [String], _ image: CGImage) {
        
        for tag in self.tags {
            tag.layer?.animateScaleSpring(from: 1.0, to: 0.3, duration: 0.2)
            tag.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak tag] _ in
                  tag?.removeFromSuperview()
             })
        }
        self.tags.removeAll()

        var x: CGFloat = 35
        
        for title in tags {
            let tagView = TextButton()
            tagView.animates = false
            tagView.set(font: .normal(12), for: .Normal)
            tagView.set(color: presentation.colors.underSelectedColor, for: .Normal)
            tagView.set(background: presentation.colors.accent.darker(), for: .Normal)
            tagView.set(text: title, for: .Normal)
            
            tagView.set(background: presentation.colors.accent.lighter(), for: .Highlight)
            
            tagView.set(handler: { [weak self] control in
                guard let `self` = self else {
                    return
                }
                for tag in self.tags {
                    if tag == control {
                        tag.isSelected = !tag.isSelected
                    } else {
                        tag.isSelected = false
                    }
                }
            }, for: .Click)
            
            _ = tagView.sizeToFit(NSMakeSize(6, 6), thatFit: false)
            tagView.layer?.cornerRadius = 6
            addSubview(tagView)
            tagView.centerY(x: x)
            tagView.layer?.animateAlpha(from: 0, to: 1.0, duration: 0.2)
           // tagView.layer?.animateScaleSpring(from: 0.6, to: 1.0, duration: 0.2)
            self.tags.append(tagView)
            
            x += tagView.frame.width + 5
        }
        
        inputContainer._change(pos: NSMakePoint(placeholderTextInset + 8, inputContainer.frame.minY), animated: true)
        
        let pHidden = !input.string.isEmpty || !tags.isEmpty
        if placeholder.isHidden != pHidden {
            placeholder.isHidden = pHidden
        }
        search.set(image: image, for: .Normal)
//        _ = search.sizeToFit()
    }
    
    public var customSearchControl: CustomSearchController? {
        didSet {
            if let oldValue = oldValue {
                search.removeHandler(oldValue.clickHandlerIdentifier)
                updateTags([], presentation.search.searchImage)
            }
            if let customSearchControl = customSearchControl {
                customSearchControl.clickHandlerIdentifier = search.set(handler: { [weak customSearchControl, weak self] control in
                    customSearchControl?.clickHandler(control, { titles, image  in
                        self?.updateTags(titles, image)
                    })
                }, for: .Click)
                search.set(image: customSearchControl.icon, for: .Normal)
            }
        }
    }
    

    private(set) public var input:NSTextView = SearchTextField()
    
    private var lock:Bool = false
    
    private var tags: [TextButton] = []
    
    private let clear:ImageButton = ImageButton()
    private let search:ImageButton = ImageButton()
    private let progressIndicator:ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 18, 18))
    private let placeholder:TextViewLabel = TextViewLabel()
    
    private let animateContainer:View = View()
    
    public let inset:CGFloat = 10
    public let leftInset:CGFloat = 10.0
    
    public var searchInteractions:SearchInteractions?
    
    private let _searchValue:ValuePromise<SearchState> = ValuePromise(SearchState(state: .None, request: nil), ignoreRepeated: true)
    
    public var searchValue: Signal<SearchState, NoError> {
        return _searchValue.get()
    }
    
    public var shouldUpdateTouchBarItemIdentifiers: (()->[Any])?
    
    
    private let inputContainer = HorizontalScrollView(frame:.zero)
    
    public var isLoading:Bool = false {
        didSet {
            if oldValue != isLoading {
                self.updateLoading()
                needsLayout = true
            }
        }
    }
    
    public var searchTheme: SearchTheme? = nil {
        didSet {
            updateLocalizationAndTheme(theme: presentation)
        }
    }
    
    override open func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        inputContainer.background = .clear
        inputContainer.backgroundColor = .clear
        input.textColor = searchTheme?.textColor ?? theme.search.textColor
        input.backgroundColor = .clear
        
        search.autohighlight = false
        search.scaleOnClick = true
        
        clear.autohighlight = false
        clear.scaleOnClick = true

        let theme = searchTheme ?? presentation.search
        
        placeholder.attributedString = .initialize(string: theme.placeholder(), color: theme.placeholderColor, font: .normal(.text))
        self.backgroundColor = theme.backgroundColor
        placeholder.sizeToFit()
        search.frame = NSMakeRect(0, 0, 20, 20)
        
        if let custom = customSearchControl {
            search.set(image: custom.icon, for: .Normal)
        } else {
            search.set(image: theme.searchImage, for: .Normal)
        }
        
        animateContainer.setFrameSize(NSMakeSize(placeholder.frame.width + placeholderTextInset, max(21, search.frame.height)))
        
        clear.set(image: theme.clearImage, for: .Normal)
       _ =  clear.sizeToFit()
        
        placeholder.centerY(x: placeholderTextInset, addition: -1)
        search.centerY(addition: -1)
        input.insertionPointColor = theme.textColor
        progressIndicator.progressColor = theme.textColor
        needsLayout = true

    }
    
    open var startTextInset: CGFloat {
        return search.frame.width + inset / 2
    }
    
    open var placeholderTextInset: CGFloat {
        if !tags.isEmpty {
            let width: CGFloat = tags.reduce(0, { current, value in
                return current + value.frame.width + 5
            })
            return startTextInset + width
        } else {
            return startTextInset
        }
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = .grayBackground
        self.layer?.cornerRadius = 6
        if #available(OSX 10.12.2, *) {
            input.allowsCharacterPickerTouchBarItem = false
        } 
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

        
        //input.placeholderAttributedString = NSAttributedString.initialize(string: localizedString("SearchField.Search"), color: .grayText, font: .normal(.text))
        
        input.font = .normal(.text)
        input.textColor = .text
        input.isHidden = true
        inputContainer.isHidden = true
        input.drawsBackground = false
        inputContainer.documentView = input
        animateContainer.backgroundColor = .clear
        
        placeholder.sizeToFit()
        
        animateContainer.addSubview(placeholder)
        animateContainer.addSubview(search)
        
        self.animateContainer.setFrameSize(NSMakeSize(NSWidth(placeholder.frame) + search.frame.width + inset / 2, max(21, search.frame.height)))
        
        placeholder.centerY(x: NSWidth(search.frame) + inset / 2, addition: -1)
        search.centerY(addition: -1)
        
        search.animates = false
        search.isEventLess = true
        search.userInteractionEnabled = false
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
        
        updateLocalizationAndTheme(theme: presentation)
        
        
        
        progressIndicator.set(handler: { [weak self] _ in
            self?.cancelSearch()
        }, for: .Click)
       
    }
    
    @available(OSX 10.12.2, *)
    public func textView(_ textView: NSTextView, shouldUpdateTouchBarItemIdentifiers identifiers: [NSTouchBarItem.Identifier]) -> [NSTouchBarItem.Identifier] {
        return self.shouldUpdateTouchBarItemIdentifiers?() as? [NSTouchBarItem.Identifier] ?? identifiers
    }
    
    open func cancelSearch() {
        if self.query.isEmpty {
            if !tags.isEmpty {
                customSearchControl?.deleteTag(tags.count - 1)
            } else {
                self.change(state: .None, true)
            }
        } else {
            
            self.setString("")
        }
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
        
        let value = SearchState(state: state, request: trimmed.trimmed, responder: self.input == window?.firstResponder)
        searchInteractions?.textModified(value)
        _searchValue.set(value)
        

        let pHidden = !input.string.isEmpty || !tags.isEmpty
        if placeholder.isHidden != pHidden {
            placeholder.isHidden = pHidden
        }
        
        
        let iHidden = !(state == .Focus && !input.string.isEmpty)
        
        if input.isHidden != iHidden {
            window?.makeFirstResponder(input)
        }
                
        for tag in tags {
            tag.isSelected = false
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
    
    open func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(deleteBackward(_:)) {
            if query.isEmpty {
                var removed: Bool = false
                for (i, tag) in tags.enumerated() {
                    if tag.isSelected {
                        customSearchControl?.deleteTag(i)
                        removed = true
                    }
                }
                if !removed, let last = tags.last {
                    last.isSelected = true
                }
                return true
            }
        }
        
        return false
    }
    
    public func textViewDidChangeSelection(_ notification: Notification) {
        needsLayout = true
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
        let value = SearchState(state: state, request: self.query, responder: false)
        searchInteractions?.responderModified(value)
        _searchValue.set(value)
        if isEmpty && tags.isEmpty {
            change(state: .None, true)
        }
        
        self.kitWindow?.removeAllHandlers(for: self)
        self.kitWindow?.removeObserver(for: self)
    }
    
    open func didBecomeResponder() {
        let value = SearchState(state: state, request: self.query, responder: true)
        searchInteractions?.responderModified(SearchState(state: state, request: self.query, responder: true))
        _searchValue.set(value)

        change(state: .Focus, true)

        self.kitWindow?.set(escape: { [weak self] _ -> KeyHandlerResult in
            if let strongSelf = self {
                strongSelf.setString("")
                return strongSelf.changeResponder() ? .invoked : .rejected
            }
            return .rejected
            
        }, with: self, priority: .modal)
        
        self.kitWindow?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.state == .Focus {
                return .invokeNext
            }
            return .rejected
        }, with: self, for: .RightArrow, priority: .modal)
        
        self.kitWindow?.set(handler: { [weak self] _ -> KeyHandlerResult in
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
            
            search.isEventLess = state != .Focus
            search.userInteractionEnabled = state == .Focus
            
            let text = input.string.trimmingCharacters(in: CharacterSet(charactersIn: "\n\r")).trimmed
            let value = SearchState(state: state, request: state == .None ? nil : text, responder: self.input == window?.firstResponder)
            searchInteractions?.stateModified(value, animated)

            _searchValue.set(value)
            
            lock = true
            
            if state == .Focus {
                
                self.input.isHidden = false
                self.inputContainer.isHidden = false
                self.window?.makeFirstResponder(self.input)
                self.lock = false
               

                clear.isHidden = false
                clear.layer?.opacity = 1.0
                if animated {
                    clear.layer?.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration)
                }
            }
            
            if state == .None {
                updateTags([], presentation.search.searchImage)
                
                self.kitWindow?.removeAllHandlers(for: self)
                self.kitWindow?.removeObserver(for: self)
               
                self.input.isHidden = true
                inputContainer.isHidden = true
                self.input.string = ""
                self.window?.makeFirstResponder(nil)
                self.placeholder.isHidden = false
                
                self.clear.isHidden = true
                self.lock = false
                
                if animated {
                    clear.layer?.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration, removeOnCompletion:true, additive:false)
                }
                clear.layer?.opacity = 0.0
            }
            updateLoading()
            
            self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
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
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    public var isLeftOrientated: Bool = false
    private var placeholderInset: CGFloat? = nil
    
    public var holderSize: NSSize {
        return NSMakeSize(leftInset + placeholder.frame.width + 20 + 5, frame.height)
    }
    public var searchSize: NSSize {
        return NSMakeSize(leftInset + 25, frame.height)
    }
    
    public func movePlaceholder(_ inset: CGFloat?, opacity: CGFloat, transition: ContainedViewLayoutTransition, moveForce: Bool = false) -> Void {
        self.placeholderInset = inset
        transition.updateAlpha(view: placeholder, alpha: opacity)
        
        if moveForce {
            self.updateLayout(size: frame.size, transition: .immediate)
        } else {
            self.updateLayout(size: frame.size, transition: transition)
        }
    }
    public func updateSearchHolderVisibility(visible: Bool, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(view: search, alpha: visible ? 1 : 0)
    }
    
    public func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        if self.isLeftOrientated {
            transition.updateFrame(view: self.animateContainer, frame: animateContainer.centerFrameY(x: leftInset))
        } else {
            switch state {
            case .None:
                transition.updateFrame(view: self.animateContainer, frame: animateContainer.centerFrame())
            case .Focus:
                transition.updateFrame(view: self.animateContainer, frame: animateContainer.centerFrameY(x: leftInset))
            }
        }
        
        var placeholderFrame = placeholder.centerFrameY(addition: -1)
        if let placeholderInset = placeholderInset {
            placeholderFrame.origin.x = placeholderTextInset + placeholderInset
        } else {
            placeholderFrame.origin.x = placeholderTextInset
        }
        transition.updateFrame(view: placeholder, frame: placeholderFrame)
        transition.updateFrame(view: clear, frame: clear.centerFrameY(x: size.width - inset - clear.frame.width))
        transition.updateFrame(view: progressIndicator, frame: progressIndicator.centerFrameY(x: size.width - inset - progressIndicator.frame.width + 2))
        
        let tagsWidth: CGFloat = tags.reduce(0, { current, value in
            return current + value.frame.width + 10
        })
        
        
        let inputRect = CGRect(origin: CGPoint(x: placeholderTextInset + 8, y: animateContainer.frame.minY + 2), size: NSMakeSize(size.width - (inset * 3) - (clear.frame.width * 2) - tagsWidth - 5, animateContainer.frame.height))
        
        
        var inputSize = NSZeroSize
        let inputPoint = NSZeroPoint

        if let storage = input.textStorage {
            let size = storage.size()
            inputSize = NSMakeSize(max(size.width + 10, inputRect.width), size.height)
        }
        transition.updateFrame(view: inputContainer, frame: inputRect)
        transition.updateFrame(view: input, frame: CGRect(origin: inputPoint, size: inputSize))
        transition.updateFrame(view: search, frame: search.centerFrameY(addition: -1))
        
        
    }
    
    /*
     switch state {
     case .None:
         animateContainer.center()
     case .Focus:
         animateContainer.centerY(x: leftInset)
     }
     placeholder.centerY(addition: -1)
     clear.centerY(x: frame.width - inset - clear.frame.width)
     progressIndicator.centerY(x: frame.width - inset - progressIndicator.frame.width + 2)
     
     let tagsWidth: CGFloat = tags.reduce(0, { current, value in
         return current + value.frame.width + 10
     })
     
     inputContainer.setFrameSize(NSMakeSize(frame.width - (inset * 3) - (clear.frame.width * 2) - tagsWidth, inputContainer.frame.height))
     inputContainer.setFrameOrigin(placeholderTextInset + 8, inputContainer.frame.minY)
     search.centerY(addition: -1)
     */

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
    
    open override func change(size: NSSize, animated: Bool = true, _ save: Bool = true, removeOnCompletion: Bool = false, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion: ((Bool) -> Void)? = nil) {
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
