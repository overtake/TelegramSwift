//
//  PremiumGiftHeaderItem.swift
//  Telegram
//
//  Created by Mike Renoir on 27.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit

final class PremiumGiftHeaderItem : GeneralRowItem {
    let textLayout: TextViewLayout
    let titleLayout: TextViewLayout

    let photoSize = NSMakeSize(100, 100)
    
    let peer: Peer
    let context: AccountContext
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, peer: Peer) {
        
        self.peer = peer
        self.context = context
        
        titleLayout = .init(.initialize(string: strings().premiumGiftTitle, color: theme.colors.text, font: .bold(18)), alignment: .center)
        
        let text = NSMutableAttributedString()
        _ = text.append(string: strings().premiumGiftText(peer.displayTitle), color: theme.colors.text, font: .normal(.text))
        text.detectBoldColorInString(with: .medium(.text))
        textLayout = .init(text, alignment: .center)

        super.init(initialSize, stableId: stableId)
        
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        titleLayout.measure(width: width - 40)
        textLayout.measure(width: width - 40)
        
        return true
    }
    
    override var height: CGFloat {
        return photoSize.height + 20 + titleLayout.layoutSize.height + 10 + textLayout.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return PremiumGiftHeaderView.self
    }
}


private final class PremiumGiftHeaderView: TableRowView {
    
    private let avatar = ChatAvatarView(frame: NSMakeSize(100, 100).bounds)
    private let textView = TextView()
    private let titleView = TextView()
//    private let scene: PremiumGiftStarSceneView = PremiumGiftStarSceneView(frame: NSMakeRect(0, 0, 200, 200))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(titleView)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        avatar.setFrameSize(NSMakeSize(100, 100))
//        addSubview(scene)
        
//        scene.updateLayout(size: scene.frame.size, transition: .immediate)
        addSubview(avatar)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        avatar.centerX(y: 0)
        titleView.centerX(y: avatar.frame.maxY + 20)
        textView.centerX(y: titleView.frame.maxY + 10)
//        scene.centerX(y: -50)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PremiumGiftHeaderItem else {
            return
        }
        
        titleView.update(item.titleLayout)
        textView.update(item.textLayout)

        avatar.setPeer(context: item.context, peer: item.peer, force: true)
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
