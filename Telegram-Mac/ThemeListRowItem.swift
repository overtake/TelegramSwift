//
//  ThemeListRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import ColorPalette
import Postbox
import SwiftSignalKit


private final class HorizontalThemeFirstItem : GeneralRowItem {
    override var width: CGFloat {
        return 5
    }
    override var height: CGFloat {
        return 5
    }
    override func viewClass() -> AnyClass {
        return HorizontalRowView.self
    }
}

private final class ThemeCachedItem {
    let source: InstallThemeSource
    init(source: InstallThemeSource) {
        self.source = source
    }
}

private let cache:NSCache<NSNumber, ThemeCachedItem> = NSCache()

private final class HorizontalThemeItem : GeneralRowItem {
    fileprivate let themeType: ThemeSource
    fileprivate let titleLayout: TextViewLayout
    fileprivate let selected: Bool
    fileprivate let theme: TelegramPresentationTheme
    fileprivate let context: AccountContext
    fileprivate let togglePalette: (InstallThemeSource)->Void
    fileprivate let menuItems: (ThemeSource)->[ContextMenuItem]
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, theme: TelegramPresentationTheme, themeType: ThemeSource, selected: Bool, togglePalette: @escaping(InstallThemeSource)->Void, menuItems: @escaping(ThemeSource)->[ContextMenuItem]) {
        self.themeType = themeType
        self.selected = selected
        self.theme = theme
        self.menuItems = menuItems
        self.togglePalette = togglePalette
        self.context = context
        let attr: NSAttributedString
        switch themeType {
        case let .local(palette, _):
            attr = .initialize(string: localizedString("AppearanceSettings.ColorTheme.\(palette.name)"), color: selected ? theme.colors.accent : theme.colors.text, font: selected ? .medium(12) : .normal(12))
        case let .cloud(cloud):
            attr = .initialize(string: cloud.title, color: selected ? theme.colors.accent : theme.colors.text, font: selected ? .medium(12) : .normal(12))
        }
        self.titleLayout = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end, alignment: .center, alwaysStaticItems: true)
        self.titleLayout.measure(width: 80)
        super.init(initialSize, height: 90, stableId: stableId)
    }
    
    
    override func viewClass() -> AnyClass {
        return HorizontalThemeView.self
    }
    
    override var width: CGFloat {
        return 100
    }
}

struct LocalPaletteWithReference {
    let palette: ColorPalette
    let cloud: TelegramTheme?
    init(palette: ColorPalette, cloud: TelegramTheme?) {
        self.palette = palette
        self.cloud = cloud
    }
    func withAccentColor(_ color: PaletteAccentColor) -> LocalPaletteWithReference {
        return LocalPaletteWithReference(palette: self.palette.withAccentColor(color), cloud: self.cloud)
    }
}

private final class HorizontalThemeView : HorizontalRowView {
    private let containerView = View(frame: NSMakeRect(0, 26, 100, 74))
    private let holderView: View = View()
    private let selectionView: View = View()
    private let imageView = TransformImageView(frame: NSMakeRect(0, 0, 80, 60))
    private let nameView: TextView = TextView()
    private let overlay: Control = Control()
    private let progressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 20, 20))
    private let disposable = MetaDisposable()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        containerView.addSubview(nameView)
        containerView.addSubview(holderView)
        containerView.addSubview(imageView)
        containerView.addSubview(selectionView)
        containerView.addSubview(overlay)
        holderView.addSubview(progressIndicator)
        selectionView.layer?.cornerRadius = 10
        selectionView.layer?.borderWidth = 2.5
        holderView.layer?.cornerRadius = 10
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        
        super.set(item: item, animated: animated)
        
        guard let item = item as? HorizontalThemeItem else {
            return
        }
        
        overlay.removeAllHandlers()
        let key = PhotoCacheKeyEntry.theme(item.themeType, item.theme.bubbled, .general)
        var cachedData: InstallThemeSource? = cache.object(forKey: .init(value: key.hashValue))?.source
        
        overlay.set(handler: { [weak item] _ in
            if let cachedData = cachedData {
                item?.togglePalette(cachedData)
            }
        }, for: .Click)
        
        overlay.contextMenu = { [weak item] in
            if let item = item {
                let items = item.menuItems(item.themeType)
                let menu = ContextMenu()
                for item in items {
                    menu.addItem(item)
                }
                return menu
            } else {
                return nil
            }
        }
        
        progressIndicator.progressColor = item.theme.colors.grayIcon
        
        let signal = themeAppearanceThumbAndData(context: item.context, bubbled: item.theme.bubbled, parent: item.theme.colors, source: item.themeType) |> deliverOnMainQueue
        
        self.imageView.setSignal(signal: cachedThemeThumb(source: item.themeType, bubbled: item.theme.bubbled), clearInstantly: false)

        var animated: Bool = !self.imageView.hasImage
        
        switch item.themeType {
        case .local:
            progressIndicator.isHidden = true
            animated = false
            self.imageView.layer?.contentsGravity = .resize
        case let .cloud(cloud):
            progressIndicator.isHidden = self.imageView.hasImage
            self.imageView.layer?.contentsGravity = cloud.file != nil ? .resize : .center
        }
        
        disposable.set(signal.start(next: { [weak self] image, data in
            self?.imageView.setSignal(signal: .single(image), clearInstantly: true, animate: animated)
            self?.progressIndicator.isHidden = true
            cacheThemeThumb(image, source: item.themeType, bubbled: item.theme.bubbled)
            let key = PhotoCacheKeyEntry.theme(item.themeType, item.theme.bubbled, .general)
            cache.setObject(ThemeCachedItem(source: data), forKey: .init(value: key.hashValue))
            cachedData = data
        }))
        
        
        selectionView.layer?.borderWidth = item.selected ? 2 : 1

        
        nameView.update(item.titleLayout)
        needsLayout = true
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? HorizontalThemeItem else {
            return theme.colors.background
        }
        return item.theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? HorizontalThemeItem else {
            return
        }
        backgroundColor = backdorColor
        selectionView.layer?.borderColor = item.selected ? item.theme.colors.accentSelect.cgColor : item.theme.colors.border.cgColor
        containerView.backgroundColor = backdorColor
        switch item.themeType {
        case .local:
            holderView.backgroundColor = item.theme.colors.grayBackground
        case let .cloud(cloud):
            holderView.backgroundColor = cloud.file != nil ? item.theme.colors.grayBackground : item.theme.colors.background
        }
        containerView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        holderView.frame = NSMakeRect(10, 0, 80, 55)
        selectionView.frame = NSMakeRect(10, 0, 80, 55)
        imageView.frame = NSMakeRect(11, 1, 78, 53)
        overlay.frame = NSMakeRect(10, 0, 80, 55)
        nameView.centerX(y: containerView.frame.height - nameView.frame.height)
        progressIndicator.center()
    }
    
    
    deinit {
        disposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



class ThemeListRowItem: GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let theme: TelegramPresentationTheme
    fileprivate let cloudThemes:[TelegramTheme]
    fileprivate let local:[LocalPaletteWithReference]
    fileprivate let togglePalette: (InstallThemeSource)->Void
    fileprivate let menuItems: (ThemeSource)->[ContextMenuItem]
    fileprivate let selected: ThemeSource
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, theme: TelegramPresentationTheme, selected: ThemeSource, local:[LocalPaletteWithReference], cloudThemes:[TelegramTheme], viewType: GeneralViewType, togglePalette: @escaping(InstallThemeSource)->Void, menuItems: @escaping(ThemeSource)->[ContextMenuItem]) {
        self.context = context
        self.theme = theme
        self.local = local
        self.selected = selected
        self.cloudThemes = cloudThemes
        self.togglePalette = togglePalette
        self.menuItems = menuItems
        super.init(initialSize, height: 74 + viewType.innerInset.top + viewType.innerInset.bottom, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return ThemeListRowView.self
    }
}


