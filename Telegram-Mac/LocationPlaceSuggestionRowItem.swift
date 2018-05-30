//
//  LocationPlaceSuggestionRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

class LocationPlaceSuggestionRowItem: GeneralRowItem {
    private let result: ChatContextResult
    fileprivate let textLayout: TextViewLayout
    fileprivate let image: TelegramMediaImage?
    fileprivate let account: Account
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, result: ChatContextResult, action: @escaping()->Void) {
        self.result = result
        self.account = account
        let attr = NSMutableAttributedString()
        var image: TelegramMediaImage? = nil
        switch result {
        case let .externalReference(_, _, _, _, _, _, _, message):
           
            switch message {
            case let .mapLocation(media, _):
                if let venue = media.venue {
                    _ = attr.append(string: venue.title, color: theme.colors.text, font: .medium(.text))
                    _ = attr.append(string: "\n")
                    _ = attr.append(string: venue.address, color: theme.colors.grayText, font: .normal(.text))
                    if let type = venue.type {
                        let resource = HttpReferenceMediaResource(url: "https://ss3.4sqi.net/img/categories_v2/\(type)_88.png", size: nil)
                        let representation = TelegramMediaImageRepresentation(dimensions: NSMakeSize(60, 60), resource: resource)
                        image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [representation], reference: nil)

                    }
                }
            default:
                break
            }
            textLayout = TextViewLayout(attr, maximumNumberOfLines: 2)
        default:
            fatalError()
        }
        
        self.image = image
        
        super.init(initialSize, height: 60, stableId: stableId, action: action, inset: NSEdgeInsetsMake(0, 10, 0, 10))
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        
        textLayout.measure(width: width - inset.left - inset.right - 50 - 10)
        return super.makeSize(width, oldWidth: oldWidth)
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
        textView.backgroundColor = theme.colors.background
        thumbHolder.backgroundColor = theme.colors.grayBackground
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? LocationPlaceSuggestionRowItem else {return}
        
        textView.update(item.textLayout)
        imageView.isHidden = item.image == nil
        if let image = item.image {
            imageView.setSignal(chatWebpageSnippetPhoto(account: item.account, photo: image, scale: backingScaleFactor, small: true))
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
