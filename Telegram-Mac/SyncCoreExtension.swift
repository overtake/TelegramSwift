//
//  SyncCoreExtension.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.11.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import TGUIKit
import Postbox

extension PixelDimensions {
    var size: CGSize {
        return CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }
    init(_ size: CGSize) {
        self.init(width: Int32(abs(size.width)), height: Int32(abs(size.height)))
    }
    init(_ width: Int32, _ height: Int32) {
        self.init(width: width, height: height)
    }
}
extension CGSize {
    var pixel: PixelDimensions {
        return PixelDimensions(self)
    }
}

enum AppLogEvents : String {
    case imageEditor = "image_editor_used"
}


extension Peer {
    var isUser:Bool {
        return self is TelegramUser
    }
    var isSecretChat:Bool {
        return self is TelegramSecretChat
    }
    var isGroup:Bool {
        return self is TelegramGroup
    }
    var canManageDestructTimer: Bool {
        if self is TelegramSecretChat {
            return true
        }
        if self.isUser && !self.isBot {
            return true
        }
        if self.isMonoForum {
            return false
        }
        
        if let peer = self as? TelegramChannel {
            if let adminRights = peer.adminRights, adminRights.rights.contains(.canDeleteMessages) {
                return true
            } else if peer.groupAccess.isCreator {
                return true
            }
            return false
        }
        if let peer = self as? TelegramGroup {
            return true
        }
        return false
    }
    
    var storyArchived: Bool {
        if let user = self as? TelegramUser {
            return user.storiesHidden ?? false
        }
        if let user = self as? TelegramChannel {
            return user.storiesHidden ?? false
        }
        return false
    }

    var canClearHistory: Bool {
        if self.isGroup || self.isUser || (self.isSupergroup && self.addressName == nil) {
            if let peer = self as? TelegramChannel, peer.flags.contains(.hasGeo) {} else {
                return true
            }
        }
        if self is TelegramSecretChat {
            return true
        }
        return false
    }
    
    var restrictionInfo: PeerAccessRestrictionInfo? {
        if let peer = self as? TelegramChannel {
            return peer.restrictionInfo
        } else if let peer = self as? TelegramUser {
            return peer.restrictionInfo
        } else {
            return nil
        }
    }
    
    func isRestrictedChannel(_ contentSettings: ContentSettings) -> Bool {
        if let restrictionInfo = self.restrictionInfo {
            for rule in restrictionInfo.rules {
                #if APP_STORE || STABLE || BETA
                if rule.platform == "ios" || rule.platform == "all", rule.reason != "sensitive" {
                    return !contentSettings.ignoreContentRestrictionReasons.contains(rule.reason)
                }
                #endif
            }
        }
        return false
    }
    
    
    func restrictionText(_ contentSettings: ContentSettings?) -> String? {
        if let restrictionInfo = self.restrictionInfo, self.isRestrictedChannel(contentSettings ?? .default) {
            for rule in restrictionInfo.rules {
                if rule.platform == "ios" || rule.platform == "all", rule.reason != "sensitive" {
                    if let contentSettings {
                        if !contentSettings.ignoreContentRestrictionReasons.contains(rule.reason) {
                            return rule.text
                        }
                    } else {
                        return rule.text
                    }
                }
            }
        }
        return nil
    }
    
    var botInfo: BotUserInfo? {
        if let peer = self as? TelegramUser {
            return peer.botInfo
        }
        return nil
    }
    
    var isSupergroup:Bool {
        if let peer = self as? TelegramChannel {
            switch peer.info {
            case .group:
                return true
            default:
                return false
            }
        }
        return false
    }
    var isBot:Bool {
        if let user = self as? TelegramUser {
            return user.botInfo != nil
        }
        return false
    }

    var canCall:Bool {
        return isUser && !isBot && ((self as! TelegramUser).phone != "42777") && ((self as! TelegramUser).phone != "42470") && ((self as! TelegramUser).phone != "4240004")
    }
    var isChannel:Bool {
        if let peer = self as? TelegramChannel {
            switch peer.info {
            case .broadcast:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    var isAdmin: Bool {
        if let peer = self as? TelegramChannel {
            return peer.adminRights != nil || peer.flags.contains(.isCreator)
        }
        return false
    }
    
    var isOwner: Bool {
        if let peer = self as? TelegramChannel {
            return peer.flags.contains(.isCreator)
        }
        return false
    }
    
    var isGigagroup:Bool {
        if let peer = self as? TelegramChannel {
            return peer.flags.contains(.isGigagroup)
        }
        return false
    }
}

