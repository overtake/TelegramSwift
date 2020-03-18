//
//  TokenizedView.swift
//  TGUIKit
//
//  Created by keepcoder on 07/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit


public struct SearchToken : Equatable {
    public let name:String
    public let uniqueId:Int64
    public init(name:String, uniqueId: Int64) {
        self.name = name
        self.uniqueId = uniqueId
    }
}

public func ==(lhs:SearchToken, rhs: SearchToken) -> Bool {
    return lhs.name == rhs.name && lhs.uniqueId == rhs.uniqueId
}

private class TokenView : Control {
    fileprivate let token:SearchToken
    private var isFailed: Bool = false
    private let dismiss: ImageButton = ImageButton()
    private let nameView: TextView = TextView()
    fileprivate var immediatlyPaste: Bool = true
    override var isSelected: Bool {
        didSet {
            updateLocalizationAndTheme(theme: presentation)
        }
    }

    init(_ token: SearchToken, maxSize: NSSize, onDismiss:@escaping()->Void, onSelect: @escaping()->Void) {
        self.token = token
        super.init()
        self.layer?.cornerRadius = 6
        let layout = TextViewLayout(.initialize(string: token.name, color: .white, font: .normal(.title)), maximumNumberOfLines: 1)
        layout.measure(width: maxSize.width - 30)
        self.nameView.update(layout)
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        setFrameSize(NSMakeSize(layout.layoutSize.width + 30, maxSize.height))
        dismiss.autohighlight = false
        updateLocalizationAndTheme(theme: presentation)
        needsLayout = true
        addSubview(nameView)
        addSubview(dismiss)
        dismiss.set(handler: { _ in
            onDismiss()
        }, for: .Click)
        set(handler: { _ in
            onSelect()
        }, for: .Click)
    }
    
    fileprivate func setFailed(_ isFailed: Bool, animated: Bool) {
        self.isFailed = isFailed
        self.updateLocalizationAndTheme(theme: presentation)
        if isFailed {
            self.shake()
        }
    }
    
    fileprivate var isPerfectSized: Bool {
        return nameView.layout?.isPerfectSized ?? false
    }
    
    override func change(size: NSSize, animated: Bool = true, _ save: Bool = true, removeOnCompletion: Bool = false, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion: ((Bool) -> Void)? = nil) {
        nameView.layout?.measure(width: size.width - 30)
        
        let size = NSMakeSize(min(((nameView.layout?.layoutSize.width ?? 0) + 30), size.width), size.height)
        
        super.change(size: size, animated: animated, save, duration: duration, timingFunction: timingFunction)
        
        let point = focus(dismiss.frame.size)
        dismiss.change(pos: NSMakePoint(frame.width - 5 - dismiss.frame.width, point.minY), animated: animated)
        
        nameView.update(nameView.layout)
    }

    override func layout() {
        super.layout()
        nameView.centerY(x: 5)
        nameView.setFrameOrigin(5, nameView.frame.minY - 1)
        dismiss.centerY(x: frame.width - 5 - dismiss.frame.width)
    }
    
