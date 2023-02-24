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
import TGModernGrowingTextView
import TelegramCore

final class PremiumBoardingHeaderItem : GeneralRowItem {
    fileprivate let titleLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    let peer: Peer?
    let context: AccountContext
    let status: PremiumEmojiStatusInfo?
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, isPremium: Bool, peer: Peer?, emojiStatus: PremiumEmojiStatusInfo?, source: PremiumLogEventsSource, premiumText: NSAttributedString?, viewType: GeneralViewType) {
        
        self.context = context
        self.peer = peer
        self.status = emojiStatus
        
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
            } else if let status = emojiStatus {
                
                if let info = status.info {
                    let packName: String = info.title
                    let packFile: TelegramMediaFile = status.items.first?.file ?? status.file
                    
                    let attr = parseMarkdownIntoAttributedString(strings().premiumBoardingPeerStatusCustomTitle(peer.displayTitle, packName), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.header), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.header), textColor: theme.colors.peerAvatarVioletBottom), linkAttribute: { contents in
                        return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                            showModal(with: StickerPackPreviewModalController(context, peerId: nil, references: [.emoji(.name(info.shortName))]), for: context.window)
                        }))
                    })) as! NSMutableAttributedString
                    
                    let range = attr.string.nsstring.range(of: "🤡")
                    if range.location != NSNotFound {
                        attr.addAttribute(.init(rawValue: "Attribute__EmbeddedItem"), value: TGTextAttachment(identifier: "\(arc4random())", fileId: packFile.fileId.id, file: packFile, text: "", info: nil), range: range)
                    }
                    
                    title = attr
                } else {
                    title = .initialize(string: strings().premiumBoardingPeerStatusDefaultTitle(peer.displayTitle), color: theme.colors.text, font: .medium(.header))
                }
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

        self.titleLayout.interactions = globalLinkExecutor
        
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
            } else if let _ = peer?.emojiStatus {
                _ = info.append(string: strings().premiumBoardingPeerStatusInfo, color: theme.colors.text, font: .normal(.text))
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
        var height = 100 + 10 + titleLayout.layoutSize.height + 10 + infoLayout.layoutSize.height + 10
        if peer?.emojiStatus != nil {
            height += 10
        }
        return height
    }
    
    
    override func viewClass() -> AnyClass {
        return PremiumBoardingHeaderView.self
    }
}


private final class PremiumBoardingHeaderView : TableRowView {
    private var premiumView: PremiumStarSceneView?
    private var statusView: InlineStickerView?
    private let titleView = TextView()
    private let infoView = TextView()
    private var packInlineView: InlineStickerItemLayer?
    private var timer: SwiftSignalKit.Timer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(infoView)
        
        
        titleView.isSelectable = false
        
        infoView.isSelectable = false
        
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    
    override func layout() {
        super.layout()
        if let premiumView = premiumView {
            premiumView.centerX(y: -30)
            titleView.centerX(y: premiumView.frame.maxY - 30 + 10)
        } else if let statusView = statusView {
            statusView.centerX(y: 0)
            titleView.centerX(y: statusView.frame.maxY + 10)
        }
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
        
        if let status = item.status, let embedded = item.titleLayout.embeddedItems.first {
            let file = status.items.first?.file ?? status.file
            let rect = embedded.rect.insetBy(dx: -1.5, dy: -1.5)
            let view = InlineStickerItemLayer(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: file.fileId.id, file: file, emoji: ""), size: rect.size)
            view.frame = rect
            titleView.addEmbeddedLayer(view)
            self.packInlineView = view
            view.isPlayable = true
        } else if let view = packInlineView {
            performSublayerRemoval(view, animated: animated)
            self.packInlineView = nil
        }
        
                
        timer = SwiftSignalKit.Timer(timeout: 5.0, repeat: true, completion: { [weak self] in
            self?.premiumView?.playAgain()
        }, queue: .mainQueue())
        
        timer?.start()
        
        if let status = item.peer?.emojiStatus {
            if let view = self.premiumView {
                performSubviewRemoval(view, animated: animated)
                self.premiumView = nil
            }
            if self.statusView == nil {
                let status = InlineStickerView(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: status.fileId, file: nil, emoji: ""), size: NSMakeSize(100, 100))
                self.statusView = status
                addSubview(status)
                
            }
        } else {
            if let view = self.statusView {
                performSubviewRemoval(view, animated: animated)
                self.statusView = nil
            }
            let current: PremiumStarSceneView
            if let view = self.premiumView {
                current = view
            } else {
                current = PremiumStarSceneView(frame: NSMakeRect(0, 0, 150, 150))
                addSubview(current)
                self.premiumView = current
            }
            current.updateLayout(size: current.frame.size, transition: .immediate)

        }
        
        needsLayout = true
        
    }
}
