//
//  PremiumBoardingController.swift
//  Telegram
//
//  Created by Mike Renoir on 10.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InAppPurchaseManager
import CurrencyFormat
import TelegramMediaPlayer

struct PremiumEmojiStatusInfo : Equatable {
    let status: PeerEmojiStatus
    let file: TelegramMediaFile
    let info: StickerPackCollectionInfo?
    let items: [StickerPackItem]
}

enum PremiumLogEventsSource : Equatable {
    
    enum Subsource : String {
        case channels
        case channels_public
        case saved_gifs
        case stickers_faved
        case dialog_filters
        case dialog_filters_chats
        case dialog_filters_pinned
        case dialog_pinned
        case topics_pin
        case caption_length
        case upload_max_fileparts
        case dialogs_folder_pinned
        case accounts
        case about
        case community_invites
        case communities_joined
    }
    
    case deeplink(String?)
    case settings
    case double_limits(Subsource)
    case more_upload
    case infinite_reactions
    case premium_stickers
    case premium_emoji
    case profile(PeerId)
    case gift(from: PeerId, to: PeerId, months: Int32, slug: String?, unclaimed: Bool)
    case story_viewers
    case stories_quality
    case send_as
    case translations
    case stories__stealth_mode
    case stories__save_to_gallery
    case channel_boost(PeerId)
    case no_ads
    case recommended_channels
    case last_seen
    case message_privacy
    case saved_tags
    case business
    case business_intro
    case business_standalone
    case folder_tags
    case upload_limit
    case grace_period
    case emoji_status
    case todo
    case limitedGift(StarGift.Gift)
    var value: String {
        switch self {
        case let .deeplink(ref):
            if let ref = ref {
                return "deeplink_" + ref
            } else {
                return "deeplink"
            }
        case .settings:
            return "settings"
        case let .double_limits(sub):
            return "double_limits__\(sub.rawValue)"
        case .more_upload:
            return "more_upload"
        case .infinite_reactions:
            return "infinite_reactions"
        case .premium_stickers:
            return "premium_stickers"
        case .premium_emoji:
            return "premium_emoji"
        case let .profile(peerId):
            return "profile__\(peerId.id._internalGetInt64Value())"
        case .gift:
            return "gift"
        case .send_as:
            return "send_as"
        case .translations:
            return "translations"
        case .stories__stealth_mode:
            return "stories__stealth_mode"
        case .story_viewers:
            return "stories__viewers"
        case .stories_quality:
            return "stories__quality"
        case .stories__save_to_gallery:
            return "stories__save_to_gallery"
        case let .channel_boost(peerId):
            return "channel_boost__\(peerId.id._internalGetInt64Value())"
        case .no_ads:
            return "no_ads"
        case .recommended_channels:
            return "recommended_channels"
        case .last_seen:
            return "last_seen"
        case .message_privacy:
            return "message_privacy"
        case .saved_tags:
            return "saved_tags"
        case .business:
            return "business"
        case .business_standalone:
            return "business_standalone"
        case .folder_tags:
            return "folder_tags"
        case .upload_limit:
            return "upload_limit"
        case .business_intro:
            return "business_intro"
        case .grace_period:
            return "grace_period"
        case .emoji_status:
            return "emoji_status"
        case .todo:
            return "todo"
        case .limitedGift:
            return "limited_gift"
        }
    }
    
    var features: PremiumValue? {
        switch self {
        case .deeplink:
            return nil
        case .settings:
            return nil
        case .double_limits:
            return .double_limits
        case .more_upload:
            return .more_upload
        case .infinite_reactions:
            return .infinite_reactions
        case .premium_stickers:
            return .premium_stickers
        case .premium_emoji:
            return .animated_emoji
        case .profile:
            return nil
        case .gift:
            return nil
        case .send_as:
            return nil
        case .translations:
            return .translations
        case .stories__stealth_mode:
            return .stories
        case .story_viewers:
            return .stories
        case .stories_quality:
            return .stories
        case .stories__save_to_gallery:
            return .stories
        case .channel_boost:
            return nil
        case .no_ads:
            return .no_ads
        case .recommended_channels:
            return nil
        case .saved_tags:
            return .saved_tags
        case .last_seen:
            return .last_seen
        case .message_privacy:
            return .message_privacy
        case .business:
            return nil
        case .business_intro:
            return .business_intro
        case .business_standalone:
            return nil
        case .folder_tags:
            return .folder_tags
        case .upload_limit:
            return nil
        case .grace_period:
            return nil
        case .emoji_status:
            return .emoji_status
        case .todo:
            return .todo
        case .limitedGift:
            return nil
        }
    }
    
    var subsource: String? {
        switch self {
        case let .double_limits(sub):
            return sub.rawValue
        default:
            return nil
        }
    }
    
}

enum PremiumLogEvents  {
    case promo_screen_show(PremiumLogEventsSource)
    case promo_screen_tap(PremiumValue)
    case promo_screen_accept
    case promo_screen_fail
    
    var value: String {
        switch self {
        case .promo_screen_show:
            return "promo_screen_show"
        case .promo_screen_tap:
            return "promo_screen_tap"
        case .promo_screen_accept:
            return "promo_screen_accept"
        case .promo_screen_fail:
            return "promo_screen_fail"
        }
    }
    
    
    func send(context: AccountContext) {

        let type = "premium.\(self.value)"
        switch self {
        case let .promo_screen_show(source):
            addAppLogEvent(postbox: context.account.postbox, time: Date().timeIntervalSince1970, type: type, peerId: context.peerId, data: [
                "premium_promo_order": context.premiumOrder.premiumValues.map { $0.rawValue },
                "source":source.value
            ])
        case let .promo_screen_tap(value):
            addAppLogEvent(postbox: context.account.postbox, time: Date().timeIntervalSince1970, type: type, peerId: context.peerId, data: [
                "item":value.rawValue
            ])
        case .promo_screen_fail, .promo_screen_accept:
            addAppLogEvent(postbox: context.account.postbox, time: Date().timeIntervalSince1970, type: type, peerId: context.peerId, data: [:])
        }

    }
}



private final class Arguments {
    let context: AccountContext
    let presentation: TelegramPresentationTheme
    let showTerms:()->Void
    let showPrivacy:()->Void
    let openInfo:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void
    let openFeature:(PremiumValue, Bool)->Void
    let togglePeriod:(PremiumPeriod)->Void
    let execute:(String)->Void
    let copyLink:(String)->Void
    let toggleAds:(Bool)->Void
    init(context: AccountContext, presentation: TelegramPresentationTheme, showTerms: @escaping()->Void, showPrivacy:@escaping()->Void, openInfo:@escaping(PeerId, Bool, MessageId?, ChatInitialAction?)->Void, openFeature:@escaping(PremiumValue, Bool)->Void, togglePeriod:@escaping(PremiumPeriod)->Void, execute:@escaping(String)->Void, copyLink:@escaping(String)->Void, toggleAds:@escaping(Bool)->Void) {
        self.context = context
        self.presentation = presentation
        self.showPrivacy = showPrivacy
        self.showTerms = showTerms
        self.openInfo = openInfo
        self.openFeature = openFeature
        self.togglePeriod = togglePeriod
        self.execute = execute
        self.copyLink = copyLink
        self.toggleAds = toggleAds
    }
}

