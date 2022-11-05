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
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(bottomView)
        addSubview(contentView)
        contentView.addSubview(slideView)
        slideView.normalColor = theme.colors.grayIcon.withAlphaComponent(0.8)
        slideView.highlightColor = NSColor(0x976FFF)
        slideView.moveOnTime = false
        
        
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
        }
        needsLayout = true
    }
    
    func setup(context: AccountContext, value: PremiumValue, stickers: [TelegramMediaFile], configuration: PremiumPromoConfiguration) {
        let more_upload = PremiumFeatureSlideView(frame: slideView.bounds)
        more_upload.setup(context: context, type: .more_upload, decoration: .dataRain, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.more_upload.rawValue], position: .bottom)
            return view
        })
        slideView.addSlide(more_upload)
        
        let faster_download = PremiumFeatureSlideView(frame: slideView.bounds)
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
        
        let voice_to_text = PremiumFeatureSlideView(frame: slideView.bounds)
        voice_to_text.setup(context: context, type: .voice_to_text, decoration: .swirlStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.voice_to_text.rawValue], position: .top)
            return view
        })
        slideView.addSlide(voice_to_text)
        
        let no_ads = PremiumFeatureSlideView(frame: slideView.bounds)
        no_ads.setup(context: context, type: .no_ads, decoration: .swirlStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.no_ads.rawValue], position: .bottom)
            return view
        })
        slideView.addSlide(no_ads)
        
        let unique_reactions = PremiumFeatureSlideView(frame: slideView.bounds)
        unique_reactions.setup(context: context, type: .infinite_reactions, decoration: .none, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.infinite_reactions.rawValue], position: .top)
            return view
        })
        slideView.addSlide(unique_reactions)
        
        let statuses = PremiumFeatureSlideView(frame: slideView.bounds)
        statuses.setup(context: context, type: .emoji_status, decoration: .none, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.emoji_status.rawValue], position: .top)
            return view
        })
        slideView.addSlide(statuses)
        
        let premium_stickers = PremiumFeatureSlideView(frame: slideView.bounds)
        
        
        premium_stickers.setup(context: context, type: .premium_stickers, decoration: .none, getView: { _ in
            let view = StickersCarouselView(context: context, stickers: Array(stickers.prefix(15)))
            return view
        })
        slideView.addSlide(premium_stickers)
        
        let animated_emoji = PremiumFeatureSlideView(frame: slideView.bounds)
        animated_emoji.setup(context: context, type: .animated_emoji, decoration: .swirlStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.animated_emoji.rawValue], position: .bottom)
            return view
        })
        slideView.addSlide(animated_emoji)
        
        let advanced_chat_management = PremiumFeatureSlideView(frame: slideView.bounds)
        advanced_chat_management.setup(context: context, type: .advanced_chat_management, decoration: .swirlStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.advanced_chat_management.rawValue], position: .top)
            return view
        })
        slideView.addSlide(advanced_chat_management)
        
        let profile_badge = PremiumFeatureSlideView(frame: slideView.bounds)
        profile_badge.setup(context: context, type: .profile_badge, decoration: .badgeStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.profile_badge.rawValue], position: .top)
            return view
        })
        slideView.addSlide(profile_badge)
        
        let animated_userpics = PremiumFeatureSlideView(frame: slideView.bounds)
        animated_userpics.setup(context: context, type: .animated_userpics, decoration: .swirlStars, getView: { _ in
            let view = PremiumDemoLegacyPhoneView(frame: .zero)
            view.setup(context: context, video: configuration.videos[PremiumValue.animated_userpics.rawValue], position: .top)
            return view
        })
        slideView.addSlide(animated_userpics)
        
        switch value {
        case .more_upload:
            slideView.displaySlide(at: 0, animated: false)
        case .faster_download:
            slideView.displaySlide(at: 1, animated: false)
        case .voice_to_text:
            slideView.displaySlide(at: 2, animated: false)
        case .no_ads:
            slideView.displaySlide(at: 3, animated: false)
        case .infinite_reactions:
            slideView.displaySlide(at: 4, animated: false)
        case .emoji_status:
            slideView.displaySlide(at: 5, animated: false)
        case .premium_stickers:
            slideView.displaySlide(at: 6, animated: false)
        case .animated_emoji:
            slideView.displaySlide(at: 7, animated: false)
        case .advanced_chat_management:
            slideView.displaySlide(at: 8, animated: false)
        case .profile_badge:
            slideView.displaySlide(at: 9, animated: false)
        case .animated_userpics:
            slideView.displaySlide(at: 10, animated: false)
        default:
            break
        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PremiumBoardingFeaturesController : TelegramGenericViewController<PremiumBoardingFeaturesView> {
    private let back:()->Void
    private let makeAcceptView:()->Control?
    private let configuration: PremiumPromoConfiguration
    private let value: PremiumValue
    private let stickers: [TelegramMediaFile]
    init(_ context: AccountContext, value: PremiumValue, stickers: [TelegramMediaFile], configuration: PremiumPromoConfiguration, back: @escaping()->Void, makeAcceptView: @escaping()->Control?) {
        self.back = back
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
        
        
        self.genericView.setup(context: context, value: value, stickers: stickers, configuration: configuration)

        genericView.dismiss.set(handler: { [weak self] _ in
            self?.back()
        }, for: .Click)
        
        genericView.setAccept(self.makeAcceptView())
        
        self.readyOnce()

        
    }
}
