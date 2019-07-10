//
//  PreviewSenderController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 02/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

private enum SecretMediaTtl {
    case off
    case seconds(Int32)
}

private enum PreviewSenderType {
    case files
    case photo
    case video
    case gif
    case audio
    case media
}


fileprivate enum PreviewSendingState : Int32 {
    case media = 0
    case file = 1
    case collage = 2
    case archive = 3
}

private final class PreviewContextState : Equatable {
    let inputQueryResult: ChatPresentationInputQueryResult?
    init(inputQueryResult: ChatPresentationInputQueryResult? = nil) {
        self.inputQueryResult = inputQueryResult
    }
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> PreviewContextState {
        return PreviewContextState(inputQueryResult: f(self.inputQueryResult))
    }
}

private func ==(lhs: PreviewContextState, rhs: PreviewContextState) -> Bool {
    return lhs.inputQueryResult == rhs.inputQueryResult
}

private final class PreviewContextInteraction : InterfaceObserver {
    private(set) var state: PreviewContextState = PreviewContextState()
    
    func update(animated:Bool = true, _ f:(PreviewContextState)->PreviewContextState) -> Void {
        let oldValue = self.state
        self.state = f(state)
        if oldValue != state {
            notifyObservers(value: state, oldValue:oldValue, animated: animated)
        }
    }
}


