//
//  FolderIcons.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/04/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa


enum FolderIconState {
    case sidebar
    case sidebarActive
    case preview
    case settings
    var color: NSColor {
        switch self {
        case .sidebar:
            return NSColor.white.withAlphaComponent(0.5)
        case .sidebarActive:
            return .white
        case .preview:
            return theme.colors.grayIcon
        case .settings:
            return theme.colors.grayIcon
        }
    }
}

let allSidebarFolderIcons: [FolderIcon] = [FolderIcon(emoticon: .emoji("🐱")),
                                           FolderIcon(emoticon: .emoji("📕")),
                                           FolderIcon(emoticon: .emoji("💰")),
                                           FolderIcon(emoticon: .emoji("📸")),
                                           FolderIcon(emoticon: .emoji("🎮")),
                                           FolderIcon(emoticon: .emoji("🏡")),
                                           FolderIcon(emoticon: .emoji("💡")),
                                           FolderIcon(emoticon: .emoji("👍")),
                                           FolderIcon(emoticon: .emoji("🔒")),
                                           FolderIcon(emoticon: .emoji("❤️")),
                                           FolderIcon(emoticon: .emoji("➕")),
                                           FolderIcon(emoticon: .emoji("🎵")),
                                           FolderIcon(emoticon: .emoji("🎨")),
                                           FolderIcon(emoticon: .emoji("✈️")),
                                           FolderIcon(emoticon: .emoji("⚽️")),
                                           FolderIcon(emoticon: .emoji("⭐")),
                                           FolderIcon(emoticon: .emoji("🎓")),
                                           FolderIcon(emoticon: .emoji("🛫")),
                                           FolderIcon(emoticon: .emoji("🦠")),
                                           FolderIcon(emoticon: .emoji("👨‍💼")),
                                           FolderIcon(emoticon: .emoji("👤")),
                                           FolderIcon(emoticon: .emoji("👥")),
                                           FolderIcon(emoticon: .emoji("📢")),
                                           FolderIcon(emoticon: .emoji("💬")),
                                           FolderIcon(emoticon: .emoji("✅")),
                                           FolderIcon(emoticon: .emoji("☑️")),
                                           FolderIcon(emoticon: .emoji("🤖")),
                                           FolderIcon(emoticon: .emoji("🗂"))]



enum FolderEmoticon {
    case emoji(String)
    case allChats
    case groups
    case read
    case personal
    case unmuted
    case unread
    case channels
    case bots
    case folder
    
    var emoji: String? {
        switch self {
        case let .emoji(emoji):
            return emoji
        case .allChats: return "💬"
        case .personal: return "👤"
        case .groups: return "👥"
        case .read: return "✅"
        case .unmuted: return "🔔"
        case .unread: return "☑️"
        case .channels: return "📢"
        case .bots: return "🤖"
        case .folder: return "🗂"
        }
    }
    
    var iconName: String {
        switch self {
        case .allChats:
            return "Icon_Sidebar_AllChats"
        case .groups:
            return "Icon_Sidebar_Group"
        case .read:
            return "Icon_Sidebar_Read"
        case .unread:
            return "Icon_Sidebar_Unread"
        case .personal:
            return "Icon_Sidebar_Personal"
        case .unmuted:
            return "Icon_Sidebar_Unmuted"
        case .channels:
            return "Icon_Sidebar_Channel"
        case .bots:
            return "Icon_Sidebar_Bot"
        case .folder:
            return "Icon_Sidebar_Folder"
        case let .emoji(emoji):
            switch emoji {
            case "👤":
                return "Icon_Sidebar_Personal"
            case "👥":
                return "Icon_Sidebar_Group"
            case "📢":
                return "Icon_Sidebar_Channel"
            case "💬":
                return "Icon_Sidebar_AllChats"
            case "✅":
                return "Icon_Sidebar_Read"
            case "☑️":
                return "Icon_Sidebar_Unread"
            case "🔔":
                return "Icon_Sidebar_Unmuted"
            case "🗂":
                return "Icon_Sidebar_Folder"
            case "🤖":
                return "Icon_Sidebar_Bot"
            case "🐶", "🐱":
                return "Icon_Sidebar_Animal"
            case "📕":
                return "Icon_Sidebar_Book"
            case "💰":
                return "Icon_Sidebar_Coin"
            case "📸":
                return "Icon_Sidebar_Flash"
            case "🎮":
                return "Icon_Sidebar_Game"
            case "🏡":
                return "Icon_Sidebar_Home"
            case "💡":
                return "Icon_Sidebar_Lamp"
            case "👍":
                return "Icon_Sidebar_Like"
            case "🔒":
                return "Icon_Sidebar_Lock"
            case "❤️":
                return "Icon_Sidebar_Love"
            case "➕":
                return "Icon_Sidebar_Math"
            case "🎵":
                return "Icon_Sidebar_Music"
            case "🎨":
                return "Icon_Sidebar_Paint"
            case "✈️":
                return "Icon_Sidebar_Plane"
            case "⚽️":
                return "Icon_Sidebar_Sport"
            case "⭐":
                return "Icon_Sidebar_Star"
            case "🎓":
                return "Icon_Sidebar_Student"
            case "🛫":
                return "Icon_Sidebar_Telegram"
            case "🦠":
                return "Icon_Sidebar_Virus"
            case "👨‍💼":
                return "Icon_Sidebar_Work"
            default:
                return "Icon_Sidebar_Folder"
            }
        }
    }
}

final class FolderIcon {
    let emoticon: FolderEmoticon
    
    init(emoticon: FolderEmoticon) {
        self.emoticon = emoticon
    }
    
    func icon(for state: FolderIconState) -> CGImage {
        return NSImage(named: self.emoticon.iconName)!.precomposed(state.color, flipVertical: state == .preview)
    }
    
}


