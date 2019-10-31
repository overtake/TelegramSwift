//
//  ReplyMarkupNode.swift
//  TelegramMac
//
//  Created by keepcoder on 16/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit
import PostboxMac
import SwiftSignalKitMac


class ReplyMarkupButtonLayout {
    
    private(set) var width:CGFloat = 0
    let text:TextViewLayout
    let style:ControlStyle
    let button:ReplyMarkupButton
    
    init(button:ReplyMarkupButton, style:ControlStyle = ControlStyle(backgroundColor: theme.colors.grayForeground, highlightColor: theme.colors.text), isInput: Bool) {
        self.button = button
        self.style = style
        self.text = TextViewLayout(NSAttributedString.initialize(string: button.title.fixed, color: theme.controllerBackgroundMode.hasWallpapaer && !isInput ? theme.chatServiceItemTextColor : theme.colors.text, font: .normal(.short)), maximumNumberOfLines: 1, truncationType: .middle, cutout: nil, alignment: .center)
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
    init(_ rows:[ReplyMarkupRow], _ flags:ReplyMarkupMessageFlags, _ interactions:ReplyMarkupInteractions, _ view:View? = nil, _ isInput: Bool = false) {
        self.flags = flags
        self.isInput = isInput
        self.interactions = interactions
        var layoutRows:[[ReplyMarkupButtonLayout]] = Array(repeating: [], count: rows.count)
        for i in 0 ..< rows.count {
            for button in rows[i].buttons {
                layoutRows[i].append(ReplyMarkupButtonLayout(button: button, isInput: isInput))
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
                        urlView?.image = theme.icons.chatActionUrl
                        urlView?.sizeToFit()
                    }
                case .switchInline:
                    urlView = ImageView()
                    urlView?.image = theme.icons.chatActionUrl
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
                
                btnView.set(handler: { control in
                    control.change(opacity: 0.7, animated: true)
                }, for: .Highlight)
                btnView.set(handler: { control in
                    control.change(opacity: 1.0, animated: true)
                }, for: .Normal)
                btnView.set(handler: { control in
                    control.change(opacity: 1.0, animated: true)
                }, for: .Hover)
                btnView.layer?.cornerRadius = .cornerRadius
                btnView.isSelectable = false
                btnView.disableBackgroundDrawing = true

                btnView.backgroundColor = button.style.backgroundColor
                btnView.set(layout:button.text)
                
                if let urlView = urlView {
                    btnView.addSubview(urlView)
                }
                
                view?.addSubview(btnView)
            }
        }
    }
    
    func proccess(_ control:Control, _ button:ReplyMarkupButton) {
        interactions.proccess(button, { [weak control] loading in
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
                let button:View? = view?.subviews[i] as? View
                button?.backgroundColor = theme.controllerBackgroundMode.hasWallpapaer && !isInput ? theme.chatServiceItemColor : theme.colors.grayBackground
                if let button = button {
                    button.frame = rect
                    button.setNeedsDisplayLayer()
                    if !button.subviews.isEmpty, let urlView = button.subviews[0] as? ImageView {
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