    var _backgroundColor: NSColor {
        
        var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
        
        var redSelected = presentation.colors.redUI

        redSelected.getRed(&r, green: &g, blue: &b, alpha: &a)
        redSelected =  NSColor(red: min(r + 0.1, 1.0), green: min(g + 0.1, 1.0), blue: min(b + 0.1, 1.0), alpha: a)
        
        return isSelected ? (isFailed ? redSelected : presentation.colors.accentSelect) : (isFailed ? presentation.colors.redUI : presentation.colors.accent)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        dismiss.set(image: #imageLiteral(resourceName: "Icon_SearchClear").precomposed(NSColor.white.withAlphaComponent(0.7)), for: .Normal)
        dismiss.set(image: #imageLiteral(resourceName: "Icon_SearchClear").precomposed(NSColor.white), for: .Highlight)
        _ = dismiss.sizeToFit()
        
        nameView.backgroundColor = _backgroundColor
        self.background = _backgroundColor
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

public protocol TokenizedProtocol : class {
    func tokenizedViewDidChangedHeight(_ view: TokenizedView, height: CGFloat, animated: Bool)
}

public class TokenizedView: ScrollView, AppearanceViewProtocol, NSTextViewDelegate {
    private var tokens:[SearchToken] = []
    private var failedTokens:[Int64] = []
    private let container: View = View()
    private let input:SearchTextField = SearchTextField()
    private(set) public var state: SearchFieldState = .None {
        didSet {
            stateValue.set(state)
        }
    }
    public let stateValue: ValuePromise<SearchFieldState> = ValuePromise(.None, ignoreRepeated: true)
    private var selectedIndex: Int? = nil {
        didSet {
            for view in container.subviews {
                if let view = view as? TokenView {
                    view.isSelected = selectedIndex != nil && view.token == tokens[selectedIndex!]
                }
            }
        }
    }
    
    
    private let _tokensUpdater:Promise<[SearchToken]> = Promise([])
    public var tokensUpdater:Signal<[SearchToken], NoError> {
        return _tokensUpdater.get()
    }
    
    private let _textUpdater:ValuePromise<String> = ValuePromise("", ignoreRepeated: true)
    public var textUpdater:Signal<String, NoError> {
        return _textUpdater.get()
    }
    
    public weak var delegate: TokenizedProtocol? = nil
    private let placeholder: TextView = TextView()
    
    public func addTokens(tokens: [SearchToken], animated: Bool) -> Void {
        self.tokens.append(contentsOf: tokens)
        
        for token in tokens {
            let view = TokenView(token, maxSize: NSMakeSize(80, 22), onDismiss: { [weak self] in
                self?.removeTokens(uniqueIds: [token.uniqueId], animated: true)
            }, onSelect: { [weak self] in
                self?.selectedIndex = self?.tokens.firstIndex(of: token)
            })
            container.addSubview(view)
        }
        _tokensUpdater.set(.single(self.tokens))
        input.string = ""
        textDidChange(Notification(name: NSText.didChangeNotification))
        (contentView as? TGClipView)?.scroll(to: NSMakePoint(0, container.frame.height - frame.height), animated: animated)
    }
    
    public func removeTokens(uniqueIds: [Int64], animated: Bool) {
        for uniqueId in uniqueIds {
            var index:Int? = nil
            for i in 0 ..< tokens.count {
                if tokens[i].uniqueId == uniqueId {
                    index = i
                    break
                }
            }
            if let index = index {
                tokens.remove(at: index)
                for view in container.subviews {
                    if let view = view as? TokenView {
                        if view.token.uniqueId == uniqueId {
                            view.change(opacity: 0, animated: animated, completion: { [weak view] completed in
                                if completed {
                                    view?.removeFromSuperview()
                                }
                            })
                            
                        }
                    }
                }
            }
        }
        layoutContainer(animated: animated)
        _tokensUpdater.set(.single(tokens))
    }
    
    private func layoutContainer(animated: Bool) {
        CATransaction.begin()

        let mainw = frame.width
        let between = NSMakePoint(5, 4)
        var point: NSPoint = between
        var extraLine: Bool = false
        let count = container.subviews.count
        for i in 0 ..< count {
            let subview = container.subviews[i]
            let next = container.subviews[min(i + 1, count - 1)]
            if let token = subview as? TokenView, token.layer?.opacity != 0 {
                token.change(pos: point, animated: token.immediatlyPaste ? false : animated)
                if animated, token.immediatlyPaste {
                    token.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                //token.change(size: NSMakeSize(100, token.frame.height), animated: animated)
                token.immediatlyPaste = false
                
                point.x += subview.frame.width + between.x
                
                let dif = mainw - (point.x + (i == count - 1 ? mainw/3 : next.frame.width) + between.x)
                if dif < between.x {
                   // if !token.isPerfectSized {
                   //     token.change(size: NSMakeSize(frame.width - startPointX - between.x, token.frame.height), animated: animated)
                   // }
                    point.x = between.x
                    if i != count - 1 {
                        point.y += token.frame.height + between.y
                    }
                }
                
            }
            if subview == container.subviews.last {
                if mainw - point.x > mainw/3 {
                   // if point.x != between.x {
                        extraLine = true
                  //  }
                }
            }
        }
        
        input.frame = NSMakeRect(point.x, point.y + 3, mainw - point.x - between.x, 16)
        placeholder.change(pos: NSMakePoint(point.x + 6, point.y + 3), animated: animated)
        placeholder.change(opacity: tokens.isEmpty ? 1.0 : 0.0, animated: animated)
        let contentHeight = max(point.y + between.y + (extraLine ? 22 : 0), 30)
        container.change(size: NSMakeSize(container.frame.width, contentHeight), animated: animated)
        
        let height = min(contentHeight, 108)
        if height != frame.height {
            
            _change(size: NSMakeSize(mainw, height), animated: animated)
            delegate?.tokenizedViewDidChangedHeight(self, height: height, animated: animated)
        }
        CATransaction.commit()
    }
    
    public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let range = input.selectedRange()
        
        if commandSelector == #selector(insertNewline(_:)) {
            return true
        }
        if range.location == 0 {
            if commandSelector == #selector(moveLeft(_:)) {
                if let index = selectedIndex {
                    selectedIndex = max(index - 1, 0)
                } else {
                    selectedIndex = tokens.count - 1
                }
                return true
            } else if commandSelector == #selector(moveRight(_:)) {
                if let index = selectedIndex {
                    if index + 1 == tokens.count {
                        selectedIndex = nil
                        input.setSelectedRange(NSMakeRange(input.string.length, 0))
                    } else {
                        selectedIndex = index + 1
                    }
                    return true
                }
            }
            
            if commandSelector == #selector(deleteBackward(_:)) {
                if let selectedIndex = selectedIndex {
                    removeTokens(uniqueIds: [tokens[selectedIndex].uniqueId], animated: true)
                    if selectedIndex != tokens.count {
                        self.selectedIndex = min(selectedIndex, tokens.count - 1)
                    } else {
                        self.selectedIndex = nil
                        input.setSelectedRange(NSMakeRange(input.string.length, 0))
                    }
                    
                    return true
                } else {
                    if !tokens.isEmpty {
                        self.selectedIndex = tokens.count - 1
                        return true
                    }
                }
                
            }
        }
        

        return false
    }
    
