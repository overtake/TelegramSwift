//
//  ChatEmptyPeerItem.swift
//  TelegramMac
//
//  Created by keepcoder on 10/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import TelegramMedia
import Postbox
import SwiftSignalKit

class ChatEmptyPeerItem: TableRowItem {

    private(set) var textViewLayout:TextViewLayout
    private(set) var image: Media?
    private(set) var sticker: TelegramMediaFile?
    private(set) var premiumRequired: Bool = false
    
    private(set) var standImage: (CGImage, CGFloat)? = nil
    
    private(set) var linkText: TextViewLayout?
    
    private (set) var introInfo: TextViewLayout?
    
    override var stableId: AnyHashable {
        return 0
    }
    let chatInteraction:ChatInteraction
    
    override var animatable: Bool {
        return false
    }
    
    override var index: Int {
        return -1000
    }
    
    override var height: CGFloat {
        if let table = table {
            return table.frame.height
        }
        return initialSize.height
    }
    private var _shouldBlurService: Bool? = nil
    var shouldBlurService: Bool {
        return _shouldBlurService ?? presentation.shouldBlurService
    }
    
    private let peerViewDisposable = MetaDisposable()
    let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, chatInteraction:ChatInteraction, theme: TelegramPresentationTheme) {
        self.chatInteraction = chatInteraction
        self.presentation = theme
        let attr = NSMutableAttributedString()
        var lineSpacing: CGFloat? = 5
        
        let textColor: NSColor = isLite(.blur) ? theme.colors.text : theme.chatServiceItemTextColor
        switch chatInteraction.mode {
        case .history, .preview:
            if  chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat {
                _ = attr.append(string: strings().chatSecretChatEmptyHeader, color: textColor, font: .medium(.text))
                _ = attr.append(string: "\n")
                _ = attr.append(string: strings().chatSecretChat1Feature, color: textColor, font: .medium(.text))
                _ = attr.append(string: "\n")
                _ = attr.append(string: strings().chatSecretChat2Feature, color: textColor, font: .medium(.text))
                _ = attr.append(string: "\n")
                _ = attr.append(string: strings().chatSecretChat3Feature, color: textColor, font: .medium(.text))
                _ = attr.append(string: "\n")
                _ = attr.append(string: strings().chatSecretChat4Feature, color: textColor, font: .medium(.text))
                
            } else if let peer = chatInteraction.peer, peer.isGroup || peer.isSupergroup, peer.groupAccess.isCreator {
                if chatInteraction.presentation.chatLocation.threadId == nil {
                    _ = attr.append(string: strings().emptyGroupInfoTitle, color: textColor, font: .medium(.text))
                    _ = attr.append(string: "\n")
                    _ = attr.append(string: strings().emptyGroupInfoSubtitle, color: textColor, font: .medium(.text))
                    _ = attr.append(string: "\n")
                    _ = attr.append(string: strings().emptyGroupInfoLine1(chatInteraction.presentation.limitConfiguration.maxSupergroupMemberCount.formattedWithSeparator), color: textColor, font: .medium(.text))
                    _ = attr.append(string: "\n")
                    _ = attr.append(string: strings().emptyGroupInfoLine2, color: textColor, font: .medium(.text))
                    _ = attr.append(string: "\n")
                    _ = attr.append(string: strings().emptyGroupInfoLine3, color: textColor, font: .medium(.text))
                    _ = attr.append(string: "\n")
                    _ = attr.append(string: strings().emptyGroupInfoLine4, color: textColor, font: .medium(.text))
                } else {
                    lineSpacing = nil
                    _ = attr.append(string: strings().chatEmptyChat, color: textColor, font: .medium(.text))
                }
                
            } else if let padMessageStars = self.chatInteraction.presentation.sendPaidMessageStars, let peer = self.chatInteraction.peer {
                attr.append(string: strings().chatEmptyPaidMessage(peer.displayTitle, strings().starListItemCountCountable(Int(padMessageStars.value))), color: textColor, font: .medium(.text))
                lineSpacing = nil
                //self.standImage = (NSImage(resource: .iconBusinessChatGreetings).precomposed(theme.colors.isDark ? theme.colors.text : theme.colors.accent), 50)
            } else {
                if let restriction = chatInteraction.presentation.peer?.restrictionText(chatInteraction.context.contentSettings) {
                    _ = attr.append(string: restriction, color: theme.chatServiceItemTextColor, font: .medium(.text))
                } else {
                    lineSpacing = nil
                    _ = attr.append(string: strings().chatEmptyChat, color: textColor, font: .medium(.text))
                }
            }
        case .scheduled:
            lineSpacing = nil
            _ = attr.append(string: strings().chatEmptyChat, color: textColor, font: .medium(.text))
        case let .thread(mode):
            lineSpacing = nil
            switch mode {
            case .comments:
                _ = attr.append(string: strings().chatEmptyComments, color: textColor, font: .medium(.text))
            case .replies:
                _ = attr.append(string: strings().chatEmptyReplies, color: textColor, font: .medium(.text))
            case .topic:
                _ = attr.append(string: strings().chatEmptyTopic, color: textColor, font: .medium(.text))
            case .savedMessages:
                _ = attr.append(string: strings().chatEmptySavedMessages, color: textColor, font: .medium(.text))
            case .saved:
                _ = attr.append(string: strings().chatEmptySavedMessages, color: textColor, font: .medium(.text))
            }
        case .pinned:
            lineSpacing = nil
            _ = attr.append(string: strings().chatEmptyChat, color: textColor, font: .medium(.text))
        case let .customChatContents(contents):
            switch contents.kind {
            case .greetingMessageInput:
                _ = attr.append(string: strings().chatEmptyBusinessGreetingMessage, color: theme.colors.text, font: .medium(.text))
                _ = attr.append(string: "\n\n")
                _ = attr.append(string: strings().chatEmptyBusinessGreetingMessageInfo, color: theme.colors.text, font: .normal(.text))
                self.standImage = (NSImage(resource: .iconBusinessChatGreetings).precomposed(theme.colors.isDark ? theme.colors.text : theme.colors.accent), 50)
            case .awayMessageInput:
                _ = attr.append(string: strings().chatEmptyBusinessAwayMessage, color: theme.colors.text, font: .medium(.text))
                _ = attr.append(string: "\n\n")
                _ = attr.append(string: strings().chatEmptyBusinessAwayMessageInfo, color: theme.colors.text, font: .normal(.text))
                self.standImage = (NSImage(resource: .iconBusinessChatAway).precomposed(theme.colors.isDark ? theme.colors.text : theme.colors.accent), 50)

            case .quickReplyMessageInput(let shortcut):
                _ = attr.append(string: strings().chatEmptyBusinessQuickReply, color: theme.colors.text, font: .medium(.text))
                _ = attr.append(string: "\n\n")
                _ = attr.append(string: strings().chatEmptyBusinessQuickReplyInfo1(shortcut), color: theme.colors.text, font: .normal(.text))
                _ = attr.append(string: "\n")
                _ = attr.append(string: strings().chatEmptyBusinessQuickReplyInfo2, color: theme.colors.text, font: .normal(.text))
                self.standImage = (NSImage(resource: .iconBusinessChatQuickReply).precomposed(theme.colors.isDark ? theme.colors.text : theme.colors.accent), 50)
                attr.detectBoldColorInString(with: .medium(.text))
            case .searchHashtag:
                _ = attr.append(string: strings().chatEmptySearchHashtag, color: theme.colors.text, font: .medium(.text))
            }
            self._shouldBlurService = false
        case let .customLink(contents):
            _ = attr.append(string: strings().chatEmptyBusinessLinkTitle, color: theme.colors.text, font: .medium(.text))
            _ = attr.append(string: "\n\n")
            _ = attr.append(string: strings().chatEmptyBusinessLinkText, color: theme.colors.text, font: .normal(.text))
            self.standImage = (NSImage(resource: .iconChatLinksToChat).precomposed(theme.colors.isDark ? theme.colors.text : theme.colors.accent), 50)
            
            let linkLayout = TextViewLayout(.initialize(string: contents.link, color: theme.colors.text, font: .medium(.text)))
            linkLayout.measure(width: .greatestFiniteMagnitude)
            self.linkText = linkLayout
            self._shouldBlurService = false
        }
        
        
        
        textViewLayout = TextViewLayout(attr, alignment: .center, lineSpacing: lineSpacing, alwaysStaticItems: true)
        textViewLayout.interactions = globalLinkExecutor
        
        super.init(initialSize)
        
        
        if chatInteraction.peerId.namespace == Namespaces.Peer.CloudUser, chatInteraction.mode.customChatContents == nil, chatInteraction.mode.customChatLink == nil {
            
            let cachedData: Signal<CachedPeerData?, NoError> = .single(chatInteraction.presentation.cachedData) |> then(getCachedDataView(peerId: chatInteraction.peerId, postbox: chatInteraction.context.account.postbox)) |> deliverOnMainQueue
            
            let peer: Signal<Peer?, NoError> = .single(chatInteraction.presentation.mainPeer) |> then(getPeerView(peerId: chatInteraction.peerId, postbox: chatInteraction.context.account.postbox)) |> deliverOnMainQueue

            let sticker: Signal<FoundStickerItem?, NoError> = .single(nil) |> then(chatInteraction.context.engine.stickers.randomGreetingSticker() |> deliverOnMainQueue)
            
            peerViewDisposable.set(combineLatest(cachedData, peer, sticker).start(next: { [weak self] cachedData, peer, sticker in
                if let cachedData = cachedData as? CachedUserData, let user = peer, let self, self.chatInteraction.mode == .history, peer?.restrictionInfo == nil {
                    if let botInfo = cachedData.botInfo {
                        var about = botInfo.description
                        if about.isEmpty {
                            about = cachedData.about ?? strings().chatEmptyChat
                        }
                        if about.isEmpty {
                            about = strings().chatEmptyChat
                        }
                        if user.isScam {
                            about = strings().peerInfoScamWarning
                        }
                        if user.isFake {
                            about = strings().peerInfoFakeWarning
                        }
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: about, color: theme.colors.text, font: .medium(.text))
                        attr.detectLinks(type: [.Links, .Mentions, .Hashtags, .Commands], context: chatInteraction.context, color: theme.colors.link, openInfo:chatInteraction.openInfo, hashtag: { hashtag in
                            chatInteraction.context.bindings.globalSearch(hashtag, nil, nil)
                        }, command: chatInteraction.sendPlainText, applyProxy: chatInteraction.applyProxy, dotInMention: false)
                        self._shouldBlurService = false
                        self.textViewLayout = TextViewLayout(attr, alignment: .left)
                        self.textViewLayout.interactions = globalLinkExecutor
                        self.image = botInfo.video ?? botInfo.photo
                    } else if cachedData.flags.contains(.premiumRequired), !chatInteraction.context.isPremium {
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: strings().chatEmptyPremiumRequiredState(user.compactDisplayTitle), color: theme.colors.text, font: .medium(.text))
                        attr.detectBoldColorInString(with: .medium(.text))
                        attr.detectLinks(type: [.Links, .Mentions, .Hashtags, .Commands], context: chatInteraction.context, color: theme.colors.link, openInfo:chatInteraction.openInfo, hashtag: { hashtag in
                            chatInteraction.context.bindings.globalSearch(hashtag, nil, nil)
                        }, command: chatInteraction.sendPlainText, applyProxy: chatInteraction.applyProxy, dotInMention: false)
                        self._shouldBlurService = false
                        self.textViewLayout = TextViewLayout(attr, alignment: .center)
                        self.textViewLayout.interactions = globalLinkExecutor
                        self.premiumRequired = true
                        self.standImage = (NSImage(resource: .iconChatPremiumRequired).precomposed(theme.colors.isDark ? theme.colors.text : theme.colors.accent), 100)
                    } else if case let .known(intro) = cachedData.businessIntro, let intro = intro {
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: intro.title.isEmpty ? strings().chatEmptyChat : intro.title, color: theme.colors.text, font: .medium(.text))
                        _ = attr.append(string: "\n", color: theme.colors.text, font: .medium(.text))
                        _ = attr.append(string: intro.text.isEmpty ? strings().chatEmptyChatInfo : intro.text, color: theme.colors.text, font: .normal(.text))
                        self._shouldBlurService = false
                        self.textViewLayout = TextViewLayout(attr, alignment: .center)
                        self.textViewLayout.interactions = globalLinkExecutor
                        self.sticker = intro.stickerFile ?? sticker?.file
                        let info = parseMarkdownIntoAttributedString(strings().chatEmptyBusinessIntroHow(user.compactDisplayTitle), attributes: .init(body: .init(font: .normal(.text), textColor: theme.colors.text), bold: .init(font: .medium(.text), textColor: theme.colors.text), link: .init(font: .normal(.text), textColor: theme.colors.accent), linkAttribute: { contents in
                            return (NSAttributedString.Key.foregroundColor.rawValue, theme.colors.accent)
                        })).detectBold(with: .medium(.text))
                        
                        
                        let introInfo = TextViewLayout(info, alignment: .center)
                        introInfo.interactions = globalLinkExecutor
                        self.introInfo = introInfo
                    }
                    self.view?.set(item: self)
                }
            }))
        }
        
    }
    
    func sendSticker() {
        if let sticker = self.sticker {
            self.chatInteraction.sendAppFile(sticker, false, nil, false, nil)
        }
    }
    
    deinit {
        peerViewDisposable.dispose()
    }
    
    override func viewClass() -> AnyClass {
        return ChatEmptyPeerView.self
    }
    
}




