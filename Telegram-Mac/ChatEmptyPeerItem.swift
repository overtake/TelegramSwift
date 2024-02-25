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
    private(set) var image: TelegramMediaImage?
    private(set) var premiumRequired: Bool = false
    
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
        case .history:
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
                if let restriction = chatInteraction.presentation.restrictionInfo {
                    var hasRule: Bool = false
                    for rule in restriction.rules {
                        #if APP_STORE
                        if rule.platform == "ios" || rule.platform == "all" {
                            if !chatInteraction.context.contentSettings.ignoreContentRestrictionReasons.contains(rule.reason) {
                                _ = attr.append(string: rule.text, color: theme.chatServiceItemTextColor, font: .medium(.text))
                                hasRule = true
                                break
                            }
                        }
                        #endif
                    }
                    if !hasRule {
                        _ = attr.append(string: strings().chatEmptyChat, color: textColor, font: .medium(.text))
                        lineSpacing = nil
                    }
                    
                } else {
                    lineSpacing = nil
                    _ = attr.append(string: strings().chatEmptyChat, color: textColor, font: .medium(.text))
                }
            }
        case .scheduled:
            lineSpacing = nil
            _ = attr.append(string: strings().chatEmptyChat, color: textColor, font: .medium(.text))
        case let .thread(_, mode):
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
        }
        
        
        
        textViewLayout = TextViewLayout(attr, alignment: .center, lineSpacing: lineSpacing, alwaysStaticItems: true)
        textViewLayout.interactions = globalLinkExecutor
        
        super.init(initialSize)
        
        
        if chatInteraction.peerId.namespace == Namespaces.Peer.CloudUser {
            
            let cachedData: Signal<CachedPeerData?, NoError> = .single(chatInteraction.presentation.cachedData) |> then(getCachedDataView(peerId: chatInteraction.peerId, postbox: chatInteraction.context.account.postbox)) |> deliverOnMainQueue
            
            let peer: Signal<Peer?, NoError> = .single(chatInteraction.presentation.mainPeer) |> then(getPeerView(peerId: chatInteraction.peerId, postbox: chatInteraction.context.account.postbox)) |> deliverOnMainQueue

            
            peerViewDisposable.set(combineLatest(cachedData, peer).start(next: { [weak self] cachedData, peer in
                if let cachedData = cachedData as? CachedUserData, let user = peer, let self {
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
                        attr.detectLinks(type: [.Links, .Mentions, .Hashtags, .Commands], context: chatInteraction.context, color: theme.colors.link, openInfo:chatInteraction.openInfo, hashtag: chatInteraction.context.bindings.globalSearch, command: chatInteraction.sendPlainText, applyProxy: chatInteraction.applyProxy, dotInMention: false)
                        self._shouldBlurService = false
                        self.textViewLayout = TextViewLayout(attr, alignment: .left)
                        self.textViewLayout.interactions = globalLinkExecutor
                        self.image = botInfo.photo
                        self.view?.set(item: self)
                    } else if cachedData.flags.contains(.premiumRequired), !chatInteraction.context.isPremium {
                        let attr = NSMutableAttributedString()
                        _ = attr.append(string: strings().chatEmptyPremiumRequiredState(user.compactDisplayTitle), color: theme.colors.text, font: .medium(.text))
                        attr.detectBoldColorInString(with: .medium(.text))
                        attr.detectLinks(type: [.Links, .Mentions, .Hashtags, .Commands], context: chatInteraction.context, color: theme.colors.link, openInfo:chatInteraction.openInfo, hashtag: chatInteraction.context.bindings.globalSearch, command: chatInteraction.sendPlainText, applyProxy: chatInteraction.applyProxy, dotInMention: false)
                        self._shouldBlurService = false
                        self.textViewLayout = TextViewLayout(attr, alignment: .center)
                        self.textViewLayout.interactions = globalLinkExecutor
                        self.premiumRequired = true
                        self.view?.set(item: self)
                    }
                    
                }
            }))
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
    private var imageView: TransformImageView? = nil
    private var visualEffect: VisualEffect?
    private var bgView: View?
    
    private var premRequiredImageView: ImageView?
    private var premRequiredButton: TextButton?
    
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
        
        guard let item = item as? ChatEmptyPeerItem else {
            return
        }
        
        if item.shouldBlurService && !isLite(.blur) {
            let current: VisualEffect
            if let view = self.visualEffect {
                current = view
            } else {
                current = VisualEffect(frame: .zero)
                self.visualEffect = current
                addSubview(current, positioned: .below, relativeTo: nil)
            }
            current.bgColor = item.presentation.blurServiceColor
        } else if let view = self.visualEffect {
            performSubviewRemoval(view, animated: animated)
            self.visualEffect = nil
        }
        
        if item.shouldBlurService && !isLite(.blur) {
            if let view = self.bgView {
                performSubviewRemoval(view, animated: animated)
                self.bgView = nil
            }
        } else {
            let current: View
            if let view = self.bgView {
                current = view
            } else {
                current = View(frame: .zero)
                self.bgView = current
                addSubview(current, positioned: .below, relativeTo: nil)
            }
            current.backgroundColor = item.presentation.colors.background
        }

        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        let bgView = self.visualEffect ?? self.bgView

        if let item = item as? ChatEmptyPeerItem, let bgView = bgView {
            
            
            item.textViewLayout.measure(width: min(frame.width - 80, 400))
            
            if item.textViewLayout.lineSpacing != nil {
                for (i, line) in item.textViewLayout.lines.enumerated() {
                    if i == 0 {
                        line.penFlush = 0.5
                    } else {
                        line.penFlush = 0.0
                    }
                }
            }
            
            textView.update(item.textViewLayout)
            
            var size = NSMakeSize(item.textViewLayout.layoutSize.width + 20, 300)

            
            if let image = item.image, let rep = image.representationForDisplayAtSize(PixelDimensions.init(1280, 1280)) {
                let current: TransformImageView
                if let view = self.imageView {
                    current = view
                } else {
                    current = TransformImageView()
                    bgView.addSubview(current)
                    self.imageView = current
                }
                
                let signal = chatMessagePhoto(account: item.chatInteraction.context.account, imageReference: .standalone(media: image), peer: item.chatInteraction.peer, scale: System.backingScale, autoFetchFullSize: true)
                
                current.setSignal(signal)
                
                size = rep.dimensions.size.aspectFitted(size)
                
                let arguments = TransformImageArguments.init(corners: .init(topLeft: .Corner(8), topRight: .Corner(8), bottomLeft: .Corner(2), bottomRight: .Corner(2)), imageSize: size, boundingSize: size, intrinsicInsets: .init())
                
                
                current.set(arguments: arguments)
                current.setFrameSize(size)
            } else if let view = self.imageView {
                performSubviewRemoval(view, animated: false)
                self.imageView = nil
            }
            
            
            if item.premiumRequired {
                let current: ImageView
                if let view = self.premRequiredImageView {
                    current = view
                } else {
                    current = ImageView()
                    current.frame = NSMakeRect(0, 0, size.width, 100)
                    bgView.addSubview(current)
                    self.premRequiredImageView = current
                }
                current.image = NSImage(named: "Icon_Chat_PremiumRequired")?.precomposed(theme.colors.isDark ? theme.colors.text : theme.colors.accent)
                current.contentGravity = .resizeAspect
            } else if let view = self.premRequiredImageView {
                performSubviewRemoval(view, animated: false)
                self.premRequiredImageView = nil
            }
            
            if item.premiumRequired {
                let current: TextButton
                if let view = self.premRequiredButton {
                    current = view
                } else {
                    current = TextButton()
                    current.frame = NSMakeRect(0, 0, size.width, 30)
                    current.background = .random
                    bgView.addSubview(current)
                    self.premRequiredButton = current
                    
                    current.set(handler: { [weak item] _ in
                        if let context = item?.chatInteraction.context {
                            showModal(with: PremiumBoardingController(context: context), for: context.window)
                        }
                    }, for: .Click)
                }
                
                
                current.scaleOnClick = true
                current.set(background: theme.colors.accent, for: .Normal)
                current.set(font: .medium(.text), for: .Normal)
                current.set(color: theme.colors.underSelectedColor, for: .Normal)
                current.set(text: strings().chatEmptyPremiumRequiredAction, for: .Normal)
                current.sizeToFit(NSMakeSize(20, 20))
                current.layer?.cornerRadius = current.frame.height / 2
            } else if let view = self.premRequiredButton {
                performSubviewRemoval(view, animated: false)
                self.premRequiredButton = nil
            }
            
            let singleLine = item.textViewLayout.lines.count == 1
            
            var h: CGFloat = [self.imageView, premRequiredButton, premRequiredImageView].compactMap { $0 }.reduce(0, { $0 + $1.frame.height })
            
            if let _ = premRequiredButton {
                h += 20
            }
            
            bgView.setFrameSize(NSMakeSize(textView.frame.width + 20, h + textView.frame.height + 20))

            
            bgView.addSubview(self.textView)
            
            bgView.center()
            
            if let view = premRequiredImageView {
                view.centerX(y: 0)
                textView.centerX(y: view.frame.maxY + 10)
            } else if let imageView = imageView {
                imageView.centerX(y: 0)
                textView.centerX(y: imageView.frame.maxY + 10)
            } else {
                textView.center()
            }
            
            if let view = premRequiredButton {
                view.centerX(y: textView.frame.maxY + 10)
            }
            
            if imageView == nil && premRequiredImageView == nil {
                bgView.layer?.cornerRadius = singleLine ? textView.frame.height / 2 : 10
            } else {
                bgView.layer?.cornerRadius = 10
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

