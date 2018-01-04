//
//  ChatPhotoItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import TGUIKit
import SwiftSignalKitMac

class ChatMediaLayoutParameters : Equatable {
    
    let presentation: ChatMediaPresentation
    let media: Media
    init(presentation: ChatMediaPresentation, media: Media) {
        self.presentation = presentation
        self.media = media
    }
    
    
    static func layout(for media:TelegramMediaFile, isWebpage: Bool, chatInteraction:ChatInteraction, presentation: ChatMediaPresentation) -> ChatMediaLayoutParameters {
        if media.isInstantVideo {
            var duration:Int = 0
            for attr in media.attributes {
                switch attr {
                case let .Video(params):
                    duration = params.duration
                default:
                    break
                }
            }
            
            return ChatMediaVideoMessageLayoutParameters(showPlayer:chatInteraction.inlineAudioPlayer, duration: duration, isMarked: true, isWebpage: isWebpage || chatInteraction.isLogInteraction, resource: media.resource, presentation: presentation, media: media)
        } else if media.isVoice {
            var waveform:AudioWaveform? = nil
            var duration:Int = 0
            for attr in media.attributes {
                switch attr {
                case let .Audio(params):
                    if let data = params.waveform?.makeData() {
                        waveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                        duration = params.duration
                    }
                default:
                    break
                }
            }
            
            return ChatMediaVoiceLayoutParameters(showPlayer:chatInteraction.inlineAudioPlayer, waveform:waveform, duration:duration, isMarked: true, isWebpage: isWebpage || chatInteraction.isLogInteraction, resource: media.resource, presentation: presentation, media: media)
        } else if media.isMusic {
            var audioTitle:String?
            var audioPerformer:String?
            
            var duration:Int = 0
            for attribute in media.attributes {
                if case let .Audio(_, d, title, performer, _) = attribute {
                    duration = d
                    audioTitle = title
                    audioPerformer = performer
                    break
                }
            }
            
            let attr = NSMutableAttributedString()
            
            
            if let _audioTitle = audioTitle, let audioPerformer = audioPerformer {
                if _audioTitle.isEmpty && audioPerformer.isEmpty {
                    _ = attr.append(string: media.fileName, color: presentation.text, font: NSFont.normal(.title))
                    audioTitle = media.fileName
                } else {
                    _ = attr.append(string: _audioTitle + " - " + audioPerformer, color: presentation.text, font: NSFont.normal(.title))
                }
            } else {
                _ = attr.append(string: media.fileName, color: presentation.text, font: NSFont.normal(.title))
                audioTitle = media.fileName
            }
            
            return ChatMediaMusicLayoutParameters(nameLayout: TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end), durationLayout: TextViewLayout(.initialize(string: String.durationTransformed(elapsed: duration), color: presentation.grayText, font: .normal(.title)), maximumNumberOfLines: 1, truncationType: .end), sizeLayout: TextViewLayout(.initialize(string: (media.size ?? 0).prettyNumber, color: presentation.grayText, font: .normal(.title)), maximumNumberOfLines: 1, truncationType: .middle), resource: media.resource, isWebpage: isWebpage, title: audioTitle, performer: audioPerformer, showPlayer:chatInteraction.inlineAudioPlayer, presentation: presentation, media: media)
        } else {
            var fileName:String = "Unknown.file"
            if let name = media.fileName {
                fileName = name
            }
            return  ChatFileLayoutParameters(fileName: fileName, hasThumb: !media.previewRepresentations.isEmpty, presentation: presentation, media: media)
        }
    }
    
    func makeLabelsForWidth(_ width: CGFloat) {
        
    }
    
}

class ChatMediaGalleryParameters : ChatMediaLayoutParameters {
    let isWebpage: Bool
    let showMedia:()->Void
    let showMessage:(Message)->Void
    init(showMedia:@escaping()->Void, showMessage:@escaping(Message)->Void, isWebpage: Bool, presentation: ChatMediaPresentation = .Empty, media: Media) {
        self.showMedia = showMedia
        self.showMessage = showMessage
        self.isWebpage = isWebpage
        super.init(presentation: presentation, media: media)
    }
}

func ==(lhs:ChatMediaLayoutParameters, rhs:ChatMediaLayoutParameters) -> Bool {
    return false
}


class ChatMediaItem: ChatRowItem {

