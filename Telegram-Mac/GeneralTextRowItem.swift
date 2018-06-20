//
//  GeneralTextRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 05/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

enum GeneralRowTextType {
    case plain(String)
    case markdown(String, linkHandler: (String)->Void)
}

class GeneralTextRowItem: GeneralRowItem {

    fileprivate var layout:TextViewLayout
    private let text:NSAttributedString
    private let alignment:NSTextAlignment
    fileprivate let centerViewAlignment: Bool
    fileprivate let additionLoading: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text:NSAttributedString, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0, top:4, bottom:2), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false, additionLoading: Bool = false, linkExecutor: TextViewInteractions = globalLinkExecutor) {
        self.text = text
        self.additionLoading = additionLoading
        self.alignment = alignment
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(text, truncationType: .end, alignment: alignment)
        layout.interactions = linkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, action: action, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text: GeneralRowTextType, textColor: NSColor = theme.colors.grayText, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0, top:4, bottom:2), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false, additionLoading: Bool = false) {
       
        let attributedText: NSMutableAttributedString
        
        switch text {
        case let .plain(text):
            attributedText = NSAttributedString.initialize(string: text, color: textColor, font: .normal(11.5)).mutableCopy() as! NSMutableAttributedString
        case let .markdown(text, handler):
            attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(11.5), textColor: textColor), bold: MarkdownAttributeSet(font: .bold(11.5), textColor: textColor), link: MarkdownAttributeSet(font: .normal(11.5), textColor: theme.colors.link), linkAttribute: { contents in
                return (NSAttributedStringKey.link.rawValue, inAppLink.callback(contents, handler))
            })).mutableCopy() as! NSMutableAttributedString
        }
        attributedText.detectBoldColorInString(with: .bold(11.5))
        self.text = attributedText
        self.alignment = alignment
        self.additionLoading = additionLoading
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(attributedText, truncationType: .end, alignment: alignment)
        layout.interactions = globalLinkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, action: action, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text:String, detectBold: Bool = true, textColor: NSColor = theme.colors.grayText, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0, top:4, bottom:2), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false, additionLoading: Bool = false) {
        let attr = NSAttributedString.initialize(string: text, color: textColor, font: .normal(11.5)).mutableCopy() as! NSMutableAttributedString
        if detectBold {
            attr.detectBoldColorInString(with: .medium(11.5))
        }
        self.text = attr
        self.alignment = alignment
        self.additionLoading = additionLoading
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(self.text, truncationType: .end, alignment: alignment)
        layout.interactions = globalLinkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, action: action, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    override var height: CGFloat {
        if _height > 0 {
            return _height
        }
        return layout.layoutSize.height + inset.top + inset.bottom + (additionLoading ? 30 : 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        
        layout.measure(width: width - inset.left - inset.right)

        return super.makeSize(width, oldWidth: oldWidth)
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
        textView.isSelectable = false
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let item = item as? GeneralTextRowItem, item.drawCustomSeparator {
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
        }
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        textView.backgroundColor = theme.colors.background
        
        guard let item = item as? GeneralTextRowItem else {return}
        
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
                textView.update(item.layout, origin:NSMakePoint(item.inset.left, item.inset.top))
            }
            
            
            if item.centerViewAlignment {
                textView.center()
            }
        }
    }
}
