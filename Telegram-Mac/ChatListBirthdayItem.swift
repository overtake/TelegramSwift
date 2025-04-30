//
//  ChatListBirthdayItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

final class ChatListAddBirthdayItem : GeneralRowItem {
    let title: TextViewLayout
    let info: TextViewLayout
    let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext) {
        self.context = context
        self.title = .init(.initialize(string: strings().chatListBirthdayAddTitle, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.info = .init(.initialize(string: strings().chatListBirthdayAddInfo, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 2)
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 20 - 15)
        self.info.measure(width: width - 20 - 15)
        return true
    }
    
    func invoke(_ date: Date) {
        editAccountUpdateBirthday(date, context: context)
        _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.setupBirthday.id).startStandalone()
    }
    
    func dismiss() {
        _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.setupBirthday.id).startStandalone()
    }
    
    override func viewClass() -> AnyClass {
        return ChatListAddBirthdayView.self
    }
    
    override var height: CGFloat {
        return 8 + title.layoutSize.height + 3 + info.layoutSize.height + 8
    }
}

final class ChatListBirthdayItem : GeneralRowItem {
    
    let birthdays: [UIChatListBirthday]
    let context: AccountContext
    let title: TextViewLayout
    let info: TextViewLayout

    init(_ initialSize: NSSize, stableId: AnyHashable, birthdays: [UIChatListBirthday], context: AccountContext) {
        self.birthdays = birthdays
        self.context = context
        
        let titleAttr = NSMutableAttributedString()
        if birthdays.count == 1 {
            titleAttr.append(string: strings().chatListBirthdaySingleTitle(birthdays[0].peer._asPeer().compactDisplayTitle), color: theme.colors.text, font: .medium(.text))
        } else {
            titleAttr.append(string: strings().chatListBirthdayMultipleTitleCountable(birthdays.count), color: theme.colors.text, font: .medium(.text))
        }
        titleAttr.detectBoldColorInString(with: .medium(.text), color: theme.colors.accent)
        
        self.title = .init(titleAttr, maximumNumberOfLines: 1)
        self.info = .init(.initialize(string: strings().chatListBirthdayInfoNewCountable(birthdays.count), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 2)

        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 20 - 20 - CGFloat(30 + (birthdays.prefix(2).count - 1) * 24))
        self.info.measure(width: width - 20 - 20 - CGFloat(30 + (birthdays.prefix(2).count - 1) * 24))
        return true
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items: [ContextMenuItem] = []
        let context = self.context
        for birthday in birthdays {
            items.append(ReactionPeerMenu(title: birthday.peer._asPeer().displayTitle, handler: { [weak self] in
                self?.context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(birthday.peer.id)))
                
            }, peer: birthday.peer._asPeer(), context: context, reaction: nil))
        }
        
        return .single(items)
    }
    
    func invoke() {
        let context = self.context
        multigift(context: context, selected: self.birthdays.map { $0.peer.id })
    }
    
    func dismiss() {
        _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.todayBirthdays.id).startStandalone()
    }
    
    
    override func viewClass() -> AnyClass {
        return ChatListBirthdayView.self
    }
    
    override var height: CGFloat {
        return 8 + title.layoutSize.height + 3 + info.layoutSize.height + 8
    }
}

private final class ChatListBirthdayView : TableRowView {
    
    private var avatars:[AvatarContentView] = []
    private let avatarsContainer = View(frame: NSMakeRect(0, 0, 30 * 3, 30))
    
    private struct Avatar : Comparable, Identifiable {
        static func < (lhs: Avatar, rhs: Avatar) -> Bool {
            return lhs.index < rhs.index
        }
        
        var stableId: PeerId {
            return peer.id
        }
        
        static func == (lhs: Avatar, rhs: Avatar) -> Bool {
            if lhs.index != rhs.index {
                return false
            }
            if !lhs.peer.isEqual(rhs.peer) {
                return false
            }
            return true
        }
        
        let peer: Peer
        let index: Int
    }

    private var peers:[Avatar] = []

    private let borderView = View()
    
    private let titleView = TextView()
    private let infoView = TextView()
    private let overlay = Control()
    private let dismiss = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(infoView)
        
        addSubview(avatarsContainer)
        avatarsContainer.isEventLess = true

        addSubview(borderView)
        addSubview(overlay)
        
        addSubview(dismiss)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        
        overlay.set(handler: { [weak self] control in
            if let item = self?.item as? ChatListBirthdayItem {
                item.invoke()
            }
        }, for: .Click)
        
