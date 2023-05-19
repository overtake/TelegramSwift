//
//  ChatHeaderController.swift
//  TelegramMac
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

import Postbox
import TGModernGrowingTextView




protocol ChatHeaderProtocol {
    func update(with state: ChatHeaderState, animated: Bool)
}




enum ChatHeaderState : Identifiable, Equatable {
    case none(ChatActiveGroupCallInfo?)
    case search(ChatActiveGroupCallInfo?, ChatSearchInteractions, Peer?, String?)
    case addContact(ChatActiveGroupCallInfo?, block: Bool, autoArchived: Bool)
    case requestChat(ChatActiveGroupCallInfo?, String, String)
    case shareInfo(ChatActiveGroupCallInfo?)
    case pinned(ChatActiveGroupCallInfo?, ChatPinnedMessage, doNotChangeTable: Bool)
    case report(ChatActiveGroupCallInfo?, autoArchived: Bool, status: PeerEmojiStatus?)
    case promo(ChatActiveGroupCallInfo?, EngineChatList.AdditionalItem.PromoInfo.Content)
    case pendingRequests(ChatActiveGroupCallInfo?, Int, [PeerInvitationImportersState.Importer])
    case restartTopic(ChatActiveGroupCallInfo?)
    var stableId:Int {
        switch self {
        case .none:
            return 0
        case .search:
            return 1
        case .report:
            return 2
        case .addContact:
            return 3
        case .pinned:
            return 4
        case .promo:
            return 5
        case .shareInfo:
            return 6
        case .pendingRequests:
            return 7
        case .requestChat:
            return 8
        case .restartTopic:
            return 9
        }
    }

    var voiceChat: ChatActiveGroupCallInfo? {
        switch self {
        case let .none(voiceChat):
            return voiceChat
        case let .search(voiceChat, _, _, _):
            return voiceChat
        case let .report(voiceChat, _, _):
            return voiceChat
        case let .addContact(voiceChat, _, _):
            return voiceChat
        case let .pinned(voiceChat, _, _):
            return voiceChat
        case let .promo(voiceChat, _):
            return voiceChat
        case let .shareInfo(voiceChat):
            return voiceChat
        case let .pendingRequests(voiceChat, _, _):
            return voiceChat
        case let .requestChat(voiceChat, _, _):
            return voiceChat
        case let .restartTopic(voiceChat):
            return voiceChat
        }
    }
    
    var primaryClass: AnyClass? {
        switch self {
        case .addContact:
            return AddContactView.self
        case .shareInfo:
            return ShareInfoView.self
        case .pinned:
            return ChatPinnedView.self
        case .search:
            return ChatSearchHeader.self
        case .report:
            return ChatReportView.self
        case .promo:
            return ChatSponsoredView.self
        case .pendingRequests:
            return ChatPendingRequests.self
        case .requestChat:
            return ChatRequestChat.self
        case .restartTopic:
            return ChatRestartTopic.self
        case .none:
            return nil
        }
    }
    var secondaryClass: AnyClass? {
        if let _ = voiceChat {
            return ChatGroupCallView.self
        }
        return nil
    }
    
    var height:CGFloat {
        return primaryHeight + secondaryHeight
    }

    var primaryHeight:CGFloat {
        var height: CGFloat = 0
        switch self {
        case .none:
            height += 0
        case .search:
            height += 44
        case let .report(_, _, status):
            if let _ = status {
                height += 30
            }
            height += 44
        case .addContact:
            height += 44
        case .shareInfo:
            height += 44
        case .pinned:
            height += 44
        case .promo:
            height += 44
        case .pendingRequests:
            height += 44
        case .requestChat:
            height += 44
        case .restartTopic:
            height += 44
        }
        return height
    }

    var secondaryHeight:CGFloat {
        var height: CGFloat = 0
        if let _ = voiceChat {
            height += 44
        }
        return height
    }
    
    var toleranceHeight: CGFloat {
        switch self {
        case let .pinned(_, _, doNotChangeTable):
            return doNotChangeTable ? height - primaryHeight : height
        default:
            return height
        }
    }
    
    static func ==(lhs:ChatHeaderState, rhs: ChatHeaderState) -> Bool {
        switch lhs {
        case let .pinned(call, pinnedId, value):
            if case .pinned(call, pinnedId, value) = rhs {
                return true
            } else {
                return false
            }
        case let .addContact(call, block, autoArchive):
            if case .addContact(call, block, autoArchive) = rhs {
                return true
            } else {
                return false
            }
        default:
            return lhs.stableId == rhs.stableId && lhs.voiceChat == rhs.voiceChat
        }
    }
}


class ChatHeaderController {
    
    
    private var _headerState:ChatHeaderState = .none(nil)
    private let chatInteraction:ChatInteraction
    
    private(set) var currentView:View?

    private var primaryView: View?
    private var seconderyView : View?

    var state:ChatHeaderState {
        return _headerState
    }
    
    func updateState(_ state:ChatHeaderState, animated:Bool, for view:View) -> Void {
        if _headerState != state {
            _headerState = state

            let (primary, secondary) = viewIfNecessary(primarySize: NSMakeSize(view.frame.width, state.primaryHeight), secondarySize: NSMakeSize(view.frame.width, state.secondaryHeight), animated: animated, p_v: self.primaryView, s_v: self.seconderyView)

            let previousPrimary = self.primaryView
            let previousSecondary = self.seconderyView

            self.primaryView = primary
            self.seconderyView = secondary

            var removed: [View] = []
            var added:[(View, NSPoint, NSPoint, View?)] = []
            var updated:[(View, NSPoint, View?)] = []

            if previousSecondary == nil || previousSecondary != secondary {
                if let previousSecondary = previousSecondary {
                    removed.append(previousSecondary)
                }
                if let secondary = secondary {
                    added.append((secondary, NSMakePoint(0, -state.secondaryHeight), NSMakePoint(0, 0), nil))
                }
            }
            if previousPrimary == nil || previousPrimary != primary {
                if let previousPrimary = previousPrimary {
                    removed.append(previousPrimary)
                }
                if let primary = primary {
                    added.append((primary, NSMakePoint(0, -(state.height - state.secondaryHeight)), NSMakePoint(0, state.secondaryHeight), secondary))
                }
            }

            if (previousSecondary == nil && secondary != nil) || previousSecondary != nil && secondary == nil {
                if let primary = primary, previousPrimary == primary {
                    updated.append((primary, NSMakePoint(0, state.secondaryHeight), secondary))
                }
            }
            if (previousPrimary == nil && primary != nil) || previousPrimary != nil && primary == nil {
                if let secondary = secondary, previousSecondary == secondary {
                    updated.append((secondary, NSMakePoint(0, 0), nil))
                }
            }

            if !added.isEmpty || primary != nil  || secondary != nil {
                let current: View
                if let view = currentView {
                    current = view
                    current.change(size: NSMakeSize(view.frame.width, state.height), animated: animated)
                } else {
                    current = View(frame: NSMakeRect(0, 0, view.frame.width, state.height))
                    current.autoresizingMask = [.width]
                    current.autoresizesSubviews = true
                    view.addSubview(current)
                    self.currentView = current
                }
                for view in removed {
                    if animated {
//                        view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
//                            view?.removeFromSuperview()
//                        })
                        view.layer?.animatePosition(from: view.frame.origin, to: NSMakePoint(0, view.frame.minY - view.frame.height), removeOnCompletion: false, completion: { [weak view] _ in
                            view?.removeFromSuperview()
                        })
                    } else {
                        view.removeFromSuperview()
                    }
                }
                for (view, from, to, below) in added {
                    current.addSubview(view, positioned: .below, relativeTo: below)
                    view.setFrameOrigin(to)
                    
                    if animated {
                        view.layer?.animatePosition(from: from, to: to, duration: 0.2)
                      //  view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                for (view, point, above) in updated {
                    current.addSubview(view, positioned: .below, relativeTo: above)
                    view.change(pos: point, animated: animated)
                }
            } else {
                if let currentView = currentView {
                    self.currentView = nil
                    if animated {
                        currentView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false)
                        currentView.layer?.animatePosition(from: currentView.frame.origin, to: currentView.frame.origin - NSMakePoint(0, currentView.frame.height), removeOnCompletion:false, completion: { [weak currentView] _ in
                            currentView?.removeFromSuperview()
                        })
                    } else {
                        currentView.removeFromSuperview()
                    }
                }
            }
            

        }
    }

    func applySearchResponder() {
         (primaryView as? ChatSearchHeader)?.applySearchResponder(true)
    }
    
