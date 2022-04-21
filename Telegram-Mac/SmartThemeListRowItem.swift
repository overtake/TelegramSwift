//
//  SmartThemeListRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore



class SmartThemeListRowItem: GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let theme: TelegramPresentationTheme
    fileprivate let list: [SmartThemeCachedData]
    fileprivate let togglePalette: (InstallThemeSource)->Void
    fileprivate let animatedEmojiStickers: [String: StickerPackItem]
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, theme: TelegramPresentationTheme, list: [SmartThemeCachedData], animatedEmojiStickers: [String: StickerPackItem], viewType: GeneralViewType, togglePalette: @escaping(InstallThemeSource)->Void) {
        self.context = context
        self.theme = theme
        self.list = list
        self.animatedEmojiStickers = animatedEmojiStickers
        self.togglePalette = togglePalette
        super.init(initialSize, height: 90 + viewType.innerInset.top + viewType.innerInset.bottom, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return SmartThemeListRowView.self
    }
}


private final class SmartThemeListRowView : GeneralContainableRowView {
    private let tableView = HorizontalTableView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(self.tableView)
        
    }
    
    
    override func updateColors() {
        guard let item = item as? SmartThemeListRowItem else {
            return
        }
        self.containerView.backgroundColor = item.theme.colors.background
        self.borderView.backgroundColor = item.theme.colors.border
        self.backgroundColor = item.viewType.rowBackground
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? SmartThemeListRowItem else {
            return theme.colors.background
        }
        return item.theme.colors.background
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? SmartThemeListRowItem else {
            return
        }
        
        let innerInset = item.viewType.innerInset
        self.borderView.frame = NSMakeRect(innerInset.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInset.left - innerInset.right, .borderSize)
        
        self.tableView.frame = NSMakeRect(0, innerInset.top, self.containerView.frame.width, self.containerView.frame.height - innerInset.bottom - innerInset.top)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        
        let previous: SmartThemeListRowItem? = self.item as? SmartThemeListRowItem
        super.set(item: item, animated: animated)
        
        guard let item = item as? SmartThemeListRowItem else {
            return
        }
        
        self.tableView.getBackgroundColor = {
            item.theme.colors.background
        }
        
        
        tableView.needUpdateVisibleAfterScroll = true
        
        self.layout()
        
        
        let reloadAnimated = animated && previous?.list.count != item.list.count
//
        tableView.beginTableUpdates()
        tableView.removeAll(animation: reloadAnimated ? .effectFade : .none)
        _ = tableView.addItem(item: GeneralRowItem(.zero, height: 10), animation: reloadAnimated ? .effectFade : .none)
        
        var scrollItem:SmartThemePreviewRowItem? = nil
        
        
        for (i, smartTheme) in item.list.enumerated() {
            let data = smartTheme.data
            let selected: Bool = item.theme.colors.accent == data.appTheme.colors.accent && item.theme.wallpaper.wallpaper == data.appTheme.wallpaper.wallpaper
            let smartItem: SmartThemePreviewRowItem
            switch smartTheme.source {
            case let .cloud(theme):
                smartItem = SmartThemePreviewRowItem(tableView.frame.size, context: item.context, stableId: theme.id, bubbled: item.theme.bubbled, emojies: item.animatedEmojiStickers, theme: (data.emoticon, data.previewIcon, data.appTheme), selected: selected, select: { [weak item] _ in
                    item?.togglePalette(.cloud(theme, InstallCloudThemeCachedData(palette: data.appTheme.colors, wallpaper: data.appTheme.wallpaper.wallpaper, cloudWallpaper: data.appTheme.wallpaper.associated?.cloud)))
                })
            case let .local(palette):
                smartItem = SmartThemePreviewRowItem(tableView.frame.size, context: item.context, stableId: arc4random(), bubbled: item.theme.bubbled, emojies: item.animatedEmojiStickers, theme: (data.emoticon, data.previewIcon, data.appTheme), selected: selected, select: { [weak item] _ in
                    item?.togglePalette(.local(palette))
                })
            }
            _ = tableView.addItem(item: smartItem)
            
            if selected && scrollItem == nil {
                scrollItem = smartItem
            }
        }

        _ = tableView.addItem(item: GeneralRowItem(.zero, height: 10), animation: reloadAnimated ? .effectFade : .none)
        tableView.endTableUpdates()
        
        if let item = scrollItem {
            self.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: reloadAnimated, focus: .init(focus: false), inset: 0), true)
        }
    }
}
