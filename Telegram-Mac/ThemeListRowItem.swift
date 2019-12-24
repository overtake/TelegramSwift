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
import SyncCore
import Postbox
import SwiftSignalKit


private final class HorizontalThemeFirstItem : GeneralRowItem {
    override var width: CGFloat {
        return 10
    }
    override var height: CGFloat {
        return 10
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

private let cache:NSCache<NSString, ThemeCachedItem> = NSCache()

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
        case let .local(palette):
            attr = .initialize(string: localizedString("AppearanceSettings.ColorTheme.\(palette.name)"), color: selected ? theme.colors.accent : theme.colors.text, font: selected ? .medium(12) : .normal(12))
        case let .cloud(cloud):
            attr = .initialize(string: cloud.title, color: selected ? theme.colors.accent : theme.colors.text, font: selected ? .medium(12) : .normal(12))
        }
        self.titleLayout = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end, alignment: .center, alwaysStaticItems: true)
        self.titleLayout.measure(width: 80)
        super.init(initialSize, height: 100, stableId: stableId)
    }
    
    
    override func viewClass() -> AnyClass {
        return HorizontalThemeView.self
    }
    
    override var width: CGFloat {
        return 100
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
        
        var cachedData: InstallThemeSource? = cache.object(forKey: PhotoCacheKeyEntry.theme(item.themeType, item.theme.bubbled).stringValue)?.source
        
        overlay.set(handler: { [weak item] _ in
            if let cachedData = cachedData {
                item?.togglePalette(cachedData)
            }
        }, for: .Click)
        
        overlay.set(handler: { [weak item] control in
            if let item = item, let event = NSApp.currentEvent {
                ContextMenu.show(items: item.menuItems(item.themeType), view: control, event: event)
            }
        }, for: .RightDown)
        
        progressIndicator.progressColor = item.theme.colors.grayIcon
        
        let signal = themeAppearanceThumbAndData(context: item.context, bubbled: item.theme.bubbled, source: item.themeType) |> deliverOnMainQueue
        
        self.imageView.setSignal(signal: cachedThemeThumb(source: item.themeType, bubbled: item.theme.bubbled), clearInstantly: true)

        
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
            let source: ThemeSource
            switch data {
            case let .local(palette):
                source = .local(palette)
            case let .cloud(cloud, _):
                source = .cloud(cloud)
            }
            self?.progressIndicator.isHidden = true
            cacheThemeThumb(image, source: source, bubbled: item.theme.bubbled)
            cache.setObject(ThemeCachedItem(source: data), forKey: PhotoCacheKeyEntry.theme(source, item.theme.bubbled).stringValue)
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
    fileprivate let local:[ColorPalette]
    fileprivate let togglePalette: (InstallThemeSource)->Void
    fileprivate let menuItems: (ThemeSource)->[ContextMenuItem]
    fileprivate let selected: ThemeSource
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, theme: TelegramPresentationTheme, selected: ThemeSource, local:[ColorPalette], cloudThemes:[TelegramTheme], viewType: GeneralViewType, togglePalette: @escaping(InstallThemeSource)->Void, menuItems: @escaping(ThemeSource)->[ContextMenuItem]) {
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


private final class ThemeListRowView : TableRowView {
    private var containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let borderView: View = View()
    private let tableView = HorizontalTableView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.containerView.addSubview(self.tableView)
        self.containerView.addSubview(self.borderView)
        
        
        self.addSubview(containerView)
    }
    
    
    override func updateColors() {
        guard let item = item as? ThemeListRowItem else {
            return
        }
        self.containerView.backgroundColor = item.theme.colors.background
        self.borderView.backgroundColor = item.theme.colors.border
        self.backgroundColor = item.viewType.rowBackground
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
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        self.borderView.frame = NSMakeRect(innerInset.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInset.left - innerInset.right, .borderSize)
        
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
        
        borderView.isHidden = !item.viewType.hasBorder
        
        self.layout()
        
        if previous?.cloudThemes == item.cloudThemes && previous?.theme == item.theme && item.selected == previous?.selected {
            return
        }
        
        let reloadAnimated = animated && previous?.cloudThemes.count != item.cloudThemes.count

        tableView.beginTableUpdates()
        tableView.removeAll(animation: reloadAnimated ? .effectFade : .none)
        _ = tableView.addItem(item: HorizontalThemeFirstItem(tableView.frame.size), animation: reloadAnimated ? .effectFade : .none)
        
        let localPalettes:[ColorPalette] = item.local
        var scrollItem:HorizontalThemeItem? = nil
        for palette in localPalettes {
            let selected: Bool
            switch item.selected {
            case let .local(local):
                selected = local.parent == palette.parent
            default:
                selected = false
            }
            let item = HorizontalThemeItem(tableView.frame.size, stableId: palette.name, context: item.context, theme: item.theme, themeType: .local(palette), selected: selected, togglePalette: item.togglePalette, menuItems: item.menuItems)
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
        tableView.endTableUpdates()
        
        if let item = scrollItem {
            self.tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: reloadAnimated, focus: .init(focus: false), inset: 0), true)
        }
    }
}
