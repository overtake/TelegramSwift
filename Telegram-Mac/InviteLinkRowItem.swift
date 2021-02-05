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

private let linkIcon: CGImage = NSImage(named: "Icon_ExportedInvitation_Link")!.precomposed(.white)




class InviteLinkRowItem: GeneralRowItem {
    private let _menuItems:(ExportedInvitation)->Signal<[ContextMenuItem], NoError>
    
    private(set) fileprivate var frames:[NSRect] = []
    let link:ExportedInvitation
    fileprivate let _action:(ExportedInvitation)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, link:ExportedInvitation, action: @escaping(ExportedInvitation)->Void, menuItems:@escaping(ExportedInvitation)->Signal<[ContextMenuItem], NoError>) {
        self._menuItems = menuItems
        self.link = link
        self._action = action
        super.init(initialSize, height: 50, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        

        return true
    }

    var innerBlockSize: NSSize {
       return NSMakeSize(blockWidth - viewType.innerInset.left - viewType.innerInset.right, height - viewType.innerInset.bottom - viewType.innerInset.top)
    }

    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return _menuItems(link)
    }
    override func viewClass() -> AnyClass {
        return InviteLinkRowView.self
    }
}
private final class ProgressView : View {

    private let circle: View = View(frame: NSMakeRect(0, 0, 28, 28))
    private let progressView: FireTimerControl = FireTimerControl(frame: NSMakeRect(0, 0, 50, 50))
    private let imageView = ImageView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(circle)
        addSubview(progressView)
        addSubview(imageView)

        circle.layer?.cornerRadius = circle.frame.height / 2