fileprivate class PreviewSenderView : Control {
    fileprivate let tableView:TableView = TableView(frame: NSZeroRect)
    fileprivate let textView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSMakeRect(0, 0, 280, 34))
    fileprivate let sendButton = ImageButton()
    fileprivate let emojiButton = ImageButton()
    fileprivate let actionsContainerView: View = View()
    fileprivate let headerView: View = View()
    fileprivate let draggingView = DraggingView(frame: NSZeroRect)
    fileprivate let closeButton = ImageButton()
    fileprivate let title: TextView = TextView()
    fileprivate let photoButton = ImageButton()
    fileprivate let fileButton = ImageButton()
    fileprivate let collageButton = ImageButton()
    fileprivate let archiveButton = ImageButton()
    fileprivate let textContainerView: View = View()
    fileprivate let separator: View = View()
    fileprivate weak var controller: PreviewSenderController? {
        didSet {
            let count = controller?.urls.count ?? 0
            textView.setPlaceholderAttributedString(.initialize(string: count > 1 ? L10n.previewSenderCommentPlaceholder : L10n.previewSenderCaptionPlaceholder, color: theme.colors.grayText, font: .normal(.text)), update: false)
        }
    }
    private let _stateValue: ValuePromise<PreviewSendingState> = ValuePromise(ignoreRepeated: true)
    
    var state: PreviewSendingState = .file {
        didSet {
            _stateValue.set(state)
        }
    }
    
    var stateValue: Signal<PreviewSendingState, NoError> {
        return _stateValue.get()
    }
    
    
    private let disposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.border
        textContainerView.backgroundColor = theme.colors.background
        
        closeButton.set(image: theme.icons.modalClose, for: .Normal)
        _ = closeButton.sizeToFit()
        
        
        photoButton.appTooltip = L10n.previewSenderMediaTooltip
        fileButton.appTooltip = L10n.previewSenderFileTooltip
        collageButton.appTooltip = L10n.previewSenderCollageTooltip
        archiveButton.appTooltip = L10n.previewSenderArchiveTooltip

        photoButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.chatAttachPhoto), for: .Normal)
        _ = photoButton.sizeToFit()
        
        disposable.set(stateValue.start(next: { [weak self] value in
            guard let `self` = self else { return }
            
            
            self.fileButton.isSelected = value == .file
            self.photoButton.isSelected = value == .media || value == .collage
            self.collageButton.isSelected = value == .collage
            self.archiveButton.isSelected = value == .archive
            
            Queue.mainQueue().justDispatch {
                removeAllTooltips(mainWindow)
                self.fileButton.controlState = .Normal
                self.photoButton.controlState = .Normal
                self.collageButton.controlState = .Normal
                self.archiveButton.controlState = .Normal
            }
            
            
        }))
        
        photoButton.isSelected = true
        
        photoButton.set(handler: { [weak self] _ in
            self?.state = .media
            FastSettings.toggleIsNeedCollage(false)
        }, for: .Click)
        
        
        archiveButton.set(handler: { [weak self] _ in
            self?.state = .archive
          //  getAppTooltip(for: ., callback: <#T##(String) -> Void#>)
        }, for: .Click)
        
        collageButton.set(handler: { [weak self] control in
            if control.isSelected {
                self?.state = .media
                FastSettings.toggleIsNeedCollage(false)
            } else {
                self?.state = .collage
                FastSettings.toggleIsNeedCollage(true)
            }
           
        }, for: .Click)
        
        fileButton.set(handler: { [weak self] _ in
            self?.state = .file
        }, for: .Click)
        
        closeButton.set(handler: { [weak self] _ in
            self?.controller?.close()
        }, for: .Click)
        
        fileButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.chatAttachFile), for: .Normal)
        _ = fileButton.sizeToFit()
        
        collageButton.set(image: theme.icons.previewCollage, for: .Normal)
        _ = collageButton.sizeToFit()
        
        archiveButton.set(image: theme.icons.previewSenderArchive, for: .Normal)
        _ = archiveButton.sizeToFit()

        title.backgroundColor = theme.colors.background
        
        
        headerView.addSubview(closeButton)
        headerView.addSubview(title)
        headerView.addSubview(fileButton)
        headerView.addSubview(photoButton)
        headerView.addSubview(collageButton)
        headerView.addSubview(archiveButton)
        title.isSelectable = false
        title.userInteractionEnabled = false
        
        sendButton.set(image: theme.icons.chatSendMessage, for: .Normal)
        _ = sendButton.sizeToFit()
        
        emojiButton.set(image: theme.icons.chatEntertainment, for: .Normal)
        _ = emojiButton.sizeToFit()
        
        actionsContainerView.addSubview(sendButton)
        actionsContainerView.addSubview(emojiButton)
        
        
        actionsContainerView.setFrameSize(sendButton.frame.width + emojiButton.frame.width + 40, 50)
        
        emojiButton.centerY(x: 0)
        sendButton.centerY(x: emojiButton.frame.maxX + 20)
        
        backgroundColor = theme.colors.background
        textView.background = theme.colors.background
        textView.textFont = .normal(.text)
        textView.textColor = theme.colors.text
        textView.linkColor = theme.colors.link
        textView.max_height = 180
        
        emojiButton.set(handler: { [weak self] control in
            self?.controller?.showEmoji(for: control)
        }, for: .Hover)
        
        sendButton.set(handler: { [weak self] _ in
            self?.controller?.send()
        }, for: .SingleClick)
        
        textView.setFrameSize(NSMakeSize(280, 34))

        addSubview(tableView)

        
        textContainerView.addSubview(textView)
        
        addSubview(headerView)
        addSubview(textContainerView)
        addSubview(actionsContainerView)
        
        addSubview(separator)
        addSubview(draggingView)
        
        layout()
    }
    
    deinit {
        disposable.dispose()
    }
    
    var additionHeight: CGFloat {
        return max(50, textView.frame.height + 16) + headerView.frame.height
    }
    
    func updateTitle(_ medias: [Media], state: PreviewSendingState) -> Void {
        
        
        let count = medias.count
        let type: PreviewSenderType
        
        var isPhotos = false
        var isMedia = false
        
       
        if medias.filter({$0 is TelegramMediaImage}).count == medias.count {
            type = .photo
            isPhotos = true
        } else {
            let files = medias.filter({$0 is TelegramMediaFile}).map({$0 as! TelegramMediaFile})
            
            let imagesCount = medias.filter({$0 is TelegramMediaImage}).count
            let count = files.filter({ file in
                
                if file.isVideo && !file.isAnimated {
                    return true
                } else if file.isAnimated {
                    return false
                }
                if let ext = file.fileName?.nsstring.pathExtension.lowercased() {
                    let mime = MIMEType(ext, isExt: true)
                    if let resource = file.resource as? LocalFileReferenceMediaResource {
                        if mime.hasPrefix("image"), let image = NSImage(contentsOf: URL(fileURLWithPath: resource.localFilePath)) {
                            if image.size.width / 10 > image.size.height || image.size.height < 40 {
                                return false
                            }
                        }
                    }
                    return photoExts.contains(ext) || videoExts.contains(ext)
                }
                return false
            }).count
            
            isMedia = (count == (files.count + imagesCount)) || count == files.count
            
            if files.filter({$0.isMusic}).count == files.count {
                type = imagesCount > 0 ? .media : .audio
            } else if files.filter({$0.isVideo && !$0.isAnimated}).count == files.count {
                type = imagesCount > 0 ? .media : .video
            } else if files.filter({$0.isVideo && $0.isAnimated}).count == files.count {
                type = imagesCount > 0 ? .media : .gif
            } else if files.filter({!$0.isVideo || !$0.isAnimated || $0.isMusic}).count != medias.count {
                type = .media
            } else {
                type = .files
            }
        }
        
        self.collageButton.isHidden = (!isPhotos && !isMedia) || medias.count > 10 || medias.count < 2
        let visibleCount = (photoButton.isHidden ? 0 : 1) + (fileButton.isHidden ? 0 : 1) + (archiveButton.isHidden ? 0 : 1) + (collageButton.isHidden ? 0 : 1)

        title.isHidden = visibleCount > 0
        
        let text:String
        switch type {
        case .files:
            text = L10n.previewSenderSendFileCountable(count)
        case .photo:
            text = L10n.previewSenderSendPhotoCountable(count)
        case .video:
            text = L10n.previewSenderSendVideoCountable(count)
        case .gif:
            text = L10n.previewSenderSendGifCountable(count)
        case .audio:
            text = L10n.previewSenderSendAudioCountable(count)
        case .media:
            text = L10n.previewSenderSendMediaCountable(count)
        }
        
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        title.update(layout)
        needsLayout = true
        separator.isHidden = false//tableView.listHeight <= frame.height - additionHeight
    }
    
    func updateHeight(_ height: CGFloat, _ animated: Bool) {
        CATransaction.begin()
        textContainerView.change(size: NSMakeSize(frame.width, height + 16), animated: animated)
        textContainerView.change(pos: NSMakePoint(0, frame.height - textContainerView.frame.height), animated: animated)
        textView._change(pos: NSMakePoint(10, height == 34 ? 8 : 11), animated: animated)

        actionsContainerView.change(pos: NSMakePoint(frame.width - actionsContainerView.frame.width, frame.height - actionsContainerView.frame.height), animated: animated)

        separator.change(pos: NSMakePoint(0, textContainerView.frame.minY), animated: animated)
        separator.change(opacity: tableView.listHeight > frame.height - additionHeight ? 1.0 : 0.0, animated: animated)
        CATransaction.commit()
        
        needsLayout = true
    }
    
    func applyOptions(_ options:[PreviewOptions], count: Int) {
        fileButton.isHidden = false//!options.contains(.media)
        photoButton.isHidden = !options.contains(.media)
        archiveButton.isHidden = count < 2
    }
    
    override func layout() {
        super.layout()
        actionsContainerView.setFrameOrigin(frame.width - actionsContainerView.frame.width, frame.height - actionsContainerView.frame.height)
        headerView.setFrameSize(frame.width, 50)
        
        tableView.setFrameSize(NSMakeSize(frame.width, frame.height - additionHeight))
        tableView.centerX(y: headerView.frame.maxY - 6)
        
        draggingView.frame = tableView.frame

        
        let visibleCount = (photoButton.isHidden ? 0 : 1) + (fileButton.isHidden ? 0 : 1) + (archiveButton.isHidden ? 0 : 1) + (collageButton.isHidden ? 0 : 1)
        
        title.layout?.measure(width: frame.width - CGFloat(visibleCount) * 40 + 20)
        title.update(title.layout)
        title.center()
        
        closeButton.centerY(x: headerView.frame.width - closeButton.frame.width - 10)
        collageButton.centerY(x: closeButton.frame.minX - 10 - collageButton.frame.width)

        
        photoButton.centerY(x: 10)
        fileButton.centerY(x: photoButton.isHidden ? (10) : (photoButton.frame.maxX + 10))
        
        archiveButton.centerY(x: !fileButton.isHidden ? fileButton.frame.maxX + 10 : (photoButton.isHidden ? 10 : photoButton.frame.maxX + 10))
        
        textContainerView.setFrameSize(frame.width, textView.frame.height + 16)
        textContainerView.setFrameOrigin(0, frame.height - textContainerView.frame.height)
        textView.setFrameSize(NSMakeSize(textContainerView.frame.width - 10 - actionsContainerView.frame.width, textView.frame.height))
        textView.setFrameOrigin(10, textView.frame.height == 34 ? 8 : 11)
        
        separator.frame = NSMakeRect(0, textContainerView.frame.minY, frame.width, .borderSize)

    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class SenderPreviewArguments {
    let context: AccountContext
    let edit:(URL)->Void
    let delete:(URL)->Void
    let reorder:(Int, Int) -> Void
    init(context: AccountContext, edit: @escaping(URL)->Void, delete: @escaping(URL)->Void, reorder: @escaping(Int, Int) -> Void) {
        self.context = context
        self.edit = edit
        self.delete = delete
        self.reorder = reorder
    }
}

private struct PreviewState : Equatable {
    let urls:[URL]
    let medias:[Media]
    let currentState: PreviewSendingState
    let editedData: [URL : EditedImageData]
    init(urls: [URL], medias: [Media], currentState: PreviewSendingState, editedData: [URL : EditedImageData]) {
        self.urls = urls
        self.medias = medias
        self.currentState = currentState
        self.editedData = editedData
    }
    
    func withUpdatedEditedData(_ f:([URL : EditedImageData]) -> [URL : EditedImageData]) -> PreviewState {
        return PreviewState(urls: self.urls, medias: self.medias, currentState: self.currentState, editedData: f(self.editedData))
    }
    func apply(transition: UpdateTransition<Media>, urls:[URL], state: PreviewSendingState) -> PreviewState {
        var medias:[Media] = self.medias
        for rdx in transition.deleted.reversed() {
            medias.remove(at: rdx)
        }
        for (idx, media) in transition.inserted {
            medias.insert(media, at: idx)
        }
        for (idx, item) in transition.updated {
            medias[idx] = item
        }
        
        return PreviewState(urls: urls, medias: medias, currentState: state, editedData: self.editedData)
    }
}
private func == (lhs: PreviewState, rhs: PreviewState) -> Bool {
    if lhs.medias.count != rhs.medias.count {
        return false
    } else {
        for i in 0 ..< lhs.medias.count {
            if !lhs.medias[i].isEqual(to: rhs.medias[i]) {
                return false
            }
        }
    }
    return lhs.urls == rhs.urls && lhs.currentState == rhs.currentState && lhs.editedData == rhs.editedData
}


private enum PreviewEntryId : Hashable {
    static func == (lhs: PreviewEntryId, rhs: PreviewEntryId) -> Bool {
        switch lhs {
        case let .media(lhsMedia):
            if case let .media(rhsMedia) = rhs {
                return lhsMedia.isEqual(to: rhsMedia)
            } else {
                return false
            }
        case .mediaGroup:
            if case .mediaGroup = rhs {
                return true
            } else {
                return false
            }
        case let .section(index):
            if case .section(index) = rhs {
                return true
            } else {
                return false
            }
        case .archive:
            if case .archive = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        
    }
    
    case media(Media)
    case mediaGroup
    case archive
    case section(Int)
}

private enum PreviewEntry : Comparable, Identifiable {
    case section(Int)
    case media(index: Int, sectionId: Int, url: URL, media: Media)
    case mediaGroup(index: Int, sectionId: Int, urls: [URL], messages: [Message])
    case archive(index: Int, sectionId: Int, urls: [URL], media: Media)
    var stableId: PreviewEntryId {
        switch self {
        case let .section(sectionId):
            return .section(sectionId)
        case let .media(_, _, _, media):
            return .media(media)
        case .mediaGroup:
            return .mediaGroup
        case .archive:
            return .archive
        }
    }
    
    var index: Int {
        switch self {
        case let .section(sectionId):
            return (sectionId * 1000) + sectionId
        case let .media(index, sectionId, _, _):
            return (sectionId * 1000) + index
        case let .mediaGroup(index, sectionId, _, _):
            return (sectionId * 1000) + index
        case let .archive(index, sectionId, _, _):
            return (sectionId * 1000) + index
        }
    }
    
    func item(arguments: SenderPreviewArguments, state: PreviewState, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .media(_, _, url, media):
            return MediaPreviewRowItem(initialSize, media: media, context: arguments.context, hasEditedData: state.editedData[url] != nil, edit: {
                arguments.edit(url)
            }, delete: {
                arguments.delete(url)
            })
        case let .archive(_, _, _, media):
            return MediaPreviewRowItem(initialSize, media: media, context: arguments.context, hasEditedData: false, edit: {
              //  arguments.edit(url)
            }, delete: {
              // arguments.delete(url)
            })
        case let .mediaGroup(_, _, urls, messages):
            return MediaGroupPreviewRowItem(initialSize, messages: messages, urls: urls, editedData: state.editedData, edit: { url in
                arguments.edit(url)
            }, delete: { url in
                arguments.delete(url)
            }, context: arguments.context, reorder: { from, to in
                arguments.reorder(from, to)
            })
        }
    }
    
}
private func == (lhs: PreviewEntry, rhs: PreviewEntry) -> Bool {
    switch lhs {
    case let .media(index, sectionId, url, lhsMedia):
        if case .media(index, sectionId, url, let rhsMedia) = rhs {
            return lhsMedia.isEqual(to: rhsMedia)
        } else {
            return false
        }
    case let .archive(index, sectionId, urls, lhsMedia):
        if case .archive(index, sectionId, urls, let rhsMedia) = rhs {
            return lhsMedia.isEqual(to: rhsMedia)
        } else {
            return false
        }
    case let .mediaGroup(index, sectionId, url, lhsMessages):
        if case .mediaGroup(index, sectionId, url, let rhsMessages) = rhs {
            if lhsMessages.count != rhsMessages.count {
                return false
            } else {
                for i in 0 ..< lhsMessages.count {
                    if !isEqualMessages(lhsMessages[i], rhsMessages[i]) {
                        return false
                    }
                }
                return true
            }
        } else {
            return false
        }
    case let .section(section):
        if case .section(section) = rhs {
            return true
        } else {
            return false
        }
    }
}
private func < (lhs: PreviewEntry, rhs: PreviewEntry) -> Bool {
    return lhs.index < rhs.index
}

private func previewMediaEntries( _ state: PreviewState) -> [PreviewEntry] {
    
    var entries: [PreviewEntry] = []
    var index: Int = 0
    
    let sectionId: Int = 0
    
    switch state.currentState {
    case .archive:
        assert(state.medias.count == 1)
        entries.append(.archive(index: index, sectionId: sectionId, urls: state.urls, media: state.medias[0]))
    case .file, .media:
        for (i, media) in state.medias.enumerated() {
            entries.append(.media(index: index, sectionId: sectionId, url: state.urls[i], media: media))
            index += 1
        }
    case .collage:
        var messages: [Message] = []
        for (id, media) in state.medias.enumerated() {
            messages.append(Message(media, stableId: UInt32(id), messageId: MessageId(peerId: PeerId(0), namespace: 0, id: MessageId.Id(id))))
        }
        entries.append(.mediaGroup(index: index, sectionId: sectionId, urls: state.urls, messages: messages))
    }
    
    return entries
}


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PreviewEntry>], right: [AppearanceWrapperEntry<PreviewEntry>], state: PreviewState, arguments: SenderPreviewArguments, animated: Bool, initialSize:NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments: arguments, state: state, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated)
}