    private func viewIfNecessary(primarySize: NSSize, secondarySize: NSSize, animated: Bool, p_v: View?, s_v: View?) -> (primary: View?, secondary: View?) {
        let primary:View?
        let secondary:View?
        let primaryRect: NSRect = .init(origin: .zero, size: primarySize)
        let secondaryRect: NSRect = .init(origin: .zero, size: secondarySize)
        if p_v == nil || p_v?.className != NSStringFromClass(_headerState.primaryClass ?? NSView.self)  {
            switch _headerState {
            case .addContact:
                primary = AddContactView(chatInteraction, state: _headerState, frame: primaryRect)
            case .shareInfo:
                primary = ShareInfoView(chatInteraction, state: _headerState, frame: primaryRect)
            case .pinned:
                primary = ChatPinnedView(chatInteraction, state: _headerState, frame: primaryRect)
            case .search:
                primary = ChatSearchHeader(chatInteraction, state: _headerState, frame: primaryRect)
            case .report:
                primary = ChatReportView(chatInteraction, state: _headerState, frame: primaryRect)
            case .promo:
                primary = ChatSponsoredView(chatInteraction, state: _headerState, frame: primaryRect)
            case .pendingRequests:
                primary = ChatPendingRequests(context: chatInteraction.context, openAction: chatInteraction.openPendingRequests, dismissAction: chatInteraction.dismissPendingRequests, state: _headerState, frame: primaryRect)
            case .requestChat:
                primary = ChatRequestChat(chatInteraction, state: _headerState, frame: primaryRect)
            case .restartTopic:
                primary = ChatRestartTopic(chatInteraction, state: _headerState, frame: primaryRect)
            case .none:
                primary = nil
            }
            primary?.autoresizingMask = [.width]
        } else {
            primary = p_v
            (primary as? ChatHeaderProtocol)?.update(with: _headerState, animated: animated)
        }
        if let _ = self._headerState.voiceChat {
            if s_v == nil || s_v?.className != NSStringFromClass(_headerState.secondaryClass ?? NSView.self) {
                secondary = ChatGroupCallView(chatInteraction.joinGroupCall, context: chatInteraction.context, state: _headerState, frame: secondaryRect)
                secondary?.autoresizingMask = [.width]
            } else {
                secondary = s_v
                (secondary as? ChatHeaderProtocol)?.update(with: _headerState, animated: animated)
            }
        } else {
            secondary = nil
        }

        primary?.setFrameSize(primarySize)
        secondary?.setFrameSize(secondarySize)
        return (primary: primary, secondary: secondary)
    }
    
    init(_ chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
    }
    
}

struct ChatSearchInteractions {
    let jump:(Message)->Void
    let results:(String)->Void
    let calendarAction:(Date)->Void
    let cancel:()->Void
    let searchRequest:(String, PeerId?, SearchMessagesState?) -> Signal<([Message], SearchMessagesState?), NoError>
}

private class ChatSponsoredModel: ChatAccessoryModel {
    

    init(context: AccountContext, title: String, text: String) {
        super.init(context: context)
        update(title: title, text: text)
    }
    
