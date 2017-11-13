//
//  ChatMapContentView.swift
//  TelegramMac
//
//  Created by keepcoder on 09/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac


class ChatMapContentView: ChatMediaContentView {
    private let imageView:TransformImageView = TransformImageView()
    private let iconView:ImageView = ImageView()
    private var textView:TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        imageView.addSubview(iconView)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func executeInteraction(_ isControl: Bool) {
        if let parameters = self.parameters as? ChatMediaMapLayoutParameters {
            execute(inapp: .external(link: parameters.url, false))
        }
    }
    
    override func layout() {
        super.layout()
        if let parameters = parameters as? ChatMediaMapLayoutParameters {
            imageView.set(arguments: parameters.arguments)
            imageView.setFrameSize(parameters.arguments.imageSize)
            iconView.center()
            textView?.update(parameters.venueText)
            textView?.centerY(x:70)
        }
    }
    
    override func update(with media: Media, size: NSSize, account: Account, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool = false, positionFlags: GroupLayoutPositionFlags? = nil) {
        let mediaUpdated = self.media == nil || !self.media!.isEqual(media)
        iconView.image = theme.icons.chatMapPin
        iconView.sizeToFit()

        super.update(with: media, size: size, account: account, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags)
        
        if mediaUpdated, let parameters = parameters as? ChatMediaMapLayoutParameters {
            imageView.setSignal( chatWebpageSnippetPhoto(account: account, photo: parameters.image, scale: backingScaleFactor, small: parameters.isVenue))
            
            if parameters.isVenue {
                if textView == nil {
                    textView = TextView()
                    
                    textView?.isSelectable = false
                    addSubview(textView!)
                }
                
            }
        }
    }
    
}