private enum PreviewMediaId : Hashable {
    case container(MediaSenderContainer)

    func hash(into hasher: inout Hasher) {
        
    }
    
}

private final class PreviewMedia : Comparable, Identifiable {
    
    static func < (lhs: PreviewMedia, rhs: PreviewMedia) -> Bool {
        return lhs.index < rhs.index
    }
    static func == (lhs: PreviewMedia, rhs: PreviewMedia) -> Bool {
        return lhs.container == rhs.container
    }
    let container: MediaSenderContainer
    let index: Int
    private(set) var media: Media?

    init(container: MediaSenderContainer, index: Int, media: Media?) {
        self.container = container
        self.index = index
        self.media = media
    }
    

    
    var stableId: PreviewMediaId {
        return .container(container)
    }
    
    func withApplyCachedMedia(_ media: Media) -> PreviewMedia {
        return PreviewMedia(container: container, index: index, media: media)
    }
    
    func generateMedia(account: Account) -> Media {
        
        if let media = self.media {
            return media
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var generated: Media!
        
        if let container = container as? ArchiverSenderContainer {
            for url in container.files {
                try? FileManager.default.copyItem(atPath: url.path, toPath: container.path + "/" + url.path.nsstring.lastPathComponent)
            }
        }
        
        _ = Sender.generateMedia(for: container, account: account).start(next: { media, path in
            generated = media
            semaphore.signal()
        })
        semaphore.wait()
        
        self.media = generated
        
        return generated
    }
}


private func previewMedias(containers:[MediaSenderContainer], savedState: [PreviewMedia]?) -> [PreviewMedia] {
    var index: Int = 0
    var result:[PreviewMedia] = []
    for container in containers {
        let found = savedState?.first(where: {$0.stableId == .container(container)})
        result.append(PreviewMedia(container: container, index: index, media: found?.media))
        index += 1
    }
    return result
}


private func prepareMedias(left: [PreviewMedia], right: [PreviewMedia], account: Account) -> UpdateTransition<Media> {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { item in
        return item.generateMedia(account: account)
    })
    return UpdateTransition(deleted: removed, inserted: inserted, updated: updated)
}