        circle.isEventLess = true
        imageView.isEventLess = true
        progressView.isEventLess = true
    }

    override func layout() {
        super.layout()
        progressView.center()
        circle.center()
        imageView.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(link: ExportedInvitation) {
        self.imageView.image = linkIcon
        self.imageView.sizeToFit()

        let color:(NSColor, NSColor, CGFloat) -> NSColor = { from, to, progress in
            let newRed = (1.0 - progress) * from.redComponent + progress * to.redComponent
            let newGreen = (1.0 - progress) * from.greenComponent + progress * to.greenComponent
            let newBlue = (1.0 - progress) * from.blueComponent + progress * to.blueComponent
            let newAlpha = (1.0 - progress) * from.alphaComponent + progress * to.alphaComponent

            return NSColor(deviceRed: newRed, green: newGreen, blue: newBlue, alpha: newAlpha)
        }

        let updateBackgroundColor: ()->NSColor = { [weak self] in
            guard let `self` = self else {
                return .white
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
            self.circle.backgroundColor = backgroundColor
            self.progressView.updateColor(backgroundColor)

            return backgroundColor
        }

        if let expiryDate = link.expireDate, !link.isExpired && !link.isRevoked {
            let startDate = link.startDate ?? link.date
            let timeout = expiryDate - startDate
            progressView.update(color: updateBackgroundColor(), timeout: timeout, deadlineTimestamp: expiryDate)

            progressView.reachedTimeout = {
                _ = updateBackgroundColor()
            }
            progressView.reachedHalf = {
                _ = updateBackgroundColor()
            }

            progressView.updateValue = { value in
                _ = updateBackgroundColor()
            }
            progressView.isHidden = false
        } else {
            progressView.isHidden = true
        }
        _ = updateBackgroundColor()
    }
}

private final class InviteLinkTokenView : Control {
    private let actions = ImageButton()
    private let titleView = TextView()
    private let countView = TextView()
    private let progressView = ProgressView(frame: NSMakeRect(0, 0, 50, 50))
    private var action:(()->Void)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(actions)
        addSubview(titleView)
        addSubview(countView)
        addSubview(progressView)
        layer?.cornerRadius = 10
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        countView.userInteractionEnabled = false
        countView.isSelectable = false
        progressView.isEventLess = true
        scaleOnClick = true
        progressView.userInteractionEnabled = false
        progressView.isEventLess = true
        set(handler: { [weak self] _ in
            self?.action?()
        }, for: .Click)
    }
    
    private var actionsPoint: NSPoint {
        return NSMakePoint(frame.width - actions.frame.width - 15, focus(actions.frame.size).minY)
    }
    private var progressPoint: NSPoint {
        return NSMakePoint(7, focus(progressView.frame.size).minY)
    }
    private var titlePoint: NSPoint {
        return NSMakePoint(58, 7)
    }
    private var countPoint: NSPoint {
        return NSMakePoint(58, frame.height - 7 - countView.frame.height)
    }

    
    override func layout() {
        super.layout()
        actions.setFrameOrigin(actionsPoint)
        progressView.setFrameOrigin(progressPoint)
        titleView.setFrameOrigin(titlePoint)
        countView.setFrameOrigin(countPoint)
    }
    
    func update(with link: ExportedInvitation, frame: NSRect, animated: Bool, showContextMenu:@escaping()->Void, action: @escaping()->Void) {
                
        self.action = action

        actions.set(image: generate(theme.colors.grayForeground), for: .Normal)
        actions.style = ControlStyle(highlightColor: theme.colors.grayForeground.highlighted)
        actions.sizeToFit()


        actions.change(pos: actionsPoint, animated: animated)
        progressView.change(pos: progressPoint, animated: animated)
        
        progressView.update(link: link)
        
        let titleText = link.link.replacingOccurrences(of: "https://", with: "")
        
        let titleAttr = NSMutableAttributedString()
        _ = titleAttr.append(string: titleText, color: theme.colors.text, font: .medium(.text))
        let titleLayout = TextViewLayout(titleAttr, maximumNumberOfLines: 2)
        titleLayout.measure(width: frame.width - 20)
        
        titleView.update(titleLayout)

        var text: String = ""
        if let count = link.count {
            text = L10n.inviteLinkJoinedCountable(Int(count))
            text = text.replacingOccurrences(of: "\(count)", with: Int(count).prettyNumber)
        } else {
            text = L10n.inviteLinkJoinedZero
        }
        var countText = text
        
        if link.isRevoked {
            countText += " " + L10n.inviteLinkStickerRevoked
        } else {
            if let usageLink = link.usageLimit, let count = link.count {
                if !link.isLimitReached {
                    countText += " " + L10n.inviteLinkRemainingFew(Int(usageLink - count))
                } else if link.isLimitReached {
                    countText += " " + L10n.inviteLinkRemainingFew(Int(usageLink - count))
                }
            }

            if link.isExpired {
                countText += " " + L10n.inviteLinkStickerExpired
            } else if let expireDate = link.expireDate {
                countText += " • " + L10n.inviteLinkStickerTimeLeft(autoremoveLocalized(Int(expireDate) - Int(Date().timeIntervalSince1970)))
            }
        }
        
        let countLayout = TextViewLayout(.initialize(string: countText, color: theme.colors.text, font: .normal(.short)), maximumNumberOfLines: 2)
        countLayout.measure(width: frame.width - 20)
        
        countView.update(countLayout)
        
        titleView.change(pos: titlePoint, animated: animated)
        countView.change(pos: countPoint, animated: animated)

        
        
        actions.removeAllHandlers()
        actions.set(handler: { _ in
           showContextMenu()
        }, for: .Click)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class InviteLinkRowView : GeneralContainableRowView {
    private let contentView: InviteLinkTokenView = InviteLinkTokenView(frame: .zero)
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

    
    override func onShowContextMenu() {
        super.onShowContextMenu()
    }
    override func onCloseContextMenu() {
        super.onCloseContextMenu()
    }
    
    override func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        return self.contentView.convert(point, from: nil)
    }

    override var additionBorderInset: CGFloat {
        return 42
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? InviteLinkRowItem else  {
            return
        }

        layout()



        contentView.update(with: item.link, frame: containerView.bounds, animated: animated, showContextMenu: { [weak self] in
            if let event = NSApp.currentEvent {
                self?.showContextMenu(event)
            }
        }, action: { [weak item] in
            if let link = item?.link {
                item?._action(link)
            }
        })
    }
}