class ChatEmptyPeerView : TableRowView {
    let textView:TextView = TextView()
    private var imageView: ChatMediaContentView? = nil
    private var stickerView: StickerMediaContentView? = nil
    private var visualEffect: VisualEffect?
    private var bgView: View?
    
    private var premRequiredImageView: ImageView?
    private var premRequiredButton: TextButton?
    
    private var linkView: TextView? = nil
    private var introInfoView: TextView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(textView)

        textView.isSelectable = false
        textView.userInteractionEnabled = true
        textView.disableBackgroundDrawing = true

    }
    
    override func updateColors() {
        super.updateColors()
        
        
      
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override var backdorColor: NSColor {
        guard let theme = (item as? ChatEmptyPeerItem)?.presentation else {
            return super.backdorColor
        }
        return theme.backgroundMode.hasWallpaper ? .clear : theme.chatBackground
    }
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)

        guard let item = item as? ChatEmptyPeerItem else { return }

        // Blur / BG view logic
        if item.shouldBlurService && !isLite(.blur) {
            if visualEffect == nil {
                let effect = VisualEffect(frame: .zero)
                visualEffect = effect
                addSubview(effect, positioned: .below, relativeTo: nil)
            }
            visualEffect?.bgColor = item.presentation.blurServiceColor
            if bgView != nil {
                performSubviewRemoval(bgView!, animated: animated)
                bgView = nil
            }
        } else {
            if bgView == nil {
                let view = View(frame: .zero)
                view.backgroundColor = item.presentation.colors.background
                bgView = view
                addSubview(view, positioned: .below, relativeTo: nil)
            }
            if let effect = visualEffect {
                performSubviewRemoval(effect, animated: animated)
                visualEffect = nil
            }
        }
        
        bgView?.addSubview(textView)

        // Image View
        if let media = item.image {
            let contentNode = ChatLayoutUtils.contentNode(for: media)
            
            let contentSize = ChatLayoutUtils.contentSize(for: media, with: 300)

            if imageView == nil || !imageView!.isKind(of: contentNode) {
                imageView?.removeFromSuperview()
                imageView = contentNode.init(frame: .zero)
                bgView?.addSubview(imageView!)
            }
            imageView?.update(with: media, size: contentSize, context: item.chatInteraction.context, parent: nil, table: item.table)
            imageView?.fetch(userInitiated: true)
        } else if let view = imageView {
            performSubviewRemoval(view, animated: false)
            imageView = nil
        }

        // Sticker
        if let sticker = item.sticker {
            let stickerSize = NSMakeSize(150, 150)
            let size = sticker.dimensions?.size.aspectFitted(stickerSize) ?? stickerSize
            if stickerView == nil {
                let view = StickerMediaContentView(frame: size.bounds)
                view.scaleOnClick = true
                view.userInteractionEnabled = true
                view.set(handler: { [weak self] _ in
                    (self?.item as? ChatEmptyPeerItem)?.sendSticker()
                }, for: .Click)
                bgView?.addSubview(view)
                stickerView = view
            }
            stickerView?.update(with: sticker, size: size, context: item.chatInteraction.context, parent: nil, table: item.table)
        } else if let view = stickerView {
            performSubviewRemoval(view, animated: false)
            stickerView = nil
        }

        // Standalone image
        if let standImage = item.standImage {
            if premRequiredImageView == nil {
                let view = ImageView()
                bgView?.addSubview(view)
                premRequiredImageView = view
            }
            premRequiredImageView?.image = standImage.0
            premRequiredImageView?.contentGravity = .resizeAspect
        } else if let view = premRequiredImageView {
            performSubviewRemoval(view, animated: false)
            premRequiredImageView = nil
        }

        // Link View
        if let linkText = item.linkText {
            if linkView == nil {
                let view = TextView()
                view.userInteractionEnabled = false
                view.isSelectable = false
                bgView?.addSubview(view)
                linkView = view
            }
            linkView?.update(linkText)
        } else if let view = linkView {
            performSubviewRemoval(view, animated: false)
            linkView = nil
        }

        // Intro info
        if let introInfo = item.introInfo {
            if introInfoView == nil {
                let view = TextView()
                view.isSelectable = false
                view.scaleOnClick = true
                view.set(handler: { [weak item] _ in
                    if let context = item?.chatInteraction.context {
                        prem(with: PremiumBoardingController(context: context, source: .business_intro), for: context.window)
                    }
                }, for: .Click)
                self.addSubview(view)
                introInfoView = view
            }
            introInfo.measure(width: 240)
            introInfo.generateAutoBlock(backgroundColor: item.presentation.colors.background)
            introInfoView?.update(introInfo)
        } else if let view = introInfoView {
            performSubviewRemoval(view, animated: false)
            introInfoView = nil
        }

        // Premium button
        if item.premiumRequired {
            if premRequiredButton == nil {
                let button = TextButton()
                button.scaleOnClick = true
                button.set(handler: { [weak item] _ in
                    if let context = item?.chatInteraction.context {
                        prem(with: PremiumBoardingController(context: context), for: context.window)
                    }
                }, for: .Click)
                bgView?.addSubview(button)
                premRequiredButton = button
            }

            premRequiredButton?.set(background: item.presentation.colors.accent, for: .Normal)
            premRequiredButton?.set(font: .medium(.text), for: .Normal)
            premRequiredButton?.set(color: item.presentation.colors.underSelectedColor, for: .Normal)
            premRequiredButton?.set(text: strings().chatEmptyPremiumRequiredAction, for: .Normal)
            premRequiredButton?.sizeToFit(NSMakeSize(20, 20))
            premRequiredButton?.layer?.cornerRadius = premRequiredButton!.frame.height / 2
        } else if let view = premRequiredButton {
            performSubviewRemoval(view, animated: false)
            premRequiredButton = nil
        }

    }

    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        guard let item = item as? ChatEmptyPeerItem,
              let bgView = self.visualEffect ?? self.bgView else { return }

        item.textViewLayout.measure(width: min(size.width - 80, 250))
        if item.textViewLayout.lineSpacing != nil {
            for (i, line) in item.textViewLayout.lines.enumerated() {
                line.penFlush = (i == 0) ? 0.5 : 0.0
            }
        }
        textView.update(item.textViewLayout)

        let textFrameWidth = max(300, item.textViewLayout.layoutSize.width + 20)
        var bgWidth = textView.frame.width + 20
        if imageView != nil || linkView != nil {
            bgWidth = max(bgWidth, 300)
        }

        var totalHeight: CGFloat = [imageView, premRequiredImageView, premRequiredButton, stickerView, linkView]
            .compactMap { $0?.frame.height }
            .reduce(0, +)

        if premRequiredImageView != nil { totalHeight += 10 }
        if premRequiredButton != nil { totalHeight += 20 }
        if stickerView != nil { totalHeight += 10 }
        if linkView != nil { totalHeight += 8 }
        
        let xOffset: CGFloat = item.chatInteraction.presentation.monoforumState == .vertical ? 40 : 0

        totalHeight += textView.frame.height + 20

        bgView.setFrameSize(NSMakeSize(bgWidth, totalHeight))
        transition.updateFrame(view: bgView, frame: bgView.centerFrame().offsetBy(dx: xOffset, dy: 0))


        if let view = premRequiredImageView {
            transition.updateFrame(view: view, frame: view.centerFrameX(y: 10).offsetBy(dx: xOffset, dy: 0))
            transition.updateFrame(view: textView, frame: textView.centerFrameX(y: view.frame.maxY + 10).offsetBy(dx: xOffset, dy: 0))
        } else if let view = imageView {
            transition.updateFrame(view: view, frame: view.centerFrameX(y: 0).offsetBy(dx: xOffset, dy: 0))
            transition.updateFrame(view: textView, frame: textView.centerFrameX(y: view.frame.maxY + 10).offsetBy(dx: xOffset, dy: 0))
        } else if let view = stickerView {
            transition.updateFrame(view: textView, frame: textView.centerFrameX(y: 10).offsetBy(dx: xOffset, dy: 0))
            transition.updateFrame(view: view, frame: view.centerFrameX(y: textView.frame.maxY + 10).offsetBy(dx: xOffset, dy: 0))
        } else {
            transition.updateFrame(view: textView, frame: textView.centerFrame().offsetBy(dx: xOffset, dy: 0))
        }

        if let view = premRequiredButton {
            transition.updateFrame(view: view, frame: view.centerFrameX(y: textView.frame.maxY + 10).offsetBy(dx: xOffset, dy: 0))
        }

        if let view = linkView {
            transition.updateFrame(view: view, frame: view.centerFrameX(y: textView.frame.maxY + 8).offsetBy(dx: xOffset, dy: 0))
        }

        if let view = introInfoView {
            transition.updateFrame(view: view, frame: view.centerFrameX(y: bgView.frame.maxY + 10).offsetBy(dx: xOffset, dy: 0))
        }

        let singleLine = item.textViewLayout.lines.count == 1
        bgView.layer?.cornerRadius = (imageView == nil && premRequiredImageView == nil) ? (singleLine ? textView.frame.height / 2 : 10) : 10
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

