//
//  RecentPeerRowItem.swift
//  Telegram
//
//  Created by keepcoder on 21/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

import SwiftSignalKit

class RecentPeerRowItem: ShortPeerRowItem {

    fileprivate let controlAction:()->Void
    fileprivate let canRemoveFromRecent:Bool
    fileprivate let badge: BadgeNode?
    fileprivate let canAddAsTag: Bool
    let adPeer: AdPeer?
    fileprivate let removeAd:((AdPeer, Bool)->Void)?
    let isRecentApp: Bool
    
    init(_ initialSize:NSSize, peer: Peer, account: Account, context: AccountContext, stableId:AnyHashable? = nil, enabled: Bool = true, height:CGFloat = 50, photoSize:NSSize = NSMakeSize(36, 36), titleStyle:ControlStyle = ControlStyle(font:.medium(.title), foregroundColor: theme.colors.text, highlightColor: .white), titleAddition:String? = nil, leftImage:CGImage? = nil, statusStyle:ControlStyle = ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status:String? = nil, borderType:BorderType = [], drawCustomSeparator:Bool = true, isLookSavedMessage: Bool = false, deleteInset:CGFloat? = nil, drawLastSeparator:Bool = false, inset:NSEdgeInsets = NSEdgeInsets(left:10.0), drawSeparatorIgnoringInset: Bool = false, interactionType:ShortPeerItemInteractionType = .plain, generalType:GeneralInteractedType = .none, action:@escaping ()->Void = {}, canRemoveFromRecent: Bool = false, controlAction:@escaping()->Void = {}, contextMenuItems:@escaping()->Signal<[ContextMenuItem], NoError> = { .single([]) }, unreadBadge: UnreadSearchBadge = .none, canAddAsTag: Bool = false, storyStats: PeerStoryStats? = nil, openStory: @escaping(StoryInitialIndex?)->Void = { _ in }, customAction: ShortPeerRowItem.CustomAction? = nil, isGrossingApp: Bool = false, isRecentApp: Bool = false, adPeer: AdPeer? = nil, removeAd:((AdPeer, Bool)->Void)? = nil, monoforumPeer: Peer? = nil) {
        self.canRemoveFromRecent = canRemoveFromRecent
        self.controlAction = controlAction
        self.canAddAsTag = canAddAsTag
        self.isRecentApp = isRecentApp
        self.removeAd = removeAd
        self.adPeer = adPeer
        switch unreadBadge {
        case let .muted(count):
            badge = BadgeNode(.initialize(string: "\(count)", color: theme.chatList.badgeTextColor, font: .medium(.small)), theme.chatList.badgeMutedBackgroundColor)
        case let .unmuted(count):
            badge = BadgeNode(.initialize(string: "\(count)", color: theme.chatList.badgeTextColor, font: .medium(.small)), theme.chatList.badgeBackgroundColor)
        case .none:
            self.badge = nil
        }
        

        super.init(initialSize, peer: peer, account: account, context: context, stableId: stableId, enabled: enabled, height: height, photoSize: photoSize, titleStyle: titleStyle, titleAddition: titleAddition, leftImage: leftImage, statusStyle: statusStyle, status: status, borderType: borderType, drawCustomSeparator: drawCustomSeparator, isLookSavedMessage: isLookSavedMessage, deleteInset: deleteInset, drawLastSeparator: drawLastSeparator, inset: inset, drawSeparatorIgnoringInset: drawSeparatorIgnoringInset, interactionType: interactionType, generalType: generalType, action: action, contextMenuItems: contextMenuItems, highlightVerified: true, story: storyStats?.subscriptionItem(peer), openStory: openStory, customAction: badge != nil ? nil : customAction, makeAvatarRound: isGrossingApp, monoforumPeer: monoforumPeer)
    }
    
    
    override func viewClass() -> AnyClass {
        return RecentPeerRowView.self
    }
    
    override var textAdditionInset:CGFloat {
        return (self.canRemoveFromRecent || self.canAddAsTag ? 5 : 0) + (highlightVerified ? 25 : 0) + (adPeer != nil ? 30 : 0)
    }
}