    func update(title: String, text: String) {
        //strings().chatProxySponsoredCapTitle
        self.header = .init(.initialize(string: title, color: theme.colors.link, font: .medium(.text)), maximumNumberOfLines: 1)
        self.message = .init(.initialize(string: text, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
}

private extension EngineChatList.AdditionalItem.PromoInfo.Content {
    var title: String {
        switch self {
        case .proxy:
            return strings().chatProxySponsoredCapTitle
        case .psa:
            return strings().psaChatTitle
        }
    }
    var text: String {
        switch self {
        case .proxy:
            return strings().chatProxySponsoredCapDesc
        case let .psa(type, _):
            return localizedPsa("psa.chat.text", type: type)
        }
    }
    var learnMore: String? {
        switch self {
        case .proxy:
            return nil
        case let .psa(type, _):
            let localized = localizedPsa("psa.chat.alert.learnmore", type: type)
            return localized != localized ? localized : nil
        }
    }
}



private final class ChatSponsoredView : Control, ChatHeaderProtocol {
    private let chatInteraction:ChatInteraction
    private let container:ChatAccessoryView = ChatAccessoryView()
    private let dismiss:ImageButton = ImageButton()
    private var node: ChatSponsoredModel?
    private var kind: EngineChatList.AdditionalItem.PromoInfo.Content?
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        super.init(frame: frame)
        
        dismiss.disableActions()
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = self.dismiss.sizeToFit()
        
        self.set(handler: { [weak self] _ in
            guard let chatInteraction = self?.chatInteraction, let kind = self?.kind else {
                return
            }
            switch kind {
            case .proxy:
                confirm(for: chatInteraction.context.window, header: strings().chatProxySponsoredAlertHeader, information: strings().chatProxySponsoredAlertText, cancelTitle: "", thridTitle: strings().chatProxySponsoredAlertSettings, successHandler: { [weak chatInteraction] result in
                    switch result {
                    case .thrid:
                        chatInteraction?.openProxySettings()
                    default:
                        break
                    }
                })
            case .psa:
                if let learnMore = kind.learnMore {
                    confirm(for: chatInteraction.context.window, header: kind.title, information: kind.text, cancelTitle: "", thridTitle: learnMore, successHandler: { result in
                        switch result {
                        case .thrid:
                            execute(inapp: .external(link: learnMore, false))
                        default:
                            break
                        }
                    })
                }
                
            }
            
            
        }, for: .Click)
        
        dismiss.set(handler: { _ in
            FastSettings.removePromoTitle(for: chatInteraction.peerId)
            chatInteraction.update({$0.withoutInitialAction()})
        }, for: .SingleClick)

        addSubview(dismiss)
        container.userInteractionEnabled = false
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        addSubview(container)

        update(with: state, animated: false)

    }

    func update(with state: ChatHeaderState, animated: Bool) {
        switch state {
        case let  .promo(_, kind):
            self.kind = kind
        default:
            self.kind = nil
        }
        if let kind = kind {
            node = ChatSponsoredModel(context: self.chatInteraction.context, title: kind.title, text: kind.text)
            node?.view = container
        }

        updateLocalizationAndTheme(theme: theme)
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.backgroundColor = theme.colors.background
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        container.backgroundColor = theme.colors.background
        if let kind = kind {
            node?.update(title: kind.title, text: kind.text)
        }
    }
    
    override func layout() {
        if let node = node {
            node.measureSize(frame.width - 70)
            container.setFrameSize(frame.width - 70, node.size.height)
        }
        container.centerY(x: 20)
        dismiss.centerY(x: frame.width - 20 - dismiss.frame.width)
        node?.setNeedDisplay()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class ChatPinnedView : Control, ChatHeaderProtocol {
    private var node:ReplyModel?
    private let chatInteraction:ChatInteraction
    private let readyDisposable = MetaDisposable()
    private var container:ChatAccessoryView = ChatAccessoryView()
    private let dismiss:ImageButton = ImageButton()
    private let loadMessageDisposable = MetaDisposable()
    private var pinnedMessage: ChatPinnedMessage?
    
    private var inlineButton: TitleButton? = nil
    
    private let particleList: VerticalParticleListControl = VerticalParticleListControl()
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {

        self.chatInteraction = chatInteraction
        super.init(frame: frame)
        
        dismiss.disableActions()
        self.contextMenu = { [weak self] in
            guard let pinnedMessage = self?.pinnedMessage else {
                return nil
            }
            let menu = ContextMenu()
            menu.addItem(ContextMenuItem(strings().chatContextPinnedHide, handler: {
                self?.chatInteraction.updatePinned(pinnedMessage.messageId, true, false, false)
            }, itemImage: MenuAnimation.menu_unpin.value))

            return menu
        }

        self.set(handler: { [weak self] _ in
            guard let `self` = self, let pinnedMessage = self.pinnedMessage else {
                return
            }
            if self.chatInteraction.mode.threadId == pinnedMessage.messageId {
                self.chatInteraction.scrollToTheFirst()
            } else {
                self.chatInteraction.focusPinnedMessageId(pinnedMessage.messageId)
            }
            
        }, for: .Click)
        
        dismiss.set(handler: { [weak self] _ in
            guard let `self` = self, let pinnedMessage = self.pinnedMessage else {
                return
            }
            if pinnedMessage.totalCount > 1 {
                self.chatInteraction.openPinnedMessages(pinnedMessage.messageId)
            } else {
                self.chatInteraction.updatePinned(pinnedMessage.messageId, true, false, false)
            }
        }, for: .SingleClick)
        
        addSubview(dismiss)
        container.userInteractionEnabled = false
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        addSubview(container)

        
        particleList.frame = NSMakeRect(22, 5, 2, 34)
        
        addSubview(particleList)

        update(with: state, animated: false)
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        switch state {
        case let .pinned(_, message, _):
            self.update(message, animated: animated)
        default:
            break
        }
    }
    
    private func update(_ pinnedMessage: ChatPinnedMessage, animated: Bool) {
        
        let animated = animated && (self.pinnedMessage != nil && (!pinnedMessage.isLatest || (self.pinnedMessage?.isLatest != pinnedMessage.isLatest)))
        
        particleList.update(count: pinnedMessage.totalCount, selectedIndex: pinnedMessage.index, animated: animated)
        
        self.dismiss.set(image: pinnedMessage.totalCount <= 1 ? theme.icons.dismissPinned : theme.icons.chat_pinned_list, for: .Normal)
        
        if pinnedMessage.messageId != self.pinnedMessage?.messageId {
            let oldContainer = self.container
            let newContainer = ChatAccessoryView()
            newContainer.userInteractionEnabled = false
            
            let newNode = ReplyModel(replyMessageId: pinnedMessage.messageId, context: chatInteraction.context, replyMessage: pinnedMessage.message, isPinned: true, headerAsName: chatInteraction.mode.threadId != nil, customHeader: pinnedMessage.isLatest ? nil : pinnedMessage.totalCount == 2 ? strings().chatHeaderPinnedPrevious : strings().chatHeaderPinnedMessageNumer(pinnedMessage.totalCount - pinnedMessage.index), drawLine: false)
            
            newNode.view = newContainer
            
            addSubview(newContainer)
            
            let width = frame.width - (40 + (dismiss.isHidden ? 0 : 30))
            newNode.measureSize(width)
            newContainer.setFrameSize(width, newNode.size.height)
            newContainer.centerY(x: 24)
            
            if animated {
                let oldFrom = oldContainer.frame.origin
                let oldTo = pinnedMessage.messageId > self.pinnedMessage!.messageId ? NSMakePoint(oldContainer.frame.minX, -oldContainer.frame.height) : NSMakePoint(oldContainer.frame.minX, frame.height)
                
                
                oldContainer.layer?.animatePosition(from: oldFrom, to: oldTo, duration: 0.2, timingFunction: .easeInEaseOut, removeOnCompletion: false, completion: { [weak oldContainer] _ in
                    oldContainer?.removeFromSuperview()
                })
                oldContainer.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, timingFunction: .easeInEaseOut, removeOnCompletion: false)
                
                
                let newTo = newContainer.frame.origin
                let newFrom = pinnedMessage.messageId < self.pinnedMessage!.messageId ? NSMakePoint(newContainer.frame.minX, -newContainer.frame.height) : NSMakePoint(newContainer.frame.minX, frame.height)
                
                
                newContainer.layer?.animatePosition(from: newFrom, to: newTo, duration: 0.2, timingFunction: .easeInEaseOut)
                newContainer.layer?.animateAlpha(from: 0, to: 1, duration: 0.2
                    , timingFunction: .easeInEaseOut)
            } else {
                oldContainer.removeFromSuperview()
            }
            
            if let message = pinnedMessage.message, let replyMarkup = pinnedMessage.message?.replyMarkup, replyMarkup.hasButtons, replyMarkup.rows.count == 1, replyMarkup.rows[0].buttons.count == 1 {
                self.installReplyMarkup(replyMarkup.rows[0].buttons[0], message: message, animated: animated)
            } else {
                self.deinstallReplyMarkup(animated: animated)
            }
            
            self.container = newContainer
            self.node = newNode
        }
        self.pinnedMessage = pinnedMessage

        updateLocalizationAndTheme(theme: theme)
    }
    
    private func installReplyMarkup(_ button: ReplyMarkupButton, message: Message, animated: Bool) {
        self.dismiss.isHidden = true
        let current: TitleButton
        if let view = self.inlineButton {
            current = view
        } else {
            current = TitleButton()
            current.autohighlight = false
            current.scaleOnClick = true
            
            
            
            if animated {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            self.inlineButton = current
        }
        current.removeAllHandlers()
        current.set(handler: { [weak self] _ in
            self?.chatInteraction.processBotKeyboard(with: message).proccess(button, { _ in
                
            })
        }, for: .Click)
        
        addSubview(current)

        
        current.set(text: button.title, for: .Normal)
        current.set(font: .medium(.text), for: .Normal)
        current.set(color: theme.colors.underSelectedColor, for: .Normal)
        current.set(background: theme.colors.accent, for: .Normal)
        current.sizeToFit(NSMakeSize(6, 8), .zero, thatFit: false)
        current.layer?.cornerRadius = current.frame.height / 2
    }
    private func deinstallReplyMarkup(animated: Bool) {
        self.dismiss.isHidden = false
        if let view = self.inlineButton {
            performSubviewRemoval(view, animated: animated)
            self.inlineButton = nil
        }
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        node?.update()
        self.backgroundColor = theme.colors.background
        if let pinnedMessage = pinnedMessage {
            self.dismiss.set(image: pinnedMessage.totalCount <= 1 ? theme.icons.dismissPinned : theme.icons.chat_pinned_list, for: .Normal)
        }
        self.dismiss.sizeToFit()
        container.backgroundColor = theme.colors.background
        
        if let current = inlineButton {
            current.set(color: theme.colors.underSelectedColor, for: .Normal)
            current.set(background: theme.colors.accent, for: .Normal)
        }
        
        needsLayout = true
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
 
    override func layout() {
        if let node = node {
            if let view = inlineButton {
                node.measureSize(frame.width - (40 + view.frame.width))
            } else {
                node.measureSize(frame.width - (40 + (dismiss.isHidden ? 0 : 30)))
            }
            container.setFrameSize(frame.width - (40 + (dismiss.isHidden ? 0 : 30)), node.size.height)
        }
        container.centerY(x: 24)
        dismiss.centerY(x: frame.width - 20 - dismiss.frame.width)
        
        if let view = inlineButton {
            view.centerY(x: frame.width - 20 - view.frame.width)
        }
        node?.setNeedDisplay()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    deinit {
        readyDisposable.dispose()
        loadMessageDisposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class ChatReportView : Control, ChatHeaderProtocol {
    private let chatInteraction:ChatInteraction
    private let report:TitleButton = TitleButton()
    private let unarchiveButton = TitleButton()
    private let dismiss:ImageButton = ImageButton()

    private var statusLayer: InlineStickerView?
    
    private let buttonsContainer = View()
    
    private var textView: TextView?
    
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        super.init(frame: frame)
        dismiss.disableActions()
        
        
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        
        report.set(text: strings().chatHeaderReportSpam, for: .Normal)
        _ = report.sizeToFit()
        
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = self.dismiss.sizeToFit()
        
        report.set(handler: { _ in
            chatInteraction.blockContact()
        }, for: .SingleClick)
        
        dismiss.set(handler: { _ in
            chatInteraction.dismissPeerStatusOptions()
        }, for: .SingleClick)
        
        unarchiveButton.set(handler: { _ in
            chatInteraction.unarchive()
        }, for: .SingleClick)
        

        addSubview(buttonsContainer)
        
        addSubview(dismiss)
        update(with: state, animated: false)
    }


    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        report.set(text: strings().chatHeaderReportSpam, for: .Normal)
        report.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.redUI, backgroundColor: theme.colors.background, highlightColor: theme.colors.accentSelect)
        _ = report.sizeToFit()
        
        unarchiveButton.set(text: strings().peerInfoUnarchive, for: .Normal)
        
        unarchiveButton.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background, highlightColor: theme.colors.accentSelect)
        
        self.backgroundColor = theme.colors.background
        needsLayout = true
    }


    func update(with state: ChatHeaderState, animated: Bool) {
        buttonsContainer.removeAllSubviews()
        switch state {
        case let .report(_, autoArchived, status):
            buttonsContainer.addSubview(report)
            if autoArchived {
                buttonsContainer.addSubview(unarchiveButton)
            }
            
            
            let context = chatInteraction.context
            let peerId = chatInteraction.peerId
            
            if let status = status {
                let current: TextView
                if let view = self.textView {
                    current = view
                } else {
                    current = TextView()
                    current.isSelectable = false
                    self.textView = current
                    addSubview(current)
                }
                let text = strings().customStatusReportSpam
                let attr: NSMutableAttributedString
                
                attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.short), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .medium(.short), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .medium(.short), textColor: theme.colors.link), linkAttribute: { contents in
                    return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { value in
                        showModal(with: PremiumBoardingController.init(context: context, source: .profile(peerId)), for: context.window)
                    }))
                })).mutableCopy() as! NSMutableAttributedString
                
                
                let range = attr.string.nsstring.range(of: "🤡")
                if range.location != NSNotFound {
                    attr.addAttribute(.init(rawValue: "Attribute__EmbeddedItem"), value: TGTextAttachment(identifier: "\(arc4random())", fileId: status.fileId, file: nil, text: "", info: nil), range: range)
                }
                let layout = TextViewLayout(attr, alignment: .center)
                layout.measure(width: frame.width - 80)
                layout.interactions = globalLinkExecutor
                current.update(layout)
                
                self.statusLayer?.removeFromSuperview()
                self.statusLayer = nil
                
                for embedded in layout.embeddedItems {
                    let rect = embedded.rect.insetBy(dx: -1.5, dy: -1.5)
                    let view = InlineStickerView(account: chatInteraction.context.account, inlinePacksContext: chatInteraction.context.inlinePacksContext, emoji: .init(fileId: status.fileId, file: nil, emoji: ""), size: rect.size)
                    view.frame = rect
                    current.addEmbeddedView(view)
                    self.statusLayer = view
                    view.updateAnimatableContent()
                    view.animateLayer.isPlayable = true
                }
            } else if let view = self.textView {
                performSubviewRemoval(view, animated: animated)
                self.textView = nil
            }
        default:
            break
        }
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.statusLayer?.updateAnimatableContent()
    }
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.statusLayer?.updateAnimatableContent()
    }

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    override func layout() {
        report.center()
        dismiss.frame = NSMakeRect(frame.width - dismiss.frame.width - 20, floorToScreenPixels(backingScaleFactor, (44 - dismiss.frame.height) / 2), dismiss.frame.width, dismiss.frame.height)
        
        buttonsContainer.frame = NSMakeRect(0, 0, frame.width, 44 - .borderSize)

        var buttons:[Control] = []
        if report.superview != nil {
            buttons.append(report)
        }
        if unarchiveButton.superview != nil {
            buttons.append(unarchiveButton)
        }
        
        let buttonWidth: CGFloat = floor(buttonsContainer.frame.width / CGFloat(buttons.count))
        var x: CGFloat = 0
        for button in buttons {
            button.frame = NSMakeRect(x, 0, buttonWidth, buttonsContainer.frame.height)
            x += buttonWidth
        }
        
        if let textView = textView {
            textView.centerX(y: frame.height - textView.frame.height - 5)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class ShareInfoView : Control, ChatHeaderProtocol {
    private let chatInteraction:ChatInteraction
    private let share:TitleButton = TitleButton()
    private let dismiss:ImageButton = ImageButton()
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        super.init(frame: frame)
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        dismiss.disableActions()
        
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = dismiss.sizeToFit()
        
        share.set(handler: { [weak self] _ in
            self?.chatInteraction.shareSelfContact(nil)
            self?.chatInteraction.dismissPeerStatusOptions()
        }, for: .SingleClick)
        
        dismiss.set(handler: { [weak self] _ in
            self?.chatInteraction.dismissPeerStatusOptions()
        }, for: .SingleClick)
        

        addSubview(share)
        addSubview(dismiss)
        updateLocalizationAndTheme(theme: theme)
    }

    func update(with state: ChatHeaderState, animated: Bool) {

    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        share.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background, highlightColor: theme.colors.accentSelect)
        
        share.set(text: strings().peerInfoShareMyInfo, for: .Normal)

        self.backgroundColor = theme.colors.background
        needsLayout = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    override func layout() {
        super.layout()
        dismiss.centerY(x: frame.width - dismiss.frame.width - 20)
        share.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

class AddContactView : Control, ChatHeaderProtocol {
    private let chatInteraction:ChatInteraction
    private let add:TitleButton = TitleButton()
    private let dismiss:ImageButton = ImageButton()
    private let blockButton: TitleButton = TitleButton()
    private let unarchiveButton = TitleButton()
    private let buttonsContainer = View()
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        super.init(frame: frame)
        self.style = ControlStyle(backgroundColor: theme.colors.background)
        dismiss.disableActions()
        
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = dismiss.sizeToFit()

        add.set(handler: { [weak self] _ in
            self?.chatInteraction.addContact()
        }, for: .SingleClick)
        
        dismiss.set(handler: { [weak self] _ in
            self?.chatInteraction.dismissPeerStatusOptions()
        }, for: .SingleClick)
        
        blockButton.set(handler: { [weak self] _ in
            self?.chatInteraction.blockContact()
        }, for: .SingleClick)
        
        unarchiveButton.set(handler: { [weak self] _ in
            self?.chatInteraction.unarchive()
        }, for: .SingleClick)

        
        addSubview(buttonsContainer)
        addSubview(dismiss)
       
        update(with: state, animated: false)
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        add.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background, highlightColor: theme.colors.accentSelect)
        blockButton.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.redUI, backgroundColor: theme.colors.background, highlightColor: theme.colors.redUI)
        
        if blockButton.superview == nil, let peer = chatInteraction.peer {
            add.set(text: strings().peerInfoAddUserToContact(peer.compactDisplayTitle), for: .Normal)
        } else {
            add.set(text: strings().peerInfoAddContact, for: .Normal)
        }
        blockButton.set(text: strings().peerInfoBlockUser, for: .Normal)
        unarchiveButton.set(text: strings().peerInfoUnarchive, for: .Normal)
        
        unarchiveButton.style = ControlStyle(font: .normal(.text), foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background, highlightColor: theme.colors.accentSelect)
        
        self.backgroundColor = theme.colors.background
        needsLayout = true
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        switch state {
        case let .addContact(_, canBlock, autoArchived):
            buttonsContainer.removeAllSubviews()

            if canBlock {
                buttonsContainer.addSubview(blockButton)
            }
            if autoArchived {
                buttonsContainer.addSubview(unarchiveButton)
            }

            if !autoArchived && canBlock {
                buttonsContainer.addSubview(add)
            } else if !autoArchived && !canBlock {
                buttonsContainer.addSubview(add)
            }
        default:
            break
        }
        updateLocalizationAndTheme(theme: theme)
        needsLayout = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    override func layout() {
        dismiss.centerY(x: frame.width - dismiss.frame.width - 20)
        
        var buttons:[Control] = []
        
        
        if add.superview != nil {
            buttons.append(add)
        }
        if blockButton.superview != nil {
            buttons.append(blockButton)
        }
        if unarchiveButton.superview != nil {
            buttons.append(unarchiveButton)
        }
        
        buttonsContainer.frame = NSMakeRect(0, 0, frame.width, frame.height - .borderSize)

        
        let buttonWidth: CGFloat = floor(buttonsContainer.frame.width / CGFloat(buttons.count))
        var x: CGFloat = 0
        for button in buttons {
            button.frame = NSMakeRect(x, 0, buttonWidth, buttonsContainer.frame.height)
            x += buttonWidth
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

private final class CSearchContextState : Equatable {
    let inputQueryResult: ChatPresentationInputQueryResult?
    let tokenState: TokenSearchState
    let peerId:PeerId?
    let messages: ([Message], SearchMessagesState?)
    let selectedIndex: Int
    let searchState: SearchState
    
    init(inputQueryResult: ChatPresentationInputQueryResult? = nil, messages: ([Message], SearchMessagesState?) = ([], nil), selectedIndex: Int = -1, searchState: SearchState = SearchState(state: .None, request: ""), tokenState: TokenSearchState = .none, peerId: PeerId? = nil) {
        self.inputQueryResult = inputQueryResult
        self.tokenState = tokenState
        self.peerId = peerId
        self.messages = messages
        self.selectedIndex = selectedIndex
        self.searchState = searchState
    }
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: f(self.inputQueryResult), messages: self.messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedTokenState(_ token: TokenSearchState) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: token, peerId: self.peerId)
    }
    func updatedPeerId(_ peerId: PeerId?) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: peerId)
    }
    func updatedMessages(_ messages: ([Message], SearchMessagesState?)) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: messages, selectedIndex: self.selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedSelectedIndex(_ selectedIndex: Int) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: selectedIndex, searchState: self.searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
    func updatedSearchState(_ searchState: SearchState) -> CSearchContextState {
        return CSearchContextState(inputQueryResult: self.inputQueryResult, messages: self.messages, selectedIndex: self.selectedIndex, searchState: searchState, tokenState: self.tokenState, peerId: self.peerId)
    }
}

