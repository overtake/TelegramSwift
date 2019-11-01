//
//  WalletBalanceItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import WalletCore

public enum RelativeTimestampFormatDay {
    case today
    case yesterday
}



private func stringForRelativeUpdateTime(day: RelativeTimestampFormatDay, hours: Int32, minutes: Int32) -> String {
    let dayString: String
    switch day {
    case .today:
        dayString = L10n.updatedTodayAt(stringForShortTimestamp(hours: hours, minutes: minutes))
    case .yesterday:
        dayString = L10n.updatedYesterdayAt(stringForShortTimestamp(hours: hours, minutes: minutes))
    }
    return dayString
}


private func lastUpdateTimestampString(statusTimestamp: Int32, relativeTo timestamp: Int32) -> String {
    let difference = timestamp - statusTimestamp
    let expanded = true
    if difference < 60 {
        return L10n.updatedJustNow
    } else if difference < 60 * 60 && !expanded {
        let minutes = difference / 60
        return L10n.updatedMinutesAgoCountable(Int(minutes))
    } else {
        var t: time_t = time_t(statusTimestamp)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        var now: time_t = time_t(timestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        if timeinfo.tm_year != timeinfoNow.tm_year {
            return L10n.updatedAtDate(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))
        }
        
        let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
        if dayDifference == 0 || dayDifference == -1 {
            let day: RelativeTimestampFormatDay
            if dayDifference == 0 {
                if expanded {
                    day = .today
                } else {
                    let hours = difference / (60 * 60)
                    return L10n.updatedHoursAgoCountable(Int(hours))
                }
            } else {
                day = .yesterday
            }
            return stringForRelativeUpdateTime(day: day, hours: timeinfo.tm_hour, minutes: timeinfo.tm_min)
        } else {
            return L10n.updatedAtDate(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))
        }
    }
}


class WalletBalanceItem: GeneralRowItem {
    fileprivate let walletState: WalletState?
    fileprivate let receiveMoney:()->Void
    fileprivate let sendMoney:()->Void
    fileprivate let balanceLayout: TextViewLayout?
    fileprivate let updatedTimestamp: Int64?
    fileprivate let update:()->Void
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, state: WalletState?, updatedTimestamp: Int64?, viewType: GeneralViewType, receiveMoney:@escaping()->Void, sendMoney:@escaping()->Void, update:@escaping()->Void) {
        self.walletState = state
        self.context = context
        self.receiveMoney = receiveMoney
        self.sendMoney = sendMoney
        self.update = update
        self.updatedTimestamp = updatedTimestamp
        if let walletState = walletState {
            let value: String
            if walletState.balance >= 0 {
                value = formatBalanceText(walletState.balance)
            } else {
                value = "0\(Formatter.withSeparator.decimalSeparator!)0"
            }
            let attributed: NSMutableAttributedString = NSMutableAttributedString()
            if let range = value.range(of: Formatter.withSeparator.decimalSeparator) {
                let integralPart = String(value[..<range.lowerBound])
                let fractionalPart = String(value[range.lowerBound...])
                _ = attributed.append(string: integralPart, color: theme.colors.text, font: .medium(35))
                _ = attributed.append(string: fractionalPart, color: theme.colors.text, font: .medium(20))
            } else {
                _ = attributed.append(string: value, color: theme.colors.text, font: .medium(35))
            }
            
            balanceLayout = TextViewLayout(attributed)
        } else {
            balanceLayout = TextViewLayout(.initialize(string: "0", color: theme.colors.text, font: .bold(35)))
        }
        balanceLayout?.measure(width: .greatestFiniteMagnitude)
        
        super.init(initialSize, height: 180, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return WalletBalanceView.self
    }
}

