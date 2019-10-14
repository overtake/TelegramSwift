//
//  WalletInfoTransactionItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit


class WalletInfoTransactionItem: GeneralRowItem {
    fileprivate let transaction: WalletInfoTransaction
    fileprivate let titleLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    fileprivate let addressLayout: TextViewLayout
    fileprivate let commentLayout: TextViewLayout?
    fileprivate let feeLayout: TextViewLayout?
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, transaction: WalletInfoTransaction, viewType: GeneralViewType, action: @escaping()->Void) {
        self.transaction = transaction
        self.context = context
        let title: String
        let directionText: String
        let titleColor: NSColor
        
        let transferredValue: Int64
        switch transaction {
        case let .completed(transaction):
            transferredValue = transaction.transferredValueWithoutFees
        case let .pending(transaction):
            transferredValue = -transaction.value
        }
        let address = stringForAddress(address: extractAddress(transaction))
        var singleAddress: String?
        let comment = extractDescription(transaction)
        


        var text: String = ""
        if transferredValue <= 0 {
            
            title = "\(formatBalanceText(abs(transferredValue)))"
            titleColor = theme.colors.redUI
            
            switch transaction {
            case let .completed(transaction):
                if transaction.outMessages.isEmpty {
                    directionText = ""
                    text = L10n.walletTransactionEmptyTransaction
                } else {
                    directionText = L10n.walletTransactionTo
                    for message in transaction.outMessages {
                        if !text.isEmpty {
                            text.append("\n")
                        }
                        text.append(formatAddress(message.destination))
                    }
                }
            case let .pending(transaction):
                directionText = L10n.walletTransactionTo
                if !text.isEmpty {
                    text.append("\n")
                }
                text.append(formatAddress(transaction.address))
            }
        } else {
            title = "\(formatBalanceText(transferredValue))"
            titleColor = theme.colors.greenUI
            directionText = L10n.walletTransactionFrom
            switch transaction {
            case let .completed(transaction):
                if let inMessage = transaction.inMessage {
                    text = formatAddress(inMessage.source)
                } else {
                    text = "<unknown>"
                }
            case .pending:
                text = "<unknown>"
            }

        }
        
        switch transaction {
        case let .completed(transaction):
            let fees = transaction.otherFee + transaction.storageFee
            if fees > 0 {
                self.feeLayout = TextViewLayout(.initialize(string: L10n.walletBalanceInfoTransactionFees(formatBalanceText(fees)), color: theme.colors.grayText, font: .normal(.text)))
            } else {
                self.feeLayout = nil
            }
        default:
            self.feeLayout = nil
        }
        
        
        let date = Date(timeIntervalSince1970: TimeInterval(transaction.timestamp) - context.timeDifference)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let dateText = formatter.string(from: date)
        
        let titleAttr = NSMutableAttributedString()
        
        
        if let range = title.range(of: Formatter.withSeparator.decimalSeparator) {
            let integralPart = String(title[..<range.lowerBound])
            let fractionalPart = String(title[range.lowerBound...])
            _ = titleAttr.append(string: integralPart, color: titleColor, font: .medium(15.0))
            _ = titleAttr.append(string: fractionalPart, color: titleColor, font: .normal(11.5))
        } else {
            _ = titleAttr.append(string: title, color: titleColor, font: .medium(15.0))
        }
        
        _ = titleAttr.append(string: " " + directionText, color: theme.colors.grayText, font: .normal(.title))
        self.titleLayout = TextViewLayout(titleAttr)
        
        
        let addressString: String
        if text.count % 2 == 0 {
            addressString = text//String(text.prefix(text.count / 2) + "\n" + text.suffix(text.count / 2))
        } else {
            addressString = text
        }
        
        
        self.dateLayout = TextViewLayout(.initialize(string: dateText, color: theme.colors.grayText, font: .normal(11.5)))
        self.addressLayout = TextViewLayout(.initialize(string: addressString, color: theme.colors.text, font: .blockchain(.text)))
        
        if !comment.isEmpty {
            commentLayout = TextViewLayout(.initialize(string: comment, color: theme.colors.grayText, font: .normal(.text)))
        } else {
            commentLayout = nil
        }
        
        super.init(initialSize, stableId: stableId, viewType: viewType, action: action)
    }
    
    override var height: CGFloat {
        var height: CGFloat = self.viewType.innerInset.top + max(self.dateLayout.layoutSize.height, self.titleLayout.layoutSize.height) + self.addressLayout.layoutSize.height + 4 + self.viewType.innerInset.bottom
        
        if let commentLayout = commentLayout {
            height += commentLayout.layoutSize.height + 4
        }
        if let feeLayout = self.feeLayout {
            height += feeLayout.layoutSize.height + 4
        }
        
        return height
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        self.dateLayout.measure(width: .greatestFiniteMagnitude)
        self.titleLayout.measure(width: .greatestFiniteMagnitude)
        
        self.addressLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        self.commentLayout?.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        self.feeLayout?.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return WalletInfoTransactionView.self
    }
    
}