private func ==(lhs: CSearchContextState, rhs: CSearchContextState) -> Bool {
    if lhs.messages.0.count != rhs.messages.0.count {
        return false
    } else {
        for i in 0 ..< lhs.messages.0.count {
            if !isEqualMessages(lhs.messages.0[i], rhs.messages.0[i]) {
                return false
            }
        }
    }
    return lhs.inputQueryResult == rhs.inputQueryResult && lhs.tokenState == rhs.tokenState && lhs.selectedIndex == rhs.selectedIndex && lhs.searchState == rhs.searchState && lhs.messages.1 == rhs.messages.1
}

private final class CSearchInteraction : InterfaceObserver {
    private(set) var state: CSearchContextState = CSearchContextState()
    
    func update(animated:Bool = true, _ f:(CSearchContextState)->CSearchContextState) -> Void {
        let oldValue = self.state
        self.state = f(state)
        if oldValue != state {
            notifyObservers(value: state, oldValue:oldValue, animated: animated)
        }
    }
    
    var currentMessage: Message? {
        if state.messages.0.isEmpty {
            return nil
        } else if state.messages.0.count <= state.selectedIndex || state.selectedIndex < 0 {
            return nil
        }
        return state.messages.0[state.selectedIndex]
    }
}

struct SearchStateQuery : Equatable {
    let query: String?
    let state: SearchMessagesState?
    init(_ query: String?, _ state: SearchMessagesState?) {
        self.query = query
        self.state = state
    }
}

struct SearchMessagesResultState : Equatable {
    static func == (lhs: SearchMessagesResultState, rhs: SearchMessagesResultState) -> Bool {
        if lhs.query != rhs.query {
            return false
        }
        if lhs.messages.count != rhs.messages.count {
            return false
        } else {
            for i in 0 ..< lhs.messages.count {
                if !isEqualMessages(lhs.messages[i], rhs.messages[i]) {
                    return false
                }
            }
        }
        return true
    }
    
    let query: String
    let messages: [Message]
    init(_ query: String, _ messages: [Message]) {
        self.query = query
        self.messages = messages
    }
    
    func containsMessage(_ message: Message) -> Bool {
        return self.messages.contains(where: { $0.id == message.id })
    }
}

class ChatSearchHeader : View, Notifable, ChatHeaderProtocol {
    
    private let searchView:ChatSearchView = ChatSearchView(frame: NSZeroRect)
    private let cancel:ImageButton = ImageButton()
    private let from:ImageButton = ImageButton()
    private let calendar:ImageButton = ImageButton()
    
    private let prev:ImageButton = ImageButton()
    private let next:ImageButton = ImageButton()

    
    private let separator:View = View()
    private let interactions:ChatSearchInteractions
    private let chatInteraction: ChatInteraction
    
    private let query:ValuePromise<SearchStateQuery> = ValuePromise()

    private let disposable:MetaDisposable = MetaDisposable()
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?
    private let inputContextHelper: InputContextHelper
    private let inputInteraction: CSearchInteraction = CSearchInteraction()
    private let parentInteractions: ChatInteraction
    private let loadingDisposable = MetaDisposable()
   
