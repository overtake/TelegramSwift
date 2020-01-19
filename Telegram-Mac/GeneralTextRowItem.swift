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
    fileprivate let textColor: NSColor
    fileprivate var layout:TextViewLayout
    private let text:NSAttributedString
    private let alignment:NSTextAlignment
    fileprivate let centerViewAlignment: Bool
    fileprivate let additionLoading: Bool
    fileprivate let isTextSelectable: Bool
    fileprivate let rightItem: InputDataGeneralTextRightData
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text:NSAttributedString, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0, top:4, bottom:2), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false, additionLoading: Bool = false, additionRightText: String? = nil, linkExecutor: TextViewInteractions = globalLinkExecutor, isTextSelectable: Bool = false, detectLinks: Bool = true, viewType: GeneralViewType = .legacy, rightItem: InputDataGeneralTextRightData = InputDataGeneralTextRightData(isLoading: false, text: nil)) {
        self.textColor = theme.colors.listGrayText
        self.isTextSelectable = isTextSelectable
        let mutable = text.mutableCopy() as! NSMutableAttributedString
        if detectLinks {
            mutable.detectLinks(type: [.Links], context: nil, openInfo: {_, _, _, _ in }, hashtag: nil, command: nil, applyProxy: nil, dotInMention: false)
        }
        self.rightItem = rightItem
        self.text = mutable
        self.additionLoading = additionLoading
        self.alignment = alignment
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(mutable, truncationType: .end, alignment: alignment)
        layout.interactions = linkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, viewType: viewType, action: action, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text: GeneralRowTextType, detectBold: Bool = true, textColor: NSColor = theme.colors.listGrayText, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0, top:4, bottom:2), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false, additionLoading: Bool = false, isTextSelectable: Bool = false, viewType: GeneralViewType = .legacy, rightItem: InputDataGeneralTextRightData = InputDataGeneralTextRightData(isLoading: false, text: nil), fontSize: CGFloat? = nil) {
       
        let attributedText: NSMutableAttributedString
        self.textColor = textColor
        switch text {
        case let .plain(text):
            attributedText = NSAttributedString.initialize(string: text, color: textColor, font: .normal(fontSize ?? 11.5)).mutableCopy() as! NSMutableAttributedString
        case let .markdown(text, handler):
            attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(fontSize ?? 11.5), textColor: textColor), bold: MarkdownAttributeSet(font: .bold(fontSize ?? 11.5), textColor: textColor), link: MarkdownAttributeSet(font: .normal(fontSize ?? 11.5), textColor: theme.colors.link), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, handler))
            })).mutableCopy() as! NSMutableAttributedString
        }
        if detectBold {
            attributedText.detectBoldColorInString(with: .bold(fontSize ?? 11.5))
        }
        self.rightItem = rightItem
        self.text = attributedText
        self.alignment = alignment
        self.isTextSelectable = isTextSelectable
        self.additionLoading = additionLoading
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(attributedText, truncationType: .end, alignment: alignment)
        layout.interactions = globalLinkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, viewType: viewType, action: action, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text:String, detectBold: Bool = true, textColor: NSColor = theme.colors.listGrayText, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false, additionLoading: Bool = false, fontSize: CGFloat = 11.5, isTextSelectable: Bool = false, viewType: GeneralViewType = .legacy, rightItem: InputDataGeneralTextRightData = InputDataGeneralTextRightData(isLoading: false, text: nil)) {
        let attr = NSAttributedString.initialize(string: text, color: textColor, font: .normal(fontSize)).mutableCopy() as! NSMutableAttributedString
        if detectBold {
            attr.detectBoldColorInString(with: .medium(fontSize))
        }
        self.textColor = textColor
        self.text = attr
        self.alignment = alignment
        self.isTextSelectable = isTextSelectable
        self.additionLoading = additionLoading
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(self.text, truncationType: .end, alignment: alignment)
        layout.interactions = globalLinkExecutor
        self.rightItem = rightItem
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
            var addition: CGFloat = 0
            if let text = rightItem.text {
                let layout = TextViewLayout(text)
                layout.measure(width: .greatestFiniteMagnitude)
                addition += layout.layoutSize.width + 20
            }
            layout.measure(width: self.blockWidth - insets.left - insets.right - addition)
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
    private var rightTextView: TextView?
    private var animatedView: MediaAnimatedStickerView?
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

        if item.additionLoading || item.rightItem.isLoading {
            let size = item.rightItem.isLoading ? NSMakeSize(15, 15) : NSMakeSize(20, 20)
            if progressView == nil {
                progressView = ProgressIndicator(frame: NSMakeRect(0, 0, size.width, size.height))
            }
            if progressView!.superview == nil {
                addSubview(progressView!)
            }
        } else {
            progressView?.removeFromSuperview()
            progressView = nil
        }
        
        if let text = item.rightItem.text {
            if self.rightTextView == nil {
                self.rightTextView = TextView()
                addSubview(self.rightTextView!)
            }
            
            
            let textLayout = TextViewLayout(text)
            textLayout.measure(width: .greatestFiniteMagnitude)
            
            var animatedData:InputDataTextInsertAnimatedViewData?
            text.enumerateAttributes(in: text.range, options: [], using: { data, range, stop in
                
                if let attr = data[InputDataTextInsertAnimatedViewData.attributeKey] {
                    animatedData = attr as? InputDataTextInsertAnimatedViewData
                }
            })
            
            if let attr = animatedData {
                if self.animatedView == nil {
                    self.animatedView = MediaAnimatedStickerView(frame: NSZeroRect)
                    self.addSubview(self.animatedView!)
                }
                self.animatedView?.update(with: attr.file, size: NSMakeSize(16, 16), context: attr.context, parent: nil, table: nil, parameters: ChatAnimatedStickerMediaLayoutParameters(playPolicy: .loop, media: attr.file), animated: animated, positionFlags: nil, approximateSynchronousValue: true)

            } else {
                self.animatedView?.removeFromSuperview()
                self.animatedView = nil
            }
            
            self.rightTextView?.update(textLayout)
            self.rightTextView?.isSelectable = false
            self.rightTextView?.userInteractionEnabled = false
        } else {
            self.rightTextView?.removeFromSuperview()
            self.rightTextView = nil
            self.animatedView?.removeFromSuperview()
            self.animatedView = nil
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
                    
                    if item.rightItem.isLoading, let progressView = self.progressView {
                        progressView.setFrameOrigin(NSMakePoint(frame.width - progressView.frame.width - mid - insets.left - insets.right, item.inset.top + insets.top))
                        progressView.progressColor = item.textColor
                    }
                    if let rightTextView = self.rightTextView {
                        rightTextView.setFrameOrigin(NSMakePoint(frame.width - rightTextView.frame.width - mid - insets.left - insets.right, frame.height - insets.bottom - rightTextView.frame.height))
                        
                        if let layout = rightTextView.layout {
                            var animatedRange: NSRange? = nil
                            layout.attributedString.enumerateAttributes(in: layout.attributedString.range, options: [], using: { data, range, stop in
                                if let _ = data[InputDataTextInsertAnimatedViewData.attributeKey] {
                                    animatedRange = range
                                }
                            })
                            if let range = animatedRange, let view = self.animatedView, let offset = layout.offset(for: range.location) {
                                view.setFrameOrigin(NSMakePoint(rightTextView.frame.minX + offset, rightTextView.frame.minY - 1))
                            }
                        }
                    }
                    
                }
               
                
            }
            if item.centerViewAlignment {
                textView.center()                
            }
        }
    }
}
