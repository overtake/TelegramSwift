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
    init(button:ReplyMarkupButton, theme: TelegramPresentationTheme, isInput: Bool, paid: Bool) {
        self.button = button
        self.presentation = theme
        self.text = TextViewLayout(NSAttributedString.initialize(string: paid ? L10n.messageReplyActionButtonShowReceipt : button.title.fixed, color: theme.controllerBackgroundMode.hasWallpaper && !isInput ? theme.chatServiceItemTextColor : theme.colors.text, font: .normal(.short)), maximumNumberOfLines: 1, truncationType: .middle, cutout: nil, alignment: .center)
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
    static let buttonPadding:CGFloat = 4
    static let rowHeight = buttonHeight + buttonPadding
    
    private var width:CGFloat = 0
    private var height:CGFloat = 0

    private let markup:[[ReplyMarkupButtonLayout]]
    private let flags:ReplyMarkupMessageFlags
    
    private let interactions:ReplyMarkupInteractions
    private let isInput: Bool
    init(_ rows:[ReplyMarkupRow], _ flags:ReplyMarkupMessageFlags, _ interactions:ReplyMarkupInteractions, _ theme: TelegramPresentationTheme, _ view:View? = nil, _ isInput: Bool = false, paid: Bool = false) {
        self.flags = flags
        self.isInput = isInput
        self.interactions = interactions
        var layoutRows:[[ReplyMarkupButtonLayout]] = Array(repeating: [], count: rows.count)
        for i in 0 ..< rows.count {
            for button in rows[i].buttons {
                layoutRows[i].append(ReplyMarkupButtonLayout(button: button, theme: theme, isInput: isInput, paid: paid))
            }
        }
        self.markup = layoutRows
        super.init(view)
    }
    
    func redraw() {
        view?.removeAllSubviews()
        for row in markup {
            for button in row {
                
                var urlView:ImageView?
                switch button.button.action {
                case let .url(url):
                    if !url.isSingleEmoji {
                        urlView = ImageView()
                        urlView?.image = theme.chat.chatActionUrl(theme: theme)
                        urlView?.sizeToFit()
                    }
                case .payment:
                    urlView = ImageView()
                    urlView?.image = theme.chat.chatInvoiceAction(theme: theme)
                    urlView?.sizeToFit()
                case .switchInline:
                    urlView = ImageView()
                    urlView?.image = theme.chat.chatActionUrl(theme: theme)
                    urlView?.sizeToFit()
                default:
                    break
                }
                
                let btnView = TextView()
                btnView.set(handler: { [weak self, weak button] control in
                    if let button = button {
                        self?.proccess(control, button.button)
                    }
                }, for: .Click)
                
                btnView.scaleOnClick = true
    
                btnView.layer?.cornerRadius = .cornerRadius
                btnView.isSelectable = false
                btnView.disableBackgroundDrawing = true

                if !self.isInput && button.presentation.shouldBlurService {
                    btnView.blurBackground = button.presentation.blurServiceColor
                    btnView.backgroundColor = .clear
                } else {
                    btnView.blurBackground = nil
                    btnView.backgroundColor = button.presentation.colors.grayBackground
                }
                btnView.set(layout:button.text)
                
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
    
    func layout() {
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
                let btnView:TextView? = view?.subviews[i] as? TextView
                
                if !self.isInput && button.presentation.shouldBlurService {
                    btnView?.blurBackground = button.presentation.blurServiceColor
                    btnView?.backgroundColor = .clear
                } else {
                    btnView?.blurBackground = nil
                    btnView?.backgroundColor = theme.colors.grayBackground
                }
                if let btnView = btnView {
                    btnView.frame = rect
                    btnView.setNeedsDisplayLayer()
                    if !btnView.subviews.isEmpty, let urlView = btnView.subviews.first(where: { $0 is ImageView }) {
                        urlView.setFrameOrigin(rect.width - urlView.frame.width - 5, 5)
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
            let single:CGFloat = floorToScreenPixels(System.backingScale, (width - CGFloat(6 * (count - 1))) / CGFloat(count))
            for button in row {
                button.measure(single)
            }
        }
        self.width = width
        self.height = CGFloat(markup.count * 34) + CGFloat((markup.count - 1) * 6)
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