    let media:Media

    
    var parameters:ChatMediaLayoutParameters?
    
    
    
    override var topInset:CGFloat {
        return 4
    }
    
    var mediaBubbleCornerInset: CGFloat {
        return 1
    }
    
    override var bubbleFrame: NSRect {
        var frame = super.bubbleFrame
        
        if isBubbleFullFilled {
            frame.size.width = contentSize.width + additionBubbleInset
            if hasBubble {
                frame.size.width += self.mediaBubbleCornerInset * 2
            }
        }
        
        return frame
    }
    
    override var defaultContentTopOffset: CGFloat {
        if isBubbled && !hasBubble {
            return defaultContentInnerInset
        }
        return super.defaultContentTopOffset
    }
    
    override var contentOffset: NSPoint {
        var offset = super.contentOffset
        //
        if hasBubble {
            if  forwardNameLayout != nil {
                offset.y += defaultContentInnerInset
            } else if authorText == nil, !isBubbleFullFilled  {
                offset.y += (defaultContentInnerInset + 2)
            }
        }

        if hasBubble && authorText == nil && replyModel == nil && forwardNameLayout == nil {
            offset.y -= (defaultContentInnerInset + self.mediaBubbleCornerInset * 2)
        }
        return offset
    }
    
    override var elementsContentInset: CGFloat {
        if hasBubble && isBubbleFullFilled {
            return bubbleContentInset
        }
        return super.elementsContentInset
    }
    
    override var _defaultHeight: CGFloat {
        if hasBubble && isBubbleFullFilled && captionLayout == nil {
            return contentOffset.y + defaultContentInnerInset - mediaBubbleCornerInset * 2
        }
        
        return super._defaultHeight
    }
    