        dismiss.set(handler: { [weak self] control in
            if let item = self?.item as? ChatListBirthdayItem {
                item.dismiss()
            }
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        overlay.frame = bounds
        self.avatarsContainer.centerY(x: 10)
        
        borderView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        
        let maxX = CGFloat(30 + (avatarsContainer.subviews.count - 1) * 20) + 20
        titleView.setFrameOrigin(NSMakePoint(maxX, 8))
        infoView.setFrameOrigin(NSMakePoint(maxX, frame.height - infoView.frame.height - 8))
        
        dismiss.centerY(x: frame.width - 10 - dismiss.frame.width)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListBirthdayItem else {
            return
        }
        
        self.titleView.update(item.title)
        self.infoView.update(item.info)
        
        dismiss.set(image: NSImage(resource: .iconVoiceChatTooltipClose).precomposed(theme.colors.grayIcon), for: .Normal)
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        dismiss.sizeToFit(NSMakeSize(10, 10))
        
        
        borderView.backgroundColor = theme.colors.border
        
        let duration = Double(0.2)
        let timingFunction = CAMediaTimingFunctionName.easeOut
        
        
        let peers:[Avatar] = item.birthdays.prefix(2).reduce([], { current, value in
            var current = current
            current.append(.init(peer: value.peer._asPeer(), index: current.count))
            return current
        })
        
        let (removed, inserted, updated) = mergeListsStableWithUpdates(leftList: self.peers, rightList: peers)
        
        for removed in removed.reversed() {
            let control = avatars.remove(at: removed)
            let peer = self.peers[removed]
            let haveNext = peers.contains(where: { $0.stableId == peer.stableId })
            control.updateLayout(size: NSMakeSize(30, 30), isClipped: false, animated: animated)
            if animated && !haveNext {
                control.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak control] _ in
                    control?.removeFromSuperview()
                })
                control.layer?.animateScaleSpring(from: 1.0, to: 0.2, duration: duration)
            } else {
                control.removeFromSuperview()
            }
        }
        for inserted in inserted {
            let control = AvatarContentView(context: item.context, peer: inserted.1.peer, message: nil, synchronousLoad: false, size: NSMakeSize(30, 30), inset: 8)
            control.updateLayout(size: NSMakeSize(30, 30), isClipped: inserted.0 != 0, animated: animated)
            control.userInteractionEnabled = false
            control.setFrameSize(NSMakeSize(30, 30))
            control.setFrameOrigin(NSMakePoint(CGFloat(inserted.0) * 20, 0))
            avatars.insert(control, at: inserted.0)
            avatarsContainer.subviews.insert(control, at: inserted.0)
            if animated {
                if let index = inserted.2 {
                    control.layer?.animatePosition(from: NSMakePoint(CGFloat(index) * 22, 0), to: control.frame.origin, timingFunction: timingFunction)
                } else {
                    control.layer?.animateAlpha(from: 0, to: 1, duration: duration, timingFunction: timingFunction)
                    control.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: duration)
                }
            }
        }
        for updated in updated {
            let control = avatars[updated.0]
            control.updateLayout(size: NSMakeSize(30, 30), isClipped: updated.0 != 0, animated: animated)
            let updatedPoint = NSMakePoint(CGFloat(updated.0) * 20, 0)
            if animated {
                control.layer?.animatePosition(from: control.frame.origin - updatedPoint, to: .zero, duration: duration, timingFunction: timingFunction, additive: true)
            }
            control.setFrameOrigin(updatedPoint)
        }
        var index: CGFloat = 10
        for control in avatarsContainer.subviews.compactMap({ $0 as? AvatarContentView }) {
            control.layer?.zPosition = index
            index -= 1
        }
        
        self.peers = peers
        
        needsLayout = true
    }

}



private final class ChatListAddBirthdayView : TableRowView {
    private let titleView = TextView()
    private let infoView = TextView()
    private let overlay = Control()
    private let dismiss = ImageButton()
    private let borderView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(infoView)
        
        addSubview(borderView)
        addSubview(overlay)
        addSubview(dismiss)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        
        overlay.set(handler: { [weak self] control in
            guard let self, let item = self.item as? ChatListAddBirthdayItem else {
                return
            }
            let controller = CalendarController(NSMakeRect(0, 0, 300, 300), item.context.window, current: Date(), lowYear: 1900, canBeNoYear: true, selectHandler: { date in
                item.invoke(date)
            })
            let nav = NavigationViewController(controller, item.context.window)
            nav._frameRect = NSMakeRect(0, 0, 300, 310)
            showModal(with: nav, for: item.context.window)

        }, for: .Click)
        
        dismiss.set(handler: { [weak self] control in
            if let item = self?.item as? ChatListAddBirthdayItem {
                item.dismiss()
            }
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        overlay.frame = bounds
        titleView.setFrameOrigin(NSMakePoint(10, 8))
        infoView.setFrameOrigin(NSMakePoint(10, frame.height - infoView.frame.height - 8))
        borderView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)

        dismiss.centerY(x: frame.width - 10 - dismiss.frame.width)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListAddBirthdayItem else {
            return
        }
        
        self.titleView.update(item.title)
        self.infoView.update(item.info)
        
        dismiss.set(image: NSImage(resource: .iconVoiceChatTooltipClose).precomposed(theme.colors.grayIcon), for: .Normal)
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        dismiss.sizeToFit(NSMakeSize(10, 10))

        borderView.backgroundColor = theme.colors.border
    }
}
