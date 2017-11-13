//
//  PreviewSenderItems.swift
//  TelegramMac
//
//  Created by keepcoder on 11/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac
class PreviewDocumentRowItem: TableRowItem {
    let url:URL
    let account:Account
    let thumb:CGImage
    let name:(TextNodeLayout, TextNode)
    init(_ initialSize:NSSize, url:URL, account:Account) {
        self.url = url
        self.thumb = extensionImage(fileExtension: url.pathExtension.isEmpty ? "F" : url.pathExtension)!
        self.account = account
        self.name = TextNode.layoutText(maybeNode: nil,  .initialize(string: url.path.nsstring.lastPathComponent, color: theme.colors.text, font: .normal(.text)), nil, 1, .end, NSMakeSize(initialSize.width - (30 + 40 + 10 + 30), 20), nil, false, .left)
        super.init(initialSize)
    }
    private let _stableId = Int64(arc4random())
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return 100
    }
    
    override func viewClass() -> AnyClass {
        return PreviewDocumentRowView.self
    }
}

class PreviewDocumentRowView : TableRowView {
    
    var imageView:ImageView = ImageView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item,animated:animated)
        
        if let item = item as? PreviewDocumentRowItem {
            imageView.image = item.thumb
        }
        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item as? PreviewDocumentRowItem {
            let f = focus(item.name.0.size)
            item.name.1.draw(NSMakeRect(80, f.minY, item.name.0.size.width, item.name.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
        }
    }
    
    override func layout() {
        super.layout()
        if let item = item as? PreviewDocumentRowItem {
            imageView.setFrameSize(item.thumb.backingSize)
            imageView.centerY(x:30)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}




class PreviewThumbRowItem :TableRowItem {
    let url:URL
    let account:Account
    let thumbSize:NSSize
    init(_ initialSize:NSSize, url:URL, account:Account) {
        self.url = url
        self.account = account
        self.thumbSize = NSImage(contentsOf: url)?.size ?? NSZeroSize
        
        super.init(initialSize)
    }
    private let _stableId = Int64(arc4random())
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return 140
    }
    
    override func viewClass() -> AnyClass {
        return PreviewThumbRowView.self
    }
}

class PreviewThumbRowView : TableRowView {
    
    var imageView:TransformImageView = TransformImageView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item,animated:animated)
        
        if let item = item as? PreviewThumbRowItem {
            imageView.setSignal( filethumb(with: item.url, account:item.account, scale: backingScaleFactor))
        }
        
    }
    
    override func layout() {
        super.layout()
        if let item = item as? PreviewThumbRowItem {
            
            let boundingSize = NSMakeSize(frame.size.width - 20, frame.size.height - 20)
            
            let imageSize = item.thumbSize.aspectFitted(boundingSize)
            let arguments = TransformImageArguments(corners: ImageCorners(radius:.cornerRadius), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: NSEdgeInsets())
            
            imageView.setFrameSize(arguments.imageSize)
            imageView.center()
            imageView.set(arguments: arguments)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


//enum MultiplePreviewSetting {
//    case files
//    case images
//    case mixed
//}
//
//class MultiplePreviewRowItem :TableRowItem {
//    let urls:[URL]
//    let account:Account
//    let textLayout:TextViewLayout
//    init(_ initialSize:NSSize, urls:[URL], options:[PreviewOptions], account:Account, onExpand:@escaping()->Void) {
//        self.urls = urls
//        self.account = account
//        
//        let text:String
//        if options.contains(.mixed) {
//            text = tr(.previewSenderSendMediaFilesCountable(urls.count))
//        } else if options.contains(.image) {
//            text = tr(.previewSenderSendImagesCountable(urls.count))
//        } else if options.contains(.video) {
//            text = tr(.previewSenderSendVideosCountable(urls.count))
//        } else {
//            text = tr(.previewSenderSendFilesCountable(urls.count))
//        }
//       // let text:String = localizedString(localizedKey, countable:urls.count)
//        let attr = NSMutableAttributedString()
//        _ = attr.append(string: text, color: .text, font: .normal(.title))
//        _ = attr.append(string: " (", color: .text, font: .normal(.title))
//        let range = attr.append(string: tr(.previewSenderExpandItems), color: .link, font: .normal(.title))
//        
//        attr.add(link: "expand", for: range)
//        _ = attr.append(string: ")", color: .text, font: .normal(.title))
//        textLayout = TextViewLayout(attr)
//        textLayout.measure(width: initialSize.width - 60)
//        textLayout.interactions = TextViewInteractions(processURL: { (any) in
//            onExpand()
//        })
//        super.init(initialSize)
//    }
//    
//    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
//        textLayout.measure(width: width - 60)
//        return super.makeSize(width, oldWidth: oldWidth)
//    }
//    
//    private let _stableId = Int64(arc4random())
//    override var stableId: AnyHashable {
//        return _stableId
//    }
//    
//    override var height: CGFloat {
//        return 60
//    }
//    
//    override func viewClass() -> AnyClass {
//        return MultiplePreviewRowView.self
//    }
//}
//
//class MultiplePreviewRowView : TableRowView {
//    private let textView:TextView = TextView()
//    required init(frame frameRect: NSRect) {
//        super.init(frame: frameRect)
//        addSubview(textView)
//    }
//    
//    override func layout() {
//        super.layout()
//        if let item = item as? MultiplePreviewRowItem {
//            textView.update(item.textLayout)
//            textView.centerY(x: 30)
//        }
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//}


class ExpandedPreviewRowItem : TableRowItem {
    fileprivate let onDelete:(ExpandedPreviewRowItem)->Void
    fileprivate let url:URL
    fileprivate let textLayout:TextViewLayout
    fileprivate let thumbSize:NSSize
    fileprivate let account:Account
    fileprivate let thumb:CGImage?
    init(_ initialSize: NSSize, account:Account, url:URL, onDelete:@escaping(ExpandedPreviewRowItem)->Void) {
        self.onDelete = onDelete
        self.url = url
        self.account = account
        self.textLayout = TextViewLayout(.initialize(string: url.path.nsstring.lastPathComponent, color: theme.colors.grayText, font: NSFont.normal(FontSize.text)), maximumNumberOfLines: 2, truncationType: .middle)
        self.textLayout.measure(width: initialSize.width - 60 - 20 - 40 - 10 - 10)
        let mimeType = MIMEType(url.pathExtension.lowercased())
        if mimeType.hasPrefix("image"), let image = NSImage(contentsOf: url) {
            self.thumbSize = image.size.aspectFilled(NSMakeSize(40, 40))
            self.thumb = nil
        } else {
            self.thumbSize = NSMakeSize(40, 40)
            self.thumb = extensionImage(fileExtension: url.path.nsstring.pathExtension.lowercased())!
        }

        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return url.hashValue
    }
    
    override var height: CGFloat {
        return 50 //max(thumbSize.height + 20,50)
    }
    
    override func viewClass() -> AnyClass {
        return ExpandedPreviewRowView.self
    }
}

class ExpandedPreviewRowView : TableRowView {
    private let textView:TextView = TextView()
    private let deleteControl:ImageButton = ImageButton()
    private let imageView:TransformImageView = TransformImageView()
    private let thumbView:ImageView = ImageView()
    private var arguments:TransformImageArguments?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        deleteControl.autohighlight = false
        
        
        deleteControl.set(handler: { [weak self] _ in
            if let item = self?.item as? ExpandedPreviewRowItem {
                item.onDelete(item)
            }
        }, for: .Click)
        textView.isSelectable = false
        addSubview(textView)
        addSubview(deleteControl)
        addSubview(imageView)
        addSubview(thumbView)
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ExpandedPreviewRowItem {
            deleteControl.centerY(x:30)
            
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: 20), imageSize: item.thumbSize, boundingSize: NSMakeSize(40, 40), intrinsicInsets: NSEdgeInsets())
            
            
            imageView.setFrameSize(arguments.boundingSize)
            imageView.set(arguments: arguments)
            
            thumbView.setFrameSize(arguments.boundingSize)
            thumbView.centerY(x:deleteControl.frame.maxX + 10)
            imageView.centerY(x:deleteControl.frame.maxX + 10 + floorToScreenPixels((40 - imageView.frame.width)/2))
            
            textView.update(item.textLayout)
            textView.centerY(x: deleteControl.frame.maxX + 40 + 20)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        if let item = item as? ExpandedPreviewRowItem {
            deleteControl.set(image: theme.icons.deleteItem, for: .Normal)
            deleteControl.sizeToFit()
            textView.backgroundColor = theme.colors.background
            imageView.dispose()
            if let thumb = item.thumb {
                thumbView.image = thumb
            } else {
                imageView.setSignal( filethumb(with: item.url, account:item.account, scale: backingScaleFactor))
            }
            thumbView.isHidden = item.thumb == nil
            imageView.isHidden = !thumbView.isHidden
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
