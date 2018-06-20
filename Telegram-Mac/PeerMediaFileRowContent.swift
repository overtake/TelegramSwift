//
//  MediaFileRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac




class PeerMediaFileRowItem: PeerMediaRowItem {
    
    private(set) var nameLayout:TextViewLayout!
    private(set) var actionLayout:TextViewLayout!
    private(set) var actionLayoutLocal:TextViewLayout!
    private(set) var iconArguments:TransformImageArguments?
    private(set) var icon:TelegramMediaImage?
    
    private(set) var file:TelegramMediaFile?
    
    private(set) var docIcon:CGImage?
    private(set) var docTitle:NSAttributedString?
    override init(_ initialSize:NSSize, _ interface:ChatInteraction, _ account:Account, _ object: PeerMediaSharedEntry) {
        super.init(initialSize,interface,account,object)
        iconSize = NSMakeSize(40, 40)
        
        if let file = message.media.first as? TelegramMediaFile {
            
            self.file = file
            
            nameLayout = TextViewLayout(NSAttributedString.initialize(string: file.fileName ?? "Unknown", color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1, truncationType: .end)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy 'at' h a"
            
            let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: Double(TimeInterval(message.timestamp) - account.context.timeDifference)))
            
            actionLayout = TextViewLayout(NSAttributedString.initialize(string: "\(dataSizeString(file.size ?? 0)) • \(dateString)",color: theme.colors.grayText, font: NSFont.normal(FontSize.text)), maximumNumberOfLines: 1, truncationType: .end)
            
            let localAction = NSMutableAttributedString()
            let range = localAction.append(string: tr(L10n.contextShowInFinder), color: theme.colors.link, font: .normal(.text))
            localAction.add(link: inAppLink.callback("finder", { _ in
                showInFinder(file, account: account)
            }), for: range)
            actionLayoutLocal = TextViewLayout(localAction, maximumNumberOfLines: 1, truncationType: .end)
            actionLayoutLocal.interactions = globalLinkExecutor
            
            let iconImageRepresentation:TelegramMediaImageRepresentation? = smallestImageRepresentation(file.previewRepresentations)
            
            if let iconImageRepresentation = iconImageRepresentation {
                iconArguments = TransformImageArguments(corners: ImageCorners( radius: iconSize.width / 2), imageSize: iconImageRepresentation.dimensions.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: NSEdgeInsets())
                icon = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], reference: nil)
            } else {
                let fileName: String = file.fileName ?? ""
                
                var fileExtension: String?
                if let range = fileName.range(of: ".", options: [.backwards]) {
                    fileExtension = fileName.substring(from: range.upperBound).lowercased()
                }
                docIcon = extensionImage(fileExtension: fileExtension ?? "file")
                
                
                if let fileExtension = fileExtension {
                    docTitle = NSAttributedString.initialize(string: fileExtension, color: theme.colors.text, font: .medium(.text))
                }
            }
        }
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        let signal = super.menuItems(in: location)
        let account = self.account
        if let file = self.file {
            return signal |> mapToSignal { items -> Signal<[ContextMenuItem], Void> in
                var items = items
                return account.postbox.mediaBox.resourceData(file.resource) |> deliverOnMainQueue |> map {data in
                    if data.complete {
                        items.append(ContextMenuItem(tr(L10n.contextCopyMedia), handler: {
                            saveAs(file, account: account)
                        }))
                        items.append(ContextMenuItem(tr(L10n.contextShowInFinder), handler: {
                            showInFinder(file, account: account)
                        }))
                    }
                    return items
                }
                
            }
        }
        return signal
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        
        nameLayout.measure(width: width - contentInset.left - contentInset.right)
        actionLayout.measure(width: width - contentInset.left - contentInset.right)
        actionLayoutLocal.measure(width: width - contentInset.left - contentInset.right)
        contentSize = NSMakeSize(width, 50)
        
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return PeerMediaFileRowView.self
    }
}

class PeerMediaFileRowView : PeerMediaRowView {
    
