//
//  ProxyListRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox

class ProxyListRowItem: GeneralRowItem {
    fileprivate let headerLayout: TextViewLayout
    fileprivate let statusLayout: TextViewLayout
    fileprivate let delete:()->Void
    fileprivate let info:()->Void
    fileprivate let status: (isConnecting: Bool, isCurrent: Bool)
    fileprivate let waiting: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, proxy: ProxyServerSettings, waiting: Bool, connectionStatus: ConnectionStatus?, status: ProxyServerStatus?, viewType: GeneralViewType, action:@escaping()->Void, info:@escaping()->Void, delete:@escaping()->Void) {
        self.delete = delete
        self.info = info
        self.waiting = waiting
        let attr = NSMutableAttributedString()
        let title: String
        switch proxy.connection {
        case .socks5:
            title = L10n.proxySettingsSocks5
        case .mtp:
             title = L10n.proxySettingsMTP
        }
        _ = attr.append(string: "\(proxy.host)", color: theme.colors.text, font: .medium(.text))
        _ = attr.append(string: ":\(proxy.port)", color: theme.colors.grayText, font: .normal(.text))

        self.headerLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
        
        var statusText: String
        var color: NSColor = theme.colors.grayText
        if let connectionStatus = connectionStatus {
            switch connectionStatus {
            case .connecting:
                statusText = L10n.connectingStatusConnecting
                self.status = (isConnecting: true, isCurrent: true)
            case .waitingForNetwork:
                statusText = L10n.connectingStatusConnecting
                self.status = (isConnecting: true, isCurrent: true)
            case .online, .updating:
                statusText = L10n.proxySettingsItemConnected
                if let status = status {
                    switch status {
                    case let .available(ping):
                        statusText = L10n.proxySettingsItemConnectedPing("\(Int(ping * 1000))")
                    default:
                        break
                    }
                }
                color = theme.colors.accent
                self.status = (isConnecting: false, isCurrent: true)
            }
        } else {
            statusText = L10n.proxySettingsItemNeverConnected
            if let status = status {
                switch status {
                case .notAvailable:
                    color = theme.colors.redUI
                case let .available(ping):
                    statusText = L10n.proxySettingsItemAvailable("\(Int(ping * 1000))") //"available (ping: \(ping * 1000)ms)"
                case .checking:
                    statusText = L10n.proxySettingsItemChecking
                }
            }
            
            self.status = (isConnecting: false, isCurrent: false)
        }
        statusText = title.lowercased() + ": " + statusText

        self.statusLayout = TextViewLayout(.initialize(string: statusText, color: color, font: .normal(.text)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 50, stableId: stableId, viewType: viewType, action: action, inset: NSEdgeInsetsMake(0, 30, 0, 30))
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        switch viewType {
        case .legacy:
            headerLayout.measure(width: width - inset.left - inset.right - 80)
            statusLayout.measure(width: width - inset.left - inset.right - 80)
        case let .modern(_, insets):
            headerLayout.measure(width: blockWidth - insets.left - insets.right - 100)
            statusLayout.measure(width: blockWidth - insets.left - insets.right - 100)
        }
        return success
    }
    
    override func viewClass() -> AnyClass {
        return ProxyListRowView.self
    }
}


