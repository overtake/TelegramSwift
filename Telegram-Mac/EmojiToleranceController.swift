//
//  EmojiToleranceController.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
private class EmojiTolerance : View {
    
    
    init(frame frameRect: NSRect, emoji:String, handle:@escaping(String)->Void) {
        super.init(frame: frameRect)
        
        
        let modifiers = emoji.emojiSkinToneModifiers
        var x:CGFloat = 2
        
        let add:(String)->Void = { [weak self] emoji in
            let button: TitleButton = TitleButton()
            button.set(font: .normal(.header), for: .Normal)
            button.set(text: emoji, for: .Normal)
            button.setFrameSize(NSMakeSize(30, 30))
            button.centerY(x: x)
            button.set(background: .clear, for: .Normal)
            button.set(background: theme.colors.grayForeground, for: .Highlight)
            button.layer?.cornerRadius = .cornerRadius
            self?.addSubview(button)
            x += button.frame.width
            
            button.set(handler: { _ in
                handle(emoji)
            }, for: .Click)
        }
        
        add(emoji)
        
        for modifier in modifiers {
           add("\(emoji)\(modifier)")
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
    
    init(_ emoji:String, postbox: Postbox, handle:@escaping(String)->Void) {
        self.emoji = emoji
        super.init(nibName: nil, bundle: nil)
        
       
        self.view = EmojiTolerance(frame: NSMakeRect(0, 2, 30 * 6 + 4, 34), emoji: emoji, handle: handle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
