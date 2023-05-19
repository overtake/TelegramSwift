//
//  Views.swift
//  Telegram
//
//  Created by keepcoder on 07/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class RestrictionWrappedView : Control {
    let textView: TextView = TextView()
    let text:String
    required init(frame frameRect: NSRect) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(_ text:String) {
        self.text = text
        super.init()
        addSubview(textView)
        textView.userInteractionEnabled = false
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        self.backgroundColor = theme.colors.background
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.grayText, font: .normal(.text)), alignment: .center)
        textView.update(layout)
        textView.backgroundColor = theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        textView.resize(frame.width - 40)
        textView.center()
    }
}

class VideoDurationView : View {
    private var textNode:(TextNodeLayout, TextNode)
    init(_ textNode:(TextNodeLayout, TextNode)) {
        self.textNode = textNode
        super.init()
        self.backgroundColor = .clear
    }
    
    func updateNode(_ textNode:(TextNodeLayout, TextNode)) {
        self.textNode = textNode
        needsDisplay = true
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    func sizeToFit() {
        setFrameSize(textNode.0.size.width + 10, textNode.0.size.height + 6)
        needsDisplay = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.setFillColor(NSColor(0x000000, 0.8).cgColor)
        ctx.round(frame.size, 4)
        ctx.fill(bounds)
        
        let f = focus(textNode.0.size)
        textNode.1.draw(f, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class CornerView : View {

    var positionFlags: LayoutPositionFlags? {
        didSet {
            needsLayout = true
        }
    }
    
    var didChangeSuperview: (()->Void)? = nil
    
    override func viewDidMoveToSuperview() {
        didChangeSuperview?()
    }
    
    override var backgroundColor: NSColor {
        didSet {
            layer?.backgroundColor = .clear
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let positionFlags = positionFlags {
            ctx.round(frame.size, positionFlags.isEmpty ? 0 : .cornerRadius, positionFlags: positionFlags)
        }
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(bounds)
//        if let positionFlags = positionFlags {
//
//            let minx:CGFloat = 0, midx = frame.width/2.0, maxx = frame.width
//            let miny:CGFloat = 0, midy = frame.height/2.0, maxy = frame.height
//
//            ctx.move(to: NSMakePoint(minx, midy))
//
//            var topLeftRadius: CGFloat = .cornerRadius
//            var bottomLeftRadius: CGFloat = .cornerRadius
//            var topRightRadius: CGFloat = .cornerRadius
//            var bottomRightRadius: CGFloat = .cornerRadius
//
//
//            if positionFlags.contains(.top) && positionFlags.contains(.left) {
//                topLeftRadius = topLeftRadius * 3 + 2
//            }
//            if positionFlags.contains(.top) && positionFlags.contains(.right) {
//                topRightRadius = topRightRadius * 3 + 2
//            }
//            if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
//                bottomLeftRadius = bottomLeftRadius * 3 + 2
//            }
//            if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
//                bottomRightRadius = bottomRightRadius * 3 + 2
//            }
//
//            ctx.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
//            ctx.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
//            ctx.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topLeftRadius)
//            ctx.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topRightRadius)
//
//            ctx.closePath()
//            ctx.clip()
//        }
//
//        ctx.setFillColor(backgroundColor.cgColor)
//        ctx.fill(bounds)
//
    }
    
}


class SearchTitleBarView : TitledBarView {
    private let search:ImageButton = ImageButton()
    private let calendar:ImageButton = ImageButton()

    init(controller: ViewController, title:NSAttributedString, handler:@escaping() ->Void, calendarClick:(() ->Void)? = nil) {
        super.init(controller: controller, title)
        search.set(handler: { _ in
            handler()
        }, for: .Click)
        addSubview(search)
        addSubview(calendar)
        
        calendar.autohighlight = false
        calendar.scaleOnClick = true
        
        calendar.set(handler: { _ in
            calendarClick?()
        }, for: .Click)
        
        calendar.isHidden = calendarClick == nil
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    func updateSearchVisibility(_ searchVisible: Bool, calendarVisible: Bool = false, animated: Bool = true) {
        if searchVisible {
            self.search.isHidden = false
        }
        search.change(opacity: searchVisible ? 1 : 0, animated: animated, completion: { [weak self] _ in
            self?.search.isHidden = !searchVisible
        })
        
        if calendarVisible {
            self.calendar.isHidden = false
        }
        calendar.change(opacity: calendarVisible ? 1 : 0, animated: animated, completion: { [weak self] _ in
            self?.calendar.isHidden = !calendarVisible
        })
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        search.set(image: theme.icons.chatSearch, for: .Normal)
        search.set(image: theme.icons.chatSearchActive, for: .Highlight)
        _ = search.sizeToFit()
        
        calendar.set(image: theme.icons.chatSearchCalendar, for: .Normal)
        _ = calendar.sizeToFit()

        
        backgroundColor = theme.colors.background
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        search.centerY(x: frame.width - search.frame.width)
        if search.isHidden {
            calendar.centerY(x: frame.width - calendar.frame.width)
        } else {
            calendar.centerY(x: frame.width - search.frame.width - 10 - calendar.frame.width)
        }
    }
    
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
