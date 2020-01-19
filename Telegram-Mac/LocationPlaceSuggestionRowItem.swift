//
//  LocationPlaceSuggestionRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox

private let randomColors = [NSColor(rgb: 0xe56cd5), NSColor(rgb: 0xf89440), NSColor(rgb: 0x9986ff), NSColor(rgb: 0x44b3f5), NSColor(rgb: 0x6dc139), NSColor(rgb: 0xff5d5a), NSColor(rgb: 0xf87aad), NSColor(rgb: 0x6e82b3), NSColor(rgb: 0xf5ba21)]

private let venueColors: [String: NSColor] = [
    "building/medical": NSColor(rgb: 0x43b3f4),
    "building/gym": NSColor(rgb: 0x43b3f4),
    "arts_entertainment": NSColor(rgb: 0xe56dd6),
    "travel/bedandbreakfast": NSColor(rgb: 0x9987ff),
    "travel/hotel": NSColor(rgb: 0x9987ff),
    "travel/hostel": NSColor(rgb: 0x9987ff),
    "travel/resort": NSColor(rgb: 0x9987ff),
    "building": NSColor(rgb: 0x6e81b2),
    "education": NSColor(rgb: 0xa57348),
    "event": NSColor(rgb: 0x959595),
    "food": NSColor(rgb: 0xf7943f),
    "education/cafeteria": NSColor(rgb: 0xf7943f),
    "nightlife": NSColor(rgb: 0xe56dd6),
    "travel/hotel_bar": NSColor(rgb: 0xe56dd6),
    "parks_outdoors": NSColor(rgb: 0x6cc039),
    "shops": NSColor(rgb: 0xffb300),
    "travel": NSColor(rgb: 0x1c9fff),
    "work": NSColor(rgb: 0xad7854),
    "home": NSColor(rgb: 0x00aeef)
]

func venueIconColor(type: String) -> NSColor {
    if type.isEmpty {
        return NSColor(rgb: 0x008df2)
    }
    if let color = venueColors[type] {
        return color
    }
    let generalType = type.components(separatedBy: "/").first ?? type
    if let color = venueColors[generalType] {
        return color
    }
    
    let index = Int(abs(persistentHash32(type)) % Int32(randomColors.count))
    return randomColors[index]
}



class LocationPlaceSuggestionRowItem: GeneralRowItem {
    private let result: ChatContextResult
    fileprivate let textLayout: TextViewLayout
    fileprivate let image: TelegramMediaImage?
    fileprivate let account: Account
    fileprivate let color: NSColor
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, result: ChatContextResult, action: @escaping()->Void) {
        self.result = result
        self.account = account
        let attr = NSMutableAttributedString()
        var image: TelegramMediaImage? = nil
        switch result {
        case let .externalReference(_, _, _, _, _, _, _, _, message):
           
            switch message {
            case let .mapLocation(media, _):
                if let venue = media.venue {
                    _ = attr.append(string: venue.title, color: theme.colors.text, font: .medium(.text))
                    _ = attr.append(string: "\n")
                    _ = attr.append(string: venue.address, color: theme.colors.grayText, font: .normal(.text))
                    if let type = venue.type {
                        let resource = HttpReferenceMediaResource(url: "https://ss3.4sqi.net/img/categories_v2/\(type)_88.png", size: nil)
                        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 60, height: 60), resource: resource)
                        image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                    }
                }
                self.color = venueIconColor(type: media.venue?.type ?? "")
            default:
                self.color = venueIconColor(type: "")
            }
            textLayout = TextViewLayout(attr, maximumNumberOfLines: 2)
        default:
            fatalError()
        }
        
        self.image = image
        
        super.init(initialSize, height: 60, stableId: stableId, action: action, inset: NSEdgeInsetsMake(0, 10, 0, 10))
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - inset.left - inset.right - 50 - 10)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return LocationPlaceSuggestionRowView.self
    }
    
}

private final class LocationPlaceSuggestionRowView : TableRowView {
    private let thumbHolder: View = View()
    private let textView: TextView = TextView()
    private let imageView: TransformImageView = TransformImageView(frame: NSMakeRect(0, 0, 40, 40))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(thumbHolder)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        thumbHolder.setFrameSize(50, 50)
        thumbHolder.layer?.cornerRadius = 25
        thumbHolder.addSubview(imageView)
        textView.isEventLess = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() {
            guard let item = item as? GeneralRowItem else {return}
            item.action()
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func updateColors() {
        super.updateColors()
        
        guard let item = item as? LocationPlaceSuggestionRowItem else {return}

        
        textView.backgroundColor = theme.colors.background
        thumbHolder.backgroundColor = item.color
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? LocationPlaceSuggestionRowItem else {return}
        
        textView.update(item.textLayout)
        imageView.isHidden = item.image == nil
        if let image = item.image {
            imageView.setSignal(chatWebpageSnippetPhoto(account: item.account, imageReference: ImageMediaReference.standalone(media: image), scale: backingScaleFactor, small: true))
            imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: NSMakeSize(40, 40), boundingSize: NSMakeSize(40, 40), intrinsicInsets: NSEdgeInsetsZero, resizeMode: .imageColor(theme.colors.grayIcon)))
        }
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {return}

        thumbHolder.centerY(x: item.inset.left)
        textView.centerY(x: thumbHolder.frame.maxX + 10)
        imageView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
