//
//  GlobalBadgeNode.swift
//  TelegramMac
//
//  Created by keepcoder on 05/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import InAppSettings



class GlobalBadgeNode: Node {
    private let account:Account
    private let sharedContext: SharedAccountContext
    private let layoutChanged:(()->Void)?
    private let excludePeerId:PeerId?
    private let disposable:MetaDisposable = MetaDisposable()
    private var textLayout:(TextNodeLayout, TextNode)?
    var customLayout: Bool = false
    var xInset:CGFloat = 0
    var onUpdate:(()->Void)?
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
            if let superview = view?.superview as? View, !self.customLayout {
                superview.customHandler.layout = { [weak self] view in
                    if let strongSelf = self {
                        if strongSelf.layoutChanged == nil {
                            var origin:NSPoint = NSZeroPoint
                            let center = view.focus(strongSelf.size)
                            origin = NSMakePoint(floorToScreenPixels(System.backingScale, center.midX) + strongSelf.xInset, 4)
                            origin.x = min(view.frame.width - strongSelf.size.width - 4, origin.x)
                            strongSelf.frame = NSMakeRect(origin.x,origin.y,strongSelf.size.width,strongSelf.size.height)
                        } else {
                            strongSelf.view?.setFrameSize(strongSelf.size)
                            strongSelf.layoutChanged?()
                        }
                    }
                }
            }
            view?.superview?.needsLayout = true
            onUpdate?()
        }
    }
    
    override func update() {
        let attributedString = self.attributedString
        self.attributedString = attributedString
    }
    
    override func setNeedDisplay() {
        super.setNeedDisplay()
    }
    
    var isSelected: Bool = false {
        didSet {
            if oldValue != self.isSelected {
                self.view?.needsDisplay = true
                let copy = self.attributedString?.mutableCopy() as? NSMutableAttributedString
                guard let attr = copy else {
                    return
                }
                attr.addAttribute(.foregroundColor, value: getColor(!isSelected), range: attr.range)
                self.attributedString = copy
            }
        }
    }
    
    private let getColor: (Bool) -> NSColor
    
    init(_ account: Account, sharedContext: SharedAccountContext, dockTile: Bool = false, collectAllAccounts: Bool = false, excludePeerId:PeerId? = nil, excludeGroupId: PeerGroupId? = nil, view: View? = nil, layoutChanged:(()->Void)? = nil, getColor: @escaping(Bool) -> NSColor = { _ in return theme.colors.redUI }, fontSize: CGFloat = .small, applyFilter: Bool = true, filter: ChatListFilter? = nil, removeWhenSidebar: Bool = false, sync: Bool = false) {
        self.account = account
        self.excludePeerId = excludePeerId
        self.layoutChanged = layoutChanged
        self.sharedContext = sharedContext
        self.getColor = getColor
        super.init(view)
        
        struct Result : Equatable {
            let dockText: String?
            let total:Int32
            init(dockText: String?, total: Int32) {
                self.dockText = dockText
                self.total = max(total, 0)
            }
        }
        
        var items:[UnreadMessageCountsItem] = []
        let peerSignal: Signal<(Peer, Bool)?, NoError>
        
        
        
        
        if let peerId = excludePeerId {
            items.append(.peer(id: peerId, handleThreads: true))
            let notificationKeyView: PostboxViewKey = .peerNotificationSettings(peerIds: Set([peerId]))
            peerSignal = combineLatest(account.postbox.loadedPeerWithId(peerId), account.postbox.combinedView(keys: [notificationKeyView]) |> map { view in
                return ((view.views[notificationKeyView] as? PeerNotificationSettingsView)?.notificationSettings[peerId])?.isRemovedFromTotalUnreadCount(default: false) ?? false
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
        
        var unreadCountItems: [UnreadMessageCountsItem] = []
        unreadCountItems.append(.total(nil))
        let keys: [PostboxViewKey] = []
        
        var s:Signal<Result, NoError>
        
        if let filter = filter {
            s = chatListFilterItems(engine: TelegramEngine(account: account), accountManager: sharedContext.accountManager) |> map { value in
                if let unread = value.count(for: filter) {
                    return Result(dockText: nil, total: Int32(unread.count))
                } else {
                    return Result(dockText: nil, total: 0)
                }
            } |> deliverOnMainQueue
        } else {
            s = combineLatest(signal, account.postbox.unreadMessageCountsView(items: items), account.postbox.combinedView(keys: keys), appNotificationSettings(accountManager: sharedContext.accountManager), peerSignal) |> map { (counts, view, keysView, inAppSettings, peerSettings) in
                
                if !applyFilter || filter == nil {
                    var excludeTotal: Int32 = 0
                    
                    var dockText: String?
                    let totalValue = !inAppSettings.badgeEnabled  ? 0 : (collectAllAccounts && !inAppSettings.notifyAllAccounts ? 0 : max(0, counts.reduce(0, { $0 + $1.0 })))
                    if totalValue > 0 {
                        dockText = "\(max(0, totalValue))"
                    }
                    
                    excludeTotal = totalValue
                    
                    if items.count == 1, let peerSettings = peerSettings {
                        if let count = view.count(for: items[0]), count > 0 {
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
                    return Result(dockText: dockText, total: excludeTotal)
                }
                return Result(dockText: nil, total: 0)
            } |> deliverOnMainQueue
        }
        
        s = combineLatest(s, chatListFolderSettings(account.postbox)) |> map {
            return Result(dockText: $0.dockText, total: $1.sidebar && removeWhenSidebar ? 0 : $0.total)
        } |> deliverOnMainQueue
        
        let semaphore = DispatchSemaphore(value: 0)
        
        
        self.disposable.set(s.start(next: { [weak self] result in
            if let strongSelf = self {
                                
                if result.total == 0 {
                    strongSelf.attributedString = nil
                } else {
                    strongSelf.attributedString = .initialize(string: Int(result.total).prettyNumber, color: getColor(strongSelf.isSelected) != theme.colors.redUI ?  theme.colors.underSelectedColor : .white, font: .bold(fontSize))
                }
                strongSelf.layoutChanged?()
                
                if dockTile {
                    NSApplication.shared.dockTile.badgeLabel = result.dockText
                    forceUpdateStatusBarIconByDockTile(sharedContext: sharedContext)
                }
            }
            if sync {
                semaphore.signal()
            }
        }))
        
        if sync {
            semaphore.wait()
        }
    }
    
    override public func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let view = view {
            ctx.setFillColor(getColor(isSelected).cgColor)
            
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

func forceUpdateStatusBarIconByDockTile(sharedContext: SharedAccountContext) {
    if let count = Int(NSApplication.shared.dockTile.badgeLabel ?? "0") {
        var color: NSColor = .black
        if #available(OSX 10.14, *) {
            if systemAppearance.name != .aqua {
                color = .white
            }
        }
        if #available(OSX 11.0, *) {
            color = .white
        }
        resourcesQueue.async {
            let icon = generateStatusBarIcon(count, color: color)
            Queue.mainQueue().async {
                 sharedContext.updateStatusBarImage(icon)
            }
        }
       
    }
}

private func generateStatusBarIcon(_ unreadCount: Int, color: NSColor) -> NSImage {
    let icon = NSImage(named: "StatusIcon")!
//    if unreadCount > 0 {
//        return NSImage(cgImage: icon.precomposed(whitePalette.redUI), size: icon.size)
//    } else {
//        return icon
//    }
    
    var string = "\(unreadCount)"
    if string.count > 3 {
        string = ".." + string.nsstring.substring(from: string.length - 2)
    }
    let attributedString = NSAttributedString.initialize(string: string, color: .white, font: .medium(8), coreText: true)
    
    let textLayout = TextNode.layoutText(maybeNode: nil,  attributedString, nil, 1, .start, NSMakeSize(18, CGFloat.greatestFiniteMagnitude), nil, false, .center)
    
    let generated: CGImage?
    if unreadCount > 0 {
        generated = generateImage(NSMakeSize(max((textLayout.0.size.width + 4), (textLayout.0.size.height + 4)), (textLayout.0.size.height + 2)), scale: nil, rotatedContext: { size, ctx in
            let rect = NSMakeRect(0, 0, size.width, size.height)
            ctx.clear(rect)
            
            ctx.setFillColor(NSColor.red.cgColor)
            
            
            ctx.round(size, size.height/2.0)
            ctx.fill(rect)
            
            ctx.setBlendMode(.clear)
            let focus = NSMakePoint((rect.width - textLayout.0.size.width) / 2, (rect.height - textLayout.0.size.height) / 2)
            textLayout.1.draw(NSMakeRect(focus.x, 2, textLayout.0.size.width, textLayout.0.size.height), in: ctx, backingScaleFactor: 2.0, backgroundColor: .white)
            
        })!
    } else {
        generated = nil
    }
        
    let full = generateImage(NSMakeSize(24, 20), contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        
 
        ctx.draw(icon.precomposed(color), in: NSMakeRect((size.width - icon.size.width) / 2, 2, icon.size.width, icon.size.height))
        
        
        if let generated = generated {
            ctx.setBlendMode(.clear)
            
            let cgPath = CGMutablePath()
            
            let clearSize = NSMakeSize(generated.size.width + 1, generated.size.height + 1)
            cgPath.addRoundedRect(in: NSMakeRect(rect.width - clearSize.width / System.backingScale, 0, clearSize.width / System.backingScale, clearSize.height / System.backingScale), cornerWidth: clearSize.height / System.backingScale / 2, cornerHeight: clearSize.height / System.backingScale / 2)
            
            ctx.addPath(cgPath)
            ctx.fillPath()
            ctx.setBlendMode(.normal)
            ctx.draw(generated, in: NSMakeRect(rect.width - generated.size.width / System.backingScale, 0, generated.size.width / System.backingScale, generated.size.height / System.backingScale))
        }
    })!
    let image = NSImage(cgImage: full, size: full.backingSize)
    image.isTemplate = true
    return image
}
