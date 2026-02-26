//
//  StoryBotInputView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox

final class StoryBotInputView : Control, StoryInput {
    func like(_ like: StoryReactionAction, resetIfNeeded: Bool) {
        
    }
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setArguments(_ arguments: StoryArguments?, groupId: PeerId?) {
        
    }
    
    func update(_ story: StoryContentItem, animated: Bool) {
        
    }
    
    func updateState(_ state: StoryInteraction.State, animated: Bool) {
       
    }
    
    func updateInputText(_ state: ChatTextInputState, prevState: ChatTextInputState, animated: Bool) {
        
    }
    
    func updateInputState(animated: Bool) {
    }
    
    func installInputStateUpdate(_ f: ((StoryInputState) -> Void)?) {
        
    }
    
    
    func resetInputView() {
        
    }
    
    func updateInputContext(with result: ChatPresentationInputQueryResult?, context: InputContextHelper, animated: Bool) {
        
    }
    
    var isFirstResponder: Bool {
        return false
    }
    
    var text: UITextView? {
        return nil
    }
    
    var input: NSTextView? {
        return nil
    }
    
    private func updateInputSize(size: NSSize, animated: Bool) {
        
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
}
