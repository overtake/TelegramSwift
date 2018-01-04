//
//  ChatMapRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 09/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac

final class ChatMediaMapLayoutParameters : ChatMediaLayoutParameters {
    let map:TelegramMediaMap
    let resource:HttpReferenceMediaResource
    let image:TelegramMediaImage
    let venueText:TextViewLayout?
    let isVenue:Bool
    let defaultImageSize:NSSize
    let url:String
    fileprivate(set) var arguments:TransformImageArguments
    init(map:TelegramMediaMap, resource:HttpReferenceMediaResource, presentation: ChatMediaPresentation) {
        self.map = map
        self.isVenue = map.venue != nil
        self.resource = resource
        self.defaultImageSize = isVenue ? NSMakeSize(60, 60) : NSMakeSize(320, 120)
        self.url = "https://maps.google.com/maps?q=\(map.latitude),\(map.longitude)"
        let representation = TelegramMediaImageRepresentation(dimensions: defaultImageSize, resource: resource)
        self.image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [representation], reference: nil)
        
        self.arguments = TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: defaultImageSize, boundingSize: defaultImageSize, intrinsicInsets: NSEdgeInsets())
        if let venue = map.venue {
            let attr = NSMutableAttributedString()
            _ = attr.append(string: venue.title, color: presentation.text, font: .normal(.text))
            _ = attr.append(string: "\n")
            _ = attr.append(string: venue.address, color: presentation.grayText, font: .normal(.text))
            venueText = TextViewLayout(attr, maximumNumberOfLines: 4, truncationType: .middle, alignment: .left)
        } else {
            venueText = nil
        }
        super.init(presentation: presentation, media: map)
    }
}

func ==(lhs:ChatMediaMapLayoutParameters, rhs:ChatMediaMapLayoutParameters) -> Bool {
    return lhs.resource.url == rhs.resource.url
}

class ChatMapRowItem: ChatMediaItem {
    fileprivate var liveText: TextViewLayout?
    fileprivate var updatedText: TextViewLayout?
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ object: ChatHistoryEntry) {
        super.init(initialSize, chatInteraction, account, object)
        let map = media as! TelegramMediaMap
        let isVenue = map.venue != nil
        let resource = HttpReferenceMediaResource(url: "https://maps.googleapis.com/maps/api/staticmap?center=\(map.latitude),\(map.longitude)&zoom=15&size=\(isVenue ? 60 * Int(2.0) : 320 * Int(2.0))x\(isVenue ? 60 * Int(2.0) : 120 * Int(2.0))&sensor=true", size: 0)
        self.parameters = ChatMediaMapLayoutParameters(map: map, resource: resource, presentation: .make(for: object.message!, account: account, renderType: object.renderType))
        
        if isLiveLocationView {
            liveText = TextViewLayout(.initialize(string: L10n.chatLiveLocation, color: theme.chat.textColor(isIncoming), font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end)
        }
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        return nil
    }
    
    override var instantlyResize:Bool {
        if let parameters = parameters as? ChatMediaMapLayoutParameters {
            return parameters.isVenue
        }
        return false
    }
    
    override var isBubbleFullFilled: Bool {
        if let media = media as? TelegramMediaMap {
            return media.venue == nil && isBubbled
        }
        return false
    }
    
    var isLiveLocationView: Bool {
        if let media = media as? TelegramMediaMap, let message = message {
            if let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                if message.timestamp < message.timestamp + liveBroadcastingTimeout {
                    return true
                }
            }
        }
        return false
    }
    
    override func viewClass() -> AnyClass {
        return isLiveLocationView ? LiveLocationRowView.self : super.viewClass()
    }
    
    override var isStateOverlayLayout: Bool {
        return !isLiveLocationView && hasBubble && isBubbleFullFilled
    }
    
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        if let parameters = parameters as? ChatMediaMapLayoutParameters {
            parameters.venueText?.measure(width: width - 70)
            var size:NSSize = parameters.defaultImageSize
            if !parameters.isVenue {
                size = parameters.defaultImageSize.aspectFitted(NSMakeSize(min(width,parameters.defaultImageSize.width), parameters.defaultImageSize.height))
                parameters.arguments = TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
            }
            var venueSize: CGFloat = 0
            if let venueText = parameters.venueText {
                venueSize = venueText.layoutSize.width + 10
            }
        
            return NSMakeSize(venueSize + size.width, size.height)
        }
        return super.makeContentSize(width)
    }
    
    override var height: CGFloat {
        if isLiveLocationView {
            liveText?.measure(width: _contentSize.width - elementsContentInset * 2)
            updatedText?.measure(width: _contentSize.width - elementsContentInset * 2)
            return super.height + 40
        }
        return super.height
    }
    
}

private class LiveLocationRowView : ChatMediaView {
    private let liveText: TextView = TextView()
    private let updatedText: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(liveText)
        //addSubview(updatedText)
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? ChatMapRowItem else {return}
        
        liveText.update(item.liveText)
        super.set(item: item, animated: animated)

    }
    
    override func layout() {
        super.layout()
        guard let item = item as? ChatMapRowItem else {return}

        liveText.setFrameOrigin(contentFrame.minX + item.elementsContentInset, item.contentSize.height + item.defaultContentTopOffset)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