    private let calendarController: CalendarController
    required init(_ chatInteraction: ChatInteraction, state: ChatHeaderState, frame: NSRect) {

        switch state {
        case let .search(_, interactions, _, initialString):
            self.interactions = interactions
            self.parentInteractions = chatInteraction
            self.calendarController = CalendarController(NSMakeRect(0, 0, 300, 300), chatInteraction.context.window, selectHandler: interactions.calendarAction)
            self.chatInteraction = ChatInteraction(chatLocation: chatInteraction.chatLocation, context: chatInteraction.context, mode: chatInteraction.mode)
            self.chatInteraction.update({$0.updatedPeer({_ in chatInteraction.presentation.peer})})
            self.inputContextHelper = InputContextHelper(chatInteraction: self.chatInteraction, highlightInsteadOfSelect: true)

            if let initialString = initialString {
                searchView.setString(initialString)
                self.query.set(SearchStateQuery(initialString, nil))
            }
        default:
            fatalError()
        }

        super.init()
        
        self.chatInteraction.movePeerToInput = { [weak self] peer in
            self?.searchView.completeToken(peer.compactDisplayTitle)
            self?.inputInteraction.update({$0.updatedPeerId(peer.id)})
        }
        
        
        self.chatInteraction.focusMessageId = { [weak self] fromId, messageId, state in
            self?.parentInteractions.focusMessageId(fromId, messageId, state)
            self?.inputInteraction.update({$0.updatedSelectedIndex($0.messages.0.firstIndex(where: {$0.id == messageId}) ?? -1)})
            _ = self?.window?.makeFirstResponder(nil)
        }
        
     

        initialize()
        

        
        parentInteractions.loadingMessage.set(.single(false))
        
        inputInteraction.add(observer: self)
        self.loadingDisposable.set((parentInteractions.loadingMessage.get() |> deliverOnMainQueue).start(next: { [weak self] loading in
            self?.searchView.isLoading = loading
        }))
        switch state {
        case let .search(_, _, initialPeer, _):
            if let initialPeer = initialPeer {
                self.chatInteraction.movePeerToInput(initialPeer)
            }
        default:
            break
        }
        Queue.mainQueue().justDispatch { [weak self] in
            self?.applySearchResponder(false)
        }
    }
    
    func update(with state: ChatHeaderState, animated: Bool) {
        
    }

    
    func applySearchResponder(_ animated: Bool = false) {
       // _ = window?.makeFirstResponder(searchView.input)
        searchView.layout()
        if searchView.state == .Focus && window?.firstResponder != searchView.input {
            _ = window?.makeFirstResponder(searchView.input)
        }
        searchView.change(state: .Focus, animated)
    }
    
    private var calendarAbility: Bool {
        return chatInteraction.mode != .scheduled && chatInteraction.mode != .pinned
    }
    
