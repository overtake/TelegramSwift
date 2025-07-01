//
//  PremiumBoardingFeaturesController.swift
//  Telegram
//
//  Created by Mike Renoir on 03.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import AppKit
import TelegramCore
import SwiftSignalKit
import Postbox

final class PremiumBoardingFeaturesView: View {
    
    private let headerView = PremiumGradientView(frame: .zero)
    private let bottomView = View()
    var accept: Control?
    
    let dismiss = ImageButton()

    private var slideView = SliderView(frame: .zero)
    private let contentView = View()
    private var playbackDisposable: Disposable?
    private let presentation: TelegramPresentationTheme
    init(frame frameRect: NSRect, presentation: TelegramPresentationTheme) {
        self.presentation = presentation
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(bottomView)
        addSubview(contentView)
        contentView.addSubview(slideView)
        slideView.normalColor = presentation.colors.grayIcon.withAlphaComponent(0.8)
        slideView.highlightColor = NSColor(0x976FFF)
        slideView.moveOnTime = false
        
        //slideView.backgroundColor = presentation.colors.background
        
        addSubview(dismiss)
        
        dismiss.scaleOnClick = true
        dismiss.autohighlight = false
        
        dismiss.set(image: NSImage(named: "Icon_ChatNavigationBack")!.precomposed(.white), for: .Normal)
        dismiss.sizeToFit(NSMakeSize(20, 20), .zero, thatFit: false)
        
        
        layout()
    }
    
    deinit {
        playbackDisposable?.dispose()
    }
    
    func next() {
        slideView.next(animated: true)
    }
    func prev() {
        slideView.prev(animated: true)
    }
    
    override func layout() {
        super.layout()
        bottomView.frame = NSMakeRect(0, frame.height - 174, frame.width, 174)
        headerView.frame = NSMakeRect(0, 0, frame.width, frame.height - bottomView.frame.height)
        contentView.frame = NSMakeRect(0, 0, frame.width, frame.height - 60)
        slideView.frame = contentView.bounds
        
        if let accept = accept {
            accept.centerX(y: bottomView.frame.height - accept.frame.height - 10)
        }
        
        dismiss.setFrameOrigin(NSMakePoint(10, 10))
    }
    
    fileprivate func setAccept(_ control: Control?) {
        if let control = control {
            self.accept = control
            self.bottomView.addSubview(control)
            bottomView.backgroundColor = presentation.colors.background
        }
        needsLayout = true
    }
    
