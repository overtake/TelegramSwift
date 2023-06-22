//
//  PremiumBoardingDoubleController.swift
//  Telegram
//
//  Created by Mike Renoir on 03.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

enum PremiumBoardingDoubleItem {
    case channels
    case pinnedChats
    case publicLinks
    case savedGifs
    case favoriteStickers
    case bio
    case captions
    case folders
    case chatsInFolder
    case accounts
    
    static var all: [PremiumBoardingDoubleItem] {
        return [.channels,
                .pinnedChats,
                .publicLinks,
                .savedGifs,
                .favoriteStickers,
                .bio,
                .captions,
                .folders,
                .chatsInFolder,
                .accounts]
    }
    
    func title(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .channels:
            return strings().premiumBoardingDoubleGroupsAndChannels
        case .pinnedChats:
            return strings().premiumBoardingDoublePinnedChats
        case .publicLinks:
            return strings().premiumBoardingDoublePublicLinks
        case .savedGifs:
            return strings().premiumBoardingDoubleSavedGifs
        case .favoriteStickers:
            return strings().premiumBoardingDoubleFavedStickers
        case .bio:
            return strings().premiumBoardingDoubleBio
        case .captions:
            return strings().premiumBoardingDoubleCaptions
        case .folders:
            return strings().premiumBoardingDoubleFolders
        case .chatsInFolder:
            return strings().premiumBoardingDoubleChatsPerFolder
        case .accounts:
            return strings().premiumBoardingDoubleAccounts
        }
    }
    func info(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .channels:
            return strings().premiumBoardingDoubleGroupsAndChannelsInfo("\(limits.channels_limit_premium)")
        case .pinnedChats:
            return strings().premiumBoardingDoublePinnedChatsInfo("\(limits.dialog_pinned_limit_premium)")
        case .publicLinks:
            return strings().premiumBoardingDoublePublicLinksInfo("\(limits.channels_public_limit_premium)")
        case .savedGifs:
            return strings().premiumBoardingDoubleSavedGifsInfo("\(limits.saved_gifs_limit_premium)")
        case .favoriteStickers:
            return strings().premiumBoardingDoubleFavedStickersInfo("\(limits.stickers_faved_limit_premium)")
        case .bio:
            return strings().premiumBoardingDoubleBioInfo
        case .captions:
            return strings().premiumBoardingDoubleCaptionsInfo
        case .folders:
            return strings().premiumBoardingDoubleFoldersInfo("\(limits.dialog_filters_limit_premium)")
        case .chatsInFolder:
            return strings().premiumBoardingDoubleChatsPerFolderInfo("\(limits.dialog_filters_chats_limit_premium)")
        case .accounts:
            return strings().premiumBoardingDoubleAccountsInfo("\(4)")
        }
    }
    
    var color: NSColor {
        switch self {
        case .channels:
            return NSColor(rgb: 0x5ba0ff)
        case .pinnedChats:
            return NSColor(rgb: 0x798aff)
        case .publicLinks:
            return NSColor(rgb: 0x9377ff)
        case .savedGifs:
            return NSColor(rgb: 0xac64f3)
        case .favoriteStickers:
            return NSColor(rgb: 0xc456ae)
        case .bio:
            return NSColor(rgb: 0xcf579a)
        case .captions:
            return NSColor(rgb: 0xdb5887)
        case .folders:
            return NSColor(rgb: 0xdb496f)
        case .chatsInFolder:
            return NSColor(rgb: 0xe95d44)
        case .accounts:
            return NSColor(rgb: 0xf2822a)
        }
    }
    func defaultLimit(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .channels:
            return "\(limits.channels_limit_default)"
        case .pinnedChats:
            return "\(limits.dialog_pinned_limit_default)"
        case .publicLinks:
            return "\(limits.channels_public_limit_default)"
        case .savedGifs:
            return "\(limits.saved_gifs_limit_default)"
        case .favoriteStickers:
            return "\(limits.stickers_faved_limit_default)"
        case .bio:
            return "\(limits.about_length_limit_default)"
        case .captions:
            return "\(limits.caption_length_limit_default)"
        case .folders:
            return "\(limits.dialog_filters_limit_default)"
        case .chatsInFolder:
            return "\(limits.dialog_filters_chats_limit_default)"
        case .accounts:
            return "\(normalAccountsLimit)"
        }
    }
    func premiumLimit(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .channels:
            return "\(limits.channels_limit_premium)"
        case .pinnedChats:
            return "\(limits.dialog_pinned_limit_premium)"
        case .publicLinks:
            return "\(limits.channels_public_limit_premium)"
        case .savedGifs:
            return "\(limits.saved_gifs_limit_premium)"
        case .favoriteStickers:
            return "\(limits.stickers_faved_limit_premium)"
        case .bio:
            return "\(limits.about_length_limit_premium)"
        case .captions:
            return "\(limits.caption_length_limit_premium)"
        case .folders:
            return "\(limits.dialog_filters_limit_premium)"
        case .chatsInFolder:
            return "\(limits.dialog_filters_chats_limit_premium)"
        case .accounts:
            return "\(normalAccountsLimit + 1)"
        }
    }
}