    private var fromAbility: Bool {
        if let peer = chatInteraction.presentation.peer {
            return (peer.isSupergroup || peer.isGroup) && (chatInteraction.mode == .history || chatInteraction.mode.isThreadMode)
        } else {
            return false
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        let context = chatInteraction.context
        if let value = value as? CSearchContextState, let oldValue = oldValue as? CSearchContextState, let superview = superview, let view = superview.superview {
            
            let stateValue = self.query
            
            prev.isEnabled = !value.messages.0.isEmpty && value.selectedIndex < value.messages.0.count - 1
            next.isEnabled = !value.messages.0.isEmpty && value.selectedIndex > 0
            next.set(image: next.isEnabled ? theme.icons.chatSearchDown : theme.icons.chatSearchDownDisabled, for: .Normal)
            prev.set(image: prev.isEnabled ? theme.icons.chatSearchUp : theme.icons.chatSearchUpDisabled, for: .Normal)

            
            
            if let peer = chatInteraction.presentation.peer {
                if value.inputQueryResult != oldValue.inputQueryResult {
                    inputContextHelper.context(with: value.inputQueryResult, for: view, relativeView: superview, position: .below, selectIndex: value.selectedIndex != -1 ? value.selectedIndex : nil, animated: animated)
                }
                switch value.tokenState {
                case .none:
                    from.isHidden = !fromAbility
                    calendar.isHidden = !calendarAbility
                    needsLayout = true
                    searchView.change(size: NSMakeSize(searchWidth, searchView.frame.height), animated: animated)
                    
                    if (peer.isSupergroup || peer.isGroup) && chatInteraction.mode == .history {
                        if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(chatLocations: [chatInteraction.chatLocation], .mention(query: value.searchState.request, includeRecent: false), currentQuery: self.contextQueryState?.0, context: context) {
                            self.contextQueryState?.1.dispose()
                            self.contextQueryState = (updatedContextQueryState, (updatedContextQuerySignal |> deliverOnMainQueue).start(next: { [weak self] result in
                                if let strongSelf = self {
                                    strongSelf.inputInteraction.update(animated: animated, { state in
                                        return state.updatedInputQueryResult { previousResult in
                                            let messages = state.searchState.responder ? state.messages : ([], nil)
                                            var suggestedPeers:[Peer] = []
                                            let inputQueryResult = result(previousResult)
                                            if let inputQueryResult = inputQueryResult, state.searchState.responder, !state.searchState.request.isEmpty, messages.1 != nil {
                                                switch inputQueryResult {
                                                case let .mentions(mentions):
                                                    suggestedPeers = mentions
                                                default:
                                                    break
                                                }
                                            }
                                            return .searchMessages((messages.0, messages.1, { searchMessagesState in
                                                stateValue.set(SearchStateQuery(state.searchState.request, searchMessagesState))
                                            }), suggestedPeers, state.searchState.request)
                                        }
                                    })
                                }
                            }))
                        }
                    } else {
                        inputInteraction.update(animated: animated, { state in
                            return state.updatedInputQueryResult { previousResult in
                                let result = state.searchState.responder ? state.messages : ([], nil)
                                return .searchMessages((result.0, result.1, { searchMessagesState in
                                    stateValue.set(SearchStateQuery(state.searchState.request, searchMessagesState))
                                }), [], state.searchState.request)
                            }
                        })
                    }
                    
                    
                case let .from(query, complete):
                    from.isHidden = true
                    calendar.isHidden = true
                    searchView.change(size: NSMakeSize(searchWidth, searchView.frame.height), animated: animated)
                    needsLayout = true
                    if complete {
                        inputInteraction.update(animated: animated, { state in
                            return state.updatedInputQueryResult { previousResult in
                                let result = state.searchState.responder ? state.messages : ([], nil)
                                return .searchMessages((result.0, result.1, { searchMessagesState in
                                    stateValue.set(SearchStateQuery(state.searchState.request, searchMessagesState))
                                }), [], state.searchState.request)
                            }
                        })
                    } else {
                        if let (updatedContextQueryState, updatedContextQuerySignal) = chatContextQueryForSearchMention(chatLocations: [chatInteraction.chatLocation], .mention(query: query, includeRecent: false), currentQuery: self.contextQueryState?.0, context: context) {
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
                                            }.updatedMessages(([], nil)).updatedSelectedIndex(-1)
                                        })
                                        
                                    }
                                }
                            }))
                            inScope = false
                            if let inScopeResult = inScopeResult {
                                inputInteraction.update(animated: animated, {
                                    $0.updatedInputQueryResult { previousResult in
                                        return inScopeResult(previousResult)
                                    }.updatedMessages(([], nil)).updatedSelectedIndex(-1)
                                })
                            }
                        }
                    }
                }
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let to = other as? ChatSearchView {
            return to === other
        } else {
            return false
        }
    }
    
    
    
    
    
    private func initialize() {
        self.from.isHidden = !fromAbility
        
        _ = self.searchView.tokenPromise.get().start(next: { [weak self] state in
            self?.inputInteraction.update({$0.updatedTokenState(state)})
        })
        
     
        self.searchView.searchInteractions = SearchInteractions({ [weak self] state, _ in
            if state.state == .None {
                self?.parentInteractions.loadingMessage.set(.single(false))
                self?.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                self?.inputInteraction.update({$0.updatedMessages(([], nil)).updatedSelectedIndex(-1).updatedSearchState(state)})
            }
        }, { [weak self] state in
            guard let `self` = self else {return}
            
            self.inputInteraction.update({$0.updatedMessages(([], nil)).updatedSelectedIndex(-1).updatedSearchState(state)})
            
            self.updateSearchState()
            switch self.searchView.tokenState {
            case .none:
                if state.request == strings().chatSearchFrom, let peer = self.chatInteraction.presentation.peer, peer.isGroup || peer.isSupergroup  {
                    self.query.set(SearchStateQuery("", nil))
                    self.parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
                    self.searchView.initToken()
                } else {
                    self.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                    self.parentInteractions.loadingMessage.set(.single(true))
                    self.query.set(SearchStateQuery(state.request, nil))
                }
                
            case .from(_, let complete):
                if complete {
                    self.parentInteractions.updateSearchRequest(SearchMessagesResultState(state.request, []))
                    self.parentInteractions.loadingMessage.set(.single(true))
                    self.query.set(SearchStateQuery(state.request, nil))
                }
            }
            
        }, responderModified: { [weak self] state in
            self?.inputInteraction.update({$0.updatedSearchState(state)})
        })
 
        
        let apply = query.get() |> mapToSignal { [weak self] state -> Signal<([Message], SearchMessagesState?, String), NoError> in
            
            guard let `self` = self else { return .single(([], nil, "")) }
            if let query = state.query {
                
                let stateSignal: Signal<SearchMessagesState?, NoError>
                if state.state == nil {
                    stateSignal = .single(state.state) |> delay(0.3, queue: Queue.mainQueue())
                } else {
                    stateSignal = .single(state.state)
                }
                
                return stateSignal |> mapToSignal { [weak self] state in
                    
                    guard let `self` = self else { return .single(([], nil, "")) }
                    
                    let emptyRequest: Bool
                    if case .from = self.inputInteraction.state.tokenState {
                        emptyRequest = true
                    } else {
                        emptyRequest = !query.isEmpty
                    }
                    if emptyRequest {
                        return self.interactions.searchRequest(query, self.inputInteraction.state.peerId, state) |> map { ($0.0, $0.1, query) }
                    } else {
                        return .single(([], nil, ""))
                    }
                }
            } else {
                return .single(([], nil, ""))
            }
        } |> deliverOnMainQueue
        
        self.disposable.set(apply.start(next: { [weak self] messages in
            guard let `self` = self else {return}
            self.parentInteractions.updateSearchRequest(SearchMessagesResultState(messages.2, messages.0))
            self.inputInteraction.update({$0.updatedMessages((messages.0, messages.1)).updatedSelectedIndex(-1)})
            self.parentInteractions.loadingMessage.set(.single(false))
        }))
        
        next.autohighlight = false
        prev.autohighlight = false



        _ = calendar.sizeToFit()
        
        addSubview(next)
        addSubview(prev)

        
        addSubview(from)
        
        
        addSubview(calendar)
        
        calendar.isHidden = !calendarAbility
        
        _ = cancel.sizeToFit()
        
        let interactions = self.interactions
        let searchView = self.searchView
        cancel.set(handler: { [weak self] _ in
            self?.inputInteraction.update {$0.updatedTokenState(.none).updatedSelectedIndex(-1).updatedMessages(([], nil)).updatedSearchState(SearchState(state: .None, request: ""))}
            self?.parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
            interactions.cancel()
        }, for: .Click)
        
        next.set(handler: { [weak self] _ in
            self?.nextAction()
            }, for: .Click)
        prev.set(handler: { [weak self] _ in
            self?.prevAction()
        }, for: .Click)

        

        from.set(handler: { [weak self] _ in
            self?.searchView.initToken()
        }, for: .Click)
        
        
        
        calendar.set(handler: { [weak self] calendar in
            guard let `self` = self else {return}
            showPopover(for: calendar, with: self.calendarController, edge: .maxY, inset: NSMakePoint(-160, -40))
        }, for: .Click)

        addSubview(searchView)
        addSubview(cancel)
        addSubview(separator)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        backgroundColor = theme.colors.background
        
        next.set(image: theme.icons.chatSearchDown, for: .Normal)
        _ = next.sizeToFit()
        
        prev.set(image: theme.icons.chatSearchUp, for: .Normal)
        _ = prev.sizeToFit()


        calendar.set(image: theme.icons.chatSearchCalendar, for: .Normal)
        _ = calendar.sizeToFit()
        
        cancel.set(image: theme.icons.chatSearchCancel, for: .Normal)
        _ = cancel.sizeToFit()

        from.set(image: theme.icons.chatSearchFrom, for: .Normal)
        _ = from.sizeToFit()
        
        separator.backgroundColor = theme.colors.border
        self.backgroundColor = theme.colors.background
        needsLayout = true
        updateSearchState()
    }
    
    func updateSearchState() {
       
    }
    
    func prevAction() {
        inputInteraction.update({$0.updatedSelectedIndex(min($0.selectedIndex + 1, $0.messages.0.count - 1))})
        perform()
    }
    
    func perform() {
        _ = window?.makeFirstResponder(nil)
        if let currentMessage = inputInteraction.currentMessage {
            interactions.jump(currentMessage)
        }
    }
    
    func nextAction() {
        inputInteraction.update({$0.updatedSelectedIndex(max($0.selectedIndex - 1, 0))})
        perform()
    }
    
    private var searchWidth: CGFloat {
        return frame.width - cancel.frame.width - 20 - 20 - 80 - (calendar.isHidden ? 0 : calendar.frame.width + 20) - (from.isHidden ? 0 : from.frame.width + 20)
    }
    
    override func layout() {
        super.layout()
        
        
        prev.centerY(x:10)
        next.centerY(x:prev.frame.maxX)


        cancel.centerY(x:frame.width - cancel.frame.width - 20)

        searchView.setFrameSize(NSMakeSize(searchWidth, 30))
        inputContextHelper.controller.view.setFrameSize(frame.width, inputContextHelper.controller.frame.height)
        searchView.centerY(x: 80)
        separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        
        from.centerY(x: searchView.frame.maxX + 20)
        calendar.centerY(x: (from.isHidden ? searchView : from).frame.maxX + 20)

    }
    
    override func viewDidMoveToWindow() {
        if let _ = window {
            layout()
            //self.searchView.change(state: .Focus, false)
        }
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
         //   self.searchView.change(state: .None, false)
        }
    }
    
    
    deinit {
        inputInteraction.update(animated: false, { state in
            return state.updatedInputQueryResult( { _ in return nil } )
        })
        parentInteractions.updateSearchRequest(SearchMessagesResultState("", []))
        disposable.dispose()
        inputInteraction.remove(observer: self)
        loadingDisposable.set(nil)
        if let window = window as? Window {
            window.removeAllHandlers(for: self)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(frame frameRect: NSRect, interactions:ChatSearchInteractions, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction = chatInteraction
        self.parentInteractions = chatInteraction
        self.inputContextHelper = InputContextHelper(chatInteraction: chatInteraction, highlightInsteadOfSelect: true)
        self.calendarController = CalendarController(NSMakeRect(0,0,300, 300), chatInteraction.context.window, selectHandler: interactions.calendarAction)
        super.init(frame: frameRect)
        initialize()
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}


private final class FakeAudioLevelGenerator {
    private var isFirstTime: Bool = true
    private var nextTarget: Float = 0.0
    private var nextTargetProgress: Float = 0.0
    private var nextTargetProgressNorm: Float = 1.0

    func get() -> Float {
        let wasFirstTime = self.isFirstTime
        self.isFirstTime = false

        self.nextTargetProgress *= 0.82
        if self.nextTargetProgress <= 0.01 {
            if Int.random(in: 0 ... 4) <= 1 && !wasFirstTime {
                self.nextTarget = 0.0
                self.nextTargetProgressNorm = Float.random(in: 0.1 ..< 0.3)
            } else {
                self.nextTarget = Float.random(in: 0.0 ..< 20.0)
                self.nextTargetProgressNorm = Float.random(in: 0.2 ..< 0.7)
            }
            self.nextTargetProgress = self.nextTargetProgressNorm
            return self.nextTarget
        } else {
            let value = self.nextTarget * max(0.0, self.nextTargetProgress / self.nextTargetProgressNorm)
            return value
        }
    }
}

private final class TimerButtonView : Control {
    private var nextTimer: SwiftSignalKit.Timer?
    private let counter = DynamicCounterTextView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(counter)
        scaleOnClick = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        let purple = NSColor(rgb: 0x3252ef)
        let pink = NSColor(rgb: 0xef436c)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var locations:[CGFloat] = [0.0, 0.85, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: [pink.cgColor, purple.cgColor, purple.cgColor] as CFArray, locations: &locations)!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0.0), end: CGPoint(x: frame.width, y: frame.height), options: [])
    }
    
    func setTime(_ timeValue: Int32, animated: Bool, layout: @escaping(NSSize, NSView)->Void) {
        let time = Int(timeValue - Int32(Date().timeIntervalSince1970))
        
        let text = timerText(time)
        let value = DynamicCounterTextView.make(for: text, count: text, font: .avatar(13), textColor: .white, width: .greatestFiniteMagnitude)
        
        counter.update(value, animated: animated)
        counter.change(size: value.size, animated: animated)

        layout(value.size, self)
        var point = focus(value.size).origin
        point = point.offset(dx: 2, dy: 0)
        counter.change(pos: point, animated: animated)
        
        
        self.nextTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: false, completion: { [weak self] in
            self?.setTime(timeValue, animated: true, layout: layout)
        }, queue: .mainQueue())
        
        nextTimer?.start()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class ChatGroupCallView : Control, ChatHeaderProtocol {
    
    struct Avatar : Comparable, Identifiable {
        static func < (lhs: Avatar, rhs: Avatar) -> Bool {
            return lhs.index < rhs.index
        }
        var stableId: PeerId {
            return peer.id
        }
        static func == (lhs: Avatar, rhs: Avatar) -> Bool {
            if lhs.index != rhs.index {
                return false
            }
            if !lhs.peer.isEqual(rhs.peer) {
                return false
            }
            return true
        }
        
        let peer: Peer
        let index: Int
    }
    private var topPeers: [Avatar] = []
    private var avatars:[AvatarContentView] = []
    private let avatarsContainer = View(frame: NSMakeRect(0, 0, 25 * 3 + 10, 38))

    private let joinButton = TitleButton()
    private var data: ChatActiveGroupCallInfo?
    private let headerView = TextView()
    private let membersCountView = DynamicCounterTextView()
    private let button = Control()

    private var scheduleButton: TimerButtonView?

    private var audioLevelGenerators: [PeerId: FakeAudioLevelGenerator] = [:]
    private var audioLevelGeneratorTimer: SwiftSignalKit.Timer?

    private let context: AccountContext
    private let join:(CachedChannelData.ActiveCall, String?) -> Void

    required init(_ join: @escaping (CachedChannelData.ActiveCall, String?) -> Void, context: AccountContext, state: ChatHeaderState, frame: NSRect) {
        self.context = context
        self.join = join
        super.init(frame: frame)
        addSubview(headerView)
        addSubview(membersCountView)
        addSubview(avatarsContainer)
        addSubview(button)
        addSubview(joinButton)
        avatarsContainer.isEventLess = true
        
        
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        membersCountView.userInteractionEnabled = false

        joinButton.set(handler: { [weak self] _ in
            if let `self` = self, let data = self.data {
                join(data.activeCall, data.joinHash)
            }
        }, for: .SingleClick)
        
        
        button.set(handler: { [weak self] _ in
            if let `self` = self, let data = self.data {
                join(data.activeCall, data.joinHash)
            }
        }, for: .SingleClick)
        
        button.set(handler: { [weak self] _ in
            self?.headerView.change(opacity: 0.6, animated: true)
            self?.membersCountView.change(opacity: 0.6, animated: true)
            self?.avatarsContainer.change(opacity: 0.6, animated: true)
        }, for: .Highlight)
        
        button.set(handler: { [weak self] _ in
            self?.headerView.change(opacity: 1, animated: true)
            self?.membersCountView.change(opacity: 1, animated: true)
            self?.avatarsContainer.change(opacity: 1.0, animated: true)
        }, for: .Normal)
        
        button.set(handler: { [weak self] _ in
            self?.headerView.change(opacity: 1, animated: true)
            self?.membersCountView.change(opacity: 1, animated: true)
            self?.avatarsContainer.change(opacity: 1.0, animated: true)
        }, for: .Hover)

        joinButton.scaleOnClick = true

        self.avatarsContainer.center()
        border = [.Bottom]

        self.update(with: state, animated: false)
        updateLocalizationAndTheme(theme: theme)
    }
    

    func update(with state: ChatHeaderState, animated: Bool) {
        if let data = state.voiceChat {
            self.update(data, animated: animated)
        }
    }

    func update(_ data: ChatActiveGroupCallInfo, animated: Bool) {
        
        let context = self.context
        
        let activeCall = data.data?.groupCall != nil
        joinButton.change(opacity: activeCall ? 0 : 1, animated: animated)
        joinButton.userInteractionEnabled = !activeCall
        joinButton.isEventLess = activeCall
        
        let duration: Double = 0.2
        let timingFunction: CAMediaTimingFunctionName = .easeInEaseOut


        var topPeers: [Avatar] = []
        if let participants = data.data?.topParticipants {
            var index:Int = 0
            let participants = participants
            for participant in participants {
                topPeers.append(Avatar(peer: participant.peer, index: index))
                index += 1
            }


        }
        let (removed, inserted, updated) = mergeListsStableWithUpdates(leftList: self.topPeers, rightList: topPeers)
        
        let avatarSize = NSMakeSize(38, 38)
        
        for removed in removed.reversed() {
            let control = avatars.remove(at: removed)
            let peer = self.topPeers[removed]
            let haveNext = topPeers.contains(where: { $0.stableId == peer.stableId })
            control.updateLayout(size: avatarSize - NSMakeSize(8, 8), isClipped: false, animated: animated)
            control.layer?.opacity = 0
            if animated && !haveNext {
                control.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak control] _ in
                    control?.removeFromSuperview()
                })
                control.layer?.animateScaleSpring(from: 1.0, to: 0.2, duration: duration, bounce: false)
            } else {
                control.removeFromSuperview()
            }
        }
        for inserted in inserted {
            let control = AvatarContentView(context: context, peer: inserted.1.peer, message: nil, synchronousLoad: false, size: avatarSize, inset: 6)
            control.updateLayout(size: avatarSize - NSMakeSize(8, 8), isClipped: inserted.0 != 0, animated: animated)
            control.userInteractionEnabled = false
            control.setFrameSize(avatarSize)
            control.setFrameOrigin(NSMakePoint(CGFloat(inserted.0) * (avatarSize.width - 14), 0))
            avatars.insert(control, at: inserted.0)
            avatarsContainer.subviews.insert(control, at: inserted.0)
            if animated {
                if let index = inserted.2 {
                    control.layer?.animatePosition(from: NSMakePoint(CGFloat(index) * (avatarSize.width - 14), 0), to: control.frame.origin, timingFunction: timingFunction)
                } else {
                    control.layer?.animateAlpha(from: 0, to: 1, duration: duration, timingFunction: timingFunction)
                    control.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: duration, bounce: false)
                }
            }
        }
        for updated in updated {
            let control = avatars[updated.0]
            control.updateLayout(size: avatarSize - NSMakeSize(8, 8), isClipped: updated.0 != 0, animated: animated)
            let updatedPoint = NSMakePoint(CGFloat(updated.0) * (avatarSize.width - 14), 0)
            if animated {
                control.layer?.animatePosition(from: control.frame.origin - updatedPoint, to: .zero, duration: duration, timingFunction: timingFunction, additive: true)
            }
            control.setFrameOrigin(updatedPoint)
        }
        var index: CGFloat = 10
        for control in avatarsContainer.subviews.compactMap({ $0 as? AvatarContentView }) {
            control.layer?.zPosition = index
            index -= 1
        }



        if let data = data.data, data.groupCall == nil {

            var activeSpeakers = data.activeSpeakers

            for peerId in activeSpeakers {
                if self.audioLevelGenerators[peerId] == nil {
                    self.audioLevelGenerators[peerId] = FakeAudioLevelGenerator()
                }
            }
            var removeGenerators: [PeerId] = []
            for peerId in self.audioLevelGenerators.keys {
                if !activeSpeakers.contains(peerId) {
                    removeGenerators.append(peerId)
                }
            }
            for peerId in removeGenerators {
                self.audioLevelGenerators.removeValue(forKey: peerId)
            }

            if self.audioLevelGenerators.isEmpty {
                self.audioLevelGeneratorTimer?.invalidate()
                self.audioLevelGeneratorTimer = nil
                self.sampleAudioGenerators()
            } else if self.audioLevelGeneratorTimer == nil {
                let audioLevelGeneratorTimer = SwiftSignalKit.Timer(timeout: 1.0 / 30.0, repeat: true, completion: { [weak self] in
                    self?.sampleAudioGenerators()
                }, queue: .mainQueue())
                self.audioLevelGeneratorTimer = audioLevelGeneratorTimer
                audioLevelGeneratorTimer.start()
            }
        }

        let subviewsCount = max(avatarsContainer.subviews.filter { $0.layer?.opacity == 1.0 }.count, 1)

        if subviewsCount == 3 {
            self.avatarsContainer.setFrameOrigin(self.focus(self.avatarsContainer.frame.size).origin)
        } else {
            let count = CGFloat(subviewsCount)
            if count != 0 {
                let animated = animated && self.data?.data?.activeSpeakers.count != 0
                let avatarSize: CGFloat = avatarsContainer.subviews.map { $0.frame.maxX }.max() ?? 0
                let pos = NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - avatarSize) / 2), self.avatarsContainer.frame.minY)
                self.avatarsContainer.change(pos: pos, animated: animated)
            }
        }
        let participantsCount = data.data?.participantCount ?? 0

        var text: String
        let pretty: String
        if let scheduledDate = data.activeCall.scheduleTimestamp, participantsCount == 0 {
            text = strings().chatGroupCallScheduledStatus(stringForMediumDate(timestamp: scheduledDate))
            pretty = ""
            var presented = false
            let current: TimerButtonView
            if let button = self.scheduleButton {
                current = button
            } else {
                current = TimerButtonView(frame: NSMakeRect(0, 0, 60, 24))
                self.scheduleButton = current
                current.layer?.cornerRadius = current.frame.height / 2
                addSubview(current)
                presented = true
                
                current.set(handler: { [weak self] _ in
                    if let `self` = self, let data = self.data {
                        self.join(data.activeCall, data.joinHash)
                    }
                }, for: .SingleClick)

            }
            current.setTime(scheduledDate, animated: animated, layout: { [weak self] size, button in
                guard let strongSelf = self else {
                    return
                }
                let animated = animated && !presented
                let size = NSMakeSize(size.width + 10, button.frame.height)
                button._change(size: size, animated: animated)
                button._change(pos: button.centerFrameY(x: strongSelf.frame.width - button.frame.width - 23).origin, animated: animated)
                presented = false
            })
            joinButton.isHidden = true
        } else {
            text = strings().chatGroupCallMembersCountable(participantsCount)
            pretty = "\(Int(participantsCount).formattedWithSeparator)"
            text = text.replacingOccurrences(of: "\(participantsCount)", with: pretty)
            joinButton.isHidden = false
            
            self.scheduleButton?.removeFromSuperview()
            self.scheduleButton = nil
        }
        let dynamicValues = DynamicCounterTextView.make(for: text, count: pretty, font: .normal(.short), textColor: theme.colors.grayText, width: frame.midX)

        self.membersCountView.update(dynamicValues, animated: animated)
        self.membersCountView.change(size: dynamicValues.size, animated: animated)


        self.topPeers = topPeers
        self.data = data
        
        
        var title: String = data.activeCall.scheduleTimestamp != nil ? strings().chatGroupCallScheduledTitle : strings().chatGroupCallTitle
        
        if data.activeCall.scheduleTimestamp == nil {
            if data.isLive {
                title = strings().chatGroupCallLiveTitle
            }
        }
        
        let headerLayout = TextViewLayout(.initialize(string: title, color: theme.colors.text, font: .medium(.text)))
        headerLayout.measure(width: frame.width - 100)
        headerView.update(headerLayout)

        needsLayout = true

    }

    private func sampleAudioGenerators() {
        var levels: [PeerId: Float] = [:]
        for (peerId, generator) in self.audioLevelGenerators {
            levels[peerId] = generator.get()
        }
        let avatars = avatarsContainer.subviews.compactMap { $0 as? AvatarContentView }
        for avatar in avatars {
            if let level = levels[avatar.peerId] {
                avatar.updateAudioLevel(color: theme.colors.accent, value: level)
            } else {
                avatar.updateAudioLevel(color: theme.colors.accent, value: 0)
            }
        }
    }

    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.background
        borderColor = theme.colors.border
        joinButton.set(font: .medium(.text), for: .Normal)
        joinButton.set(text: strings().chatGroupCallJoin, for: .Normal)
        joinButton.sizeToFit(NSMakeSize(14, 8), .zero, thatFit: false)
        joinButton.layer?.cornerRadius = joinButton.frame.height / 2
        joinButton.set(color: theme.colors.underSelectedColor, for: .Normal)
        joinButton.set(background: theme.colors.accent, for: .Normal)
        joinButton.set(background: theme.colors.accent.highlighted, for: .Highlight)
        
    }
    
    override func layout() {
        super.layout()
        
        if let scheduleButton = scheduleButton {
            scheduleButton.centerY(x: frame.width - scheduleButton.frame.width - 23)
        }
        joinButton.centerY(x: frame.width - joinButton.frame.width - 23)
        
        let subviewsCount = max(avatarsContainer.subviews.filter { $0.layer?.opacity == 1.0 }.count, 1)
        
        if subviewsCount == 3 || subviewsCount == 0 {
            self.avatarsContainer.center()
        } else {
            let count = CGFloat(subviewsCount)
            let avatarSize: CGFloat = (count * 30) - ((count - 1) * 3)
            self.avatarsContainer.centerY(x: floorToScreenPixels(backingScaleFactor, (frame.width - avatarSize) / 2))
        }
        
        headerView.resize(frame.width - 100)

        
        headerView.setFrameOrigin(.init(x: 22, y: bounds.midY - headerView.frame.height))
        membersCountView.setFrameOrigin(.init(x: 22, y: bounds.midY))
                
        button.frame = bounds
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}


