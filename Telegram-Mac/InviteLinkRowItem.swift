//
//  InviteLinkRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit


private func generate(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(50 / System.backingScale, 50 / System.backingScale), contextGenerator: { size, ctx in
        let rect: NSRect = .init(origin: .zero, size: size)
        ctx.clear(rect)
        
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: rect)
        
        let image = NSImage(named: "Icon_ChatActionsActive")!.precomposed()
        
        ctx.clip(to: rect, mask: image)
        ctx.clear(rect)
        
        
    }, scale: System.backingScale)!
}

private let expiredIcon: CGImage = NSImage(named: "Icon_ExportedInvitation_Expired")!.precomposed(.white)
private let linkIcon: CGImage = NSImage(named: "Icon_ExportedInvitation_Link")!.precomposed(.white)

private let menuIcon: CGImage = {
    return generate(.white)
}()


class InviteLinkRowItem: GeneralRowItem {
    private let _menuItems:(ExportedInvitation)->Signal<[ContextMenuItem], NoError>
    
    private(set) fileprivate var frames:[NSRect] = []
    let links:[ExportedInvitation]
    fileprivate let _action:(ExportedInvitation)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, links:[ExportedInvitation], action: @escaping(ExportedInvitation)->Void, menuItems:@escaping(ExportedInvitation)->Signal<[ContextMenuItem], NoError>) {
        self._menuItems = menuItems
        self.links = links
        self._action = action
        super.init(initialSize, height: viewType.innerInset.top + 100 + viewType.innerInset.bottom, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        let innerBlockSize = NSMakeSize(blockWidth - viewType.innerInset.left - viewType.innerInset.right, height - viewType.innerInset.bottom - viewType.innerInset.top)
        frames.removeAll()
        if links.count == 1 {
            frames = [CGRect(origin: .init(x: viewType.innerInset.left, y: viewType.innerInset.top), size: innerBlockSize)]
        } else {
            frames.append(CGRect(origin: .init(x: viewType.innerInset.left, y: viewType.innerInset.top), size: .init(width: floorToScreenPixels(System.backingScale, innerBlockSize.width / 2) - 5, height: innerBlockSize.height)))
            frames.append(CGRect(origin: .init(x: frames[0].maxX + 10, y: viewType.innerInset.top), size: .init(width: frames[0].width, height: innerBlockSize.height)))
        }
        
        return true
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        for (i, frame) in frames.enumerated() {
            if NSPointInRect(location, frame) {
                return _menuItems(links[i])
            }
        }
        return .single([])
    }
    override func viewClass() -> AnyClass {
        return InviteLinkRowView.self
    }
}