enum PremiumValue : String {
    case double_limits
    case more_upload
    case faster_download
    case voice_to_text
    case no_ads
    case infinite_reactions
    case emoji_status
    case premium_stickers
    case animated_emoji
    case advanced_chat_management
    case profile_badge
    case animated_userpics
    case translations
    case stories
    case wallpapers
    case peer_colors
    case saved_tags
    case last_seen
    case message_privacy
    case todo
    
    case business
    
    case business_location
    case business_hours
    case quick_replies
    case greeting_message
    case away_message
    case business_bots
    case business_intro
    case business_links
    case folder_tags
    
    var isBusiness: Bool {
        switch self {
        case .business_location, .business_hours, .quick_replies, .greeting_message, .away_message, .business_bots, .business_intro, .business_links:
            return true
        default:
            return false
        }
    }
    
    func gradient(_ index: Int) -> [NSColor] {
        let colors:[NSColor] = [ NSColor(rgb: 0xef6922),
                                 NSColor(rgb: 0xD6593E),
                                 NSColor(rgb: 0xe95a2c),
                                 NSColor(rgb: 0xe74e33),
                                 NSColor(rgb: 0xe54837),
                                 NSColor(rgb: 0xe3433c),
                                 NSColor(rgb: 0xdb374b),
                                 NSColor(rgb: 0xcb3e6d),
                                 NSColor(rgb: 0xbc4395),
                                 NSColor(rgb: 0xab4ac4),
                                 NSColor(rgb: 0x9b4fed),
                                 NSColor(rgb: 0x7861ff),
                                 NSColor(rgb: 0x8958ff),
                                 NSColor(rgb: 0x676bff),
                                 NSColor(rgb: 0x4e8aea),
                                 NSColor(rgb: 0x5b79ff),
                                 NSColor(rgb: 0x4492ff),
                                 NSColor(rgb: 0x429bd5),
                                 NSColor(rgb: 0x41a6a5),
                                 NSColor(rgb: 0x3eb26d),
                                 NSColor(rgb: 0x3dbd4a),
                                 NSColor(rgb: 0x51c736),
                                 NSColor(rgb: 0x5ed429)]
        return [colors[min(index, colors.count - 1)]]
    }
    
    func businessGradient(_ index: Int) -> [NSColor] {
        let colors = [
            NSColor(red: 0, green: 0.478, blue: 1, alpha: 1),
            NSColor(red: 0.675, green: 0.392, blue: 0.953, alpha: 1),
            NSColor(red: 0.937, green: 0.412, blue: 0.133, alpha: 1),
            NSColor(red: 0.914, green: 0.365, blue: 0.267, alpha: 1),
            NSColor(red: 0.949, green: 0.51, blue: 0.165, alpha: 1),
            NSColor(red: 0.906, green: 0.584, blue: 0.098, alpha: 1),
            NSColor(red: 0.404, green: 0.42, blue: 1, alpha: 1),
            NSColor(rgb: 0x5a78ff)
        ]
        return [colors[index]]
    }
    
    func icon(_ index: Int, business: Bool, presentation: TelegramPresentationTheme) -> CGImage {
        let image = self.image(presentation)
        let size = image.backingSize
        let img = generateImage(size, contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            ctx.clip(to: size.bounds, mask: image)
            
            let gradient: [NSColor] = business ? businessGradient(index) : gradient(index)
            
            let colors = gradient.compactMap { $0.cgColor } as NSArray

            if gradient.count == 1 {
                ctx.setFillColor(gradient[0].cgColor)
                ctx.fill(size.bounds)
            } else {
                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                
                var locations: [CGFloat] = []
                for i in 0 ..< colors.count {
                    locations.append(delta * CGFloat(i))
                }
                let colorSpace = deviceColorSpace
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
                
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
            }
        })!
        
