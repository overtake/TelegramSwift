//
//  BoostFeatureRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 15.12.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation



enum BoostFeatureType {
    case background
    case backgroundPhoto
    case coverColor
    case linkColor
    case linkIcon
    case nameColor
    case reaction
    case status
    case stories
    
  
    var image: CGImage {
        switch self {
        case .background:
            return theme.icons.channel_feature_background
        case .backgroundPhoto:
            return theme.icons.channel_feature_background_photo
        case .coverColor:
            return theme.icons.channel_feature_cover_color
        case .linkColor:
            return theme.icons.channel_feature_link_color
        case .linkIcon:
            return theme.icons.channel_feature_link_icon
        case .nameColor:
            return theme.icons.channel_feature_name_color
        case .reaction:
            return theme.icons.channel_feature_reaction
        case .status:
            return theme.icons.channel_feature_status
        case .stories:
            return theme.icons.channel_feature_stories
        }
    }
    
    func text(level: Int32) -> String {
        switch self {
        case .background:
            return "8 Channel Backgrounds"
        case .backgroundPhoto:
            return "8 Channel Backgrounds"
        case .coverColor:
            return "16 Colors for Channel Cover"
        case .linkColor:
            return "24 Styles for Links and Quotes"
        case .linkIcon:
            return "Custom Logo for Links and Quotes"
        case .nameColor:
            return "8 Channel Name Colors"
        case .reaction:
            return "9 Custom Reactions"
        case .status:
            return "1000+ Emoji Statuses"
        case .stories:
            return "\(level) Story Per Day"
        }
    }
}

final class BoostFeatureRowItem : GeneralRowItem {
    let boostType: BoostFeatureType
    init(_ initialSize: NSSize, stableId: AnyHashable, type: BoostFeatureType) {
        self.boostType = type
        super.init(initialSize, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return BoostFeatureRowView.self
    }
}

private final class BoostFeatureRowView: GeneralRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
