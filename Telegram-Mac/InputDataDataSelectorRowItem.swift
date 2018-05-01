//
//  InputDataDataSelectorRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class InputDataDataSelectorRowItem: GeneralRowItem, InputDataRowDataValue {

    private let updated:()->Void
    fileprivate var _value: InputDataValue {
        didSet {
            if _value != oldValue {
                updated()
            }
        }
    }
    fileprivate let placeholderLayout: TextViewLayout

    var value: InputDataValue {
        return _value
    }
    
    fileprivate let values: [ValuesSelectorValue<InputDataValue>]
    init(_ initialSize: NSSize, stableId: AnyHashable, value: InputDataValue, error: InputDataValueError?, placeholder: String, updated: @escaping()->Void, values: [ValuesSelectorValue<InputDataValue>]) {
        self._value = value
        self.updated = updated
        self.placeholderLayout = TextViewLayout(.initialize(string: placeholder, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        self.values = values
        super.init(initialSize, height: 42, stableId: stableId, error: error)
        _ = makeSize(initialSize.width, oldWidth: oldWidth)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        placeholderLayout.measure(width: 100)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return InputDataDataSelectorRowView.self
    }
    
}


final class InputDataDataSelectorRowView : GeneralRowView {
    private let placeholderTextView = TextView()
    private let dataTextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(placeholderTextView)
        addSubview(dataTextView)
        placeholderTextView.userInteractionEnabled = false
        placeholderTextView.isSelectable = false
        dataTextView.userInteractionEnabled = false
        dataTextView.isSelectable = false
    }
    
    override func mouseDown(with event: NSEvent) {
        
        guard let item = item as? InputDataDataSelectorRowItem else {return}
        showModal(with: ValuesSelectorModalController(values: item.values, selected: item.values.first(where: {$0.value == item.value}), title: item.placeholderLayout.attributedString.string, onComplete: { [weak item] newValue in
            item?._value = newValue.value
            item?.redraw()
        }), for: mainWindow)
       
       
    }
    
    override func shakeView() {
        dataTextView.shake()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? InputDataDataSelectorRowItem else {return}
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? InputDataDataSelectorRowItem else {return}
        placeholderTextView.setFrameOrigin(item.inset.left, 14)
        
        dataTextView.layout?.measure(width: frame.width - item.inset.left - item.inset.right - 106)
        dataTextView.update(dataTextView.layout)
        dataTextView.setFrameOrigin(item.inset.left + 106, 14)
    }
    
    override func updateColors() {
        placeholderTextView.backgroundColor = theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? InputDataDataSelectorRowItem else {return}
        placeholderTextView.update(item.placeholderLayout)
        
        var selected: ValuesSelectorValue<InputDataValue>?
        let index:Int? = item.values.index(where: { entry -> Bool in
            return entry.value == item.value
        })
        if let index = index {
            selected = item.values[index]
        }
        let layout = TextViewLayout(.initialize(string: selected?.localized ?? item.placeholderLayout.attributedString.string, color: selected == nil ? theme.colors.grayText : theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        dataTextView.update(layout)
        
        needsLayout = true
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
