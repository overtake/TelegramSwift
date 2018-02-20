//
//  ChatInvoiceItem.swift
//  Telegram
//
//  Created by keepcoder on 19/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


class ChatInvoiceItem: ChatRowItem {
    fileprivate let media:TelegramMediaInvoice
    fileprivate let textLayout:TextViewLayout
    fileprivate var arguments:TransformImageArguments?
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        let message = object.message!
        
        let isIncoming: Bool = message.isIncoming(account, object.renderType == .bubble)

        self.media = message.media[0] as! TelegramMediaInvoice
        let attr = NSMutableAttributedString()
        _ = attr.append(string: media.description, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text))
        attr.detectLinks(type: [.Links], color: theme.chat.linkColor(isIncoming, object.renderType == .bubble))
        
        textLayout = TextViewLayout(attr)
        
        super.init(initialSize, chatInteraction, account, object, downloadSettings)
        
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {

        var contentSize = NSMakeSize(width, 0)

        if let photo = media.photo {
            
            for attr in photo.attributes {
                switch attr {
                case .ImageSize(let size):
                    //videoSize.fitted()
                    contentSize = size.fitted(NSMakeSize(200, 200))
                    arguments = TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: size, boundingSize: contentSize, intrinsicInsets: NSEdgeInsets())

                default:
                    break
                }
            }
        }
        textLayout.measure(width: contentSize.width)
        contentSize.height += textLayout.layoutSize.height + defaultContentTopOffset
        
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
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ChatInvoiceItem {
            textView.update(item.textLayout, origin: NSMakePoint(0, contentView.frame.height - item.textLayout.layoutSize.height))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ChatInvoiceItem {
            textView.update(item.textLayout)
            if let photo = item.media.photo, let arguments = item.arguments {
                addSubview(imageView)
                imageView.setSignal( chatMessageWebFilePhoto(account: item.account, photo: photo, scale: backingScaleFactor))
                imageView.set(arguments: arguments)
                imageView.setFrameSize(arguments.boundingSize)
                _ = item.account.postbox.mediaBox.fetchedResource(photo.resource, tag: nil).start()

            } else {
                imageView.removeFromSuperview()
            }
        }
    }
}

