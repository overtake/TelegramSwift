//
//  GroupNameRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 26/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

class GroupNameRowItem: GeneralInputRowItem {

    var photo:String?
    fileprivate let pickPicture: ((Bool)->Void)?
    fileprivate let account: Account
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, placeholder: String, photo: String? = nil, text:String = "", limit: Int32 = 140, textChangeHandler:@escaping(String)->Void = {_ in}, pickPicture: ((Bool)->Void)? = nil) {
        self.photo = photo
        self.account = account
        self.pickPicture = pickPicture
        super.init(initialSize, stableId: stableId, placeholder: placeholder, text: text, limit: limit, textChangeHandler:textChangeHandler, automaticallyBecomeResponder: false)
    }
    
    override func viewClass() -> AnyClass {
        return GroupNameRowView.self
    }
    
    override var height: CGFloat {
        return 80
    }
    
}




class GroupNameRowView : GeneralInputRowView {
    private let imageView:ImageView = ImageView()
    private let sepator:View = View()
    private let photoView: TransformImageView = TransformImageView()
    private let tranparentView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.isSingleLine = true
        addSubview(sepator)
        addSubview(photoView)
        addSubview(tranparentView)
        addSubview(imageView)
        photoView.setFrameSize(50, 50)
        tranparentView.setFrameSize(50, 50)
        
        tranparentView.layer?.cornerRadius = 25
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupNameRowItem else {return}
        
        photoView.isHidden = item.photo == nil
        
        if let path = item.photo, let image = NSImage(contentsOf: URL(fileURLWithPath: path)) {
            
            let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
            let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: image.size, resource: resource)], reference: nil)
            photoView.setSignal(chatMessagePhoto(account: item.account, photo: image, scale: backingScaleFactor), clearInstantly: false)
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: photoView.frame.width / 2), imageSize: photoView.frame.size, boundingSize: photoView.frame.size, intrinsicInsets: NSEdgeInsets())
            photoView.set(arguments: arguments)
            
        }
        tranparentView.backgroundColor = item.photo == nil ? NSColor.clear : theme.colors.blackTransparent
        sepator.backgroundColor = theme.colors.border
        imageView.image = theme.icons.newChatCamera
        imageView.sizeToFit()
    }
    
    
    
    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if NSPointInRect(point, photoView.frame) {
            if let item = item as? GroupNameRowItem {
                if item.photo == nil {
                    item.pickPicture?(true)
                } else {
                    ContextMenu.show(items: [ContextMenuItem(tr(L10n.peerCreatePeerContextUpdatePhoto), handler: {
                        item.pickPicture?(true)
                    }), ContextMenuItem(tr(L10n.peerCreatePeerContextRemovePhoto), handler: {
                        item.pickPicture?(false)
                    })], view: photoView, event: event)
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        textView.frame = NSMakeRect(100, 0, frame.width - 140 ,textView.frame.height)
        textView.centerY()
        imageView.setFrameOrigin(30 + floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - imageView.frame.width)/2.0), 17 + floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - imageView.frame.height)/2.0))
        sepator.frame = NSMakeRect(105, textView.frame.maxY - .borderSize, frame.width - 140, .borderSize)
        photoView.setFrameOrigin(30 + floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - photoView.frame.width)/2.0), 17 + floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - photoView.frame.height)/2.0))
        tranparentView.setFrameOrigin(30 + floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - tranparentView.frame.width)/2.0), 17 + floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - tranparentView.frame.height)/2.0))

    }
    
    override func textViewTextDidChange(_ string: String) {
        super.textViewTextDidChange(string)
    }
    
    override func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        textView._change(pos: NSMakePoint(100, floorToScreenPixels(scaleFactor: backingScaleFactor, (frame.height - height)/2.0)), animated: animated)
        super.textViewHeightChanged(height, animated: animated)
        sepator._change(pos: NSMakePoint(105, textView.frame.maxY - .borderSize), animated: animated)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setStrokeColor(theme.colors.grayIcon.cgColor)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: NSMakeRect(30, 17, 50, 50))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
