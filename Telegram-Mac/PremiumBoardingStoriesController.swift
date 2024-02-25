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
    let itemType: PremiumBoardingStoriesItem
    let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, type: PremiumBoardingStoriesItem, presentation: TelegramPresentationTheme) {
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




enum PremiumBoardingStoriesItem {
    case priority
    case stealth
    case permanentViews
    case expiratationDuration
    case saveToGallery
    case longerCaption
    case linksAndFormating
    case highQuality
    static var all: [PremiumBoardingStoriesItem] {
        return [.priority,
                .stealth,
                .highQuality,
                .permanentViews,
                .expiratationDuration,
                .saveToGallery,
                .longerCaption,
                .linksAndFormating]
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
        }
    }
    
    var color: NSColor {
        return .random
    }
    var image: CGImage? {
        switch self {
        case .priority:
            return NSImage(named: "Icon_PremiumBoarding_PriorityOrder")?.precomposed()
        case .stealth:
            return NSImage(named: "Icon_PremiumBoarding_StealthMode")?.precomposed()
        case .permanentViews:
            return NSImage(named: "Icon_PremiumBoarding_PermanentViewsHistory")?.precomposed()
        case .expiratationDuration:
            return NSImage(named: "Icon_PremiumBoarding_ExpirationDurations")?.precomposed()
        case .saveToGallery:
            return NSImage(named: "Icon_PremiumBoarding_SaveStoriesToGallery")?.precomposed()
        case .longerCaption:
            return NSImage(named: "Icon_PremiumBoarding_LongerCaptions")?.precomposed()
        case .linksAndFormating:
            return NSImage(named: "Icon_PremiumBoarding_LinksAndFormatting")?.precomposed()
        case .highQuality:
            return NSImage(named: "Icon_PremiumBoarding_HighQuality")?.precomposed(NSColor(0x9A64EE))
        }
    }
}

final class PremiumBoardingStoriesView: View, PremiumSlideView {
    
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
    
    
    func initialize(context: AccountContext, initialSize: NSSize) {
        _ = self.tableView.addItem(item: GeneralRowItem(initialSize, height: 15, backgroundColor: presentation.colors.background))
        
        for type in PremiumBoardingStoriesItem.all {
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
