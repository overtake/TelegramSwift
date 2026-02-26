//
//  ReplyMarkupNode.swift
//  TelegramMac
//
//  Created by keepcoder on 16/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import TGUIKit
import Postbox
import SwiftSignalKit


class ReplyMarkupButtonLayout {
    
    private(set) var width:CGFloat = 0
    let text:TextViewLayout
    let button:ReplyMarkupButton
    let presentation: TelegramPresentationTheme
    init(button:ReplyMarkupButton, theme: TelegramPresentationTheme, isInput: Bool, paid: Bool, xtrAmount: Int64?) {
        self.button = button
        self.presentation = theme
        let attr = NSMutableAttributedString()
        
        
        let color = theme.controllerBackgroundMode.hasWallpaper && !isInput ? theme.chatServiceItemTextColor : theme.colors.text
        
        attr.append(string: paid ? strings().messageReplyActionButtonShowReceipt : button.title.fixed, color: color, font: .semibold(.short))

        switch button.action {
        case let .url(url):
            switch url {
            case SuggestedPostMessageAttribute.commandApprove:
                attr.insert(.initialize(string: clown_space), at: 0)
                attr.insertEmbedded(.embedded(name: "Icon_SuggestPost_Approve", color: theme.chatServiceItemTextColor, resize: false), for: clown)
            case SuggestedPostMessageAttribute.commandDecline:
                attr.insert(.initialize(string: clown_space), at: 0)
                attr.insertEmbedded(.embedded(name: "Icon_SuggestPost_Decline", color: theme.chatServiceItemTextColor, resize: false), for: clown)
            case SuggestedPostMessageAttribute.commandChanges:
                attr.insert(.initialize(string: clown_space), at: 0)
                attr.insertEmbedded(.embedded(name: "Icon_SuggestPost_Edit", color: theme.chatServiceItemTextColor, resize: false), for: clown)
            default:
                break
            }
        default:
            break
        }
        
        self.text = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .middle, cutout: nil, alignment: .center, alwaysStaticItems: true)
    }
    
    func measure(_ width:CGFloat) {
        text.measure(width: width - 8)
        self.width = width
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
}

class ReplyMarkupNode: Node {

    static let buttonHeight:CGFloat = 34
    static let buttonPadding:CGFloat = 2
    static let rowHeight = buttonHeight + buttonPadding
    
    private var width:CGFloat = 0
    private var height:CGFloat = 0

    private let markup:[[ReplyMarkupButtonLayout]]
    private let flags:ReplyMarkupMessageFlags
    
    private let interactions:ReplyMarkupInteractions
    private let isInput: Bool
    private let theme: TelegramPresentationTheme
    private let xtr: Bool
    private let isPostSuggest: Bool
    init(_ rows:[ReplyMarkupRow], _ flags:ReplyMarkupMessageFlags, _ interactions:ReplyMarkupInteractions, _ theme: TelegramPresentationTheme, _ view:View? = nil, _ isInput: Bool = false, paid: Bool = false, xtrAmount: Int64? = nil, isPostSuggest: Bool = false) {
        self.flags = flags
        self.isInput = isInput
        self.isPostSuggest = isPostSuggest
        self.xtr = xtrAmount != nil
        self.interactions = interactions
        self.theme = theme
        var layoutRows:[[ReplyMarkupButtonLayout]] = Array(repeating: [], count: rows.count)
        for i in 0 ..< rows.count {
            for button in rows[i].buttons {
                layoutRows[i].append(ReplyMarkupButtonLayout(button: button, theme: theme, isInput: isInput, paid: paid, xtrAmount: xtrAmount))
            }
        }
        self.markup = layoutRows
        super.init(view)
    }
    
    var shouldBlurService: Bool {
        return !isLite(.blur) && theme.shouldBlurService
    }
    
