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
    
    enum SceneType {
        case coin
        case star
        case grace
        case gift(StarGift.Gift)
    }
    
    fileprivate let titleLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    let peer: Peer?
    let context: AccountContext
    let status: PremiumEmojiStatusInfo?
    let presentation: TelegramPresentationTheme
    let sceneType: SceneType
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, presentation: TelegramPresentationTheme, isPremium: Bool, peer: Peer?, emojiStatus: PremiumEmojiStatusInfo?, source: PremiumLogEventsSource, premiumText: NSAttributedString?, viewType: GeneralViewType, sceneType: SceneType) {
        
        self.context = context
        self.peer = peer
        self.status = emojiStatus
        self.presentation = presentation
        self.sceneType = sceneType
        
        let title: NSAttributedString
        var info = NSMutableAttributedString()
        
        switch sceneType {
        case let .gift(gift):
            let limit = gift.perUserLimit?.total ?? 0
            title = .initialize(string: strings().premiumStarGiftTitle, color: presentation.colors.text, font: .medium(.header))
            info.append(
                string: strings().premiumStarGiftInfo(Int(limit)),
                color: theme.colors.text,
                font: .normal(.text)
            )
            info.detectBoldColorInString(with: .medium(.text))

        case .coin:
            title = .initialize(string: strings().premiumBoardingBusinessTelegramBusiness, color: presentation.colors.text, font: .medium(.header))
            if isPremium {
                _ = info.append(string: strings().premiumBoardingBusinessTelegramBusinessHeaderInfo1, color: presentation.colors.text, font: .normal(.text))
            } else {
                _ = info.append(string: strings().premiumBoardingBusinessTelegramBusinessHeaderInfo2, color: presentation.colors.text, font: .normal(.text))
            }
        case .grace:
            title = .initialize(string: strings().premiumBoardingGraceTitle, color: presentation.colors.text, font: .medium(.header))
            _ = info.append(string: strings().premiumBoardingGraceText, color: presentation.colors.text, font: .normal(.text))
            info.detectBoldColorInString(with: .medium(.text))
        case .star:
            if let peer = peer {
                if case let .gift(from, _, months, _, _) = source {
                    let text: String
                    if from == context.peerId {
                        text = strings().premiumBoardingPeerGiftYouTitle(peer.displayTitle, "\(months)")
                    } else {
                        text = strings().premiumBoardingPeerGiftTitle(peer.displayTitle, "\(months)")
                    }
                    title = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.header), textColor: presentation.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: presentation.colors.text), link: MarkdownAttributeSet(font: .medium(.header), textColor: presentation.colors.peerAvatarVioletBottom), linkAttribute: { contents in
                        return (NSAttributedString.Key.link.rawValue, contents)
                    }))
                } else if let status = emojiStatus {
                    
                    if let info = status.info {
                        let packName: String = info.title
                        let packFile: TelegramMediaFile = status.items.first?.file._parse() ?? status.file
                        
                        let attr = parseMarkdownIntoAttributedString(strings().premiumBoardingPeerStatusCustomTitle(peer.displayTitle, packName), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.header), textColor: presentation.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: presentation.colors.text), link: MarkdownAttributeSet(font: .medium(.header), textColor: presentation.colors.peerAvatarVioletBottom), linkAttribute: { contents in
                            return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                                showModal(with: StickerPackPreviewModalController(context, peerId: nil, references: [.emoji(.name(info.shortName))]), for: context.window)
                            }))
                        })) as! NSMutableAttributedString
                        
                        let range = attr.string.nsstring.range(of: clown)
                        if range.location != NSNotFound {
                            attr.addAttribute(TextInputAttributes.embedded, value: InlineStickerItem(source: .attribute(.init(fileId: packFile.fileId.id, file: packFile, emoji: ""))), range: range)
                        }
                        
                        title = attr
                    } else {
                        title = .initialize(string: strings().premiumBoardingPeerStatusDefaultTitle(peer.displayTitle), color: presentation.colors.text, font: .medium(.header))
                    }
                } else {
                    title = parseMarkdownIntoAttributedString(strings().premiumBoardingPeerTitle(peer.displayTitle), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .medium(.header), textColor: presentation.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: presentation.colors.text), link: MarkdownAttributeSet(font: .medium(.header), textColor: presentation.colors.peerAvatarVioletBottom), linkAttribute: { contents in
                        return (NSAttributedString.Key.link.rawValue, contents)
                    }))
                }
                
            } else {
                if isPremium {
                    title = .initialize(string: strings().premiumBoardingGotTitle, color: presentation.colors.text, font: .medium(.header))
                } else {
                    title = .initialize(string: strings().premiumBoardingTitle, color: presentation.colors.text, font: .medium(.header))
                }
            }
            if let _ = peer {
                if case let .gift(from, _, _, slug, _) = source {
                    let text: String
                    if from == context.peerId {
                        text = strings().premiumBoardingPeerGiftYouInfo
                    } else {
                        if let _ = slug {
                            text = strings().premiumBoardingPeerGiftLinkInfo
                        } else {
                            text = strings().premiumBoardingPeerGiftInfo
                        }
                    }
                    _ = info.append(string: text, color: presentation.colors.text, font: .normal(.text))
                } else if let _ = peer?.emojiStatus {
                    _ = info.append(string: strings().premiumBoardingPeerStatusInfo, color: presentation.colors.text, font: .normal(.text))
                } else {
                    _ = info.append(string: strings().premiumBoardingPeerInfo, color: presentation.colors.text, font: .normal(.text))
                }
                info.detectBoldColorInString(with: .medium(.text))
                
            } else {
                if isPremium, let premiumText = premiumText {
                    info = premiumText.mutableCopy() as! NSMutableAttributedString
                } else {
                    _ = info.append(string: strings().premiumBoardingInfo, color: presentation.colors.text, font: .normal(.text))
                    info.detectBoldColorInString(with: .medium(.text))
                }
            }

        }
        
        self.titleLayout = .init(title, alignment: .center)

        self.titleLayout.interactions = globalLinkExecutor
        
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
    private var premiumView: (PremiumSceneView & NSView)?
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
        
        self.layer?.masksToBounds = false
        
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? PremiumBoardingHeaderItem else {
            return theme.colors.listBackground
        }
        return item.presentation.colors.listBackground
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
            let file = status.items.first?.file._parse() ?? status.file
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
        
        
        
        if case let .gift(gift) = item.sceneType {
            if let view = self.premiumView {
                performSubviewRemoval(view, animated: animated)
                self.premiumView = nil
            }
            if self.statusView == nil {
                let status = InlineStickerView(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: gift.file.fileId.id, file: gift.file, emoji: ""), size: NSMakeSize(100, 100))
                self.statusView = status
                addSubview(status)
            }
            
        } else if let status = item.peer?.emojiStatus {
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
            
            var current: (PremiumSceneView & NSView)?
            if let view = self.premiumView {
                current = view
            } else {
                switch item.sceneType {
                case .coin:
                    current = PremiumCoinSceneView(frame: NSMakeRect(0, 0, frame.width, 150))
                case .star, .grace:
                    current = PremiumStarSceneView(frame: NSMakeRect(0, 0, frame.width, 150))
                case .gift:
                    current = nil
                }
                if let current {
                    addSubview(current)
                    self.premiumView = current
                } else {
                    self.premiumView?.removeFromSuperview()
                    self.premiumView = nil
                }
            }
            if var current {
                current.sceneBackground = backdorColor
                current.updateLayout(size: current.frame.size, transition: .immediate)
            }
        }
        
        needsLayout = true
        
    }
}
