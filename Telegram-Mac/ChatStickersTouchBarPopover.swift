//
//  ChatStickersTouchBarPopover.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

@available(OSX 10.12.2, *)
fileprivate extension NSTouchBarItem.Identifier {
    static let sticker = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.sticker")
}

@available(OSX 10.12.2, *)
private extension NSTouchBar.CustomizationIdentifier {
    static let stickersScrubber = NSTouchBar.CustomizationIdentifier("\(Bundle.main.bundleIdentifier!).touchBar.chat.StickersScrubber")
}

enum TouchBarStickerEntry {
    case header(TextViewLayout)
    case sticker(TelegramMediaFile)
}



@available(OSX 10.12.2, *)
class StickersScrubberBarItem: NSCustomTouchBarItem, NSScrubberDelegate, NSScrubberDataSource, NSScrubberFlowLayoutDelegate {
    
    private static let stickerItemViewIdentifier = "StickersItemViewIdentifier"
    private static let headerItemViewIdentifier = "HeaderItemViewIdentifier"

    private let entries: [TouchBarStickerEntry]
    private let account: Account
    private let sendSticker: (TelegramMediaFile)->Void
    init(identifier: NSTouchBarItem.Identifier, account: Account, sendSticker:@escaping(TelegramMediaFile)->Void, entries: [TouchBarStickerEntry]) {
        self.entries = entries
        self.account = account
        self.sendSticker = sendSticker
        super.init(identifier: identifier)
        
        let scrubber = TGScrubber()
        scrubber.register(TouchBarStickerItemView.self, forItemIdentifier: NSUserInterfaceItemIdentifier(rawValue: StickersScrubberBarItem.stickerItemViewIdentifier))
        scrubber.register(TouchBarScrubberHeaderItemView.self, forItemIdentifier: NSUserInterfaceItemIdentifier(rawValue: StickersScrubberBarItem.headerItemViewIdentifier))
        
        scrubber.mode = .free
        scrubber.selectionBackgroundStyle = .roundedBackground
        scrubber.floatsSelectionViews = true
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
    
    func scrubber(_ scrubber: NSScrubber, didHighlightItemAt highlightedIndex: Int) {
        switch entries[highlightedIndex] {
        case .header:
            scrubber.selectionBackgroundStyle = nil
            scrubber.selectedIndex = -1
        default:
            scrubber.selectionBackgroundStyle = .roundedBackground
        }
    }
    
    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        let itemView: NSScrubberItemView
        switch entries[index] {
        case let .header(title):
             let view = scrubber.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: StickersScrubberBarItem.headerItemViewIdentifier), owner: nil) as! TouchBarScrubberHeaderItemView
             view.update(title)
            itemView = view
        case let .sticker(file):
            let view = scrubber.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: StickersScrubberBarItem.stickerItemViewIdentifier), owner: nil) as! TouchBarStickerItemView
            view.update(account: account, file: file)
            itemView = view
        }
        
        return itemView
    }
    
    func scrubber(_ scrubber: NSScrubber, layout: NSScrubberFlowLayout, sizeForItemAt itemIndex: Int) -> NSSize {
        switch entries[itemIndex] {
        case let .header(layout):
            return NSMakeSize(layout.layoutSize.width + 20, 30)
        case .sticker:
            return NSSize(width: 40, height: 30)
        }
    }
    
    
    func scrubber(_ scrubber: NSScrubber, didSelectItemAt index: Int) {
        switch entries[index] {
        case let .sticker(file):
            sendSticker(file)
        default:
            break
        }
    }
}


@available(OSX 10.12.2, *)
final class ChatStickersTouchBarPopover : NSTouchBar, NSTouchBarDelegate {
    private let chatInteraction: ChatInteraction
    private let entries: [TouchBarStickerEntry]
    private let dismiss:(TelegramMediaFile?) -> Void
    init(chatInteraction: ChatInteraction, dismiss:@escaping(TelegramMediaFile?)->Void, entries: [TouchBarStickerEntry]) {
        self.dismiss = dismiss
     
        self.entries = entries
        self.chatInteraction = chatInteraction
        super.init()
        delegate = self
        customizationIdentifier = .stickersScrubber
        defaultItemIdentifiers = [.sticker]
        customizationAllowedItemIdentifiers = [.sticker]
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .sticker:
            let scrubberItem: NSCustomTouchBarItem = StickersScrubberBarItem(identifier: identifier, account: chatInteraction.account, sendSticker: { [weak self] file in
                self?.dismiss(file)
            }, entries: self.entries)
            return scrubberItem
        default:
            return nil
        }
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
