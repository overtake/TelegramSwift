//
//  EmojiToleranceController.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
private class EmojiTolerance : View {
    
    
    init(frame frameRect: NSRect, emoji:String, handle:@escaping(String, String?)->Void) {
        super.init(frame: frameRect)
        
        
        let modifiers = emoji.emojiSkinToneModifiers
        var x:CGFloat = 2
        
        let add:(String, String, String?)->Void = { [weak self] emoji, notModified, modifier in
            let button: TitleButton = TitleButton()
            button.set(font: .normal(.header), for: .Normal)
            button.set(text: emoji, for: .Normal)
            button.setFrameSize(NSMakeSize(30, 30))
            button.centerY(x: x, addition: 0)
            button.set(background: .clear, for: .Normal)
            button.set(background: theme.colors.grayForeground, for: .Highlight)
            button.layer?.cornerRadius = .cornerRadius
            self?.addSubview(button)
            x += button.frame.width
            
            button.set(handler: { _ in
                handle(notModified, modifier)
            }, for: .Click)
        }
        
        add(emoji, emoji, nil)
        
        for modifier in modifiers {
           add(emoji.emojiWithSkinModifier(modifier), emoji, modifier)
        }
        
    }
    
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class EmojiToleranceController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    private let emoji:String
    
    init(_ emoji:String, postbox: Postbox, handle:@escaping(String, String?)->Void) {
        self.emoji = emoji
        super.init(nibName: nil, bundle: nil)
        
       
        self.view = EmojiTolerance(frame: NSMakeRect(0, 4, 30 * 6 + 4, 34), emoji: emoji, handle: handle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


final class EmojiToleranceContextMenuItem : ContextMenuItem {
    let emoji: String
    let callback:(String?)->Void
    init(emoji: String, callback:@escaping(String?)->Void) {
        self.emoji = emoji
        self.callback = callback
        super.init("", handler: {
            
        })
    }
    
    
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return EmojiToleranceContextMenuRowItem.init(.zero, presentation: presentation, menuItem: self, interaction: interaction)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class EmojiToleranceContextMenuRowItem : AppMenuBasicItem {
    override func viewClass() -> AnyClass {
        return EmojiToleranceContextMenuRowView.self
    }
    
    fileprivate var castMenuItem: EmojiToleranceContextMenuItem? {
        return self.menuItem as? EmojiToleranceContextMenuItem
    }
    
    override var effectiveSize: NSSize {
        return NSMakeSize(30 * 6 + 10, 30)
    }
    
    override var height: CGFloat {
        return 30
    }
    
    
    var emoji: String {
        return castMenuItem?.emoji ?? ""
    }
    var callback:((String?)->Void)? {
        return castMenuItem?.callback
    }
}

private final class EmojiToleranceContextMenuRowView: AppMenuBasicItemView {
    
    private var tolerance: EmojiTolerance?
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? EmojiToleranceContextMenuRowItem else {
            return
        }
        
        let current: EmojiTolerance
        if let view = self.tolerance {
            current = view
        } else {
            current = EmojiTolerance(frame: CGRect(origin: .zero, size: CGSize.init(width: 30 * 6, height: item.height)), emoji: item.emoji, handle: { [weak item] emoji, color in
                item?.callback?(color)
                if let menuItem = item?.menuItem {
                    item?.interaction?.action(menuItem)
                }
            })
            addSubview(current)
            self.tolerance = current
        }
    }
    
}
