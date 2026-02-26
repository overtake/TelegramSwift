//
//  BoostFeatureRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 15.12.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

enum BoostChannelPerk: Equatable {
    case story(Int32)
    case reaction(Int32)
    case nameColor(Int32)
    case profileColor(Int32)
    case profileIcon
    case linkColor(Int32)
    case linkIcon
    case emojiStatus
    case wallpaper(Int32)
    case customWallpaper
    case audioTranscription
    case emojiPack
    case noAds
    case autotranslation
    func title(isGroup: Bool) -> String {
        switch self {
        case let .story(value):
            return strings().channelBoostTableStoriesPerDayCountable(Int(value))
        case let .reaction(value):
            return strings().channelBoostTableCustomReactionsCountable(Int(value))
        case let .nameColor(value):
            return strings().channelBoostTableNameColorCountable(Int(value))
        case let .profileColor(value):
            if isGroup {
                return strings().channelBoostTableProfileColorGroupCountable(Int(value))
            } else {
                return strings().channelBoostTableProfileColorCountable(Int(value))
            }
        case .profileIcon:
            if isGroup {
                return strings().channelBoostTableProfileLogoGroup
            } else {
                return strings().channelBoostTableProfileLogo
            }
        case let .linkColor(value):
            return strings().channelBoostTableStyleForHeadersCountable(Int(value))
        case .linkIcon:
            return strings().channelBoostTableHeadersLogo
        case .emojiStatus:
            return strings().channelBoostTableEmojiStatus
        case let .wallpaper(value):
            if isGroup {
                return strings().channelBoostTableWallpaperGroupCountable(Int(value))
            } else {
                return strings().channelBoostTableWallpaperCountable(Int(value))
            }
        case .customWallpaper:
            if isGroup {
                return strings().channelBoostTableCustomWallpaperGroup
            } else {
                return strings().channelBoostTableCustomWallpaper
            }
        case .audioTranscription:
            return strings().channelBoostTableAudioTranscription
        case .emojiPack:
            return strings().channelBoostTableEmojiPack
        case .noAds:
            return strings().channelBoostTableNoAds
        case .autotranslation:
            return strings().channelBoostAutotranslation

        }
    }
    
    var image: CGImage {
        
        switch self {
        case .story:
            return theme.icons.channel_feature_stories
        case .reaction:
            return theme.icons.channel_feature_reaction
        case .nameColor:
            return theme.icons.channel_feature_name_color
        case .profileColor:
            return theme.icons.channel_feature_cover_color
        case .profileIcon:
            return theme.icons.channel_feature_cover_icon
        case .linkColor:
            return theme.icons.channel_feature_link_color
        case .linkIcon:
            return theme.icons.channel_feature_link_icon
        case .emojiStatus:
            return theme.icons.channel_feature_status
        case .wallpaper:
            return theme.icons.channel_feature_background
        case .customWallpaper:
            return theme.icons.channel_feature_background_photo
        case .audioTranscription:
            return theme.icons.channel_feature_voice_to_text
        case .emojiPack:
            return theme.icons.channel_feature_emoji_pack
        case .noAds:
            return theme.icons.channel_feature_no_ads
        case .autotranslation:
            return theme.icons.channel_feature_autotranslate
        }
    }
}


final class BoostFeatureRowItem : GeneralRowItem {
    let perk: BoostChannelPerk
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, isGroup: Bool, perk: BoostChannelPerk) {
        self.perk = perk
        self.textLayout = .init(.initialize(string: perk.title(isGroup: isGroup), color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        self.textLayout.measure(width: width - 60)
        return true
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return BoostFeatureRowView.self
    }
}

private final class BoostFeatureRowView: GeneralRowView {
    private let imageView = ImageView()
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? BoostFeatureRowItem else {
            return
        }
        textView.update(item.textLayout)
        imageView.image = item.perk.image
        imageView.sizeToFit()
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        imageView.centerY(x: 20)
        textView.centerY(x: imageView.frame.maxX + 20)
    }
}


final class BoostPerkLevelHeaderItem : GeneralRowItem {
    fileprivate let level: Int32
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, level: Int32) {
        self.level = level
        self.textLayout = .init(.initialize(string: strings().channelBoostTableLevelUnlocksCountable(Int(level)), color: .white, font: .medium(.text)), alwaysStaticItems: true)
        super.init(initialSize, stableId: stableId)
        self.textLayout.measure(width: .greatestFiniteMagnitude)
    }
    
    override var height: CGFloat {
        return 50
    }
    override func viewClass() -> AnyClass {
        return BoostPerkLevelHeaderView.self
    }
}

private final class BoostPerkLevelHeaderView: GeneralRowView {
    private let container = View()
    private let textView = TextView()
    private let gradient = SimpleGradientLayer()
    private let left = View()
    private let right = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        container.addSubview(textView)
        addSubview(left)
        addSubview(right)
        
        container.layer?.addSublayer(gradient)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        container.center()
        textView.center()
        gradient.frame = container.bounds
        
        let b_width = (frame.width - container.frame.width - 80) / 2
        let b_y = floorToScreenPixels((frame.height - .borderSize) / 2)
        left.frame = NSMakeRect(20, b_y, b_width, .borderSize)
        right.frame = NSMakeRect(frame.width - b_width - 20, b_y, b_width, .borderSize)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? BoostPerkLevelHeaderItem else {
            return
        }
        
        left.backgroundColor = theme.colors.listGrayText.withAlphaComponent(0.25)
        right.backgroundColor = theme.colors.listGrayText.withAlphaComponent(0.25)

        textView.update(item.textLayout)
        
        gradient.colors = [NSColor(rgb: 0x9076ff), NSColor(rgb: 0xbc6de8)].map { $0.cgColor }
        self.gradient.startPoint = CGPoint(x: 0, y: 0.5)
        self.gradient.endPoint = CGPoint(x: 1.0, y: 1)
        

        
        let size = NSMakeSize(item.textLayout.layoutSize.width + 24, item.textLayout.layoutSize.height + 16)
        container.setFrameSize(size)
        container.layer?.cornerRadius = size.height / 2
    }
}
