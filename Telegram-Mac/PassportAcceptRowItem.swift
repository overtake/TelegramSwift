//
//  PassportAcceptRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class PassportAcceptRowItem: GeneralRowItem {

    init(_ initialSize: NSSize, stableId: AnyHashable, enabled: Bool, action:@escaping()->Void) {
        super.init(initialSize, height: 50, stableId: stableId, action: action, enabled: enabled)
    }
    
    
    override func viewClass() -> AnyClass {
        return PassportAcceptRowView.self
    }
}

final class PassportAcceptRowView : TableRowView {
    private let button: TextButton = TextButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
        button.set(font: .medium(.header), for: .Normal)
        
        button.set(handler: { [weak self] _ in
            guard let item = self?.item as? GeneralRowItem else {return}
            item.action()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {return}
        
        _ = button.sizeToFit(NSZeroSize, NSMakeSize(170, 40), thatFit: true)//.setFrameSize(NSMakeSize(frame.width - item.inset.left - item.inset.right, 40))
        button.center()
        button.layer?.cornerRadius = 20
    }
    
    override func updateColors() {
        super.updateColors()
        button.set(text: strings().secureIdRequestAccept, for: .Normal)
        button.set(color: .white, for: .Normal)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GeneralRowItem else {return}

      //  button.userInteractionEnabled = item.enabled
        button.autohighlight = false
        button.set(background: item.enabled ? theme.colors.accent : theme.colors.grayForeground, for: .Normal)
        button.set(image: theme.icons.secureIdAuth, for: .Normal)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
