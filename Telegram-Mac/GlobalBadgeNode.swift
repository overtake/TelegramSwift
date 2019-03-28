//
//  GlobalBadgeNode.swift
//  TelegramMac
//
//  Created by keepcoder on 05/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import SwiftSignalKitMac
import TelegramCoreMac

class GlobalBadgeNode: Node {
    private let account:Account
    private let layoutChanged:(()->Void)?
    private let excludePeerId:PeerId?
    private let disposable:MetaDisposable = MetaDisposable()
    private var textLayout:(TextNodeLayout, TextNode)?
    var xInset:CGFloat = 0
    private var attributedString:NSAttributedString? {
        didSet {
            if let attributedString = attributedString {
                textLayout = TextNode.layoutText(maybeNode: nil,  attributedString, nil, 1, .middle, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .left)
                size = NSMakeSize(textLayout!.0.size.width + 8, textLayout!.0.size.height + 7)
                size = NSMakeSize(max(size.height,size.width), size.height)
            } else {
                textLayout = nil
                size = NSZeroSize
            }
            setNeedDisplay()
            if let superview = view?.superview as? View {
                superview.customHandler.layout = { [weak self] view in
                    if let strongSelf = self {
                        if strongSelf.layoutChanged == nil {
                            var origin:NSPoint = NSZeroPoint
                            let center = view.focus(strongSelf.size)
                            origin = NSMakePoint(floorToScreenPixels(scaleFactor: System.backingScale, center.midX) + strongSelf.xInset, 4)
                            origin.x = min(view.frame.width - strongSelf.size.width - 4, origin.x)
                            strongSelf.frame = NSMakeRect(origin.x,origin.y,strongSelf.size.width,strongSelf.size.height)
                        } else {
                            strongSelf.view?.setFrameSize(strongSelf.size)
                        }
                    }
                }
            }
            view?.superview?.needsLayout = true
        }
    }
    
    override func update() {
        let attributedString = self.attributedString
        self.attributedString = attributedString
    }
    
    override func setNeedDisplay() {
        super.setNeedDisplay()
    }
    
    private let getColor: () -> NSColor
    
    init(_ account: Account, sharedContext: SharedAccountContext, dockTile: Bool = false, collectAllAccounts: Bool = false, excludePeerId:PeerId? = nil, view: View? = nil, layoutChanged:(()->Void)? = nil, getColor: @escaping() -> NSColor = { theme.colors.redUI }) {
        self.account = account
        self.excludePeerId = excludePeerId
        self.layoutChanged = layoutChanged
        self.getColor = getColor
        super.init(view)
        
        var items:[UnreadMessageCountsItem] = []
        let peerSignal: Signal<(Peer, Bool)?, NoError>
        if let peerId = excludePeerId {
            items.append(.peer(peerId))
            let notificationKeyView: PostboxViewKey = .peerNotificationSettings(peerIds: Set([peerId]))
            peerSignal = combineLatest(account.postbox.loadedPeerWithId(peerId), account.postbox.combinedView(keys: [notificationKeyView]) |> map { view in
                return ((view.views[notificationKeyView] as? PeerNotificationSettingsView)?.notificationSettings[peerId])?.isRemovedFromTotalUnreadCount ?? false
            }) |> map {Optional($0)}
        } else {
            peerSignal = .single(nil)
        }
        
        let signal: Signal<[(Int32, RenderedTotalUnreadCountType)], NoError>
        if collectAllAccounts {
            signal = sharedContext.activeAccountsWithInfo |> mapToSignal { primaryId, accounts in
                return combineLatest(accounts.filter { $0.account.id != account.id }.map { renderedTotalUnreadCount(accountManager: sharedContext.accountManager, postbox: $0.account.postbox) })
            }
        } else {
            signal = renderedTotalUnreadCount(accountManager: sharedContext.accountManager, postbox: account.postbox) |> map { [$0] }
        }
        
        self.disposable.set((combineLatest(signal, account.postbox.unreadMessageCountsView(items: items), appNotificationSettings(accountManager: sharedContext.accountManager), peerSignal) |> deliverOnMainQueue).start(next: { [weak self] (counts, view, inAppSettings, peerSettings) in
            if let strongSelf = self {
                
                var excludeTotal: Int32 = 0
                
                var dockText: String?
                let totalValue = max(0, counts.reduce(0, { $0 + $1.0 }))
                if totalValue > 0 {
                     dockText = "\(totalValue)"
                }
                
                excludeTotal = totalValue
 
                
                if items.count == 1, let peerSettings = peerSettings {
                    if let count = view.count(for: items[0]), inAppSettings.totalUnreadCountIncludeTags.contains(peerSettings.0.peerSummaryTags), count > 0 {
                        var removable = false
                        switch inAppSettings.totalUnreadCountDisplayStyle {
                        case .raw:
                            removable = true
                        case .filtered:
                            if !peerSettings.1 {
                                removable = true
                            }
                        }
                        if removable {
                            switch inAppSettings.totalUnreadCountDisplayCategory {
                            case .chats:
                                excludeTotal -= 1
                            case .messages:
                                excludeTotal -= count
                            }
                        }
                    }
                }
                
                
                if excludeTotal == 0 {
                    strongSelf.attributedString = nil
                } else {
                    strongSelf.attributedString = .initialize(string: Int(excludeTotal).prettyNumber, color: .white, font: .bold(.small))
                }
                strongSelf.layoutChanged?()
                if dockTile {
                    NSApplication.shared.dockTile.badgeLabel = dockText
                }
            }
        }))
    }
    
    override public func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let view = view {
            ctx.setFillColor(getColor().cgColor)
            
            ctx.round(self.size, self.size.height/2.0)
            ctx.fill(layer.bounds)
            
            if let textLayout = textLayout {
                let focus = view.focus(textLayout.0.size)
                textLayout.1.draw(focus, in: ctx, backingScaleFactor: view.backingScaleFactor, backgroundColor: view.backgroundColor)
            }
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
}
