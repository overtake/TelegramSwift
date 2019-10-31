//
//  WalletSplashRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac

extension WalletSplashMode {
    var splashAnimation: String {
        switch self {
        case .intro:
            return "❤️"
        default:
            return "👍"
        }
    }
    var title: String {
        switch self {
        case .intro:
            return "Gram Wallet"
        case .created:
            return "Congratulations"
        case .success:
            return "Ready to go!"
        case .restoreFailed:
            return "Too Bad"
        }
    }
    var desc: String {
        switch self {
        case .intro:
            return "Gram wallet allows you to make fast and secure blockchain-based payments without intermediaries."
        case .created:
            return "Your Gram wallet has just been created. Only you control it.\n\nTo be able to always have access to it, please write down secret words and\nset up a secure passcode."
        case .success:
            return "You’re all set. Now you have a wallet that only you control - directly, without middlemen or bankers. "
        case .restoreFailed:
            return "Without the secret words, you can't'nrestore access to the wallet."
        }
    }
}

class WalletSplashRowItem: GeneralRowItem {
    fileprivate let mode:WalletSplashMode
    fileprivate let descLayout: TextViewLayout
    fileprivate let titleLayout: TextViewLayout
    fileprivate let animation: TelegramMediaFile?
    fileprivate let context: AccountContext
    private var h: CGFloat = 0
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, mode: WalletSplashMode, animations: [String: TelegramMediaFile], viewType: GeneralViewType) {
        self.mode = mode
        self.context = context
        self.animation = animations[mode.splashAnimation]
        self.descLayout = TextViewLayout(.initialize(string: mode.desc, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        self.titleLayout = TextViewLayout(.initialize(string: mode.title, color: theme.colors.text, font: .medium(.huge)), alignment: .center)

        super.init(initialSize, stableId: stableId, viewType: viewType)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override var height: CGFloat {
        return self.h
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.descLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)
        self.titleLayout.measure(width: self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right)

        self.h = self.viewType.innerInset.top + self.viewType.innerInset.bottom + self.descLayout.layoutSize.height + self.viewType.innerInset.top + self.titleLayout.layoutSize.height + self.viewType.innerInset.top + 150
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return WalletIntroRowView.self
    }
}


private final class WalletIntroRowView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let titleView = TextView()
    private let descView = TextView()
    private let animationView: ChatMediaAnimatedStickerView = ChatMediaAnimatedStickerView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(animationView)
        containerView.addSubview(titleView)
        containerView.addSubview(descView)
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        descView.userInteractionEnabled = false
        descView.isSelectable = false
        addSubview(containerView)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? WalletSplashRowItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.titleView.background = backdorColor
        self.descView.background = backdorColor
        self.containerView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? WalletSplashRowItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        animationView.centerX(y: item.viewType.innerInset.top)
        titleView.centerX(y: animationView.frame.maxY + item.viewType.innerInset.top)
        descView.centerX(y: titleView.frame.maxY + item.viewType.innerInset.top)

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WalletSplashRowItem else {
            return
        }
        titleView.update(item.titleLayout)
        descView.update(item.descLayout)
        if let animation = item.animation {
            animationView.update(with: animation, size: NSMakeSize(150, 150), context: item.context, parent: nil, table: item.table, parameters: nil, animated: animated, positionFlags: nil, approximateSynchronousValue: !animated)
        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