private final class WalletBalanceView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let balanceView: TextView = TextView()
    private let updatedTimestampView = TextView()
    private let receiveButton = TitleButton()
    private let sendButton = TitleButton()
    private let reloadButton = ImageButton()
    private let crystalView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)
    private let animator: ConstantDisplayLinkAnimator
    
    required init(frame frameRect: NSRect) {
        
        var updateImpl: (() -> Void)?
        self.animator = ConstantDisplayLinkAnimator(update: {
            updateImpl?()
        })
        
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(balanceView)
        containerView.addSubview(receiveButton)
        containerView.addSubview(sendButton)
        containerView.addSubview(updatedTimestampView)
        containerView.addSubview(reloadButton)
        containerView.addSubview(crystalView)
        receiveButton.layer?.cornerRadius = .cornerRadius
        sendButton.layer?.cornerRadius = .cornerRadius
        
        updatedTimestampView.userInteractionEnabled = false
        updatedTimestampView.isSelectable = false
        
        receiveButton.disableActions()
        sendButton.disableActions()
        
        updateImpl = { [weak self] in
            self?.updateAnimation()
        }

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? WalletBalanceItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
        
        updatedTimestampView.backgroundColor = backdorColor
        
        receiveButton.set(text: L10n.walletBalanceInfoReceive, for: .Normal)
        receiveButton.set(background: theme.colors.accent, for: .Normal)
        receiveButton.set(background: theme.colors.accent.withAlphaComponent(0.8), for: .Highlight)
        receiveButton.set(color: theme.colors.underSelectedColor, for: .Normal)
        receiveButton.set(font: .medium(.text), for: .Normal)
        receiveButton.set(image: theme.icons.wallet_receive, for: .Normal)
        receiveButton.set(image: theme.icons.wallet_receive, for: .Highlight)

        _ = receiveButton.sizeToFit()
        
        sendButton.set(text: L10n.walletBalanceInfoSend, for: .Normal)
        sendButton.set(background: theme.colors.accent, for: .Normal)
        sendButton.set(background: theme.colors.accent.withAlphaComponent(0.8), for: .Highlight)
        sendButton.set(color: theme.colors.underSelectedColor, for: .Normal)
        sendButton.set(font: .medium(.text), for: .Normal)
        sendButton.set(image: theme.icons.wallet_send, for: .Normal)
        sendButton.set(image: theme.icons.wallet_send, for: .Highlight)

        _ = sendButton.sizeToFit()
        
        reloadButton.set(image: theme.icons.wallet_update, for: .Normal)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? WalletBalanceItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        let midY = containerView.frame.midY - (40 - item.viewType.innerInset.bottom) / 2
        balanceView.centerX(y: midY - balanceView.frame.height, addition: crystalView.frame.width / 2)
        crystalView.setFrameOrigin(NSMakePoint(balanceView.frame.minX - crystalView.frame.width, balanceView.frame.minY - 3))
        updatedTimestampView.centerX(y: balanceView.frame.maxY - 3)
        
        let buttonWidth = sendButton.isHidden ? (item.blockWidth - item.viewType.innerInset.left - item.viewType.innerInset.right) : (item.blockWidth - item.viewType.innerInset.left * 3) / 2
        
        receiveButton.setFrameSize(NSMakeSize(min(buttonWidth, 140), 40))
        sendButton.setFrameSize(NSMakeSize(min(buttonWidth, 140), 40))
        
        if sendButton.isHidden {
            receiveButton.centerX(y: containerView.frame.height - receiveButton.frame.height - item.viewType.innerInset.bottom - 20)
        } else {
            receiveButton.setFrameOrigin(NSMakePoint(containerView.frame.width / 2 - 5 - receiveButton.frame.width, containerView.frame.height - receiveButton.frame.height - 20))
            sendButton.setFrameOrigin(NSMakePoint(containerView.frame.width / 2 + 5, containerView.frame.height - sendButton.frame.height - 20))
        }
        reloadButton.setFrameSize(NSMakeSize(40, 40))
        
        reloadButton.setFrameOrigin(NSMakePoint(containerView.frame.width - reloadButton.frame.width, 0))
    }
    
    private var currentAngle: CGFloat = 0.0
    private var currentExtraSpeed: CGFloat = 0.0
    private var animateToZeroState: (Double, CGFloat)?
    private var currentTextIndex: Int = 0
    
    private func updateAnimation() {
        guard let item = item as? WalletBalanceItem else {
            return
        }
        var speed: CGFloat = 0.0
        var baseValue: CGFloat = 0.0
        
        if item.updatedTimestamp == nil {
            speed = 0.01
            self.animateToZeroState = nil
        } else {
            if self.currentExtraSpeed.isZero && self.animateToZeroState == nil && !self.currentAngle.isZero {
                self.animateToZeroState = (CACurrentMediaTime(), self.currentAngle)
                
            }
        }
        

        
        if let (startTime, startValue) = self.animateToZeroState {
            let endValue: CGFloat = floor(startValue) + 1.0
            let duration: Double = Double(endValue - startValue) * 1.0
            let timeDelta = (startTime + duration - CACurrentMediaTime())
            let t: CGFloat = 1.0 - CGFloat(max(0.0, min(1.0, timeDelta / duration)))
            if t >= 1.0 - CGFloat.ulpOfOne {
                self.animateToZeroState = nil
                self.currentAngle = 0.0
            } else {
                let bt = bezierPoint(0.23, 1.0, 0.32, 1.0, t)
                self.currentAngle = startValue * (1.0 - bt) + endValue * bt
            }
        } else {
            self.currentAngle += speed + self.currentExtraSpeed
        }
        self.currentExtraSpeed *= 0.97
        if abs(self.currentExtraSpeed) < 0.0001 {
            self.currentExtraSpeed = 0.0
        }
        
        self.reloadButton.layer?.anchorPoint = NSMakePoint(0.5, 0.5)
        self.reloadButton.layer?.position = NSMakePoint(containerView.frame.width - reloadButton.frame.width + 20, 20)
        self.reloadButton.layer?.transform = CATransform3DMakeRotation((baseValue + self.currentAngle) * CGFloat.pi * 2.0, 0.0, 0.0, 1.0)
        
        
        let updatedTimestampLayout: TextViewLayout
        if let updatedTimestamp = item.updatedTimestamp {
            updatedTimestampLayout = TextViewLayout(.initialize(string: lastUpdateTimestampString(statusTimestamp: Int32(updatedTimestamp), relativeTo: Int32(Date().timeIntervalSince1970)), color: theme.colors.grayText, font: .normal(12)))
        } else {
            let text: String
            if currentTextIndex <= 15 {
                 text = L10n.walletBalanceInfoUpdating1
            } else if currentTextIndex <= 30 {
                text = L10n.walletBalanceInfoUpdating2
            } else {
                text = L10n.walletBalanceInfoUpdating3
            }
            updatedTimestampLayout = TextViewLayout(.initialize(string: text, color: theme.colors.grayText, font: .normal(12)))
            
            currentTextIndex += 1
            
            if currentTextIndex > 45 {
                currentTextIndex = 0
            }
        }
        updatedTimestampLayout.measure(width: .greatestFiniteMagnitude)
        self.updatedTimestampView.update(updatedTimestampLayout)
        if !self.currentExtraSpeed.isZero || !speed.isZero || self.animateToZeroState != nil {
            self.animator.isPaused = false
        } else {
            self.animator.isPaused = true
            self.currentTextIndex = 0
        }
    }

    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WalletBalanceItem else {
            return
        }
        
        crystalView.update(with: WalletAnimatedSticker.brilliant_static.file, size: NSMakeSize(44, 44), context: item.context, parent: nil, table: nil, parameters: WalletAnimatedSticker.brilliant_static.parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: true)
        
        sendButton.isHidden = item.walletState?.balance == -1
        
        receiveButton.removeAllHandlers()
        receiveButton.set(handler: { [weak item] _ in
            item?.receiveMoney()
        }, for: .Click)
        
        sendButton.removeAllHandlers()
        sendButton.set(handler: { [weak item] _ in
            item?.sendMoney()
        }, for: .Click)
        
        reloadButton.removeAllHandlers()
        reloadButton.set(handler: { [weak item] _ in
            item?.update()
        }, for: .Click)
        
        if item.updatedTimestamp == nil {
            updateAnimation()
        }
        
        balanceView.update(item.balanceLayout)
        
        let updatedTimestampLayout: TextViewLayout
        if let updatedTimestamp = item.updatedTimestamp {
            updatedTimestampLayout = TextViewLayout(.initialize(string: lastUpdateTimestampString(statusTimestamp: Int32(updatedTimestamp), relativeTo: Int32(Date().timeIntervalSince1970)), color: theme.colors.grayText, font: .normal(12)))
        } else {
            updatedTimestampLayout = TextViewLayout(.initialize(string: L10n.walletBalanceInfoUpdating3, color: theme.colors.grayText, font: .normal(12)))
        }
        updatedTimestampLayout.measure(width: .greatestFiniteMagnitude)
        updatedTimestampView.update(updatedTimestampLayout)
        needsLayout = true
    }
    
}