private final class ProxyListRowView : GeneralRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let headerView: TextView = TextView()
    private let statusView: TextView = TextView()
    private let delete: ImageButton = ImageButton()
    private let info: ImageButton = ImageButton()
    private let connectingView: ProgressIndicator = ProgressIndicator()
    private let connected:ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        headerView.userInteractionEnabled = false
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        headerView.isSelectable = false
        containerView.addSubview(delete)
        containerView.addSubview(headerView)
        containerView.addSubview(statusView)
        containerView.addSubview(info)
        containerView.addSubview(connectingView)
        containerView.addSubview(connected)
        addSubview(containerView)
        
        containerView.displayDelegate = self
        
        containerView.set(handler: { [weak self] _ in
            guard let item = self?.item as? ProxyListRowItem else {return}
            item.action()
        }, for: .Click)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        
        delete.set(handler: { [weak self] _ in
            guard let item = self?.item as? ProxyListRowItem else {return}
            item.delete()
        }, for: .Click)
        
        info.set(handler: { [weak self] _ in
            guard let item = self?.item as? ProxyListRowItem else {return}
            item.info()
        }, for: .Click)
    }
    
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? ProxyListRowItem else {return}
        
        let highlighted = item.viewType == .legacy ? self.backdorColor : theme.colors.grayHighlight
        headerView.backgroundColor = containerView.controlState == .Highlight ? highlighted : backdorColor
        statusView.backgroundColor = containerView.controlState == .Highlight ? highlighted : backdorColor
        self.layer?.backgroundColor = item.viewType.rowBackground.cgColor
        
        containerView.set(background: self.backdorColor, for: .Normal)
        containerView.set(background: highlighted, for: .Highlight)

    }
    
    override func layout() {
        super.layout()
        guard let item = item as? ProxyListRowItem else {return}

        switch item.viewType {
        case .legacy:
            self.containerView.frame = self.bounds
            self.containerView.setCorners([])
            headerView.setFrameOrigin(item.inset.left + item.inset.left, 7)
            statusView.setFrameOrigin(item.inset.left + item.inset.left, self.containerView.frame.height - statusView.frame.height - 7)
            delete.centerY(x: self.containerView.frame.width - delete.frame.width - item.inset.right)
            info.centerY(x: self.containerView.frame.width - delete.frame.width - item.inset.right - 10 - info.frame.width)
            connected.centerY(x: 30)
            connectingView.centerY(x: 30)
        case let .modern(position, innerInsets):
            self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
            self.containerView.setCorners(position.corners)
            headerView.setFrameOrigin(innerInsets.left + item.inset.left, 7)
            statusView.setFrameOrigin(innerInsets.left + item.inset.left, self.containerView.frame.height - statusView.frame.height - 7)
            delete.centerY(x: self.containerView.frame.width - delete.frame.width - innerInsets.right)
            info.centerY(x: self.containerView.frame.width - delete.frame.width - innerInsets.right - 10 - info.frame.width)
            connected.centerY(x: innerInsets.left + 2)
            connectingView.centerY(x: innerInsets.left + 2)
        }
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? ProxyListRowItem else {return}
        if layer == containerView.layer {
            ctx.setFillColor(theme.colors.border.cgColor)
            switch item.viewType {
            case .legacy:
                ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
            case let .modern(position, insets):
                switch position {
                case .first, .inner:
                    ctx.fill(NSMakeRect(insets.left + 30, containerView.frame.height - .borderSize, containerView.frame.width - item.inset.left - item.inset.right, .borderSize))
                default:
                    break
                }
            }
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ProxyListRowItem else {return}
        
        switch item.viewType {
        case .legacy:
            containerView.setCorners([], animated: animated)
        case let .modern(position, _):
            containerView.setCorners(position.corners, animated: animated)
        }
        
        headerView.update(item.headerLayout)
        statusView.update(item.statusLayout)
        
        connected.isHidden = (!item.status.isCurrent || item.status.isConnecting) && !item.waiting
        connectingView.isHidden = !item.status.isCurrent || !item.status.isConnecting
        
        connected.image = item.waiting ? theme.icons.proxyNextWaitingListItem : theme.icons.proxyConnectedListItem
        connected.sizeToFit()
        
        connectingView.progressColor = theme.colors.indicatorColor
        
        delete.set(image: theme.icons.proxyDeleteListItem, for: .Normal)
        _ = delete.sizeToFit()
        
        info.set(image: theme.icons.proxyInfoListItem, for: .Normal)
        _ = info.sizeToFit()
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