        return generateImage(size, contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(size.bounds.insetBy(dx: 2, dy: 2))
            
            ctx.draw(img, in: size.bounds)
        })!
    }
    
    func image(_ presentation: TelegramPresentationTheme) -> CGImage {
        switch self {
        case .double_limits:
            return NSImage(resource: .iconPremiumBoardingX2).precomposed(presentation.colors.accent)
        case .more_upload:
            return NSImage(resource: .iconPremiumBoardingFiles).precomposed(presentation.colors.accent)
        case .faster_download:
            return NSImage(resource: .iconPremiumBoardingSpeed).precomposed(presentation.colors.accent)
        case .voice_to_text:
            return NSImage(resource: .iconPremiumBoardingVoice).precomposed(presentation.colors.accent)
        case .no_ads:
            return NSImage(resource: .iconPremiumBoardingAds).precomposed(presentation.colors.accent)
        case .infinite_reactions:
            return NSImage(resource: .iconPremiumBoardingReactions).precomposed(presentation.colors.accent)
        case .emoji_status:
            return NSImage(resource: .iconPremiumBoardingStatus).precomposed(presentation.colors.accent)
        case .premium_stickers:
            return NSImage(resource: .iconPremiumBoardingStickers).precomposed(presentation.colors.accent)
        case .animated_emoji:
            return NSImage(resource: .iconPremiumBoardingEmoji).precomposed(presentation.colors.accent)
        case .advanced_chat_management:
            return NSImage(resource: .iconPremiumBoardingChats).precomposed(presentation.colors.accent)
        case .profile_badge:
            return NSImage(resource: .iconPremiumBoardingBadge).precomposed(presentation.colors.accent)
        case .animated_userpics:
            return NSImage(resource: .iconPremiumBoardingProfile).precomposed(presentation.colors.accent)
        case .translations:
            return NSImage(resource: .iconPremiumBoardingTranslations).precomposed(presentation.colors.accent)
        case .stories:
            return NSImage(resource: .iconPremiumStories).precomposed(presentation.colors.accent)
        case .wallpapers:
            return NSImage(resource: .iconPremiumWallpapers).precomposed(presentation.colors.accent)
        case .peer_colors:
            return NSImage(resource: .iconPremiumPeerColors).precomposed(presentation.colors.accent)
        case .saved_tags:
            return NSImage(resource: .iconPremiumBoardingTag).precomposed(presentation.colors.accent)
        case .last_seen:
            return NSImage(resource: .iconPremiumBoardingLastSeen).precomposed(presentation.colors.accent)
        case .message_privacy:
            return NSImage(resource: .iconPremiumBoardingMessagePrivacy).precomposed(presentation.colors.accent)
        case .business:
            return NSImage(resource: .iconPremiumBoardingBusiness).precomposed(presentation.colors.accent)
        case .business_location:
            return NSImage(resource: .iconPremiumBusinessLocation).precomposed(presentation.colors.accent)
        case .business_hours:
            return NSImage(resource: .iconPremiumBusinessHours).precomposed(presentation.colors.accent)
        case .quick_replies:
            return NSImage(resource: .iconPremiumBusinessQuickReply).precomposed(presentation.colors.accent)
        case .greeting_message:
            return NSImage(resource: .iconPremiumBusinessGreeting).precomposed(presentation.colors.accent)
        case .away_message:
            return NSImage(resource: .iconPremiumBusinessAway).precomposed(presentation.colors.accent)
        case .business_bots:
            return NSImage(resource: .iconPremiumBusinessBot).precomposed(presentation.colors.accent)
        case .business_intro:
            return NSImage(resource: .iconPremiumBusinessIntro).precomposed(presentation.colors.accent)
        case .business_links:
            return NSImage(resource: .iconPremiumBusinessLinks).precomposed(presentation.colors.accent)
        case .folder_tags:
            return NSImage(resource: .iconPremiumBoardingTag).precomposed(presentation.colors.accent)
        case .todo:
            return NSImage(resource: .iconPremiumBoardingTodo).precomposed(presentation.colors.accent)
        }
    }
    
    func title(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .double_limits:
            return strings().premiumBoardingDoubleTitle
        case .more_upload:
            return strings().premiumBoardingFileSizeTitle(String.prettySized(with: limits.upload_max_fileparts_premium, afterDot: 0, round: true))
        case .faster_download:
            return strings().premiumBoardingDownloadTitle
        case .voice_to_text:
            return strings().premiumBoardingVoiceTitle
        case .no_ads:
            return strings().premiumBoardingNoAdsTitle
        case .infinite_reactions:
            return strings().premiumBoardingReactionsNewTitle
        case .premium_stickers:
            return strings().premiumBoardingStickersTitle
        case .emoji_status:
            return strings().premiumBoardingStatusTitle
        case .animated_emoji:
            return strings().premiumBoardingEmojiTitle
        case .advanced_chat_management:
            return strings().premiumBoardingChatsTitle
        case .profile_badge:
            return strings().premiumBoardingBadgeTitle
        case .animated_userpics:
            return strings().premiumBoardingAvatarTitle
        case .translations:
            return strings().premiumBoardingTranslateTitle
        case .stories:
            return strings().premiumBoardingStoriesTitle
        case .wallpapers:
            return strings().premiumBoardingWallpapersTitle
        case .peer_colors:
            return strings().premiumBoardingColorsTitle
        case .saved_tags:
            return strings().premiumBoardingSavedTagsTitle
        case .last_seen:
            return strings().premiumBoardingLastSeenTitle
        case .message_privacy:
            return strings().premiumBoardingMessagePrivacyTitle
        case .business:
            return strings().premiumBoardingBusinessTelegramBusiness
        case .business_location:
            return strings().premiumBoardingBusinessLocation
        case .business_hours:
            return strings().premiumBoardingBusinessOpeningHours
        case .quick_replies:
            return strings().premiumBoardingBusinessQuickReplies
        case .greeting_message:
            return strings().premiumBoardingBusinessGreetingMessages
        case .away_message:
            return strings().premiumBoardingBusinessAwayMessages
        case .business_bots:
            return strings().premiumBoardingBusinessChatBots
        case .business_intro:
            return strings().premiumBoardingBusinessIntro
        case .business_links:
            return strings().premiumBoardingBusinessLinks
        case .folder_tags:
            return strings().premiumBoardingTagFolders
        case .todo:
            return strings().premiumBoardingTodo
        }
    }
    func info(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .double_limits:
            return strings().premiumBoardingDoubleInfo("\(limits.channels_limit_premium)", "\(limits.dialog_filters_limit_premium)", "\(limits.dialog_pinned_limit_premium)", "\(limits.channels_public_limit_premium)")
        case .more_upload:
            return strings().premiumBoardingFileSizeInfo(String.prettySized(with: limits.upload_max_fileparts_default, afterDot: 0, round: true), String.prettySized(with: limits.upload_max_fileparts_premium, afterDot: 0, round: true))
        case .faster_download:
            return strings().premiumBoardingDownloadInfo
        case .voice_to_text:
            return strings().premiumBoardingVoiceInfo
        case .no_ads:
            return strings().premiumBoardingNoAdsInfo
        case .infinite_reactions:
            return strings().premiumBoardingReactionsNewInfo
        case .premium_stickers:
            return strings().premiumBoardingStickersInfo
        case .emoji_status:
            return strings().premiumBoardingStatusInfo
        case .animated_emoji:
            return strings().premiumBoardingEmojiInfo
        case .advanced_chat_management:
            return strings().premiumBoardingChatsInfo
        case .profile_badge:
            return strings().premiumBoardingBadgeInfo
        case .animated_userpics:
            return strings().premiumBoardingAvatarInfo
        case .translations:
            return strings().premiumBoardingTranslateInfo
        case .stories:
            return strings().premiumBoardingStoriesInfo
        case .wallpapers:
            return strings().premiumBoardingWallpapersInfo
        case .peer_colors:
            return strings().premiumBoardingColorsInfo
        case .saved_tags:
            return strings().premiumBoardingSavedTagsInfo
        case .last_seen:
            return strings().premiumBoardingLastSeenInfo
        case .message_privacy:
            return strings().premiumBoardingMessagePrivacyInfo
        case .business:
            return strings().premiumBoardingBusinessTelegramBusinessInfo
        case .business_location:
            return strings().premiumBoardingBusinessLocationInfo
        case .business_hours:
            return strings().premiumBoardingBusinessOpeningHoursInfo
        case .quick_replies:
            return strings().premiumBoardingBusinessQuickRepliesInfo
        case .greeting_message:
            return strings().premiumBoardingBusinessGreetingMessagesInfo
        case .away_message:
            return strings().premiumBoardingBusinessAwayMessagesInfo
        case .business_bots:
            return strings().premiumBoardingBusinessChatBotsInfo
        case .business_intro:
            return strings().premiumBoardingBusinessIntroInfo
        case .business_links:
            return strings().premiumBoardingBusinessLinksInfo
        case .folder_tags:
            return strings().premiumBoardingTagFoldersInfo
        case .todo:
            return strings().premiumBoardingTodoInfo
        }
    }
}



private struct State : Equatable {
    var values:[PremiumValue] = [.double_limits, .stories, .more_upload, .faster_download, .voice_to_text, .no_ads, .infinite_reactions, .emoji_status, .premium_stickers, .animated_emoji, .advanced_chat_management, .profile_badge, .animated_userpics, .translations, .saved_tags, .last_seen, .message_privacy, .todo]
    var businessValues: [PremiumValue] = []
    
    let source: PremiumLogEventsSource
    
