//
//  ChatSearchView.swift
//  Telegram
//
//  Created by keepcoder on 25/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

enum TokenSearchState : Equatable {
    case none
    case from(query: String, complete: Bool)
    case emojiTag(tag: EmojiTag)
}

private final class TagTokenView: Control {
    fileprivate let imageView: AnimationLayerContainer = AnimationLayerContainer(frame: NSMakeRect(0, 0, 14, 14))
    private let backgroundView: NinePathImage = NinePathImage()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.backgroundColor = .clear
        self.backgroundView.capInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 17)

        
        addSubview(backgroundView)
        
        addSubview(imageView)
        
        

    }
    
    func update(with tag: EmojiTag, context: AccountContext, animated: Bool) {
        let layer: InlineStickerItemLayer = .init(account: context.account, file: tag.file, size: NSMakeSize(14, 14))
        imageView.updateLayer(layer, isLite: true, animated: animated)
        
        let image = NSImage(named: "Icon_SearchInputTag")!
        let background = NSImage(cgImage: generateTintedImage(image: image._cgImage, color: theme.colors.accent)!, size: image.size)
        self.backgroundView.image = background

    }
    
    deinit {
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.backgroundView, frame: size.bounds)
        transition.updateFrame(view: self.imageView, frame: imageView.centerFrameY(x: 5))
    }
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
}


class ChatSearchView: SearchView {
    
    private var fromView: TextView?
    private var textTokenView: TextView?
    private var emojiTokenView: TagTokenView?
    private let countView:TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    var countValue:(current:Int, total:Int) = (current: 0, total: 0) {
        didSet {
            if countValue.current > 0 && countValue.total > 0 {
                addSubview(countView)
                updateClearVisibility(false)
            } else {
                countView.removeFromSuperview()
                updateClearVisibility(true)
            }
            updateLocalizationAndTheme(theme: theme)
            self.needsLayout = true
        }
    }
    
    override var isEmpty: Bool {
        if case .from = tokenState {
            return false
        }
        if case .emojiTag = tokenState {
            return false
        }
        return super.isEmpty
    }
    
