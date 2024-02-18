//
//  PremiumBoardingStoriesController.swift
//  Telegram
//
//  Created by Mike Renoir on 27.07.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class PremiumBoardingStoryRowItem : GeneralRowItem {
    let title: TextViewLayout
    let info: TextViewLayout
    let itemType: PremiumBoardingExtraFeatureItem
    let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, type: PremiumBoardingExtraFeatureItem, presentation: TelegramPresentationTheme) {
        self.itemType = type
        self.presentation = presentation
        self.title = .init(.initialize(string: type.title, color: presentation.colors.text, font: .medium(.title)))
        
        
        let info = NSMutableAttributedString()
        _ = info.append(string: type.info, color: presentation.colors.grayText, font: .normal(.text))
        info.detectLinks(type: .Links)
        self.info = .init(info)

        super.init(initialSize, stableId: arc4random64())
        _ = makeSize(initialSize.width)
    }
    
    override var height: CGFloat {
        return title.layoutSize.height + 4 + info.layoutSize.height + 8
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        title.measure(width: width - 100)
        info.measure(width: width - 100)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return PremiumBoardingStoriesRowView.self
    }
    
}

private final class PremiumBoardingStoriesRowView : TableRowView {
    


    private let titleView = TextView()
    private let infoView = TextView()
    private let imageView = ImageView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(infoView)
        addSubview(imageView)
        titleView.userInteractionEnabled = false
        infoView.userInteractionEnabled = false
        
        titleView.isSelectable = false
        infoView.isSelectable = false
        
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? PremiumBoardingStoryRowItem else {
            return super.backdorColor
        }
        return item.presentation.colors.background
    }
    
    override func layout() {
        super.layout()
        imageView.setFrameOrigin(NSMakePoint(20, 0))

        titleView.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 10, 0))
        infoView.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 10, titleView.frame.maxY + 4))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PremiumBoardingStoryRowItem else {
            return
        }
        titleView.update(item.title)
        infoView.update(item.info)
        
        imageView.image = item.itemType.image
        imageView.sizeToFit()
        
        needsLayout = true

    }
}




enum PremiumBoardingExtraFeatureItem {
    case priority
    case stealth
    case permanentViews
    case expiratationDuration
    case saveToGallery
    case longerCaption
    case linksAndFormating
    case highQuality
    
    case business_location
    case business_hours
    case business_quick_replies
    case business_greeting_messages
    case business_away_messages
    case business_chatbots
    
    
    static var stories: [PremiumBoardingExtraFeatureItem] {
        return [.priority,
                .stealth,
                .highQuality,
                .permanentViews,
                .expiratationDuration,
                .saveToGallery,
                .longerCaption,
                .linksAndFormating]
    }
    
    static var business: [PremiumBoardingExtraFeatureItem] {
        return [.business_location,
                .business_hours,
                .business_quick_replies,
                .business_greeting_messages,
                .business_away_messages]
    }
    
    
    
    var title: String {
        switch self {
        case .priority:
            return strings().premiumBoardingStoriesPriorityOrderTitle
        case .stealth:
            return strings().premiumBoardingStoriesStealthModeTitle
        case .permanentViews:
            return strings().premiumBoardingStoriesPermanentHistoryViewTitle
        case .expiratationDuration:
            return strings().premiumBoardingStoriesExpirationDurationTitle
        case .saveToGallery:
            return strings().premiumBoardingStoriesSaveToGalleryTitle
        case .longerCaption:
            return strings().premiumBoardingStoriesLongerCaptionTitle
        case .linksAndFormating:
            return strings().premiumBoardingStoriesLinkFormattingTitle
        case .highQuality:
            return strings().premiumBoardingStoriesHighQualityTitle
        case .business_location:
            //TODOLANG
            return "Location"
        case .business_hours:
            return "Opening Hours"
        case .business_quick_replies:
            return "Quick Replies"
        case .business_greeting_messages:
            return "Greeting Messages"
        case .business_away_messages:
            return "Away Messages"
        case .business_chatbots:
            return "ChatBots"
        }
    }
    var info: String {
        switch self {
        case .priority:
            return strings().premiumBoardingStoriesPriorityOrderInfo
        case .stealth:
            return strings().premiumBoardingStoriesStealthModeInfo
        case .permanentViews:
            return strings().premiumBoardingStoriesPermanentHistoryViewInfo
        case .expiratationDuration:
            return strings().premiumBoardingStoriesExpirationDurationInfo
        case .saveToGallery:
            return strings().premiumBoardingStoriesSaveToGalleryInfo
        case .longerCaption:
            return strings().premiumBoardingStoriesLongerCaptionInfo
        case .linksAndFormating:
            return strings().premiumBoardingStoriesLinkFormattingInfo
        case .highQuality:
            return strings().premiumBoardingStoriesHighQualityInfo
        case .business_location:
            //TODOLANG
            return "Display the location of your business on your account."
        case .business_hours:
            return "Show to your customers when you are open for business."
        case .business_quick_replies:
            return "Set up shortcuts with rich text and media to respond to messages faster."
        case .business_greeting_messages:
            return "Create greetings that will be automatically sent to new customers."
        case .business_away_messages:
            return "Define messages that are automatically sent when you are off."
        case .business_chatbots:
            return "Add any third party chatbots that will process customer interactions."
        }
    }
    
