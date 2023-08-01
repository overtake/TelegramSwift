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
    case gift(from: PeerId, to: PeerId, months: Int32)
    case send_as
    case translations
    case stealth_mode
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
        case .stealth_mode:
            return "stories__stealth_mode"
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
    let showTerms:()->Void
    let showPrivacy:()->Void
    let openInfo:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void
    let openFeature:(PremiumValue)->Void
    let togglePeriod:(PremiumPeriod)->Void
    init(context: AccountContext, showTerms: @escaping()->Void, showPrivacy:@escaping()->Void, openInfo:@escaping(PeerId, Bool, MessageId?, ChatInitialAction?)->Void, openFeature:@escaping(PremiumValue)->Void, togglePeriod:@escaping(PremiumPeriod)->Void) {
        self.context = context
        self.showPrivacy = showPrivacy
        self.showTerms = showTerms
        self.openInfo = openInfo
        self.openFeature = openFeature
        self.togglePeriod = togglePeriod
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
    func gradient(_ index: Int) -> [NSColor] {
        let colors:[NSColor] = [ NSColor(rgb: 0xF27C30),
                                 NSColor(rgb: 0xE36850),
                                 NSColor(rgb: 0xE36850),
                                 NSColor(rgb: 0xda5d63),
                                 NSColor(rgb: 0xD15078),
                                 NSColor(rgb: 0xC14998),
                                 NSColor(rgb: 0xB24CB5),
                                 NSColor(rgb: 0xA34ED0),
                                 NSColor(rgb: 0x9054E9),
                                 NSColor(rgb: 0x7561EB),
                                 NSColor(rgb: 0x5A6EEE),
                                 NSColor(rgb: 0x548DFF),
                                 NSColor(rgb: 0x54A3FF),
                                 NSColor(rgb: 0x54bdff),
                                 NSColor(rgb: 0x71c8ff)]
        return [colors[index]]
    }
    
    func icon(_ index: Int) -> CGImage {
        let image = self.image
        let size = image.backingSize
        let img = generateImage(size, contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            ctx.clip(to: size.bounds, mask: image)
            
            let colors = gradient(index).compactMap { $0.cgColor } as NSArray

            if gradient(index).count == 1 {
                ctx.setFillColor(gradient(index)[0].cgColor)
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
    
    var image: CGImage {
        switch self {
        case .double_limits:
            return NSImage(named: "Icon_Premium_Boarding_X2")!.precomposed(theme.colors.accent)
        case .more_upload:
            return NSImage(named: "Icon_Premium_Boarding_Files")!.precomposed(theme.colors.accent)
        case .faster_download:
            return NSImage(named: "Icon_Premium_Boarding_Speed")!.precomposed(theme.colors.accent)
        case .voice_to_text:
            return NSImage(named: "Icon_Premium_Boarding_Voice")!.precomposed(theme.colors.accent)
        case .no_ads:
            return NSImage(named: "Icon_Premium_Boarding_Ads")!.precomposed(theme.colors.accent)
        case .infinite_reactions:
            return NSImage(named: "Icon_Premium_Boarding_Reactions")!.precomposed(theme.colors.accent)
        case .emoji_status:
            return NSImage(named: "Premium_Boarding_Status")!.precomposed(theme.colors.accent)
        case .premium_stickers:
            return NSImage(named: "Icon_Premium_Boarding_Stickers")!.precomposed(theme.colors.accent)
        case .animated_emoji:
            return NSImage(named: "Icon_Premium_Boarding_Emoji")!.precomposed(theme.colors.accent)
        case .advanced_chat_management:
            return NSImage(named: "Icon_Premium_Boarding_Chats")!.precomposed(theme.colors.accent)
        case .profile_badge:
            return NSImage(named: "Icon_Premium_Boarding_Badge")!.precomposed(theme.colors.accent)
        case .animated_userpics:
            return NSImage(named: "Icon_Premium_Boarding_Profile")!.precomposed(theme.colors.accent)
        case .translations:
            return NSImage(named: "Icon_Premium_Boarding_Translations")!.precomposed(theme.colors.accent)
        case .stories:
            return NSImage(named: "Icon_Premium_Stories")!.precomposed(theme.colors.accent)
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
        }
    }
}



private struct State : Equatable {
    var values:[PremiumValue] = [.double_limits, .stories, .more_upload, .faster_download, .voice_to_text, .no_ads, .infinite_reactions, .emoji_status, .premium_stickers, .animated_emoji, .advanced_chat_management, .profile_badge, .animated_userpics, .translations]
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
}



private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(35)))
    sectionId += 1

    

    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("header"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        let status = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: state.premiumConfiguration.statusEntities)], for: state.premiumConfiguration.status, message: nil, context: arguments.context, fontSize: 13, openInfo: arguments.openInfo)
        return PremiumBoardingHeaderItem(initialSize, stableId: stableId, context: arguments.context, isPremium: state.isPremium, peer: state.peer?.peer, emojiStatus: state.status, source: state.source, premiumText: status, viewType: .legacy)
    }))
    index += 1
    
    
    
    if !state.periods.isEmpty, !state.isPremium {
        let period = state.period ?? state.periods[0]
                
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_id_periods"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
            return PremiumSelectPeriodRowItem(initialSize, stableId: stableId, context: arguments.context, periods: state.periods, selectedPeriod: period, viewType: .singleItem, callback: { period in
                arguments.togglePeriod(period)
            })
        }))
        index += 1

        entries.append(.sectionId(sectionId, type: .customModern(15)))
        sectionId += 1
    }
    
    for (i, value) in state.values.enumerated() {
        let viewType = bestGeneralViewType(state.values, for: i)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init(value.rawValue), equatable: InputDataEquatable(value), comparable: nil, item: { initialSize, stableId in
            return PremiumBoardingRowItem(initialSize, stableId: stableId, viewType: viewType, index: i, value: value, limits: arguments.context.premiumLimits, isLast: false, callback: arguments.openFeature)
        }))
        index += 1
    }
    
