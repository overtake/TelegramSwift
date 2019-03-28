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
//
//fileprivate class PreviewArchivingContainer : Control {
//    private let progress: RadialProgressView = RadialProgressView()
//    private var state: PreviewSenderViewState = .archiving(0)
//    required init(frame frameRect: NSRect) {
//        super.init(frame: frameRect)
//        backgroundColor = theme.colors.background
//        addSubview(progress)
//    }
//    
//    fileprivate func updateState(_ state: PreviewSenderViewState) {
//        switch state {
//        case let .archiving(progress):
//            progress.state = .Fetching(progress: progress, force: false)
//        case .normal:
//            progress.state = .Success
//        }
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//}


fileprivate class PreviewSenderView : Control {
    fileprivate let tableView:TableView = TableView.init(frame: NSZeroRect)
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
    let state: ValuePromise<PreviewSendingState> = ValuePromise(ignoreRepeated: true)
    private let disposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.border
        textContainerView.backgroundColor = theme.colors.background
        
        closeButton.set(image: theme.icons.modalClose, for: .Normal)
        _ = closeButton.sizeToFit()
        
        
        photoButton.toolTip = L10n.previewSenderMediaTooltip
        fileButton.toolTip = L10n.previewSenderFileTooltip
        collageButton.toolTip = L10n.previewSenderCollageTooltip
        archiveButton.toolTip = L10n.previewSenderArchiveTooltip

        photoButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.chatAttachPhoto), for: .Normal)
        _ = photoButton.sizeToFit()
        
        disposable.set(state.get().start(next: { [weak self] value in
            self?.fileButton.isSelected = value == .file
            self?.photoButton.isSelected = value == .media
            self?.collageButton.isSelected = value == .collage
            self?.archiveButton.isSelected = value == .archive
        }))
        
        photoButton.isSelected = true
        
        photoButton.set(handler: { [weak self] _ in
            self?.state.set(.media)
            FastSettings.toggleIsNeedCollage(false)
        }, for: .Click)
        
        
        archiveButton.set(handler: { [weak self] _ in
            self?.state.set(.archive)
        }, for: .Click)
        
        collageButton.set(handler: { [weak self] _ in
            self?.state.set(.collage)
            FastSettings.toggleIsNeedCollage(true)
        }, for: .Click)
        
        fileButton.set(handler: { [weak self] _ in
            self?.state.set(.file)
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

class PreviewSenderController: ModalViewController, TGModernGrowingDelegate, Notifable {
   
    

    fileprivate var urls:[URL]
    private let context:AccountContext
    private let chatInteraction:ChatInteraction
    private var sendingState:PreviewSendingState = .file
    private let disposable = MetaDisposable()
    private let emoji: EmojiViewController
    private var cachedMedia:[PreviewSendingState: (media: [Media], items: [TableRowItem])] = [:]
    private var sent: Bool = false
    private let isFileDisposable = MetaDisposable()
    private let pasteDisposable = MetaDisposable()
    override func viewClass() -> AnyClass {
        return PreviewSenderView.self
    }
    
    private var temporaryInputState: ChatTextInputState?
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private let inputContextHelper: InputContextHelper
    private let inputInteraction:PreviewContextInteraction = PreviewContextInteraction()
    private let contextChatInteraction: ChatInteraction
    private let editorDisposable = MetaDisposable()
    private let archiverStatusesDisposable = MetaDisposable()
    private var editedData: [URL : EditedImageData] = [:]
    private var archiveStatuses: [ArchiveSource : ArchiveStatus] = [:]
    private var genericView:PreviewSenderView {
        return self.view as! PreviewSenderView
    }
    
    override var responderPriority: HandlerPriority {
        return .high
    }
    
    private let animated: Atomic<Bool> = Atomic(value: false)

    
    func makeItems(_ urls:[URL])  {
        
        if urls.isEmpty {
            return
        }
        
        
        let initialSize = NSMakeSize(320, 320)
        let context = self.context
        
        let options = takeSenderOptions(for: urls)
        genericView.applyOptions(options, count: urls.count)
        let animated = self.animated
        
        let edit:(URL) -> Void = { [weak self] url in
            self?.runEditor(for: url)
        }
        let delete:(URL) -> Void = { [weak self] url in
            self?.deleteUrl(url)
        }
        
        let editedData = self.editedData
        
        let reorder: (Int, Int) -> Void = { [weak self] from, to in
            guard let `self` = self else {return}
            let medias:[PreviewSendingState] = [.media, .file, .collage]
            self.urls.move(at: from, to: to)
            for type in medias {
                self.cachedMedia[type]?.media.move(at: from, to: to)
            }
            self.updateSize(self.frame.width, animated: true)
        }
        
        let signal = genericView.state.get() |> mapToSignal { [weak self] state -> Signal<([Media], [TableRowItem], PreviewSendingState), NoError> in
            if let cached = self?.cachedMedia[state], cached.media.count == urls.count {
                return .single((cached.media, cached.items, state))
            } else if state == .collage {
                return combineLatest(urls.map({ value in
                    return Sender.generateMedia(for: MediaSenderContainer(path: value.path, caption: "", isFile: false), account: context.account) |> map { ($0.0, value)}
                }))
                |> map { datas in
                    var id:Int32 = 0
                    let groups = datas.map({ media, _ -> Message in
                        id += 1
                        return Message(media, stableId: UInt32(id), messageId: MessageId(peerId: PeerId(0), namespace: 0, id: id))
                    }).chunks(10)
                    
                    return (datas.map {$0.0}, groups.map({MediaGroupPreviewRowItem(initialSize, messages: $0, urls: datas.map {$0.1}, editedData: editedData, edit: { url in
                        edit(url)
                    }, delete: { url in
                        delete(url)
                    }, context: context, reorder: reorder)}), state)
                }
            } else if state == .archive {
                let dir = NSTemporaryDirectory() + "tg_temp_archive_\(arc4random())"
                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
                for url in urls {
                    try? FileManager.default.copyItem(atPath: url.path, toPath: dir + "/" + url.path.nsstring.lastPathComponent)
                }
                return Sender.generateMedia(for: MediaSenderContainer(path: dir, caption: "", isFile: true), account: context.account) |> map {
                    return [($0.0, URL(fileURLWithPath: dir))]
                } |> map { ($0.map({$0.0}), $0.map{ value -> MediaPreviewRowItem in
                        return MediaPreviewRowItem(initialSize, media: value.0, context: context, hasEditedData: false)
                }, state) }
            } else {
                return combineLatest(urls.map({ value in
                    return Sender.generateMedia(for: MediaSenderContainer(path: value.path, caption: "", isFile: state == .file), account: context.account) |> map { ($0.0, value)}
                }))
                    |> map { ($0.map({$0.0}), $0.map{ value -> MediaPreviewRowItem in
                        return MediaPreviewRowItem(initialSize, media: value.0, context: context, hasEditedData: editedData[value.1] != nil, edit: {
                            edit(value.1)
                        }, delete: {
                            delete(value.1)
                        })
                    }, state) }
            }
        } |> deliverOnMainQueue
        
        
        disposable.set(signal.start(next: { [weak self] medias, items, state in
            guard let `self` = self else {return}
            self.sendingState = state
            
            let animated = animated.swap(true)
            
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

            
            self.cachedMedia[state] = (media: medias, items: items)
            
            if state == .archive {
                self.genericView.updateTitle(self.cachedMedia[.media]?.media ?? self.cachedMedia[.file]?.media ?? self.cachedMedia[.collage]?.media ?? medias, state: state)
                
            } else {
                self.genericView.updateTitle(medias, state: state)
            }
            self.genericView.tableView.beginTableUpdates()
            self.genericView.tableView.removeAll(animation: .effectFade)
            self.genericView.tableView.insert(items: items, animation: .effectFade)
            self.genericView.tableView.endTableUpdates()
            
            if items.count > 1 {
                self.genericView.tableView.resortController = TableResortController(resortRange: NSMakeRange(0, items.count), startTimeout: 0.0, start: { index in
                    
                }, resort: { index in
                    
                }, complete: { [weak self] previous, current in
                    guard let `self` = self else {return}
                    
                    self.urls.move(at: previous, to: current)
                    self.genericView.tableView.moveItem(from: previous, to: current)
                    
                    let medias:[PreviewSendingState] = [.media, .file]
                    for type in medias {
                        self.cachedMedia[type]?.media.move(at: previous, to: current)
                        self.cachedMedia[type]?.items.move(at: previous, to: current)
                    }
                    self.makeItems(self.urls)
                })
            } else {
                self.genericView.tableView.resortController = nil
            }
            
            
            let maxWidth: CGFloat = 320
            self.updateSize(maxWidth, animated: animated)
            
            
            self.readyOnce()
        }))
    }
    
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
                    self?.insertAdditionUrls(list.map({URL(fileURLWithPath: $0)}))
                    
                })]
            }
        }
        return []
    }
    
    private func insertAdditionUrls(_ list: [URL]) {
        self.urls.append(contentsOf: list)
        
        let canCollage: Bool = canCollagesFromUrl(self.urls)
        self.disposable.set(nil)
        self.genericView.state.set(self.sendingState == .collage ? canCollage ? .collage : .media : self.sendingState)
        self.makeItems(self.urls)
    }
    override func returnKeyAction() -> KeyHandlerResult {
        if let currentEvent = NSApp.currentEvent {
//            if inputInteraction.state.inputQueryResult != nil {
//                return .rejected
//            }
            if FastSettings.checkSendingAbility(for: currentEvent), didSetReady {
                send()
                return .invoked
            }
        }
        
        return .invokeNext
    }
    
    func send() {
        if let cached = cachedMedia[sendingState] {
            let media = cached.media
            
            for i in 0 ..< media.count {
                if let media = media[i] as? TelegramMediaFile, let resource = media.resource as? LocalFileArchiveMediaResource {
                    if let status = archiveStatuses[.resource(resource)] {
                        switch status {
                        case .waiting, .fail, .none:
                            genericView.tableView.item(at: i).view?.shakeView()
                     //       NSSound.beep()
                            return
                        default:
                            break
                        }
                    } else {
                        genericView.tableView.item(at: i).view?.shakeView()
                      //  NSSound.beep()
                        return
                    }
                }
            }
            
            self.sent = true
            emoji.popover?.hide()
            self.modal?.close(true)
            let attributed = self.genericView.textView.attributedString()
            
            var input:ChatTextInputState = ChatTextInputState(inputText: attributed.string, selectionRange: 0 ..< 0, attributes: chatTextAttributes(from: attributed)).subInputState(from: NSMakeRange(0, attributed.length))
            
            if input.attributes.isEmpty {
                input = ChatTextInputState(inputText: input.inputText.trimmed)
            }
            
            if media.count > 1 && !input.inputText.isEmpty {
                chatInteraction.forceSendMessage(input)
                input = ChatTextInputState()
            }
            chatInteraction.sendMedias(media, input, sendingState == .collage)
        }
    }
    
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: false)
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    private func deleteUrl(_ url: URL) {
        if let index = self.urls.firstIndex(where: { ($0 as NSURL) === (url as NSURL) }) {
            self.urls.remove(at: index)
            if urls.isEmpty {
                self.close()
            } else {
                if let file = self.cachedMedia[sendingState]?.media[index] as? TelegramMediaFile, let resource = file.resource as? LocalFileArchiveMediaResource {
                    archiver.remove(.resource(resource))
                }
                self.cachedMedia.removeAll()
                self.disposable.set(nil)
                self.genericView.state.set(self.sendingState == .collage ? canCollagesFromUrl(urls) ? .collage : .media : self.sendingState)
                self.makeItems(self.urls)
            }
        }
    }
    
    private func runEditor(for url: URL) {
        let data = editedData[url]
        let editor = EditImageModalController(data?.originalUrl ?? url, defaultData: data)
        showModal(with: editor, for: mainWindow)
        editorDisposable.set((editor.result |> deliverOnMainQueue).start(next: { [weak self] (new, editedData) in
            guard let `self` = self else {return}
            if let index = self.urls.firstIndex(where: { ($0 as NSURL) === (url as NSURL) }) {
                self.urls[index] = new
                if let editedData = editedData {
                    self.editedData[new] = editedData
                } else {
                    self.editedData.removeValue(forKey: new)
                }
                self.cachedMedia.removeAll()
                self.makeItems(self.urls)
            }
        }))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            if self.sendingState == .media && self.urls.count == 1, self.cachedMedia[self.sendingState]?.media.first is TelegramMediaImage {
                self.runEditor(for: self.urls[0])
            }
            return .invoked
        }, with: self, for: .E, priority: .high, modifierFlags: [.command])
        
        
        
        window?.set(handler: { () -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .LeftArrow, priority: .modal)
        
        window?.set(handler: { () -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .RightArrow, priority: .modal)
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.inputInteraction.state.inputQueryResult != nil {
                return .rejected
            }
            return .invokeNext
        }, with: self, for: .UpArrow, priority: .modal)
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if self?.inputInteraction.state.inputQueryResult != nil {
                return .rejected
            }
            return .invokeNext
        }, with: self, for: .DownArrow, priority: .modal)
        
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.textView.boldWord()
            return .invoked
        }, with: self, for: .B, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.makeUrl(of: self.genericView.textView.selectedRange())
            return .invoked
        }, with: self, for: .U, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.textView.italicWord()
            return .invoked
        }, with: self, for: .I, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.textView.codeWord()
            return .invoked
        }, with: self, for: .K, priority: .modal, modifierFlags: [.command, .shift])
        
        
        window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}

            if !self.genericView.tableView.isEmpty, let view = self.genericView.tableView.item(at: 0).view as? MediaGroupPreviewRowView {
                if view.draggingIndex != nil {
                    view.mouseUp(with: event)
                    return .invoked
                }
            }
            
            return .rejected
        }, with: self, for: .leftMouseUp, priority: .high)
        
        
        var lastPressureEventStage: Int = 0
        
        window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else { return .rejected }
            if !self.genericView.tableView.isEmpty, let view = self.genericView.tableView.item(at: 0).view  {
                view.pressureChange(with: event)
            }
            return .invoked
        }, with: self, for: .pressure, priority: .high)
        
        window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            self.genericView.tableView.enumerateViews(with: { view -> Bool in
                view.updateMouse()
                return true
            })
            
            
            return .invokeNext
        }, with: self, for: .mouseMoved, priority: .high)
        
        genericView.tableView.needUpdateVisibleAfterScroll = true
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.draggingView.controller = self
        genericView.controller = self
        genericView.textView.delegate = self
        genericView.state.set(sendingState)
        inputInteraction.add(observer: self)
        
        self.temporaryInputState = chatInteraction.presentation.interfaceState.inputState
        let text = chatInteraction.presentation.interfaceState.inputState.attributedString
        
        genericView.textView.setAttributedString(text, animated: false)
        chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedInputState(ChatTextInputState())})})
        
        let interactions = EntertainmentInteractions(.emoji, peerId: chatInteraction.peerId)
        
        interactions.sendEmoji = { [weak self] emoji in
            self?.genericView.textView.appendText(emoji)
        }
        
        emoji.update(with: interactions)
        
        makeItems(self.urls)
    }
    
    deinit {
        inputInteraction.remove(observer: self)
        disposable.dispose()
        isFileDisposable.dispose()
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
    
    init(urls:[URL], chatInteraction:ChatInteraction, asMedia:Bool = true) {
        
        let filtred = urls.filter { url in
            return FileManager.default.fileExists(atPath: url.path)
        }

        let context = chatInteraction.context
        
        self.urls = filtred
        self.context = context
        self.emoji = EmojiViewController(context)
        
        let canCollage: Bool = canCollagesFromUrl(urls)
        let options = takeSenderOptions(for: urls)

        self.contextChatInteraction = ChatInteraction(chatLocation: chatInteraction.chatLocation, context: context)
        
        inputContextHelper = InputContextHelper(chatInteraction: contextChatInteraction)
        self.sendingState = asMedia ? FastSettings.isNeedCollage && canCollage ? .collage : (options == [.file] ? .file : .media) : .file
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
    }
    
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
        let animated: Bool = true
        let string = genericView.textView.string()

        if let peer = chatInteraction.peer, !string.isEmpty, let (possibleQueryRange, possibleTypes, _) = textInputStateContextQueryRangeAndType(ChatTextInputState(inputText: string, selectionRange: range.min ..< range.max, attributes: []), includeContext: false) {
            
            if (possibleTypes.contains(.mention) && (peer.isGroup || peer.isSupergroup)) || possibleTypes.contains(.emoji) {
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
        
        showModal(with: InputURLFormatterModalController(string: self.genericView.textView.string().nsstring.substring(with: range), completion: { [weak self] url in
            self?.genericView.textView.addLink(url)
        }), for: window)
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        
        let result = InputPasteboardParser.canProccessPasteboard(pasteboard)
        
        if !result {
            self.pasteDisposable.set(InputPasteboardParser.getPasteboardUrls(pasteboard).start(next: { [weak self] urls in
                self?.insertAdditionUrls(urls)
            }))
        }
        
        return !result
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
    
}
