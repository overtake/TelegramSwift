//
//  TouchBarEmojiPicker.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

@available(OSX 10.12.2, *)
class TGScrubber : NSScrubber {
    private let leftShadow = ShadowView(frame: NSMakeRect(0, 0, 20, 40))
    private let rightShadow = ShadowView(frame: NSMakeRect(0, 0, 20, 40))
    init() {
        super.init(frame: NSZeroRect)
        leftShadow.shadowBackground = .black
        leftShadow.direction = .horizontal(false)
        addSubview(leftShadow)
        
        rightShadow.shadowBackground = .black
        rightShadow.direction = .horizontal(true)
        addSubview(rightShadow)
    }
    
    
    override func layout() {
        super.layout()
        leftShadow.frame = NSMakeRect(0, 0, 20, frame.height)
        rightShadow.frame = NSMakeRect(frame.width - rightShadow.frame.width, 0, 20, frame.height)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum TouchBarEmojiPickerEntry {
    case header(TextViewLayout)
    case emoji(String)
}

@available(OSX 10.12.2, *)
fileprivate extension NSTouchBarItem.Identifier {
    static let emoji = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.emoji")
}

@available(OSX 10.12.2, *)
private extension NSTouchBar.CustomizationIdentifier {
    static let emojiScrubber = NSTouchBar.CustomizationIdentifier("\(Bundle.main.bundleIdentifier!).touchBar.EmojiScrubber")
}


@available(OSX 10.12.2, *)
private class EmojiScrubberBarItem: NSCustomTouchBarItem, NSScrubberDelegate, NSScrubberDataSource, NSScrubberFlowLayoutDelegate {
    
    private static let emojiItemViewIdentifier = "EmojiItemViewIdentifier"
    private static let headerItemViewIdentifier = "HeaderItemViewIdentifier"
    
    private let entries: [TouchBarEmojiPickerEntry]
    private let selectedEmoji: (String)->Void
    init(identifier: NSTouchBarItem.Identifier, selectedEmoji:@escaping(String)->Void, entries: [TouchBarEmojiPickerEntry]) {
        self.entries = entries
        self.selectedEmoji = selectedEmoji
        super.init(identifier: identifier)
        
        let scrubber = TGScrubber()
        scrubber.register(TouchBarEmojiItemView.self, forItemIdentifier: NSUserInterfaceItemIdentifier(rawValue: EmojiScrubberBarItem.emojiItemViewIdentifier))
        scrubber.register(TouchBarScrubberHeaderItemView.self, forItemIdentifier: NSUserInterfaceItemIdentifier(rawValue: EmojiScrubberBarItem.headerItemViewIdentifier))
        
        scrubber.mode = .free
        scrubber.selectionBackgroundStyle = .roundedBackground
        scrubber.delegate = self
        scrubber.dataSource = self
        
        self.view = scrubber
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
   
    
    
    func numberOfItems(for scrubber: NSScrubber) -> Int {
        return entries.count
    }
    
    
    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        let itemView: NSScrubberItemView
        switch entries[index] {
        case let .header(title):
            let view = scrubber.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: EmojiScrubberBarItem.headerItemViewIdentifier), owner: nil) as! TouchBarScrubberHeaderItemView
            view.update(title)
            itemView = view
        case let .emoji(emoji):
            let view = scrubber.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: EmojiScrubberBarItem.emojiItemViewIdentifier), owner: nil) as! TouchBarEmojiItemView
            view.update(emoji)
            itemView = view
        }
        
        return itemView
    }
    
    func scrubber(_ scrubber: NSScrubber, layout: NSScrubberFlowLayout, sizeForItemAt itemIndex: Int) -> NSSize {
        switch entries[itemIndex] {
        case let .header(layout):
            return NSMakeSize(layout.layoutSize.width + 20, 30)
        case .emoji:
            return NSSize(width: 42, height: 30)
        }
    }
    
    
    func scrubber(_ scrubber: NSScrubber, didSelectItemAt index: Int) {
        switch entries[index] {
        case let .emoji(emoji):
            selectedEmoji(emoji)
        default:
            break
        }
        scrubber.selectedIndex = -1
    }
}

@available(OSX 10.12.2, *)
class TouchBarEmojiPicker: NSTouchBar, NSTouchBarDelegate {
    private let selectedEmoji: (String) -> Void
    private let entries: [TouchBarEmojiPickerEntry]
    init(recent: [String], segments: [EmojiSegment : [String]], selectedEmoji: @escaping(String) -> Void) {
        var entries: [TouchBarEmojiPickerEntry] = []
        if !recent.isEmpty {
            let layout = TextViewLayout(.initialize(string: L10n.touchBarRecentlyUsed, color: .grayText, font: .normal(.header)))
            layout.measure(width: .greatestFiniteMagnitude)
            entries.append(.header(layout))
            entries.append(contentsOf: recent.map {.emoji($0)})
        }
        
        for segment in segments.sorted(by: {$0.key < $1.key}) {
            let layout = TextViewLayout(.initialize(string: segment.key.localizedString, color: .grayText, font: .normal(.header)))
            layout.measure(width: .greatestFiniteMagnitude)
            entries.append(.header(layout))
            entries.append(contentsOf: segment.value.map {.emoji($0)})
        }
        
        self.entries = entries
        self.selectedEmoji = selectedEmoji
        super.init()
        delegate = self
        customizationIdentifier = .emojiScrubber
        defaultItemIdentifiers = [.emoji]
        customizationAllowedItemIdentifiers = [.emoji]
    }
    
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .emoji:
            let scrubberItem: NSCustomTouchBarItem = EmojiScrubberBarItem(identifier: identifier, selectedEmoji: selectedEmoji, entries: self.entries)
            return scrubberItem
        default:
            return nil
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
