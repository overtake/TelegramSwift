//
//  ChannelStatsSegmentController.swift
//  Telegram
//
//  Created by Mike Renoir on 03.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit

private final class CenterView : TitledBarView {
    let segment: CatalinaStyledSegmentController
    var select:((Int)->Void)? = nil
    init(controller: ViewController, monetization: Bool, stars: Bool) {
        self.segment = CatalinaStyledSegmentController(frame: NSMakeRect(0, 0, 240, 30))
        super.init(controller: controller)
        
        segment.add(segment: .init(title: strings().statsStatistics, handler: { [weak self] in
            self?.select?(0)
        }))
        
        segment.add(segment: .init(title: strings().statsBoosts, handler: { [weak self] in
            self?.select?(1)
        }))
        if monetization {
            segment.add(segment: .init(title: strings().statsMonetization, handler: { [weak self] in
                self?.select?(2)
            }))
        }
        
        if stars {
            segment.add(segment: .init(title: strings().statsStars, handler: { [weak self] in
                self?.select?(3)
            }))
        }
        
        self.addSubview(segment.view)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        segment.theme = CatalinaSegmentTheme(backgroundColor: theme.colors.listBackground, foregroundColor: theme.colors.background, activeTextColor: theme.colors.text, inactiveTextColor: theme.colors.listGrayText)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        segment.view.frame = focus(NSMakeSize(min(frame.width - 40, 600), 30))
    }
}

final class ChannelStatsSegmentController : SectionViewController {
    private let stats: ViewController
    private let boosts: ViewController
    private let monetization: ViewController?
    private let stars: ViewController?
    private let context: AccountContext
    private let peerId: PeerId
    init(_ context: AccountContext, peerId: PeerId, isChannel: Bool, monetization: Bool = false, stars: Bool = false) {
        self.context = context
        self.peerId = peerId
        if isChannel {
            self.stats = ChannelStatsViewController(context, peerId: peerId)
            if monetization {
                self.monetization = FragmentMonetizationController(context: context, peerId: peerId)
            } else {
                self.monetization = nil
            }
            if stars {
                self.stars = FragmentStarMonetizationController(context: context, peerId: peerId, revenueContext: nil)
            } else {
                self.stars = nil
            }
        } else {
            self.stats = GroupStatsViewController(context, peerId: peerId)
            self.monetization = nil
            self.stars = nil
        }
        self.boosts = ChannelBoostStatsController(context: context, peerId: peerId)

        var items:[SectionControllerItem] = []
        items.append(SectionControllerItem(title: { "" }, controller: stats))
        items.append(SectionControllerItem(title: { "" }, controller: boosts))

        if let monetization = self.monetization {
            items.append(SectionControllerItem(title: { "" }, controller: monetization))
        }
        if let stars = self.stars {
            items.append(SectionControllerItem(title: { "" }, controller: stars))
        }
        super.init(sections: items, selected: 0, hasHeaderView: false, hasBar: true)

    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return CenterView(controller: self, monetization: self.monetization != nil, stars: self.stars != nil)
    }
    
    override func getRightBarViewOnce() -> BarView {
        return BarView(80, controller: self)
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override var supportSwipes: Bool {
        return self.selectedIndex == 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centerView.select = { [weak self] index in
            self?.select(index, true)
        }
        
        self.selectionUpdateHandler = { [weak self] index in
            self?.centerView.segment.set(selected: index, animated: true)
        }
    }
    
    private var centerView: CenterView {
        return self.centerBarView as! CenterView
    }
}
