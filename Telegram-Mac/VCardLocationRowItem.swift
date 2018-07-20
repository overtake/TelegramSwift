//
//  VCardLocationRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Contacts
import TelegramCoreMac

class VCardLocationRowItem: GeneralRowItem {
    fileprivate let address: CNLabeledValue<CNPostalAddress>
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, address: CNLabeledValue<CNPostalAddress>, account: Account) {
        self.address = address
        let attr = NSMutableAttributedString()
        
        if let label = address.label {
            _ = attr.append(string: label, color: theme.colors.blueUI, font: .normal(.text))
            _ = attr.append(string: "\n\n")
        }
        
        _ = attr.append(string: address.value.street, color: theme.colors.text, font: .normal(.text))
        _ = attr.append(string: "\n", color: theme.colors.text, font: .normal(.text))
        _ = attr.append(string: address.value.city, color: theme.colors.text, font: .normal(.text))
        _ = attr.append(string: "\n", color: theme.colors.text, font: .normal(.text))
        _ = attr.append(string: address.value.country, color: theme.colors.text, font: .normal(.text))
        _ = attr.append(string: "\n", color: theme.colors.text, font: .normal(.text))
        
        self.textLayout = TextViewLayout(attr)
        super.init(initialSize, stableId: stableId)
        
    }
    
    override var height: CGFloat {
        return max(textLayout.layoutSize.height, 80)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - 180)
        return result
    }
    
    override func viewClass() -> AnyClass {
        return VCardLocationRowView.self
    }
    
}

private final class VCardLocationRowView : TableRowView {
    fileprivate let textView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = theme.colors.background
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? VCardLocationRowItem else { return }
        
        textView.centerY(x: item.inset.left)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        guard let item = item as? VCardLocationRowItem else { return }
        textView.update(item.textLayout)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