class PreviewSenderController: ModalViewController, TGModernGrowingDelegate, Notifable {
   
    
    private var _urls:[URL] = []
    
    fileprivate var urls:[URL] {
        set {
            _urls = newValue.uniqueElements
            self.urlsValue.set(.single(_urls))
            let canCollage: Bool = canCollagesFromUrl(_urls)
            self.genericView.state = genericView.state == .collage ? canCollage ? .collage : .media : genericView.state
        }
        get {
            return _urls
        }
    }
    
    fileprivate let urlsValue:Promise<[URL]> = Promise()
    
    
    private let context:AccountContext
    private let chatInteraction:ChatInteraction
    private let disposable = MetaDisposable()
    private let emoji: EmojiViewController
    private var cachedMedia:[PreviewSendingState: (media: [Media], items: [TableRowItem])] = [:]
    private var sent: Bool = false
    private let pasteDisposable = MetaDisposable()
    

    private var temporaryInputState: ChatTextInputState?
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private let inputContextHelper: InputContextHelper
    private let inputInteraction:PreviewContextInteraction = PreviewContextInteraction()
    private let contextChatInteraction: ChatInteraction
    private let editorDisposable = MetaDisposable()
    private let archiverStatusesDisposable = MetaDisposable()
    private var archiveStatuses: [ArchiveSource : ArchiveStatus] = [:]
    private var genericView:PreviewSenderView {
        return self.view as! PreviewSenderView
    }
    
    override var responderPriority: HandlerPriority {
        return .high
    }
    
    private var sendCurrentMedia:(()->Void)? = nil
    private var runEditor:((URL)->Void)? = nil
    private var insertAdditionUrls:(([URL]) -> Void)? = nil
    
    private let animated: Atomic<Bool> = Atomic(value: false)

    private func updateSize(_ width: CGFloat, animated: Bool) {
        if let contentSize = mainWindow.contentView?.frame.size {
            
            var listHeight = genericView.tableView.listHeight
            if let inputQuery = inputInteraction.state.inputQueryResult {
                switch inputQuery {
                case let .emoji(emoji, _):
                    if !emoji.isEmpty {
                        listHeight = listHeight > 0 ? max(40, listHeight) : 0
                    }
                default:
                    listHeight = listHeight > 0 ? max(150, listHeight) : 0
                }
            }
            
            let height = listHeight + max(genericView.additionHeight, 88)

            
            self.modal?.resize(with: NSMakeSize(width, min(contentSize.height - 70, height)), animated: animated)
            genericView.layout()
        }
    }
  
