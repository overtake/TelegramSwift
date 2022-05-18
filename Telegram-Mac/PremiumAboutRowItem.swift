//
//  PremiumAboutRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 17.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class PremiumAboutRowItem : GeneralRowItem {
    
    fileprivate let title: TextViewLayout
    fileprivate let info: TextViewLayout
    fileprivate let about: TextViewLayout

    init(_ initialSize: NSSize, stableId: AnyHashable, terms:@escaping()->Void, privacy:@escaping()->Void) {
        
        self.title = .init(.initialize(string: strings().premiumBoardingAboutTitle, color: theme.colors.text, font: .medium(.title)), alignment: .center)
        
        let infoAttr = NSMutableAttributedString()
        _ = infoAttr.append(string: strings().premiumBoardingAboutText, color: theme.colors.text, font: .normal(.text))
        infoAttr.detectBoldColorInString(with: .medium(.text))
        self.info = .init(infoAttr, alignment: .center)

        
        let about = parseMarkdownIntoAttributedString(strings().premiumBoardingAboutTos, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .normal(.title), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        }))
                
        self.about = .init(about, alignment: .center)
        
        self.about.interactions = .init(processURL: { content in
            if let content = content as? String {
                if content == "privacy" {
                    privacy()
                } else if content == "terms" {
                    terms()
                }
            }
        })

        super.init(initialSize, stableId: stableId)
        
        makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 40)
        self.info.measure(width: width - 40)
        self.about.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        return title.layoutSize.height + 12 + info.layoutSize.height + 12 + about.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return PremiumAboutRowView.self
    }
}


private final class PremiumAboutRowView : TableRowView {
    private let title = TextView()
    private let info = TextView()
    private let about = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(info)
        addSubview(about)
        
        title.isSelectable = false
        info.isSelectable = false
        about.isSelectable = false

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        
        title.centerX(y: 0)
        info.centerX(y: title.frame.maxY + 12)
        about.centerX(y: info.frame.maxY + 12)

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PremiumAboutRowItem else {
            return
        }
        title.update(item.title)
        info.update(item.info)
        about.update(item.about)
        
        needsLayout = true

    }
}
