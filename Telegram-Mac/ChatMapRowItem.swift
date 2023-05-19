//
//  ChatMapRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 09/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import InAppSettings

final class ChatMediaMapLayoutParameters : ChatMediaLayoutParameters {
    let map:TelegramMediaMap
    let resource:TelegramMediaResource
    let image:TelegramMediaImage
    let venueText:TextViewLayout?
    let isVenue:Bool
    let defaultImageSize:NSSize
    let url:String
    
    let execute: ()->Void
    
    fileprivate(set) var arguments:TransformImageArguments
    init(map:TelegramMediaMap, resource:TelegramMediaResource, presentation: ChatMediaPresentation, automaticDownload: Bool, execute: @escaping() -> Void) {
        self.map = map
        self.isVenue = map.venue != nil
        self.resource = resource
        self.execute = execute
        self.defaultImageSize = isVenue ? NSMakeSize(60, 60) : NSMakeSize(320, 120)
        self.url = "https://maps.google.com/maps?q=\(String(format:"%f", map.latitude)),\(String(format:"%f", map.longitude))"
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(defaultImageSize), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false)
        
        self.image = TelegramMediaImage(imageId: map.id ?? MediaId(namespace: 0, id: arc4random64()), representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        
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
        super.init(presentation: presentation, media: map, automaticDownload: automaticDownload, autoplayMedia: AutoplayMediaPreferences.defaultSettings)
    }
}

func ==(lhs:ChatMediaMapLayoutParameters, rhs:ChatMediaMapLayoutParameters) -> Bool {
    return lhs.resource.isEqual(to: rhs.resource)
}

class ChatMapRowItem: ChatMediaItem {
    fileprivate var liveText: TextViewLayout?
    fileprivate var updatedText: TextViewLayout?
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        let map = media as! TelegramMediaMap
      //  let isVenue = map.venue != nil
        let resource =  MapSnapshotMediaResource(latitude: map.latitude, longitude: map.longitude, width: 320 * 2, height: 120 * 2, zoom: 15)
        //let resource = HttpReferenceMediaResource(url: "https://maps.googleapis.com/maps/api/staticmap?center=\(map.latitude),\(map.longitude)&zoom=15&size=\(isVenue ? 60 * Int(2.0) : 320 * Int(2.0))x\(isVenue ? 60 * Int(2.0) : 120 * Int(2.0))&sensor=true", size: 0)
        self.parameters = ChatMediaMapLayoutParameters(map: map, resource: resource, presentation: .make(for: object.message!, account: context.account, renderType: object.renderType, theme: theme), automaticDownload: downloadSettings.isDownloable(object.message!), execute: {
            
            if #available(OSX 10.13, *) {
                showModal(with: LocationModalPreview(context, map: map, peer: object.message!.effectiveAuthor, messageId: object.message!.id), for: context.window)
            } else {
                execute(inapp: .external(link: "https://maps.google.com/maps?q=\(String(format:"%f", map.latitude)),\(String(format:"%f", map.longitude))", false))
            }
        })
        
        if isLiveLocationView {
            liveText = TextViewLayout(.initialize(string: strings().chatLiveLocation, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .bold(.text)), maximumNumberOfLines: 1, truncationType: .end)
            
            var editedDate:Int32 = object.message!.timestamp
            for attr in object.message!.attributes {
                if let attr = attr as? EditedMessageAttribute {
                    editedDate = attr.date
                }
            }
                        
            var time:TimeInterval = Date().timeIntervalSince1970
            time -= context.timeDifference
            let timeUpdated = Int32(time) - editedDate
                
            updatedText = TextViewLayout(.initialize(string: timeUpdated < 60 ? strings().chatLiveLocationUpdatedNow : strings().chatLiveLocationUpdatedCountable(Int(timeUpdated / 60)), color: theme.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.text)), maximumNumberOfLines: 1)
        }
    }
    
    override var isForceRightLine: Bool {
        if let parameters = parameters as? ChatMediaMapLayoutParameters {
            if parameters.isVenue {
                if rightSize.width > (_contentSize.width - 70) {
                    return true
                }
            }
        }
        return super.isForceRightLine
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
                time -= context.timeDifference
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
                time -= context.timeDifference
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
    private let progress:TimableProgressView = TimableProgressView(theme: TimableProgressTheme(seconds: 20))
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
            progress.theme = TimableProgressTheme(backgroundColor: .clear, foregroundColor: theme.chat.textColor(item.isIncoming, item.entry.renderType == .bubble), seconds: Double(item.liveLocationTimeout), start: item.liveLocationProgress, borderWidth: 2)
            progress.progress = 0
            progress.isHidden = false
            rightView.isHidden = true
        } else {
            progress.isHidden = true
            rightView.isHidden = false
        }
        
        
        progress.startAnimation()
        super.set(item: item, animated: animated)

    }
    
    override func updateColors() {
        super.updateColors()
        liveText.backgroundColor = contentColor
        updatedText.backgroundColor = contentColor
    }
    
    private func textFrame(_ item: ChatRowItem) -> NSRect {
        guard let item = item as? ChatMapRowItem else { return .zero }
        guard let liveText = item.liveText else {return NSZeroRect}
        let contentFrame = self.contentFrame(item)
        return NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultContentInnerInset, liveText.layoutSize.width, liveText.layoutSize.height)
    }
    private func updateFrame(_ item: ChatRowItem) -> NSRect {
        guard let item = item as? ChatMapRowItem else { return .zero }
        guard let updatedText = item.updatedText else {return NSZeroRect}
        let contentFrame = self.contentFrame(item)
        return NSMakeRect(contentFrame.minX + item.elementsContentInset, contentFrame.maxY + item.defaultContentInnerInset + liveText.frame.height, updatedText.layoutSize.width, updatedText.layoutSize.height)
    }
    
    private func progressFrame(_ item: ChatRowItem) -> NSRect {
        let contentFrame = self.contentFrame(item)
        return NSMakeRect(contentFrame.maxX - progress.frame.width - (item.isBubbled ? item.defaultContentInnerInset : 0) - 3, contentFrame.maxY + item.defaultContentInnerInset + 5, 25, 25)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? ChatMapRowItem else { return }

        liveText.frame = textFrame(item)
        updatedText.frame = updateFrame(item)
        progress.frame = progressFrame(item)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