private final class ThemeListRowView : GeneralContainableRowView {
    private let tableView = HorizontalTableView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(self.tableView)
    }
    
    
   
    override var backdorColor: NSColor {
        guard let item = item as? ThemeListRowItem else {
            return theme.colors.background
        }
        return item.theme.colors.background
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? ThemeListRowItem else {
            return
        }
        
        let innerInset = item.viewType.innerInset
        
        self.tableView.frame = NSMakeRect(0, innerInset.top, self.containerView.frame.width, self.containerView.frame.height - innerInset.bottom - innerInset.top)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        
        let previous: ThemeListRowItem? = self.item as? ThemeListRowItem
        super.set(item: item, animated: animated)
        
        guard let item = item as? ThemeListRowItem else {
            return
        }
        
        self.tableView.getBackgroundColor = {
            item.theme.colors.background
        }
                
        self.layout()
        
        if previous?.cloudThemes == item.cloudThemes && previous?.theme == item.theme && item.selected == previous?.selected {
            return
        }
        
        let reloadAnimated = animated && previous?.cloudThemes.count != item.cloudThemes.count

        tableView.beginTableUpdates()
        tableView.removeAll(animation: reloadAnimated ? .effectFade : .none)
        _ = tableView.addItem(item: HorizontalThemeFirstItem(tableView.frame.size), animation: reloadAnimated ? .effectFade : .none)
        
        let localPalettes:[LocalPaletteWithReference] = item.local
        var scrollItem:HorizontalThemeItem? = nil
        for palette in localPalettes {
            let selected: Bool
            switch item.selected {
            case let .local(local, _):
                selected = local.parent == palette.palette.parent
            default:
                selected = false
            }
            let item = HorizontalThemeItem(tableView.frame.size, stableId: palette.palette.name, context: item.context, theme: item.theme, themeType: .local(palette.palette, palette.cloud), selected: selected, togglePalette: item.togglePalette, menuItems: item.menuItems)
            _ = tableView.addItem(item: item)
            if item.selected && scrollItem == nil {
                scrollItem = item
            }
        }
        
        for cloud in item.cloudThemes {
            let selected: Bool
            switch item.selected {
            case let .cloud(theme):
                selected = theme.id == cloud.id
            default:
                selected = false
            }
            let item = HorizontalThemeItem(tableView.frame.size, stableId: cloud.id, context: item.context, theme: item.theme, themeType: .cloud(cloud), selected: selected, togglePalette: item.togglePalette, menuItems: item.menuItems)
            _ = tableView.addItem(item: item, animation: reloadAnimated ? .effectFade : .none)
            if item.selected && scrollItem == nil {
                scrollItem = item
            }
        }
        
        _ = tableView.addItem(item: HorizontalThemeFirstItem(tableView.frame.size), animation: reloadAnimated ? .effectFade : .none)
        _ = tableView.addItem(item: HorizontalThemeFirstItem(tableView.frame.size), animation: reloadAnimated ? .effectFade : .none)
        tableView.endTableUpdates()
        
        if let item = scrollItem {
            self.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: reloadAnimated, focus: .init(focus: false), inset: 0), true)
        }
    }
}