private final class WalletInfoTransactionView: TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private var pendingView: SendingClockProgress?
    private let crystalView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)
    private let borderView: View = View()
    private let titleView = TextView()
    private let dateView = TextView()
    private let addressView = TextView()
    private let commentsView = TextView()
    private let feeView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.containerView)
        
        self.containerView.addSubview(borderView)
        self.containerView.addSubview(titleView)
        self.containerView.addSubview(dateView)
        self.containerView.addSubview(addressView)
        self.containerView.addSubview(commentsView)
        self.containerView.addSubview(feeView)
        self.containerView.addSubview(crystalView)
        titleView.userInteractionEnabled = false
        dateView.userInteractionEnabled = false
        addressView.userInteractionEnabled = false
        commentsView.userInteractionEnabled = false
        feeView.userInteractionEnabled = false
        titleView.isSelectable = false
        dateView.isSelectable = false
        commentsView.isSelectable = false
        feeView.isSelectable = false
        self.containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? GeneralRowItem  {
                item.action()
            }
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? WalletInfoTransactionItem else {
            return
        }
        
        let highlighted = item.viewType == .legacy ? self.backdorColor : theme.colors.grayHighlight
        
        self.backgroundColor = item.viewType.rowBackground
        self.borderView.backgroundColor = theme.colors.border
        self.titleView.backgroundColor = containerView.controlState == .Highlight ? highlighted : backdorColor
        self.dateView.backgroundColor = containerView.controlState == .Highlight ? highlighted : backdorColor
        self.addressView.backgroundColor = containerView.controlState == .Highlight ? highlighted : backdorColor
        self.commentsView.backgroundColor = containerView.controlState == .Highlight ? highlighted : backdorColor
        self.feeView.backgroundColor = containerView.controlState == .Highlight ? highlighted : backdorColor
        containerView.set(background: self.backdorColor, for: .Normal)
        containerView.set(background: highlighted, for: .Highlight)
        
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? WalletInfoTransactionItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        titleView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left + crystalView.frame.width, item.viewType.innerInset.top))
        crystalView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top - 1))
        dateView.setFrameOrigin(NSMakePoint(item.blockWidth - dateView.frame.width - item.viewType.innerInset.right, item.viewType.innerInset.top))
        addressView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, titleView.frame.maxY + 4))
        commentsView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, addressView.frame.maxY + 4))
        
        if let pendingView = pendingView {
            pendingView.setFrameOrigin(NSMakePoint(item.blockWidth - pendingView.frame.width - item.viewType.innerInset.right - dateView.frame.width - 3, item.viewType.innerInset.top))
        }

        let feeUpperView: NSView = commentsView.layout != nil ? commentsView : addressView
        feeView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, feeUpperView.frame.maxY + 4))
        
        borderView.frame = NSMakeRect(item.viewType.innerInset.left, self.containerView.frame.height - .borderSize, item.blockWidth - item.viewType.innerInset.left - item.viewType.innerInset.right, .borderSize)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WalletInfoTransactionItem else {
            return
        }
        
        self.dateView.update(item.dateLayout)
        self.titleView.update(item.titleLayout)
        self.addressView.update(item.addressLayout)
        self.commentsView.update(item.commentLayout)
        self.feeView.update(item.feeLayout)
        borderView.isHidden = !item.viewType.hasBorder
        
        switch item.transaction {
        case .pending:
            if pendingView == nil {
                pendingView = SendingClockProgress()
                containerView.addSubview(pendingView!)
            }
            self.pendingView?.applyGray()
        case .completed:
            if let pendingView = self.pendingView {
                self.pendingView = nil
                if animated {
                    pendingView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak pendingView] _ in
                        pendingView?.removeFromSuperview()
                    })
                } else {
                    pendingView.removeFromSuperview()
                }
            }
        }
        
        let parameters = ChatAnimatedStickerMediaLayoutParameters(playPolicy: .once, media: WalletAnimatedSticker.brilliant_static.file)
        
        crystalView.update(with: WalletAnimatedSticker.brilliant_static.file, size: NSMakeSize(16, 16), context: item.context, parent: nil, table: nil, parameters: parameters, animated: animated, positionFlags: nil, approximateSynchronousValue: true)

        
        needsLayout = true
    }
    
}