private final class ChatRequestChat : Control, ChatHeaderProtocol {
    private let chatInteraction:ChatInteraction
    private let dismiss:ImageButton = ImageButton()
    private let textView = TextView()
    
    
    private var _state: ChatHeaderState?
    
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        self._state = state
        super.init(frame: frame)

        dismiss.disableActions()
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = self.dismiss.sizeToFit()
        
        self.set(handler: { [weak self] control in
            if let window = control.kitWindow, let state = self?._state {
                switch state {
                case let .requestChat(_, _, text):
                    alert(for: window, info: text)
                default:
                    break
                }
            }
            self?.chatInteraction.openPendingRequests()
        }, for: .Click)
        
        dismiss.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            self.chatInteraction.dismissPeerStatusOptions()
        }, for: .SingleClick)

        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        addSubview(dismiss)
        addSubview(textView)
        self.style = ControlStyle(backgroundColor: theme.colors.background)

        self.border = [.Bottom]
        
        update(with: state, animated: false)

    }

    func update(with state: ChatHeaderState, animated: Bool) {
        _state = state
        switch state {
        case let .requestChat(_, text, _):
            let attr = NSMutableAttributedString()
            _ = attr.append(string: text, color: theme.colors.text, font: .normal(.text))
            attr.detectBoldColorInString(with: .medium(.text))
            let layout = TextViewLayout(attr)
            textView.update(layout)
            break
        default:
            break
        }
        updateLocalizationAndTheme(theme: theme)
        needsLayout = true

    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.backgroundColor = theme.colors.background
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
    }
    
    override func layout() {
        super.layout()
        dismiss.centerY(x: frame.width - 20 - dismiss.frame.width)
        textView.resize(frame.width - 60)
        textView.center()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

final class ChatPendingRequests : Control, ChatHeaderProtocol {
    private let dismiss:ImageButton = ImageButton()
    private let textView = TextView()
    private var avatars:[AvatarContentView] = []
    private let avatarsContainer = View(frame: NSMakeRect(0, 0, 30 * 3, 30))
    
    private struct Avatar : Comparable, Identifiable {
        static func < (lhs: Avatar, rhs: Avatar) -> Bool {
            return lhs.index < rhs.index
        }
        
        var stableId: PeerId {
            return peer.id
        }
        
        static func == (lhs: Avatar, rhs: Avatar) -> Bool {
            if lhs.index != rhs.index {
                return false
            }
            if !lhs.peer.isEqual(rhs.peer) {
                return false
            }
            return true
        }
        
        let peer: Peer
        let index: Int
    }

    private var peers:[Avatar] = []
    private let context: AccountContext
    
    required init(context: AccountContext, openAction:@escaping()->Void, dismissAction:@escaping([PeerId])->Void, state: ChatHeaderState, frame: NSRect) {
        self.context = context
        super.init(frame: frame)
        addSubview(avatarsContainer)
        avatarsContainer.isEventLess = true

        dismiss.disableActions()
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = self.dismiss.sizeToFit()
        
        self.set(handler: { _ in
            openAction()
        }, for: .Click)
        
        dismiss.set(handler: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            dismissAction(self.peers.map { $0.peer.id })
        }, for: .SingleClick)

        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        addSubview(dismiss)
        addSubview(textView)
        self.style = ControlStyle(backgroundColor: theme.colors.background)

        self.border = [.Bottom]
        
        update(with: state, animated: false)

    }

    func update(with state: ChatHeaderState, animated: Bool) {
      
        
        switch state {
        case let .pendingRequests(_, count, peers):
            let text = strings().chatHeaderRequestToJoinCountable(count)
            let layout = TextViewLayout(.initialize(string: text, color: theme.colors.accent, font: .medium(.text)), maximumNumberOfLines: 1)
            layout.measure(width: frame.width - 60)
            textView.update(layout)
            
            let duration: TimeInterval = 0.4
            let timingFunction: CAMediaTimingFunctionName = .spring

            
            let peers:[Avatar] = peers.reduce([], { current, value in
                var current = current
                if let peer = value.peer.peer {
                    current.append(.init(peer: peer, index: current.count))
                }
                return current
            })
            
            let (removed, inserted, updated) = mergeListsStableWithUpdates(leftList: self.peers, rightList: peers)
            
            for removed in removed.reversed() {
                let control = avatars.remove(at: removed)
                let peer = self.peers[removed]
                let haveNext = peers.contains(where: { $0.stableId == peer.stableId })
                control.updateLayout(size: NSMakeSize(30, 30), isClipped: false, animated: animated)
                if animated && !haveNext {
                    control.layer?.animateAlpha(from: 1, to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak control] _ in
                        control?.removeFromSuperview()
                    })
                    control.layer?.animateScaleSpring(from: 1.0, to: 0.2, duration: duration)
                } else {
                    control.removeFromSuperview()
                }
            }
            for inserted in inserted {
                let control = AvatarContentView(context: context, peer: inserted.1.peer, message: nil, synchronousLoad: false, size: NSMakeSize(30, 30))
                control.updateLayout(size: NSMakeSize(30, 30), isClipped: inserted.0 != 0, animated: animated)
                control.userInteractionEnabled = false
                control.setFrameSize(NSMakeSize(30, 30))
                control.setFrameOrigin(NSMakePoint(CGFloat(inserted.0) * 29, 0))
                avatars.insert(control, at: inserted.0)
                avatarsContainer.subviews.insert(control, at: inserted.0)
                if animated {
                    if let index = inserted.2 {
                        control.layer?.animatePosition(from: NSMakePoint(CGFloat(index) * 32, 0), to: control.frame.origin, timingFunction: timingFunction)
                    } else {
                        control.layer?.animateAlpha(from: 0, to: 1, duration: duration, timingFunction: timingFunction)
                        control.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: duration)
                    }
                }
            }
            for updated in updated {
                let control = avatars[updated.0]
                control.updateLayout(size: NSMakeSize(30, 30), isClipped: updated.0 != 0, animated: animated)
                let updatedPoint = NSMakePoint(CGFloat(updated.0) * 29, 0)
                if animated {
                    control.layer?.animatePosition(from: control.frame.origin - updatedPoint, to: .zero, duration: duration, timingFunction: timingFunction, additive: true)
                }
                control.setFrameOrigin(updatedPoint)
            }
            var index: CGFloat = 10
            for control in avatarsContainer.subviews.compactMap({ $0 as? AvatarContentView }) {
                control.layer?.zPosition = index
                index -= 1
            }
            
            self.peers = peers
            
        default:
            break
        }
        updateLocalizationAndTheme(theme: theme)
        needsLayout = true

    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.backgroundColor = theme.colors.background
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
    }
    
    override func layout() {
        super.layout()
        dismiss.centerY(x: frame.width - 20 - dismiss.frame.width)
        textView.resize(frame.width - 60)
        textView.center()
        self.avatarsContainer.centerY(x: 22)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}


