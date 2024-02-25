//
//  PreviewSenderController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 02/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import TGModernGrowingTextView
import SwiftSignalKit
import Postbox
import InputView
import ColorPalette

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

fileprivate struct PreviewSendingState : Hashable {
    enum State : Int32 {
        case media = 0
        case file = 1
        case archive = 3
    }
    let state:State
    let isCollage: Bool
    let isSpoiler: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(state)
        hasher.combine(isCollage)
        hasher.combine(isSpoiler)
    }
    
    func withUpdatedState(_ state: State) -> PreviewSendingState {
        return .init(state: state, isCollage: self.isCollage, isSpoiler: self.isSpoiler)
    }
    func withUpdatedIsCollage(_ isCollage: Bool) -> PreviewSendingState {
        return .init(state: self.state, isCollage: isCollage, isSpoiler: self.isSpoiler)
    }
    func withUpdatedIsSpoiler(_ isSpoiler: Bool) -> PreviewSendingState {
        return .init(state: self.state, isCollage: self.isCollage, isSpoiler: isSpoiler)
    }
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
    fileprivate let textView:UITextView
    fileprivate let sendButton = ImageButton()
    fileprivate let emojiButton = ImageButton()
    fileprivate let actionsContainerView: View = View()
    fileprivate let headerView: View = View()
    fileprivate let draggingView = DraggingView(frame: NSZeroRect)
    fileprivate let closeButton = ImageButton()
    fileprivate let photoButton = ImageButton()
    fileprivate let fileButton = ImageButton()
    fileprivate let collageButton = ImageButton()
    fileprivate let archiveButton = ImageButton()
    fileprivate let spoilerButton = ImageButton()
    fileprivate let textContainerView: View = View()
    fileprivate let separator: View = View()
    fileprivate let forHelperView: View = View()
    fileprivate weak var controller: PreviewSenderController?
    fileprivate var stateValueInteractiveUpdate: ((PreviewSendingState)->Void)?
    
    private var _state: PreviewSendingState = PreviewSendingState(state: .file, isCollage: true, isSpoiler: false)
    var state: PreviewSendingState {
        set {
            let previous = _state
            _state = newValue
            self.fileButton.isSelected = newValue.state == .file
            self.photoButton.isSelected = newValue.state == .media
            self.collageButton.isSelected = newValue.isCollage
            self.archiveButton.isSelected = newValue.state == .archive
            self.spoilerButton.isSelected = newValue.isSpoiler

            spoilerButton.appTooltip = newValue.isSpoiler ? strings().previewSenderSpoilerTooltipDisable : strings().previewSenderSpoilerTooltipEnable

            
            DispatchQueue.main.async {
                if newValue.state != previous.state || newValue.isCollage != previous.isCollage, let window = self.kitWindow {
                    removeAllTooltips(window)
                }
                self.fileButton.controlState = .Normal
                self.photoButton.controlState = .Normal
                self.collageButton.controlState = .Normal
                self.archiveButton.controlState = .Normal
                self.spoilerButton.controlState = .Normal
            }
        }
        get {
            return self._state
        }
    }
    
    fileprivate func updateWithSlowMode(_ slowMode: SlowMode?, urlsCount: Int) {
        if urlsCount > 1, let _ = slowMode  {
            self.fileButton.isEnabled = false
            self.photoButton.isEnabled = false
            self.photoButton.appTooltip = strings().slowModePreviewSenderFileTooltip
            self.fileButton.appTooltip = strings().slowModePreviewSenderFileTooltip
        } else {
            self.fileButton.isEnabled = true
            self.photoButton.isEnabled = true
            self.photoButton.appTooltip = strings().previewSenderMediaTooltip
            self.fileButton.appTooltip = strings().previewSenderFileTooltip
        }
    }
    
    
    
    private let disposable = MetaDisposable()
    private let theme: TelegramPresentationTheme
    
    required init(frame frameRect: NSRect, theme: TelegramPresentationTheme) {
        self.theme = theme
        self.textView = UITextView(frame: NSMakeRect(0, 0, 280, 34))
        super.init(frame: frameRect)
        
        backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.border
        textContainerView.backgroundColor = theme.colors.background
        closeButton.set(image: theme.icons.modalClose, for: .Normal)
        _ = closeButton.sizeToFit()
        
        tableView.getBackgroundColor = {
            .clear
        }
        
        photoButton.appTooltip = strings().previewSenderMediaTooltip
        fileButton.appTooltip = strings().previewSenderFileTooltip
        collageButton.appTooltip = strings().previewSenderCollageTooltip
        archiveButton.appTooltip = strings().previewSenderArchiveTooltip


        
        
        photoButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.previewSenderPhoto), for: .Normal)
        _ = photoButton.sizeToFit()
        
        let updateValue:((PreviewSendingState)->PreviewSendingState)->Void = { [weak self] f in
            guard let `self` = self else {
                return
            }
            self.stateValueInteractiveUpdate?(f(self.state))
        }
        
        photoButton.set(handler: { _ in
            updateValue {
                $0.withUpdatedState(.media)
            }
        }, for: .Click)
        
        
        archiveButton.set(handler: {  _ in
            updateValue {
                $0.withUpdatedState(.archive)
            }
        }, for: .Click)
        
        spoilerButton.set(handler: { _ in
            updateValue {
                $0.withUpdatedIsSpoiler(!$0.isSpoiler)
            }
        }, for: .Click)
        
        collageButton.set(handler: { _ in
            updateValue {
                $0.withUpdatedIsCollage(!$0.isCollage)
            }
        }, for: .Click)
        
        fileButton.set(handler: { _ in
            updateValue {
                $0.withUpdatedState(.file)
            }
        }, for: .Click)
        
        closeButton.set(handler: { [weak self] _ in
            self?.controller?.closeModal()
        }, for: .Click)
        
        fileButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.previewSenderFile), for: .Normal)
        _ = fileButton.sizeToFit()
        
        collageButton.set(image: theme.icons.previewSenderCollage, for: .Normal)
        _ = collageButton.sizeToFit()
        
        archiveButton.set(image: theme.icons.previewSenderArchive, for: .Normal)
        _ = archiveButton.sizeToFit()

        
        spoilerButton.set(image: theme.icons.send_media_spoiler, for: .Normal)
        _ = spoilerButton.sizeToFit()

        headerView.addSubview(closeButton)
        headerView.addSubview(fileButton)
        headerView.addSubview(photoButton)
        headerView.addSubview(collageButton)
        headerView.addSubview(archiveButton)
        headerView.addSubview(spoilerButton)

        sendButton.set(image: theme.icons.chatSendMessage, for: .Normal)
        sendButton.autohighlight = false
        _ = sendButton.sizeToFit()
        
        emojiButton.set(image: theme.icons.chatEntertainment, for: .Normal)
        _ = emojiButton.sizeToFit()
        
        actionsContainerView.addSubview(sendButton)
        actionsContainerView.addSubview(emojiButton)
        
        
        actionsContainerView.setFrameSize(sendButton.frame.width + emojiButton.frame.width + 40, 50)
        
        emojiButton.centerY(x: 0)
        sendButton.centerY(x: emojiButton.frame.maxX + 20)
        
        backgroundColor = theme.colors.background
        
        
        textView.interactions.max_height = 180
        textView.interactions.min_height = 50

        emojiButton.set(handler: { [weak self] control in
            self?.controller?.showEmoji(for: control)
        }, for: .Hover)
        
        sendButton.set(handler: { [weak self] _ in
            self?.controller?.send(false)
        }, for: .SingleClick)
        

        
        sendButton.contextMenu = { [weak self] in
            if let controller = self?.controller, let peer = controller.chatInteraction.peer {
                let chatInteraction = controller.chatInteraction
                let context = chatInteraction.context
                if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                    return nil
                }
                var items:[ContextMenuItem] = []
                
                if peer.id != chatInteraction.context.account.peerId {
                    items.append(ContextMenuItem(strings().chatSendWithoutSound, handler: { [weak controller] in
                        controller?.send(true)
                    }, itemImage: MenuAnimation.menu_mute.value))
                }
                switch chatInteraction.mode {
                case .history, .thread:
                    if !peer.isSecretChat {
                        items.append(ContextMenuItem(peer.id == chatInteraction.context.peerId ? strings().chatSendSetReminder : strings().chatSendScheduledMessage, handler: { [weak controller] in
                            showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak controller] date in
                                controller?.send(false, atDate: date)
                            }), for: context.window)
                        }, itemImage: MenuAnimation.menu_schedule_message.value))
                        
                        if peer.id != chatInteraction.context.peerId, chatInteraction.presentation.canScheduleWhenOnline {
                            items.append(ContextMenuItem(strings().chatSendSendWhenOnline, handler: {  [weak controller] in
                                controller?.send(false, atDate: scheduleWhenOnlineDate)
                            }, itemImage: MenuAnimation.menu_online.value))
                        }
                        
                        items.append(ContextMenuItem(strings().previewSenderSendAsSpoiler, handler: { [weak controller] in
                            controller?.send(false, asSpoiler: true)
                        }, itemImage: MenuAnimation.menu_send_spoiler.value))
                        
                    }
                default:
                    break
                }
                if !items.isEmpty {
                   let menu = ContextMenu()
                    for item in items {
                        menu.addItem(item)
                    }
                    return menu
                }
            }
            return nil
        }
        
        textView.setFrameSize(NSMakeSize(280, 34))

        addSubview(tableView)

        
        textContainerView.addSubview(textView)
        
        addSubview(headerView)
        addSubview(forHelperView)
        addSubview(textContainerView)
        addSubview(actionsContainerView)
        addSubview(separator)
        addSubview(draggingView)
        
        draggingView.isEventLess = true
        layout()
    }
    
    private var textInputSuggestionsView: InputSwapSuggestionsPanel?
    
    func updateTextInputSuggestions(_ files: [TelegramMediaFile], chatInteraction: ChatInteraction, range: NSRange, animated: Bool) {
        
        let context = chatInteraction.context
        
        if !files.isEmpty {
            let current: InputSwapSuggestionsPanel
            let isNew: Bool
            if let view = self.textInputSuggestionsView {
                current = view
                isNew = false
            } else {
                current = InputSwapSuggestionsPanel(inputView: self.textView.inputView, textContent: self.textView.scrollView.contentView, relativeView: self, window: context.window, context: context, chatInteraction: chatInteraction, presentation: self.theme, highlightRect: { [weak self] range, whole in
                    return self?.textView.highlight(for: range, whole: whole) ?? .zero
                })
                self.textInputSuggestionsView = current
                isNew = true
            }
            current.apply(files, range: range, animated: animated, isNew: isNew)
        } else if let view = self.textInputSuggestionsView {
            view.close(animated: animated)
            self.textInputSuggestionsView = nil
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
    func textViewSize() -> (NSSize, CGFloat) {
        let w = textWidth
        let height = self.textView.height(for: w)
        return (NSMakeSize(w, min(max(height, textView.min_height), textView.max_height)), height)
    }
    
    var additionHeight: CGFloat {
        return textViewSize().0.height + headerView.frame.height
    }
    
    func updateHeight(_ height: CGFloat, _ animated: Bool) {
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        self.updateLayout(size: NSMakeSize(self.frame.width, height), transition: transition)
    }
    
    func applyOptions(_ options:[PreviewOptions], count: Int, canCollage: Bool, canSpoiler: Bool) {
        self.fileButton.isHidden = false//!options.contains(.media)
        self.photoButton.isHidden = !options.contains(.media)
        self.archiveButton.isHidden = count < 2
        self.spoilerButton.isHidden = !canSpoiler
        self.collageButton.isHidden = !canCollage
        separator.isHidden = false
        needsLayout = true
    }
    
    var textWidth: CGFloat {
        return frame.width - 10 - actionsContainerView.frame.width
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        transition.updateFrame(view: actionsContainerView, frame: CGRect(origin: NSMakePoint(size.width - actionsContainerView.frame.width, size.height - actionsContainerView.frame.height), size: actionsContainerView.frame.size))
        
        transition.updateFrame(view: headerView, frame: CGRect(origin: .zero, size: NSMakeSize(size.width, 50)))
        
        let height = size.height - additionHeight
        
        let listHeight = tableView.listHeight
        
        let tableRect = NSMakeRect(0, headerView.frame.maxY - 6, frame.width, min(height, listHeight))
        transition.updateFrame(view: tableView, frame: tableRect)
        transition.updateFrame(view: draggingView, frame: size.bounds)
        
        transition.updateFrame(view: closeButton, frame: closeButton.centerFrameY(x: headerView.frame.width - closeButton.frame.width - 10))
        
        transition.updateFrame(view: collageButton, frame: collageButton.centerFrameY(x: closeButton.frame.minX - 10 - collageButton.frame.width))


        var inset: CGFloat = 10

        if !photoButton.isHidden {
            transition.updateFrame(view: photoButton, frame: photoButton.centerFrameY(x: inset))
            inset += photoButton.frame.width + 10
        }
        
        if !fileButton.isHidden {
            transition.updateFrame(view: fileButton, frame: fileButton.centerFrameY(x: inset))
            inset += fileButton.frame.width + 10
        }
        
        collageButton.centerY(x: closeButton.frame.minX - 10 - collageButton.frame.width)


        
        if !archiveButton.isHidden {
            transition.updateFrame(view: archiveButton, frame: archiveButton.centerFrameY(x: inset))
            inset += archiveButton.frame.width + 10
        }
        
        if !spoilerButton.isHidden {
            if collageButton.isHidden {
                transition.updateFrame(view: spoilerButton, frame: spoilerButton.centerFrameY(x: closeButton.frame.minX - 10 - spoilerButton.frame.width))
            } else {
                transition.updateFrame(view: spoilerButton, frame: spoilerButton.centerFrameY(x: collageButton.frame.minX - 10 - spoilerButton.frame.width))
            }
        }
                
        let (textSize, textHeight) = textViewSize()
        
        let textContainerRect = NSMakeRect(0, size.height - textSize.height, size.width, textSize.height)
        transition.updateFrame(view: textContainerView, frame: textContainerRect)
        
        
        transition.updateFrame(view: textView, frame: CGRect(origin: CGPoint(x: 10, y: 0), size: textSize))
        textView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        
        transition.updateFrame(view: separator, frame: NSMakeRect(0, textContainerView.frame.minY, size.width, .borderSize))
        
        transition.updateFrame(view: forHelperView, frame: NSMakeRect(0, textContainerView.frame.minY, 0, 0))
        
        self.textInputSuggestionsView?.updateRect(transition: transition)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)

    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

private final class SenderPreviewArguments {
    let context: AccountContext
    let theme: TelegramPresentationTheme
    let edit:(URL)->Void
    let paint: (URL)->Void
    let delete:(URL)->Void
    let reorder:(Int, Int) -> Void
    init(context: AccountContext, theme: TelegramPresentationTheme, edit: @escaping(URL)->Void, paint: @escaping(URL)->Void, delete: @escaping(URL)->Void, reorder: @escaping(Int, Int) -> Void) {
        self.context = context
        self.theme = theme
        self.edit = edit
        self.paint = paint
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
        case let .mediaGroup(index):
            if case .mediaGroup(index) = rhs {
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
    case mediaGroup(Int)
    case archive
    case section(Int)
}

private enum PreviewEntry : Comparable, Identifiable {
    case section(Int)
    case media(index: Int, sectionId: Int, url: URL, media: Media, isSpoiler: Bool)
    case mediaGroup(index: Int, sectionId: Int, urls: [URL], messages: [Message], isSpoiler: Bool)
    case archive(index: Int, sectionId: Int, urls: [URL], media: Media)
    var stableId: PreviewEntryId {
        switch self {
        case let .section(sectionId):
            return .section(sectionId)
        case let .media(_, _, _, media, _):
            return .media(media)
        case let .mediaGroup(index, _, _, _, _):
            return .mediaGroup(index)
        case .archive:
            return .archive
        }
    }
    
    var index: Int {
        switch self {
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        case let .media(index, sectionId, _, _, _):
            return (sectionId * 1000) + index
        case let .mediaGroup(index, sectionId, _, _, _):
            return (sectionId * 1000) + index
        case let .archive(index, sectionId, _, _):
            return (sectionId * 1000) + index
        }
    }
    
    func item(arguments: SenderPreviewArguments, state: PreviewState, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .media(_, _, url, media, isSpoiler):
            return MediaPreviewRowItem(initialSize, media: media, context: arguments.context, theme: arguments.theme, editedData: state.editedData[url], isSpoiler: isSpoiler, edit: {
                arguments.edit(url)
            }, paint: {
                arguments.paint(url)
            }, delete: {
                arguments.delete(url)
            })
        case let .archive(_, _, _, media):
            return MediaPreviewRowItem(initialSize, media: media, context: arguments.context, theme: arguments.theme, editedData: nil, isSpoiler: false, edit: {
              //  arguments.edit(url)
            }, delete: {
              // arguments.delete(url)
            })
        case let .mediaGroup(_, _, urls, messages, isSpoiler):
            return MediaGroupPreviewRowItem(initialSize, messages: messages, urls: urls, editedData: state.editedData, isSpoiler: isSpoiler, edit: { url in
                arguments.edit(url)
            }, paint: { url in
                arguments.paint(url)
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
    case let .media(index, sectionId, url, lhsMedia, spoiler):
        if case .media(index, sectionId, url, let rhsMedia, spoiler) = rhs {
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
    case let .mediaGroup(index, sectionId, url, lhsMessages, spoiler):
        if case .mediaGroup(index, sectionId, url, let rhsMessages, spoiler) = rhs {
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
    
    switch state.currentState.state {
    case .archive:
        assert(state.medias.count == 1)
        entries.append(.archive(index: index, sectionId: sectionId, urls: state.urls, media: state.medias[0]))
    case .media:
        if state.currentState.isCollage {
            var messages: [Message] = []
            for (i, media) in state.medias.enumerated() {
                messages.append(Message(media, stableId: UInt32(i), messageId: MessageId(peerId: PeerId(0), namespace: 0, id: MessageId.Id(i))))
            }
            let collages = messages.chunks(10)
            for collage in collages {
                entries.append(.mediaGroup(index: index, sectionId: sectionId, urls: state.urls, messages: collage, isSpoiler: state.currentState.isSpoiler))
                index += 1
            }
        } else {
            for (i, media) in state.medias.enumerated() {
                entries.append(.media(index: index, sectionId: sectionId, url: state.urls[i], media: media, isSpoiler: state.currentState.isSpoiler))
                index += 1
            }
        }
    case .file:
        for (i, media) in state.medias.enumerated() {
            entries.append(.media(index: index, sectionId: sectionId, url: state.urls[i], media: media, isSpoiler: false))
            index += 1
        }
    }
    
    return entries
}


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PreviewEntry>], right: [AppearanceWrapperEntry<PreviewEntry>], state: PreviewState, arguments: SenderPreviewArguments, animated: Bool, initialSize:NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments: arguments, state: state, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated, grouping: true)
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
        return lhs.container == rhs.container && lhs.isCollage == rhs.isCollage
    }
    let container: MediaSenderContainer
    let index: Int
    let isCollage: Bool
    private(set) var media: Media?

    init(container: MediaSenderContainer, index: Int, media: Media?, isCollage: Bool) {
        self.container = container
        self.index = index
        self.media = media
        self.isCollage = isCollage
    }
    

    
    var stableId: PreviewMediaId {
        return .container(container)
    }
    
    func withApplyCachedMedia(_ media: Media) -> PreviewMedia {
        return PreviewMedia(container: container, index: index, media: media, isCollage: isCollage)
    }
    
    func generateMedia(account: Account, isSecretRelated: Bool, isCollage: Bool) -> Media {
        
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
        
        _ = Sender.generateMedia(for: container, account: account, isSecretRelated: isSecretRelated, isCollage: isCollage).start(next: { media, path in
            generated = media
            semaphore.signal()
        })
        semaphore.wait()
        
        self.media = generated
        
        return generated
    }
}


private func previewMedias(containers:[MediaSenderContainer], savedState: [PreviewMedia]?, isCollage: Bool) -> [PreviewMedia] {
    var index: Int = 0
    var result:[PreviewMedia] = []
    for container in containers {
        let found = savedState?.first(where: {$0.stableId == .container(container)})
        result.append(PreviewMedia(container: container, index: index, media: found?.media, isCollage: isCollage))
        index += 1
    }
    return result
}


private func prepareMedias(left: [PreviewMedia], right: [PreviewMedia], isSecretRelated: Bool, isCollage: Bool, account: Account) -> UpdateTransition<Media> {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { item in
        return item.generateMedia(account: account, isSecretRelated: isSecretRelated, isCollage: isCollage)
    })
    return UpdateTransition(deleted: removed, inserted: inserted, updated: updated)
}

private struct UrlAndState : Equatable {
    let urls:[URL]
    let state: PreviewSendingState
    init(_ urls:[URL], _ state: PreviewSendingState) {
        self.urls = urls
        self.state = state
    }
}


class PreviewSenderController: ModalViewController, Notifable {
   
    private var lockInteractiveChanges: Bool = false
    private var _urls:[URL] = []
    
    fileprivate var urls:[URL] {
        set {
            _urls = newValue.uniqueElements
            let canCollage: Bool = canCollagesFromUrl(_urls)
            if !lockInteractiveChanges {
                if self.genericView.state.isCollage, !canCollage {
                    self.genericView.state = self.genericView.state.withUpdatedIsCollage(false)
                }
            }
            self.genericView.updateWithSlowMode(chatInteraction.presentation.slowMode, urlsCount: _urls.count)
            self.urlsAndStateValue.set(UrlAndState(_urls, self.genericView.state))
        }
        get {
            return _urls
        }
    }
    
    fileprivate let urlsAndStateValue:ValuePromise<UrlAndState> = ValuePromise(ignoreRepeated: true)
    
    
    private let context:AccountContext
    let chatInteraction:ChatInteraction
    private let disposable = MetaDisposable()
    private let emoji: EmojiesController
    private var cachedMedia:[PreviewSendingState: (media: [Media], items: [TableRowItem])] = [:]
    private var sent: Bool = false
    private let pasteDisposable = MetaDisposable()
    
    private let inputSwapDisposable = MetaDisposable()
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
        return .modal
    }
    
    private var sendCurrentMedia:((Bool, Date?, Bool?)->Void)? = nil
    private var runEditor:((URL, Bool)->Void)? = nil
    private var insertAdditionUrls:(([URL]) -> Void)? = nil
    
    private let animated: Atomic<Bool> = Atomic(value: false)

    private func updateSize(_ width: CGFloat, animated: Bool) {
        
        if let contentSize = context.window.contentView?.frame.size {
            
            var listHeight = genericView.tableView.listHeight
            if let inputQuery = inputInteraction.state.inputQueryResult {
                switch inputQuery {
                case let .emoji(emoji, _, _):
                    if !emoji.isEmpty {
                        listHeight = listHeight > 0 ? max(40, listHeight) : 0
                    }
                default:
                    //listHeight = listHeight > 0 ? max(150, listHeight) : 0
                    break
                }
            }
            
            let height = listHeight + max(genericView.additionHeight, 88)

            
            self.modal?.resize(with: NSMakeSize(width, min(contentSize.height - 70, height)), animated: animated)
            
        }
    }
  
    override var dynamicSize: Bool {
        return true
    }
    
    override func draggingItems(for pasteboard: NSPasteboard) -> [DragItem] {
        if let types = pasteboard.types, types.contains(.kFilenames) {
            let list = pasteboard.propertyList(forType: .kFilenames) as? [String]
            if let list = list {
                return [DragItem(title: strings().previewDraggingAddItemsCountable(list.count), desc: "", handler: { [weak self] in
                    self?.insertAdditionUrls?(list.map({URL(fileURLWithPath: $0)}))
                    
                })]
            }
        }
        return []
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let currentEvent = NSApp.currentEvent {
            if FastSettings.checkSendingAbility(for: currentEvent), didSetReady {
                send(false)
                return .invoked
            }
        }
        return .invokeNext
    }
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        
        let currentText = self.genericView.textView.string()
        let basicText = self.temporaryInputState?.inputText ?? ""
        if (self.temporaryInputState == nil && !currentText.isEmpty) || (basicText != currentText) {
            verifyAlert_button(for: context.window, header: strings().mediaSenderDiscardChangesHeader, information: strings().mediaSenderDiscardChangesText, ok: strings().mediaSenderDiscardChangesOK, successHandler: { [weak self] _ in
                self?.closeModal()
            })
        } else {
            self.closeModal()
        }
    }
    
    fileprivate func closeModal() {
        super.close()
    }
    
    func send(_ silent: Bool, atDate: Date? = nil, asSpoiler: Bool? = nil) {
        
        let text = self.genericView.textView.string().trimmed
        let context = self.context
        if context.isPremium {
            if text.length > context.premiumLimits.caption_length_limit_premium {
                alert(for: chatInteraction.context.window, info: strings().chatInputErrorMessageTooLongCountable(text.length - Int(context.premiumLimits.caption_length_limit_premium)))
                return
            }
        } else {
            if text.length > context.premiumLimits.caption_length_limit_default {
                verifyAlert_button(for: context.window, information: strings().chatInputErrorMessageTooLongCountable(text.length - Int(context.premiumLimits.caption_length_limit_default)), ok: strings().alertOK, cancel: "", option: strings().premiumGetPremiumDouble, successHandler: { result in
                    switch result {
                    case .thrid:
                        showPremiumLimit(context: context, type: .caption(text.length))
                    default:
                        break
                    }

                })
                return
            }
        }
        
        switch chatInteraction.mode {
        case .scheduled:
            if let peer = chatInteraction.peer {
                showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { [weak self] date in
                    self?.sendCurrentMedia?(silent, date, asSpoiler)
                }), for: context.window)
            }
        case .history, .thread:
            sendCurrentMedia?(silent, atDate, asSpoiler)
        case .pinned:
            break
        }
    }
    
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: false)
    }
    
    override var handleAllEvents: Bool {
        return true
    }
    
    private var inputPlaceholder: String {
        
        var placeholder: String = strings().previewSenderCommentPlaceholder
        if self.genericView.tableView.count == 1 {
            if let item = self.genericView.tableView.firstItem {
                if let item = item as? MediaPreviewRowItem {
                    if item.media.canHaveCaption {
                        placeholder = strings().previewSenderCaptionPlaceholder
                    }
                } else if item is MediaGroupPreviewRowItem {
                    placeholder = strings().previewSenderCaptionPlaceholder
                }
            }
        }
        
        return placeholder
    }
    
    private func set(_ state: Updated_ChatTextInputState) {
        self.contextChatInteraction.update({
            $0.withUpdatedEffectiveInputState(state.textInputState())
        })
    }
    
    private func inputDidUpdateLayout(animated: Bool) {
        updateSize(frame.width, animated: animated)

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let initialSize = self.atomicSize
        let theme = self.presentation ?? theme
        
        let myPeerColor = chatInteraction.context.myPeer?.nameColor
        let colors: PeerNameColors.Colors
        if let myPeerColor = myPeerColor {
            colors = chatInteraction.context.peerNameColors.get(myPeerColor)
        } else {
            colors = .init(main: theme.colors.accent)
        }
        self.genericView.textView.inputTheme = theme.inputTheme.withUpdatedQuote(colors)
        
        
        self.genericView.textView.interactions.inputDidUpdate = { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.set(state)
            self.inputDidUpdateLayout(animated: true)
        }
        
        self.genericView.textView.interactions.processEnter = { [weak self] event in
            return self?.processEnter(event) ?? true
        }
        self.genericView.textView.interactions.processPaste = { [weak self] pasteboard in
            return self?.processPaste(pasteboard) ?? false
        }
        self.genericView.textView.interactions.processAttriburedCopy = { attributedString in
            return globalLinkExecutor.copyAttributedString(attributedString)
        }
        
        genericView.emojiButton.isHidden = false

        
        self.genericView.textView.context = context
        genericView.draggingView.controller = self
        genericView.controller = self
        inputInteraction.add(observer: self)
        
        self.genericView.textView.placeholder = self.inputPlaceholder
        
        
        if let attributedString = attributedString {
            genericView.textView.set(.init(attributedText: stateAttributedStringForText(attributedString), selectionRange: attributedString.length ..< attributedString.length))
        } else {
            let input = chatInteraction.presentation.interfaceState.inputState
            self.temporaryInputState = input
            genericView.textView.set(input)
            chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedInputState(ChatTextInputState())})})
        }
        
        let interactions = EntertainmentInteractions(.emoji, peerId: chatInteraction.peerId)
        
        interactions.sendEmoji = { [weak self] emoji, fromRect in
            _ = self?.contextChatInteraction.appendText(.initialize(string: emoji))
            _ = self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        }
        interactions.sendAnimatedEmoji = { [weak self] sticker, _, _, fromRect in
            let text = (sticker.file.customEmojiText ?? sticker.file.stickerText ?? clown).fixed
            _ = self?.contextChatInteraction.appendText(.makeAnimated(sticker.file, text: text))
            _ = self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        }
        
        emoji.update(with: interactions, chatInteraction: contextChatInteraction)
        
        let actionsDisposable = DisposableSet()
        self.disposable.set(actionsDisposable)
        
        
        let initialState = PreviewState(urls: [], medias: [], currentState: .init(state: .media, isCollage: true, isSpoiler: false), editedData: [:])
        
        let statePromise:ValuePromise<PreviewState> = ValuePromise(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((PreviewState) -> PreviewState) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let removeTransitionAnimation: Atomic<Bool> = Atomic(value: false)
        
        let arguments = SenderPreviewArguments(context: context, theme: presentation ?? theme, edit: { [weak self] url in
            self?.runEditor?(url, false)
        }, paint: { [weak self] url in
            self?.runEditor?(url, true)
        }, delete: { [weak self] url in
            guard let `self` = self else { return }
            self.lockInteractiveChanges = true
            self.urls.removeAll(where: {$0 == url})
            self.lockInteractiveChanges = false
        }, reorder: { [weak self] from, to in
            guard let `self` = self else { return }
            _ = removeTransitionAnimation.swap(true)
            self.lockInteractiveChanges = true
            self.urls.move(at: from, to: to)
            self.lockInteractiveChanges = false
        })
        
        let archiveRandomId = arc4random()
        
        let isSecretRelated = chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat
       
        
        let previousMedias:Atomic<[PreviewMedia]> = Atomic(value: [])
        let savedStateMedias:Atomic<[PreviewSendingState : [PreviewMedia]]> = Atomic(value: [:])

        let urlSignal = self.urlsAndStateValue.get() |> deliverOnPrepareQueue
        
        let urlsTransition: Signal<(UpdateTransition<Media>, [URL], PreviewSendingState, [PreviewMedia]), NoError> = urlSignal |> map { urlsAndState -> ([PreviewMedia], [URL], PreviewSendingState) in
            
            let urls = urlsAndState.urls
            let state = urlsAndState.state
            
            var containers = urls.compactMap { url -> MediaSenderContainer? in
                switch state.state {
                case .media:
                    return MediaSenderContainer(path: url.path, isFile: false)
                case .file:
                    return MediaSenderContainer(path: url.path, isFile: true)
                case .archive:
                    return nil
                }
            }
            
            if state.state == .archive {
                let dir = NSTemporaryDirectory() + "tg_temp_archive_\(archiveRandomId)"
                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
                containers.append(ArchiverSenderContainer(path: dir, files: urls))
            }
            
            return (previewMedias(containers: containers, savedState: savedStateMedias.with { $0[state]}, isCollage: state.isCollage), urls, state)
        } |> map { previews, urls, state in
            return (prepareMedias(left: previousMedias.swap(previews), right: previews, isSecretRelated: isSecretRelated, isCollage: state.isCollage, account: context.account), urls, state, previews)
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
        
        let isSecretChat = chatInteraction.presentation.peer?.isSecretChat == true
        
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
            
            self.genericView.state = state
            
            let options = takeSenderOptions(for: self.urls)
            var canCollage = canCollagesFromUrl(self.urls)
            switch state.state {
            case .media:
                canCollage = canCollage && options == [.media]
            case .archive:
                canCollage = false
            default:
                break
            }
            
            let canSpoiler: Bool
            canSpoiler = options.contains(.media) && state.state == .media && !isSecretChat

            
            self.genericView.applyOptions(options, count: self.urls.count, canCollage: canCollage, canSpoiler: canSpoiler)
            
            CATransaction.begin()
            self.genericView.tableView.merge(with: transition)
            self.genericView.tableView.reloadHeight()
            CATransaction.commit()
            
            self.genericView.textView.placeholder = self.inputPlaceholder
            
            

            if self.genericView.tableView.isEmpty {
                self.closeModal()
                if self.chatInteraction.presentation.effectiveInput.inputText.isEmpty {
                    let input = self.genericView.textView.interactions.presentation.textInputState()
                    self.chatInteraction.update({$0.withUpdatedEffectiveInputState(input)})
                }
            } else {
                let oldSize = self.genericView.frame.size
                self.updateSize(320, animated: first.swap(!self.genericView.tableView.isEmpty))
                if scrollAfterTransition.swap(false), self.genericView.frame.size == oldSize {
                    self.genericView.tableView.scroll(to: .down(true))
                }
            }
            self.readyOnce()
            

            if self.genericView.tableView.count > 1 {
                self.genericView.tableView.resortController = TableResortController(resortRange: NSMakeRange(0, self.genericView.tableView.count), startTimeout: 0.0, start: { _ in }, resort: { _ in }, complete: { from, to in
                    arguments.reorder(from, to)
                })
            } else {
                self.genericView.tableView.resortController = nil
            }
            
        }))
        
        
        var canCollage: Bool = canCollagesFromUrl(self.urls)
        let options = takeSenderOptions(for: self.urls)
        let mediaState:PreviewSendingState.State = asMedia && options == [.media] ? .media : .file
        switch mediaState {
        case .media:
            canCollage = canCollage && options == [.media]
        case .archive:
            canCollage = false
        default:
            break
        }
        var state: PreviewSendingState = .init(state: mediaState, isCollage: canCollage, isSpoiler: false)
        if let _ = chatInteraction.presentation.slowMode {
            if state.state != .archive && self.urls.count > 1, !state.isCollage {
                state = .init(state: .archive, isCollage: false, isSpoiler: false)
            }
        }
        
        self.genericView.state = state
        self.urlsAndStateValue.set(UrlAndState(self.urls, state))
        self.genericView.updateWithSlowMode(chatInteraction.presentation.slowMode, urlsCount: self.urls.count)
        
        self.genericView.textView.placeholder = self.inputPlaceholder
        
        self.genericView.stateValueInteractiveUpdate = { [weak self] state in
            guard let `self` = self else { return }
            var state = state
            var canCollage = canCollagesFromUrl(self.urls)
            let options = takeSenderOptions(for: self.urls)
            switch state.state {
            case .media:
                canCollage = canCollage && options == [.media]
            case .archive:
                canCollage = false
            default:
                break
            }
            if !canCollage && state.isCollage {
                state = state.withUpdatedIsCollage(false)
            }
            self.genericView.tableView.scroll(to: .up(true))
            self.urlsAndStateValue.set(UrlAndState(self.urls, state))
        }
        
        self.sendCurrentMedia = { [weak self] silent, atDate, asSpoiler in
            guard let `self` = self else { return }
            
            let slowMode = self.chatInteraction.presentation.slowMode
            let inputState = self.genericView.textView.interactions.presentation

            if let slowMode = slowMode, slowMode.hasLocked {
                self.genericView.textView.shake()
            } else if self.inputPlaceholder != strings().previewSenderCaptionPlaceholder && slowMode != nil && inputState.inputText.length > 0 {
                tooltip(for: self.genericView.sendButton, text: strings().slowModeMultipleError)
                self.genericView.textView.selectAll()
                self.genericView.textView.shake()
            } else {
                let peer = self.chatInteraction.peer
                let state = stateValue.with { $0.currentState }
                let medias = stateValue.with { $0.medias }
                var permissions:[(String, Int)] = []
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
                    if let string = checkMediaPermission(medias[i], for: peer) {
                        permissions.append((string, i))
                    }
                }
                
                var input:ChatTextInputState = inputState.textInputState().subInputState(from: NSMakeRange(0, inputState.inputText.length))
                
                if input.attributes.isEmpty {
                    input = ChatTextInputState(inputText: input.inputText.trimmed)
                }
                var additionalMessage: ChatTextInputState? = nil
                
                if (medias.count > 1  || (medias.count == 1 && (!medias[0].canHaveCaption))) && !input.inputText.isEmpty  {
                    if !state.isCollage {
                        additionalMessage = input
                        input = ChatTextInputState()
                    }
                }
                if additionalMessage != nil, let text = permissionText(from: peer, for: .banSendText) {
                    permissions.insert((text, -1), at: 0)
                }
                
                for (_, i) in permissions {
                    if i != -1 {
                        self.genericView.tableView.optionalItem(at: i)?.view?.shakeView()
                    } else {
                        self.genericView.textView.shake(beep: true)
                    }
                }
                if let first = permissions.first {
                    showModalText(for: context.window, text: first.0)
                    return
                }
                
                self.sent = true
                self.emoji.popover?.hide()
                self.closeModal()
                
                self.chatInteraction.sendMessage(silent, atDate)
                if state.isCollage {
                    let collages = medias.chunks(10)
                    for collage in collages {
                        self.chatInteraction.sendMedias(collage, input, state.isCollage, additionalMessage, silent, atDate, asSpoiler ?? state.isSpoiler)
                        additionalMessage = nil
                    }
                } else {
                    self.chatInteraction.sendMedias(medias, input, state.isCollage, additionalMessage, silent, atDate, asSpoiler ?? state.isSpoiler)
                }
            }
            
            
        }
        
        self.runEditor = { [weak self] url, paint in
            guard let `self` = self else { return }
            
            let editedData = stateValue.with { $0.editedData }
            
            let data = editedData[url] ?? EditedImageData(originalUrl: url)
            
            if paint, let image = NSImage(contentsOf: data.originalUrl) {
                var paintings:[EditImageDrawTouch] = data.paintings
                let image = image._cgImage!
                let editor = EditImageCanvasController(image: image, actions: data.paintings, updatedImage: { updated in
                    paintings = updated
                }, closeHandler: { [weak self] in
                    guard let `self` = self else {return}
                    var editedData = data
                    editedData.paintings = paintings
                    let new = EditedImageData.generateNewUrl(data: editedData, selectedRect: CGRect(origin: .zero, size: image.size)) |> deliverOnMainQueue
                    self.editorDisposable.set(new.start(next: { [weak self] new in
                        if let index = self?.urls.firstIndex(where: { ($0 as NSURL) === (url as NSURL) }) {
                            updateState { $0.withUpdatedEditedData { data in
                                var data = data
                                data[new] = editedData
                                if editedData.hasntData {
                                    data.removeValue(forKey: new)
                                }
                                return data
                            }}
                            self?.urls[index] = new
                            addAppLogEvent(postbox: context.account.postbox, time: Date().timeIntervalSince1970, type: AppLogEvents.imageEditor.rawValue, peerId: context.peerId, data: [:])
                        }
                    }))
                }, alone: true)
                showModal(with: editor, for: context.window, animationType: .scaleCenter)

            } else {
                let editor = EditImageModalController(data.originalUrl, context: context, defaultData: data)
                showModal(with: editor, for: context.window, animationType: .scaleCenter)
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
                        addAppLogEvent(postbox: context.account.postbox, time: Date().timeIntervalSince1970, type: AppLogEvents.imageEditor.rawValue, peerId: context.peerId, data: [:])
                    }
                }))
            }
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

        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            let state = stateValue.with { $0.currentState }
            let medias = stateValue.with { $0.medias }
            
            if state.state == .media, medias.count == 1, medias.first is TelegramMediaImage {
                self.runEditor?(self.urls[0], false)
            }
            return .invoked
        }, with: self, for: .E, priority: .high, modifierFlags: [.command])
        
        
        context.window.set(handler: { _ -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .LeftArrow, priority: .modal)
        
        context.window.set(handler: { _ -> KeyHandlerResult in
            return .invokeNext
        }, with: self, for: .RightArrow, priority: .modal)
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.inputInteraction.state.inputQueryResult != nil {
                return .rejected
            }
            return .invokeNext
        }, with: self, for: .UpArrow, priority: .modal)
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.inputInteraction.state.inputQueryResult != nil {
                return .rejected
            }
            return .invokeNext
        }, with: self, for: .DownArrow, priority: .modal)
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let strongSelf = self, strongSelf.context.window.firstResponder != strongSelf.genericView.textView.inputView {
                _ = strongSelf.context.window.makeFirstResponder(strongSelf.genericView.textView.inputView)
                return .invoked
            }
        return .invoked
        }, with: self, for: .Tab, priority: .modal)
        
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.inputApplyTransform(.attribute(TextInputAttributes.bold))
            return .invoked
        }, with: self, for: .B, priority: .modal, modifierFlags: [.command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.inputApplyTransform(.attribute(TextInputAttributes.underline))
            return .invoked
        }, with: self, for: .U, priority: .modal, modifierFlags: [.shift, .command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.inputApplyTransform(.attribute(TextInputAttributes.spoiler))
            return .invoked
        }, with: self, for: .P, priority: .modal, modifierFlags: [.shift, .command])
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.inputApplyTransform(.attribute(TextInputAttributes.strikethrough))
            return .invoked
        }, with: self, for: .X, priority: .modal, modifierFlags: [.shift, .command])
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.genericView.textView.inputApplyTransform(.url)
            return .invoked
        }, with: self, for: .U, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.inputApplyTransform(.attribute(TextInputAttributes.italic))
            return .invoked
        }, with: self, for: .I, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.inputApplyTransform(.attribute(TextInputAttributes.monospace))
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
    
    func runDrawer() {
        self.runEditor?(self.urls[0], false)
    }
    
    deinit {
        inputInteraction.remove(observer: self)
        disposable.dispose()
        editorDisposable.dispose()
        archiverStatusesDisposable.dispose()
        inputSwapDisposable.dispose()
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
        return genericView.textView.inputView
    }
    
    private let asMedia: Bool
    private let attributedString: NSAttributedString?
    private let presentation: TelegramPresentationTheme?
    init(urls:[URL], chatInteraction:ChatInteraction, asMedia:Bool = true, attributedString: NSAttributedString? = nil, presentation: TelegramPresentationTheme? = nil) {
        self.presentation = presentation
        let filtred = urls.filter { url in
            return FileManager.default.fileExists(atPath: url.path)
        }.uniqueElements
        
        self._urls = filtred
    
        self.attributedString = attributedString
        let context = chatInteraction.context
        self.asMedia = asMedia
        self.context = context
        self.emoji = EmojiesController(context, presentation: presentation ?? theme)
        
       

        self.contextChatInteraction = ChatInteraction(chatLocation: chatInteraction.chatLocation, context: context)
        
        inputContextHelper = InputContextHelper(chatInteraction: contextChatInteraction)
        self.chatInteraction = chatInteraction
        super.init(frame:NSMakeRect(0, 0, 320, 300))
        bar = .init(height: 0)
        

        contextChatInteraction.movePeerToInput = { [weak self] peer in
            if let strongSelf = self {
                let textInputState = strongSelf.genericView.textView.inputTextState.textInputState()
                
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
                        attributes.append(.uid(range.lowerBound ..< range.upperBound - 1, peer.id.id._internalGetInt64Value()))
                        let updatedState = ChatTextInputState(inputText: state.inputText, selectionRange: state.selectionRange, attributes: attributes)
                        strongSelf.contextChatInteraction.update({$0.withUpdatedEffectiveInputState(updatedState)})
                    }
                }
            }
        }
        
        self.contextChatInteraction.add(observer: self)
        self.chatInteraction.add(observer: self)
    }
    
    func showEmoji(for control: Control) {
        showPopover(for: control, with: emoji)
    }

    
    func processEnter(_ event: NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            return true
        }
        return false
    }
    
    
    func isEqual(to other: Notifable) -> Bool {
        return false
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? PreviewContextState, let oldValue = oldValue as? PreviewContextState {
            if value.inputQueryResult != oldValue.inputQueryResult {
                self.updateSize(frame.width, animated: animated)
                inputContextHelper.context(with: value.inputQueryResult, for: self.genericView, relativeView: self.genericView.forHelperView, animated: animated)
            }
        } else if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if value === self.contextChatInteraction.presentation {
                if value.effectiveInput != oldValue.effectiveInput {
                    updateInput(value, prevState: oldValue, animated)
                }
            } else if value === self.chatInteraction.presentation {
                if value.slowMode != oldValue.slowMode {
                    let urls = self.urls
                    self.urls = urls
                }
            }
            if value.effectiveInput != oldValue.effectiveInput {
                self.genericView.textView.scrollToCursor()
            }
        }
    }
    
    private func updateInput(_ state:ChatPresentationInterfaceState, prevState: ChatPresentationInterfaceState, _ animated:Bool = true) -> Void {
        
        let input = state.effectiveInput
        let textInputContextState = textInputStateContextQueryRangeAndType(input, includeContext: false)
        let chatInteraction = self.contextChatInteraction
        var cleanup = true
        if let textInputContextState = textInputContextState {
            if textInputContextState.1.contains(.swapEmoji) {
                let stringRange = textInputContextState.0
                let range = NSRange(string: input.inputText, range: stringRange)
                if !input.isAnimatedEmoji(at: range) {
                    let query = String(input.inputText[stringRange])
                    let signal = InputSwapSuggestionsPanelItems(query, peerId: chatInteraction.peerId, context: chatInteraction.context)
                    |> deliverOnMainQueue
                    self.inputSwapDisposable.set(signal.start(next: { [weak self] files in
                        self?.genericView.updateTextInputSuggestions(files, chatInteraction: chatInteraction, range: range, animated: animated)
                    }))
                    cleanup = false
                }
            }
        }
        
        if cleanup {
            self.genericView.updateTextInputSuggestions([], chatInteraction: chatInteraction, range: NSMakeRange(0, 0), animated: animated)
            self.inputSwapDisposable.set(nil)
        }
        
        genericView.textView.set(input)
        
        self.updateContextQuery(NSMakeRange(input.selectionRange.lowerBound, input.selectionRange.upperBound - input.selectionRange.lowerBound))
    }
    
    func updateContextQuery(_ range: NSRange) {
        
        let animated: Bool = true
        let state = genericView.textView.interactions.presentation.textInputState()

        if let peer = chatInteraction.peer, let (possibleQueryRange, possibleTypes, _) = textInputStateContextQueryRangeAndType(state, includeContext: false) {
            
            if (possibleTypes.contains(.mention) && (peer.isGroup || peer.isSupergroup)) || possibleTypes.contains(.emoji) || possibleTypes.contains(.emojiFast) {
                let query = String(state.inputText[possibleQueryRange])
                if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(chatLocations: [chatInteraction.chatLocation], possibleTypes.contains(.emoji) ? .emoji(query, firstWord: false) : possibleTypes.contains(.emojiFast) ? .emoji(query, firstWord: true) : .mention(query: query, includeRecent: false), currentQuery: self.contextQueryState?.0, context: context, filter: .filterSelf(includeNameless: true, includeInlineBots: false)) {
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
                self.contextQueryState?.1.dispose()
                inputInteraction.update(animated: animated, {
                    $0.updatedInputQueryResult { _ in
                        return nil
                    }
                })
            }
            
            
        } else {
            self.contextQueryState?.1.dispose()
            inputInteraction.update(animated: animated, {
                $0.updatedInputQueryResult { _ in
                    return nil
                }
            })
        }
    }
    
    
    func processPaste(_ pasteboard: NSPasteboard) -> Bool {
        
        let result = InputPasteboardParser.canProccessPasteboard(pasteboard, context: context)
        
    
        let pasteRtf:()->Void = { [weak self] in
            guard let `self` = self else {
                return
            }
            if let data = pasteboard.data(forType: .rtfd) ?? pasteboard.data(forType: .rtf) {
                if let attributed = (try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)) ?? (try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil))  {
                    
                    let (attributed, attachments) = attributed.applyRtf()
                    self.contextChatInteraction.appendText(attributed)
                    if !attachments.isEmpty {
                        self.pasteDisposable.set((prepareTextAttachments(attachments) |> deliverOnMainQueue).start(next: { [weak self] urls in
                            if !urls.isEmpty {
                                self?.insertAdditionUrls?(urls)
                            }
                        }))
                    }
                }
            }
            
        }
        
        if !result {
            self.pasteDisposable.set(InputPasteboardParser.getPasteboardUrls(pasteboard, context: context).start(next: { [weak self] urls in
                self?.insertAdditionUrls?(urls)
                
                if urls.isEmpty {
                    pasteRtf()
                }
            }))
        }
        
        return !result
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        return NSMakeSize(textView.frame.width, textView.frame.height)
    }
    
    override func viewClass() -> AnyClass {
        return PreviewSenderView.self
    }
    

    override func initializer() -> NSView {
        return PreviewSenderView(frame: frame, theme: presentation ?? theme)
    }
    
    override func didResizeView(_ size: NSSize, animated: Bool) {
        self.genericView.updateHeight(size.height, animated)
    }
    
    override func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
        super.updateFrame(frame, transition: transition)
    }
    
}
