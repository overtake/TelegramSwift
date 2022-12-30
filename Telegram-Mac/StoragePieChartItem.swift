//
//  StorageUsagePieChartItem.swift
//  Telegram
//
//  Created by Mike Renoir on 21.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

class StoragePieChartItem : GeneralRowItem {
    let items: [PieChartView.Item]
    let dynamicText: String
    let context: AccountContext
    let peer: Peer?
    let toggleSelected:(PieChartView.Item)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, items: [PieChartView.Item], dynamicText: String, peer: Peer?, viewType: GeneralViewType, toggleSelected:@escaping(PieChartView.Item)->Void) {
        self.items = items
        self.context = context
        self.peer = peer
        self.dynamicText = dynamicText
        self.toggleSelected = toggleSelected
        super.init(initialSize, stableId: stableId, viewType: .singleItem)
    }
    
    override var height: CGFloat {
        return 200
    }
    override func viewClass() -> AnyClass {
        return StoragePieChartItemView.self
    }
}
private class StoragePieChartItemView : GeneralRowView {
    private let pieChart = PieChartView(frame: NSMakeRect(0, 0, 200, 200), presentation: .init(strokeColor: theme.colors.background, strokeSize: 1, bgColor: theme.colors.background, totalTextColor: theme.colors.text, itemTextColor: .white))
    private var avatar: ChatAvatarView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(pieChart)
    }
    
    override func layout() {
        super.layout()
        pieChart.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoragePieChartItem else {
            return
        }
        
        self.pieChart.frame = self.focus(NSMakeSize(frame.width, item.height))
        self.pieChart.presentation = .init(strokeColor: theme.colors.listBackground, strokeSize: 1, bgColor: theme.colors.listBackground, totalTextColor: theme.colors.text, itemTextColor: .white)
        self.pieChart.update(items: item.items, dynamicText: item.dynamicText, animated: animated)
        
        self.pieChart.toggleSelected = item.toggleSelected
        
        if let peer = item.peer {
            let current: ChatAvatarView
            if let view = self.avatar {
                current = view
            } else {
                current = ChatAvatarView(frame: NSMakeRect(0, 0, 70, 70))
                addSubview(current, positioned: .below, relativeTo: pieChart)
                current.center()
                self.avatar = current
            }
            current.setPeer(context: item.context, peer: peer, disableForum: true)
        } else if let view = self.avatar {
            performSubviewRemoval(view, animated: animated)
            self.avatar = nil
        }
        needsLayout = true
    }
}
