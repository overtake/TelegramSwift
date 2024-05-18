//
//  FactCheckMessageView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.05.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

class FactCheckMessageLayout {
    let text: TextViewLayout
    let title: TextViewLayout
    let whatThisLayout: TextViewLayout
    let context: AccountContext
    let presentation: WPLayoutPresentation
    private(set) var size: NSSize = .zero
    
    
    init(_ message: Message, context: AccountContext, presentation: WPLayoutPresentation) {
        
        self.context = context
        self.presentation = presentation
        
        let text = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
        
        self.text = .init(.initialize(string: text, color: presentation.text, font: .normal(.text)), alwaysStaticItems: true, mayItems: true)
        self.title = .init(.initialize(string: strings().factCheckTitle, color: presentation.activity.main, font: .medium(.text)))
        self.whatThisLayout = .init(.initialize(string: strings().factCheckWhatThis, color: presentation.activity.main, font: .normal(.small)), alignment: .center)
        
        self.title.measure(width: .greatestFiniteMagnitude)
        self.whatThisLayout.measure(width: .greatestFiniteMagnitude)
        
    }
    
    func measure(for width: CGFloat) {
        self.text.measure(width: width - 20)
        size = NSMakeSize(width, 2 + title.layoutSize.height + text.layoutSize.height + 2 + 4)
    }
    
}

final class FactCheckMessageView : View {
    
    let textView = InteractiveTextView()
    private let titleView = TextView()
    private let whatThisView = TextView()
    private let dashLayer = DashLayer()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(titleView)
        addSubview(whatThisView)
        
        textView.textView.userInteractionEnabled = true
        textView.textView.isSelectable = true
        
        self.layer?.addSublayer(dashLayer)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        whatThisView.isSelectable = false
        whatThisView.scaleOnClick = true
        
        layer?.cornerRadius = 4
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(layout: FactCheckMessageLayout, animated: Bool) {
        self.textView.set(text: layout.text, context: layout.context)
        self.titleView.update(layout.title)
        self.whatThisView.update(layout.whatThisLayout)
        self.whatThisView.setFrameSize(NSMakeSize(self.whatThisView.frame.width + 6, self.whatThisView.frame.height + 2))
        self.whatThisView.backgroundColor = layout.presentation.activity.main.withAlphaComponent(0.2)
        self.whatThisView.layer?.cornerRadius = self.whatThisView.frame.height / 2
        self.dashLayer.colors = layout.presentation.activity

        self.backgroundColor = layout.presentation.activity.main.withAlphaComponent(0.1)
    }
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: titleView, frame: NSMakeRect(10, 2, titleView.frame.width, titleView.frame.height))
        transition.updateFrame(view: whatThisView, frame: NSMakeRect(titleView.frame.maxX + 6, 4, whatThisView.frame.width, whatThisView.frame.height))
        transition.updateFrame(view: textView, frame: NSMakeRect(10, titleView.frame.maxY, textView.frame.width, textView.frame.height))
        transition.updateFrame(layer: dashLayer, frame: NSMakeRect(0, 0, 3, size.height))
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
}