    open func textDidChange(_ notification: Notification) {
        
        let pHidden = !input.string.isEmpty
        if placeholder.isHidden != pHidden {
            placeholder.isHidden = pHidden
        }
        if self.window?.firstResponder == self.input {
            self.state = .Focus
        }
        _textUpdater.set(input.string)
        selectedIndex = nil
    }
    
    
    
    public func textDidEndEditing(_ notification: Notification) {
        self.didResignResponder()
    }
    
    public func textDidBeginEditing(_ notification: Notification) {
        //self.didBecomeResponder()
    }

    public override var needsLayout: Bool {
        set {
            super.needsLayout = false
        }
        get {
            return super.needsLayout
        }
    }
    
    public override func layout() {
        super.layout()
        //layoutContainer(animated: false)
    }
    
    
    private let localizationFunc: (String)->String
    private let placeholderKey: String
    required public init(frame frameRect: NSRect, localizationFunc: @escaping(String)->String, placeholderKey:String) {
        self.localizationFunc = localizationFunc
        self.placeholderKey = placeholderKey
        super.init(frame: frameRect)
        
        hasVerticalScroller = true
        container.frame = bounds
        container.autoresizingMask = [.width]
        contentView.documentView = container
        
        input.focusRingType = .none
        input.backgroundColor = NSColor.clear
        input.delegate = self
        input.isRichText = false
        
        input.textContainer?.widthTracksTextView = true
        input.textContainer?.heightTracksTextView = false
        
        input.isHorizontallyResizable = false
        input.isVerticallyResizable = false
        
        
        placeholder.set(handler: { [weak self] _ in
            self?.window?.makeFirstResponder(self?.responder)
        }, for: .Click)

        input.font = .normal(.text)
        container.addSubview(input)
        container.addSubview(placeholder)
        container.layer?.cornerRadius = 10
        wantsLayer = true
        self.layer?.cornerRadius = 10
        self.layer?.backgroundColor = presentation.colors.grayBackground.cgColor
        updateLocalizationAndTheme(theme: presentation)
    }
    
    public func markAsFailed(_ ids:[Int64], animated: Bool) {
        self.failedTokens = ids
        self.updateFailed(animated)
    }
    
    public func addTooltip(for id: Int64, text: String) {
        for token in self.container.subviews {
            if let token = token as? TokenView, token.token.uniqueId == id {
                tooltip(for: token, text: text)
                break
            }
        }
    }
    
    public func removeAllFailed(animated: Bool) {
        self.failedTokens = []
        self.updateFailed(animated)
    }
    
    private func updateFailed(_ animated: Bool) {
        
        for token in self.container.subviews {
            if let token = token as? TokenView {
                 token.setFailed(failedTokens.contains(token.token.uniqueId), animated: animated)
            }
        }
        
    }
    
    open func didResignResponder() {
        state = .None
    }
    
    open func didBecomeResponder() {
        state = .Focus
        
    }
    
    public var query: String {
        return input.string
    }
    
    override public func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(input)
        return true
    }
    
    public var responder: NSResponder? {
        return input
    }
    
    public func updateLocalizationAndTheme(theme: PresentationTheme) {
        background = presentation.colors.background
        contentView.background = presentation.colors.background
        self.container.backgroundColor = presentation.colors.grayBackground
        input.textColor = presentation.colors.text
        input.insertionPointColor = presentation.search.textColor
        let placeholderLayout = TextViewLayout(.initialize(string: localizedString(placeholderKey), color: presentation.colors.grayText, font: .normal(.title)), maximumNumberOfLines: 1)
        placeholderLayout.measure(width: .greatestFiniteMagnitude)
        placeholder.update(placeholderLayout)
        placeholder.backgroundColor = presentation.colors.grayBackground
        placeholder.isSelectable = false
        layoutContainer(animated: false)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    


}