    var premiumProduct: InAppPurchaseManager.Product?
    var products: [InAppPurchaseManager.Product] = []
    var isPremium: Bool
    var peer: PeerEquatable?
    var premiumConfiguration: PremiumPromoConfiguration
    var stickers: [TelegramMediaFile]
    var canMakePayment: Bool
    var status: PremiumEmojiStatusInfo?
    var period: PremiumPeriod?
    var periods: [PremiumPeriod] = []
    
    var newPerks: [String] = []
    
    var adsEnabled: Bool = false
    
    func activateForFree(_ accountPeerId: PeerId) -> Bool {
        switch source {
        case let .gift(_, toId, _, slug, unclaimed):
            if let _ = slug, unclaimed {
                return accountPeerId == toId
            } else {
                return false
            }
        default:
            return false
        }
    }
    var slug: String? {
        switch source {
        case let .gift(_, _, _, slug, _):
            return slug
        default:
            return nil
        }
    }

}

private let _id_toggle_ads = InputDataIdentifier("_id_toggle_ads")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(35)))
    sectionId += 1

    
    let scene: PremiumBoardingHeaderItem.SceneType
    if case let .limitedGift(gift) = state.source {
        scene = .gift(gift)
    } else if state.source == .business_standalone || state.source == .business {
        scene = .coin
    } else if state.source == .grace_period {
        scene = .grace
    } else {
        scene = .star
    }
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        
        let status: NSAttributedString
        status = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: state.premiumConfiguration.statusEntities)], for: state.premiumConfiguration.status, message: nil, context: arguments.context, fontSize: 13, openInfo: arguments.openInfo, isDark: theme.colors.isDark, bubbled: theme.bubbled)

        return PremiumBoardingHeaderItem(initialSize, stableId: stableId, context: arguments.context, presentation: arguments.presentation, isPremium: state.isPremium, peer: state.peer?.peer, emojiStatus: state.status, source: state.source, premiumText: status, viewType: .legacy, sceneType: scene)
    }))
    index += 1
    
    
    switch state.source {
    case let .gift(fromId, toId, _, slug, unclaimed):
        if fromId != arguments.context.peerId, let slug = slug, unclaimed {
            let link = "t.me/giftcode/\(slug.prefixWithDots(20))"
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("link"), equatable: InputDataEquatable(link), comparable: nil, item: { initialSize, stableId in
                return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: link, font: .normal(.text), insets: NSEdgeInsets(left: 20, right: 20), rightAction: .init(image: arguments.presentation.icons.fast_copy_link, action: { _ in
                    arguments.copyLink("t.me/giftcode/\(slug)")
                }), customTheme: .initialize(arguments.presentation))
            }))
            index += 1
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    default:
        break
    }
    
    
    if !state.periods.isEmpty, !state.isPremium {
        let period = state.period ?? state.periods[0]
                
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_id_periods"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
            return PremiumSelectPeriodRowItem(initialSize, stableId: stableId, context: arguments.context, presentation: arguments.presentation, periods: state.periods, selectedPeriod: period, viewType: .singleItem, callback: { period in
                arguments.togglePeriod(period)
            })
        }))
        index += 1

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    if state.source == .business || state.source == .business_standalone, !state.businessValues.isEmpty {
        for (i, value) in state.businessValues.enumerated() {
            let viewType = bestGeneralViewType(state.businessValues, for: i)
            
            struct Tuple : Equatable {
                let value: PremiumValue
                let isNew: Bool
            }
            let tuple = Tuple(value: value, isNew: state.newPerks.contains(value.rawValue))
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init(value.rawValue), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return PremiumBoardingRowItem(initialSize, stableId: stableId, viewType: viewType, presentation: arguments.presentation, index: i, value: value, limits: arguments.context.premiumLimits, isLast: false, isNew: tuple.isNew, callback: { value in
                    arguments.openFeature(value, true)
                })
            }))
            index += 1
        }
        
        if state.source == .business {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().premiumBoardingMoreBusinessHeaderCountable(state.values.count)), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
        }
    }
    
    if state.source != .business_standalone {
        let elements = state.values.uniqueElements
        for (i, value) in elements.enumerated() {
            let viewType = bestGeneralViewType(elements, for: i)
            
            struct Tuple : Equatable {
                let value: PremiumValue
                let isNew: Bool
                let viewType: GeneralViewType
            }
            let tuple = Tuple(value: value, isNew: state.newPerks.contains(value.rawValue), viewType: viewType)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init(value.rawValue), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return PremiumBoardingRowItem(initialSize, stableId: stableId, viewType: viewType, presentation: arguments.presentation, index: i, value: value, limits: arguments.context.premiumLimits, isLast: false, isNew: tuple.isNew, callback: { value in
                    arguments.openFeature(value, true)
                })
            }))
            index += 1
        }
        
        if !state.isPremium {
            let status = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: state.premiumConfiguration.statusEntities)], for: state.premiumConfiguration.status, message: nil, context: arguments.context, fontSize: 11.5, openInfo: arguments.openInfo, textColor: arguments.presentation.colors.listGrayText, isDark: theme.colors.isDark, bubbled: theme.bubbled)

            entries.append(.desc(sectionId: sectionId, index: index, text: .attributed(status), data: .init(color: arguments.presentation.colors.listGrayText, viewType: .textBottomItem)))
            index += 1
        } else {
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1

            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().premiumBoardingAboutTitle.uppercased()), data: .init(color: arguments.presentation.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_id_about"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: strings().premiumBoardingAboutText, font: .normal(.text))
            }))
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().premiumBoardingAboutTos, linkHandler: { link in
                execute(inapp: .external(link: "https://telegram.org/" + link == "terms" ? "tos" : link, false))
            }), data: .init(color: arguments.presentation.colors.listGrayText, viewType: .textBottomItem)))
            index += 1

        }
    } else {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessSwitchAdTitle), data: .init(color: arguments.presentation.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_toggle_ads, data: .init(name: strings().businessSwitchAd, color: theme.colors.text, type: .switchable(state.adsEnabled) , viewType: .singleItem, action: {
            arguments.toggleAds(!state.adsEnabled)
        })))
        
        
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().businessSwitchAdInfo, linkHandler: arguments.execute), data: .init(color: arguments.presentation.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

    }
    
    
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

   
    
    return entries
}

private final class PremiumBoardingView : View {
    
    private final class AcceptView : Control {
        private let gradient: PremiumGradientView = PremiumGradientView(frame: .zero)
        private let shimmer = ShimmerEffectView()
        private let textView = TextView()
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
            addSubview(shimmer)
            shimmer.isStatic = true
            container.addSubview(textView)
            addSubview(container)
            scaleOnClick = true
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            
            
            gradient.frame = bounds
            shimmer.frame = bounds
            
            shimmer.updateAbsoluteRect(bounds, within: frame.size)
            shimmer.update(backgroundColor: .clear, foregroundColor: .clear, shimmeringColor: NSColor.white.withAlphaComponent(0.3), shapes: [.roundedRect(rect: bounds, cornerRadius: frame.height / 2)], horizontal: true, size: frame.size)
            