    var color: NSColor {
        return .random
    }
    var image: CGImage {
        switch self {
        case .priority:
            return NSImage(resource: .iconPremiumBoardingPriorityOrder).precomposed()
        case .stealth:
            return NSImage(resource: .iconPremiumBoardingStealthMode).precomposed()
        case .permanentViews:
            return NSImage(resource: .iconPremiumBoardingPermanentViewsHistory).precomposed()
        case .expiratationDuration:
            return NSImage(resource: .iconPremiumBoardingExpirationDurations).precomposed()
        case .saveToGallery:
            return NSImage(resource: .iconPremiumBoardingSaveStoriesToGallery).precomposed()
        case .longerCaption:
            return NSImage(resource: .iconPremiumBoardingLongerCaptions).precomposed()
        case .linksAndFormating:
            return NSImage(resource: .iconPremiumBoardingLinksAndFormatting).precomposed()
        case .highQuality:
            return NSImage(resource: .iconPremiumBoardingHighQuality).precomposed(NSColor(0x9A64EE))
        case .business_location:
            return NSImage(resource: .iconPremiumBusinessFeatureLocation).precomposed()
        case .business_hours:
            return NSImage(resource: .iconPremiumBusinessFeatureHours).precomposed()
        case .business_quick_replies:
            return NSImage(resource: .iconPremiumBusinessFeatureReply).precomposed()
        case .business_greeting_messages:
            return NSImage(resource: .iconPremiumBusinessFeatureGreeting).precomposed()
        case .business_away_messages:
            return NSImage(resource: .iconPremiumBusinessFeatureAway).precomposed()
        case .business_chatbots:
            return NSImage(resource: .iconPremiumBusinessFeatureBot).precomposed()
        }
    }
}

final class PremiumBoardingExtraFeaturesView: View, PremiumSlideView {
    
    final class HeaderView: View {
        private let container = View()
        private let titleView = TextView()
        private let presentation: TelegramPresentationTheme
        init(frame frameRect: NSRect, presentation: TelegramPresentationTheme) {
            self.presentation = presentation
            super.init(frame: frameRect)
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            titleView.isEventLess = true
            
            container.backgroundColor = presentation.colors.background
            container.border = [.Bottom]
            container.borderColor = presentation.colors.border
            container.isEventLess = true

            let layout = TextViewLayout(.initialize(string: strings().premiumBoardingStoriesTitle, color: presentation.colors.text, font: .medium(.header)))
            layout.measure(width: 300)
            
            titleView.update(layout)
            container.addSubview(titleView)
            
            addSubview(container)

        }
        
        func set(string: String) {
            let layout = TextViewLayout(.initialize(string: string, color: presentation.colors.text, font: .medium(.header)))
            layout.measure(width: 300)
            
            titleView.update(layout)
        }
        
        
        override func layout() {
            super.layout()
            container.frame = bounds
            titleView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        required init(frame frameRect: NSRect) {
            fatalError("init(frame:) has not been implemented")
        }
    }
    


    let headerView: HeaderView
    let bottomBorder = View(frame: .zero)
    
    let tableView: TableView = TableView()
    let presentation: TelegramPresentationTheme
    required init(frame frameRect: NSRect, presentation: TelegramPresentationTheme) {
        self.presentation = presentation
        self.headerView = HeaderView(frame: .zero, presentation: presentation)
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(headerView)
        
        tableView.getBackgroundColor = {
            presentation.colors.background
        }
        
        addSubview(bottomBorder)
        bottomBorder.backgroundColor = presentation.colors.border
        
    }
    
    override func layout() {
        super.layout()
        headerView.frame = NSMakeRect(0, 0, frame.width, 50)
                
        tableView.frame = NSMakeRect(0, headerView.frame.height, frame.width, frame.height - headerView.frame.height)
        self.bottomBorder.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    func initialize(context: AccountContext, initialSize: NSSize, list: [PremiumBoardingExtraFeatureItem], title: String) {
        
        self.headerView.set(string: title)
        
        _ = self.tableView.addItem(item: GeneralRowItem(initialSize, height: 15, backgroundColor: presentation.colors.background))
        
        for type in list {
            let item = PremiumBoardingStoryRowItem(initialSize, type: type, presentation: presentation)
            _ = self.tableView.addItem(item: item)
            _ = self.tableView.addItem(item: GeneralRowItem(initialSize, height: 15, backgroundColor: presentation.colors.background))
        }
        
    }
    
    func willAppear() {
        
    }
    func willDisappear() {
        
    }
}
