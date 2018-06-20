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
    let resource:TelegramMediaResource
    let image:TelegramMediaImage
    let venueText:TextViewLayout?
    let isVenue:Bool
    let defaultImageSize:NSSize
    let url:String
    
    fileprivate(set) var arguments:TransformImageArguments
    init(map:TelegramMediaMap, resource:TelegramMediaResource, presentation: ChatMediaPresentation, automaticDownload: Bool) {
        self.map = map
        self.isVenue = map.venue != nil
        self.resource = resource
        self.defaultImageSize = isVenue ? NSMakeSize(60, 60) : NSMakeSize(320, 120)
        self.url = "https://maps.google.com/maps?q=\(map.latitude),\(map.longitude)"
        let representation = TelegramMediaImageRepresentation(dimensions: defaultImageSize, resource: resource)
        self.image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [representation], reference: nil)
        
        self.arguments = TransformImageArguments(corners: ImageCorners(radius: 8), imageSize: defaultImageSize, boundingSize: defaultImageSize, intrinsicInsets: NSEdgeInsets())
        if let venue = map.venue {
            let attr = NSMutableAttributedString()
            _ = attr.append(string: venue.title, color: presentation.text, font: .normal(.text))
            _ = attr.append(string: "\n")
            _ = attr.append(string: venue.address, color: presentation.grayText, font: .normal(.text))
            venueText = TextViewLayout(attr, maximumNumberOfLines: 4, truncationType: .middle, alignment: .left)
        } else {
            venueText = nil
        }
        super.init(presentation: presentation, media: map, automaticDownload: automaticDownload)
    }
}

func ==(lhs:ChatMediaMapLayoutParameters, rhs:ChatMediaMapLayoutParameters) -> Bool {
    return lhs.resource.isEqual(to: rhs.resource)
}

class ChatMapRowItem: ChatMediaItem {
    fileprivate var liveText: TextViewLayout?
    fileprivate var updatedText: TextViewLayout?
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        super.init(initialSize, chatInteraction, account, object, downloadSettings)
        let map = media as! TelegramMediaMap
      //  let isVenue = map.venue != nil
        let resource =  MapSnapshotMediaResource(latitude: map.latitude, longitude: map.longitude, width: 320 * 2, height: 120 * 2)
        //let resource = HttpReferenceMediaResource(url: "https://maps.googleapis.com/maps/api/staticmap?center=\(map.latitude),\(map.longitude)&zoom=15&size=\(isVenue ? 60 * Int(2.0) : 320 * Int(2.0))x\(isVenue ? 60 * Int(2.0) : 120 * Int(2.0))&sensor=true", size: 0)
        self.parameters = ChatMediaMapLayoutParameters(map: map, resource: resource, presentation: .make(for: object.message!, account: account, renderType: object.renderType), automaticDownload: downloadSettings.isDownloable(object.message!))
        
        if isLiveLocationView {
            liveText = TextViewLayout(.initialize(string: L10n.chatLiveLocation, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .bold(.text)), maximumNumberOfLines: 1, truncationType: .end)
            
            var editedDate:Int32 = object.message!.timestamp
            for attr in object.message!.attributes {
                if let attr = attr as? EditedMessageAttribute {
                    editedDate = attr.date
                }
            }
                        
            var time:TimeInterval = Date().timeIntervalSince1970
            time -= account.context.timeDifference
            let timeUpdated = Int32(time) - editedDate
                
            updatedText = TextViewLayout(.initialize(string: timeUpdated < 60 ? L10n.chatLiveLocationUpdatedNow : L10n.chatLiveLocationUpdatedCountable(Int(timeUpdated / 60)), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text)), maximumNumberOfLines: 1)
        }
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        if let parameters = parameters as? ChatMediaMapLayoutParameters {
            if parameters.isVenue {
                return rightSize.width > (_contentSize.width - 70) ? rightSize.height : nil
            }
        }
        return nil
    }
    
    override var isFixedRightPosition: Bool {
        return true
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
                var time:TimeInterval = Date().timeIntervalSince1970
                time -= account.context.timeDifference
                if Int32(time) < message.timestamp + liveBroadcastingTimeout {
                    return true
                }
            }
        }
        return false
    }
    
    var liveLocationTimeout: Int32 {
        if let media = media as? TelegramMediaMap {
            if let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                return liveBroadcastingTimeout
            }
        }
        return 0
    }
    
    var liveLocationProgress: TimeInterval {
        if let media = media as? TelegramMediaMap {
            if let liveBroadcastingTimeout = media.liveBroadcastingTimeout, let message = message {
                var time:TimeInterval = Date().timeIntervalSince1970
                time -= account.context.timeDifference
                return 100.0 - (Double(time) - Double(message.timestamp)) / Double(liveBroadcastingTimeout) * 100.0
            }
        }
        return 0
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
            return super.height + (renderType == .bubble ? 46 : 40)
        }
        return super.height
    }
    
}

private class LiveLocationRowView : ChatMediaView {
    private let liveText: TextView = TextView()
    private let updatedText: TextView = TextView()
    private let progress:TimableProgressView = TimableProgressView(TimableProgressTheme(seconds: 20))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        rowView.addSubview(updatedText)
        rowView.addSubview(liveText)
        rowView.addSubview(progress)
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? ChatMapRowItem else {return}
        
        liveText.update(item.liveText)
        updatedText.update(item.updatedText)
        
//        let difference:()->TimeInterval = {
//            return TimeInterval((countdownBeginTime + attribute.timeout)) - (CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
//        }
//        let start = difference() / Double(attribute.timeout) * 100.0
        if item.isLiveLocationView {
            progress.theme = TimableProgressTheme(backgroundColor: backdorColor, foregroundColor: theme.chat.textColor(item.isIncoming, item.renderType == .bubble), seconds: Double(item.liveLocationTimeout), start: item.liveLocationProgress, borderWidth: 2)
            progress.progress = 0
            progress.isHidden = false
        } else {
            progress.isHidden = true
        }
        
        
        progress.startAnimation()
        super.set(item: item, animated: animated)

    }
    
    override func updateColors() {
        super.updateColors()
        liveText.backgroundColor = contentColor
        updatedText.backgroundColor = contentColor
    }
    
    private var textFrame: NSRect {
        guard let item = item as? ChatMapRowItem, let liveText = item.liveText else {return NSZeroRect}
        
        return NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultContentInnerInset, liveText.layoutSize.width, liveText.layoutSize.height)
    }
    private var updateFrame: NSRect {
        guard let item = item as? ChatMapRowItem, let updatedText = item.updatedText else {return NSZeroRect}
        
        return NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultContentInnerInset + liveText.frame.height, updatedText.layoutSize.width, updatedText.layoutSize.height)
    }
    
    private var progressFrame: NSRect {
        guard let item = item as? ChatMapRowItem else {return NSZeroRect}
        
        return NSMakeRect(contentFrame.maxX - progress.frame.width, contentFrame.maxY + item.defaultContentInnerInset + 4, 25, 25)
    }
    
    override func layout() {
        super.layout()
        
        liveText.frame = textFrame
        updatedText.frame = updateFrame
        progress.frame = progressFrame
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
