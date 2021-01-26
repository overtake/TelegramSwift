//
//  ExportedInvitationRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SyncCore
import Postbox
import TelegramCore
import SwiftSignalKit


private func generate(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(40 / System.backingScale, 40 / System.backingScale), contextGenerator: { size, ctx in
        let rect: NSRect = .init(origin: .zero, size: size)
        ctx.clear(rect)
        
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: rect)
        
        let image = NSImage(named: "Icon_ChatActionsActive")!.precomposed()
        
        ctx.clip(to: rect, mask: image)
        ctx.clear(rect)
        
        
    }, scale: System.backingScale)!
}

private var menuIcon: CGImage {
    return generate(theme.colors.grayForeground.darker())
}
private var menuIconActive: CGImage {
    return generate(theme.colors.grayForeground.darker().highlighted)
}

class ExportedInvitationRowItem: GeneralRowItem {

    enum Mode {
        case normal
        case short
    }
    
    fileprivate let context: AccountContext
    fileprivate let exportedLink: ExportedInvitation?
    fileprivate let linkTextLayout: TextViewLayout
    private let _menuItems: ()->Signal<[ContextMenuItem], NoError>
    fileprivate let shareLink:(String)->Void
    fileprivate let usageTextLayout: TextViewLayout
    fileprivate let lastPeers: [RenderedPeer]
    fileprivate let mode: Mode
    fileprivate let open:(ExportedInvitation)->Void
    fileprivate let copyLink:(String)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, exportedLink: ExportedInvitation?, lastPeers: [RenderedPeer], viewType: GeneralViewType, mode: Mode = .normal, menuItems: @escaping()->Signal<[ContextMenuItem], NoError>, share: @escaping(String)->Void, open: @escaping(ExportedInvitation)->Void = { _ in }, copyLink: @escaping(String)->Void = { _ in }) {
        self.context = context
        self.exportedLink = exportedLink
        self._menuItems = menuItems
        self.lastPeers = lastPeers
        self.shareLink = share
        self.open = open
        self.mode = mode
        self.copyLink = copyLink
        let text: String
        let color: NSColor
        let usageText: String
        let usageColor: NSColor
        if let exportedLink = exportedLink {
            text = exportedLink.link.replacingOccurrences(of: "https://", with: "")
            color = theme.colors.text
            if let count = exportedLink.count {
                usageText = L10n.inviteLinkPeopleJoinedCountable(Int(count))
                if count > 0 {
                    usageColor = theme.colors.link
                } else {
                    usageColor = theme.colors.grayText
                }
            } else {
                usageText = L10n.inviteLinkPeopleJoinedZero
                usageColor = theme.colors.grayText
            }
        } else {
            text = L10n.channelVisibilityLoading
            color = theme.colors.grayText
            usageText = L10n.inviteLinkPeopleJoinedZero
            usageColor = theme.colors.grayText
        }
        
        linkTextLayout = TextViewLayout(.initialize(string: text, color: color, font: .normal(.text)), alignment: .center)
        

        usageTextLayout = TextViewLayout(.initialize(string: usageText, color: usageColor, font: .normal(.text)))
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        var height: CGFloat = viewType.innerInset.top + 40 + viewType.innerInset.top
        
        if let link = exportedLink, !link.isExpired && !link.isRevoked {
            height += 40 + viewType.innerInset.top
        }
        
        switch mode {
        case .normal:
            height += 30 + viewType.innerInset.bottom
        case .short:
            break
        }
        
        return height
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        
        linkTextLayout.measure(width: blockWidth - viewType.innerInset.left * 2 + viewType.innerInset.right * 2 - 120)
        usageTextLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        return result
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return _menuItems()
    }
    
    override func viewClass() -> AnyClass {
        return ExportedInvitationRowView.self
    }
}


private final class ExportedInvitationRowView : GeneralContainableRowView {
    
    
    struct Avatar : Comparable, Identifiable {
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
    
    
    private let linkContainer: Control = Control()
    private let linkView: TextView = TextView()
    private let share: TitleButton = TitleButton()
    private let actions: ImageButton = ImageButton()
    private let usageTextView = TextView()
    private let usageContainer = Control()
    
    
    private var topPeers: [Avatar] = []
    private var avatars:[AvatarContentView] = []
    private let avatarsContainer = View(frame: NSMakeRect(0, 0, 25 * 3 + 10, 38))

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(linkContainer)
        linkContainer.layer?.cornerRadius = 10
        linkContainer.addSubview(linkView)
        addSubview(share)
        share.layer?.cornerRadius = 10
        share._thatFit = true
        linkView.userInteractionEnabled = false
        linkView.isSelectable = false
        
        
        linkContainer.addSubview(actions)
        
        addSubview(usageContainer)
        
        usageTextView.userInteractionEnabled = false
        usageTextView.isSelectable = false
        usageTextView.isEventLess = true
        avatarsContainer.isEventLess = true
        
        
        usageContainer.addSubview(usageTextView)
        
        usageContainer.addSubview(avatarsContainer)

        
        linkContainer.set(handler: { [weak self] _ in
            guard let item = self?.item as? ExportedInvitationRowItem else {
                return
            }
            if let link = item.exportedLink {
                item.copyLink(link.link)
            }
        }, for: .Click)
        
        actions.set(handler: { [weak self] control in
            guard let event = NSApp.currentEvent else {
                return
            }
            self?.showContextMenu(event)
        }, for: .Down)
        
