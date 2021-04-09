//
//  AnimatedBadgeView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 30.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit


final class AnimatedBadgeView : View {
    
    private let textView: DynamicCounterTextView = DynamicCounterTextView()
    
    override init() {
        super.init(frame: .zero)
        addSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func update(dynamicValue: DynamicCounterTextView.Value, backgroundColor: NSColor, animated: Bool, frame: NSRect) {
        
        textView.update(dynamicValue, animated: animated)
        
        let textFrame = frame.focus(dynamicValue.size)
        
        
        self.change(size: frame.size, animated: animated)
        self.change(pos: frame.origin, animated: animated)
        textView.change(size: textFrame.size, animated: animated)
        textView.change(pos: textFrame.origin, animated: animated)
        
        self.backgroundColor = backgroundColor
        if animated {
            layer?.animateBackground()
        }

        layer?.cornerRadius = frame.height / 2
    }
}