final class PremiumBoardingDoubleView: View, PremiumSlideView {
    
    final class HeaderView: View {
        private let container = View()
        private let titleView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)            
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            titleView.isEventLess = true
            
            container.backgroundColor = theme.colors.background
            container.border = [.Bottom]
            container.isEventLess = true

            let layout = TextViewLayout(.initialize(string: strings().premiumBoardingDoubleTitle, color: theme.colors.text, font: .medium(.header)))
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
    }
    


    let headerView = HeaderView(frame: .zero)
    let bottomBorder = View(frame: .zero)
    
    let tableView: TableView = TableView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(headerView)
        
        addSubview(bottomBorder)
        bottomBorder.backgroundColor = theme.colors.border
        
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
    
    
    func initialize(context: AccountContext, initialSize: NSSize) {
        _ = self.tableView.addItem(item: GeneralRowItem(initialSize, height: 15))
        
        for type in PremiumBoardingDoubleItem.all {
            let item = PremiumBoardingDoubleRowItem(initialSize, limits: context.premiumLimits, type: type)
            _ = self.tableView.addItem(item: item)
            _ = self.tableView.addItem(item: GeneralRowItem(initialSize, height: 15))
        }
        
    }
    
    func willAppear() {
        
    }
    func willDisappear() {
        
    }
}
//
//final class PremiumBoardingDoubleController : TelegramGenericViewController<PremiumBoardingDoubleView> {
//    private let back:()->Void
//    private let makeAcceptView:()->Control?
//    init(_ context: AccountContext, back:@escaping()->Void, makeAcceptView: @escaping()->Control?) {
//        self.back = back
//        self.makeAcceptView = makeAcceptView
//        super.init(context)
//        bar = .init(height: 0)
//    }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        let initialSize = self.frame.size
//
//        _ = genericView.tableView.addItem(item: GeneralRowItem(initialSize, height: 15))
//
//        for type in PremiumBoardingDoubleItem.all {
//            let item = PremiumBoardingDoubleRowItem(initialSize, limits: context.premiumLimits, type: type)
//            _ = genericView.tableView.addItem(item: item)
//            _ = genericView.tableView.addItem(item: GeneralRowItem(initialSize, height: 15))
//        }
//        genericView.headerView.dismiss.set(handler: { [weak self] _ in
//            self?.back()
//        }, for: .Click)
//
//        genericView.setAccept(self.makeAcceptView())
//        genericView.updateScroll(genericView.tableView.scrollPosition().current, animated: false)
//
//        readyOnce()
//    }
//
//    deinit {
//        var bp = 0
//        bp += 1
//    }
//}
