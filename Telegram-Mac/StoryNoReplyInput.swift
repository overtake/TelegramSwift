//
//  StoryNoReplyInput.swift
//  Telegram
//
//  Created by Mike Renoir on 17.07.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TGModernGrowingTextView

final class StoryNoReplyInput : Control, StoryInput {
    
    
   
    
    
    private let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setArguments(_ arguments: StoryArguments?, groupId: PeerId?) {
        
    }
    
    func update(_ story: StoryContentItem, animated: Bool) {
        let text = strings().storyNoReplyInputNoReply
        let layout = TextViewLayout.init(.initialize(string: text, color: storyTheme.colors.grayText, font: .normal(.text)))
        layout.measure(width: frame.width)
        self.textView.update(layout)
        
    }
    
    func updateState(_ state: StoryInteraction.State, animated: Bool) {
       
    }
    
    func updateInputText(_ state: ChatTextInputState, prevState: ChatTextInputState, animated: Bool) {
        
    }
    
    func updateInputState(animated: Bool) {
        guard let superview = self.superview else {
            return
        }
        updateInputSize(size: NSMakeSize(superview.frame.width, 30), animated: animated)
    }
    
    func installInputStateUpdate(_ f: ((StoryInputState) -> Void)?) {
        
    }
    
    func makeUrl() {
        
    }
    
    func resetInputView() {
        
    }
    
    func updateInputContext(with result: ChatPresentationInputQueryResult?, context: InputContextHelper, animated: Bool) {
        
    }
    
    var isFirstResponder: Bool {
        return false
    }
    
    var text: TGModernGrowingTextView? {
        return nil
    }
    
    var input: NSTextView? {
        return nil
    }
    
    private func updateInputSize(size: NSSize, animated: Bool) {
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        guard let superview = superview, let window = self.window else {
            return
        }
        
        let wSize = NSMakeSize(window.frame.width - 100, superview.frame.height - 110)
        let aspect = StoryView.size.aspectFitted(wSize)

        transition.updateFrame(view: self, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(backingScaleFactor,  (superview.frame.width - size.width) / 2), y: aspect.height + 10 - size.height + 30), size: size))
        self.updateLayout(size: size, transition: transition)

    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: textView, frame: textView.centerFrame())
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
}
