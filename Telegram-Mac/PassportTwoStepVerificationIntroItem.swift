//
//  SecureIdTwoStepVerificationIntroItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac

class PassportTwoStepVerificationIntroItem: GeneralRowItem {

    fileprivate let headerLayout:TextViewLayout
    fileprivate let descLayout:TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: Peer, action: @escaping()->Void) {
        let headerAttr = NSMutableAttributedString()
        _ = headerAttr.append(string: L10n.secureIdCreatePasswordIntroHeader(peer.displayTitle), color: theme.colors.grayText, font: .normal(.text))
        headerAttr.detectBoldColorInString(with: .medium(.text))
        headerLayout = TextViewLayout(headerAttr, alignment: .center)
        
        descLayout = TextViewLayout(.initialize(string: L10n.secureIdCreatePasswordIntro, color: theme.colors.grayText, font: .normal(.text)), alignment: .center)
        
        super.init(initialSize, stableId: stableId, action: action)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override var height: CGFloat {
        return headerLayout.layoutSize.height + (theme.icons.twoStepVerificationCreateIntro.backingSize.height + 40) + descLayout.layoutSize.height + 20 + 20
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        headerLayout.measure(width: width - inset.left - inset.right)
        descLayout.measure(width: width - inset.left - inset.right)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return PassportTwoStepVerificationIntroRowView.self
    }
    
}

private final class PassportTwoStepVerificationIntroRowView : TableRowView {
    private let headerView: TextView = TextView()
    private let imageView: ImageView = ImageView()
    private let descView: TextView = TextView()
    private let button: TitleButton = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(imageView)
        addSubview(descView)
        addSubview(button)
        
        descView.isSelectable = false
        descView.isSelectable = false
        button.set(font: .normal(.title), for: .Normal)

        
        button.set(handler: { [weak self] _ in
            (self?.item as? GeneralRowItem)?.action()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        headerView.centerX(y: 0)
        imageView.centerX(y: headerView.frame.maxY + 20)
        descView.centerX(y: imageView.frame.maxY + 20)
        button.centerX(y: descView.frame.maxY + 20)
    }
    
    
    override func updateColors() {
        super.updateColors()
        button.set(color: theme.colors.accent, for: .Normal)
        headerView.backgroundColor = theme.colors.background
        descView.backgroundColor = theme.colors.background
        button.set(background: theme.colors.background, for: .Normal)
        imageView.image = theme.icons.twoStepVerificationCreateIntro
        imageView.sizeToFit()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PassportTwoStepVerificationIntroItem else {return}
        
        button.set(text: L10n.secureIdRequestCreatePassword, for: .Normal)
        _ = button.sizeToFit()
        headerView.update(item.headerLayout)
        descView.update(item.descLayout)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
