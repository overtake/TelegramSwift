//
//  PaymentsCheckoutPreviewRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TGUIKit

final class PaymentsCheckoutPreviewRowItem : GeneralRowItem {
    fileprivate let invoice: TelegramMediaInvoice
    fileprivate let textLayout: TextViewLayout
    fileprivate let image: TelegramMediaWebFile?
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, message: Message, viewType: GeneralViewType) {
        self.invoice = message.media.first as! TelegramMediaInvoice
        self.context = context
        self.image = invoice.photo
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: invoice.title, color: theme.colors.text, font: .medium(.text))
        _ = attr.append(string: "\n")
        _ = attr.append(string: invoice.description, color: theme.colors.text, font: .normal(.text))
        _ = attr.append(string: "\n")
        _ = attr.append(string: messageMainPeer(message)?.displayTitle ?? "", color: theme.colors.grayText, font: .normal(.text))
        
        self.textLayout = TextViewLayout(attr)
        super.init(initialSize, viewType: viewType)
    }
    
    private var contentHeight: CGFloat = 0
    fileprivate private(set) var imageSize: NSSize = .zero
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        var height: CGFloat = 0
        if let image = image {
            let imageSize = image.dimensions?.size ?? NSMakeSize(200, 200)
            let halfWidth = blockWidth / 2 - viewType.innerInset.right - viewType.innerInset.left - viewType.innerInset.right
            let fitted = imageSize.aspectFitted(NSMakeSize(halfWidth, halfWidth))
            self.imageSize = fitted
            textLayout.measure(width: blockWidth - fitted.width - viewType.innerInset.right - viewType.innerInset.left - viewType.innerInset.right)
            height = max(fitted.height, textLayout.layoutSize.height)
        } else {
            textLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        }
        contentHeight = height
        return true
    }
    
    override var height: CGFloat {
        return  viewType.innerInset.bottom + contentHeight + viewType.innerInset.top
    }
    
    override func viewClass() -> AnyClass {
        return PaymentsCheckoutPreviewRowView.self
    }
}


private final class PaymentsCheckoutPreviewRowView : GeneralContainableRowView {
    private var imageView: TransformImageView?
    private let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PaymentsCheckoutPreviewRowItem else {
            return
        }
        if let imageView = imageView {
            imageView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
            textView.setFrameOrigin(NSMakePoint(imageView.frame.maxX + item.viewType.innerInset.left, item.viewType.innerInset.top))
        } else {
            textView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        
        guard let item = item as? PaymentsCheckoutPreviewRowItem else {
            return
        }
        
        textView.update(item.textLayout)
        
        if let image = item.image {
            if imageView == nil {
                self.imageView = TransformImageView()
                addSubview(self.imageView!)
            }
            
            self.imageView?.setFrameSize(item.imageSize)
            imageView?.setSignal(chatMessageWebFilePhoto(account: item.context.account, photo: image, scale: backingScaleFactor))
            
            _ = fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, reference: MediaResourceReference.standalone(resource: image.resource)).start()

            imageView?.set(arguments: TransformImageArguments.init(corners: .init(radius: .cornerRadius), imageSize: item.imageSize, boundingSize: item.imageSize, intrinsicInsets: .init()))

        } else {
            imageView?.removeFromSuperview()
            imageView = nil
        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
