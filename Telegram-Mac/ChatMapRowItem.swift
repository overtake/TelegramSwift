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
    init(map:TelegramMediaMap, resource:HttpReferenceMediaResource) {
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
            _ = attr.append(string: venue.title, color: theme.colors.text, font: .normal(.text))
            _ = attr.append(string: "\n")
            _ = attr.append(string: venue.address, color: theme.colors.grayText, font: .normal(.text))
            venueText = TextViewLayout(attr, maximumNumberOfLines: 4, truncationType: .middle, alignment: .left)
        } else {
            venueText = nil
        }
    }
}

func ==(lhs:ChatMediaMapLayoutParameters, rhs:ChatMediaMapLayoutParameters) -> Bool {
    return lhs.resource.url == rhs.resource.url
}

class ChatMapRowItem: ChatMediaItem {

    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ object: ChatHistoryEntry) {
        super.init(initialSize, chatInteraction, account, object)
        let map = media as! TelegramMediaMap
        let isVenue = map.venue != nil
        let resource = HttpReferenceMediaResource(url: "https://maps.googleapis.com/maps/api/staticmap?center=\(map.latitude),\(map.longitude)&zoom=15&size=\(isVenue ? 60 * Int(2.0) : 320 * Int(2.0))x\(isVenue ? 60 * Int(2.0) : 120 * Int(2.0))&sensor=true", size: 0)
        self.parameters = ChatMediaMapLayoutParameters(map: map, resource: resource)
    }
    
    override var instantlyResize:Bool {
        if let parameters = parameters as? ChatMediaMapLayoutParameters {
            return parameters.isVenue
        }
        return false
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        if let parameters = parameters as? ChatMediaMapLayoutParameters {
            parameters.venueText?.measure(width: width - 70)
            var size:NSSize = parameters.defaultImageSize
            if !parameters.isVenue {
                size = parameters.defaultImageSize.aspectFitted(NSMakeSize(min(width,parameters.defaultImageSize.width), parameters.defaultImageSize.height))
                parameters.arguments = TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
            }
            return NSMakeSize(width, size.height)
        }
        return super.makeContentSize(width)
    }
    
}