private final class ChatRestartTopic : Control, ChatHeaderProtocol {
    private let chatInteraction:ChatInteraction
    private let textView = TextView()
    
    
    private var _state: ChatHeaderState?
    
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        self._state = state
        super.init(frame: frame)
        
        self.set(handler: { [weak self] control in
            self?.chatInteraction.restartTopic()
        }, for: .SingleClick)
        
        self.set(handler: { [weak self] _ in
            self?.textView.alphaValue = 0.8
        }, for: .Highlight)
        
        self.set(handler: { [weak self] _ in
            self?.textView.alphaValue = 1
        }, for: .Normal)
        
        self.set(handler: { [weak self] _ in
            self?.textView.alphaValue = 1
        }, for: .Hover)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        addSubview(textView)
        self.style = ControlStyle(backgroundColor: theme.colors.background)

        self.border = [.Bottom]
        
        update(with: state, animated: false)

    }

    func update(with state: ChatHeaderState, animated: Bool) {
        _state = state
        let attr = NSMutableAttributedString()
        _ = attr.append(string: strings().chatHeaderRestartTopic, color: theme.colors.accent, font: .normal(.text))
        let layout = TextViewLayout(attr)
        textView.update(layout)
        updateLocalizationAndTheme(theme: theme)
        needsLayout = true

    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.backgroundColor = theme.colors.background
    }
    
    override func layout() {
        super.layout()
        textView.resize(frame.width - 40)
        textView.center()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
