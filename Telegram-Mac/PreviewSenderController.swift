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
    fileprivate let tableView:TableView = TableView()
    fileprivate let textView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
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
    
    fileprivate let textContainerView: View = View()
    fileprivate let separator: View = View()
    fileprivate weak var controller: PreviewSenderController? {
        didSet {
            let count = controller?.urls.count ?? 0
            textView.setPlaceholderAttributedString(.initialize(string: count > 1 ? tr(L10n.previewSenderCommentPlaceholder) : tr(L10n.previewSenderCaptionPlaceholder), color: theme.colors.grayText, font: .normal(.text)), update: false)
        }
    }
    let sendAsFile: ValuePromise<PreviewSendingState> = ValuePromise(ignoreRepeated: true)
    private let disposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.border
        textContainerView.backgroundColor = theme.colors.background
        
        closeButton.set(image: theme.icons.modalClose, for: .Normal)
        _ = closeButton.sizeToFit()
        
        
        photoButton.toolTip = tr(L10n.previewSenderMediaTooltip)
        fileButton.toolTip = tr(L10n.previewSenderFileTooltip)
        collageButton.toolTip = tr(L10n.previewSenderCollageTooltip)
        
        photoButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.chatAttachPhoto), for: .Normal)
        _ = photoButton.sizeToFit()
        
        disposable.set(sendAsFile.get().start(next: { [weak self] value in
            self?.fileButton.isSelected = value == .file
            self?.photoButton.isSelected = value == .media
            self?.collageButton.isSelected = value == .collage
        }))
        
        photoButton.isSelected = true
        
        photoButton.set(handler: { [weak self] _ in
            self?.sendAsFile.set(.media)
            FastSettings.toggleIsNeedCollage(false)
        }, for: .Click)
        
        collageButton.set(handler: { [weak self] _ in
            self?.sendAsFile.set(.collage)
            FastSettings.toggleIsNeedCollage(true)
        }, for: .Click)
        
        fileButton.set(handler: { [weak self] _ in
            self?.sendAsFile.set(.file)
        }, for: .Click)
        
        closeButton.set(handler: { [weak self] _ in
            self?.controller?.close()
        }, for: .Click)
        
        fileButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.chatAttachFile), for: .Normal)
        _ = fileButton.sizeToFit()
        
        collageButton.set(image: theme.icons.previewCollage, for: .Normal)
        _ = collageButton.sizeToFit()
        
        title.backgroundColor = theme.colors.background
        
        headerView.addSubview(closeButton)
        headerView.addSubview(title)
        headerView.addSubview(fileButton)
        headerView.addSubview(photoButton)
        headerView.addSubview(collageButton)
        
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
        textView.max_height = 120
        
        emojiButton.set(handler: { [weak self] control in
            self?.controller?.showEmoji(for: control)
        }, for: .Hover)
        
        sendButton.set(handler: { [weak self] _ in
            self?.controller?.send()
        }, for: .SingleClick)
        
        textView.setFrameSize(NSMakeSize(0, 34))

        addSubview(tableView)

        
        textContainerView.addSubview(textView)
        
        addSubview(headerView)
        addSubview(textContainerView)
        addSubview(actionsContainerView)
        
        addSubview(separator)
        addSubview(draggingView)
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
                    let mime = MIMEType(ext)
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
        
        let text:String
        switch type {
        case .files:
            text = tr(L10n.previewSenderSendFileCountable(count))
        case .photo:
            text = tr(L10n.previewSenderSendPhotoCountable(count))
        case .video:
            text = tr(L10n.previewSenderSendVideoCountable(count))
        case .gif:
            text = tr(L10n.previewSenderSendGifCountable(count))
        case .audio:
            text = tr(L10n.previewSenderSendAudioCountable(count))
        case .media:
            text = tr(L10n.previewSenderSendMediaCountable(count))
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
    
    func applyOptions(_ options:[PreviewOptions]) {
        fileButton.isHidden = !options.contains(.media)
        photoButton.isHidden = !options.contains(.media)
    }
    
    override func layout() {
        super.layout()
        actionsContainerView.setFrameOrigin(frame.width - actionsContainerView.frame.width, frame.height - actionsContainerView.frame.height)
        headerView.setFrameSize(frame.width, 50)
        
        tableView.setFrameSize(NSMakeSize(frame.width, frame.height - additionHeight))
        tableView.centerX(y: headerView.frame.maxY - 6)
        
        draggingView.frame = tableView.frame

        
        title.layout?.measure(width: frame.width - (collageButton.isHidden ? 100 : 160))
        title.update(title.layout)
        title.centerX()
        title.centerY()
        
        closeButton.centerY(x: headerView.frame.width - closeButton.frame.width - 10)
        collageButton.centerY(x: closeButton.frame.minX - 10 - collageButton.frame.width)

        
        photoButton.centerY(x: 10)
        fileButton.centerY(x: photoButton.frame.maxX + 10)
        
        
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
    private let account:Account
    private let chatInteraction:ChatInteraction
    private var sendingState:PreviewSendingState = .file
    private let disposable = MetaDisposable()
    private let emoji: EmojiViewController
    private var cachedMedia:[PreviewSendingState: (media: [Media], items: [TableRowItem])] = [:]
    
    private let isFileDisposable = MetaDisposable()
    private let pasteDisposable = MetaDisposable()
    override func viewClass() -> AnyClass {
        return PreviewSenderView.self
    }
    
    private var formatterPopover: InputFormatterPopover?

    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private let inputContextHelper: InputContextHelper
    private let inputInteraction:PreviewContextInteraction = PreviewContextInteraction()
    private let contextChatInteraction: ChatInteraction
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
        let account = self.account
        
        let options = takeSenderOptions(for: urls)
        genericView.applyOptions(options)
        let animated = self.animated
        
        let reorder: (Int, Int) -> Void = { [weak self] from, to in
            guard let `self` = self else {return}
            let medias:[PreviewSendingState] = [.media, .file, .collage]
            for type in medias {
                self.cachedMedia[type]?.media.move(at: from, to: to)
                if type != .collage {
                    self.cachedMedia[type]?.items.move(at: from, to: to)
                }
            }
            self.updateSize(self.frame.width, animated: true)
        }
        
        let signal = genericView.sendAsFile.get() |> mapToSignal { [weak self] state -> Signal<([Media], [TableRowItem], PreviewSendingState), Void> in
            if let cached = self?.cachedMedia[state], cached.media.count == urls.count {
                return .single((cached.media, cached.items, state))
            } else if state == .collage {
                
                return combineLatest(urls.map({Sender.generateMedia(for: MediaSenderContainer(path: $0.path, caption: "", isFile: state == .file), account: account)}))
                    |> map { $0.map({$0.0})}
                    |> map { media in
                        var id:Int32 = 0
                        let groups = media.map({ media -> Message in
                            id += 1
                            return Message(media, stableId: UInt32(id), messageId: MessageId(peerId: PeerId(0), namespace: 0, id: id))
                        }).chunks(10)
                        
                        return (media, groups.map({MediaGroupPreviewRowItem(initialSize, messages: $0, account: account, reorder: reorder)}), state)
                    }
            } else {
                return combineLatest(urls.map({Sender.generateMedia(for: MediaSenderContainer(path: $0.path, caption: "", isFile: state == .file), account: account)}))
                    |> map { $0.map({$0.0})}
                    |> map { ($0, $0.map{MediaPreviewRowItem(initialSize, media: $0, account: account)}, state) }
            }
        } |> deliverOnMainQueue
        
        
        disposable.set(signal.start(next: { [weak self] medias, items, state in
            if let strongSelf = self {
                strongSelf.sendingState = state
                
                let animated = animated.swap(true)
                
                strongSelf.cachedMedia[state] = (media: medias, items: items)
                strongSelf.genericView.updateTitle(medias, state: state)
                strongSelf.genericView.tableView.removeAll(animation: .effectFade)
                strongSelf.genericView.tableView.insert(items: items, animation: .effectFade)
                strongSelf.genericView.layout()
                
                let maxWidth: CGFloat = 320
                strongSelf.updateSize(maxWidth, animated: animated)

                
                strongSelf.readyOnce()
            }
        }))
    }
    
    private func updateSize(_ width: CGFloat, animated: Bool) {
        if let contentSize = mainWindow.contentView?.frame.size {
            self.modal?.resize(with: NSMakeSize(width, min(contentSize.height - 70, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: animated)
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
        self.genericView.sendAsFile.set(self.sendingState == .collage ? canCollage ? .collage : .media : self.sendingState)
        self.makeItems(self.urls)
    }
    override func returnKeyAction() -> KeyHandlerResult {
        if let currentEvent = NSApp.currentEvent {
            if inputInteraction.state.inputQueryResult != nil {
                return .rejected
            }
            if FastSettings.checkSendingAbility(for: currentEvent) {
                send()
                return .invoked
            }
        }
        
        return .invokeNext
    }
    
    func send() {
        emoji.popover?.hide()
        self.modal?.close(true)
        
        let attributed = self.genericView.textView.attributedString()

        var input:ChatTextInputState = ChatTextInputState(inputText: attributed.string, selectionRange: 0 ..< 0, attributes: chatTextAttributes(from: attributed)).subInputState(from: NSMakeRange(0, attributed.length))
        
        if input.attributes.isEmpty {
            input = ChatTextInputState(inputText: input.inputText.trimmed)
        }
        
        if let cached = cachedMedia[sendingState] {
            if cached.media.count > 1 && !input.inputText.isEmpty {
                chatInteraction.forceSendMessage(input)
                input = ChatTextInputState()
            }
            chatInteraction.sendMedias(cached.media, input, sendingState == .collage)
        }
    }
    
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: false)
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.draggingView.controller = self
        genericView.controller = self
        genericView.textView.delegate = self
        genericView.sendAsFile.set(sendingState)
        inputInteraction.add(observer: self)
        
       
        
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    override func firstResponder() -> NSResponder? {
        return genericView.textView
    }
    
    init(urls:[URL], account:Account, chatInteraction:ChatInteraction, asMedia:Bool = true) {
        self.urls = urls
        self.account = account
        self.emoji = EmojiViewController(account)
        
        let canCollage: Bool = canCollagesFromUrl(urls)
        
        self.contextChatInteraction = ChatInteraction(chatLocation: chatInteraction.chatLocation, account: account)
        
        inputContextHelper = InputContextHelper(account: account, chatInteraction: contextChatInteraction)
        self.sendingState = asMedia ? FastSettings.isNeedCollage && canCollage ? .collage : .media : .file
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
        
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return false
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? PreviewContextState, let oldValue = oldValue as? PreviewContextState {
            if value.inputQueryResult != oldValue.inputQueryResult {
                inputContextHelper.context(with: value.inputQueryResult, for: self.genericView, relativeView: self.genericView.textContainerView, animated: animated)
            }
        }
    }
    
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
        let animated: Bool = true
        let string = genericView.textView.string()

        if let peer = chatInteraction.peer, peer.isGroup || peer.isSupergroup, !string.isEmpty, let (possibleQueryRange, possibleTypes, _) = textInputStateContextQueryRangeAndType(ChatTextInputState(inputText: string, selectionRange: range.min ..< range.max, attributes: []), includeContext: false) {
            
            if possibleTypes.contains(.mention) {
                let query = String(string[possibleQueryRange])
                if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(peer: peer, .mention(query: query, includeRecent: false), currentQuery: self.contextQueryState?.0, account: account, filter: .filterSelf(includeNameless: true, includeInlineBots: false)) {
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
    }
    
    func textViewDidReachedLimit(_ textView: Any) {
        genericView.textView.shake()
    }
    
    func canTransformInputText() -> Bool {
        return true
    }
    
    
    func makeUrl(of range: NSRange) {
        guard range.min != range.max else {
            return
        }
        
        let close:()->Void = { [weak self] in
            if let strongSelf = self {
                strongSelf.formatterPopover?.close()
                strongSelf.genericView.textView.setSelectedRange(NSMakeRange(strongSelf.genericView.textView.selectedRange().max, 0))
                strongSelf.formatterPopover = nil
            }
        }
        
        if formatterPopover == nil {
            self.formatterPopover = InputFormatterPopover(InputFormatterArguments(bold: {
                close()
            }, italic: {
                close()
            }, code: {
                close()
            }, link: { [weak self] url in
                self?.genericView.textView.addLink(url)
                close()
            }), window: mainWindow)
        }
        
        formatterPopover?.show(relativeTo: genericView.textView.inputView.selectedRangeRect, of: genericView.textView, preferredEdge: .maxY)
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
        return 200
    }
    
}
