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
import Translate
import Postbox
import TGModernGrowingTextView
import Localization



protocol ChatHeaderProtocol {
    func update(with state: ChatHeaderState, animated: Bool)
    func remove(animated: Bool)
    
    func measure(_ width: CGFloat)
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition)
}

struct EmojiTag : Equatable {
    let emoji: String
    let tag: SavedMessageTags.Tag
    let file: TelegramMediaFile
}


struct ChatHeaderState : Identifiable, Equatable {
    enum Value : Equatable {
        case none
        case search(ChatSearchInteractions, Peer?, String?, [EmojiTag]?, EmojiTag?, ChatLocation)
        case addContact(block: Bool, autoArchived: Bool)
        case requestChat(String, String)
        case shareInfo
        case pinned(ChatPinnedMessage, ChatLiveTranslateContext.State.Result?, doNotChangeTable: Bool)
        case report(autoArchived: Bool, status: PeerEmojiStatus?)
        case promo(EngineChatList.AdditionalItem.PromoInfo.Content)
        case pendingRequests(Int, [PeerInvitationImportersState.Importer])
        case restartTopic
        case removePaidMessages(Peer, StarsAmount)
        
        static func ==(lhs:Value, rhs: Value) -> Bool {
            switch lhs {
            case let .pinned(pinnedId, translate, value):
                if case .pinned(pinnedId, translate, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .addContact(block, autoArchive):
                if case .addContact(block, autoArchive) = rhs {
                    return true
                } else {
                    return false
                }
            case let .search(_, _, _, tags, selected, chatLocation):
                if case .search(_, _, _, tags, selected, chatLocation) = rhs {
                    return true
                } else {
                    return false
                }
            default:
                return lhs.stableId == rhs.stableId
            }
        }
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
            case .removePaidMessages:
                return 10
            }
        }
    }
    
    struct BotAdMessage : Equatable {
        let header: TextViewLayout
        let text: TextViewLayout
        let dismissLayout: TextViewLayout
        let adHeader: TextViewLayout
        let message: Message
        init(message: Message, chatInteraction: ChatInteraction) {
            self.message = message
            
            let dismissLayout = TextViewLayout(.initialize(string: strings().chatAdWhatThis, color: theme.colors.accent, font: .normal(.small)), alignment: .center)
            dismissLayout.measure(width: .greatestFiniteMagnitude)

            self.dismissLayout = dismissLayout
            
            let context = chatInteraction.context
            
            adHeader = .init(.initialize(string: strings().chatBotAdAd, color: theme.colors.accent, font: .medium(.text)))
            adHeader.measure(width: .greatestFiniteMagnitude)
            
            let headerAttr = NSMutableAttributedString()
            
            headerAttr.append(string: message.author?.displayTitle ?? "", color: theme.colors.text, font: .medium(.text))
            
            let headerLayout = TextViewLayout(headerAttr)
            self.header = headerLayout
            
            let entities = message.entities
            
            let attr = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: entities)], for: message.text, message: nil, context: context, fontSize: .text, openInfo: chatInteraction.openInfo, textColor: theme.colors.text, linkColor: theme.colors.link, isDark: theme.colors.isDark, bubbled: theme.bubbled, confirm: false).mutableCopy() as! NSMutableAttributedString
            
            InlineStickerItem.apply(to: attr, associatedMedia: message.associatedMedia, entities: entities, isPremium: context.isPremium)
            
            let textLayout = TextViewLayout(attr)
            
            self.text = textLayout

        }
        
        var height: CGFloat {
            var height: CGFloat = 10
            height += adHeader.layoutSize.height + 4
            height += header.layoutSize.height
            height += 4
            height += text.layoutSize.height
            height += 10
            return height
        }
        
        func measure(_ width: CGFloat) {
            self.header.measure(width: width - 40 - 2 - dismissLayout.layoutSize.width - 8)
            self.text.measure(width: width - 40)
        }
    }
    
    var main: Value
    var voiceChat: ChatActiveGroupCallInfo?
    var translate: ChatPresentationInterfaceState.TranslateState?
    var botManager: ChatBotManagerData?
    var botAd: BotAdMessage?
    
    var stableId:Int {
        return main.stableId
    }
    
    var primaryClass: AnyClass? {
        switch main {
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
        case .removePaidMessages:
            return ChatRemovePaidMessage.self
        case .none:
            return nil
        }
    }
    var secondaryClass: AnyClass {
        return ChatGroupCallView.self
    }
    var thirdClass: AnyClass {
        return ChatTranslateHeader.self
    }
    var fourthClass: AnyClass {
        return ChatBotManager.self
    }
    
    var fifthClass: AnyClass {
        return ChatAdHeaderView.self
    }
    
    var height:CGFloat {
        return primaryHeight + secondaryHeight + thirdHeight + fourthHeight
    }

    var primaryHeight:CGFloat {
        var height: CGFloat = 0
        switch main {
        case .none:
            height += 0
        case let .search(_, _, _, emojiTags, _, _):
            height += 44
            if emojiTags != nil {
                height += 35
            }
        case let .report(_, status):
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
            height += 40
        case .removePaidMessages:
            height += 50
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
    var thirdHeight:CGFloat {
        var height: CGFloat = 0
        if let _ = translate {
            height += 36
        }
        return height
    }
    var fourthHeight:CGFloat {
        var height: CGFloat = 0
        if let _ = botManager {
            height += 44
        }
        if let botAd = botAd {
            height += botAd.height
        }
        return height
    }
    
    var toleranceHeight: CGFloat {
        return 0
//        switch main {
//        case let .pinned(_, doNotChangeTable):
//            return doNotChangeTable ? height - primaryHeight : height
//        default:
//            return height
//        }
    }
    
    func measure(_ width: CGFloat) {
        self.botAd?.measure(width)
    }
}


class ChatHeaderController {
    
    
    private var _headerState:ChatHeaderState = .init(main: .none)
    private let chatInteraction:ChatInteraction
    
    private(set) var currentView:View?

    
    private var primaryInited = false
    private var seconderyInited = false
    private var thirdInited = false
    private var fourthInited = false

    private var primaryView: View? {
        didSet {
            if oldValue == nil, primaryView != nil {
                primaryInited = false
            }
        }
    }
    private var seconderyView : View? {
        didSet {
            if oldValue == nil, seconderyView != nil {
                seconderyInited = false
            }
        }
    }
    private var thirdView : View? {
        didSet {
            if oldValue == nil, thirdView != nil {
                thirdInited = false
            }
        }
    }
    private var fourthView : View? {
        didSet {
            if oldValue == nil, fourthView != nil {
                fourthInited = false
            }
        }
    }

    var state:ChatHeaderState {
        return _headerState
    }
    
    func measure(_ width: CGFloat) {
        (self.primaryView as? ChatHeaderProtocol)?.measure(width)
        (self.seconderyView as? ChatHeaderProtocol)?.measure(width)
        (self.thirdView as? ChatHeaderProtocol)?.measure(width)
        (self.fourthView as? ChatHeaderProtocol)?.measure(width)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        if let view = self.primaryView {
            transition.updateFrame(view: view, frame: NSMakeRect(0, view.frame.minY, size.width, view.frame.height))
            
            let layoutTransition = primaryInited ? transition : .immediate
            primaryInited = true
            (view as? ChatHeaderProtocol)?.updateLayout(size: view.frame.size, transition: layoutTransition)
        }
        if let view = self.seconderyView {
            transition.updateFrame(view: view, frame: NSMakeRect(0, view.frame.minY, size.width, view.frame.height))
            let layoutTransition = seconderyInited ? transition : .immediate
            seconderyInited = true
            (view as? ChatHeaderProtocol)?.updateLayout(size: view.frame.size, transition: layoutTransition)
        }
        if let view = self.thirdView {
            transition.updateFrame(view: view, frame: NSMakeRect(0, view.frame.minY, size.width, view.frame.height))
            let layoutTransition = thirdInited ? transition : .immediate
            thirdInited = true
            (view as? ChatHeaderProtocol)?.updateLayout(size: view.frame.size, transition: layoutTransition)
        }
        if let view = self.fourthView {
            transition.updateFrame(view: view, frame: NSMakeRect(0, view.frame.minY, size.width, view.frame.height))
            let layoutTransition = fourthInited ? transition : .immediate
            fourthInited = true
            (view as? ChatHeaderProtocol)?.updateLayout(size: view.frame.size, transition: layoutTransition)
        }
    }
    
    func updateState(_ state:ChatHeaderState, animated:Bool, for view:View, inset: CGFloat, relativeView: NSView?) -> Void {
        if _headerState != state {
            _headerState = state
            

            let (primary, secondary, third, fourth) = viewIfNecessary(
                primarySize: NSMakeSize(view.frame.width - inset, state.primaryHeight),
                secondarySize: NSMakeSize(view.frame.width - inset, state.secondaryHeight),
                thirdSize: NSMakeSize(view.frame.width - inset, state.thirdHeight),
                fourthSize: NSMakeSize(view.frame.width - inset, state.fourthHeight),
                animated: animated,
                p_v: self.primaryView,
                s_v: self.seconderyView,
                t_v: self.thirdView,
                f_v: self.fourthView
            )
            

            let previousPrimary = self.primaryView
            let previousSecondary = self.seconderyView
            let previousThird = self.thirdView
            let previousFourth = self.fourthView

            self.primaryView = primary
            self.seconderyView = secondary
            self.thirdView = third
            self.fourthView = fourth
            


            var removed: [View] = []
            var added: [(view: View, fromPosition: NSPoint, toPosition: NSPoint, aboveView: View?)] = []
            var updated: [(view: View, position: NSPoint, aboveView: View?)] = []

            // Define the views and their respective heights
            var viewInfos: [(name: String, current: View?, previous: View?, height: CGFloat)] = []
            
            viewInfos.append(("secondary", secondary, previousSecondary, state.secondaryHeight))
            viewInfos.append(("primary", primary, previousPrimary, state.primaryHeight))
            viewInfos.append(("third", third, previousThird, state.thirdHeight))

            
            if let fourth, fourth.isKind(of: state.fifthClass) {
                viewInfos.append(("fourth", fourth, previousFourth, state.fourthHeight))
            } else {
                viewInfos.insert(("fourth", fourth, previousFourth, state.fourthHeight), at: 0)
            }

            var cumulativeY: CGFloat = 0
            var positions: [String: NSPoint] = [:]
            for info in viewInfos {
                positions[info.name] = NSMakePoint(0, cumulativeY)
                if info.current != nil {
                    cumulativeY += info.height
                }
            }

            var cumulativeHeightsBelow: [String: CGFloat] = [:]
            var cumulativeHeightBelow: CGFloat = 0
            for info in viewInfos.reversed() {
                cumulativeHeightsBelow[info.name] = cumulativeHeightBelow
                if info.current != nil {
                    cumulativeHeightBelow += info.height
                }
            }

            var lastView: View? = nil
            for info in viewInfos {
                let (name, currentView, previousView, _) = info
                let toPosition = positions[name]!
                let aboveView = lastView

                // Determine if the view was added, removed, or updated
                if previousView == nil || previousView != currentView {
                    if let previousView = previousView {
                        removed.append(previousView)
                    }
                    if let currentView = currentView {
                        // Adjust the fromPosition based on your animation requirements
                        let fromPositionY = cumulativeHeightsBelow[name]! - state.secondaryHeight - currentView.frame.height
                        let fromPosition = NSMakePoint(0, fromPositionY)
                        added.append((view: currentView, fromPosition: fromPosition, toPosition: toPosition, aboveView: aboveView))
                        lastView = currentView
                    }
                } else if let currentView = currentView {
                    updated.append((view: currentView, position: toPosition, aboveView: aboveView))
                    lastView = currentView
                }
            }

            if !added.isEmpty || primary != nil || secondary != nil || third != nil || fourth != nil {
                let current: View
                if let v = currentView {
                    current = v
                    current.change(size: NSMakeSize(view.frame.width - inset, state.height), animated: animated)
                } else {
                    current = View(frame: NSMakeRect(inset, 0, view.frame.width - inset, state.height))
                    if let relativeView {
                        view.addSubview(current, positioned: .below, relativeTo: relativeView)
                    } else {
                        view.addSubview(current)
                    }
                    self.currentView = current
                }

                for (view, position, aboveView) in updated {
                    if let aboveView = aboveView {
                        current.addSubview(view, positioned: .below, relativeTo: aboveView)
                    } else {
                        current.addSubview(view)
                    }
                    view.change(pos: position, animated: animated)
                }

                for view in removed {
                    if let view = view as? ChatHeaderProtocol {
                        view.remove(animated: animated)
                    }
                    if animated {
                        view.layer?.animatePosition(
                            from: view.frame.origin,
                            to: NSMakePoint(0, view.frame.minY - view.frame.height),
                            duration: 0.2,
                            removeOnCompletion: false,
                            completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            }
                        )
                    } else {
                        view.removeFromSuperview()
                    }
                }

                for (view, fromPosition, toPosition, aboveView) in added {
                    let justAdded = view.superview == nil
                    if let aboveView = aboveView {
                        current.addSubview(view, positioned: .below, relativeTo: aboveView)
                    } else {
                        current.addSubview(view)
                    }
                    view.setFrameOrigin(toPosition)

                    if animated {
                        view.layer?.animatePosition(from: fromPosition, to: toPosition, duration: 0.2)
                        // Uncomment the following line if you need to animate alpha
                        // view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    } else if justAdded, current.superview != nil {
                        // view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
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
    
    private func viewIfNecessary(primarySize: NSSize, secondarySize: NSSize, thirdSize: NSSize, fourthSize: NSSize, animated: Bool, p_v: View?, s_v: View?, t_v: View?, f_v: View?) -> (primary: View?, secondary: View?, third: View?, fourth: View?) {
        
        let primary:View?
        let secondary:View?
        let third: View?
        var fourth: View?

        let primaryRect: NSRect = .init(origin: .zero, size: primarySize)
        let secondaryRect: NSRect = .init(origin: .zero, size: secondarySize)
        let thirdRect: NSRect = .init(origin: .zero, size: thirdSize)
        let fourthRect: NSRect = .init(origin: .zero, size: fourthSize)

        if p_v == nil || p_v?.className != NSStringFromClass(_headerState.primaryClass ?? NSView.self)  {
            switch _headerState.main {
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
            case .removePaidMessages:
                primary = ChatRemovePaidMessage(chatInteraction, state: _headerState, frame: primaryRect)
            case .none:
                primary = nil
            }
        } else {
            primary = p_v
            (primary as? ChatHeaderProtocol)?.update(with: _headerState, animated: animated)
        }
        
        if let _ = self._headerState.voiceChat {
            if s_v == nil || s_v?.className != NSStringFromClass(_headerState.secondaryClass) {
                secondary = ChatGroupCallView(chatInteraction.joinGroupCall, context: chatInteraction.context, state: _headerState, frame: secondaryRect)
            } else {
                secondary = s_v
                (secondary as? ChatHeaderProtocol)?.update(with: _headerState, animated: animated)
            }
        } else {
            secondary = nil
        }
        
        if let _ = self._headerState.translate {
            if t_v == nil || t_v?.className != NSStringFromClass(_headerState.thirdClass) {
                third = ChatTranslateHeader(chatInteraction, state: _headerState, frame: thirdRect)
            } else {
                third = t_v
                (third as? ChatHeaderProtocol)?.update(with: _headerState, animated: animated)
            }
        } else {
            third = nil
        }
        
        if let _ = self._headerState.botManager {
            if f_v == nil || f_v?.className != NSStringFromClass(_headerState.fourthClass) {
                fourth = ChatBotManager(chatInteraction, state: _headerState, frame: thirdRect)
            } else {
                fourth = f_v
                (fourth as? ChatHeaderProtocol)?.update(with: _headerState, animated: animated)
            }
        } else {
            fourth = nil
        }
        
        if let _ = self._headerState.botAd {
            if f_v == nil || f_v?.className != NSStringFromClass(_headerState.fifthClass) {
                fourth = ChatAdHeaderView(chatInteraction, state: _headerState, frame: thirdRect)
            } else {
                fourth = f_v
                (fourth as? ChatHeaderProtocol)?.update(with: _headerState, animated: animated)
            }
        } else {
            fourth = nil
        }


        primary?.setFrameSize(primarySize)
        secondary?.setFrameSize(secondarySize)
        third?.setFrameSize(thirdSize)
        fourth?.setFrameSize(fourthSize)
        
        return (primary: primary, secondary: secondary, third: third, fourth: fourth)
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
    let searchRequest:(String, PeerId?, SearchMessagesState?, [EmojiTag]) -> Signal<([Message], SearchMessagesState?), NoError>
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
                verifyAlert_button(for: chatInteraction.context.window, header: strings().chatProxySponsoredAlertHeader, information: strings().chatProxySponsoredAlertText, cancel: "", option: strings().chatProxySponsoredAlertSettings, successHandler: { [weak chatInteraction] result in
                    switch result {
                    case .thrid:
                        chatInteraction?.openProxySettings()
                    default:
                        break
                    }
                })
            case .psa:
                if let learnMore = kind.learnMore {
                    verifyAlert_button(for: chatInteraction.context.window, header: kind.title, information: kind.text, cancel: "", option: learnMore, successHandler: { result in
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
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        switch state.main {
        case let .promo(kind):
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
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let node = node {
            node.measureSize(size.width - 70)
            container.setFrameSize(NSSize(width: size.width - 70, height: node.size.height))
        }

        transition.updateFrame(view: container, frame: container.centerFrameY(x: 20))

        let dismissX = size.width - 20 - dismiss.frame.width
        transition.updateFrame(view: dismiss, frame: dismiss.centerFrameY(x: dismissX))

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
    
    private var inlineButton: TextButton? = nil
    private var _state: ChatHeaderState
    private let particleList: VerticalParticleListControl = VerticalParticleListControl()
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {

        self.chatInteraction = chatInteraction
        _state = state
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
            if self.chatInteraction.chatLocation.threadMsgId == pinnedMessage.messageId {
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
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        self._state = state
        switch state.main {
        case let .pinned(message, translate, _):
            self.update(message, translate: translate, animated: animated)
        default:
            break
        }
    }
    private var translate: ChatLiveTranslateContext.State.Result?
    
    private func update(_ pinnedMessage: ChatPinnedMessage, translate: ChatLiveTranslateContext.State.Result?, animated: Bool) {
        
        
        
        let animated = animated && (self.pinnedMessage != nil && (!pinnedMessage.isLatest || (self.pinnedMessage?.isLatest != pinnedMessage.isLatest))) && self.translate == translate

        
        particleList.update(count: pinnedMessage.totalCount, selectedIndex: pinnedMessage.index, animated: animated)
        
        self.dismiss.set(image: pinnedMessage.totalCount <= 1 ? theme.icons.dismissPinned : theme.icons.chat_pinned_list, for: .Normal)
        
        if pinnedMessage.messageId != self.pinnedMessage?.messageId || translate != self.translate {
            let oldContainer = self.container
            let newContainer = ChatAccessoryView()
            newContainer.userInteractionEnabled = false
                        
            let newNode = ReplyModel(message: nil, replyMessageId: pinnedMessage.messageId, context: chatInteraction.context, replyMessage: pinnedMessage.message, isPinned: true, headerAsName: chatInteraction.chatLocation.threadMsgId != nil, customHeader: pinnedMessage.isLatest ? nil : pinnedMessage.totalCount == 2 ? strings().chatHeaderPinnedPrevious : strings().chatHeaderPinnedMessageNumer(pinnedMessage.totalCount - pinnedMessage.index), drawLine: false, translate: translate)
            
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
            
            var telegramCall: TelegramMediaWebpageLoadedContent? = nil
            
            if let media = pinnedMessage.message?.media.first as? TelegramMediaWebpage {
                switch media.content {
                case let .Loaded(content):
                    if content.type == "telegram_call" {
                        telegramCall = content
                    }
                default:
                    break
                }
            }
            
            if let content = telegramCall {
                
                self.dismiss.isHidden = true
                let current: TextButton
                if let view = self.inlineButton {
                    current = view
                } else {
                    current = TextButton()
                    current.autohighlight = false
                    current.scaleOnClick = true
                    
                    
                    
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                    self.inlineButton = current
                }
                current.setSingle(handler: { [weak self] _ in
                    if let chatInteraction = self?.chatInteraction {
                        let link = inApp(for: content.url.nsstring, context: chatInteraction.context, openInfo: chatInteraction.openInfo)
                        execute(inapp: link)
                    }
                }, for: .Click)
                
                addSubview(current)

                current.set(text: strings().chatJoinGroupCall, for: .Normal)
                current.set(font: .medium(.text), for: .Normal)
                current.set(color: theme.colors.underSelectedColor, for: .Normal)
                current.set(background: theme.colors.accent, for: .Normal)
                current.sizeToFit(NSMakeSize(6, 8), .zero, thatFit: false)
                current.layer?.cornerRadius = current.frame.height / 2
                
            } else {
                if let message = pinnedMessage.message, let replyMarkup = pinnedMessage.message?.replyMarkup, replyMarkup.hasButtons, replyMarkup.rows.count == 1, replyMarkup.rows[0].buttons.count == 1 {
                    self.installReplyMarkup(replyMarkup.rows[0].buttons[0], message: message, animated: animated)
                } else {
                    self.deinstallReplyMarkup(animated: animated)
                }
            }
                        
            self.container = newContainer
            self.node = newNode
        }
        self.pinnedMessage = pinnedMessage
        self.translate = translate
        updateLocalizationAndTheme(theme: theme)
    }
    
    private func installReplyMarkup(_ button: ReplyMarkupButton, message: Message, animated: Bool) {
        self.dismiss.isHidden = true
        let current: TextButton
        if let view = self.inlineButton {
            current = view
        } else {
            current = TextButton()
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
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        var availableWidth: CGFloat

        if let inlineButton = inlineButton {
            availableWidth = size.width - (40 + inlineButton.frame.width)
        } else {
            availableWidth = size.width - (40 + (dismiss.isHidden ? 0 : 30))
        }

        if let node = node {
            node.measureSize(availableWidth)
            container.setFrameSize(NSSize(width: availableWidth, height: node.size.height))
        }

        transition.updateFrame(view: container, frame: container.centerFrameY(x: 24))

        let dismissX = size.width - 20 - dismiss.frame.width
        transition.updateFrame(view: dismiss, frame: dismiss.centerFrameY(x: dismissX))

        if let inlineButton = inlineButton {
            let buttonX = size.width - 20 - inlineButton.frame.width
            transition.updateFrame(view: inlineButton, frame: inlineButton.centerFrameY(x: buttonX))
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
    private let report:TextButton = TextButton()
    private let unarchiveButton = TextButton()
    private let dismiss:ImageButton = ImageButton()

    private var statusLayer: InlineStickerItemLayer?
    
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
    
    func measure(_ width: CGFloat) {
        
    }

    func remove(animated: Bool) {
        
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        buttonsContainer.removeAllSubviews()
        switch state.main {
        case let .report(autoArchived, status):
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
                
                
                let range = attr.string.nsstring.range(of: clown)
                if range.location != NSNotFound {
                    attr.addAttribute(TextInputAttributes.embedded, value: InlineStickerItem(source: .attribute(.init(fileId: status.fileId, file: nil, emoji: ""))), range: range)
                }
                let layout = TextViewLayout(attr, alignment: .center)
                layout.measure(width: frame.width - 80)
                layout.interactions = globalLinkExecutor
                current.update(layout)
                
                self.statusLayer?.removeFromSuperlayer()
                self.statusLayer = nil
                
                for embedded in layout.embeddedItems {
                    let rect = embedded.rect.insetBy(dx: -1.5, dy: -1.5)
                    let view = InlineStickerItemLayer(account: chatInteraction.context.account, inlinePacksContext: chatInteraction.context.inlinePacksContext, emoji: .init(fileId: status.fileId, file: nil, emoji: ""), size: rect.size)
                    view.frame = rect
                    current.addEmbeddedLayer(view)
                    self.statusLayer = view
                    view.isPlayable = true
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
        self.statusLayer?.isPlayable = window != nil
    }

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, layer.frame.height - .borderSize, layer.frame.width, .borderSize))
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: report, frame: report.centerFrame())

        let dismissX = size.width - dismiss.frame.width - 20
        let dismissY = floorToScreenPixels(backingScaleFactor, (44 - dismiss.frame.height) / 2)
        let dismissFrame = NSRect(x: dismissX, y: dismissY, width: dismiss.frame.width, height: dismiss.frame.height)
        transition.updateFrame(view: dismiss, frame: dismissFrame)

        let buttonsContainerFrame = NSRect(x: 0, y: 0, width: size.width, height: 44 - .borderSize)
        transition.updateFrame(view: buttonsContainer, frame: buttonsContainerFrame)

        var buttons: [Control] = []
        if report.superview != nil {
            buttons.append(report)
        }
        if unarchiveButton.superview != nil {
            buttons.append(unarchiveButton)
        }

        let buttonWidth: CGFloat = floor(buttonsContainerFrame.width / CGFloat(max(buttons.count, 1)))
        for (index, button) in buttons.enumerated() {
            let buttonFrame = NSRect(x: CGFloat(index) * buttonWidth, y: 0, width: buttonWidth, height: buttonsContainerFrame.height)
            transition.updateFrame(view: button, frame: buttonFrame)
        }

        if let textView = textView {
            let textViewFrame = textView.centerFrameX(y: size.height - textView.frame.height - 5)
            transition.updateFrame(view: textView, frame: textViewFrame)
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
    private let share:TextButton = TextButton()
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
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        
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
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
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
    private let add:TextButton = TextButton()
    private let dismiss:ImageButton = ImageButton()
    private let blockButton: TextButton = TextButton()
    private let unarchiveButton = TextButton()
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
    
    func measure(_ width: CGFloat) {
        
    }

    func remove(animated: Bool) {
        
    }
    
    func update(with state: ChatHeaderState, animated: Bool) {
        switch state.main {
        case let .addContact(canBlock, autoArchived):
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
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let dismissX = size.width - dismiss.frame.width - 20
        transition.updateFrame(view: dismiss, frame: dismiss.centerFrameY(x: dismissX))

        var buttons: [Control] = []
        if add.superview != nil {
            buttons.append(add)
        }
        if blockButton.superview != nil {
            buttons.append(blockButton)
        }
        if unarchiveButton.superview != nil {
            buttons.append(unarchiveButton)
        }

        let buttonsContainerFrame = NSRect(x: 0, y: 0, width: size.width, height: size.height - .borderSize)
        transition.updateFrame(view: buttonsContainer, frame: buttonsContainerFrame)

        let buttonWidth: CGFloat = floor(buttonsContainerFrame.width / CGFloat(max(buttons.count, 1)))
        for (index, button) in buttons.enumerated() {
            let buttonFrame = NSRect(x: CGFloat(index) * buttonWidth, y: 0, width: buttonWidth, height: buttonsContainerFrame.height)
            transition.updateFrame(view: button, frame: buttonFrame)
        }
    }

    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    private let joinButton = TextButton()
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
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        
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
                if let participantPeer = participant.peer {
                    topPeers.append(Avatar(peer: participantPeer._asPeer(), index: index))
                }
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
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        avatarsContainer.isHidden = size.width < 300

        if let scheduleButton = scheduleButton {
            let scheduleX = size.width - scheduleButton.frame.width - 23
            transition.updateFrame(view: scheduleButton, frame: scheduleButton.centerFrameY(x: scheduleX))
        }

        let joinX = size.width - joinButton.frame.width - 23
        transition.updateFrame(view: joinButton, frame: joinButton.centerFrameY(x: joinX))

        let visibleSubviewsCount = max(avatarsContainer.subviews.filter { $0.layer?.opacity == 1.0 }.count, 1)

        if visibleSubviewsCount == 3 || visibleSubviewsCount == 0 {
            transition.updateFrame(view: avatarsContainer, frame: avatarsContainer.centerFrame())
        } else {
            let count = CGFloat(visibleSubviewsCount)
            let avatarSize: CGFloat = (count * 30) - ((count - 1) * 3)
            let x = floorToScreenPixels(backingScaleFactor, (size.width - avatarSize) / 2)
            transition.updateFrame(view: avatarsContainer, frame: avatarsContainer.centerFrameY(x: x))
        }

        headerView.resize(size.width - 100)

        let headerOrigin = NSPoint(x: 22, y: size.height / 2 - headerView.frame.height)
        transition.updateFrame(view: headerView, frame: NSRect(origin: headerOrigin, size: headerView.frame.size))

        let membersOrigin = NSPoint(x: 22, y: size.height / 2)
        transition.updateFrame(view: membersCountView, frame: NSRect(origin: membersOrigin, size: membersCountView.frame.size))

        transition.updateFrame(view: button, frame: NSRect(origin: .zero, size: size))
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
            if let window = control._window, let state = self?._state {
                switch state.main {
                case let .requestChat(_, text):
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
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        _state = state
        switch state.main {
        case let .requestChat(text, _):
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
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: dismiss, frame: dismiss.centerFrameY(x: size.width - 20 - dismiss.frame.width))

        let textWidth = size.width - 60
        textView.resize(textWidth)
     
        transition.updateFrame(view: textView, frame: textView.centerFrame())
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
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        
    }

    func update(with state: ChatHeaderState, animated: Bool) {
      
        
        switch state.main {
        case let .pendingRequests(count, peers):
            let text = strings().chatHeaderRequestToJoinCountable(count)
            let layout = TextViewLayout(.initialize(string: text, color: theme.colors.accent, font: .medium(.text)), maximumNumberOfLines: 1)
            layout.measure(width: frame.width - 60)
            textView.update(layout)
            
            let duration: TimeInterval = 0.4
            let timingFunction: CAMediaTimingFunctionName = .spring

            
            let peers:[Avatar] = peers.prefix(3).reduce([], { current, value in
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
                control.setFrameOrigin(NSMakePoint(CGFloat(inserted.0) * 27, 0))
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
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        updateLayout(size: self.frame.size, transition: transition)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.backgroundColor = theme.colors.background
        self.dismiss.set(image: theme.icons.dismissPinned, for: .Normal)
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let dismissX = size.width - 20 - dismiss.frame.width
        transition.updateFrame(view: dismiss, frame: dismiss.centerFrameY(x: dismissX))

        textView.resize(size.width - 60 - avatarsContainer.frame.width)
        transition.updateFrame(view: textView, frame: textView.centerFrame())

        transition.updateFrame(view: avatarsContainer, frame: avatarsContainer.centerFrameY(x: 22))

        let minX = 30 + CGFloat(avatars.count) * 15
        let adjustedTextX = max(textView.frame.minX, minX)
        let adjustedTextOrigin = NSPoint(x: adjustedTextX, y: textView.frame.minY)
        transition.updateFrame(view: textView, frame: NSRect(origin: adjustedTextOrigin, size: textView.frame.size))
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
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        
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
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}


private final class ChatTranslateHeader : Control, ChatHeaderProtocol {
    
    private var container: View = View()
    private let chatInteraction:ChatInteraction
    
    private var textView = TextButton()
    private var action = ImageButton()
    
    private var _state: ChatHeaderState?
    
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        self._state = state
        super.init(frame: frame)
        
        self.set(handler: { [weak self] control in
            self?.chatInteraction.toggleTranslate()
        }, for: .Click)
        
        self.set(handler: { [weak self] _ in
            self?.textView.alphaValue = 0.8
        }, for: .Highlight)
        
        self.set(handler: { [weak self] _ in
            self?.textView.alphaValue = 1
        }, for: .Normal)
        
        self.set(handler: { [weak self] _ in
            self?.textView.alphaValue = 1
        }, for: .Hover)
        
       
        
        
        self.container = View()
        
        container.addSubview(textView)
        self.addSubview(action)
        
        addSubview(container)
        
        self.style = ControlStyle(backgroundColor: theme.colors.background)

        self.border = [.Bottom]
        
        update(with: state, animated: false)
        
        action.contextMenu = { [weak self] in
            return self?.makeContextMenu()
        }

    }
    
    private func makeContextMenu() -> ContextMenu? {
        guard let translate = self._state?.translate else {
            return nil
        }
        
        let menu = ContextMenu()
        var items: [ContextMenuItem] = []

        if translate.paywall {
            items.append(ContextMenuItem(strings().chatTranslateMenuHide, handler: { [weak self] in
                self?.chatInteraction.hideTranslation()
            }, itemImage: MenuAnimation.menu_clear_history.value))
            
            menu.items = items
            return menu
        }
        
        
        let other = ContextMenuItem(strings().chatTranslateMenuTo, itemImage: MenuAnimation.menu_translate.value)
        
        var codes = Translate.codes.sorted(by: { lhs, rhs in
            let lhsSelected = lhs.code.contains(translate.to)
            let rhsSelected = rhs.code.contains(translate.to)
            if lhsSelected && !rhsSelected {
                return true
            } else if !lhsSelected && rhsSelected {
                return false
            } else {
                return lhs.language < rhs.language
            }
        })
        
        let codeIndex = codes.firstIndex(where: {
            $0.code.contains(appAppearance.languageCode)
        })
        if let codeIndex = codeIndex {
            codes.move(at: codeIndex, to: 0)
        }
        
        let submenu = ContextMenu()
        
        for code in codes {
            submenu.addItem(ContextMenuItem(code.language, handler: { [weak self] in
                if let first = code.code.first {
                    self?.chatInteraction.translateTo(first)
                }
            }, itemImage: code.code.contains(translate.to) ? MenuAnimation.menu_check_selected.value : nil))
        }
        other.submenu = submenu
        
        items.append(other)
                
        if let from = translate.from, let language = Translate.find(from) {
            items.append(ContextMenuItem(strings().chatTranslateMenuDoNotTranslate(_NSLocalizedString("Translate.Language.\(language.language)")), handler: { [weak self] in
                self?.chatInteraction.doNotTranslate(from)
            }, itemImage: MenuAnimation.menu_restrict.value))
        }
        
        items.append(ContextSeparatorItem())
        items.append(ContextMenuItem(strings().chatTranslateMenuHide, handler: { [weak self] in
            self?.chatInteraction.hideTranslation()
        }, itemImage: MenuAnimation.menu_clear_history.value))
        
        
        //items.append(ContextMenuItem("Read about transl"))
        menu.items = items
        
        return menu
        
    }
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        let updated = state.translate?.translate != _state?.translate?.translate
        _state = state
        
        if updated || !animated {
            let container = View(frame: bounds)
            let textView = TextButton()
            textView.userInteractionEnabled = false
            textView.autohighlight = false
            textView.isEventLess = true
            textView.disableActions()
            textView.animates = false
            container.addSubview(textView)
            
            let removeTo = state.translate?.translate == true ? NSMakePoint(0, frame.height) : NSMakePoint(0, -frame.height)
            let appearFrom = state.translate?.translate == true ? NSMakePoint(0, -frame.height) : NSMakePoint(0, frame.height)
            
            performSubviewPosRemoval(self.container, pos: removeTo, animated: animated)
            self.container = container
            
            if animated {
                container.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                container.layer?.animatePosition(from: appearFrom, to: .zero)
            }
            self.textView = textView
            addSubview(container, positioned: .below, relativeTo: action)
        }
        
        textView.set(font: .normal(.text), for: .Normal)
        textView.set(color: theme.colors.accent, for: .Normal)
        textView.set(image: theme.icons.chat_translate, for: .Normal)
        
        action.set(image: theme.icons.chatActions, for: .Normal)
        action.sizeToFit(NSZeroSize, NSMakeSize(36, 36), thatFit: true)
        action.autohighlight = false
        action.scaleOnClick = true
        
        if let translate = state.translate {
            let language = Translate.find(translate.to)
            if let language = language {
                if translate.translate {
                    if let from = translate.from.flatMap(Translate.find) {
                        textView.set(text: strings().chatTranslateShowOriginal + " (\(from.language))", for: .Normal)
                    } else {
                        textView.set(text: strings().chatTranslateShowOriginal, for: .Normal)

                    }
                } else {
                    let toString = _NSLocalizedString("Translate.Language.\(language.language)")
                    textView.set(text: strings().chatTranslateTo(toString), for: .Normal)
                }
                textView.sizeToFit(NSMakeSize(0, 6))
            }
        }
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
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: container, frame: size.bounds)
        transition.updateFrame(view: textView, frame: textView.centerFrame())
        transition.updateFrame(view: action, frame: action.centerFrameY(x: size.width - action.frame.width - 17))
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}




private final class ChatBotManager : Control, ChatHeaderProtocol {
    private let chatInteraction:ChatInteraction
    private let setup:ImageButton = ImageButton()
    private let avatar = AvatarControl(font: .avatar(.title))
    private let textView = TextView()
    private let infoView = TextView()
    
    private let stop = TextButton()
    
    private var _state: ChatHeaderState?
    
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        self._state = state
        super.init(frame: frame)
        
        avatar.setFrameSize(NSMakeSize(30, 30))

        setup.disableActions()
        setup.autohighlight = false
        setup.scaleOnClick = true
        
        stop.scaleOnClick = true
        stop.autohighlight = false
        
        let context = self.chatInteraction.context
        let peerId = self.chatInteraction.peerId
        
        self.set(handler: { [weak self] _ in
            guard let self, let data = self._state?.botManager, let url = data.settings.manageUrl else {
                return
            }
            execute(inapp: inApp(for: url as NSString, context: context, openInfo: self.chatInteraction.openInfo))
        }, for: .Click)

        
        stop.set(handler: { _ in
            context.engine.peers.toggleChatManagingBotIsPaused(chatId: peerId)
        }, for: .Click)

        setup.contextMenu = { [weak self] in
            
            guard let data = self?._state?.botManager else {
                return nil
            }
            
            let menu = ContextMenu()
            

            menu.addItem(ContextMenuItem(strings().chatBotManagerContextManage, handler: {
                context.bindings.rootNavigation().push(BusinessChatbotController(context: context))
            }, itemImage: MenuAnimation.menu_gear.value))
            
            menu.addItem(ContextSeparatorItem())
            
            menu.addItem(ContextMenuItem(strings().chatBotManagerContextRevoke, handler: {
                context.engine.peers.removeChatManagingBot(chatId: peerId)
            }, itemMode: .destruct, itemImage: MenuAnimation.menu_clear_history.value))
            
            
            return menu
        }

        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        
        addSubview(avatar)
        addSubview(setup)
        addSubview(textView)
        addSubview(infoView)
        addSubview(stop)
        self.style = ControlStyle(backgroundColor: theme.colors.background)

        self.border = [.Bottom]
        
        update(with: state, animated: false)
    }
    
    func measure(_ width: CGFloat) {
        
    }
    
    func remove(animated: Bool) {
        
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        _state = state
        if let data = state.botManager  {
            textView.update(TextViewLayout(.initialize(string: data.peer._asPeer().displayTitle, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1))
            let status: String
            if data.bot.rights.contains(.readMessages) {
                if data.settings.isPaused {
                    status = strings().chatBotManagerPaused
                } else {
                    status = strings().chatBotManagerReadOnly
                }
            } else {
                status = strings().chatBotManagerFullAccess
            }
            stop.isHidden = false//!data.bot.canReply
            self.stop.set(text: data.settings.isPaused ? strings().chatBotManagerStart : strings().chatBotManagerStop, for: .Normal)
            infoView.update(TextViewLayout(.initialize(string: status, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1))
            self.avatar.setPeer(account: chatInteraction.context.account, peer: data.peer._asPeer())

        }
        
        updateLocalizationAndTheme(theme: theme)
        needsLayout = true

    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.backgroundColor = theme.colors.background
        self.setup.set(image: theme.icons.bot_manager_settings, for: .Normal)
        self.setup.sizeToFit()
        
        self.stop.set(font: .medium(.text), for: .Normal)
        self.stop.set(background: theme.colors.accent, for: .Normal)
        self.stop.set(color: theme.colors.underSelectedColor, for: .Normal)
        self.stop.sizeToFit(NSMakeSize(8, 4))
        self.stop.layer?.cornerRadius = self.stop.frame.height / 2
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: avatar, frame: avatar.centerFrameY(x: 25))
        
        let setupX = size.width - 23 - setup.frame.width
        transition.updateFrame(view: setup, frame: setup.centerFrameY(x: setupX))
        
        let stopX = setupX - 10 - stop.frame.width
        transition.updateFrame(view: stop, frame: stop.centerFrameY(x: stopX))
        
        let textWidth = size.width - avatar.frame.maxX - 20 - setup.frame.width - 10 - stop.frame.width - 10
        textView.resize(textWidth)
        infoView.resize(textWidth)
        
        transition.updateFrame(view: textView, frame: CGRect(
            origin: NSPoint(x: avatar.frame.maxX + 11, y: 6),
            size: textView.frame.size
        ))
        
        transition.updateFrame(view: infoView, frame: CGRect(
            origin: NSPoint(x: avatar.frame.maxX + 11, y: size.height - infoView.frame.height - 6),
            size: infoView.frame.size
        ))
    }


    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}




private final class ChatAdHeaderView : Control, ChatHeaderProtocol {
    private let chatInteraction:ChatInteraction
    private var botAd: ChatHeaderState.BotAdMessage?
    private let header: TextView = TextView()
    private let adHeaderView = TextView()
    private let text = InteractiveTextView()
    private let whatsThis = TextView()
    private var dismiss: ImageButton?
    private var state: ChatHeaderState
    
    private var imageView: ChatInteractiveContentView?
    
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        self.state = state
        super.init(frame: frame)
        
        addSubview(adHeaderView)
        addSubview(header)
        addSubview(text)
        
        addSubview(whatsThis)
        
        whatsThis.scaleOnClick = true
        whatsThis.isSelectable = false
        
        header.userInteractionEnabled = false
        header.isSelectable = false
        
        text.userInteractionEnabled = false
        
        adHeaderView.userInteractionEnabled = false
        adHeaderView.isSelectable = false
        

        self.set(handler: { [weak self] _ in
            if let interactions = self?.chatInteraction, let adAttribute = self?.state.botAd?.message.adAttribute {
                let context = interactions.context
                let link: inAppLink = inApp(for: adAttribute.url.nsstring, context: context, openInfo: chatInteraction.openInfo)
                execute(inapp: link)
                interactions.markAdAction(adAttribute.opaqueId, adAttribute.hasContentMedia)
            }
        }, for: .Click)
        
        let menu:(Control)->Void = { [weak self] control in
            if let message = self?.state.botAd?.message, let interactions = self?.chatInteraction {
                let signal = chatMenuItems(for: message, entry: nil, textLayout: nil, chatInteraction: interactions) |> deliverOnMainQueue
                if let event = NSApp.currentEvent {
                    _ = signal.startStandalone(next: { items in
                        let menu = ContextMenu()
                        menu.items = items
                        AppMenu.show(menu: menu, event: event, for: control)
                    })
                }
            }
        }
        
        whatsThis.set(handler: menu, for: .Click)
        self.set(handler: menu, for: .RightDown)
        
        update(with: state, animated: false)

    }
    
    func measure(_ width: CGFloat) {
        self.state.botAd?.measure(width)
        self.update(with: self.state, animated: false)
    }
    
    func remove(animated: Bool) {
        
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        
        self.botAd = state.botAd
        self.state = state

        
        guard let botAd = state.botAd else {
            return
        }
        
        adHeaderView.update(botAd.adHeader)
                
        let context = self.chatInteraction.context
        
        self.whatsThis.update(botAd.dismissLayout)
        self.whatsThis.setFrameSize(NSMakeSize(botAd.dismissLayout.layoutSize.width + 8, botAd.dismissLayout.layoutSize.height + 4))
        
        self.whatsThis.layer?.cornerRadius = self.whatsThis.frame.height / 2
        self.whatsThis.backgroundColor = theme.colors.accent.withAlphaComponent(0.2)
        
        self.header.update(botAd.header)
        
        self.text.set(text: botAd.text, context: context)
        
        
        if let media = botAd.message.media.first {
            let current: ChatInteractiveContentView
            if let view = self.imageView {
                current = view
            } else {
                current = ChatInteractiveContentView(frame: NSMakeRect(0, 0, 40, 40))
                self.addSubview(current)
                self.imageView = current
            }
            current.layer?.cornerRadius = 4
            current.update(with: media, size: current.frame.size, context: self.chatInteraction.context, parent: botAd.message, table: nil, animated: false)
        } else if let view = self.imageView {
            performSubviewRemoval(view, animated: animated)
            self.imageView = nil
        }
        
        if botAd.message.media.first == nil {
            let current: ImageButton
            if let view = self.dismiss {
                current = view
            } else {
                current = ImageButton()
                self.dismiss = current
                addSubview(current)
                current.autohighlight = false
                current.scaleOnClick = true
            }
            
            current.set(image: NSImage(resource: .iconStoryClose).precomposed(theme.colors.grayIcon), for: .Normal)
            current.setSingle(handler: { [weak self] _ in
                if let interactions = self?.chatInteraction {
                    let context = interactions.context
                    if context.isPremium, let opaqueId = self?.botAd?.message.adAttribute?.opaqueId {
                        _ = context.engine.accountData.updateAdMessagesEnabled(enabled: false).startStandalone()
                        interactions.removeAd(opaqueId)
                        showModalText(for: context.window, text: strings().chatDisableAdTooltip)
                    } else {
                        prem(with: PremiumBoardingController(context: context, source: .no_ads, openFeatures: true), for: context.window)
                    }
                }
            }, for: .Click)
            
            current.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
        } else if let dismiss {
            performSubviewRemoval(dismiss, animated: animated)
            self.dismiss = nil
            
        }
        if let adAttribute = botAd.message.adAttribute {
            chatInteraction.markAdAsSeen(adAttribute.opaqueId)
        }
        
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
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let adHeaderOrigin = NSPoint(x: 20, y: 10)
        transition.updateFrame(view: adHeaderView, frame: NSRect(origin: adHeaderOrigin, size: adHeaderView.frame.size))

        let headerOrigin = NSPoint(x: 20, y: adHeaderView.frame.maxY + 4)
        transition.updateFrame(view: header, frame: NSRect(origin: headerOrigin, size: header.frame.size))

        let whatsThisOrigin = NSPoint(x: adHeaderView.frame.maxX + 5, y: adHeaderView.frame.minY)
        transition.updateFrame(view: whatsThis, frame: NSRect(origin: whatsThisOrigin, size: whatsThis.frame.size))

        let textOrigin = NSPoint(x: 20, y: header.frame.maxY + 4)
        transition.updateFrame(view: text, frame: NSRect(origin: textOrigin, size: text.frame.size))

        if let imageView = imageView {
            let imageX = size.width - 50 - 10
            transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: imageX))
        }

        if let dismiss = dismiss {
            let dismissX = size.width - 30 - 20
            transition.updateFrame(view: dismiss, frame: dismiss.centerFrameY(x: dismissX))
        }
    }

    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
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




private final class ChatRemovePaidMessage : Control, ChatHeaderProtocol {
    private let chatInteraction:ChatInteraction
    private let header: InteractiveTextView = InteractiveTextView()
    private let dismiss:ImageButton = ImageButton()
    private let removeFee = TextButton()
    private var state: ChatHeaderState
    
    private var headerLayout: TextViewLayout?
        
    required init(_ chatInteraction:ChatInteraction, state: ChatHeaderState, frame: NSRect) {
        self.chatInteraction = chatInteraction
        self.state = state
        super.init(frame: frame)
        
        addSubview(header)
        addSubview(removeFee)
        
        removeFee.scaleOnClick = true
                
        switch state.main {
        case let .removePaidMessages(peer, amount):
            let attr = NSMutableAttributedString()
            let text: String
            if let removePaidMessageFeeData = chatInteraction.presentation.removePaidMessageFeeData {
                text = strings().chatHeaderRemoveFeeMonoforumText(removePaidMessageFeeData.peer._asPeer().compactDisplayTitle.prefixWithDots(30), clown_space + amount.stringValue)
            } else {
                text = strings().chatHeaderRemoveFeeText(peer.compactDisplayTitle.prefixWithDots(30), clown_space + amount.stringValue)
            }
            attr.append(string: text, color: theme.colors.grayText, font: .normal(.text))
            attr.insertEmbedded(.embedded(name: "star_small", color: theme.colors.grayText, resize: false), for: clown)
            headerLayout = .init(attr, alignment: .center)
            
            removeFee.setSingle(handler: { [weak chatInteraction] _ in
                
                if let chatInteraction = chatInteraction {
                    let engine = chatInteraction.context.engine
                    let window = chatInteraction.context.window
                    let accountId = chatInteraction.context.peerId
                    
                    let removePaidMessageFeeData = chatInteraction.presentation.removePaidMessageFeeData
                                        
                    if let removePaidMessageFeeData  {
                        _ = showModalProgress(signal: engine.peers.getPaidMessagesRevenue(scopePeerId: peer.id, peerId: removePaidMessageFeeData.peer.id), for: window).startStandalone(next: { amount in
                            
                            let option: String?
                            if let amount, amount.value > 0 {
                                option = strings().chatHeaderRemoveFeeConfirmOption(strings().starListItemCountCountable(Int(amount.value)))
                            } else {
                                option = nil
                            }
                            verifyAlert(for: window, header: strings().chatHeaderRemoveFeeConfirmHeader, information: strings().chatHeaderRemoveFeeMonoforumConfirmInfo(removePaidMessageFeeData.peer._asPeer().displayTitle), ok: strings().chatHeaderRemoveFeeConfirmOK, option: option, optionIsSelected: false, successHandler: { result in
                                _ = engine.peers.addNoPaidMessagesException(scopePeerId: peer.id, peerId: removePaidMessageFeeData.peer.id, refundCharged: result == .thrid).start()
                            })
                        })
                    } else {
                        _ = showModalProgress(signal: engine.peers.getPaidMessagesRevenue(scopePeerId: accountId, peerId: peer.id), for: window).startStandalone(next: { amount in
                            
                            let option: String?
                            if let amount, amount.value > 0 {
                                option = strings().chatHeaderRemoveFeeConfirmOption(strings().starListItemCountCountable(Int(amount.value)))
                            } else {
                                option = nil
                            }
                            verifyAlert(for: window, header: strings().chatHeaderRemoveFeeConfirmHeader, information: strings().chatHeaderRemoveFeeConfirmInfo(peer.displayTitle), ok: strings().chatHeaderRemoveFeeConfirmOK, option: option, optionIsSelected: false, successHandler: { result in
                                _ = engine.peers.addNoPaidMessagesException(scopePeerId: accountId, peerId: peer.id, refundCharged: result == .thrid).start()
                            })
                        })
                    }
                    
                    
                    
                    
                }
                
            }, for: .Click)
            
        default:
            headerLayout = nil
        }
        
        removeFee.set(text: strings().chatHeaderRemoveFee, for: .Normal)
        removeFee.set(color: theme.colors.accent, for: .Normal)
        removeFee.set(font: .medium(.text), for: .Normal)
        removeFee.sizeToFit()
        
        
        
        header.userInteractionEnabled = false
        update(with: state, animated: false)

    }
    
    func measure(_ width: CGFloat) {
        headerLayout?.measure(width: width)
        self.update(with: self.state, animated: false)
    }
    
    func remove(animated: Bool) {
        
    }

    func update(with state: ChatHeaderState, animated: Bool) {
        
        self.state = state
   
        let context = self.chatInteraction.context
        self.header.set(text: headerLayout, context: context)
        
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
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: header, frame: header.centerFrameX(y: 6))

        let removeFeeY = size.height - removeFee.frame.height - 7
        transition.updateFrame(view: removeFee, frame: removeFee.centerFrameX(y: removeFeeY))
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
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
