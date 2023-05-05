//
//  StoryMyInputView.swift
//  Telegram
//
//  Created by Mike Renoir on 05.05.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TGModernGrowingTextView
import Postbox
import TelegramCore
import SwiftSignalKit


private let more_image = NSImage(named: "Icon_StoryMore")!.precomposed(NSColor.white)
private let delete_image = NSImage(named: "Icon_StoryDelete")!.precomposed(NSColor.white)



final class StoryMyInputView : Control, StoryInput {
    
    private let delete = ImageButton()
    private let more = ImageButton()
    private let views = View()
    private let viewsText = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.cornerRadius = 10
        addSubview(delete)
        addSubview(more)
        addSubview(views)
        views.addSubview(viewsText)
        
        viewsText.userInteractionEnabled = false
        viewsText.isSelectable = false
        
        more.scaleOnClick = true
        more.autohighlight = false
        
        delete.scaleOnClick = true
        delete.autohighlight = false
        
        more.set(image: more_image, for: .Normal)
        more.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
        
        delete.set(image: delete_image, for: .Normal)
        delete.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
        
        more.contextMenu = {
            
            let menu = ContextMenu(presentation: AppMenu.Presentation.current(storyTheme.colors))
            
            menu.addItem(ContextMenuItem("Share", itemImage: MenuAnimation.menu_share.value))
            menu.addItem(ContextMenuItem("Hide", itemImage: MenuAnimation.menu_hide.value))

            menu.addItem(ContextSeparatorItem())
            menu.addItem(ContextMenuItem("Delete", itemMode: .destruct, itemImage: MenuAnimation.menu_report.value))

            return menu
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setArguments(_ arguments: StoryArguments?, groupId: PeerId?) {
        let text: NSAttributedString = .initialize(string: "No Views yet", color: storyTheme.colors.text, font: .normal(.short))
        let layout = TextViewLayout(text)
        layout.measure(width: .greatestFiniteMagnitude)
        self.viewsText.update(layout)
        self.views.setFrameSize(layout.layoutSize)
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

        transition.updateFrame(view: self, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(backingScaleFactor,  (superview.frame.width - size.width) / 2), y: 20 + aspect.height + 10 - size.height + 30), size: size))
        self.updateLayout(size: size, transition: transition)

    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: delete, frame: delete.centerFrameY(x: size.width - delete.frame.width - 16))
        transition.updateFrame(view: more, frame: more.centerFrameY(x: delete.frame.minX - more.frame.width - 10))
        transition.updateFrame(view: views, frame: views.centerFrameY(x: 16))
        transition.updateFrame(view: viewsText, frame: viewsText.centerFrameY(x: 0))
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
}