private final class InviteLinkTokenView : Control {
    private let actions = ImageButton()
    private let progressView: FireTimerControl = FireTimerControl(frame: NSMakeRect(0, 0, 40, 40))
    private let imageView = ImageView()
    private let titleView = TextView()
    private let countView = TextView()
    private var action:(()->Void)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(actions)
        addSubview(progressView)
        addSubview(titleView)
        addSubview(countView)
        addSubview(imageView)
        layer?.cornerRadius = 10
        actions.set(image: menuIcon, for: .Normal)
        actions.style = ControlStyle(highlightColor: NSColor(0xffffff).highlighted)
        actions.sizeToFit()
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        countView.userInteractionEnabled = false
        countView.isSelectable = false
        imageView.isEventLess = true
        scaleOnClick = true
        progressView.userInteractionEnabled = false
        progressView.isEventLess = true
        imageView.isEventLess = true
        set(handler: { [weak self] _ in
            self?.action?()
        }, for: .Click)
    }
    
    private var actionsPoint: NSPoint {
        return NSMakePoint(frame.width - actions.frame.width - 10, 10)
    }
    private var progressPoint: NSPoint {
        return NSMakePoint(3, 3)
    }
    private var titlePoint: NSPoint {
        return NSMakePoint(10, frame.height - 10 - countView.frame.height - 3 - titleView.frame.height)
    }
    private var countPoint: NSPoint {
        return NSMakePoint(10, frame.height - 10 - countView.frame.height)
    }
    private var imagePoint: NSPoint {
        return NSMakePoint(8, 8)
    }
    
    override func layout() {
        super.layout()
        actions.setFrameOrigin(actionsPoint)
        progressView.setFrameOrigin(progressPoint)
        titleView.setFrameOrigin(titlePoint)
        countView.setFrameOrigin(countPoint)
        imageView.setFrameOrigin(imagePoint)
    }
    
    func update(with link: ExportedInvitation, frame: NSRect, animated: Bool, showContextMenu:@escaping()->Void, action: @escaping()->Void) {
                
        self.action = action
        
        change(size: frame.size, animated: animated)
        change(pos: frame.origin, animated: animated)
        
        actions.change(pos: actionsPoint, animated: animated)
        progressView.change(pos: progressPoint, animated: animated)
        
        
        imageView.image = link.expireDate != nil ? expiredIcon : linkIcon
        imageView.sizeToFit()
        
        
        
        let color:(NSColor, NSColor, CGFloat) -> NSColor = { from, to, progress in
            let newRed = (1.0 - progress) * from.redComponent + progress * to.redComponent
            let newGreen = (1.0 - progress) * from.greenComponent + progress * to.greenComponent
            let newBlue = (1.0 - progress) * from.blueComponent + progress * to.blueComponent
            let newAlpha = (1.0 - progress) * from.alphaComponent + progress * to.alphaComponent
            
            return NSColor(deviceRed: newRed, green: newGreen, blue: newBlue, alpha: newAlpha)
        }
                
        let updateBackgroundColor = { [weak self] in
            guard let `self` = self else {
                return
            }
            let backgroundColor: NSColor
            if link.isRevoked {
                backgroundColor = theme.colors.grayForeground.darker()
            } else if let expireDate = link.expireDate {
                
                let timeout = expireDate - (link.startDate ?? link.date)
                
                let current = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                
                let from: NSColor?
                let to: NSColor
                            
                var progress: CGFloat = 1
                
                if link.isExpired || link.isLimitReached {
                    to = theme.colors.redUI.darker()
                    from = nil
                } else {
                    let dif = expireDate - current
                    progress = 1 - (CGFloat(dif) / CGFloat(timeout))
                    
                    if progress <= 0.5 {
                        progress /= 0.5
                        to = theme.colors.peerAvatarOrangeBottom
                        from = theme.colors.greenUI.darker()
                    } else {
                        progress = (progress - 0.5) / 0.5
                        to = theme.colors.redUI.darker()
                        from = theme.colors.peerAvatarOrangeBottom
                    }
                }
                if let from = from {
                    
                    backgroundColor = color(from, to, progress)
                } else {
                    backgroundColor = to
                }
                                
            } else {
                backgroundColor = theme.colors.accent.lighter()
            }
            self.backgroundColor = backgroundColor.withAlphaComponent(0.8)
            self.progressView.isHidden = link.isExpired || link.isRevoked
            self.imageView.isHidden = !self.progressView.isHidden
            
        }
        
        if let expiryDate = link.expireDate, !link.isExpired {
            let startDate = link.startDate ?? link.date
            let timeout = expiryDate - startDate
            progressView.update(color: .white, timeout: timeout, deadlineTimestamp: expiryDate)
            
            progressView.reachedTimeout = {
                updateBackgroundColor()
            }
            progressView.reachedHalf = {
                updateBackgroundColor()
            }
            
            progressView.updateValue = { value in
                updateBackgroundColor()
            }
        }
        
        
        
        let titleText = link.link.replacingOccurrences(of: "https://", with: "")
        
        let titleAttr = NSMutableAttributedString()
        _ = titleAttr.append(string: titleText, color: NSColor(0xffffff), font: .medium(.text))
        let range = titleText.nsstring.range(of: "t.me/joinchat/")
        if range.location != NSNotFound {
            titleAttr.addAttribute(.foregroundColor, value: NSColor(0xffffff).withAlphaComponent(0.8), range: range)
        }
        let titleLayout = TextViewLayout(titleAttr, maximumNumberOfLines: 2)
        titleLayout.measure(width: frame.width - 20)
        
        titleView.update(titleLayout)

        var text: String = ""
        if let count = link.count {
            text = L10n.inviteLinkPeopleJoinedCountable(Int(count))
            text = text.replacingOccurrences(of: "\(count)", with: Int(count).prettyNumber)
        } else {
            text = L10n.inviteLinkPeopleJoinedZero
        }
        var countText = text
        
        if link.isRevoked {
            countText += " " + L10n.inviteLinkStickerRevoked
        } else {
            if link.isLimitReached {
                countText += " " + L10n.inviteLinkStickerLimit
            }
            if link.isExpired {
                countText += " " + L10n.inviteLinkStickerExpired
            }
        }
        
        let countLayout = TextViewLayout(.initialize(string: countText, color: .white, font: .normal(.short)), maximumNumberOfLines: 2)
        countLayout.measure(width: frame.width - 20)
        
        countView.update(countLayout)
        
        titleView.change(pos: titlePoint, animated: animated)
        countView.change(pos: countPoint, animated: animated)

        
        
        actions.removeAllHandlers()
        actions.set(handler: { _ in
           showContextMenu()
        }, for: .Click)
        
        updateBackgroundColor()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class InviteLinkRowView : GeneralContainableRowView {
    private let contentView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(contentView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        contentView.frame = containerView.bounds
    }
    
    override func updateColors() {
        super.updateColors()
    }
    
    override var borderColor: NSColor {
        return .clear
    }
    
    override func onShowContextMenu() {
        super.onShowContextMenu()
    }
    override func onCloseContextMenu() {
        super.onCloseContextMenu()
    }
    
    override func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        return self.contentView.convert(point, from: nil)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? InviteLinkRowItem else  {
            return
        }
        
        
        while self.contentView.subviews.count > item.links.count {
            self.contentView.subviews.last?.removeFromSuperview()
        }
        while self.contentView.subviews.count < item.links.count {
            let index = self.contentView.subviews.count
            contentView.addSubview(InviteLinkTokenView(frame: item.frames[index]))
        }
        
        for (i, link) in item.links.enumerated() {
            (contentView.subviews[i] as? InviteLinkTokenView)?.update(with: link, frame: item.frames[i], animated: animated, showContextMenu: { [weak self] in
                if let event = NSApp.currentEvent {
                    self?.showContextMenu(event)
                }
            }, action: { [weak item] in
                item?._action(link)
            })
        }
    }
}
