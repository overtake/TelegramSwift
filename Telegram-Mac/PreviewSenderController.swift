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
import TelegramMedia

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
    enum Sort : Int32 {
        case down
        case up
    }
    let state:State
    let isCollage: Bool
    let isSpoiler: Bool
    let sort: Sort
    let payAmount: Int64?
    let sendMessageStars: StarsAmount?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(state)
        hasher.combine(isCollage)
        hasher.combine(isSpoiler)
        if let payAmount {
            hasher.combine(payAmount)
        }
        if let sendMessageStars {
            hasher.combine(sendMessageStars.value)
        }
    }
    
    var sortValue: Sort {
        if state != .media {
            return .down
        } else {
            return self.sort
        }
    }
    
    func withUpdatedState(_ state: State) -> PreviewSendingState {
        return .init(state: state, isCollage: self.isCollage, isSpoiler: self.isSpoiler, sort: self.sort, payAmount: self.payAmount, sendMessageStars: self.sendMessageStars)
    }
    func withUpdatedIsCollage(_ isCollage: Bool) -> PreviewSendingState {
        return .init(state: self.state, isCollage: isCollage, isSpoiler: self.isSpoiler, sort: self.sort, payAmount: self.payAmount, sendMessageStars: self.sendMessageStars)
    }
    func withUpdatedIsSpoiler(_ isSpoiler: Bool) -> PreviewSendingState {
        return .init(state: self.state, isCollage: self.isCollage, isSpoiler: isSpoiler, sort: self.sort, payAmount: self.payAmount, sendMessageStars: self.sendMessageStars)
    }
    func withUpdatedSort(_ sort: Sort) -> PreviewSendingState {
        return .init(state: self.state, isCollage: self.isCollage, isSpoiler: isSpoiler, sort: sort, payAmount: self.payAmount, sendMessageStars: self.sendMessageStars)
    }
    func withUpdatedPayAmount(_ payAmount: Int64?) -> PreviewSendingState {
        return .init(state: self.state, isCollage: self.isCollage, isSpoiler: isSpoiler, sort: sort, payAmount: payAmount, sendMessageStars: self.sendMessageStars)
    }
    func withUpdatedSendMessageStars(_ sendMessageStars: StarsAmount?) -> PreviewSendingState {
        return .init(state: self.state, isCollage: self.isCollage, isSpoiler: isSpoiler, sort: sort, payAmount: self.payAmount, sendMessageStars: sendMessageStars)
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
    fileprivate let actions = ImageButton()
    
    fileprivate var starsSendActionView: StarsSendActionView?

    fileprivate let titleView = TextView()
    
    fileprivate let textContainerView: View = View()
    fileprivate let separator: View = View()
    fileprivate let forHelperView: View = View()
    fileprivate weak var controller: PreviewSenderController?
    fileprivate var messageEffect: InputMessageEffectView?
    fileprivate var stateValueInteractiveUpdate: ((PreviewSendingState)->Void)?
    
    fileprivate var canCollage: Bool = false
    fileprivate var canSpoiler: Bool = false
    fileprivate var options:[PreviewOptions] = []
    fileprivate var totalCount: Int = 0
    fileprivate var slowMode: SlowMode? = nil
    
    private var _state: PreviewSendingState = PreviewSendingState(state: .file, isCollage: FastSettings.isNeedCollage, isSpoiler: false, sort: .down, payAmount: nil, sendMessageStars: nil)
    
    var state: PreviewSendingState {
        set {
            _state = newValue
        }
        get {
            return self._state
        }
    }
    
    fileprivate func updateWithSlowMode(_ slowMode: SlowMode?, urlsCount: Int) {
        self.slowMode = slowMode
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
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        actions.isSelected = false
        actions.set(image: theme.icons.chatActions, for: .Normal)
        actions.autohighlight = false
        actions.scaleOnClick = true
        actions.sizeToFit()
        
        tableView.getBackgroundColor = {
            .clear
        }
        
        
        let updateValue:((PreviewSendingState)->PreviewSendingState)->Void = { [weak self] f in
            guard let `self` = self else {
                return
            }
            self.stateValueInteractiveUpdate?(f(self.state))
        }
        
      
        closeButton.set(handler: { [weak self] _ in
            self?.controller?.closeModal()
        }, for: .Click)
        

        headerView.addSubview(closeButton)
        headerView.addSubview(actions)
        headerView.addSubview(titleView)

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
        

        
        textView.setFrameSize(NSMakeSize(280, 34))


        
        textContainerView.addSubview(textView)
        
        addSubview(headerView)
        addSubview(tableView)
        addSubview(forHelperView)
        addSubview(textContainerView)
        addSubview(actionsContainerView)
        addSubview(separator)
        

        
        addSubview(draggingView)
        
        draggingView.isEventLess = true
        
        
        actions.contextMenu = { [weak self] in
            guard let self else {
                return nil
            }
            
            let canCollage = self.canCollage
            let canSpoiler = self.canSpoiler
            let optons = self.options
            let totalCount = self.totalCount
            let newValue = self.state
                            
            let menu = ContextMenu()
            
            if options.contains(.media) {
                menu.addItem(ContextMenuItem(strings().previewSenderSendAsMedia, handler: {
                    updateValue {
                        $0.withUpdatedState(.media)
                    }
                }, itemImage: newValue.state == .media ? MenuAnimation.menu_check_selected.value : nil))
            }
           
            menu.addItem(ContextMenuItem(strings().previewSenderSendAsFile, handler: {
                updateValue {
                    $0.withUpdatedState(.file)
                }
            }, itemImage: newValue.state == .file ? MenuAnimation.menu_check_selected.value : nil))
            if totalCount > 1 {
                menu.addItem(ContextMenuItem(strings().previewSenderArchive, handler: {
                    updateValue {
                        $0.withUpdatedState(.archive)
                    }
                }, itemImage: newValue.state == .archive ? MenuAnimation.menu_check_selected.value : nil))
            }
            if canCollage, totalCount > 1 {
                menu.addItem(ContextSeparatorItem())

                menu.addItem(ContextMenuItem(strings().previewSenderGrouped, handler: {
                    updateValue {
                        $0.withUpdatedIsCollage(true)
                    }
                    FastSettings.isNeedCollage = true
                }, itemImage: newValue.isCollage ? MenuAnimation.menu_check_selected.value : nil))
                menu.addItem(ContextMenuItem(strings().previewSenderUngrouped, handler: {
                    updateValue {
                        $0.withUpdatedIsCollage(false)
                    }
                    FastSettings.isNeedCollage = false
                }, itemImage: !newValue.isCollage ? MenuAnimation.menu_check_selected.value : nil))
            }
            if canSpoiler || state.state == .media {
                menu.addItem(ContextSeparatorItem())
            }
            
            
            if totalCount == 1, newValue.state == .media {
                if let medias = self.controller?.getMedias(), let media = medias[0] as? TelegramMediaFile, let url = self.controller?.urls.first {
                    if media.isVideo {
                        
                        enum Action {
                            case upload
                            case change
                            case remove
                            var string: String {
                                switch self {
                                case .upload:
                                    return strings().previewSenderUploadVideoCover
                                case .change:
                                    return strings().previewSenderChangeVideoCover
                                case .remove:
                                    return strings().previewSenderRemoveVideoCover
                                }
                            }
                        }
                        
                        let action: Action
                        if media.videoCover == nil {
                            action = .upload
                        } else {
                            action = .change
                        }
                        
                        menu.addItem(ContextMenuItem(action.string, handler: { [weak self] in
                            if let controller = self?.controller {
                                let context = controller.chatInteraction.context
                                filePanel(with: photoExts, allowMultiple: false, for: context.window, completion: { files in
                                    if let first = files?.first {
                                        
                                        let editorSettings: EditControllerSettings
                                        if let size = media.dimensions?.size {
                                            editorSettings = .disableSizes(dimensions: SelectionRectDimensions.bestDimension(for: size), circle: false)
                                        } else {
                                            editorSettings = .plain
                                        }
                                        
                                        let editor = EditImageModalController(URL(fileURLWithPath: first), context: context, settings: editorSettings)
                                        showModal(with: editor, for: context.window, animationType: .scaleCenter)
                                        
                                        
                                        _ = (editor.result |> deliverOnMainQueue).start(next: { [weak self] new, editedData in
                                            if let controller = self?.controller {
                                                controller.updateCustomPreview(url.path, new.path)
                                            }
                                        })
                                    }
                                })
                            }
                        }, itemImage: MenuAnimation.menu_shared_media.value))
                        
                        if media.videoCover != nil {
                            menu.addItem(ContextMenuItem(Action.remove.string, handler: { [weak self] in
                                if let controller = self?.controller {
                                    controller.updateCustomPreview(url.path, nil)
                                }
                            }, itemImage: MenuAnimation.menu_delete.value))
                        }
                    }
                }
            }

            if canSpoiler {
                menu.addItem(ContextMenuItem(!newValue.isSpoiler ? strings().previewSenderSpoilerTooltipEnable : strings().previewSenderSpoilerTooltipDisable, handler: {
                    updateValue {
                        $0.withUpdatedIsSpoiler(!$0.isSpoiler)
                    }
                }, itemImage: MenuAnimation.menu_send_spoiler.value))
            }
            if state.state == .media, let peer = self.controller?.chatInteraction.peer {
                menu.addItem(ContextMenuItem(newValue.sortValue == .down ? strings().previewSenderMoveTextUp : strings().previewSenderMoveTextDown, handler: {
                    updateValue {
                        $0.withUpdatedSort($0.sort == .down ? .up : .down)
                    }
                }, itemImage: newValue.sortValue == .up ?  MenuAnimation.menu_sort_down.value : MenuAnimation.menu_sort_up.value))
                
                let cachedData = self.controller?.chatInteraction.presentation.cachedData as? CachedChannelData
                
                if peer.isChannel, cachedData?.flags.contains(.paidMediaAllowed) == true {
                    menu.addItem(ContextMenuItem(newValue.payAmount != nil ? strings().previewSenderRemovePaid : strings().previewSenderMakePaid, handler: { [weak self] in
                        self?.controller?.togglePaidContent()
                    }, itemImage: MenuAnimation.menu_paid.value))
                }
            }
            
            if state.state == .media {
                menu.addItem(ContextSeparatorItem())
                menu.addItem(ContextMenuItem(strings().generalSettingsSendLargePhotos, handler: { [weak self] in
                    FastSettings.sendLargePhotos(!FastSettings.sendLargePhotos)
                    if let window = self?.window as? Window {
                        showModalText(for: window, text: FastSettings.sendLargePhotos ? strings().generalSettingsSendLargePhotosTooltipEnabled : strings().generalSettingsSendLargePhotosTooltipDisabled)
                    }
                }, state: FastSettings.sendLargePhotos ? .on : nil, itemImage: MenuAnimation.menu_hd.value))
            }
            
            
            return menu
        }
        
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
                current = InputSwapSuggestionsPanel(inputView: self.textView, textContent: self.textView.scrollView.contentView, relativeView: self, window: context.window, context: context, presentation: self.theme, highlightRect: { [weak self] range, whole in
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
        
        self.canCollage = canCollage
        self.canSpoiler = canSpoiler
        self.options = options
        self.totalCount = count
        
        let title: String
        if self.state.state == .file {
            title = strings().peerMediaTitleSearchFilesCountable(count)
        } else if self.state.state == .archive {
            title = strings().previewSenderTitleArchive
        } else {
            title = strings().peerMediaTitleSearchMediaCountable(count)
        }
        
        let layout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(.text)))
        self.titleView.update(layout)
        
        if let sendPaidMessages = state.sendMessageStars, let controller {
            let messagesCount = count
            let current: StarsSendActionView
            if let view = self.starsSendActionView {
                current = view
            } else {
                current = StarsSendActionView(frame: .zero)
                actionsContainerView.addSubview(current)
                self.starsSendActionView = current
            }
            current.update(price: sendPaidMessages.value * Int64(messagesCount), context: controller.chatInteraction.context, animated: false)
            
            current.setSingle(handler: { [weak self] _ in
                self?.sendButton.send(event: .SingleClick)
            }, for: .Click)
        } else if let view = starsSendActionView {
            performSubviewRemoval(view, animated: false, scale: true)
            self.starsSendActionView = nil
        }
        
        sendButton.isHidden = starsSendActionView != nil
        
        self.separator.isHidden = false
        needsLayout = true
    }
    
    var textWidth: CGFloat {
        let width = frame.width - 14 - actionsContainerView.frame.width
        return width
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        
        if let starsSendActionView {
            starsSendActionView.centerY(x: actionsContainerView.frame.width - starsSendActionView.frame.width - 15)
        }
        
        let send = starsSendActionView ?? sendButton
        
        emojiButton.centerY(x: send.frame.minX - emojiButton.frame.width - 10)
        
        actionsContainerView.setFrameSize(send.frame.width + emojiButton.frame.width + 40, 50)

        transition.updateFrame(view: headerView, frame: CGRect(origin: .zero, size: NSMakeSize(size.width, 50)))

        titleView.resize(size.width - closeButton.frame.width - actions.frame.width - 40)
        
        transition.updateFrame(view: titleView, frame: titleView.centerFrame())
        
        let actionPoint: NSPoint
        
//        switch state.sortValue {
//        case .down:
        actionPoint = NSMakePoint(size.width - actionsContainerView.frame.width + 5, size.height - actionsContainerView.frame.height)
//        case .up:
//            actionPoint = NSMakePoint(size.width - actionsContainerView.frame.width + 5, headerView.frame.maxY)
//        }
        transition.updateFrame(view: actionsContainerView, frame: CGRect(origin: actionPoint, size: actionsContainerView.frame.size))
        
        let (textSize, textHeight) = textViewSize()
        
        let textContainerRect: NSRect
//        switch state.sortValue {
//        case .down:
            textContainerRect = NSMakeRect(0, size.height - textSize.height, size.width, textSize.height)
//        case .up:
//            textContainerRect = NSMakeRect(0, headerView.frame.maxY, size.width, textSize.height)
//        }
        transition.updateFrame(view: textContainerView, frame: textContainerRect)
        
        
        transition.updateFrame(view: textView, frame: CGRect(origin: CGPoint(x: 14, y: 0), size: textSize))
        textView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)

        
        
        let height = size.height - additionHeight
        
        let listHeight = tableView.listHeight
        
        let tableRect: NSRect
        
        tableRect = NSMakeRect(0, headerView.frame.maxY - 6, frame.width, min(height, listHeight))
        
        transition.updateFrame(view: tableView, frame: tableRect)
        transition.updateFrame(view: draggingView, frame: size.bounds)
        
        transition.updateFrame(view: closeButton, frame: closeButton.centerFrameY(x: 10))
        
        transition.updateFrame(view: actions, frame: closeButton.centerFrameY(x: size.width - actions.frame.width - 10))
        
        transition.updateFrame(view: separator, frame: NSMakeRect(0, textContainerView.frame.minY, size.width, .borderSize))
        
        transition.updateFrame(view: forHelperView, frame: NSMakeRect(0, textContainerView.frame.minY, 0, 0))
        
        self.textInputSuggestionsView?.updateRect(transition: transition)
        
        if let messageEffect {
            transition.updateFrame(view: messageEffect, frame: CGRect(origin: NSMakePoint(textContainerView.frame.width - messageEffect.frame.width - 10, textContainerView.frame.height - messageEffect.frame.height - 5), size: messageEffect.frame.size))
        }
        

    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    func updateMessageEffect(_ messageEffect: ChatInterfaceMessageEffect?, interactions: ChatInteraction, animated: Bool) {
        let context = interactions.context
        if let messageEffect {
            if self.messageEffect?.view.animateLayer.fileId != messageEffect.effect.effectSticker.fileId.id {
                if let view = self.messageEffect {
                    performSubviewRemoval(view, animated: animated)
                }
                let current = InputMessageEffectView(account: interactions.context.account, file: messageEffect.effect.effectSticker._parse(), size: NSMakeSize(16, 16))
                current.userInteractionEnabled = true
                current.setFrameOrigin(NSMakePoint(textContainerView.frame.width - current.frame.width - 10, textContainerView.frame.height - current.frame.height - 5))
                
                let showMenu:(Control)->Void = { [weak interactions] control in
                    if let event = NSApp.currentEvent, let interactions = interactions {
                        let sendMenu = interactions.sendMessageMenu(true) |> deliverOnMainQueue
                        _ = sendMenu.startStandalone(next: { menu in
                            if let menu {
                                AppMenu.show(menu: menu, event: event, for: control)
                            }
                        })
                    }
                }

                current.set(handler: { control in
                    showMenu(control)
                }, for: .Down)
                
                current.set(handler: { control in
                    showMenu(control)
                }, for: .LongMouseDown)
                
 
                self.messageEffect = current
                textContainerView.addSubview(current)
                
                if let fromRect = messageEffect.fromRect {
                    let layer = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: messageEffect.effect.effectSticker.fileId.id, file: messageEffect.effect.effectSticker._parse(), emoji: ""), size: current.frame.size)
                    
                    let toRect = current.convert(current.frame.size.bounds, to: nil)
                    
                    let from = fromRect.origin.offsetBy(dx: fromRect.width / 2, dy: fromRect.height / 2)
                    let to = toRect.origin.offsetBy(dx: toRect.width / 2, dy: toRect.height / 2)
                    
                    let completed: (Bool)->Void = { [weak self] _ in
                        DispatchQueue.main.async {
                            if let container = self?.messageEffect {
                                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                                container.isHidden = false
                            }
                        }
                    }
                    current.isHidden = true
                    parabollicReactionAnimation(layer, fromPoint: from, toPoint: to, window: context.window, completion: completed)
                    
                    DispatchQueue.main.async {
                        interactions.update {
                            $0.updatedInterfaceState {
                                $0.withRemovedEffectRect()
                            }
                        }
                    }
                    
                    let messageEffect = messageEffect.effect
                    let file = messageEffect.effectSticker._parse()
                    let signal: Signal<(LottieAnimation, String)?, NoError>
                    
                    let animationSize = NSMakeSize(200, 200)
                                        
                    if let animation = messageEffect.effectAnimation?._parse() {
                        signal = context.account.postbox.mediaBox.resourceData(animation.resource) |> filter { $0.complete } |> take(1) |> map { data in
                            if data.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                return (LottieAnimation(compressed: data, key: .init(key: .bundle("_prem_effect_\(animation.fileId.id)"), size: animationSize, backingScale: Int(System.backingScale), mirror: false), cachePurpose: .temporaryLZ4(.effect), playPolicy: .onceEnd), animation.stickerText ?? "")
                            } else {
                                return nil
                            }
                        }
                    } else {
                        if let effect = messageEffect.effectSticker._parse().premiumEffect {
                            signal = context.account.postbox.mediaBox.resourceData(effect.resource) |> filter { $0.complete } |> take(1) |> map { data in
                                if data.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                    return (LottieAnimation(compressed: data, key: .init(key: .bundle("_prem_effect_\(file.fileId.id)"), size: animationSize, backingScale: Int(System.backingScale), mirror: false), cachePurpose: .temporaryLZ4(.effect), playPolicy: .onceEnd), file.stickerText ?? "")
                                } else {
                                    return nil
                                }
                            }
                        } else {
                            signal = .single(nil)
                        }
                    }
                    _ = (signal |> deliverOnMainQueue).startStandalone(next: { value in
                        
                        if let animation = value?.0 {
                            let player = LottiePlayerView(frame: NSMakeRect(toRect.minX - animationSize.width / 2 - 50, toRect.minY - animationSize.height / 2 + 30, animationSize.width, animationSize.height))

                            animation.triggerOn = (LottiePlayerTriggerFrame.last, { [weak player] in
                                player?.removeFromSuperview()
                            }, {})
                            player.set(animation)
                            context.window.contentView?.addSubview(player)
                        }
                    })
                }
            }
        } else if let view = self.messageEffect {
            performSubviewRemoval(view, animated: animated)
            self.messageEffect = nil
        }
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
    case media(index: Int, sectionId: Int, url: URL, media: Media, isSpoiler: Bool, payAmount: Int64?)
    case mediaGroup(index: Int, sectionId: Int, urls: [URL], messages: [Message], isSpoiler: Bool, payAmount: Int64?)
    case archive(index: Int, sectionId: Int, urls: [URL], media: Media)
    var stableId: PreviewEntryId {
        switch self {
        case let .section(sectionId):
            return .section(sectionId)
        case let .media(_, _, _, media, _, _):
            return .media(media)
        case let .mediaGroup(index, _, _, _, _, _):
            return .mediaGroup(index)
        case .archive:
            return .archive
        }
    }
    
    var index: Int {
        switch self {
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        case let .media(index, sectionId, _, _, _, _):
            return (sectionId * 1000) + index
        case let .mediaGroup(index, sectionId, _, _, _, _):
            return (sectionId * 1000) + index
        case let .archive(index, sectionId, _, _):
            return (sectionId * 1000) + index
        }
    }
    
    func item(arguments: SenderPreviewArguments, state: PreviewState, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .media(_, _, url, media, isSpoiler, payAmount):
            return MediaPreviewRowItem(initialSize, media: media, context: arguments.context, theme: arguments.theme, editedData: state.editedData[url], isSpoiler: isSpoiler, payAmount: payAmount, edit: {
                arguments.edit(url)
            }, paint: {
                arguments.paint(url)
            }, delete: {
                arguments.delete(url)
            })
        case let .archive(_, _, _, media):
            return MediaPreviewRowItem(initialSize, media: media, context: arguments.context, theme: arguments.theme, editedData: nil, isSpoiler: false, payAmount: nil, edit: {
              //  arguments.edit(url)
            }, delete: {
              // arguments.delete(url)
            })
        case let .mediaGroup(_, _, urls, messages, isSpoiler, payAmount):
            return MediaGroupPreviewRowItem(initialSize, messages: messages, urls: urls, editedData: state.editedData, isSpoiler: isSpoiler, payAmount: payAmount, edit: { url in
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
    case let .media(index, sectionId, url, lhsMedia, spoiler, payAmount):
        if case .media(index, sectionId, url, let rhsMedia, spoiler, payAmount) = rhs {
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
    case let .mediaGroup(index, sectionId, url, lhsMessages, spoiler, payAmount):
        if case .mediaGroup(index, sectionId, url, let rhsMessages, spoiler, payAmount) = rhs {
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
                entries.append(.mediaGroup(index: index, sectionId: sectionId, urls: state.urls, messages: collage, isSpoiler: state.currentState.isSpoiler, payAmount: state.currentState.payAmount))
                index += 1
            }
        } else {
            for (i, media) in state.medias.enumerated() {
                entries.append(.media(index: index, sectionId: sectionId, url: state.urls[i], media: media, isSpoiler: state.currentState.isSpoiler, payAmount: state.currentState.payAmount))
                index += 1
            }
        }
    case .file:
        for (i, media) in state.medias.enumerated() {
            entries.append(.media(index: index, sectionId: sectionId, url: state.urls[i], media: media, isSpoiler: false, payAmount: state.currentState.payAmount))
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
        return lhs.container == rhs.container && lhs.isCollage == rhs.isCollage && lhs.customPreview == rhs.customPreview
    }
    let container: MediaSenderContainer
    let index: Int
    let isCollage: Bool
    private(set) var media: Media?
    let customPreview: String?
    init(container: MediaSenderContainer, index: Int, media: Media?, isCollage: Bool, customPreview: String?) {
        self.container = container
        self.index = index
        self.media = media
        self.isCollage = isCollage
        self.customPreview = customPreview
    }
    

    
    var stableId: PreviewMediaId {
        return .container(container)
    }
    
    func withApplyCachedMedia(_ media: Media) -> PreviewMedia {
        return PreviewMedia(container: container, index: index, media: media, isCollage: isCollage, customPreview: customPreview)
    }
    
    func withCustomPreview(_ customPreview: String?) -> PreviewMedia {
        return PreviewMedia(container: container, index: index, media: media, isCollage: isCollage, customPreview: customPreview)
    }
    
    func generateMedia(account: Account, isSecretRelated: Bool, isCollage: Bool, customPreview: String?) -> Media {
        
//        if let media = self.media {
//            return media
//        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var generated: Media!
        
        if let container = container as? ArchiverSenderContainer {
            for url in container.files {
                try? FileManager.default.copyItem(atPath: url.path, toPath: container.path + "/" + url.path.nsstring.lastPathComponent)
            }
        }
        
        _ = Sender.generateMedia(for: container, account: account, isSecretRelated: isSecretRelated, isCollage: isCollage, customPreview: customPreview).start(next: { media, path in
            generated = media
            semaphore.signal()
        })
        semaphore.wait()
        
        self.media = generated
        
        return generated
    }
}


private func previewMedias(containers:[MediaSenderContainer], savedState: [PreviewMedia]?, isCollage: Bool, previews: [String: String]) -> [PreviewMedia] {
    var index: Int = 0
    var result:[PreviewMedia] = []
    for container in containers {
        let found = savedState?.first(where: {$0.stableId == .container(container)})
        result.append(PreviewMedia(container: container, index: index, media: found?.media, isCollage: isCollage, customPreview: previews[container.path]))
        index += 1
    }
    return result
}


private func prepareMedias(left: [PreviewMedia], right: [PreviewMedia], isSecretRelated: Bool, isCollage: Bool, account: Account) -> UpdateTransition<Media> {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { item in
        return item.generateMedia(account: account, isSecretRelated: isSecretRelated, isCollage: isCollage, customPreview: item.customPreview)
    })
    return UpdateTransition(deleted: removed, inserted: inserted, updated: updated)
}

private struct UrlAndState : Equatable {
    let urls:[URL]
    let state: PreviewSendingState
    let previews: [String : String]
    init(_ urls:[URL], _ state: PreviewSendingState, previews: [String : String]) {
        self.urls = urls
        self.state = state
        self.previews = previews
    }
}


class PreviewSenderController: ModalViewController, Notifable {
   
    private var lockInteractiveChanges: Bool = false
    private var _urls:[URL] = []
    
    var getMedias:()->[Media] = { return [] }
    var updateCustomPreview:(String, String?)->Void = { _, _ in }

    fileprivate var previews: [String: String] = [:] {
        didSet {
            self.urlsAndStateValue.set(UrlAndState(_urls, self.genericView.state, previews: self.previews))
        }
    }
    
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
            self.urlsAndStateValue.set(UrlAndState(_urls, self.genericView.state, previews: self.previews))
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
        case .history, .thread, .customChatContents:
            sendCurrentMedia?(silent, atDate, asSpoiler)
        case .pinned:
            break
        case .customLink:
            break
        case .preview:
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
        
        
        let showMenu:(Control)->Void = { [weak self] control in
            if let event = NSApp.currentEvent, let interactions = self?.contextChatInteraction {
                let sendMenu = interactions.sendMessageMenu(false) |> deliverOnMainQueue
                _ = sendMenu.startStandalone(next: { menu in
                    if let menu {
                        AppMenu.show(menu: menu, event: event, for: control)
                    }
                })
            }
        }

        genericView.sendButton.set(handler: { control in
            showMenu(control)
        }, for: .RightDown)
        
        genericView.sendButton.set(handler: { control in
            showMenu(control)
        }, for: .LongMouseDown)
        
        contextChatInteraction.sendMessageMenu = { [weak self] fromEffect in
            guard let self else {
                return .single(nil)
            }
            let presentation = self.chatInteraction.presentation
            let chatInteraction = self.chatInteraction
            let peerId = chatInteraction.peerId
            
            guard let peer = presentation.peer else {
                return .single(nil)
            }
            
            let context = context
            if let slowMode = presentation.slowMode, slowMode.hasLocked {
                return .single(nil)
            }
            if presentation.state != .normal {
                return .single(nil)
            }
            var items:[ContextMenuItem] = []
            
            if peer.id != context.account.peerId, !fromEffect {
                items.append(ContextMenuItem(strings().chatSendWithoutSound, handler: { [weak self] in
                    self?.send(true)
                }, itemImage: MenuAnimation.menu_mute.value))
            }
            switch chatInteraction.mode {
            case .history, .thread:
                if fromEffect {
                    items.append(ContextMenuItem(strings().modalRemove, handler: { [weak self] in
                        self?.contextChatInteraction.update {
                            $0.updatedInterfaceState {
                                $0.withUpdatedMessageEffect(nil)
                            }
                        }
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_clear_history.value))
                } else {
                    if !peer.isSecretChat {
                        let text = peer.id == context.peerId ? strings().chatSendSetReminder : strings().chatSendScheduledMessage
                        items.append(ContextMenuItem(text, handler: { [weak self] in
                            showModal(with: DateSelectorModalController(context: context, mode: .schedule(peer.id), selectedAt: { date in
                                self?.send(false, atDate: date)
                            }), for: context.window)
                        }, itemImage: MenuAnimation.menu_schedule_message.value))
                        
                        if peer.id != context.peerId, presentation.canScheduleWhenOnline {
                            items.append(ContextMenuItem(strings().chatSendSendWhenOnline, handler: { [weak self] in
                                self?.send(false, atDate: scheduleWhenOnlineDate)
                            }, itemImage: MenuAnimation.menu_online.value))
                        }
                        
                        items.append(ContextMenuItem(strings().previewSenderSendAsSpoiler, handler: { [weak self] in
                            self?.send(false, asSpoiler: true)
                        }, itemImage: MenuAnimation.menu_send_spoiler.value))
                        
                        
                    }
                }
                
                
            default:
                break
            }
                                    
            let reactions:Signal<[AvailableMessageEffects.MessageEffect], NoError> = context.diceCache.availableMessageEffects |> map { view in
                return view?.messageEffects ?? []
            } |> deliverOnMainQueue |> take(1)
                        
            return reactions |> map { [weak self] reactions in
                
                let width = ContextAddReactionsListView.width(for: reactions.count, maxCount: 7, allowToAll: true)
                let aboveText: String = strings().chatContextMessageEffectAdd
                
                let w_width = width + 20
                let color = theme.colors.darkGrayText.withAlphaComponent(0.8)
                let link = theme.colors.link.withAlphaComponent(0.8)
                let attributed = parseMarkdownIntoAttributedString(aboveText, attributes: .init(body: .init(font: .normal(.text), textColor: color), bold: .init(font: .medium(.text), textColor: color), link: .init(font: .normal(.text), textColor: link), linkAttribute: { link in
                    return (NSAttributedString.Key.link.rawValue, inAppLink.callback("", { _ in
                        prem(with: PremiumBoardingController(context: context, source: .saved_tags, openFeatures: true), for: context.window)
                    }))
                })).detectBold(with: .medium(.text))
                let aboveLayout = TextViewLayout(attributed, maximumNumberOfLines: 2, alignment: .center)
                aboveLayout.measure(width: w_width - 24)
                aboveLayout.interactions = globalLinkExecutor
                
                let rect = NSMakeRect(0, 0, w_width, 40 + 20 + aboveLayout.layoutSize.height + 4)
                
                let panel = Window(contentRect: rect, styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
                panel._canBecomeMain = false
                panel._canBecomeKey = false
                panel.level = .popUpMenu
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = false
                

                let reveal:((ContextAddReactionsListView & StickerFramesCollector)->Void)?
                
                
                let current = self?.contextChatInteraction.presentation.interfaceState.messageEffect
                
                var selectedItems: [EmojiesSectionRowItem.SelectedItem] = []
                
                if let effect = current {
                    selectedItems.append(.init(source: .custom(effect.effect.effectSticker.fileId.id), type: .transparent))
                }
                
                let update:(Int64, NSRect?)->Void = { fileId, fromRect in
                    let effect = reactions.first(where: {
                        $0.effectSticker.fileId.id == fileId
                    })
                    let current = self?.contextChatInteraction.presentation.interfaceState.messageEffect
                    let value: ChatInterfaceMessageEffect?
                    if let effect, current?.effect != effect {
                        value = ChatInterfaceMessageEffect(effect: effect, fromRect: fromRect)
                    } else {
                        value = nil
                    }
                    self?.contextChatInteraction.update {
                        $0.updatedInterfaceState {
                            $0.withUpdatedMessageEffect(value)
                        }
                    }
                }
                
                reveal = { view in
                    let window = ReactionsWindowController(context, peerId: peerId, selectedItems: selectedItems, react: { sticker, fromRect in
                        update(sticker.file.fileId.id, fromRect)
                    }, moveTop: true, mode: .messageEffects)
                    window.show(view)
                }
                
                let available: [ContextReaction] = Array(reactions.map { value in
                    return .custom(value: .custom(value.effectSticker.fileId.id), fileId: value.effectSticker.fileId.id, value.effectSticker._parse(), isSelected: current?.effect.effectSticker.fileId.id == value.effectSticker.fileId.id)
                }.prefix(7))
                
                let view = ContextAddReactionsListView(frame: rect, context: context, list: available, add: { value, checkPrem, fromRect in
                    switch value {
                    case let .custom(fileId):
                        update(fileId, fromRect)
                    default:
                        break
                    }
                }, radiusLayer: nil, revealReactions: reveal, aboveText: aboveLayout)
                
                
                panel.contentView?.addSubview(view)
                panel.contentView?.wantsLayer = true
                view.autoresizingMask = [.width, .height]
                
                let menu = ContextMenu(bottomAnchor: true)
                if peer.isUser, peer.id != context.peerId {
                    menu.topWindow = panel
                }
                
                for item in items {
                    menu.addItem(item)
                }
                return menu
            }
        }

        
        
        
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
            let messageEffect = chatInteraction.presentation.interfaceState.messageEffect
            
            self.temporaryInputState = input
            
            self.contextChatInteraction.update {
                $0.updatedInterfaceState {
                    $0.withUpdatedMessageEffect(messageEffect)
                }
            }
            
            genericView.textView.set(input)
            self.genericView.updateMessageEffect(messageEffect, interactions: contextChatInteraction, animated: false)
            
            chatInteraction.update({
                $0.updatedInterfaceState({
                    $0.withUpdatedInputState(ChatTextInputState()).withUpdatedMessageEffect(nil)
                })
            })
        }
        
        let interactions = EntertainmentInteractions(.emoji, peerId: chatInteraction.peerId)
        
        interactions.sendEmoji = { [weak self] emoji, fromRect in
            _ = self?.contextChatInteraction.appendText(.initialize(string: emoji))
            _ = self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        }
        interactions.sendAnimatedEmoji = { [weak self] sticker, _, _, _, fromRect in
            let text = (sticker.file._parse().customEmojiText ?? sticker.file._parse().stickerText ?? clown).fixed
            _ = self?.contextChatInteraction.appendText(.makeAnimated(sticker.file._parse(), text: text))
            _ = self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        }
        
        emoji.update(with: interactions, chatInteraction: contextChatInteraction)
        
        let actionsDisposable = DisposableSet()
        self.disposable.set(actionsDisposable)
        
        
        let initialState = PreviewState(urls: [], medias: [], currentState: .init(state: .media, isCollage: true, isSpoiler: false, sort: .down, payAmount: nil, sendMessageStars: chatInteraction.presentation.sendPaidMessageStars), editedData: [:])
        
        let statePromise:ValuePromise<PreviewState> = ValuePromise(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((PreviewState) -> PreviewState) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        self.getMedias = {
            return stateValue.with { $0.medias }
        }
        
        self.updateCustomPreview = { [weak self] path, preview in
            if let preview {
                self?.previews[path] = preview
            } else {
                self?.previews.removeValue(forKey: path)
            }
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
            
            return (previewMedias(containers: containers, savedState: savedStateMedias.with { $0[state]}, isCollage: state.isCollage, previews: urlsAndState.previews), urls, state)
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
            canSpoiler = options.contains(.media) && state.state == .media && !isSecretChat && state.payAmount == nil

            
            self.genericView.applyOptions(options, count: self.urls.count, canCollage: canCollage, canSpoiler: canSpoiler)
            
            CATransaction.begin()
            self.genericView.tableView.merge(with: transition)
            self.genericView.tableView.reloadHeight()
            CATransaction.commit()
            
            self.genericView.textView.placeholder = self.inputPlaceholder
            
            

            if medias.isEmpty {
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
        var state: PreviewSendingState = .init(state: mediaState, isCollage: canCollage, isSpoiler: false, sort: .down, payAmount: nil, sendMessageStars: chatInteraction.presentation.sendPaidMessageStars)
        if let _ = chatInteraction.presentation.slowMode {
            if state.state != .archive && self.urls.count > 1, !state.isCollage {
                state = .init(state: .archive, isCollage: false, isSpoiler: false, sort: .down, payAmount: nil, sendMessageStars: chatInteraction.presentation.sendPaidMessageStars)
            }
        }
        
        self.genericView.state = state
        self.urlsAndStateValue.set(UrlAndState(self.urls, state, previews: self.previews))
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
            self.urlsAndStateValue.set(UrlAndState(self.urls, state, previews: self.previews))
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
                if additionalMessage != nil, let text = permissionText(from: peer, for: .banSendText, cachedData: chatInteraction.presentation.cachedData) {
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
                    if let totalBoostNeed = chatInteraction.presentation.totalBoostNeed {
                        if totalBoostNeed > 0 {
                            verifyAlert(for: context.window, information: strings().boostGroupChatInputSendMedia, ok: strings().boostGroupChatInputBoost, successHandler: { [weak self] _ in
                                self?.chatInteraction.boostToUnrestrict(.unblockText(totalBoostNeed))
                            })
                            return
                        }
                    } else {
                        showModalText(for: context.window, text: first.0)
                        return
                    }
                }
                
              
                
                let amount = state.payAmount
                
                let makeMedia:([Media], Bool)->[Media] = { media, collage in
                    if let amount {
                        if collage {
                            return [TelegramMediaPaidContent(amount: amount, extendedMedia: media.map { .full(media: $0) })]
                        } else {
                            return media.map {
                                return TelegramMediaPaidContent(amount: amount, extendedMedia: [.full(media: $0)])
                            }
                        }
                    } else {
                        return media
                    }
                }
                
                let effect = self.contextChatInteraction.presentation.messageEffect
                
                let invoke:()->Void = { [weak self] in
                    guard let self, let window = self.window else {
                        return
                    }
                    
                    
                    self.chatInteraction.sendMessage(silent, atDate, effect)
                    if state.isCollage && medias.count > 1 {
                        let collages = medias.chunks(10)
                        for collage in collages {
                            self.chatInteraction.sendMedias(makeMedia(collage, true), input, state.isCollage && state.payAmount == nil, additionalMessage, silent, atDate, asSpoiler ?? state.isSpoiler, effect, state.sortValue == .up)
                            additionalMessage = nil
                        }
                    } else {
                        self.chatInteraction.sendMedias(makeMedia(medias, false), input, false, additionalMessage, silent, atDate, asSpoiler ?? state.isSpoiler, effect, state.sortValue == .up)
                    }
                    
                    self.sent = true
                    self.emoji.popover?.hide()
                    self.closeModal()
                }
                
                let presentation = self.chatInteraction.presentation
                
                let messagesCount = medias.count + (additionalMessage != nil ? 1 : 0)
                
                if messagesCount > 0, let payStars = presentation.sendPaidMessageStars, let peer = presentation.peer, let starsState = presentation.starsState {
                    let starsPrice = Int(payStars.value * Int64(messagesCount))
                    let amount = strings().starListItemCountCountable(starsPrice)
                    
                    if !presentation.alwaysPaidMessage {
                        
                        let messageCountText = strings().chatPayStarsConfirmMediasCountable(messagesCount)
                        
                        verifyAlert(for: chatInteraction.context.window, header: strings().chatPayStarsConfirmTitle, information: strings().chatPayStarsConfirmText(peer.displayTitle, amount, amount, messageCountText), ok: strings().chatPayStarsConfirmPayMediaCountable(messagesCount), option: strings().chatPayStarsConfirmCheckbox, optionIsSelected: false, successHandler: { result in
                            
                            if starsState.balance.value > starsPrice {
                                self.chatInteraction.update({ current in
                                    return current
                                        .withUpdatedAlwaysPaidMessage(result == .thrid)
                                })
                                invoke()
                            } else {
                                showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                            }
                        })
                    } else {
                        if starsState.balance.value > starsPrice {
                            invoke()
                        } else {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                        }
                    }
                } else {
                    invoke()
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
        
        self.context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.textView.inputApplyTransform(.attribute(TextInputAttributes.quote))
            return .invoked
        }, with: self, for: .I, priority: .high, modifierFlags: [.shift, .command])

        
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
                view.updateMouse(animated: true)
                return true
            })
            
            return .invokeNext
        }, with: self, for: .mouseMoved, priority: .high)
        
        genericView.tableView.needUpdateVisibleAfterScroll = true
    }
    
    func runDrawer() {
        self.runEditor?(self.urls[0], false)
    }
    
    func togglePaidContent() {
        if self.genericView.state.payAmount == nil {
            showModal(with: MediaPaidSetterController(context: context, callback: { [weak self] amount in
                guard let self else {
                    return
                }
                let state = self.genericView.state.withUpdatedPayAmount(amount).withUpdatedIsSpoiler(false)
                self.genericView.stateValueInteractiveUpdate?(state)
            }), for: context.window)
        } else {
            let state = self.genericView.state.withUpdatedPayAmount(nil).withUpdatedIsSpoiler(false)
            self.genericView.stateValueInteractiveUpdate?(state)
        }
        
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
        if !sent {
            chatInteraction.update({
                $0.updatedInterfaceState({ state in
                    var state = state
                    if let temp = temporaryInputState {
                        state = state.withUpdatedInputState(temp)
                    }
                    state = state.withUpdatedMessageEffect(self.contextChatInteraction.presentation.interfaceState.messageEffect)
                    return state
                })
            })
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
                if value.interfaceState.messageEffect != oldValue.interfaceState.messageEffect {
                    self.genericView.updateMessageEffect(value.interfaceState.messageEffect, interactions: contextChatInteraction, animated: animated)
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
        
    
        let pasteRtf:()->Bool = { [weak self] in
            guard let `self` = self else {
                return false
            }
            if let data = pasteboard.data(forType: .kInApp) {
                let decoder = AdaptedPostboxDecoder()
                if let decoded = try? decoder.decode(ChatTextInputState.self, from: data) {
                    let state = decoded.unique(isPremium: self.contextChatInteraction.context.isPremium)
                    self.contextChatInteraction.appendText(state.attributedString())
                    return true
                }
            } else if let data = pasteboard.data(forType: .rtfd) ?? pasteboard.data(forType: .rtf) {
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
                    return true
                }
            }
            return false
        }
        
        if !result {
            self.pasteDisposable.set(InputPasteboardParser.getPasteboardUrls(pasteboard, context: context).start(next: { [weak self] urls in
                self?.insertAdditionUrls?(urls)
                
                if urls.isEmpty {
                    _ = pasteRtf()
                }
            }))
        } else {
            if pasteRtf() {
                return true
            }
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
