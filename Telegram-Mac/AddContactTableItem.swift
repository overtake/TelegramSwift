//
//  AddContactTableItem.swift
//  Telegram
//
//  Created by keepcoder on 10/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class AddContactTableItem: TableRowItem {
    private let _stableId:AnyHashable
    fileprivate let text:TextViewLayout
    override var stableId: AnyHashable {
        return _stableId
    }
    fileprivate let addContact:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, addContact: @escaping()->Void) {
        _stableId = stableId
        
        self.text = TextViewLayout(.initialize(string: tr(L10n.contactsAddContact), color: theme.colors.blueUI, font: .normal(.title)), maximumNumberOfLines: 1)
        self.addContact = addContact
        super.init(initialSize)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        text.measure(width: width - 80)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return AddContactTableRowView.self
    }
    
    override var height: CGFloat {
        return 50
    }
    
}

class AddContactTableRowView : TableRowView {
    private let imageView = ImageView()
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(imageView)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
    }
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() {
            if let item = item as? AddContactTableItem {
                item.addContact()
            }
        }
    }
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        if let item = item as? AddContactTableItem {
            self.textView.update(item.text)
            
            imageView.image = theme.icons.contactsNewContact
            imageView.sizeToFit()
            needsLayout = true
            
        }
    }
    
    
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(56, frame.height - .borderSize, frame.width - 56, .borderSize))
        ctx.fill(NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height))
    }
    
    override func layout() {
        super.layout()
        imageView.centerY(x: floorToScreenPixels(scaleFactor: backingScaleFactor, (56 - imageView.frame.width)/2))
        textView.layout?.measure(width: frame.width - 66)
        textView.update(textView.layout)
        textView.centerY(x: 56)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