    override var dynamicSize: Bool {
        return true
    }
    
    override func draggingItems(for pasteboard: NSPasteboard) -> [DragItem] {
        if let types = pasteboard.types, types.contains(.kFilenames) {
            let list = pasteboard.propertyList(forType: .kFilenames) as? [String]
            if let list = list {
                return [DragItem(title: L10n.previewDraggingAddItemsCountable(list.count), desc: "", handler: { [weak self] in
                    self?.insertAdditionUrls?(list.map({URL(fileURLWithPath: $0)}))
                    
                })]
            }
        }
        return []
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let currentEvent = NSApp.currentEvent {

            if FastSettings.checkSendingAbility(for: currentEvent), didSetReady {
                send()
                return .invoked
            }
        }
        
        return .invokeNext
    }
    
    func send() {
        sendCurrentMedia?()
    }
    
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: false)
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.draggingView.controller = self
        genericView.controller = self
        genericView.textView.delegate = self
        inputInteraction.add(observer: self)
        
        if let attributedString = attributedString {
            genericView.textView.setAttributedString(attributedString, animated: false)
        } else {
            self.temporaryInputState = chatInteraction.presentation.interfaceState.inputState
            let text = chatInteraction.presentation.interfaceState.inputState.attributedString
            
            genericView.textView.setAttributedString(text, animated: false)
            chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedInputState(ChatTextInputState())})})
        }
        
        let interactions = EntertainmentInteractions(.emoji, peerId: chatInteraction.peerId)
        
        interactions.sendEmoji = { [weak self] emoji in
            self?.genericView.textView.appendText(emoji)
        }
        
        emoji.update(with: interactions)
        
        let actionsDisposable = DisposableSet()
        self.disposable.set(actionsDisposable)
        
        let context = self.context
        let initialSize = self.atomicSize
        
        let initialState = PreviewState(urls: [], medias: [], currentState: .media, editedData: [:])
        
        let statePromise:ValuePromise<PreviewState> = ValuePromise(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((PreviewState) -> PreviewState) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let removeTransitionAnimation: Atomic<Bool> = Atomic(value: false)
        
        let arguments = SenderPreviewArguments(context: context, edit: { [weak self] url in
            self?.runEditor?(url)
        }, delete: { [weak self] url in
            guard let `self` = self else { return }
            self.urls.removeAll(where: {$0 == url})
        }, reorder: { [weak self] from, to in
            guard let `self` = self else { return }
            _ = removeTransitionAnimation.swap(true)
            self.urls.move(at: from, to: to)
        })
        
        
        let archiveRandomId = arc4random()
       
        
        let previousMedias:Atomic<[PreviewMedia]> = Atomic(value: [])
        let savedStateMedias:Atomic<[PreviewSendingState : [PreviewMedia]]> = Atomic(value: [:])

        let urlsTransition: Signal<(UpdateTransition<Media>, [URL], PreviewSendingState, [PreviewMedia]), NoError> = combineLatest(queue: prepareQueue, self.urlsValue.get(), self.genericView.stateValue) |> map { urls, state -> ([PreviewMedia], [URL], PreviewSendingState) in
            
            var containers = urls.compactMap { url -> MediaSenderContainer? in
                switch state {
                case .media, .collage:
                    return MediaSenderContainer(path: url.path, isFile: false)
                case .file:
                    return MediaSenderContainer(path: url.path, isFile: true)
                case .archive:
                    return nil
                }
            }
            
            if state == .archive {
                let dir = NSTemporaryDirectory() + "tg_temp_archive_\(archiveRandomId)"
                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
                containers.append(ArchiverSenderContainer(path: dir, files: urls))
            }
            
            return (previewMedias(containers: containers, savedState: savedStateMedias.with { $0[state]}), urls, state)
        } |> map { previews, urls, state in
            return (prepareMedias(left: previousMedias.swap(previews), right: previews, account: context.account), urls, state, previews)
        }

        actionsDisposable.add(urlsTransition.start(next: { transition, urls, state, previews in
            updateState {
                $0.apply(transition: transition, urls: urls, state: state)
            }
            _ = savedStateMedias.modify { current in
                var current = current
                current[state] = previews
                return current
            }
        }))
    
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<PreviewEntry>]> = Atomic(value: [])
        
        let itemsTransition: Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, statePromise.get() |> map { state -> ([PreviewEntry], PreviewState) in
            return (previewMediaEntries(state), state)
        }, appearanceSignal) |> map { datas, appearance in
            let entries = datas.0.map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return prepareTransition(left: previousEntries.swap(entries), right: entries, state: datas.1, arguments: arguments, animated: !removeTransitionAnimation.swap(false), initialSize: initialSize.with { $0 })
        } |> deliverOnMainQueue
        
        let first: Atomic<Bool> = Atomic(value: false)
        let scrollAfterTransition: Atomic<Bool> = Atomic(value: false)
        
        actionsDisposable.add(itemsTransition.start(next: { [weak self] transition in
            guard let `self` = self else {return}
            
            let state = stateValue.with { $0.currentState }
            let medias = stateValue.with { $0.medias }

            
            let sources:[ArchiveSource] = medias.filter { media in
                if let media = media as? TelegramMediaFile {
                    return media.resource is LocalFileArchiveMediaResource
                } else {
                    return false
                }
            }.map { ($0 as! TelegramMediaFile).resource as! LocalFileArchiveMediaResource}.map {.resource($0)}
            
            self.archiverStatusesDisposable.set(combineLatest(sources.map {archiver.archive($0)}).start(next: { [weak self] statuses in
                guard let `self` = self else {return}
                self.archiveStatuses.removeAll()
                for i in 0 ..< sources.count {
                    self.archiveStatuses[sources[i]] = statuses[i]
                }
            }))
            
            
            CATransaction.begin()
            self.genericView.tableView.merge(with: transition)

            var placeholder: String = L10n.previewSenderCommentPlaceholder
            
            if self.genericView.tableView.count == 1 {
                if let item = self.genericView.tableView.firstItem {
                    if let item = item as? MediaPreviewRowItem {
                        if item.media.canHaveCaption {
                            placeholder = L10n.previewSenderCaptionPlaceholder
                        }
                    }
                }
            }
            
           self.genericView.textView.setPlaceholderAttributedString(.initialize(string: placeholder, color: theme.colors.grayText, font: .normal(.text)), update: false)

            
            if self.genericView.tableView.isEmpty {
                self.close()
                if self.chatInteraction.presentation.effectiveInput.inputText.isEmpty {
                    let attributedString = self.genericView.textView.attributedString()
                    let input = ChatTextInputState(inputText: attributedString.string, selectionRange: attributedString.string.length ..< attributedString.string.length, attributes: chatTextAttributes(from: attributedString))
                    self.chatInteraction.update({$0.withUpdatedEffectiveInputState(input)})
                }
            } else {
                self.updateSize(320, animated: first.swap(!self.genericView.tableView.isEmpty))
            }
            self.readyOnce()
            CATransaction.commit()
            
            let options = takeSenderOptions(for: self.urls)
            self.genericView.applyOptions(options, count: self.urls.count)

            
            if state == .archive {
                let globalMedias = savedStateMedias.with { $0[.media] ?? $0[.file] ?? $0[.collage] }?.compactMap { $0.media } ?? medias
                self.genericView.updateTitle(globalMedias, state: state)
            } else {
                self.genericView.updateTitle(medias, state: state)
            }
            
            
            if scrollAfterTransition.swap(false) {
                self.genericView.tableView.scroll(to: .down(true))
            }

            if self.genericView.tableView.count > 1 {
                self.genericView.tableView.resortController = TableResortController(resortRange: NSMakeRange(0, self.genericView.tableView.count), startTimeout: 0.0, start: { _ in }, resort: { _ in }, complete: { from, to in
                    arguments.reorder(from, to)
                })
            } else {
                self.genericView.tableView.resortController = nil
            }
            
        }))
        
        
        let canCollage: Bool = canCollagesFromUrl(self.urls)
        let options = takeSenderOptions(for: self.urls)
        self.genericView.state = asMedia ? FastSettings.isNeedCollage && canCollage ? .collage : (options == [.file] ? .file : .media) : .file
        self.urlsValue.set(.single(self.urls))
        
        
        
        self.sendCurrentMedia = { [weak self] in
            guard let `self` = self else { return }
            
            let state = stateValue.with { $0.currentState }
            let medias = stateValue.with { $0.medias }

            for i in 0 ..< medias.count {
                if let media = medias[i] as? TelegramMediaFile, let resource = media.resource as? LocalFileArchiveMediaResource {
                    if let status = self.archiveStatuses[.resource(resource)] {
                        switch status {
                        case .waiting, .fail, .none:
                            self.genericView.tableView.item(at: i).view?.shakeView()
                            return
                        default:
                            break
                        }
                    } else {
                        self.genericView.tableView.item(at: i).view?.shakeView()
                        return
                    }
                }
            }
            
            self.sent = true
            self.emoji.popover?.hide()
            self.modal?.close(true)
            let attributed = self.genericView.textView.attributedString()
            
            var input:ChatTextInputState = ChatTextInputState(inputText: attributed.string, selectionRange: 0 ..< 0, attributes: chatTextAttributes(from: attributed)).subInputState(from: NSMakeRange(0, attributed.length))
            
            if input.attributes.isEmpty {
                input = ChatTextInputState(inputText: input.inputText.trimmed)
            }
            var additionalMessage: ChatTextInputState? = nil
            
            if (medias.count > 1  || (medias.count == 1 && !medias[0].canHaveCaption)) && !input.inputText.isEmpty {
                if state != .collage {
                    additionalMessage = input
                    input = ChatTextInputState()

                }
            }
            self.chatInteraction.sendMedias(medias, input, state == .collage, additionalMessage)
        }
        
        self.runEditor = { [weak self] url in
            guard let `self` = self else { return }
            
            let editedData = stateValue.with { $0.editedData }
            
            let data = editedData[url]
            let editor = EditImageModalController(data?.originalUrl ?? url, defaultData: data)
            showModal(with: editor, for: mainWindow)
            self.editorDisposable.set((editor.result |> deliverOnMainQueue).start(next: { [weak self] new, editedData in
                guard let `self` = self else {return}
                if let index = self.urls.firstIndex(where: { ($0 as NSURL) === (url as NSURL) }) {
                    updateState { $0.withUpdatedEditedData { data in
                        var data = data
                        if let editedData = editedData {
                            data[new] = editedData
                        } else {
                            data.removeValue(forKey: new)
                        }
                        return data
                    }}
                    self.urls[index] = new
                }
            }))
        }
        
        self.insertAdditionUrls = { [weak self] list in
            guard let `self` = self else { return }
            let previous = self.urls
            _ = scrollAfterTransition.swap(true)
            self.urls.append(contentsOf: list)
            if previous == self.urls {
                _ = scrollAfterTransition.swap(false)
                NSSound.beep()
            }
        }

        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            let state = stateValue.with { $0.currentState }
            let medias = stateValue.with { $0.medias }
            
            if state == .media, medias.count == 1, medias.first is TelegramMediaImage {
                self.runEditor?(self.urls[0])
            }
            return .invoked
        }, with: self, for: .E, priority: .high, modifierFlags: [.command])
        
        
        context.window.set(handler: { () -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .LeftArrow, priority: .modal)
        
        context.window.set(handler: { () -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .RightArrow, priority: .modal)
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.inputInteraction.state.inputQueryResult != nil {
                return .rejected
            }
            return .invokeNext
            }, with: self, for: .UpArrow, priority: .modal)
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.inputInteraction.state.inputQueryResult != nil {
                return .rejected
            }
            return .invokeNext
        }, with: self, for: .DownArrow, priority: .modal)
        
        self.context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            if let strongSelf = self, strongSelf.context.window.firstResponder != strongSelf.genericView.textView.inputView {
                _ = strongSelf.context.window.makeFirstResponder(strongSelf.genericView.textView.inputView)
                return .invoked
            }
        return .invoked
        }, with: self, for: .Tab, priority: .modal)
        
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.textView.boldWord()
            return .invoked
            }, with: self, for: .B, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.makeUrl(of: self.genericView.textView.selectedRange())
            return .invoked
        }, with: self, for: .U, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.textView.italicWord()
            return .invoked
        }, with: self, for: .I, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.textView.codeWord()
            return .invoked
        }, with: self, for: .K, priority: .modal, modifierFlags: [.command, .shift])
        
        
        context.window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            if !self.genericView.tableView.isEmpty, let view = self.genericView.tableView.item(at: 0).view as? MediaGroupPreviewRowView {
                if view.draggingIndex != nil {
                    view.mouseUp(with: event)
                    return .invoked
                }
            }
            
            return .rejected
        }, with: self, for: .leftMouseUp, priority: .high)
        
        
        
        context.window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else { return .rejected }
            if !self.genericView.tableView.isEmpty, let view = self.genericView.tableView.item(at: 0).view  {
                view.pressureChange(with: event)
            }
            return .invoked
        }, with: self, for: .pressure, priority: .high)
        
        context.window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            self.genericView.tableView.enumerateViews(with: { view -> Bool in
                view.updateMouse()
                return true
            })
            
            return .invokeNext
        }, with: self, for: .mouseMoved, priority: .high)
        
        genericView.tableView.needUpdateVisibleAfterScroll = true
    }
    
    deinit {
        inputInteraction.remove(observer: self)
        disposable.dispose()
        editorDisposable.dispose()
        archiverStatusesDisposable.dispose()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        closeAllPopovers(for: mainWindow)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !sent, let temp = temporaryInputState {
             chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedInputState(temp)})})
        }
        if !sent {
            for (_, cached) in cachedMedia {
                for media in cached.media {
                    if let media = media as? TelegramMediaFile, let resource = media.resource as? LocalFileArchiveMediaResource {
                        archiver.remove(.resource(resource))
                    }
                }
            }
        }
        window?.removeAllHandlers(for: self)
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    override func firstResponder() -> NSResponder? {
        return genericView.textView
    }
    
    private let asMedia: Bool
    private let attributedString: NSAttributedString?
    init(urls:[URL], chatInteraction:ChatInteraction, asMedia:Bool = true, attributedString: NSAttributedString? = nil) {
        
        let filtred = urls.filter { url in
            return FileManager.default.fileExists(atPath: url.path)
        }
        self.attributedString = attributedString
        let context = chatInteraction.context
        self.asMedia = asMedia
        self._urls = filtred.uniqueElements
        self.context = context
        self.emoji = EmojiViewController(context)
        
       

        self.contextChatInteraction = ChatInteraction(chatLocation: chatInteraction.chatLocation, context: context)
        
        inputContextHelper = InputContextHelper(chatInteraction: contextChatInteraction)
        self.chatInteraction = chatInteraction
        super.init(frame:NSMakeRect(0, 0, 320, mainWindow.frame.height - 80))
        bar = .init(height: 0)
        

        contextChatInteraction.movePeerToInput = { [weak self] peer in
            if let strongSelf = self {
                let string = strongSelf.genericView.textView.string()
                let range = strongSelf.genericView.textView.selectedRange()
                let textInputState = ChatTextInputState(inputText: string, selectionRange: range.min ..< range.max, attributes: chatTextAttributes(from: strongSelf.genericView.textView.attributedString()))
                strongSelf.contextChatInteraction.update({$0.withUpdatedEffectiveInputState(textInputState)})
                if let (range, _, _) = textInputStateContextQueryRangeAndType(textInputState, includeContext: false) {
                    let inputText = textInputState.inputText
                    
                    let name:String = peer.addressName ?? peer.compactDisplayTitle

                    let distance = inputText.distance(from: range.lowerBound, to: range.upperBound)
                    let replacementText = name + " "
                    
                    let atLength = peer.addressName != nil ? 0 : 1
                    
                    let range = strongSelf.contextChatInteraction.appendText(replacementText, selectedRange: textInputState.selectionRange.lowerBound - distance - atLength ..< textInputState.selectionRange.upperBound)
                    
                    if peer.addressName == nil {
                        let state = strongSelf.contextChatInteraction.presentation.effectiveInput
                        var attributes = state.attributes
                        attributes.append(.uid(range.lowerBound ..< range.upperBound - 1, peer.id.id))
                        let updatedState = ChatTextInputState(inputText: state.inputText, selectionRange: state.selectionRange, attributes: attributes)
                        strongSelf.contextChatInteraction.update({$0.withUpdatedEffectiveInputState(updatedState)})
                    }
                    
                    let updatedText = strongSelf.contextChatInteraction.presentation.effectiveInput
                    
                    strongSelf.genericView.textView.setAttributedString(updatedText.attributedString, animated: true)
                    strongSelf.genericView.textView.setSelectedRange(NSMakeRange(updatedText.selectionRange.lowerBound, updatedText.selectionRange.lowerBound + updatedText.selectionRange.upperBound))
                }
            }
        }
        
        contextChatInteraction.add(observer: self)
        
    }
    
    func showEmoji(for control: Control) {
        showPopover(for: control, with: emoji)
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
        updateSize(frame.width, animated: animated)
        
        genericView.updateHeight(height, animated)
        
    }
    
    func textViewEnterPressed(_ event: NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            return true
        }
        return false
    }
    
    
    func textViewTextDidChange(_ string: String) {
        if FastSettings.isPossibleReplaceEmojies {
            let previousString = contextChatInteraction.presentation.effectiveInput.inputText
            
            if previousString != string {
                let difference = string.replacingOccurrences(of: previousString, with: "")
                if difference.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    let replacedEmojies = string.stringEmojiReplacements
                    if string != replacedEmojies {
                        self.genericView.textView.setString(replacedEmojies)
                    }
                }
            }
            
        }
        
        let attributed = genericView.textView.attributedString()
        let range = self.genericView.textView.selectedRange()
        let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.location ..< range.location + range.length, attributes: chatTextAttributes(from: attributed))
        contextChatInteraction.update({$0.withUpdatedEffectiveInputState(state)})
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return false
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? PreviewContextState, let oldValue = oldValue as? PreviewContextState {
            if value.inputQueryResult != oldValue.inputQueryResult {
                updateSize(frame.width, animated: animated)
                inputContextHelper.context(with: value.inputQueryResult, for: self.genericView, relativeView: self.genericView.textContainerView, animated: animated)
            }
        } else if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if value.effectiveInput != oldValue.effectiveInput {
                updateInput(value, prevState: oldValue, animated)
            }
        }
    }
    
    private func updateInput(_ state:ChatPresentationInterfaceState, prevState: ChatPresentationInterfaceState, _ animated:Bool = true) -> Void {
        
        let textView = genericView.textView
        
        if textView.string() != state.effectiveInput.inputText || state.effectiveInput.attributes != prevState.effectiveInput.attributes  {
            textView.setAttributedString(state.effectiveInput.attributedString, animated:animated)
        }
        let range = NSMakeRange(state.effectiveInput.selectionRange.lowerBound, state.effectiveInput.selectionRange.upperBound - state.effectiveInput.selectionRange.lowerBound)
        if textView.selectedRange().location != range.location || textView.selectedRange().length != range.length {
            textView.setSelectedRange(range)
        }
        textViewTextDidChangeSelectedRange(range)
    }
    
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
        let animated: Bool = true
        let string = genericView.textView.string()

        if let peer = chatInteraction.peer, !string.isEmpty, let (possibleQueryRange, possibleTypes, _) = textInputStateContextQueryRangeAndType(ChatTextInputState(inputText: string, selectionRange: range.min ..< range.max, attributes: []), includeContext: false) {
            
            if (possibleTypes.contains(.mention) && (peer.isGroup || peer.isSupergroup)) || possibleTypes.contains(.emoji) || possibleTypes.contains(.emojiFast) {
                let query = String(string[possibleQueryRange])
                if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(peer: peer, possibleTypes.contains(.emoji) ? .emoji(query, firstWord: false) : possibleTypes.contains(.emojiFast) ? .emoji(query, firstWord: true) : .mention(query: query, includeRecent: false), currentQuery: self.contextQueryState?.0, context: context, filter: .filterSelf(includeNameless: true, includeInlineBots: false)) {
                    self.contextQueryState?.1.dispose()
                    var inScope = true
                    var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                    self.contextQueryState = (updatedContextQueryState, (updatedContextQuerySignal |> deliverOnMainQueue).start(next: { [weak self] result in
                        if let strongSelf = self {
                            if Thread.isMainThread && inScope {
                                inScope = false
                                inScopeResult = result
                            } else {
                                strongSelf.inputInteraction.update(animated: animated, {
                                    $0.updatedInputQueryResult { previousResult in
                                        return result(previousResult)
                                    }
                                })
                                
                            }
                        }
                    }))
                    inScope = false
                    if let inScopeResult = inScopeResult {
                        inputInteraction.update(animated: animated, {
                            $0.updatedInputQueryResult { previousResult in
                                return inScopeResult(previousResult)
                            }
                        })
                    }
                }
            } else {
                inputInteraction.update(animated: animated, {
                    $0.updatedInputQueryResult { _ in
                        return nil
                    }
                })
            }
            
            
        } else {
            inputInteraction.update(animated: animated, {
                $0.updatedInputQueryResult { _ in
                    return nil
                }
            })
        }
        
        let attributed = self.genericView.textView.attributedString()
        
        let state = ChatTextInputState(inputText: attributed.string, selectionRange: range.location ..< range.location + range.length, attributes: chatTextAttributes(from: attributed))
        contextChatInteraction.update({$0.withUpdatedEffectiveInputState(state)})

    }
    
    func textViewDidReachedLimit(_ textView: Any) {
        genericView.textView.shake()
    }
    
    func canTransformInputText() -> Bool {
        return true
    }
    
    
    func makeUrl(of range: NSRange) {
        guard range.min != range.max, let window = window else {
            return
        }
        var effectiveRange:NSRange = NSMakeRange(NSNotFound, 0)
        let defaultTag: TGInputTextTag? = genericView.textView.attributedString().attribute(NSAttributedString.Key(rawValue: TGCustomLinkAttributeName), at: range.location, effectiveRange: &effectiveRange) as? TGInputTextTag
        
        let defaultUrl = defaultTag?.attachment as? String
        
        if effectiveRange.location == NSNotFound {
            effectiveRange = range
        }
        
        showModal(with: InputURLFormatterModalController(string: self.genericView.textView.string().nsstring.substring(with: effectiveRange), defaultUrl: defaultUrl, completion: { [weak self] url in
            self?.genericView.textView.addLink(url, range: effectiveRange)
        }), for: window)
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        
        let result = InputPasteboardParser.canProccessPasteboard(pasteboard)
        
        if let data = pasteboard.data(forType: .rtfd) ?? pasteboard.data(forType: .rtf) {
            if let attributed = (try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)) ?? (try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil))  {
                
                let (attributed, attachments) = attributed.applyRtf()
                let current = genericView.textView.attributedString().copy() as! NSAttributedString
                let currentRange = genericView.textView.selectedRange()
                let (attributedString, range) = current.appendAttributedString(attributed.attributedSubstring(from: NSMakeRange(0, min(Int(self.maxCharactersLimit(genericView.textView)), attributed.length))), selectedRange: currentRange)
                let item = SimpleUndoItem(attributedString: current, be: attributedString, wasRange: currentRange, be: range)
                genericView.textView.addSimpleItem(item)

                if !attachments.isEmpty {
                    pasteDisposable.set((prepareTextAttachments(attachments) |> deliverOnMainQueue).start(next: { [weak self] urls in
                        if !urls.isEmpty {
                            self?.insertAdditionUrls?(urls)
                        }
                    }))
                }
                return true
            }
        }
        
        
        if !result {

            self.pasteDisposable.set(InputPasteboardParser.getPasteboardUrls(pasteboard).start(next: { [weak self] urls in
                self?.insertAdditionUrls?(urls)
            }))
            
            
        }
        
        return !result
    }
    
    func copyText(withRTF rtf: NSAttributedString!) -> Bool {
        return globalLinkExecutor.copyAttributedString(rtf)
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        return NSMakeSize(frame.width - 40, textView.frame.height)
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        return 1024
    }
    
    override func viewClass() -> AnyClass {
        return PreviewSenderView.self
    }

    
}