            container.center()
            textView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(animated: Bool, state: State, context: AccountContext) -> NSSize {
            
            let option = state.period
            guard let option = state.period else {
                return .zero
            }

            let text: String
            if state.activateForFree(context.peerId) {
                text = strings().premiumBoardingActivateForFree
            } else {
                if state.canMakePayment {
                    if state.source == .grace_period {
                        text = option.renewString
                    } else {
                        text = option.buyString
                    }
                } else {
                    text = strings().premiumBoardingPaymentNotAvailalbe
                }
            }
            
            
            let layout = TextViewLayout(.initialize(string: text, color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
                        
            container.setFrameSize(layout.layoutSize)
            
            let size = NSMakeSize(container.frame.width + 100, 40)
            

            needsLayout = true
            
            self.userInteractionEnabled = state.canMakePayment || state.activateForFree(context.peerId)
            
            self.alphaValue = state.canMakePayment || state.activateForFree(context.peerId) ? 1.0 : 0.7
            
            return size
        }
    }
    
    final class HeaderView: View {
        let dismiss = ImageButton()
        private let container = View()
        private let titleView = TextView()
        let presentation: TelegramPresentationTheme
        init(frame frameRect: NSRect, presentation: TelegramPresentationTheme) {
            self.presentation = presentation
            super.init(frame: frameRect)
            addSubview(container)
            addSubview(dismiss)
            
            dismiss.scaleOnClick = true
            dismiss.autohighlight = false
            
            dismiss.set(image: presentation.icons.modalClose, for: .Normal)
            dismiss.sizeToFit()
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            titleView.isEventLess = true
            
            container.backgroundColor = presentation.colors.background
            container.border = [.Bottom]
            container.borderColor = presentation.colors.border

            let layout = TextViewLayout(.initialize(string: strings().premiumBoardingTitle, color: presentation.colors.text, font: .medium(.header)))
            layout.measure(width: 300)
            
            titleView.update(layout)
            container.addSubview(titleView)
        }
        
        func update(isHidden: Bool, animated: Bool) {
            container.change(opacity: isHidden ? 0 : 1, animated: animated)
        }
        
        override func layout() {
            super.layout()
            dismiss.centerY(x: 10)
            container.frame = bounds
            titleView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
    }

    
    let headerView: HeaderView
    let tableView = TableView()
    private var bottomView: View?
    private let bottomBorder = View()
    private let acceptView = AcceptView(frame: .zero)
    
    private let containerView = View()
    private var fadeView: View?
    
    var dismiss:(()->Void)?
    var accept:(()->Void)?
    
    private var state: State?
    private var arguments: Arguments?
    let presentation: TelegramPresentationTheme

    init(frame frameRect: NSRect, presentation: TelegramPresentationTheme) {
        self.presentation = presentation
        self.headerView = HeaderView(frame: .zero, presentation: presentation)
        super.init(frame: frameRect)
        containerView.addSubview(tableView)
        containerView.addSubview(headerView)
        addSubview(containerView)
        
        tableView.getBackgroundColor = {
            presentation.colors.listBackground
        }
                
        bottomBorder.backgroundColor = presentation.colors.border
        
        
        tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            self?.updateScroll(position, animated: true)
        }))
        
        headerView.dismiss.set(handler: { [weak self] _ in
            self?.dismiss?()
        }, for: .Click)
        
        acceptView.set(handler: { [weak self] _ in
            self?.accept?()
        }, for: .Click)
    }
    
    private func updateScroll(_ scroll: ScrollPosition, animated: Bool) {
        let offset = scroll.rect.minY - tableView.frame.height
        
        if scroll.rect.minY >= tableView.listHeight {
            bottomBorder.change(opacity: 0, animated: animated)
            bottomView?.backgroundColor = presentation.colors.listBackground
            if animated {
                bottomView?.layer?.animateBackground()
            }
        } else {
            bottomBorder.change(opacity: 1, animated: animated)
            bottomView?.backgroundColor = presentation.colors.background
            if animated {
                bottomView?.layer?.animateBackground()
            }
        }
        
        headerView.update(isHidden: offset <= 127, animated: animated)
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    var bottomHeight: CGFloat {
        if let _ = bottomView {
            return acceptView.frame.height + 20
        } else {
            return 0
        }
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: headerView, frame: NSMakeRect(0, 0, size.width, 50))
        transition.updateFrame(view: containerView, frame: bounds)
        
        transition.updateFrame(view: tableView, frame: NSMakeRect(0, 0, size.width, size.height - bottomHeight))
        if let bottomView = bottomView {
            transition.updateFrame(view: bottomView, frame: NSMakeRect(0, tableView.frame.maxY, size.width, bottomHeight))
            
            transition.updateFrame(view: acceptView, frame: bottomView.focus(acceptView.frame.size))
            
            transition.updateFrame(view: bottomBorder, frame: NSMakeRect(0, 0, bottomView.frame.width, .borderSize))
        }
        
        if let controller = self.currentController {
            transition.updateFrame(view: controller.view, frame: bounds)
        }
    }
    
    func contentSize(maxSize size: NSSize) -> NSSize {
        return NSMakeSize(size.width, min(min(headerView.frame.height + tableView.listHeight + bottomHeight, 523), size.height))
    }
    