    override var realContentSize: NSSize {
        var size = super.realContentSize
        
        if isBubbleFullFilled {
            size.width -= bubbleContentInset * 2
        }
        return size
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        if isForceRightLine {
            return rightSize.height
        }
        if let caption = captionLayout {
            if let line = caption.lines.last, line.frame.width > realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
                return rightSize.height
            }
        }
        if postAuthor != nil {
           // return isStateOverlayLayout ? nil : rightSize.height
        }
        return super.additionalLineForDateInBubbleState
    }
    
    override var isFixedRightPosition: Bool {
        if media is TelegramMediaImage {
            return true
        } else if let media = media as? TelegramMediaFile {
            
            if let captionLayout = captionLayout, let line = captionLayout.lines.last, line.frame.width < realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
                return true
            }
            
            return media.isVideo || media.isAnimated || media.isVoice || media.isMusic || media.isSticker
        }
        return super.isFixedRightPosition
    }
    

    override var isBubbleFullFilled: Bool {
        return (media.isInteractiveMedia || isSticker) && isBubbled 
    }
    
    var positionFlags: GroupLayoutPositionFlags? = nil
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account: Account, _ object: ChatHistoryEntry) {
        
        let message = object.message!
        
        let isIncoming: Bool = message.isIncoming(account, object.renderType == .bubble)

        media = message.media[0]
        
        
        super.init(initialSize, chatInteraction, account, object)
        
        
        if !message.text.isEmpty {
            
            
            var caption:NSMutableAttributedString = NSMutableAttributedString()
            NSAttributedString.initialize()
            _ = caption.append(string: message.text, color: theme.chat.textColor(isIncoming), font: NSFont.normal(theme.fontSize))
            var types:ParsingType = [.Links, .Mentions, .Hashtags]
            
            if let peer = messageMainPeer(message) as? TelegramUser {
                if peer.botInfo != nil {
                    types.insert(.Commands)
                }
            } else if let peer = messageMainPeer(message) as? TelegramChannel {
                switch peer.info {
                case .group:
                    types.insert(.Commands)
                default:
                    break
                }
            } else {
                types.insert(.Commands)
            }
            
            var hasEntities: Bool = false
            for attr in message.attributes {
                if attr is TextEntitiesMessageAttribute {
                    hasEntities = true
                    break
                }
            }
            if hasEntities {
                caption = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text.fixed, account:account, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.forceSendMessage, hashtag:chatInteraction.modalSearch, applyProxy: chatInteraction.applyProxy).mutableCopy() as! NSMutableAttributedString
            }
            caption.detectLinks(type: types, account: account, color: theme.chat.linkColor(isIncoming), openInfo:chatInteraction.openInfo, hashtag: chatInteraction.modalSearch, command: chatInteraction.forceSendMessage)
            captionLayout = TextViewLayout(caption, alignment: .left, selectText: theme.chat.selectText(isIncoming), strokeLinks: object.renderType == .bubble, alwaysStaticItems: true)
            
            captionLayout?.interactions = globalLinkExecutor

        }
        
        
        self.parameters = ChatMediaGalleryParameters(showMedia: {
            
        }, showMessage: { [weak self] message in
            self?.chatInteraction.focusMessageId(nil, message.id, .center(id: 0, animated: true, focus: true, inset: 0))
            }, isWebpage: chatInteraction.isLogInteraction, presentation: .make(for: message, account: account, renderType: object.renderType), media: media)
        
        
        if isBubbleFullFilled  {
            var positionFlags: GroupLayoutPositionFlags = []
            if captionLayout == nil {
                positionFlags.insert(.bottom)
                positionFlags.insert(.left)
                positionFlags.insert(.right)
            }
            if authorText == nil && replyModel == nil && forwardNameLayout == nil {
                positionFlags.insert(.top)
                positionFlags.insert(.left)
                positionFlags.insert(.right)
            }
            self.positionFlags = positionFlags
        }

    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        return ChatLayoutUtils.contentSize(for: media, with: width)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        var items:Signal<[ContextMenuItem], Void> = .complete()
        if let message = message, let peer = peer {
            items = chatMenuItems(for: message, account: account, chatInteraction: chatInteraction, peer: peer)
        }
        return items |> map { [weak self] items in
            var items = items
            if let captionLayout = self?.captionLayout {
                let text = captionLayout.attributedString.string
                items.insert(ContextMenuItem(tr(L10n.textCopy), handler: {
                    copyToClipboard(text)
                }), at: 1)
                
                if let view = self?.view as? ChatRowView, let textView = view.captionView, let window = textView.window {
                    let point = textView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                    if let layout = textView.layout {
                        if let (link, range, _) = layout.link(at: point) {
                            var text:String = layout.attributedString.string.nsstring.substring(with: range)
                            if let link = link as? inAppLink {
                                if case let .external(link, _) = link {
                                    text = link
                                }
                            }
                            
                            for i in 0 ..< items.count {
                                if items[i].title == tr(L10n.messageContextCopyMessageLink) {
                                    items.remove(at: i)
                                    break
                                }
                            }
                            
                            items.insert(ContextMenuItem(tr(L10n.messageContextCopyMessageLink), handler: {
                                copyToClipboard(text)
                            }), at: 1)
                        }
                    }
                }
            }
            
            return items
        }
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        return false
    }
    
    override var identifier: String {
        return super.identifier + "\(stableId)"
    }
   
    public func contentNode() -> ChatMediaContentView.Type {
        return ChatLayoutUtils.contentNode(for: media)
    }
    
    override func viewClass() -> AnyClass {
        return ChatMediaView.self
    }
    
}



class ChatMediaView: ChatRowView {
    
    fileprivate(set) var contentNode:ChatMediaContentView?
    
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = true
            contentNode?.needsDisplay = true
        }
    }
    
    override var backgroundColor: NSColor {
        didSet {
            
            contentNode?.backgroundColor = contentColor
        }
    }
    
    
    override var contentFrame: NSRect {
        var rect = super.contentFrame
        
        guard let item = item as? ChatMediaItem else { return rect }
        
        if item.isBubbled, item.isBubbleFullFilled {
            rect.origin.x -= item.bubbleContentInset
            if item.hasBubble {
                rect.origin.x += item.mediaBubbleCornerInset
            }
        }
        
        return rect
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        if let item:ChatMediaItem = item as? ChatMediaItem {
            if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = item.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            
            self.contentNode?.update(with: item.media, size: item.contentSize, account: item.account!, parent:item.message, table:item.table, parameters:item.parameters, animated: animated, positionFlags: item.positionFlags)
        }
        super.set(item: item, animated: animated)
    }
    
    open override func interactionContentView(for innerId: AnyHashable ) -> NSView {
        if let content = self.contentNode?.interactionContentView(for: innerId) {
            return content
        }
        return self
    }

}