//    entries.append(.sectionId(sectionId, type: .customModern(15)))
//    sectionId += 1
   
//    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().premiumBoardingAboutTitle.uppercased()), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
//    index += 1
//
//
//    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("about"), equatable: nil, comparable: nil, item: { initialSize, stableId in
//        return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: strings().premiumBoardingAboutText, font: .normal(.text), insets: NSEdgeInsets(left: 20, right: 20))
//    }))
    
    
    if !state.isPremium {
        let status = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: state.premiumConfiguration.statusEntities)], for: state.premiumConfiguration.status, message: nil, context: arguments.context, fontSize: 11.5, openInfo: arguments.openInfo, textColor: theme.colors.listGrayText)

        entries.append(.desc(sectionId: sectionId, index: index, text: .attributed(status), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .customModern(15)))
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
        
        func update(animated: Bool, state: State) -> NSSize {
            
            let option = state.period
            guard let option = state.period else {
                return .zero
            }

            let text: String
            if state.canMakePayment {
                text = option.buyString
            } else {
                text = strings().premiumBoardingPaymentNotAvailalbe
            }
            
            let layout = TextViewLayout(.initialize(string: text, color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
                        
            container.setFrameSize(layout.layoutSize)
            
            let size = NSMakeSize(container.frame.width + 100, 40)
            

            needsLayout = true
            
            self.userInteractionEnabled = state.canMakePayment
            
            self.alphaValue = state.canMakePayment ? 1.0 : 0.7
            
            return size
        }
    }
    
    final class HeaderView: View {
        let dismiss = ImageButton()
        private let container = View()
        private let titleView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(container)
            addSubview(dismiss)
            
            dismiss.scaleOnClick = true
            dismiss.autohighlight = false
            
            dismiss.set(image: theme.icons.modalClose, for: .Normal)
            dismiss.sizeToFit()
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            titleView.isEventLess = true
            
            container.backgroundColor = theme.colors.background
            container.border = [.Bottom]

            let layout = TextViewLayout(.initialize(string: strings().premiumBoardingTitle, color: theme.colors.text, font: .medium(.header)))
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
    }

    
    private let headerView: HeaderView = HeaderView(frame: .zero)
    let tableView = TableView()
    private var bottomView: View?
    private let bottomBorder = View()
    private let acceptView = AcceptView(frame: .zero)
    
    private let containerView = View()
    private var fadeView: View?
    
    var dismiss:(()->Void)?
    var accept:(()->Void)?
    
    private var state: State?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(tableView)
        containerView.addSubview(headerView)
        addSubview(containerView)
        
        tableView.getBackgroundColor = {
            theme.colors.listBackground
        }
                
        bottomBorder.backgroundColor = theme.colors.border
        
        
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
            bottomView?.backgroundColor = theme.colors.listBackground
            if animated {
                bottomView?.layer?.animateBackground()
            }
        } else {
            bottomBorder.change(opacity: 1, animated: animated)
            bottomView?.backgroundColor = theme.colors.background
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
    
    func update(animated: Bool, arguments: Arguments, state: State) {
        let previousState = self.state
        self.state = state
        let size = acceptView.update(animated: animated, state: state)
        acceptView.setFrameSize(NSMakeSize(frame.width - 40, size.height))
        acceptView.layer?.cornerRadius = 10
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        
        if state.isPremium != previousState?.isPremium {
            if !state.isPremium {
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
        if let state = self.state, !state.isPremium {
            let acceptView = AcceptView(frame: .zero)
            let size = acceptView.update(animated: false, state: state)
            acceptView.setFrameSize(NSMakeSize(frame.width - 40, size.height))
            acceptView.layer?.cornerRadius = 10
            acceptView.set(handler: { [weak self] _ in
                self?.accept?()
            }, for: .Click)
            
            return acceptView
        } else {
            let okButton = TitleButton()
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
            
            gradient.colors = premiumGradient.compactMap { $0?.cgColor }
            
            okButton.layer?.insertSublayer(gradient, at: 0)
            
            okButton.set(handler: { [weak self] _ in
                self?.dismiss?()
            }, for: .Click)
            
            return okButton
        }
        
    }
    
    private var currentController: ViewController?
    
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
        fadeView.backgroundColor = theme.colors.blackTransparent
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
}

final class PremiumBoardingController : ModalViewController {

    private let context: AccountContext
    private let source: PremiumLogEventsSource
    private let openFeatures: Bool
    init(context: AccountContext, source: PremiumLogEventsSource = .settings, openFeatures: Bool = false) {
        self.context = context
        self.source = source
        self.openFeatures = openFeatures
        super.init(frame: NSMakeRect(0, 0, 380, 300))
    }
    
    override func measure(size: NSSize) {
        updateSize(false)
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: genericView.contentSize(maxSize: NSMakeSize(380, contentSize.height - 80)), animated: animated)
        }
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.openFeatures {
            if let value = PremiumValue(rawValue: self.source.value) {
                arguments?.openFeature(value)
            }
        }
    }
    
    private var arguments: Arguments?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let inAppPurchaseManager = context.inAppPurchaseManager
        
        let actionsDisposable = DisposableSet()
        let paymentDisposable = MetaDisposable()
        let activationDisposable = MetaDisposable()
        let context = self.context
        let source = self.source
        let openFeatures = self.openFeatures
        
        PremiumLogEvents.promo_screen_show(source).send(context: context)
        
        let close: ()->Void = {
            closeAllModals()
        }

        var canMakePayment: Bool = true
        #if APP_STORE || DEBUG
        canMakePayment = inAppPurchaseManager.canMakePayments()
        #endif
        
        let initialState = State(values: context.premiumOrder.premiumValues, source: source, isPremium: context.isPremium, premiumConfiguration: PremiumPromoConfiguration.defaultValue, stickers: [], canMakePayment: canMakePayment)
        
        let statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let arguments = Arguments(context: context, showTerms: {
            
        }, showPrivacy: {
            
        }, openInfo: { peerId, _, _, initialAction in
            var updated: ChatInitialAction? = initialAction
            switch initialAction {
            case let .start(parameter, _):
                updated = .start(parameter: parameter, behavior: .automatic)
            default:
                break
            }
            let controller = ChatController(context: context, chatLocation: .peer(peerId), initialAction: updated)
            context.bindings.rootNavigation().push(controller)
            
            close()
        }, openFeature: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.genericView.append(PremiumBoardingFeaturesController(context, value: value, stickers: stateValue.with { $0.stickers }, configuration: stateValue.with { $0.premiumConfiguration }, back: { [weak strongSelf] in
                _ = strongSelf?.escapeKeyAction()
            }, makeAcceptView: { [weak strongSelf] in
                return strongSelf?.genericView.makeAcceptView()
            }), animated: true)
        }, togglePeriod: { period in
            updateState { current in
                var current = current
                current.period = period
                return current
            }
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
                                            return (peer, PremiumEmojiStatusInfo(status: status, file: file, info: info, items: items))
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
        case let .gift(from, to, _):
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
                    result.append(mediaItem.media)
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

        
        let stateSignal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
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
            self?.updateSize(transition.0.animated)
            self?.readyOnce()
        }))
        
        
        
        let buyNonStore = {
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
                    paymentDisposable.set((inAppPurchaseManager.buyProduct(premiumProduct, account: context.account)
                    |> deliverOnMainQueue).start(next: { [weak lockModal] status in
        
                        lockModal?.close()
                        needToShow = false
        
                        if case let .purchased(transaction) = status {
                            let activate = showModalProgress(signal: context.engine.payments.sendAppStoreReceipt(receipt: InAppPurchaseManager.getReceiptData() ?? Data(), purpose: .subscription), for: context.window)
                            activationDisposable.set(activate.start(error: { _ in
                                showModalText(for: context.window, text: strings().errorAnError)
                                inAppPurchaseManager.finishAllTransactions()
                            }, completed: {
                                close()
                                inAppPurchaseManager.finishAllTransactions()
                                delay(0.2, closure: {
                                    PlayConfetti(for: context.window)
                                    showModalText(for: context.window, text: strings().premiumBoardingAppStoreSuccess)
                                    let _ = updatePremiumPromoConfigurationOnce(account: context.account).start()
                                })
                            }))
                        }
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
        genericView.accept = {
            
            addAppLogEvent(postbox: context.account.postbox, type: PremiumLogEvents.promo_screen_accept.value)
            
            #if APP_STORE || DEBUG
            buyAppStore()
            #else
            buyNonStore()
            #endif
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
    
    func restore() {
        if let receiptData = InAppPurchaseManager.getReceiptData() {
            let context = self.context
            _ = showModalProgress(signal: context.engine.payments.sendAppStoreReceipt(receipt: receiptData, purpose: .restore), for: context.window).start(error: { _ in
                showModalText(for: context.window, text: strings().premiumRestoreErrorUnknown)
            }, completed: {
                showModalText(for: context.window, text: strings().premiumRestoreSuccess)
            })
        }
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.stackBack(animated: true) {
            return .invoked
        } else {
            return super.escapeKeyAction()
        }
    }
}





