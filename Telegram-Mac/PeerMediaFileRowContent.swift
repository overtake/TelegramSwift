//
//  MediaFileRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit




class PeerMediaFileRowItem: PeerMediaRowItem {
    
    private(set) var nameLayout:TextViewLayout
    private(set) var actionLayout:TextViewLayout
    private(set) var actionLayoutLocal:TextViewLayout
    private(set) var iconArguments:TransformImageArguments?
    private(set) var icon:TelegramMediaImage?
    
    private(set) var file:TelegramMediaFile?
    
    private(set) var docIcon:CGImage?
    private(set) var docTitle:NSAttributedString?
    override init(_ initialSize:NSSize, _ interface:ChatInteraction, _ object: PeerMediaSharedEntry, viewType: GeneralViewType = .legacy) {
        
        
        let message = object.message!
        let file = message.media.first as! TelegramMediaFile
        self.file = file
        
        nameLayout = TextViewLayout(NSAttributedString.initialize(string: file.fileName ?? "Unknown", color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1, truncationType: .end)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h a"
        
        let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: Double(TimeInterval(message.timestamp) - interface.context.timeDifference)))
        
        actionLayout = TextViewLayout(NSAttributedString.initialize(string: "\(dataSizeString(file.size ?? 0)) • \(dateString)",color: theme.colors.grayText, font: NSFont.normal(12.5)), maximumNumberOfLines: 1, truncationType: .end)
        
        let localAction = NSMutableAttributedString()
        let range = localAction.append(string: tr(L10n.contextShowInFinder), color: theme.colors.link, font: .normal(.text))
        localAction.add(link: inAppLink.callback("finder", { _ in
            showInFinder(file, account: interface.context.account)
        }), for: range)
        actionLayoutLocal = TextViewLayout(localAction, maximumNumberOfLines: 1, truncationType: .end)
        actionLayoutLocal.interactions = globalLinkExecutor
        
        let iconImageRepresentation:TelegramMediaImageRepresentation? = smallestImageRepresentation(file.previewRepresentations)
        
        if let iconImageRepresentation = iconImageRepresentation {
            iconArguments = TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: iconImageRepresentation.dimensions.size.aspectFilled(PeerMediaIconSize), boundingSize: PeerMediaIconSize, intrinsicInsets: NSEdgeInsets())
            icon = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil)
        } else {
            let fileName: String = file.fileName ?? ""
            
            var fileExtension: String = "file"
            if let range = fileName.range(of: ".", options: [.backwards]) {
                fileExtension = fileName[range.upperBound...].lowercased()
            }
            if fileExtension.length > 5 {
                fileExtension = "file"
            }
            docIcon = extensionImage(fileExtension: fileExtension)
            
            docTitle = NSAttributedString.initialize(string: fileExtension, color: theme.colors.text, font: .medium(.text))

        }
        super.init(initialSize,interface,object, viewType: viewType)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        let signal = super.menuItems(in: location)
        let context = self.interface.context
        if let file = self.file {
            return signal |> mapToSignal { items -> Signal<[ContextMenuItem], NoError> in
                var items = items
                return context.account.postbox.mediaBox.resourceData(file.resource) |> deliverOnMainQueue |> map {data in
                    if data.complete {
                        items.append(ContextMenuItem(L10n.contextCopyMedia, handler: {
                            saveAs(file, account: context.account)
                        }))
                        items.append(ContextMenuItem(L10n.contextShowInFinder, handler: {
                            showInFinder(file, account: context.account)
                        }))
                    }
                    return items
                }
                
            }
        }
        return signal
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        nameLayout.measure(width: self.blockWidth - contentInset.left - contentInset.right - self.viewType.innerInset.left - self.viewType.innerInset.right)
        actionLayout.measure(width: self.blockWidth - contentInset.left - contentInset.right - self.viewType.innerInset.left - self.viewType.innerInset.right)
        actionLayoutLocal.measure(width: self.blockWidth - contentInset.left - contentInset.right - self.viewType.innerInset.left - self.viewType.innerInset.right)
        return success
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaFileRowView.self
    }
}

class PeerMediaFileRowView : PeerMediaRowView {
    
    var nameView:TextView = TextView()
    var actionView:TextView = TextView()
    var imageView:TransformImageView = TransformImageView(frame:NSMakeRect(0, 0, 40, 40))
    
    private var downloadStatusControl:ImageView?
    private var downloadProgressView:LinearProgressControl?
    
    private let statusDisposable = MetaDisposable()
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var fetchStatus: MediaResourceStatus?
    private let fetchDisposable = MetaDisposable()
    
