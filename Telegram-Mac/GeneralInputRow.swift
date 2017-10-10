//
//  GeneralInputRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 02/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac

class GeneralInputRowItem: TableRowItem {
    
    private let textChangeHandler:(String)->Void
    var text:String = "" {
        didSet {
            if text != oldValue {
                inputTextChanged(text)
            }
        }
    }
    
    func inputTextChanged(_ text:String) {
        Queue.mainQueue().justDispatch {
            self.textChangeHandler(text)
        }
    }
    
    fileprivate let textFilter:(String)->String
    fileprivate let pasteFilter:((String)->(Bool, String))?
    let insets:NSEdgeInsets
    let placeholder:NSAttributedString
    let limit:Int32
    let holdText:Bool
    fileprivate let canFastClean: Bool
    let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, stableId:AnyHashable = arc4random(), placeholder:String, text:String = "", limit:Int32 = 140, insets: NSEdgeInsets = NSEdgeInsets(left:25,right:25,top:2,bottom:3), textChangeHandler:@escaping(String)->Void = {_ in}, textFilter:@escaping(String)->String = {value in return value}, holdText:Bool = false, pasteFilter:((String)->(Bool, String))? = nil, canFastClean: Bool = false) {
        _stableId = stableId
        self.insets = insets
        self.pasteFilter = pasteFilter
        self.holdText = holdText
        self.canFastClean = canFastClean
        self.textChangeHandler = textChangeHandler
        self.limit = limit
        self.text = text
        self.textFilter = textFilter
        self.placeholder = .initialize(string: placeholder, color: theme.colors.grayText, font: NSFont.normal(FontSize.text), coreText: false)
        
        let textStorage = NSTextStorage(attributedString: .initialize(string: text))
        let textContainer = NSTextContainer(containerSize: NSMakeSize(initialSize.width - insets.left - insets.right, .greatestFiniteMagnitude))
        
        let layoutManager = NSLayoutManager();
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        layoutManager.ensureLayout(for: textContainer)
        
        _height = max(24, layoutManager.usedRect(for: textContainer).height + 12)
        
        
        super.init(initialSize)
    }
    
    var _height:CGFloat = 24
    
    override var height: CGFloat {
        return _height + insets.top + insets.bottom
    }
    
    override func viewClass() -> AnyClass {
        return GeneralInputRowView.self
    }
    
}

class GeneralInputRowView: TableRowView,TGModernGrowingDelegate {
    

    
    let textView:TGModernGrowingTextView
    private let cleanImage: ImageButton = ImageButton()
    required init(frame frameRect: NSRect) {
        textView = TGModernGrowingTextView(frame: frameRect)
        super.init(frame: frameRect)
        addSubview(textView)
        textView.delegate = self
        textView.textFont = NSFont.normal(FontSize.text)
        
        textView.min_height = 16
        
        addSubview(cleanImage)
        
        cleanImage.set(handler: { [weak self] _ in
            self?.textView.setString("")
        }, for: .Click)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func layout() {
        super.layout()
        if let item = item as? GeneralInputRowItem {
            textView.frame = NSMakeRect(item.insets.left, item.insets.top, frame.width - item.insets.left - item.insets.right,textView.frame.height)
            cleanImage.centerY(x: frame.width - item.insets.right - cleanImage.frame.width)
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let item = item as? GeneralInputRowItem {
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(item.insets.left, frame.height - .borderSize, frame.width - item.insets.left - item.insets.right, .borderSize))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated:animated)
        textView.textColor = theme.colors.text
        textView.linkColor = theme.colors.link
        if let item = item as? GeneralInputRowItem {
            
            cleanImage.set(image: theme.icons.recentDismiss, for: .Normal)
            cleanImage.sizeToFit()
            cleanImage.isHidden = (!item.canFastClean || (item.holdText && item.text.isEmpty))
            
            if item.holdText {
                textView.defaultText = item.placeholder.string
               // if item.text != textView.string() {
                    textView.setString(item.text, animated: false)
               // }
            } else {
                if textView.placeholderAttributedString == nil || !textView.placeholderAttributedString!.isEqual(to: item.placeholder) {
                    textView.setPlaceholderAttributedString(item.placeholder, update: false)
                }
                if item.text != textView.string() {
                    textView.setString(item.text, animated: false)
                }
            }
        }
        needsLayout = true
    }
    
    public func maxCharactersLimit() -> Int32 {
        if let item = item as? GeneralInputRowItem {
            return item.limit
        }
        return 100
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
        if let item = item as? GeneralInputRowItem, let table = item.table {
            item._height = height
            
            table.noteHeightOfRow(item.index,animated)
        }
        
    }
    
    func textViewSize() -> NSSize {
        return textView.frame.size
    }
    
    func textViewEnterPressed(_ event:NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            return true
        }
        return false
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func textViewNeedClose(_ textView: Any) {
        
    }
    
    func textViewTextDidChange(_ string: String) {
        if let item = item as? GeneralInputRowItem {
            let updated = item.textFilter(string)
            if updated != string {
                textView.setString(updated)
            } else {
                item.text = string
            }
            cleanImage.isHidden = (!item.canFastClean || (item.holdText && updated.isEmpty))
        }
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        if let item = item as? GeneralInputRowItem, let pasteFilter = item.pasteFilter {
            if let string = pasteboard.string(forType: .string) {
                let value = pasteFilter(string)
                let updatedText = item.textFilter(value.1)
                if value.0 {
                    textView.setString(updatedText)
                } else {
                    textView.appendText(updatedText)
                }
                return true
            }
            
        }
        return false
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func becomeFirstResponder() -> Bool {
        return self.textView.becomeFirstResponder()
    }
    
}