    override var rightAccessory: NSView {
        return countValue.current > 0 && countValue.total > 0 ? countView : super.rightAccessory
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        let fromLayout = TextViewLayout(.initialize(string: "\(strings().chatSearchFrom) ", color: theme.colors.text, font: .normal(.text)))
        fromLayout.measure(width: .greatestFiniteMagnitude)
        
        fromView?.update(fromLayout)
        fromView?.backgroundColor = theme.colors.grayBackground
        textTokenView?.backgroundColor = theme.colors.grayBackground
        
        countView.backgroundColor = theme.colors.grayBackground

        let countLayout = TextViewLayout(.initialize(string: strings().chatSearchCount(countValue.current, countValue.total), color: theme.search.placeholderColor, font: .normal(.text)))
        countLayout.measure(width: .greatestFiniteMagnitude)
        countView.update(countLayout)
        
        if case let .emojiTag(tag) = tokenState {
            if let context = context {
                emojiTokenView?.update(with: tag, context: context, animated: false)
            }
        }
        
        super.updateLocalizationAndTheme(theme: theme)
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
    
    override func cancelSearch() {
        switch tokenState {
        case let .from(q, complete):
            if complete {
                if !query.isEmpty {
                    setString("")
                } else {
                    tokenState = .from(query: "", complete: false)
                    self.searchInteractions?.textModified(.init(state: self.state, request: self.query, responder: true))
                }
            } else if !q.isEmpty {
                setString("")
                tokenState = .from(query: "", complete: false)
                self.searchInteractions?.textModified(.init(state: self.state, request: self.query, responder: true))
            } else {
                tokenState = .none
                self.searchInteractions?.textModified(.init(state: self.state, request: self.query, responder: true))
            }
        case .emojiTag:
            if !query.isEmpty {
                setString("")
            } else {
                tokenState = .none
                self.searchInteractions?.textModified(.init(state: self.state, request: self.query, responder: true))
            }
        case .none:
            super.cancelSearch()
        }
    }
    
    override func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(deleteBackward(_:)) {
            if query.isEmpty {
                switch tokenState {
                case .none:
                    break
                default:
                    cancelSearch()
                }
                return true
            }
        }
        return false
    }
    
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        
        switch tokenState {
        case .from(_, let complete):
            if !complete {
                let updatedState:TokenSearchState = .from(query: query, complete: complete)
                self.tokenState = updatedState
            }
        default:
            break
        }
    }
    
    override var placeholderTextInset:CGFloat {
        var x = super.startTextInset
        switch tokenState {
        case .none:
            break
        case .from(_, let complete):
            if let fromView = fromView {
                x += (fromView.frame.width + 3)
            }
            if complete, let textTokenView = textTokenView {
                x += textTokenView.frame.width + 3
            }
        case .emojiTag:
            if let emojiTokenView = emojiTokenView {
                x += (emojiTokenView.frame.width + 3)
            }
        }
        return x
    }
    
    override func layout() {
        super.layout()
        if let fromView = fromView {
            fromView.centerY(x: startTextInset + leftInset)
        }
        if let textTokenView = textTokenView, let fromView = fromView {
            textTokenView.centerY(x: fromView.frame.maxX + 3)
        }
        if let emojiTokenView = emojiTokenView {
            emojiTokenView.centerY(x: startTextInset + leftInset)
        }
        countView.centerY(x: frame.width - countView.frame.width - leftInset)
    }
    
    func initToken() {
        tokenState = .from(query: "", complete: false)
        setString("")
        change(state: .Focus, false)
    }
    
    func completeToken(_ name:String) {
        tokenState = .from(query: name, complete: true)
        self.setString("")
    }
    
    private var context: AccountContext?
    func completeEmojiToken(_ tag: EmojiTag, context: AccountContext) {
        self.context = context
        self.tokenState = .emojiTag(tag: tag)
        self.change(state: .Focus, true)
        
        self.searchInteractions?.textModified(.init(state: self.state, request: self.query, responder: true))
    }
    
    func cancelEmojiToken(animated: Bool) {
        self.tokenState = .none
        self.change(state: .Focus, animated)
        self.searchInteractions?.textModified(.init(state: self.state, request: self.query, responder: true))
    }
    
    let tokenPromise:ValuePromise<TokenSearchState> = ValuePromise(.none, ignoreRepeated: true)
    
    var tokenState:TokenSearchState = .none {
        didSet {
            tokenPromise.set(tokenState)
            switch tokenState {
            case .none:
                if let fromView = fromView {
                    performSubviewRemoval(fromView, animated: true)
                    self.fromView = nil
                }
                if let textTokenView = textTokenView {
                    performSubviewRemoval(textTokenView, animated: true)
                    self.textTokenView = nil
                }
                if let emojiTokenView = emojiTokenView {
                    performSubviewRemoval(emojiTokenView, animated: true)
                    self.emojiTokenView = nil
                }
            case .from(let text, let complete):
                if let emojiTokenView = emojiTokenView {
                    performSubviewRemoval(emojiTokenView, animated: true)
                    self.emojiTokenView = nil
                }
                if fromView == nil {
                    let fromView = TextView()
                    self.fromView = fromView
                    addSubview(fromView)
                }
                if complete {
                    let current: TextView
                    if let view = self.textTokenView {
                        current = view
                    } else {
                        current = TextView()
                        addSubview(current)
                        self.textTokenView = current
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                    let layout:TextViewLayout = TextViewLayout(.initialize(string: text, color: theme.colors.link, font: .normal(.text)), maximumNumberOfLines: 1)
                    layout.measure(width: 50)
                    current.update(layout)
                } else if let tokenView = textTokenView {
                    performSubviewRemoval(tokenView, animated: true)
                    self.textTokenView = nil
                }
            case let .emojiTag(tag):
                if let fromView = fromView {
                    performSubviewRemoval(fromView, animated: true)
                    self.fromView = nil
                }
                if let textTokenView = textTokenView {
                    performSubviewRemoval(textTokenView, animated: true)
                    self.textTokenView = nil
                }
                let current: TagTokenView
                if let view = self.emojiTokenView {
                    current = view
                } else {
                    current = TagTokenView(frame: NSMakeRect(0, 0, 36, 20))
                    addSubview(current)
                    self.emojiTokenView = current
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                if let context = context {
                    current.update(with: tag, context: context, animated: true)
                }
            }
            updateLocalizationAndTheme(theme: theme)
            self.needsLayout = true
        }
    }
    
    
    
}
