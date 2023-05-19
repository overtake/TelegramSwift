//
//  GroupCallVolumeMenuItem.swift
//  Telegram
//
//  Created by Mike Renoir on 27.01.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation

import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit



final class GroupCallVolumeMenuItem : ContextMenuItem {
    private let didUpdateValue:((CGFloat, Bool)->Void)?
    private let volume: CGFloat
    init(volume: CGFloat, _ didUpdateValue:((CGFloat, Bool)->Void)? = nil) {
        self.volume = volume
        self.didUpdateValue = didUpdateValue
        super.init("")
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return GroupCallVolumeMenuRowItem(.zero, presentation: presentation, interaction: interaction, menuItem: self, volume: volume, didUpdateValue: self.didUpdateValue)
    }
}


private final class GroupCallVolumeMenuRowItem : AppMenuBasicItem {
    fileprivate let didUpdateValue:((CGFloat, Bool)->Void)?
    fileprivate let volume: CGFloat
    init(_ initialSize: NSSize, presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction, menuItem: ContextMenuItem, volume: CGFloat, didUpdateValue:((CGFloat, Bool)->Void)?) {
        self.didUpdateValue = didUpdateValue
        self.volume = volume
        super.init(initialSize, presentation: presentation, menuItem: menuItem, interaction: interaction)
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallVolumeMenuRowView.self
    }
    
    override var effectiveSize: NSSize {
        return NSMakeSize(200, super.effectiveSize.height)
    }
    
    override var height: CGFloat {
        return 28
    }
}


private final class GroupCallVolumeMenuRowView : AppMenuBasicItemView {
    let volumeControl = VolumeMenuItemView(frame: NSMakeRect(0, 0, 200, 26))
    private var drawable_muted: AppMenuAnimatedImage?
    private var drawable: AppMenuAnimatedImage?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(volumeControl)
       

        containerView.set(handler: { [weak self] _ in
            self?.drawable?.updateState(.Hover)
        }, for: .Hover)
        containerView.set(handler: { [weak self] _ in
            self?.drawable?.updateState(.Highlight)
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.drawable?.updateState(.Normal)
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.drawable?.updateState(.Other)
        }, for: .Other)
           
    }
    
    deinit {
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        let x: CGFloat = 11 + 18
        volumeControl.setFrameSize(contentSize.width - x - 2, 26)
        volumeControl.centerY(x: x)
        self.drawable?.centerY(x: 11)
        self.drawable_muted?.centerY(x: 11)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallVolumeMenuRowItem else {
            return
        }
        
        volumeControl.value = item.volume
        volumeControl.lineColor = item.presentation.borderColor

        volumeControl.didUpdateValue = { [weak item, weak self] value, sync in
            item?.didUpdateValue?(value, sync)
            self?.updateValue(value)
        }
        
        if self.drawable == nil, let menuItem = item.menuItem {
            self.drawable = AppMenuAnimatedImage(LocalAnimatedSticker.menu_speaker, NSColor(0xffffff), menuItem)
            self.drawable?.setFrameSize(NSMakeSize(18, 18))
            self.addSubview(self.drawable!)
        }
        if self.drawable_muted == nil, let menuItem = item.menuItem {
            self.drawable_muted = AppMenuAnimatedImage(LocalAnimatedSticker.menu_speaker_muted, NSColor(0xffffff), menuItem)
            self.drawable_muted?.setFrameSize(NSMakeSize(18, 18))
            self.addSubview(self.drawable_muted!)
        }
        self.drawable?.change(opacity: item.volume > 0 ? 1 : 0, animated: animated)
        self.drawable_muted?.change(opacity: item.volume > 0 ? 0 : 1, animated: animated)

        needsLayout = true
    }
    
    private func updateValue(_ value: CGFloat) {
        self.drawable?.change(opacity: value > 0 ? 1 : 0)
        self.drawable_muted?.change(opacity: value > 0 ? 0 : 1)
    }
}
