//
//  MonoforumHorizontalView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.05.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

class MonoforumHorizontalView : View {
    private let segmentView: ScrollableSegmentView = ScrollableSegmentView(frame: NSZeroRect)
    private let selectionView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(segmentView)
        
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        self.backgroundColor = theme.colors.background
        self.selectionView.backgroundColor = theme.colors.accent
    }
    
    
    private func updateSelectionRect(animated: Bool = false) {
        
    }
    
    func set(items: [MonoforumItem], selected: Int64?, context: AccountContext, animated: Bool) {
        
        let presentation = theme
        
        let segmentTheme = ScrollableSegmentTheme(background: presentation.colors.background, border: presentation.colors.border, selector: presentation.colors.accent, inactiveText: presentation.colors.grayText, activeText: presentation.colors.accent, textFont: .normal(.title))
        
        var index: Int = 0
        let insets = NSEdgeInsets(left: 10, right: 10, top: 3, bottom: 5)
        var _items:[ScrollableSegmentItem] = []
        for tab in items {
            let title: String = tab.title
            let selected = selected.flatMap(EngineChatList.Item.Id.forum) == tab.id
           
            _items.append(ScrollableSegmentItem(title: title, index: index, uniqueId: tab.uniqueId, selected: selected, insets: insets, icon: nil, theme: segmentTheme, equatable: nil, customTextView: {
                
                let attr = NSMutableAttributedString()
                attr.append(string: "\(clown_space)" + title, color: selected ? segmentTheme.activeText : segmentTheme.inactiveText, font: segmentTheme.textFont)
                
                attr.insertEmbedded(.embeddedAnimated(tab.file), for: clown)

                let layout = TextViewLayout(attr)
                layout.measure(width: .greatestFiniteMagnitude)

                let textView = InteractiveTextView()
                textView.userInteractionEnabled = false
                textView.textView.isSelectable = false
                textView.set(text: layout, context: context)
                
                return textView
            }))
            index += 1
        }
        
        segmentView.updateItems(_items, animated: animated)
        
    }
    
    override func layout() {
        super.layout()
        segmentView.frame = bounds
    }
}
