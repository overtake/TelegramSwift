//
//  PremiumBoardingHeaderItem.swift
//  Telegram
//
//  Created by Mike Renoir on 11.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox

final class PremiumBoardingHeaderItem : GeneralRowItem {
    fileprivate let titleLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, isPremium: Bool, peer: Peer?, source: PremiumLogEventsSource, premiumText: NSAttributedString?, viewType: GeneralViewType) {
        
        let title: NSAttributedString
        if let peer = peer {
            if case let .gift(from, _, months) = source {
                let text: String
                if from == context.peerId {
                    text = strings().premiumBoardingPeerGiftYouTitle(peer.displayTitle, "\(months)")
                } else {
                    text = strings().premiumBoardingPeerGiftTitle(peer.displayTitle, "\(months)")
                }
                title = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.header), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.header), textColor: theme.colors.peerAvatarVioletBottom), linkAttribute: { contents in
                    return (NSAttributedString.Key.link.rawValue, contents)
                }))
            } else {
                title = parseMarkdownIntoAttributedString(strings().premiumBoardingPeerTitle(peer.displayTitle), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.header), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.header), textColor: theme.colors.peerAvatarVioletBottom), linkAttribute: { contents in
                    return (NSAttributedString.Key.link.rawValue, contents)
                }))
            }
            
        } else {
            if isPremium {
                title = .initialize(string: strings().premiumBoardingGotTitle, color: theme.colors.text, font: .medium(.header))
            } else {
                title = .initialize(string: strings().premiumBoardingTitle, color: theme.colors.text, font: .medium(.header))
            }
        }
        self.titleLayout = .init(title, alignment: .center)

        var info = NSMutableAttributedString()
        if let _ = peer {
            
            if case let .gift(from, _, _) = source {
                let text: String
                if from == context.peerId {
                    text = strings().premiumBoardingPeerGiftYouInfo
                } else {
                    text = strings().premiumBoardingPeerGiftInfo
                }
                _ = info.append(string: text, color: theme.colors.text, font: .normal(.text))
            } else {
                _ = info.append(string: strings().premiumBoardingPeerInfo, color: theme.colors.text, font: .normal(.text))
            }
            info.detectBoldColorInString(with: .medium(.text))
            
        } else {
            if isPremium, let premiumText = premiumText {
                info = premiumText.mutableCopy() as! NSMutableAttributedString
            } else {
                _ = info.append(string: strings().premiumBoardingInfo, color: theme.colors.text, font: .normal(.text))
                info.detectBoldColorInString(with: .medium(.text))
            }
        }
        self.infoLayout = .init(info, alignment: .center)
        self.infoLayout.interactions = globalLinkExecutor
        super.init(initialSize, stableId: stableId)
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        titleLayout.measure(width: width - 40)
        infoLayout.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        return 100 + 10 + titleLayout.layoutSize.height + 10 + infoLayout.layoutSize.height + 10
    }
    
    
    override func viewClass() -> AnyClass {
        return PremiumBoardingHeaderView.self
    }
}


private final class PremiumBoardingHeaderView : TableRowView {
    private let premiumView = PremiumStarSceneView(frame: NSMakeRect(0, 0, 150, 150))
    private let titleView = TextView()
    private let infoView = TextView()
    private var timer: SwiftSignalKit.Timer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(infoView)
        addSubview(premiumView)
        
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        infoView.isSelectable = false
        
        premiumView.updateLayout(size: premiumView.frame.size, transition: .immediate)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    
    override func layout() {
        super.layout()
        premiumView.centerX(y: -30)
        titleView.centerX(y: premiumView.frame.maxY - 30 + 10)
        infoView.centerX(y: titleView.frame.maxY + 10)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PremiumBoardingHeaderItem else {
            return
        }
        titleView.update(item.titleLayout)
        infoView.update(item.infoLayout)
                
        timer = SwiftSignalKit.Timer(timeout: 5.0, repeat: true, completion: { [weak self] in
            self?.premiumView.playAgain()
        }, queue: .mainQueue())
        
        timer?.start()
        
        needsLayout = true
        
    }
}
