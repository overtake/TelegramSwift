//
//  PassportDocumentRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

class PassportDocumentRowItem: GeneralRowItem, InputDataRowDataValue {

    fileprivate let title: TextViewLayout
    fileprivate let status: TextViewLayout
    fileprivate let removeAction:(SecureIdVerificationDocument)->Void
    fileprivate let account: Account
    fileprivate let accessContext: SecureIdAccessContext
    fileprivate let document: SecureIdVerificationDocument
    
    var value: InputDataValue {
        return .secureIdDocument(document)
    }
    
    var image: TelegramMediaImage {
        return TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [TelegramMediaImageRepresentation(dimensions: NSMakeSize(100, 100), resource: document.resource)], reference: nil)
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, accessContext: SecureIdAccessContext, document: SecureIdVerificationDocument, header: String, removeAction:@escaping(SecureIdVerificationDocument)->Void) {
        self.document = document
        self.account = account
        self.accessContext = accessContext
        title = TextViewLayout(.initialize(string: header, color: theme.colors.text, font: .normal(.text)))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = NSTimeZone.local
        formatter.timeStyle = .short

        switch document {
        case let .remote(file):
            status = TextViewLayout(.initialize(string: formatter.string(from: Date(timeIntervalSince1970: TimeInterval(file.timestamp))), color: theme.colors.grayText, font: .normal(.text)))
        case let .local(file):
            switch file.state {
            case .uploaded:
                status = TextViewLayout(.initialize(string: formatter.string(from: Date()), color: theme.colors.grayText, font: .normal(.text)))
            case let .uploading(progress):
                status = TextViewLayout(.initialize(string: L10n.secureIdFileUploadProgress("\(Int(progress * 100.0))"), color: theme.colors.grayText, font: .normal(.text)))
            }
        }
        
        self.removeAction = removeAction
        super.init(initialSize, stableId: stableId)
        
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func viewClass() -> AnyClass {
        return PassportDocumentRowView.self
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        title.measure(width: width)
        status.measure(width: width)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override var height: CGFloat {
        return 60
    }
    
}


final class PassportDocumentRowView : TableRowView {
    private let statusView = TextView()
    private let titleView = TextView()
    private let imageView = TransformImageView()
    private let removeButton = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(statusView)
        addSubview(imageView)
        addSubview(removeButton)
        imageView.setFrameSize(NSMakeSize(60, 50))
        
        removeButton.set(handler: { [weak self] _ in
            guard let item = self?.item as? PassportDocumentRowItem else {return}
            item.removeAction(item.document)
        }, for: .Click)
    }
    
    override func shakeView() {
        statusView.shake()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? PassportDocumentRowItem else {return}

       // ctx.setFillColor(theme.colors.border.cgColor)
    //    ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
        
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GeneralRowItem else {return}
        imageView.centerY(x: item.inset.left)
        titleView.setFrameOrigin(imageView.frame.maxX + 10, 10)
        statusView.setFrameOrigin(imageView.frame.maxX + 10, frame.height - 10 - statusView.frame.height)
        removeButton.centerY(x: frame.width - removeButton.frame.width - item.inset.right)
    }
    
    override func updateColors() {
        super.updateColors()
        statusView.backgroundColor = theme.colors.background
        titleView.backgroundColor = theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PassportDocumentRowItem else {return}
        statusView.update(item.status)
        titleView.update(item.title)
        
        
        imageView.setSignal(chatMessagePhotoThumbnail(account: item.account, photo: item.image, secureIdAccessContext: item.accessContext))
        _ = chatMessagePhotoInteractiveFetched(account: item.account, photo: item.image).start()
        
        imageView.set(arguments: TransformImageArguments(corners: .init(radius: .cornerRadius), imageSize: NSMakeSize(60, 50), boundingSize: NSMakeSize(60, 50), intrinsicInsets: NSEdgeInsets()))
        
        removeButton.set(image: theme.icons.stickerPackDelete, for: .Normal)
        _ = removeButton.sizeToFit()
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
