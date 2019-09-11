//
//  GeneralTextRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 05/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

enum GeneralRowTextType : Equatable {
    case plain(String)
    case markdown(String, linkHandler: (String)->Void)
    
    static func ==(lhs: GeneralRowTextType, rhs: GeneralRowTextType) -> Bool {
        switch lhs {
        case let .plain(text):
            if case .plain(text) = rhs {
                return true
            } else {
                return false
            }
        case let .markdown(text, _):
            if case .markdown(text, _) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}



class GeneralTextRowItem: GeneralRowItem {

    fileprivate var layout:TextViewLayout
    private let text:NSAttributedString
    private let alignment:NSTextAlignment
    fileprivate let centerViewAlignment: Bool
    fileprivate let additionLoading: Bool
    fileprivate let isTextSelectable: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text:NSAttributedString, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0, top:4, bottom:2), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false, additionLoading: Bool = false, linkExecutor: TextViewInteractions = globalLinkExecutor, isTextSelectable: Bool = false, detectLinks: Bool = true, viewType: GeneralViewType = .legacy) {
        
        self.isTextSelectable = isTextSelectable
        let mutable = text.mutableCopy() as! NSMutableAttributedString
        if detectLinks {
            mutable.detectLinks(type: [.Links], context: nil, openInfo: {_, _, _, _ in }, hashtag: nil, command: nil, applyProxy: nil, dotInMention: false)
        }
        
        self.text = mutable
        self.additionLoading = additionLoading
        self.alignment = alignment
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(mutable, truncationType: .end, alignment: alignment)
        layout.interactions = linkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, viewType: viewType, action: action, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text: GeneralRowTextType, detectBold: Bool = true, textColor: NSColor = theme.colors.grayText, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0, top:4, bottom:2), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false, additionLoading: Bool = false, isTextSelectable: Bool = false, viewType: GeneralViewType = .legacy) {
       
        let attributedText: NSMutableAttributedString
        
        switch text {
        case let .plain(text):
            attributedText = NSAttributedString.initialize(string: text, color: textColor, font: .normal(11.5)).mutableCopy() as! NSMutableAttributedString
        case let .markdown(text, handler):
            attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(11.5), textColor: textColor), bold: MarkdownAttributeSet(font: .bold(11.5), textColor: textColor), link: MarkdownAttributeSet(font: .normal(11.5), textColor: theme.colors.link), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, handler))
            })).mutableCopy() as! NSMutableAttributedString
        }
        if detectBold {
            attributedText.detectBoldColorInString(with: .bold(11.5))
        }
        
        self.text = attributedText
        self.alignment = alignment
        self.isTextSelectable = isTextSelectable
        self.additionLoading = additionLoading
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(attributedText, truncationType: .end, alignment: alignment)
        layout.interactions = globalLinkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, viewType: viewType, action: action, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text:String, detectBold: Bool = true, textColor: NSColor = theme.colors.grayText, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false, additionLoading: Bool = false, fontSize: CGFloat = 11.5, isTextSelectable: Bool = false, viewType: GeneralViewType = .legacy) {
        let attr = NSAttributedString.initialize(string: text, color: textColor, font: .normal(fontSize)).mutableCopy() as! NSMutableAttributedString
        if detectBold {
            attr.detectBoldColorInString(with: .medium(fontSize))
        }
        self.text = attr
        self.alignment = alignment
        self.isTextSelectable = isTextSelectable
        self.additionLoading = additionLoading
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(self.text, truncationType: .end, alignment: alignment)
        layout.interactions = globalLinkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, viewType: viewType, action: action, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    
    
    override var height: CGFloat {
        if _height > 0 {
            return _height
        }
        switch viewType {
        case .legacy:
            return layout.layoutSize.height + inset.top + inset.bottom + (additionLoading ? 30 : 0)
        case let .modern(_, insets):
            return layout.layoutSize.height + inset.top + inset.bottom + insets.top + insets.bottom + (additionLoading ? 30 : 0)
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        switch viewType {
        case .legacy:
            layout.measure(width: width - inset.left - inset.right)
        case let .modern(_, insets):
            layout.measure(width: self.blockWidth - insets.left - insets.right)
        }

        return success
    }
    
    override func viewClass() -> AnyClass {
        return GeneralTextRowView.self
    }
    
}


class GeneralTextRowView : GeneralRowView {
    private let textView:TextView = TextView()
    private var progressView: ProgressIndicator?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
    }
    
    override var firstResponder: NSResponder? {
        return nil
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let item = item as? GeneralTextRowItem {
            switch item.viewType {
            case .legacy:
                if item.drawCustomSeparator {
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
                }
            case .modern:
                break
            }
        }
    }
    
    override var backdorColor: NSColor {
        if let item = item as? GeneralTextRowItem {
            return item.viewType.rowBackground
        }
        return theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        textView.backgroundColor = self.backdorColor
        
        guard let item = item as? GeneralTextRowItem else {return}
        textView.isSelectable = item.isTextSelectable

        if item.additionLoading {
            if progressView == nil {
                progressView = ProgressIndicator()
            }
            if progressView!.superview == nil {
                addSubview(progressView!)
            }
        } else {
            progressView?.removeFromSuperview()
            progressView = nil
        }
        
        
        needsDisplay = true
        needsLayout = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if let item = item as? GeneralTextRowItem, mouseInside() {
           item.action()
        } else {
            super.mouseUp(with: event)
        }
    }
    
    
    override func shakeView() {
        textView.shake()
    }
    

    
    override func layout() {
        super.layout()
        if let item = item as? GeneralTextRowItem {
            if item.additionLoading, let progressView = progressView {
                progressView.centerX(y: 0)
                textView.update(item.layout)
                textView.centerX(y: progressView.frame.maxY + 10)
            } else {
                switch item.viewType {
                case .legacy:
                    textView.update(item.layout, origin: NSMakePoint(item.inset.left, item.inset.top))
                case let .modern(_, insets):
                    let mid = max(0, floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2))
                    textView.update(item.layout, origin: NSMakePoint(mid + insets.left, item.inset.top + insets.top))
                }
            }
            if item.centerViewAlignment {
                textView.center()                
            }
        }
    }
}
