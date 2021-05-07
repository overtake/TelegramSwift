//
//  GroupCallInviteRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 30.03.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit



final class GroupCallInviteRowItem : GeneralRowItem {
    fileprivate let videoMode: Bool
    private let futureWidth:()->CGFloat?
    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable, videoMode: Bool, viewType: GeneralViewType = .legacy, action: @escaping () -> Void, futureWidth:@escaping()->CGFloat?) {
        self.videoMode = videoMode
        self.futureWidth = futureWidth
        super.init(initialSize, height: height, stableId: stableId, viewType: viewType, action: action, inset: NSEdgeInsets())
    }
    
    override var width: CGFloat {
        if let futureWidth = self.futureWidth() {
            return futureWidth
        }
        if let superview = table?.superview {
            return superview.frame.width
        } else {
            return super.width
        }
    }
    
    var isVertical: Bool {
        return videoMode && (width == 160 || width >= fullScreenThreshold)
    }
    
    override var hasBorder: Bool {
        return !isVertical
    }
    
    override var instantlyResize: Bool {
        return false
    }
    
    override func viewClass() -> AnyClass {
        return  GroupCallInviteRowView.self
    }
}


private final class GroupCallInviteRowView : GeneralContainableRowView {
    private let textView = TextView()
    private let thumbView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(thumbView)
        addSubview(textView)
        
        thumbView.isEventLess = true
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? GroupCallInviteRowItem else {
                return
            }
            item.action()
        }, for: .Click)
    }
    
    override func updateColors() {
        super.updateColors()
        let color = containerView.controlState == .Highlight ? self.backdorColor.lighter() : self.backdorColor
        containerView.backgroundColor = color
        textView.backgroundColor = color
    }
    
    override var borderColor: NSColor {
        return GroupCallTheme.customTheme.borderColor
    }
    
    override var backdorColor: NSColor {
        return GroupCallTheme.membersColor
    }
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? GroupCallInviteRowItem else {
            return
        }
        
        thumbView.image = GroupCallTheme.inviteIcon
        thumbView.sizeToFit()
        
        textView.change(opacity: item.isVertical ? 0 : 1, animated: animated)
        
        let layout = TextViewLayout(.initialize(string: L10n.voiceChatInviteInviteMembers, color: GroupCallTheme.customTheme.textColor, font: .normal(.title)))
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)

        self.layout()
        
        if item.isVertical {
            thumbView.change(pos: NSMakePoint(floorToScreenPixels(backingScaleFactor, (160 - thumbView.frame.width) / 2), floorToScreenPixels(backingScaleFactor, (containerView.frame.height - thumbView.frame.height) / 2)), animated: animated)
        } else {
            thumbView.change(pos: NSMakePoint(item.viewType.innerInset.left, floorToScreenPixels(backingScaleFactor, (containerView.frame.height - thumbView.frame.height) / 2)), animated: animated)
            textView.change(pos: NSMakePoint(thumbView.frame.maxX + 20, floorToScreenPixels(backingScaleFactor, (containerView.frame.height - textView.frame.height) / 2)), animated: animated)
        }
        
    }

    override var additionBorderInset: CGFloat {
        return 44
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