class RecentPeerRowView : ShortPeerRowView {
    
    
    class AdView: Control {
        private let textView = TextView()
        private let imageView = ImageView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            addSubview(imageView)
            imageView.image = NSImage(resource: .iconSearchAd).precomposed(theme.colors.accent)
            imageView.sizeToFit()
            
            let layout = TextViewLayout(.initialize(string: strings().searchAd, color: theme.colors.accent, font: .normal(.small)))
            layout.measure(width: .greatestFiniteMagnitude)
            self.textView.update(layout)
            
            self.textView.userInteractionEnabled = false
            self.textView.isSelectable = false
            
            set(background: theme.colors.accent.withAlphaComponent(0.2), for: .Normal)
            
            setFrameSize(NSMakeSize(textView.frame.width + 8 + imageView.frame.width, 16))
            
            self.layer?.cornerRadius = frame.height / 2
            
            scaleOnClick = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            textView.centerY(x: 5)
            imageView.centerY(x: textView.frame.maxX)
        }
        
    }
    
    private var trackingArea:NSTrackingArea?
    private let control:ImageButton = ImageButton()
    private var badgeView:View?
    
    private var adView: AdView?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        //control.autohighlight = false
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        control.isHidden = true
        
        control.set(handler: { [weak self] _ in
            if let item = self?.item as? RecentPeerRowItem {
                item.controlAction()
            }
        }, for: .Click)
    }
    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        trackingArea = nil
        
        if let _ = window {
            let options:NSTrackingArea.Options = [.cursorUpdate, .mouseEnteredAndExited, .mouseMoved, .activeAlways]
            self.trackingArea = NSTrackingArea.init(rect: self.bounds, options: options, owner: self, userInfo: nil)
            
            self.addTrackingArea(self.trackingArea!)
        }
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateTrackingAreas()
    }
    
    deinit {
        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateMouse(animated: true)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateMouse(animated: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateMouse(animated: true)
    }
    
    override func updateMouse(animated: Bool) {
        if mouseInside(), control.superview != nil {
            control.isHidden = false
            badgeView?.isHidden = true
        } else {
            control.isHidden = true
            badgeView?.isHidden = false
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? RecentPeerRowItem {
            
            
            if item.canAddAsTag {
                control.set(image: isSelect ? theme.icons.search_filter_add_peer_active : theme.icons.search_filter_add_peer, for: .Normal)
            } else {
                control.set(image: isSelect ? theme.icons.recentDismissActive : theme.icons.recentDismiss, for: .Normal)
            }
            _ = control.sizeToFit()
            
            if item.customAction == nil, item.canRemoveFromRecent || item.canAddAsTag {
                addSubview(control)
            } else {
                control.removeFromSuperview()
            }
            
            if let badgeNode = item.badge {
                if badgeView == nil {
                    badgeView = View()
                    addSubview(badgeView!)
                }
                badgeView?.setFrameSize(badgeNode.size)
                badgeNode.view = badgeView
                badgeNode.setNeedDisplay()
            } else {
                badgeView?.removeFromSuperview()
                badgeView = nil
            }
            
            if let adPeer = item.adPeer, let context = item.context {
                let current: AdView
                if let view = self.adView {
                    current = view
                } else {
                    current = AdView(frame: .zero)
                    addSubview(current)
                    self.adView = current
                }
                _ = item.context?.engine.messages.markAdAsSeen(opaqueId: adPeer.opaqueId)
                
                current.contextMenu = { [weak item] in
                    let menu = ContextMenu()
                    
                    if let text = adPeer.sponsorInfo {
                        let submenu = ContextMenu()
                        
                        let item = ContextMenuItem(strings().searchAdSponsorInfo, itemImage: MenuAnimation.menu_show_info.value)
                        
                        item.submenu = submenu
                        
                        submenu.addItem(ContextMenuItem(text, handler: {
                            copyToClipboard(text)
                            showModalText(for: context.window, text: strings().contextAlertCopied)
                        }, removeTail: false))
                        
                        if let text = adPeer.additionalInfo {
                            if !submenu.items.isEmpty {
                                submenu.addItem(ContextSeparatorItem())
                            }
                            submenu.addItem(ContextMenuItem(text, handler: {
                                copyToClipboard(text)
                                showModalText(for: context.window, text: strings().contextAlertCopied)
                            }, removeTail: false))
                        }
                        
                    }
                    
                    menu.addItem(ContextMenuItem(strings().chatMessageSponsoredAbout, handler: {
                        showModal(with: SearchAdAboutController(context: context), for: context.window)
                    }, itemImage: MenuAnimation.menu_show_info.value))

                    
                    menu.addItem(ContextMenuItem(strings().chatMessageSponsoredReport, handler: {
                        
                        _ = showModalProgress(signal: context.engine.messages.reportAdMessage(opaqueId: adPeer.opaqueId, option: nil), for: context.window).startStandalone(next: { result in
                            switch result {
                            case .reported:
                                showModalText(for: context.window, text: strings().chatMessageSponsoredReportAready)
                            case .adsHidden:
                                break
                            case let .options(title, options):
                                showComplicatedReport(context: context, title: title, info: strings().chatMessageSponsoredReportLearnMore, header: strings().chatMessageSponsoredReport, data: .init(subject: .list(options.map { .init(string: $0.text, id: $0.option) }), title: strings().chatMessageSponsoredReportOptionTitle), report: { report in
                                    return context.engine.messages.reportAdMessage(opaqueId: adPeer.opaqueId, option: report.id) |> `catch` { error in
                                        return .single(.reported)
                                    } |> deliverOnMainQueue |> map { result in
                                        switch result {
                                        case let .options(_, options):
                                            return .init(subject: .list(options.map { .init(string: $0.text, id: $0.option) }), title: report.string)
                                        case .reported:
                                            showModalText(for: context.window, text: strings().chatMessageSponsoredReportSuccess)
                                            item?.removeAd?(adPeer, false)
                                            return nil
                                        case .adsHidden:
                                            return nil
                                        }
                                    }
                                    
                                })
                            }
                        }, error: { error in
                            switch error {
                            case .premiumRequired:
                                prem(with: PremiumBoardingController(context: context, source: .no_ads, openFeatures: true), for: context.window)
                            case .generic:
                                break
                            }
                        })
                    }, itemImage: MenuAnimation.menu_restrict.value))
                    
                    
                    if !context.premiumIsBlocked {
                        menu.addItem(ContextSeparatorItem())

                        menu.addItem(ContextMenuItem(strings().searchAdRemoveAd, handler: {
                            if context.isPremium {
                                _ = context.engine.accountData.updateAdMessagesEnabled(enabled: false).startStandalone()
                                item?.removeAd?(adPeer, true)
                                showModalText(for: context.window, text: strings().chatDisableAdTooltip)
                            } else {
                                prem(with: PremiumBoardingController(context: context, source: .no_ads, openFeatures: true), for: context.window)
                            }
                        }, itemImage: MenuAnimation.menu_clear_history.value))
                    }

                    return menu
                }
                
            } else if let view = adView {
                performSubviewRemoval(view, animated: animated)
                self.adView = nil
            }
            
        }
        updateMouse(animated: true)
        needsLayout = true
    }
    
    override var backdorColor: NSColor {
        if let item = item {
            return item.isHighlighted && !item.isSelected ? theme.colors.grayForeground : super.backdorColor
        } else {
            return super.backdorColor
        }
    }
    
    override func layout() {
        super.layout()
        
        
        control.centerY(x: frame.width - control.frame.width - 10)
        if let badgeView = badgeView {
            badgeView.centerY(x: frame.width - badgeView.frame.width - 10)
        }
        
        if let adView {
            adView.setFrameOrigin(NSMakePoint(frame.width - adView.frame.width - 10, 10))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
