//
//  GroupNameRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 26/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox

class GroupNameRowItem: InputDataRowItem {

    var photo:String?
    fileprivate let pickPicture: ((Bool)->Void)?
    fileprivate let account: Account
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, placeholder: String, photo: String? = nil, viewType: GeneralViewType = .legacy, text:String = "", limit: Int32 = 140, textChangeHandler:@escaping(String)->Void = {_ in}, pickPicture: ((Bool)->Void)? = nil) {
        self.photo = photo
        self.account = account
        self.pickPicture = pickPicture
        super.init(initialSize, stableId: stableId, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: placeholder, filter: { $0 }, updated: textChangeHandler, limit: limit)

    }
    
    override func viewClass() -> AnyClass {
        return GroupNameRowView.self
    }
    
    override var textFieldLeftInset: CGFloat {
        return 60
    }
    
    override var height: CGFloat {
        switch viewType {
        case .legacy:
            return max(80, super.height)
        case let .modern(_, insets):
            return max(insets.bottom + insets.top + 50, super.height)
        }
    }
    
}


class GroupNameRowView : InputDataRowView {
    private let imageView:ImageView = ImageView()
    private let photoView: TransformImageView = TransformImageView()
    private let tranparentView: View = View()
    private let circleView = View(frame: NSMakeRect(0, 0, 50, 50))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(photoView)
        containerView.addSubview(tranparentView)
        containerView.addSubview(imageView)
        containerView.addSubview(circleView)
        photoView.setFrameSize(50, 50)
        tranparentView.setFrameSize(50, 50)
        photoView.animatesAlphaOnFirstTransition = true
        tranparentView.layer?.cornerRadius = 25
        circleView.layer?.cornerRadius = 25
        circleView.layer?.borderWidth = .borderSize
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupNameRowItem else {return}
        
        photoView.isHidden = item.photo == nil
        imageView.isHidden = item.photo != nil
        if let path = item.photo, let image = NSImage(contentsOf: URL(fileURLWithPath: path)) {
            
            let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
            let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(image.size), resource: resource, progressiveSizes: [])], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            photoView.setSignal(chatMessagePhoto(account: item.account, imageReference: ImageMediaReference.standalone(media: image), scale: backingScaleFactor), clearInstantly: false, animate: true)
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: photoView.frame.width / 2), imageSize: photoView.frame.size, boundingSize: photoView.frame.size, intrinsicInsets: NSEdgeInsets())
            photoView.set(arguments: arguments)
            
        }
        circleView.isHidden = item.photo != nil
        tranparentView.backgroundColor = NSColor.clear
        imageView.image = theme.icons.newChatCamera
        imageView.sizeToFit()
    }
    
    override func updateColors() {
        super.updateColors()
        circleView.layer?.borderColor = theme.colors.grayIcon.cgColor
    }
    
    override func mouseUp(with event: NSEvent) {
        let point = containerView.convert(event.locationInWindow, from: nil)
        if NSPointInRect(point, photoView.frame) {
            if let item = item as? GroupNameRowItem {
                if item.photo == nil {
                    item.pickPicture?(true)
                } else {
                    ContextMenu.show(items: [ContextMenuItem(L10n.peerCreatePeerContextUpdatePhoto, handler: {
                        item.pickPicture?(true)
                    }), ContextMenuItem(L10n.peerCreatePeerContextRemovePhoto, handler: {
                        item.pickPicture?(false)
                    })], view: photoView, event: event)
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GroupNameRowItem else {return}

        switch item.viewType {
        case .legacy:
            imageView.setFrameOrigin(30 + floorToScreenPixels(backingScaleFactor, (50 - imageView.frame.width)/2.0), 17 + floorToScreenPixels(backingScaleFactor, (50 - imageView.frame.height)/2.0))
            photoView.setFrameOrigin(30 + floorToScreenPixels(backingScaleFactor, (50 - photoView.frame.width)/2.0), 17 + floorToScreenPixels(backingScaleFactor, (50 - photoView.frame.height)/2.0))
            tranparentView.setFrameOrigin(30 + floorToScreenPixels(backingScaleFactor, (50 - tranparentView.frame.width)/2.0), 17 + floorToScreenPixels(backingScaleFactor, (50 - tranparentView.frame.height)/2.0))
        case let .modern(_, insets):
            circleView.setFrameOrigin(insets.left, insets.top)
            imageView.setFrameOrigin(insets.left + floorToScreenPixels(backingScaleFactor, (50 - imageView.frame.width) / 2), insets.top + floorToScreenPixels(backingScaleFactor, (50 - imageView.frame.height) / 2))
            photoView.setFrameOrigin(insets.left, insets.top)
            tranparentView.setFrameOrigin(insets.left, insets.top)
            textView.centerY(x: insets.left + item.textFieldLeftInset - 3)

        }

    }
    
    override func textViewTextDidChange(_ string: String) {
        super.textViewTextDidChange(string)
    }
    
    override func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        super.textViewHeightChanged(height, animated: animated)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