    func setup(context: AccountContext, presentation: TelegramPresentationTheme, value: PremiumValue, stickers: [TelegramMediaFile], configuration: PremiumPromoConfiguration) {
        
        let bounds = slideView.bounds

        
        let navigationGray: CGImage = NSImage(resource: .iconChatNavigationBack).precomposed(presentation.colors.grayIcon)
        let navigationWhite: CGImage = NSImage(resource: .iconChatNavigationBack).precomposed(.white)
        
        let stories = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        stories.setup(context: context, type: .stories, decoration: .none, getView: { _ in
            let view = PremiumBoardingExtraFeaturesView(frame: bounds, presentation: presentation)
            view.initialize(context: context, initialSize: bounds.size, list: PremiumBoardingExtraFeatureItem.stories, title: PremiumValue.stories.title(context.premiumLimits))
            return view
        })
        
        stories.appear = { [weak self] in
            self?.dismiss.set(image: navigationGray, for: .Normal)
        }
        stories.disappear = { [weak self] in
            self?.dismiss.set(image: navigationWhite, for: .Normal)
        }
        
        slideView.addSlide(stories)
        
        let business = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        business.setup(context: context, type: .business, decoration: .none, getView: { _ in
            let view = PremiumBoardingExtraFeaturesView(frame: bounds, presentation: presentation)
            view.initialize(context: context, initialSize: bounds.size, list: PremiumBoardingExtraFeatureItem.business, title: PremiumValue.business.title(context.premiumLimits))
            return view
        })
        
        business.appear = { [weak self] in
            self?.dismiss.set(image: navigationGray, for: .Normal)
        }
        business.disappear = { [weak self] in
            self?.dismiss.set(image: navigationWhite, for: .Normal)
        }
        
        slideView.addSlide(business)
 
        
        let double_limits = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        
        double_limits.appear = { [weak self] in
            self?.dismiss.set(image: navigationGray, for: .Normal)
        }
        double_limits.disappear = { [weak self] in
            self?.dismiss.set(image: navigationWhite, for: .Normal)
        }
        
        double_limits.setup(context: context, type: .double_limits, decoration: .none, getView: { _ in
            let view = PremiumBoardingDoubleView(frame: bounds, presentation: presentation)
            view.initialize(context: context, initialSize: bounds.size)
            return view
        })
        slideView.addSlide(double_limits)
        

                
        let more_upload = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        more_upload.setup(context: context, type: .more_upload, decoration: .dataRain, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.more_upload.rawValue], position: .bottom)
            return view
        })
        slideView.addSlide(more_upload)
        
        let faster_download = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        faster_download.setup(context: context, type: .faster_download, decoration: .fasterStars, getView: { [weak self] parentView in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.faster_download.rawValue], position: .top)
            if let status = view.status {
                self?.playbackDisposable = status.start(next: { [weak parentView] status in
                    if status.timestamp > 8.0 {
                        parentView?.decoration?.resetAnimation()
                    } else if status.timestamp > 0.85 {
                        parentView?.decoration?.startAnimation()
                    }

                })
            }
            return view
        })
        slideView.addSlide(faster_download)
        
        let voice_to_text = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        voice_to_text.setup(context: context, type: .voice_to_text, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.voice_to_text.rawValue], position: .top)
            return view
        })
        slideView.addSlide(voice_to_text)
        
        let no_ads = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        no_ads.setup(context: context, type: .no_ads, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.no_ads.rawValue], position: .bottom)
            return view
        })
        slideView.addSlide(no_ads)
        
        let unique_reactions = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        unique_reactions.setup(context: context, type: .infinite_reactions, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.infinite_reactions.rawValue], position: .top)
            return view
        })
        slideView.addSlide(unique_reactions)
        
        let statuses = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        statuses.setup(context: context, type: .emoji_status, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.emoji_status.rawValue], position: .top)
            return view
        })
        slideView.addSlide(statuses)
        
        let premium_stickers = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        
        
        premium_stickers.setup(context: context, type: .premium_stickers, decoration: .none, getView: { _ in
            let view = StickersCarouselView(context: context, stickers: Array(stickers.prefix(15)))
            return view
        })
        slideView.addSlide(premium_stickers)
        
        let animated_emoji = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        animated_emoji.setup(context: context, type: .animated_emoji, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.animated_emoji.rawValue], position: .bottom)
            return view
        })
        slideView.addSlide(animated_emoji)
        
        let advanced_chat_management = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        advanced_chat_management.setup(context: context, type: .advanced_chat_management, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.advanced_chat_management.rawValue], position: .top)
            return view
        })
        slideView.addSlide(advanced_chat_management)
        
        let profile_badge = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        profile_badge.setup(context: context, type: .profile_badge, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.profile_badge.rawValue], position: .top)
            return view
        })
        slideView.addSlide(profile_badge)
        
        let animated_userpics = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        animated_userpics.setup(context: context, type: .animated_userpics, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.animated_userpics.rawValue], position: .top)
            return view
        })
        slideView.addSlide(animated_userpics)
        
        
        let translations = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        translations.setup(context: context, type: .translations, decoration: .hello, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.translations.rawValue], position: .top)
            return view
        })
        slideView.addSlide(translations)
        
        let peer_colors = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        peer_colors.setup(context: context, type: .peer_colors, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.peer_colors.rawValue], position: .top)
            return view
        })
        slideView.addSlide(peer_colors)
        
        let wallpapers = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        wallpapers.setup(context: context, type: .wallpapers, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.wallpapers.rawValue], position: .top)
            return view
        })
        slideView.addSlide(wallpapers)
        
        let savedTags = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        savedTags.setup(context: context, type: .saved_tags, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.saved_tags.rawValue], position: .top)
            return view
        })
        slideView.addSlide(savedTags)
        
        let lastSeen = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        lastSeen.setup(context: context, type: .last_seen, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.last_seen.rawValue], position: .top)
            return view
        })
        slideView.addSlide(lastSeen)
        
        let messagesPrivacy = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        messagesPrivacy.setup(context: context, type: .message_privacy, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.message_privacy.rawValue], position: .top)
            return view
        })
        slideView.addSlide(messagesPrivacy)
        
        let folderTags = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        folderTags.setup(context: context, type: .folder_tags, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.folder_tags.rawValue], position: .top)
            return view
        })
        slideView.addSlide(folderTags)
        
        let business_location = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        business_location.setup(context: context, type: .business_location, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.business_location.rawValue], position: .top)
            return view
        })
        slideView.addSlide(business_location)
        
        let business_hours = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        business_hours.setup(context: context, type: .business_hours, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.business_hours.rawValue], position: .top)
            return view
        })
        slideView.addSlide(business_hours)
        
  
        
        let quick_replies = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        quick_replies.setup(context: context, type: .quick_replies, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.quick_replies.rawValue], position: .top)
            return view
        })
        slideView.addSlide(quick_replies)
        
        let greeting_message = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        greeting_message.setup(context: context, type: .greeting_message, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.greeting_message.rawValue], position: .top)
            return view
        })
        slideView.addSlide(greeting_message)
        
        
        let away_message = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        away_message.setup(context: context, type: .away_message, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.away_message.rawValue], position: .top)
            return view
        })
        slideView.addSlide(away_message)
        
        let business_bots = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        business_bots.setup(context: context, type: .business_bots, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.business_bots.rawValue], position: .top)
            return view
        })
        slideView.addSlide(business_bots)
        
        let business_intro = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        business_intro.setup(context: context, type: .business_intro, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.business_intro.rawValue], position: .top)
            return view
        })
        slideView.addSlide(business_intro)
        
        let business_links = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        business_links.setup(context: context, type: .business_links, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.business_links.rawValue], position: .top)
            return view
        })
        slideView.addSlide(business_links)
        
        let todo = PremiumFeatureSlideView(frame: slideView.bounds, presentation: presentation)
        todo.setup(context: context, type: .todo, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.todo.rawValue], position: .top)
            return view
        })
        slideView.addSlide(todo)
        
        switch value {
        case .stories:
            slideView.displaySlide(at: 0, animated: false)
        case .business:
            slideView.displaySlide(at: 1, animated: false)
        case .double_limits:
            slideView.displaySlide(at: 2, animated: false)
        case .more_upload:
            slideView.displaySlide(at: 3, animated: false)
        case .faster_download:
            slideView.displaySlide(at: 4, animated: false)
        case .voice_to_text:
            slideView.displaySlide(at: 5, animated: false)
        case .no_ads:
            slideView.displaySlide(at: 6, animated: false)
        case .infinite_reactions:
            slideView.displaySlide(at: 7, animated: false)
        case .emoji_status:
            slideView.displaySlide(at: 8, animated: false)
        case .premium_stickers:
            slideView.displaySlide(at: 9, animated: false)
        case .animated_emoji:
            slideView.displaySlide(at: 10, animated: false)
        case .advanced_chat_management:
            slideView.displaySlide(at: 11, animated: false)
        case .profile_badge:
            slideView.displaySlide(at: 12, animated: false)
        case .animated_userpics:
            slideView.displaySlide(at: 13, animated: false)
        case .translations:
            slideView.displaySlide(at: 14, animated: false)
        case .peer_colors:
            slideView.displaySlide(at: 15, animated: false)
        case .wallpapers:
            slideView.displaySlide(at: 16, animated: false)
        case .saved_tags:
            slideView.displaySlide(at: 17, animated: false)
        case .last_seen:
            slideView.displaySlide(at: 18, animated: false)
        case .message_privacy:
            slideView.displaySlide(at: 19, animated: false)
        case .folder_tags:
            slideView.displaySlide(at: 20, animated: false)
        case .business_location:
            slideView.displaySlide(at: 21, animated: false)
        case .business_hours:
            slideView.displaySlide(at: 22, animated: false)
        case .quick_replies:
            slideView.displaySlide(at: 23, animated: false)
        case .greeting_message:
            slideView.displaySlide(at: 24, animated: false)
        case .away_message:
            slideView.displaySlide(at: 25, animated: false)
        case .business_bots:
            slideView.displaySlide(at: 26, animated: false)
        case .business_intro:
            slideView.displaySlide(at: 27, animated: false)
        case .business_links:
            slideView.displaySlide(at: 28, animated: false)
        case .todo:
            slideView.displaySlide(at: 29, animated: false)

        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

final class PremiumBoardingFeaturesController : TelegramGenericViewController<PremiumBoardingFeaturesView> {
    private let back:()->Void
    private let makeAcceptView:()->Control?
    private let configuration: PremiumPromoConfiguration
    private let value: PremiumValue
    private let stickers: [TelegramMediaFile]
    private let presentation: TelegramPresentationTheme
    init(_ context: AccountContext, presentation: TelegramPresentationTheme, value: PremiumValue, stickers: [TelegramMediaFile], configuration: PremiumPromoConfiguration, back: @escaping()->Void, makeAcceptView: @escaping()->Control?) {
        self.back = back
        self.presentation = presentation
        self.value = value
        self.stickers = stickers
        self.makeAcceptView = makeAcceptView
        self.configuration = configuration
        super.init(context)
        bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        
        
        self.genericView.setup(context: context, presentation: presentation, value: value, stickers: stickers, configuration: configuration)

        genericView.dismiss.set(handler: { [weak self] _ in
            self?.back()
        }, for: .Click)
        
        genericView.setAccept(self.makeAcceptView())
        
        self.readyOnce()
    }
    
    override func initializer() -> PremiumBoardingFeaturesView {
        return .init(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), presentation: presentation)
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
}
