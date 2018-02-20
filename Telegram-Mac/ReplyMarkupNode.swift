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
    
    init(_ button:ReplyMarkupButton, _ style:ControlStyle = ControlStyle(backgroundColor: theme.colors.grayForeground, highlightColor: theme.colors.text)) {
        self.button = button
        self.style = style
        self.text = TextViewLayout(NSAttributedString.initialize(string: button.title.fixed, color: theme.colors.text, font: .normal(.short)), maximumNumberOfLines: 1, truncationType: .middle, cutout: nil, alignment: .center)
    }
    
    func measure(_ width:CGFloat) {
        text.measure(width: width - 8)
        self.width = width
    }
    
}

class ReplyMarkupNode: Node {

    static let buttonHeight:CGFloat = 34
    static let buttonPadding:CGFloat = 6
    static let rowHeight = buttonHeight + buttonPadding
    
    private var width:CGFloat = 0
    private var height:CGFloat = 0

    private let markup:[[ReplyMarkupButtonLayout]]
    private let flags:ReplyMarkupMessageFlags
    
    private let interactions:ReplyMarkupInteractions
    
    init(_ rows:[ReplyMarkupRow], _ flags:ReplyMarkupMessageFlags, _ interactions:ReplyMarkupInteractions, _ view:View? = nil) {
        self.flags = flags
        self.interactions = interactions
        var layoutRows:[[ReplyMarkupButtonLayout]] = Array(repeating: [], count: rows.count)
        for i in 0 ..< rows.count {
            for button in rows[i].buttons {
                layoutRows[i].append(ReplyMarkupButtonLayout(button))
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
                case .url, .switchInline:
                    urlView = ImageView()
                    urlView?.image = theme.icons.chatActionUrl
                    urlView?.sizeToFit()
                default:
                    break
                }
                
                let btnView = TextView()
                btnView.set(handler: { [weak self] _ in
                    self?.proccess(btnView,button.button)
                }, for: .Click)
                
                btnView.set(handler: { control in
                    control.change(opacity: 0.85, animated: true)
                }, for: .Highlight)
                btnView.set(handler: { control in
                    control.change(opacity: 1.0, animated: true)
                }, for: .Normal)
                btnView.set(handler: { control in
                    control.change(opacity: 1.0, animated: true)
                }, for: .Hover)
                btnView.layer?.cornerRadius = .cornerRadius
                btnView.isSelectable = false
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
        interactions.proccess(button, { loading in
            control.backgroundColor = loading ? .black : theme.colors.grayBackground
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
                button?.backgroundColor = theme.colors.grayBackground
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
            let single:CGFloat = floorToScreenPixels(scaleFactor: System.backingScale, (width - CGFloat(6 * (count - 1))) / CGFloat(count))
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