        share.set(handler: { [weak self] _ in
            guard let item = self?.item as? ExportedInvitationRowItem else {
                return
            }
            if let link = item.exportedLink {
                item.shareLink(link.link)
            }
        }, for: .Click)
        
        usageContainer.set(handler: { [weak self] _ in
            guard let item = self?.item as? ExportedInvitationRowItem else {
                return
            }
            if let exportedLink = item.exportedLink {
                item.open(exportedLink)
            }
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? ExportedInvitationRowItem else {
            return
        }
        
        let innerBlockSize = item.blockWidth - item.viewType.innerInset.left - item.viewType.innerInset.right
        
        linkContainer.frame = NSMakeRect(item.viewType.innerInset.left, item.viewType.innerInset.top, innerBlockSize, 40)
        linkView.center()
        
        
        share.frame = NSMakeRect(item.viewType.innerInset.left, linkContainer.frame.maxY + item.viewType.innerInset.top, innerBlockSize, 40)
        actions.centerY(x: linkContainer.frame.width - actions.frame.width - item.viewType.innerInset.right)
        
        usageContainer.frame = NSMakeRect(item.viewType.innerInset.left, share.frame.maxY + item.viewType.innerInset.top, innerBlockSize, 30)
        
        let avatarSize: CGFloat = avatarsContainer.subviews.map { $0.frame.maxX }.max() ?? 0

        if avatarSize > 0 {
            usageTextView.centerY(x: floorToScreenPixels(backingScaleFactor, (frame.width - usageTextView.frame.width - avatarSize - 5) / 2))
            avatarsContainer.centerY(x: usageTextView.frame.minX - avatarSize - 5)
        } else {
            usageTextView.center()
        }        
    }
    
    override func updateColors() {
        super.updateColors()
        
        guard let item = item as? ExportedInvitationRowItem else {
            return
        }
        
        
        linkContainer.backgroundColor = theme.colors.grayBackground
        linkView.backgroundColor = theme.colors.grayBackground
        share.set(background: theme.colors.accent, for: .Normal)
        share.set(background: theme.colors.accent.highlighted, for: .Highlight)
        share.set(color: theme.colors.underSelectedColor, for: .Normal)
        actions.set(image: menuIcon, for: .Normal)
        actions.set(image: menuIconActive, for: .Highlight)
        actions.sizeToFit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ExportedInvitationRowItem else {
            return
        }
        
        let duration: Double = 0.4
        let timingFunction: CAMediaTimingFunctionName = .spring
        
        var topPeers: [Avatar] = []
        if !item.lastPeers.isEmpty {
            var index:Int = 0
            for participant in item.lastPeers {
                if let peer = participant.peer {
                    topPeers.append(Avatar(peer: peer, index: index))
                    index += 1
                }
            }
        }
        
        let (removed, inserted, updated) = mergeListsStableWithUpdates(leftList: self.topPeers, rightList: topPeers)
        
        let avatarSize = NSMakeSize(38, 38)
        
        for removed in removed.reversed() {
            let control = avatars.remove(at: removed)
            let peer = self.topPeers[removed]
            let haveNext = topPeers.contains(where: { $0.stableId == peer.stableId })
            control.updateLayout(size: avatarSize - NSMakeSize(8, 8), isClipped: false, animated: animated)
            control.layer?.opacity = 0
            if animated && !haveNext {
                control.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak control] _ in
                    control?.removeFromSuperview()
                })
                control.layer?.animateScaleSpring(from: 1.0, to: 0.2, duration: duration, bounce: false)
            } else {
                control.removeFromSuperview()
            }
        }
        for inserted in inserted {
            let control = AvatarContentView(context: item.context, peer: inserted.1.peer, message: nil, synchronousLoad: false, size: avatarSize, inset: 6)
            control.updateLayout(size: avatarSize - NSMakeSize(8, 8), isClipped: inserted.0 != 0, animated: animated)
            control.userInteractionEnabled = false
            control.setFrameSize(avatarSize)
            control.setFrameOrigin(NSMakePoint(CGFloat(inserted.0) * (avatarSize.width - 14), 0))
            avatars.insert(control, at: inserted.0)
            avatarsContainer.subviews.insert(control, at: inserted.0)
            if animated {
                if let index = inserted.2 {
                    control.layer?.animatePosition(from: NSMakePoint(CGFloat(index) * (avatarSize.width - 14), 0), to: control.frame.origin, timingFunction: timingFunction)
                } else {
                    control.layer?.animateAlpha(from: 0, to: 1, duration: duration, timingFunction: timingFunction)
                    control.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: duration, bounce: false)
                }
            }
        }
        for updated in updated {
            let control = avatars[updated.0]
            control.updateLayout(size: avatarSize - NSMakeSize(8, 8), isClipped: updated.0 != 0, animated: animated)
            let updatedPoint = NSMakePoint(CGFloat(updated.0) * (avatarSize.width - 14), 0)
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
                
        share.set(font: .medium(.text), for: .Normal)
        share.set(text: L10n.inviteLinkShareLink, for: .Normal)
        if let link = item.exportedLink {
            share.userInteractionEnabled = !link.isExpired && !link.isRevoked
        } else {
            share.userInteractionEnabled = item.exportedLink != nil
        }
        linkView.update(item.linkTextLayout)
     
        usageTextView.update(item.usageTextLayout)
        needsLayout = true
    }
}
