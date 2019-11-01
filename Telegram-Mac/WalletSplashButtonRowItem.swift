//
//  WalletSplashButtonRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore



@available (OSX 10.12, *)
class WalletSplashButtonRowItem: GeneralRowItem {
    fileprivate let subTextLayout: TextViewLayout?
    private var h: CGFloat = 0
    fileprivate let buttonText: String
    init(_ initialSize: NSSize, stableId: AnyHashable, buttonText: String, subButtonText: String?, enabled: Bool = true, viewType: GeneralViewType, subTextAction:@escaping(String)->Void, action: @escaping()->Void) {
        self.buttonText = buttonText
        if let subText = subButtonText {
            let attributedText: NSMutableAttributedString = parseMarkdownIntoAttributedString(subText, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(12.5), textColor: theme.colors.listGrayText), bold: MarkdownAttributeSet(font: .bold(12.5), textColor: theme.colors.listGrayText), link: MarkdownAttributeSet(font: .normal(12.5), textColor: theme.colors.link), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, subTextAction))
            })).mutableCopy() as! NSMutableAttributedString
            
            self.subTextLayout = TextViewLayout(attributedText, alignment: .center)
            self.subTextLayout?.interactions = globalLinkExecutor
        } else {
            self.subTextLayout = nil
        }
        super.init(initialSize, stableId: stableId, viewType: viewType, action: action, enabled: enabled)
    }
    
    override var height: CGFloat {
        return self.h
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        if let subTextLayout = subTextLayout  {
            subTextLayout.measure(width: self.blockWidth - viewType.innerInset.left - viewType.innerInset.right)
            self.h = 40 + subTextLayout.layoutSize.height + self.viewType.innerInset.bottom
        } else {
            self.h = 40
        }
        
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return WalletSplashButtonRowView.self
    }
}


@available (OSX 10.12, *)
private final class WalletSplashButtonRowView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let descView = TextView()
    private let button = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        descView.isSelectable = false
        containerView.addSubview(descView)
        containerView.addSubview(button)
        addSubview(containerView)
        button.layer?.cornerRadius = 10
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func updateColors() {
        guard let item = item as? WalletSplashButtonRowItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.descView.background = backdorColor
        self.containerView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? WalletSplashButtonRowItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
    
        button.centerX(y: 0)
        descView.centerX(y: button.frame.maxY + item.viewType.innerInset.top)

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WalletSplashButtonRowItem else {
            return
        }
        
        button.removeAllHandlers()
        button.set(handler: { [weak item] _ in
            item?.action()
        }, for: .Click)
        
        descView.update(item.subTextLayout)
        button.set(font: .medium(.header), for: .Normal)
        button.set(color: theme.colors.underSelectedColor, for: .Normal)
        button.set(background: !item.enabled ? theme.colors.accent.withAlphaComponent(0.8) : theme.colors.accent, for: .Normal)
        button.set(background: theme.colors.accent.withAlphaComponent(0.8), for: .Highlight)
        button.set(text: item.buttonText, for: .Normal)
        _ = button.sizeToFit(NSZeroSize, NSMakeSize(280, 40), thatFit: true)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
