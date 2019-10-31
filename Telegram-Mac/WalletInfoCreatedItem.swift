//
//  WalletInfoCreatedItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac


class WalletInfoCreatedItem: GeneralRowItem {
    fileprivate let addressLayout: TextViewLayout
    fileprivate let headerView: TextViewLayout
    fileprivate let yourWalletAddress: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let animation: TelegramMediaFile = WalletAnimatedSticker.chiken_born.file
    private var _h: CGFloat = 0
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, address: String, viewType: GeneralViewType) {
        var addressString: String
        if address.count % 2 == 0 {
            addressString = String(address.prefix(address.count / 2) + "\n" + address.suffix(address.count / 2))
        } else {
            addressString = address
        }
//        addressString = Array(addressString).map { String($0) }.joined(separator: " ")
        self.addressLayout = TextViewLayout(.initialize(string: addressString, color: theme.colors.listGrayText, font: .blockchain(.title)), alignment: .center)
        self.yourWalletAddress = TextViewLayout(.initialize(string: L10n.walletInfoWalletCreatedText, color: theme.colors.listGrayText, font: .normal(.title)))
        self.headerView = TextViewLayout(.initialize(string: L10n.walletInfoWalletCreatedHeader, color: theme.colors.listGrayText, font: .bold(22)))
        self.context = context
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        _ = self.addressLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        _ = self.yourWalletAddress.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        _ = self.headerView.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        var height = self.viewType.innerInset.top + addressLayout.layoutSize.height + self.viewType.innerInset.top + self.yourWalletAddress.layoutSize.height + self.viewType.innerInset.top + self.headerView.layoutSize.height + self.viewType.innerInset.bottom
        
        height += 150 + self.viewType.innerInset.top

        self._h = height
        return true
    }
    
    override var height: CGFloat {
        return _h
    }
    
    override func viewClass() -> AnyClass {
        return WalletInfoCreatedView.self
    }
}


private final class WalletInfoCreatedView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let headerView: TextView = TextView()
    private let descView: TextView = TextView()
    private let addressView: TextView = TextView()
    private let animationView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSZeroRect)

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        headerView.isSelectable = false
        descView.isSelectable = false
        containerView.addSubview(headerView)
        containerView.addSubview(descView)
        containerView.addSubview(addressView)
        containerView.addSubview(animationView)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func updateColors() {
        guard let item = item as? WalletInfoCreatedItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? WalletInfoCreatedItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        animationView.centerX(y: item.viewType.innerInset.top)
        headerView.centerX(y: animationView.frame.maxY + item.viewType.innerInset.top)
        descView.centerX(y: headerView.frame.maxY + item.viewType.innerInset.top)
        addressView.centerX(y: descView.frame.maxY + item.viewType.innerInset.top)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WalletInfoCreatedItem else {
            return
        }
        
        addressView.update(item.addressLayout)
        descView.update(item.yourWalletAddress)
        headerView.update(item.headerView)
        
        animationView.update(with: item.animation, size: NSMakeSize(150, 150), context: item.context, parent: nil, table: item.table, parameters: nil, animated: animated, positionFlags: nil, approximateSynchronousValue: !animated)
    }
}