    required init(frame frameRect: NSRect) {
        nameView.isSelectable = false
        nameView.userInteractionEnabled = false
        actionView.isSelectable = false
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(nameView)
        addSubview(actionView)
        
    }
    
    
    func cancel() -> Void {
        cancelFetching()
    }
    
    func delete() -> Void {
        if let item = item as? PeerMediaFileRowItem {
            let mediaBox = item.interface.context.account.postbox.mediaBox
            let messageId = item.message.id
            _ = item.interface.context.account.postbox.transaction { transaction -> Void in
                deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: [messageId])
            }.start()
        }
    }
    
    func cancelFetching() {
        if let item = item as? PeerMediaFileRowItem, let file = item.file {
            messageMediaFileCancelInteractiveFetch(context: item.interface.context, messageId: item.message.id, fileReference: FileMediaReference.message(message: MessageReference(item.message), media: file))
        }
    }
    
    func open() -> Void {
        if let item = item as? PeerMediaFileRowItem, let file = item.file {
            if file.isGraphicFile {
                showChatGallery(context: item.interface.context, message: item.message, item.table, nil)
            } else {
               QuickLookPreview.current.show(context: item.interface.context, with: file, stableId:item.message.chatStableId, item.table)
            }
        }
    }
    
    func fetch() -> Void {
        if let item = item as? PeerMediaFileRowItem, let file = item.file {
            fetchDisposable.set(messageMediaFileInteractiveFetched(context: item.interface.context, messageId: item.message.id, fileReference: FileMediaReference.message(message: MessageReference(item.message), media: file)).start())
        }
    }
    
    func executeInteraction(_ isControl:Bool) -> Void {
        if let fetchStatus = self.fetchStatus, let item = item as? PeerMediaRowItem {
            switch fetchStatus {
            case .Fetching:
                if isControl {
                    if item.message.flags.contains(.Unsent) && !item.message.flags.contains(.Failed) {
                        delete()
                    }
                    cancel()
                } else {
                    open()
                }
            case .Remote:
                if isControl {
                    fetch()
                } else {
                    open()
                }
            case .Local:
                open()
                break
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if let item = item as? PeerMediaRowItem, !(item.interface.presentation.state == .selecting) {
            if imageView._mouseInside() {
                executeInteraction(true)
                return
            } else if let status = self.fetchStatus {
                switch status {
                case .Remote:
                    executeInteraction(true)
                case .Fetching:
                    executeInteraction(true)
                default:
                    break
                }
            }
        }
        super.mouseUp(with: event)
    }
    
    override func layout() {
        super.layout()
        if let item = item as? PeerMediaRowItem {
            if let downloadProgressView = downloadProgressView {
                downloadProgressView.frame = NSMakeRect(item.separatorOffset, containerView.frame.height - 4, containerView.frame.width - item.separatorOffset - item.viewType.innerInset.right, 4)
            }
            if let downloadStatusControl = downloadStatusControl {
                downloadStatusControl.setFrameOrigin(NSMakePoint(item.contentInset.left, contentView.frame.height - 4 - downloadStatusControl.frame.height))
                actionView.setFrameOrigin(item.contentInset.left + downloadStatusControl.frame.width + 2.0,actionView.frame.minY)
            } else {
                actionView.setFrameOrigin(item.contentInset.left, actionView.frame.minY)
            }
        }
        
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return imageView
    }
    
    deinit {
        statusDisposable.dispose()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateSelectingMode(with selectingMode: Bool, animated: Bool = false) {
        super.updateSelectingMode(with: selectingMode, animated: animated)
        if let status = fetchStatus {
            if case .Local = status {
               self.actionView.userInteractionEnabled = !selectingMode
            } else {
               self.actionView.userInteractionEnabled = false
            }
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        let previous = self.item as? PeerMediaFileRowItem
        super.set(item: item, animated: animated)
        
        statusDisposable.set(nil)
        nameView.backgroundColor = theme.colors.background
        actionView.backgroundColor = theme.colors.background
        if let item = item as? PeerMediaFileRowItem {
            nameView.update(item.nameLayout, origin: NSMakePoint(item.contentInset.left, item.contentInset.top + 2))
            actionView.update(item.actionLayout, origin: NSMakePoint(item.contentInset.left, item.contentSize.height - item.actionLayout.layoutSize.height - item.contentInset.bottom - 2))
            
            let updateIconImageSignal:Signal<ImageDataTransformation,NoError>
            if let icon = item.icon {
                updateIconImageSignal = chatWebpageSnippetPhoto(account: item.interface.context.account, imageReference: ImageMediaReference.message(message: MessageReference(item.message), media: icon), scale: backingScaleFactor, small:true)
            } else {
                updateIconImageSignal = .complete()
            }
            
            imageView.setSignal( updateIconImageSignal)
            if let arguments = item.iconArguments {
                imageView.set(arguments: arguments)
            } else {
                imageView.layer?.contents = item.docIcon
            }
            
            
            var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
            var updatedFetchControls: FetchControls?
            
            let context = item.interface.context
            if let file = item.file {
                updatedStatusSignal = chatMessageFileStatus(account: context.account, file: file, approximateSynchronousValue: false)
                updatedFetchControls = FetchControls(fetch: { [weak self] in
                    self?.executeInteraction(true)
                })
            }
           
            let animated:Atomic<Bool> = Atomic(value:false)
            
            if let updatedStatusSignal = updatedStatusSignal {
                self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self {
                        strongSelf.fetchStatus = status
                        if case .Local = status {
                            strongSelf.actionView.userInteractionEnabled = (strongSelf.item as? PeerMediaRowItem)?.interface.presentation.state != .selecting
                        } else {
                            strongSelf.actionView.userInteractionEnabled = false
                        }
                        
                        let initStatusControlIfNeeded = { [weak strongSelf] in
                           if let strongSelf = strongSelf, strongSelf.downloadStatusControl == nil {
                               strongSelf.downloadStatusControl = ImageView(frame:NSMakeRect(0, 0, theme.icons.peerMediaDownloadFileStart.backingSize.width, theme.icons.peerMediaDownloadFileStart.backingSize.height))
                               strongSelf.downloadStatusControl?.animates = true
                               strongSelf.addSubview(strongSelf.downloadStatusControl!)
                               strongSelf.needsLayout = true
                           }
                       }
                        
                        let initDownloadControlIfNeeded = { [weak strongSelf] in
                            if let strongSelf = strongSelf {
                                if strongSelf.downloadStatusControl == nil {
                                    strongSelf.downloadStatusControl = ImageView(frame:NSMakeRect(0, 0, theme.icons.peerMediaDownloadFileStart.backingSize.width, theme.icons.peerMediaDownloadFileStart.backingSize.height))
                                    strongSelf.downloadStatusControl?.animates = true
                                    strongSelf.addSubview(strongSelf.downloadStatusControl!)
                                }
                                if strongSelf.downloadProgressView == nil {
                                    strongSelf.downloadProgressView = LinearProgressControl()
                                    strongSelf.downloadProgressView?.cornerRadius = 2.0
                                    strongSelf.containerView.addSubview(strongSelf.downloadProgressView!)
                                }
                                strongSelf.downloadProgressView?.style = ControlStyle(foregroundColor:theme.colors.accent)
                                strongSelf.needsLayout = true
                            }
                        }
                        
                        let deinitDownloadControls = { [weak strongSelf] in
                            if let strongSelf = strongSelf {
                                if let downloadProgressView = strongSelf.downloadProgressView {
                                    strongSelf.downloadProgressView = nil
                                    downloadProgressView.set(progress: 1.0)
                                    downloadProgressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak downloadProgressView] _ in
                                        downloadProgressView?.removeFromSuperview()
                                    })
                                }
                                strongSelf.downloadStatusControl?.removeFromSuperview()
                                strongSelf.downloadStatusControl = nil
                            }
                            strongSelf?.needsLayout = true
                        }
                        
                        let deinitProgressControl = { [weak strongSelf] in
                            if let strongSelf = strongSelf {
                                strongSelf.downloadProgressView?.removeFromSuperview()
                                strongSelf.downloadProgressView = nil
                            }
                            strongSelf?.needsLayout = true
                        }

                        
                        switch status {
                        case .Local:
                            deinitDownloadControls()
                            strongSelf.actionView.update(item.actionLayoutLocal)
                        case .Remote:
                            deinitProgressControl()
                            initStatusControlIfNeeded()
                            strongSelf.downloadStatusControl?.image = theme.icons.peerMediaDownloadFileStart
                            strongSelf.actionView.update(item.actionLayout)
                            break
                        case let .Fetching(_, progress):
                            
                            initDownloadControlIfNeeded()
                            
                            let animated = animated.swap(true)
                            
                            strongSelf.downloadProgressView?.set(progress: CGFloat(progress), animated: animated)
                            
                            strongSelf.downloadStatusControl?.image = theme.icons.peerMediaDownloadFilePause
                            
                            break
                        }
                        
                    }
                }))
            }

            if let updatedFetchControls = updatedFetchControls {
                let _ = fetchControls.swap(updatedFetchControls)
            }
        }
        self.needsLayout = true
    }
    
}