    func redraw() {
        view?.removeAllSubviews()
        for row in markup {
            for button in row {
                var urlView:ImageView?
                switch button.button.action {
                case let .url(url):
                    if !url.isSingleEmoji, !isPostSuggest {
                        urlView = ImageView()
                        urlView?.image = theme.chat.chatActionUrl(theme: theme)
                        urlView?.sizeToFit()
                    }
                    
                case .payment:
                    if !xtr {
                        urlView = ImageView()
                        urlView?.image = theme.chat.chatInvoiceAction(theme: theme)
                        urlView?.sizeToFit()
                    }
                case .switchInline:
                    urlView = ImageView()
                    urlView?.image = theme.chat.chatActionUrl(theme: theme)
                    urlView?.sizeToFit()
                case .openWebApp, .openWebView:
                    urlView = ImageView()
                    urlView?.image = theme.chat.chatActionWebUrl(theme: theme)
                    urlView?.sizeToFit()
                case .copyText:
                    urlView = ImageView()
                    urlView?.image = theme.chat.chatActionCopy(theme: theme)
                    urlView?.sizeToFit()
                default:
                    break
                }
                
                let btnView = InteractiveTextView()
                btnView.set(handler: { [weak self, weak button] control in
                    if let button = button {
                        self?.proccess(control, button.button)
                    }
                }, for: .Click)
                
                btnView.scaleOnClick = true
    
                btnView.layer?.cornerRadius = .cornerRadius
                btnView.textView.isSelectable = false
                
                if !self.isInput && shouldBlurService {
                    btnView.blurBackground = button.presentation.blurServiceColor
                    btnView.backgroundColor = .clear
                } else {
                    btnView.blurBackground = nil
                    if button.presentation.hasWallpaper && !self.isInput {
                        btnView.backgroundColor = button.presentation.chatServiceItemColor
                    } else {
                        btnView.backgroundColor = button.presentation.colors.grayForeground
                    }
                }
                btnView.set(text: button.text, context: self.interactions.context)
                
                if let urlView = urlView {
                    btnView.addSubview(urlView)
                }
                
                view?.addSubview(btnView)
            }
        }
    }
    
    func proccess(_ control:Control, _ button:ReplyMarkupButton) {
        interactions.proccess(button, { _ in
           // control?.backgroundColor = loading ? .black : theme.colors.grayBackground
        })
    }
    
    func layout(transition: ContainedViewLayoutTransition = .immediate) {
        var y:CGFloat = 0
        
        var i:Int = 0
        for row in markup {
            var j:Int = 0
            var rect:NSRect = NSMakeRect(0,y,0,0)
            for button in row {
                var w = button.width
                if j == row.count - 1 {
                    w = self.width - rect.minX
                }
                rect.size = NSMakeSize(w, ReplyMarkupNode.buttonHeight)
                let btnView:InteractiveTextView? = view?.subviews[i] as? InteractiveTextView
                
                if !self.isInput && self.shouldBlurService {
                    btnView?.blurBackground = button.presentation.blurServiceColor
                    btnView?.backgroundColor = .clear
                } else {
                    btnView?.blurBackground = nil
                    if button.presentation.hasWallpaper && !self.isInput {
                        btnView?.backgroundColor = button.presentation.chatServiceItemColor
                    } else {
                        btnView?.backgroundColor = button.presentation.colors.grayForeground
                    }
                }
                if let btnView = btnView {
                    transition.updateFrame(view: btnView, frame: rect)
                    btnView.textView.setNeedsDisplayLayer()
                    if !btnView.subviews.isEmpty, let urlView = btnView.subviews.first(where: { $0 is ImageView }) {
                        
                        transition.updateFrame(view: urlView, frame: NSMakeRect(rect.width - urlView.frame.width - 5, 5, urlView.frame.width, urlView.frame.height))
                        
                    }
                }
                
                rect = rect.offsetBy(dx: w + ReplyMarkupNode.buttonPadding, dy: 0)
                i += 1
                j += 1
            }
            y += ReplyMarkupNode.rowHeight
        }
    }
    
    var hasButtons:Bool {
        return !markup.isEmpty
    }

    override func measureSize(_ width: CGFloat) {
        for row in markup {
            let count = row.count
            
            let single:CGFloat = floorToScreenPixels(System.backingScale, (width - CGFloat(ReplyMarkupNode.buttonPadding * CGFloat(count - 1))) / CGFloat(count))
            for button in row {
                button.measure(single)
            }
        }
        self.width = width
        self.height = CGFloat(CGFloat(markup.count) * ReplyMarkupNode.buttonHeight) + CGFloat(CGFloat(markup.count - 1) * ReplyMarkupNode.buttonPadding)
    }
    
    override var size: NSSize {
        get {
            return NSMakeSize(width, height)
        }
        set {
            super.size = newValue
        }
    }
    
}