    private var first = true
    func update(animated: Bool, arguments: Arguments, state: State) {
        let previousState = self.state
        self.state = state
        self.arguments = arguments
        let size = acceptView.update(animated: animated, state: state, context: arguments.context)
        acceptView.setFrameSize(NSMakeSize(frame.width - 40, size.height))
        acceptView.layer?.cornerRadius = 10
        let transition: ContainedViewLayoutTransition
        if animated && !first {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
            first = false
        }
        
        
        if state.isPremium != previousState?.isPremium || state.activateForFree(arguments.context.peerId) {
            if !state.isPremium || state.activateForFree(arguments.context.peerId) {
                let bottomView = View(frame: NSMakeRect(0, frame.height - bottomHeight, frame.width, bottomHeight))
                containerView.addSubview(bottomView)
                
                bottomView.addSubview(acceptView)
                bottomView.addSubview(bottomBorder)
                
                if let view = self.bottomView {
                    performSubviewRemoval(view, animated: animated)
                }
                
                self.bottomView = bottomView
                
                if animated {
                    bottomView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
        } else if let bottomView = bottomView, state.isPremium {
            if state.peer != nil || state.isPremium {
                self.bottomView = nil
                performSubviewRemoval(bottomView, animated: animated)
            }
        }
                
        self.updateScroll(tableView.scrollPosition().current, animated: false)

        updateLayout(size: frame.size, transition: transition)
    }
    
    func makeAcceptView() -> Control? {
        if let state = self.state, !state.isPremium, let arguments = self.arguments {
            let acceptView = AcceptView(frame: .zero)
            let size = acceptView.update(animated: false, state: state, context: arguments.context)
            acceptView.setFrameSize(NSMakeSize(frame.width - 40, size.height))
            acceptView.layer?.cornerRadius = 10
            acceptView.set(handler: { [weak self] _ in
                self?.accept?()
            }, for: .Click)
            
            return acceptView
        } else {
            let okButton = TextButton()
            okButton.scaleOnClick = true
            okButton.autohighlight = false
            okButton.set(font: .medium(.text), for: .Normal)
            okButton.set(color: .white, for: .Normal)
            okButton.layer?.cornerRadius = 10
            okButton.set(text: strings().modalOK, for: .Normal)
            okButton.sizeToFit(.zero, NSMakeSize(frame.width - 40, 40), thatFit: true)
            okButton.layer?.cornerRadius = 10
            let gradient = CAGradientLayer()
            gradient.frame = okButton.bounds
            gradient.disableActions()
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 0)
            
            gradient.colors = premiumGradient.compactMap { $0.cgColor }
            
            okButton.layer?.insertSublayer(gradient, at: 0)
            
            okButton.set(handler: { [weak self] _ in
                self?.dismiss?()
            }, for: .Click)
            
            return okButton
        }
        
    }
    
    private(set) var currentController: ViewController?
    
    private let duration: Double = 0.4
    
    func append(_ controller: ViewController, animated: Bool) {
        controller._frameRect = self.bounds
        addSubview(controller.view)

        if animated {
            controller.view.layer?.animatePosition(from: NSMakePoint(frame.width, 0), to: .zero, duration: duration, timingFunction: .spring)
            self.containerView.layer?.animatePosition(from: .zero, to: NSMakePoint(-30, 0), duration: duration, timingFunction: .spring)
            
            applyFade(from: 0, to: 1)

        }
        
        self.currentController = controller
    }
    
    private func applyFade(from: Double, to: Double) {
        let fadeView = View()
        fadeView.backgroundColor = presentation.colors.blackTransparent
        fadeView.frame = bounds
        addSubview(fadeView, positioned: .above, relativeTo: containerView)
        
        fadeView.layer?.animateAlpha(from: from, to: to, duration: duration - 0.05, removeOnCompletion: false, completion: { [weak fadeView] _ in
            fadeView?.removeFromSuperview()
        })
    }
    
    func stackBack(animated: Bool) -> Bool {
        if let controller = currentController {
            controller.view.layer?.animatePosition(from: .zero, to: NSMakePoint(frame.width, 0), duration: duration, timingFunction: .spring, removeOnCompletion: false, completion: { [weak controller, weak self] _ in
                controller?.view.removeFromSuperview()
                self?.currentController = nil
            })

            self.containerView.layer?.animatePosition(from: NSMakePoint(-30, 0), to: .zero, duration: duration, timingFunction: .spring)
            
            applyFade(from: 1, to: 0)
            
            return true
        } else {
            return false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

final class PremiumBoardingController : ModalViewController {

    fileprivate let context: AccountContext
    private let source: PremiumLogEventsSource
    private let openFeatures: Bool
    private let presentation: TelegramPresentationTheme
    init(context: AccountContext, source: PremiumLogEventsSource = .settings, openFeatures: Bool = false, presentation: TelegramPresentationTheme = theme) {
        self.context = context
        self.source = source
        self.openFeatures = openFeatures
        self.presentation = presentation
        super.init(frame: NSMakeRect(0, 0, 380, 530))
        bar = .init(height: 50, enableBorder: false)
    }
    
    override var hasBorder: Bool {
        return false
    }
    
    override func measure(size: NSSize) {
        updateSize(false)
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: genericView.contentSize(maxSize: NSMakeSize(380, contentSize.height - 80)), animated: animated)
        }
    }
    
    override func initializer() -> NSView {
        return PremiumBoardingView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), presentation: presentation)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    private var genericView: PremiumBoardingView {
        return self.view as! PremiumBoardingView
    }
    
    override func viewClass() -> AnyClass {
        return PremiumBoardingView.self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.openFeatures {
            if let value = self.source.features {
                arguments?.openFeature(value, false)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        window?.set(handler: { [weak self] _ in
            let features = self?.genericView.currentController as? PremiumBoardingFeaturesController
            features?.genericView.prev()
            return .invoked
        }, with: self, for: .LeftArrow, priority: .modal)
        
        window?.set(handler: { [weak self] _ in
            let features = self?.genericView.currentController as? PremiumBoardingFeaturesController
            features?.genericView.next()
            return .invoked
        }, with: self, for: .RightArrow, priority: .modal)
        
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    private var arguments: Arguments?
    
    override var enableBack: Bool {
        return true
    }
    
    
    override func loadView() {
        if self.source == .business_standalone {
            self.leftBarView = getLeftBarViewOnce()
            self.centerBarView = getCenterBarViewOnce()
            self.rightBarView = getRightBarViewOnce()
        }
        super.loadView()
    }
    
    override var defaultBarTitle: String {
        if source == .business_standalone {
            return strings().premiumBoardingBusinessTelegramBusiness
        }
        return super.defaultBarTitle
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let inAppPurchaseManager = context.inAppPurchaseManager
        
        let actionsDisposable = DisposableSet()
        let paymentDisposable = MetaDisposable()
        let activationDisposable = MetaDisposable()
        let context = self.context
        let source = self.source
        let openFeatures = self.openFeatures
        
        actionsDisposable.add(context.engine.accountData.keepShortcutMessageListUpdated().startStrict())
        actionsDisposable.add(context.engine.accountData.keepCachedTimeZoneListUpdated().startStrict())
        actionsDisposable.add(context.engine.accountData.refreshBusinessChatLinks().startStrict())
        
        actionsDisposable.add(context.account.viewTracker.peerView(context.peerId, updateData: true).start())
        
        PremiumLogEvents.promo_screen_show(source).send(context: context)
        
        let close: ()->Void = { [weak self] in
            self?.close()
        }

        var canMakePayment: Bool = true
        #if APP_STORE || DEBUG
        canMakePayment = inAppPurchaseManager.canMakePayments
        #endif
        
        
        
        let business = context.premiumOrder.premiumValues.filter { $0.isBusiness }.uniqueElements
        let rest = context.premiumOrder.premiumValues.filter { !$0.isBusiness }.uniqueElements

        var initialState = State(values: rest, businessValues: business, source: source, isPremium: context.isPremium, premiumConfiguration: PremiumPromoConfiguration.defaultValue, stickers: [], canMakePayment: canMakePayment, newPerks: FastSettings.premiumPerks)
        
        if source != .business && source != .business_standalone {
            initialState.values.insert(.business, at: 1)
        }
        
        let statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        
        actionsDisposable.add(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.AdsEnabled(id: context.peerId)).start(next: { value in
            updateState { current in
                var current = current
                current.adsEnabled = value
                return current
            }
        }))
        
        let arguments = Arguments(context: context, presentation: presentation, showTerms: {
            
        }, showPrivacy: {
            
        }, openInfo: { peerId, _, _, initialAction in
            var updated: ChatInitialAction? = initialAction
            switch initialAction {
            case let .start(parameter, _):
                updated = .start(parameter: parameter, behavior: .automatic)
            default:
                break
            }
            navigateToChat(navigation: context.bindings.rootNavigation(), context: context, chatLocation: .peer(peerId), initialAction: updated)
            
            close()
        }, openFeature: { [weak self] value, animated in
            
            guard let strongSelf = self else {
                return
            }
            
            FastSettings.dismissPremiumPerk(value.rawValue)
            
            if strongSelf.source == .business_standalone {
                switch value {
                case .business_location:
                    strongSelf.navigationController?.push(BusinessLocationController(context: context))
                case .business_hours:
                    strongSelf.navigationController?.push(BusinessHoursController(context: context))
                case .quick_replies:
                    strongSelf.navigationController?.push(BusinessQuickReplyController(context: context))
                case .greeting_message:
                    strongSelf.navigationController?.push(BusinessMessageController(context: context, type: .greetings))
                case .away_message:
                    strongSelf.navigationController?.push(BusinessMessageController(context: context, type: .away))
                case .business_bots:
                    strongSelf.navigationController?.push(BusinessChatbotController(context: context))
                case .business_intro:
                    strongSelf.navigationController?.push(BusinessIntroController(context: context))
                case .business_links:
                    strongSelf.navigationController?.push(BusinessLinksController(context: context))
                default:
                    fatalError("not possible")
                }
                return
            }
            strongSelf.genericView.append(PremiumBoardingFeaturesController(context, presentation: strongSelf.presentation, value: value, stickers: stateValue.with { $0.stickers }, configuration: stateValue.with { $0.premiumConfiguration }, back: { [weak strongSelf] in
                _ = strongSelf?.escapeKeyAction()
            }, makeAcceptView: { [weak strongSelf] in
                return strongSelf?.genericView.makeAcceptView()
            }), animated: animated)
            
            updateState { current in
                var current = current
                current.newPerks.removeAll(where: { $0 == value.rawValue })
                return current
            }
        }, togglePeriod: { period in
            updateState { current in
                var current = current
                current.period = period
                return current
            }
        }, execute: { link in
            if link.isEmpty {
                execute(inapp: .external(link: "https://telegram.org/tos", false))
            } else {
                execute(inapp: .external(link: link, false))
            }
        }, copyLink: { link in
            copyToClipboard(link)
            showModalText(for: context.window, text: strings().shareLinkCopied)
        }, toggleAds: { value in
            _ = context.engine.accountData.updateAdMessagesEnabled(enabled: value).startStandalone()
        })
        
        self.arguments = arguments
        
        
        
        let peer: Signal<(Peer?, PremiumEmojiStatusInfo?), NoError>
        switch source {
        case let .profile(peerId):
            peer = context.account.postbox.transaction { $0.getPeer(peerId) }
            |> mapToSignal { peer in
                if let peer = peer {
                    if let status = peer.emojiStatus {
                        return context.inlinePacksContext.load(fileId: status.fileId) |> mapToSignal { file in
                            if let file = file, let reference = file.emojiReference {
                                if !isDefaultStatusesPackId(reference) {
                                    return context.engine.stickers.loadedStickerPack(reference: reference, forceActualized: false) |> map { pack in
                                        switch pack {
                                        case let .result(info, items, _):
                                            return (peer, PremiumEmojiStatusInfo(status: status, file: file, info: info._parse(), items: items))
                                        default:
                                            return (peer, nil)
                                        }
                                    } |> filter {
                                        return $0.1 != nil
                                    } |> take(1)
                                } else {
                                    return .single((peer, .init(status: status, file: file, info: nil, items: [])))
                                }
                            } else {
                                return .single((peer, nil))
                            }
                        }
                    } else {
                        return .single((peer, nil))
                    }
                } else {
                    return .single((peer, nil))
                }
            }
        case let .gift(from, to, _, _, _):
            if from == context.peerId {
                peer = context.account.postbox.transaction { ($0.getPeer(to), nil) }
            } else {
                peer = context.account.postbox.transaction { ($0.getPeer(from), nil) }
            }
        default:
            peer = .single((nil, nil))
        }
        
        
        
        let premiumPromo = context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.PremiumPromo())
        |> deliverOnMainQueue
        
        
        let stickersKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudPremiumStickers)

        let stickers: Signal<[TelegramMediaFile], NoError> = context.account.postbox.combinedView(keys: [stickersKey])
        |> map { views -> [OrderedItemListEntry] in
            if let view = views.views[stickersKey] as? OrderedItemListView, !view.items.isEmpty {
                return view.items
            } else {
                return []
            }
        }
        |> map { items in
            var result: [TelegramMediaFile] = []
            for item in items {
                if let mediaItem = item.contents.get(RecentMediaItem.self) {
                    result.append(mediaItem.media._parse())
                }
            }
            return result
        }
        |> take(1)
        |> deliverOnMainQueue
        
        let products: Signal<[InAppPurchaseManager.Product], NoError>
        #if APP_STORE //|| DEBUG
        products = inAppPurchaseManager.availableProducts |> map {
            $0.filter { $0.isSubscription }
        }
        #else
        products = .single([])
        #endif
        
        actionsDisposable.add(combineLatest(
            queue: Queue.mainQueue(),
            products,
            premiumPromo,
            stickers,
            context.account.postbox.peerView(id: context.account.peerId)
            |> map { view -> Bool in
                return view.peers[view.peerId]?.isPremium ?? false
            }, peer).start(next: { products, promoConfiguration, stickers, isPremium, peerAndStatus in
                updateState { current in
                    var current = current
                    current.premiumProduct = products.first
                    current.products = products
                    current.isPremium = isPremium
                    current.premiumConfiguration = promoConfiguration
                    current.stickers = stickers
                    current.periods = promoConfiguration.premiumProductOptions.compactMap { period in
                        if let value = PremiumPeriod.Period(rawValue: period.months) {
                            #if APP_STORE
                            if products.first(where: { $0.id == period.storeProductId }) == nil {
                                return nil
                            }
                            #endif
                            return .init(period: value, options: promoConfiguration.premiumProductOptions, storeProducts: products, storeProduct: products.first(where: { $0.id == period.storeProductId }), option: period)
                        }
                        return nil
                    }
                    if current.period == nil {
                        current.period = current.periods.first
                    }
                    if let peer = peerAndStatus.0 {
                        current.peer = .init(peer)
                        current.status = peerAndStatus.1
                    }
                    
                    return current
                }
                var videos = promoConfiguration.videos.map {
                    (key: $0.key, value: $0.value)
                }
                if openFeatures {
                    videos = videos.sorted(by: { lhs, rhs in
                        if source.value == lhs.key {
                            return true
                        }
                        return false
                    })
                }
                var delayValue: CGFloat = 0
                for (_, video) in promoConfiguration.videos {
                    let signal = preloadVideoResource(postbox: context.account.postbox, userLocation: .other, userContentType: .init(file: video), resourceReference: .standalone(resource: video.resource), duration: 3.0) |> delay(delayValue, queue: .concurrentBackgroundQueue())
                    actionsDisposable.add(signal.start())
                    if openFeatures {
                        delayValue += 1
                    }
                }
        }))

        
        let stateSignal = statePromise.get() |> filter { $0.period != nil } |> deliverOnPrepareQueue |> map { state in
            return (InputDataSignalValue(entries: entries(state, arguments: arguments)), state)
        }
        
        let previous: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        
        let inputArguments = InputDataArguments(select: { _, _ in }, dataUpdated: {
            
        })
        
        
        let signal: Signal<(TableUpdateTransition, State), NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, stateSignal) |> mapToQueue { appearance, state in
            let entries = state.0.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            return prepareInputDataTransition(left: previous.swap(entries), right: entries, animated: state.0.animated, searchState: state.0.searchState, initialSize: initialSize.modify{ $0 }, arguments: inputArguments, onMainQueue: true)
            |> map {
                ($0, state.1)
            }
        } |> deliverOnMainQueue |> afterDisposed {
            previous.swap([])
        }
        
        actionsDisposable.add(signal.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition.0)
            self?.genericView.update(animated: transition.0.animated, arguments: arguments, state: transition.1)
            self?.updateSize(true)
            self?.readyOnce()
        }))
        
        
        
        let buyNonStore = {
            
            let url = context.appConfiguration.getStringValue("premium_manage_subscription_url", orElse: "https://t.me/premiumbot?start=status")
            if source == .grace_period {
                let inApp = inApp(for: url.nsstring, context: context, openInfo: arguments.openInfo)
                execute(inapp: inApp)
                close()
                return
            }
            
            if let slug = context.premiumBuyConfig.invoiceSlug {
                
                let signal = showModalProgress(signal: context.engine.payments.fetchBotPaymentInvoice(source: .slug(slug)), for: context.window)

                _ = signal.start(next: { invoice in
                    showModal(with: PaymentsCheckoutController(context: context, source: .slug(slug), invoice: invoice, completion: { status in
                        switch status {
                        case .paid:
                            PlayConfetti(for: context.window)
                            close()
                        case .cancelled:
                            break
                        case .failed:
                            break
                        }
                    }), for: context.window)
                }, error: { error in
                    showModalText(for: context.window, text: strings().paymentsInvoiceNotExists)
                })
            } else if let url = stateValue.with ({ $0.period?.option.botUrl }) {
                let inApp = inApp(for: url.nsstring, context: context, openInfo: arguments.openInfo)
                execute(inapp: inApp)
                close()
            }
        }
        
        
        let buyAppStore = {
            
            let url = context.appConfiguration.getStringValue("premium_manage_subscription_url", orElse: "https://apps.apple.com/account/subscriptions")
            if source == .grace_period {
                let inApp = inApp(for: url.nsstring, context: context, openInfo: arguments.openInfo)
                execute(inapp: inApp)
                close()
                return
            }
            
            let premiumProduct = stateValue.with { $0.period?.storeProduct }

            guard let premiumProduct = premiumProduct else {
                buyNonStore()
                return
            }
            
            let lockModal = PremiumLockModalController()
            
            var needToShow = true
            delay(0.2, closure: {
                if needToShow {
                    showModal(with: lockModal, for: context.window)
                }
            })
            
            let _ = (context.engine.payments.canPurchasePremium(purpose: .subscription)
            |> deliverOnMainQueue).start(next: { [weak lockModal] available in
                if available {
                    
                    paymentDisposable.set((inAppPurchaseManager.buyProduct(premiumProduct, purpose: .subscription)
                    |> deliverOnMainQueue).start(next: { [weak lockModal] status in
        
                        lockModal?.close()
                        needToShow = false
                        close()
                        inAppPurchaseManager.finishAllTransactions()
                        delay(0.2, closure: {
                            PlayConfetti(for: context.window)
                            showModalText(for: context.window, text: strings().premiumBoardingAppStoreSuccess)
                            let _ = updatePremiumPromoConfigurationOnce(account: context.account).start()
                        })
                        
                    }, error: { [weak lockModal] error in
                        let errorText: String
                        switch error {
                            case .generic:
                                errorText = strings().premiumPurchaseErrorUnknown
                            case .network:
                                errorText =  strings().premiumPurchaseErrorNetwork
                            case .notAllowed:
                                errorText =  strings().premiumPurchaseErrorNotAllowed
                            case .cantMakePayments:
                                errorText =  strings().premiumPurchaseErrorCantMakePayments
                            case .assignFailed:
                                errorText =  strings().premiumPurchaseErrorUnknown
                            case .cancelled:
                                errorText = strings().premiumBoardingAppStoreCancelled
                        }
                        lockModal?.close()
                        showModalText(for: context.window, text: errorText)
                        inAppPurchaseManager.finishAllTransactions()
                    }))
                } else {
                    lockModal?.close()
                    needToShow = false
                }
            })
        }
        
      
        genericView.dismiss = { [weak self] in
            if self?.genericView.stackBack(animated: true) == false {
                close()
            }
        }
        
        genericView.headerView.isHidden = source == .business_standalone
        
        genericView.accept = {
            
            
            let state = stateValue.with { $0 }
            if state.activateForFree(context.peerId), let slug = state.slug {
                if state.isPremium {
                    showModalText(for: context.window, text: strings().premiumBoardingActivateForFreeAlready)
                } else {
                    _ = context.engine.payments.applyPremiumGiftCode(slug: slug).start()
                    PlayConfetti(for: context.window)
                    showModalText(for: context.window, text: strings().giftLinkUseSuccess)
                    close()
                }
                
            } else {
                addAppLogEvent(postbox: context.account.postbox, type: PremiumLogEvents.promo_screen_accept.value)
                
                #if APP_STORE
                buyAppStore()
                #else
                buyNonStore()
                #endif
            }
        }
                
        self.onDeinit = {
            actionsDisposable.dispose()
        }
        
    }
    
    func buy() {
        if isLoaded() {
            self.genericView.accept?()
        }
    }
    
    override var modalTheme: ModalViewController.Theme {
        return .init(presentation: presentation)
    }
    
    func restore() {
        let context = self.context
        
        context.inAppPurchaseManager.restorePurchases(completion: { restore in
            switch restore {
            case let .succeed(value):
                if value {
                    showModalText(for: context.window, text: strings().premiumRestoreSuccess)
                }
            case .failed:
                showModalText(for: context.window, text: strings().premiumRestoreErrorUnknown)
            }
        })
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.stackBack(animated: true) {
            return .invoked
        } else {
            return super.escapeKeyAction()
        }
    }
    
    
}





func prem(with controller: PremiumBoardingController, for window: Window) {
    if controller.context.premiumIsBlocked {
        showModalText(for: window, text: strings().premiumBoardingPaymentNotAvailalbe)
    } else {
        showModal(with: controller, for: window)
    }
}
