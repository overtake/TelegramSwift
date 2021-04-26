//
//  ChatInvoiceItem.swift
//  Telegram
//
//  Created by keepcoder on 19/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit


class ChatInvoiceItem: ChatRowItem {
    fileprivate let media:TelegramMediaInvoice
    fileprivate let textLayout:TextViewLayout
    fileprivate var arguments:TransformImageArguments?
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        let message = object.message!
        
        let isIncoming: Bool = message.isIncoming(context.account, object.renderType == .bubble)

        self.media = message.media[0] as! TelegramMediaInvoice
        let attr = NSMutableAttributedString()
        _ = attr.append(string: media.title, color: theme.chat.linkColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
        _ = attr.append(string: "\n")
        _ = attr.append(string: media.description, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text))
        attr.detectLinks(type: [.Links], color: theme.chat.linkColor(isIncoming, object.renderType == .bubble))
        
        textLayout = TextViewLayout(attr)
        
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        
    }
    
    override var isBubbleFullFilled: Bool {
        if let _ = media.photo {
            return true
        } else {
            return super.isBubbleFullFilled
        }
    }
    
    var mediaBubbleCornerInset: CGFloat {
        return 1
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override var contentOffset: NSPoint {
        var offset = super.contentOffset
        //
        if hasBubble {
            if  forwardNameLayout != nil {
                offset.y += defaultContentInnerInset
            } else if !isBubbleFullFilled  {
                offset.y += (defaultContentInnerInset + 2)
            }
        }

        if hasBubble && authorText == nil && replyModel == nil && forwardNameLayout == nil {
            offset.y -= (defaultContentInnerInset + self.mediaBubbleCornerInset * 2 - (isBubbleFullFilled ? 1 : 0))
        }
        return offset
    }
    
    override var elementsContentInset: CGFloat {
        if hasBubble && isBubbleFullFilled {
            return bubbleContentInset
        }
        return super.elementsContentInset
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
        if let line = textLayout.lines.last, line.frame.width > realContentSize.width - (rightSize.width + insetBetweenContentAndDate ) {
            return rightSize.height
        }
        if postAuthor != nil {
            return isStateOverlayLayout ? nil : rightSize.height
        }
        return super.additionalLineForDateInBubbleState
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
            return 2
        }
        return isBubbled && !isBubbleFullFilled ? 14 :  super.defaultContentTopOffset
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {

        var contentSize = NSMakeSize(width, 0)

        if let photo = media.photo {
            
            for attr in photo.attributes {
                switch attr {
                case let .ImageSize(size):
                    contentSize = size.size.aspectFitted(NSMakeSize(width, 200))
                    var topLeftRadius: CGFloat = .cornerRadius
                    let bottomLeftRadius: CGFloat = .cornerRadius
                    var topRightRadius: CGFloat = .cornerRadius
                    let bottomRightRadius: CGFloat = .cornerRadius
                    if isBubbled {
                        if !hasHeader {
                            topLeftRadius = topLeftRadius * 3 + 2
                            topRightRadius = topRightRadius * 3 + 2
                        }
                    }
                    let corners = ImageCorners(topLeft: .Corner(topLeftRadius), topRight: .Corner(topRightRadius), bottomLeft: .Corner(bottomLeftRadius), bottomRight: .Corner(bottomRightRadius))
                    arguments = TransformImageArguments(corners: corners, imageSize: size.size, boundingSize: contentSize, intrinsicInsets: NSEdgeInsets())

                default:
                    break
                }
            }
        }
        
        var maxWidth: CGFloat = contentSize.width
        if hasBubble {
            maxWidth -= bubbleDefaultInnerInset
        }
        
        textLayout.measure(width: maxWidth)
        if arguments == nil {
            contentSize.width = textLayout.layoutSize.width
        } else {
            contentSize.height += defaultContentTopOffset
        }
        contentSize.height += textLayout.layoutSize.height
        
        return contentSize
    }
    
    override func viewClass() -> AnyClass {
        return ChatInvoiceView.self
    }
}

class ChatInvoiceView : ChatRowView {
    let textView:TextView = TextView()
    let imageView:TransformImageView = TransformImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
    }
    override func contentFrame(_ item: ChatRowItem) -> NSRect {
        var rect = super.contentFrame(item)
        guard let item = item as? ChatInvoiceItem else {
            return rect
        }
        if item.isBubbled, item.isBubbleFullFilled {
            rect.origin.x -= item.bubbleContentInset
            if item.hasBubble {
                rect.origin.x += item.mediaBubbleCornerInset
            }
        }
        
        return rect
    }
    
    override var selectableTextViews: [TextView] {
        return [textView]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ChatInvoiceItem {
            textView.setFrameOrigin(NSMakePoint(item.elementsContentInset, (item.arguments == nil ? 0 : imageView.frame.maxY + item.defaultContentInnerInset)))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ChatInvoiceItem {
            textView.update(item.textLayout)
            if let photo = item.media.photo, let arguments = item.arguments, let message = item.message {
                addSubview(imageView)
                imageView.setSignal(chatMessageWebFilePhoto(account: item.context.account, photo: photo, scale: backingScaleFactor))
                imageView.set(arguments: arguments)
                imageView.setFrameSize(arguments.boundingSize)
                _ = fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, reference: MediaResourceReference.media(media: AnyMediaReference.message(message: MessageReference(message), media: photo), resource: photo.resource)).start()

            } else {
                imageView.removeFromSuperview()
            }
        }
        needsLayout = true
    }
}

