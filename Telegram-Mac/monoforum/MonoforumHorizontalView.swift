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
    
    func set(items: [MonoforumItem], selected: Int64?, chatInteraction: ChatInteraction, animated: Bool) {
        
        let presentation = theme
        let context = chatInteraction.context
        
        let segmentTheme = ScrollableSegmentTheme(background: presentation.colors.background, border: presentation.colors.border, selector: presentation.colors.accent, inactiveText: presentation.colors.grayText, activeText: presentation.colors.accent, textFont: .normal(.title))
        
        var index: Int = 0
        let insets = NSEdgeInsets(left: 10, right: 10, top: 3, bottom: 5)
        var _items:[ScrollableSegmentItem] = []
        
        _items.append(.init(title: "", index: index, uniqueId: -1, selected: false, insets: NSEdgeInsets(left: 10, right: 10), icon: nil, theme: segmentTheme, equatable: nil))
        index += 1
        
        _items.append(.init(title: "", index: index, uniqueId: -1, selected: false, insets: NSEdgeInsets(left: 15, right: 15), icon: NSImage(resource: .iconMonoforumToggle).precomposed(theme.colors.grayIcon), theme: segmentTheme, equatable: nil))
        index += 1
        
        //TODOLANG
        _items.append(.init(title: "All", index: index, uniqueId: 0, selected: selected == nil, insets: insets, icon: nil, theme: segmentTheme, equatable: .init(selected)))
        index += 1
        
        for tab in items {
            let title: String = tab.title
            let selected = selected == tab.uniqueId
           
            _items.append(ScrollableSegmentItem(title: title, index: index, uniqueId: tab.uniqueId, selected: selected, insets: insets, icon: nil, theme: segmentTheme, equatable: .init(selected), customTextView: {
                
                let attr = NSMutableAttributedString()
                attr.append(string: "\(clown_space)" + title, color: selected ? segmentTheme.activeText : segmentTheme.inactiveText, font: segmentTheme.textFont)
                
                switch tab.mediaItem(selected: selected) {
                case let .topic(fileId):
                    attr.insertEmbedded(.embeddedAnimated(fileId), for: clown)
                case let .avatar(peer):
                    attr.insertEmbedded(.embeddedAvatar(peer), for: clown)
                default:
                    break
                }
                
                

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
        
        segmentView.didChangeSelectedItem = { [weak chatInteraction] item in
            if item.uniqueId == 0 || item.uniqueId > 0 {
                chatInteraction?.updateChatLocationThread(item.uniqueId == 0 ? nil : item.uniqueId)
            } else if item.uniqueId == -1 {
                chatInteraction?.toggleMonoforumState()
            }
        }
        
    }
    
    override func layout() {
        super.layout()
        segmentView.frame = bounds
    }
}