    var nameView:TextView = TextView()
    var actionView:TextView = TextView()
    var imageView:TransformImageView = TransformImageView(frame:NSMakeRect(10, 5, 40, 40))
    
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
        
    }
    
    func delete() -> Void {
        if let item = item as? PeerMediaFileRowItem {
            _ = item.account.postbox.transaction({ transaction -> Void in
                transaction.deleteMessages([item.message.id])
            }).start()
        }
    }
    
    func cancelFetching() {
        if let item = item as? PeerMediaFileRowItem, let file = item.file {
            messageMediaFileCancelInteractiveFetch(account: item.account, messageId: item.message.id, file: file)
        }
    }
    
    func open() -> Void {
        if let item = item as? PeerMediaFileRowItem, let file = item.file {
            if file.isGraphicFile {
                showChatGallery(account: item.account, message: item.message, item.table, nil)
            } else {
               QuickLookPreview.current.show(account: item.account, with: file, stableId:item.message.chatStableId, item.table)
            }
        }
    }
    
    func fetch() -> Void {
        if let item = item as? PeerMediaFileRowItem, let file = item.file {
            fetchDisposable.set(messageMediaFileInteractiveFetched(account: item.account, messageId: item.message.id, file: file).start())
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
            
            downloadProgressView?.frame = NSMakeRect(item.contentInset.left,frame.height - 4,frame.width - item.contentInset.left - item.contentInset.right,4)

            if let downloadStatusControl = downloadStatusControl {
                actionView.setFrameOrigin(item.contentInset.left + downloadStatusControl.frame.width + 2.0,actionView.frame.minY)
            } else {
                actionView.setFrameOrigin(item.contentInset.left,actionView.frame.minY)
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
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        statusDisposable.set(nil)
        nameView.backgroundColor = theme.colors.background
        actionView.backgroundColor = theme.colors.background
        if let item = item as? PeerMediaFileRowItem {
            nameView.update(item.nameLayout, origin: NSMakePoint(item.contentInset.left, item.contentInset.top + 2))
            actionView.update(item.actionLayout, origin: NSMakePoint(item.contentInset.left, item.contentSize.height - item.actionLayout.layoutSize.height - item.contentInset.bottom - 2))
            
            let updateIconImageSignal:Signal<(TransformImageArguments) -> DrawingContext?,NoError>
            if let icon = item.icon {
                updateIconImageSignal = chatWebpageSnippetPhoto(account: item.account, photo: icon, scale: backingScaleFactor, small:true)
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
            
            let account = item.account
            if let file = item.file {
                updatedStatusSignal = chatMessageFileStatus(account: account, file: file)
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
                            strongSelf.actionView.userInteractionEnabled = true
                        } else {
                            strongSelf.actionView.userInteractionEnabled = false
                        }
                        let initDownloadControlIfNeeded = { [weak strongSelf] in
                            if let strongSelf = strongSelf, strongSelf.downloadStatusControl == nil {
                                strongSelf.downloadStatusControl = ImageView(frame:NSMakeRect(item.contentInset.left, strongSelf.frame.height - theme.icons.peerMediaDownloadFileStart.backingSize.height - item.contentInset.bottom - 4.0, theme.icons.peerMediaDownloadFileStart.backingSize.width, theme.icons.peerMediaDownloadFileStart.backingSize.height))
                                strongSelf.addSubview(strongSelf.downloadStatusControl!)
                                
                                if strongSelf.downloadProgressView == nil {
                                    strongSelf.downloadProgressView = LinearProgressControl()
                                    strongSelf.addSubview(strongSelf.downloadProgressView!)
                                }
                                strongSelf.downloadProgressView?.style = ControlStyle(foregroundColor:theme.colors.blueUI)
                                strongSelf.needsLayout = true
                            }
                            
                        }
                        
                        let deinitDownloadControls = {[weak strongSelf] in
                            if let strongSelf = strongSelf {
                                strongSelf.downloadProgressView?.removeFromSuperview()
                                strongSelf.downloadProgressView = nil
                                strongSelf.downloadStatusControl?.removeFromSuperview()
                                strongSelf.downloadStatusControl = nil
                            }
                            strongSelf?.needsLayout = true
                        }

                        
                        switch status {
                        case .Local:
                            deinitDownloadControls()
                            strongSelf.actionView.update(item.actionLayoutLocal)
                        case .Remote:
                            initDownloadControlIfNeeded()
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
