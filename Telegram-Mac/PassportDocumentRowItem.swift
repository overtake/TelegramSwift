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
import SwiftSignalKitMac

class PassportDocumentRowItem: GeneralRowItem, InputDataRowDataValue {

    fileprivate let title: TextViewLayout
    fileprivate let status: TextViewLayout
    fileprivate let removeAction:(SecureIdVerificationDocument)->Void
    fileprivate let account: Account
    
    fileprivate let documentValue: SecureIdDocumentValue
    
    var value: InputDataValue {
        return .secureIdDocument(documentValue.document)
    }
    fileprivate var accessContext: SecureIdAccessContext {
        return documentValue.context
    }
    var image: TelegramMediaImage {
        return documentValue.image
    }
    
    fileprivate private(set) var uploadingProgress: Float?
    
    init(_ initialSize: NSSize, account: Account, document: SecureIdDocumentValue, error: InputDataValueError?, header: String, removeAction:@escaping(SecureIdVerificationDocument)->Void) {
        self.documentValue = document
        self.account = account
        title = TextViewLayout(.initialize(string: header, color: theme.colors.text, font: .normal(.text)))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = NSTimeZone.local
        formatter.timeStyle = .short

        switch document.document {
        case let .remote(file):
            if let error = error {
                status = TextViewLayout(.initialize(string: error.description, color: theme.colors.redUI, font: .normal(.text)), maximumNumberOfLines: 1)
            } else {
                status = TextViewLayout(.initialize(string: formatter.string(from: Date(timeIntervalSince1970: TimeInterval(file.timestamp))), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
            }
        case let .local(file):
            switch file.state {
            case .uploaded:
                status = TextViewLayout(.initialize(string: formatter.string(from: Date()), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
            case let .uploading(progress):
                uploadingProgress = progress
                status = TextViewLayout(.initialize(string: L10n.secureIdFileUploadProgress("\(Int(progress * 100.0))"), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
            }
        }
        
        self.removeAction = removeAction
        super.init(initialSize, stableId: document.stableId, error: error)
        
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
    private let progressView: RadialProgressView = RadialProgressView()
    private let downloadingProgress: MetaDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(statusView)
        addSubview(imageView)
        addSubview(removeButton)
        imageView.setFrameSize(NSMakeSize(60, 50))
        
        removeButton.set(handler: { [weak self] _ in
            guard let item = self?.item as? PassportDocumentRowItem else {return}
            item.removeAction(item.documentValue.document)
        }, for: .Click)
    }
    
    override func shakeView() {
        statusView.shake()
    }
    
    deinit {
        downloadingProgress.dispose()
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GeneralRowItem else {return}
        imageView.centerY(x: item.inset.left)
        titleView.setFrameOrigin(imageView.frame.maxX + 10, 10)
        statusView.setFrameOrigin(imageView.frame.maxX + 10, frame.height - 10 - statusView.frame.height)
        removeButton.centerY(x: frame.width - removeButton.frame.width - item.inset.right)
        progressView.center()
    }
    
    override func mouseUp(with event: NSEvent) {
        if imageView._mouseInside() {
            guard let item = item as? PassportDocumentRowItem, let table = item.table else {return}
            var passportItems:[PassportDocumentRowItem] = []
            table.enumerateItems { item -> Bool in
                if let item = item as? PassportDocumentRowItem {
                    passportItems.append(item)
                }
                return true
            }
            let index = passportItems.index(of: item)!
            showSecureIdDocumentsGallery(account: item.account, medias: passportItems.map({$0.documentValue}), firstIndex: index, item.table)
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        guard let item = item as? PassportDocumentRowItem, let table = item.table else {return}

        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(imageView.frame.maxX + 10, frame.height - .borderSize, frame.width - imageView.frame.maxX - item.inset.right - 10, .borderSize))
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool) -> NSView {
        return imageView
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
        
        if let progress = item.uploadingProgress {
            progressView.state = .Fetching(progress: progress, force: false)
            if progressView.superview == nil {
                imageView.addSubview(progressView)
            }
        } else {
            progressView.state = .None
            progressView.removeFromSuperview()
        }
        
        downloadingProgress.set((chatMessagePhotoStatus(account: item.account, photo: item.image) |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let `self` = self else {return}
            guard let item = self.item as? PassportDocumentRowItem else {return}
            switch status {
            case let .Fetching(_, progress):
                self.progressView.state = .Fetching(progress: progress, force: false)
                if self.progressView.superview == nil {
                    self.imageView.addSubview(self.progressView)
                    self.progressView.center()
                }
               
            default:
                if item.uploadingProgress == nil {
                    self.progressView.state = .None
                    self.progressView.removeFromSuperview()
                }
            }
        }))
        
        self.progressView.fetchControls = FetchControls(fetch: { [weak item] in
            guard let item = item else {return}
            item.removeAction(item.documentValue.document)
        })
        
        imageView.setSignal(chatWebpageSnippetPhoto(account: item.account, photo: item.image, scale: backingScaleFactor, small: true, secureIdAccessContext: item.accessContext))
        _ = chatMessagePhotoInteractiveFetched(account: item.account, photo: item.documentValue.image).start()
        imageView.set(arguments: TransformImageArguments(corners: .init(radius: .cornerRadius), imageSize: NSMakeSize(60, 50), boundingSize: NSMakeSize(60, 50), intrinsicInsets: NSEdgeInsets()))
        removeButton.set(image: theme.icons.stickerPackDelete, for: .Normal)
        _ = removeButton.sizeToFit()
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
