//
//  ChatSearchView.swift
//  Telegram
//
//  Created by keepcoder on 25/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac

enum TokenSearchState : Equatable {
    case none
    case from(query: String, complete: Bool)
}

func ==(lhs: TokenSearchState, rhs: TokenSearchState) -> Bool {
    switch lhs {
    case .none:
        if case .none = rhs {
            return true
        } else {
            return false
        }
    case let .from(query, complete):
        if case .from(query, complete) = rhs {
            return true
        } else {
            return false
        }
    }
}

class ChatSearchView: SearchView {
    private let fromView: TextView = TextView()
    private let tokenView: TextView = TextView()
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
            updateLocalizationAndTheme()
            self.needsLayout = true
        }
    }
    
    override var isEmpty: Bool {
        if case .from = tokenState {
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
    
    override func updateLocalizationAndTheme() {
        let fromLayout = TextViewLayout(.initialize(string: "\(tr(L10n.chatSearchFrom)) ", color: theme.colors.text, font: .normal(.text)))
        fromLayout.measure(width: .greatestFiniteMagnitude)
        fromView.update(fromLayout)
        fromView.backgroundColor = theme.colors.grayBackground
        tokenView.backgroundColor = theme.colors.grayBackground
        
        countView.backgroundColor = theme.colors.grayBackground

        let countLayout = TextViewLayout(.initialize(string: tr(L10n.chatSearchCount(countValue.current, countValue.total)), color: theme.search.placeholderColor, font: .normal(.text)))
        countLayout.measure(width: .greatestFiniteMagnitude)
        countView.update(countLayout)
        super.updateLocalizationAndTheme()
    }
    
    override func cancelSearch() {
        switch tokenState {
        case let .from(q, complete):
            if complete {
                if !query.isEmpty {
                    setString("")
                } else {
                    tokenState = .from(query: "", complete: false)
                }
            } else if !q.isEmpty {
                setString("")
                tokenState = .from(query: "", complete: false)
            } else {
                tokenState = .none
            }
        case .none:
            super.cancelSearch()
        }
    }
    
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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
        switch tokenState {
        case .none:
            return super.startTextInset
        case .from(_, let complete):
            return super.startTextInset + fromView.frame.width + 3 + (complete ? tokenView.frame.width + 3 : 0)
        }
    }
    
    override func layout() {
        super.layout()
        fromView.centerY(x: startTextInset + leftInset)
        tokenView.centerY(x: fromView.frame.maxX + 3)
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
    
    let tokenPromise:ValuePromise<TokenSearchState> = ValuePromise(.none, ignoreRepeated: true)
    
    var tokenState:TokenSearchState = .none {
        didSet {
            tokenPromise.set(tokenState)
            switch tokenState {
            case .none:
                fromView.removeFromSuperview()
                tokenView.removeFromSuperview()
            case .from(let text, let complete):
                addSubview(fromView)
                if complete {
                    let layout:TextViewLayout = TextViewLayout(.initialize(string: text, color: theme.colors.link, font: .normal(.text)), maximumNumberOfLines: 1)
                    layout.measure(width: 50)
                    tokenView.update(layout)
                    addSubview(tokenView)
                } else {
                    tokenView.removeFromSuperview()
                }
            }
            updateLocalizationAndTheme()
            self.needsLayout = true
        }
    }
    
    
    
}
