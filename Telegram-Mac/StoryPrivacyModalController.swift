//
//  StoryPrivacyModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 22.11.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InputView

private final class StoryPreviewHeaderItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let peer: EnginePeer
    fileprivate let nameLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, presentation: TelegramPresentationTheme, context: AccountContext, peer: EnginePeer) {
        self.context = context
        self.presentation = presentation
        self.peer = peer
        self.nameLayout = .init(.initialize(string: peer._asPeer().displayTitle, color: presentation.colors.listGrayText, font: .normal(.text)))
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        self.nameLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 35)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return StoryPreviewHeaderView.self
    }
    
    override var height: CGFloat {
        return 20 + 4
    }
}

private final class StoryPreviewHeaderView : TableRowView {
    private let avatar = AvatarControl(font: .avatar(5))
    private let nameView = TextView()
    private let imageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(NSMakeSize(16, 16))
        addSubview(avatar)
        addSubview(nameView)
        addSubview(imageView)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {
            return
        }
        imageView.setFrameOrigin(NSMakePoint(item.inset.left + item.viewType.innerInset.left, 0))
        avatar.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 4, 0))
        nameView.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 5, 0))
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoryPreviewHeaderItem else {
            return
        }
        
        imageView.image = item.presentation.icons.story_repost_from_white
        imageView.sizeToFit()
        
        nameView.update(item.nameLayout)
        avatar.setPeer(account: item.context.account, peer: item.peer._asPeer())
        
        needsLayout = true
    }
}

private final class StoryPreviewRowItem : GeneralRowItem {
    fileprivate let story: StoryContentItem
    fileprivate let context: AccountContext
    fileprivate let presentation: TelegramPresentationTheme
    fileprivate let interactions: TextView_Interactions
    fileprivate let state: Updated_ChatTextInputState
    fileprivate let updateState:(Updated_ChatTextInputState)->Void
    fileprivate let showEmojis:(Control)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, presentation: TelegramPresentationTheme, context: AccountContext, story: StoryContentItem, interactions: TextView_Interactions, state: Updated_ChatTextInputState, updateState:@escaping(Updated_ChatTextInputState)->Void, showEmojis:@escaping(Control)->Void) {
        self.story = story
        self.context = context
        self.presentation = presentation
        self.interactions = interactions
        self.state = state
        self.updateState = updateState
        self.showEmojis = showEmojis
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return StoryPreviewRowView.self
    }
    
    override var height: CGFloat {
        return 100
    }
}

private final class StoryPreviewRowView : GeneralContainableRowView {
    let inputView: UITextView = UITextView(frame: NSMakeRect(0, 0, 100, 50))
    private var storyView: StoryLayoutView?
    
    private let emojiButton = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(inputView)
        addSubview(emojiButton)
        inputView.placeholder = strings().previewSenderCaptionPlaceholder
    }
    
    private func inputDidUpdateLayout(animated: Bool) {
        self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)

    }
    
    private func set(_ state: Updated_ChatTextInputState) {
        guard let item = item as? StoryPreviewRowItem else {
            return
        }
        
        item.updateState(state)
        
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? StoryPreviewRowItem else {
            return super.backdorColor
        }
        return item.presentation.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoryPreviewRowItem else {
            return
        }
        inputView.inputTheme = item.presentation.inputTheme
        

        inputView.context = item.context
        
        item.interactions.min_height = 16
        item.interactions.max_height = 90
        
        emojiButton.set(image: item.presentation.icons.chatEntertainment, for: .Normal)
        emojiButton.sizeToFit()
        emojiButton.autohighlight = false
        emojiButton.scaleOnClick = true
        emojiButton.removeAllHandlers()
        emojiButton.set(handler: { [weak item] control in
            item?.showEmojis(control)
        }, for: .Click)


        self.inputView.interactions = item.interactions
        
        item.interactions.inputDidUpdate = { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.set(state)
            self.inputDidUpdateLayout(animated: true)
        }
 
        if self.storyView == nil, let peerId = item.story.peerId {
            let storyView = StoryLayoutView.makeView(for: item.story.storyItem, isHighQuality: item.context.sharedContext.baseSettings.highQualityStories && item.context.isPremium, peerId: peerId, peer: item.story.peer?._asPeer(), context: item.context, frame: NSMakeRect(0, 0, 100, 100))
            storyView.layer?.cornerRadius = 0
            addSubview(storyView)
            self.storyView = storyView
        }
        
        window?.makeFirstResponder(inputView.inputView)
        
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    override var firstResponder: NSResponder? {
        return inputView.inputView
    }
    
    var textWidth: CGFloat {
        guard let item = item as? StoryPreviewRowItem else {
            return frame.width
        }
        return item.blockWidth - 100 - (item.viewType.innerInset.left - 5) - 20
    }
    
    func textViewSize() -> (NSSize, CGFloat) {
        let w = textWidth
        let height = inputView.height(for: w)
        return (NSMakeSize(w, min(max(height, inputView.min_height), inputView.max_height)), height)
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? StoryPreviewRowItem else {
            return
        }
        
        let (textSize, textHeight) = textViewSize()
                
        transition.updateFrame(view: inputView, frame: CGRect(origin: CGPoint(x: item.viewType.innerInset.left - 5 + 100, y: 5), size: textSize))
        inputView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        
        transition.updateFrame(view: emojiButton, frame: CGRect(origin: CGPoint(x: containerView.frame.width - emojiButton.frame.width - 5, y: containerView.frame.height - emojiButton.frame.height - 5), size: emojiButton.frame.size))
    }
    
}

private final class Arguments {
    let context: AccountContext
    let presentation: TelegramPresentationTheme
    let reason: StoryPrivacyReason
    let interactions: TextView_Interactions
    let togleCategory:(EngineStoryPrivacy.Base)->Void
    let toggleOption:(OptionId)->Void
    let selectUsers:(EngineStoryPrivacy.Base)->Void
    let reveal:()->Void
    let updateState:(Updated_ChatTextInputState)->Void
    let showSendAs:()->Void
    let updateBlockList:()->Void
    let showEmojis:(Control)->Void
    init(context: AccountContext, presentation: TelegramPresentationTheme, reason: StoryPrivacyReason, interactions: TextView_Interactions, togleCategory:@escaping(EngineStoryPrivacy.Base)->Void, toggleOption:@escaping(OptionId)->Void, selectUsers:@escaping(EngineStoryPrivacy.Base)->Void, reveal:@escaping()->Void, updateState:@escaping(Updated_ChatTextInputState)->Void, showSendAs:@escaping()->Void, updateBlockList:@escaping()->Void, showEmojis:@escaping(Control)->Void) {
        self.context = context
        self.presentation = presentation
        self.reason = reason
        self.interactions = interactions
        self.togleCategory = togleCategory
        self.toggleOption = toggleOption
        self.selectUsers = selectUsers
        self.reveal = reveal
        self.updateState = updateState
        self.showSendAs = showSendAs
        self.updateBlockList = updateBlockList
        self.showEmojis = showEmojis
    }
}

private enum OptionId: Int, Hashable {
    case screenshot = 0
    case pin = 1
}


private struct State : Equatable {
    var privacy: StoryPosterResultPrivacy
    var initited: Bool = false
    var peers: [EnginePeer.Id : EnginePeer] = [:]
    var sendAsPeers: [SendAsPeer] = []
    var blockedPeers:[RenderedPeer] = []
    var reveal: Bool = false
    var textState:Updated_ChatTextInputState = .init(inputText: .init())
    var friends: [EnginePeer] = []
    
    func find(_ category: EngineStoryPrivacy.Base) -> EngineStoryPrivacy {
        switch category {
        case .everyone:
            return privacy.privacyEveryone
        case .contacts:
            return privacy.privacyContacts
        case .closeFriends:
            return privacy.privacyFriends
        case .nobody:
            return privacy.privacyNobody
        }
    }
    
    func text(for category: EngineStoryPrivacy.Base) -> String {
        let privacy = find(category)
        let peersText = privacy.additionallyIncludePeers.compactMap { self.peers[$0] }.map { $0._asPeer().compactDisplayTitle }.joined(separator: ", ")

        switch category {
        case .everyone, .contacts:
            if privacy.additionallyIncludePeers.isEmpty {
                return strings().storyPrivacyExcludePeople
            } else {
                return strings().storyPrivacyExceptPeople(peersText)
            }
        case .closeFriends:
            if friends.isEmpty {
                return strings().storyPrivacyEditList
            } else {
                if friends.count > 2 {
                    return strings().storyPrivacyPeopleListCountable(friends.count)
                } else {
                    return friends.map { $0._asPeer().compactDisplayTitle }.joined(separator: ", ")
                }
            }
        case .nobody:
            if privacy.additionallyIncludePeers.isEmpty {
                return strings().storyPrivacyChoose
            } else {
                return peersText
            }
        }
    }
    
    var sendAsPeerId: PeerId? {
        if let peerId = privacy.sendAsPeerId {
            let found = sendAsPeers.first(where: { $0.peer.id == peerId }) != nil
            if found {
                return peerId
            }
        }
        return nil
    }
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_preview = InputDataIdentifier("_id_preview")
private let _id_preview_header = InputDataIdentifier("_id_preview_header")

private let _id_show_settings = InputDataIdentifier("_id_show_settings")

private let _id_privacy_everyone = InputDataIdentifier("_id_privacy_everyone")
private let _id_privacy_my_contacts = InputDataIdentifier("_id_privacy_my_contacts")
private let _id_privacy_close_friends = InputDataIdentifier("_id_privacy_close_friends")
private let _id_privacy_select_users = InputDataIdentifier("_id_privacy_select_users")
private let _id_privacy_allow_screenshot = InputDataIdentifier("_id_privacy_allow_screenshot")
private let _id_privacy_post_to_profile = InputDataIdentifier("_id_privacy_post_to_profile")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let presentation = arguments.presentation
    let rowTheme = GeneralRowItem.Theme.initialize(presentation)
    
    
    switch arguments.reason {
    case .share(let storyContentItem):
        if let peer = storyContentItem.peer {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return StoryPreviewHeaderItem(initialSize, stableId: stableId, viewType: .textTopItem, presentation: presentation, context: arguments.context, peer: peer)
                
            }))
        }
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return StoryPreviewRowItem(initialSize, stableId: stableId, viewType: .singleItem, presentation: presentation, context: arguments.context, story: storyContentItem, interactions: arguments.interactions, state: state.textState, updateState: arguments.updateState, showEmojis: arguments.showEmojis)
            
        }))
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
    case .settings:
        break
    }
    
        
    switch arguments.reason {
    case .share:
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storyPrivacyPostStoryAs), data: .init(color: presentation.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        let sendAs = state.privacy.sendAsPeerId ?? arguments.context.peerId
        
        let sendAsPeer = state.sendAsPeers.first(where: { $0.peer.id == sendAs })?.peer ?? state.peers[arguments.context.peerId]?._asPeer()
        if let peer = sendAsPeer {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, stableId: stableId, titleStyle: ControlStyle(font: .medium(.title), foregroundColor: presentation.colors.text, highlightColor: .white), statusStyle: ControlStyle(font: .normal(.text), foregroundColor: presentation.colors.grayText), status: strings().storyPrivacyPersonalAccount, inset: NSEdgeInsets(left: 20, right: 20), generalType: .next, viewType: .singleItem, action: arguments.showSendAs, customTheme: rowTheme)
            }))
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    case .settings:
        break
    }
    
    if state.reveal {

        if state.sendAsPeerId == arguments.context.peerId || state.sendAsPeerId == nil {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storyPrivacyWhoCanViewStory), data: .init(color: presentation.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_privacy_everyone, data: .init(name: strings().storyPrivacyEveryone, color: presentation.colors.text, type: .selectableLeft(state.privacy.selectedPrivacy == .everyone), viewType: .firstItem, description: state.text(for: .everyone), descTextColor: presentation.colors.accent, action: {
                arguments.togleCategory(.everyone)
            }, descClick: {
                arguments.selectUsers(.everyone)
            }, theme: rowTheme)))
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_privacy_my_contacts, data: .init(name: strings().storyPrivacyContacts, color: presentation.colors.text, type: .selectableLeft(state.privacy.selectedPrivacy == .contacts), viewType: .innerItem, description: state.text(for: .contacts), descTextColor: presentation.colors.accent, action: {
                arguments.togleCategory(.contacts)
            }, descClick: {
                arguments.selectUsers(.contacts)
            }, theme: rowTheme)))
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_privacy_close_friends, data: .init(name: strings().storyPrivacyCloseFriends, color: presentation.colors.text, type: .selectableLeft(state.privacy.selectedPrivacy == .closeFriends), viewType: .innerItem, description: state.text(for: .closeFriends), descTextColor: presentation.colors.accent, action: {
                arguments.togleCategory(.closeFriends)
            }, descClick: {
                arguments.selectUsers(.closeFriends)
            }, theme: rowTheme)))
            
            

            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_privacy_select_users, data: .init(name: strings().storyPrivacySelectUsers, color: presentation.colors.text, type: .selectableLeft(state.privacy.selectedPrivacy == .nobody), viewType: .lastItem, description: state.text(for: .nobody), descTextColor: presentation.colors.accent, action: {
                arguments.togleCategory(.nobody)
            }, descClick: {
                arguments.selectUsers(.nobody)
            }, theme: rowTheme)))
            
            let grayListText: String
            if state.blockedPeers.isEmpty {
                grayListText = strings().storyPrivacyGrayListPart1
            } else {
                grayListText = strings().storyPrivacyGrayListPersonCountable(state.blockedPeers.count)
            }

            entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().storyPrivacyGrayListMain(grayListText), linkHandler: { link in
                arguments.updateBlockList()
            }), data: .init(color: presentation.colors.listGrayText, viewType: .textBottomItem, linkColor: presentation.colors.link)))
            index += 1

        }
       
       
        
        switch arguments.reason {
        case .share:
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_privacy_allow_screenshot, data: .init(name: strings().storyPrivacyAllowScreenshot, color: presentation.colors.text, type: .switchable(!state.privacy.isForwardingDisabled), viewType: .firstItem, action: {
                arguments.toggleOption(.screenshot)
            }, theme: rowTheme)))
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_privacy_post_to_profile, data: .init(name: strings().storyPrivacyPostToMyProfile, color: presentation.colors.text, type: .switchable(state.privacy.pin), viewType: .lastItem, action: {
                arguments.toggleOption(.pin)
            }, theme: rowTheme)))

            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storyPrivacyBasicInfo), data: .init(color: presentation.colors.listGrayText, viewType: .textBottomItem)))
            index += 1
        case .settings:
            break
        }
        
    } else {
        
        let privacyText: String
        let current = state.find(state.privacy.selectedPrivacy)
        switch state.privacy.selectedPrivacy {
        case .closeFriends:
            privacyText = strings().storyPrivacyCloseFriends
        case .contacts:
            privacyText = strings().storyPrivacyContacts
        case .everyone:
            privacyText = strings().storyPrivacyEveryone
        case .nobody:
            if current.additionallyIncludePeers.isEmpty {
                privacyText = ""
            } else {
                if current.additionallyIncludePeers.count > 3 {
                    privacyText = strings().storyPrivacyPeopleListCountable(current.additionallyIncludePeers.count)
                } else {
                    privacyText = current.additionallyIncludePeers.compactMap { state.peers[$0] }.map { $0._asPeer().compactDisplayTitle }.joined(separator: ", ")
                }
            }
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_show_settings, data: .init(name: strings().storyPrivacyRevealTitle, color: presentation.colors.text, type: .nextContext(privacyText), viewType: .singleItem, action: arguments.reveal, theme: rowTheme)))
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().storyPrivacyRevealInfo), data: .init(color: presentation.colors.listGrayText, viewType: .textBottomItem)))
        index += 1

    }
    
   
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

enum StoryPrivacyReason {
    case share(StoryContentItem)
    case settings(StoryContentItem)
}

func StoryPrivacyModalController(context: AccountContext, presentation: TelegramPresentationTheme, reason: StoryPrivacyReason) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    
    var close:(()->Void)? = nil
    var getController:(()->InputDataController?)? = nil
    
    let reveal: Bool
    var initialPrivacy: StoryPosterResultPrivacy = .init(sendAsPeerId: context.peerId, privacyEveryone: .init(base: .everyone, additionallyIncludePeers: []), privacyContacts: .init(base: .contacts, additionallyIncludePeers: []), privacyFriends: .init(base: .closeFriends, additionallyIncludePeers: []), privacyNobody: .init(base: .nobody, additionallyIncludePeers: []), selectedPrivacy: .everyone, isForwardingDisabled: false, pin: true)
    
    switch reason {
    case let  .settings(item):
        reveal = true
        if let privacy = item.storyItem.privacy {
            initialPrivacy.selectedPrivacy = privacy.base
        }
    case .share:
        reveal = false
    }

    let initialState = State(privacy: initialPrivacy, reveal: reveal)
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
        
    
    switch reason {
    case .share:
        let state: Signal<StoryPosterState?, NoError> = storyPosterState(engine: context.engine)
        actionsDisposable.add(state.start(next: { value in
            updateState { current in
                var current = current
                if let privacy = value?.privacy {
                    current.privacy = privacy
                }
                return current
            }
        }))
    case let .settings(story):
        let state: Signal<StoryPosterState?, NoError> = storyPosterState(engine: context.engine) |> take(1)
        actionsDisposable.add(state.start(next: { value in
            updateState { current in
                var current = current
                if let privacy = value?.privacy {
                    if let storyPrivacy = story.storyItem.privacy {
                        var privacyEveryone: EngineStoryPrivacy = privacy.privacyEveryone
                        var privacyContacts: EngineStoryPrivacy = privacy.privacyContacts
                        var privacyCloseFriends: EngineStoryPrivacy = privacy.privacyFriends
                        var privacyNobody: EngineStoryPrivacy = privacy.privacyNobody
                        
                        switch storyPrivacy.base {
                        case .everyone:
                            privacyEveryone = storyPrivacy
                        case .contacts:
                            privacyContacts = storyPrivacy
                        case .closeFriends:
                            privacyCloseFriends = storyPrivacy
                        case .nobody:
                            privacyNobody = storyPrivacy
                        }
                        current.privacy = .init(sendAsPeerId: nil, privacyEveryone: privacyEveryone, privacyContacts: privacyContacts, privacyFriends: privacyCloseFriends, privacyNobody: privacyNobody, selectedPrivacy: storyPrivacy.base, isForwardingDisabled: privacy.isForwardingDisabled, pin: privacy.pin)
                    } else {
                        current.privacy = privacy
                    }
                }
                return current
            }
        }))
    }
    
    
    
    var peerIds:[EnginePeer.Id] = []
    
    let selectPeers: (EngineStoryPrivacy)->Void = { privacy in
        
        let title: String
        switch privacy.base {
        case .closeFriends:
            title = strings().storyPrivacySelectTitleCloseFriends
        case .contacts:
            title = strings().storyPrivacySelectTitleContacts
        case .everyone:
            title = strings().storyPrivacySelectTitleContacts
        case .nobody:
            title = strings().storyPrivacySelectTitleNobody
        }
        
        let selectedPeerIds:[EnginePeer.Id]
        switch privacy.base {
        case .closeFriends:
            selectedPeerIds = stateValue.with { $0.friends.map { $0.id } }
        default:
            selectedPeerIds = privacy.additionallyIncludePeers
        }
        
        let behaviour = SelectContactsBehavior(customTheme: { GeneralRowItem.Theme.initialize(presentation) })
        _ = selectModalPeers(window: context.window, context: context, title: title, behavior: behaviour, selectedPeerIds: Set(selectedPeerIds)).start(next: { updatedPeerIds in
            updateState { current in
                var current = current
                switch privacy.base {
                case .everyone:
                    current.privacy.privacyEveryone.additionallyIncludePeers = updatedPeerIds
                case .contacts:
                    current.privacy.privacyContacts.additionallyIncludePeers = updatedPeerIds
                case .nobody:
                    current.privacy.privacyNobody.additionallyIncludePeers = updatedPeerIds
                default:
                    break
                }
                return current
            }
            if case .closeFriends = privacy.base {
                _ = context.engine.privacy.updateCloseFriends(peerIds: updatedPeerIds).startStandalone()
            }
        })
    }

    actionsDisposable.add(statePromise.get().start(next: { state in
    
        var currentIds:[EnginePeer.Id] = state.privacy.privacyEveryone.additionallyIncludePeers + state.privacy.privacyContacts.additionallyIncludePeers + state.privacy.privacyNobody.additionallyIncludePeers
        
        if let sendAs = state.privacy.sendAsPeerId {
            currentIds.append(sendAs)
        }
        currentIds.append(context.peerId)
        
        if currentIds != peerIds {
            let peers: Signal<[EnginePeer.Id: EnginePeer], NoError> = context.account.postbox.transaction { transaction in
                var peers:[EnginePeer.Id: EnginePeer] = [:]
                for currentId in currentIds {
                    if let peer = transaction.getPeer(currentId) {
                        peers[peer.id] = .init(peer)
                    }
                }
                return peers
            } |> deliverOnMainQueue
            
            _ = peers.start(next: { peers in
                updateState { current in
                    var current = current
                    current.peers = peers
                    current.initited = true
                    return current
                }
            })
            peerIds = currentIds
        }
        switch reason {
        case .share:
            _ = updateStoryPosterStateInteractively(engine: context.engine, { _ in
                return .init(privacy: state.privacy)
            }).start()
        case .settings:
            break
        }
    }))
    
    let adminedChannelsWithParticipants: Signal<[SendAsPeer], NoError> = context.engine.peers.channelsForStories()
    |> mapToSignal { peers -> Signal<[SendAsPeer], NoError> in
        return context.engine.data.subscribe(
            EngineDataMap(peers.map(\.id).map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
        )
        |> map { participantCountMap -> [SendAsPeer] in
            return peers.map({ .init(peer: $0._asPeer(), subscribers: participantCountMap[$0.id]?.flatMap { Int32($0) }, isPremiumRequired: false) })
        }
    }

    let blockedContext = BlockedPeersContext(account: context.account, subject: .stories)
    
    actionsDisposable.add(combineLatest(adminedChannelsWithParticipants, blockedContext.state, context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.CloseFriends())).start(next: { peers, blocked, friends in
        updateState { current in
            var current = current
            current.sendAsPeers = peers
            current.blockedPeers = blocked.peers
            current.friends = friends
            return current
        }
    }))
    
    let textInteractions = TextView_Interactions()
    let emoji = EmojiesController(context, presentation: presentation)
    
    let contextChatInteraction = ChatInteraction(chatLocation: .peer(context.peerId), context: context)

    let interactions = EntertainmentInteractions(.emoji, peerId: contextChatInteraction.peerId)
    
    interactions.sendEmoji = { emoji, fromRect in
//        _ = self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        let updated = textInteractions.insertText(.initialize(string: emoji))
        textInteractions.update { _ in
            updated
        }
    }
    interactions.sendAnimatedEmoji = { sticker, _, _, fromRect in
        let text = (sticker.file.customEmojiText ?? sticker.file.stickerText ?? clown).fixed
        let updated = textInteractions.insertText(.makeAnimated(sticker.file, text: text))
        textInteractions.update { _ in
            updated
        }
    }
    
    emoji.update(with: interactions, chatInteraction: contextChatInteraction)

    
    
    textInteractions.processEnter = { event in
        return false
    }
    textInteractions.processAttriburedCopy = { attributedString in
        return globalLinkExecutor.copyAttributedString(attributedString)
    }
    textInteractions.processPaste = { pasteboard in
        if let data = pasteboard.data(forType: .kInApp) {
            let decoder = AdaptedPostboxDecoder()
            if let decoded = try? decoder.decode(ChatTextInputState.self, from: data) {
                let state = decoded.unique(isPremium: true)
                textInteractions.update { _ in
                    return textInteractions.insertText(state.attributedString())
                }
                return true
            }
        }
        return false
    }
    
    let arguments = Arguments(context: context, presentation: presentation, reason: reason, interactions: textInteractions, togleCategory: { privacy in
        let same = stateValue.with { $0.privacy.selectedPrivacy == privacy }
        updateState { current in
            var current = current
            current.privacy.selectedPrivacy = privacy
            return current
        }
        if same {
            selectPeers(stateValue.with { $0.find(privacy) })
        }
    }, toggleOption: { option in
        updateState { current in
            var current = current
            if option == .pin {
                current.privacy.pin = !current.privacy.pin
            } else if option == .screenshot {
                current.privacy.isForwardingDisabled = !current.privacy.isForwardingDisabled
            }
            return current
        }
    }, selectUsers: { privacy in
        selectPeers(stateValue.with { $0.find(privacy) })
    }, reveal: {
        updateState { current in
            var current = current
            current.reveal = true
            return current
        }
    }, updateState: { state in
        textInteractions.update { _ in
            return state
        }
        updateState { current in
            var current = current
            current.textState = state
            return current
        }
    }, showSendAs: {
        if let event = NSApp.currentEvent {
            let menu = ContextMenu(presentation: .init(colors: presentation.colors), betterInside: true)
            
            
            let currentPeerId = stateValue.with { $0.privacy.sendAsPeerId }
                        
            let myPeer = stateValue.with { $0.peers[context.peerId] }
            
            var items:[ContextMenuItem] = []
            
            var peers = stateValue.with { $0.sendAsPeers }
            
            if let myPeer = myPeer {
                peers.insert(.init(peer: myPeer._asPeer(), subscribers: nil, isPremiumRequired: false), at: 0)
            }
            
            if let index = peers.firstIndex(where: { $0.peer.id == currentPeerId }) {
                peers.move(at: index, to: 0)
            }
            let header = ContextMenuItem(strings().storyPrivacyContextPostAs)
            header.isEnabled = false
            items.append(header)
            
            for (i, peer) in peers.enumerated() {
                items.append(ContextSendAsMenuItem(peer: peer, context: context, isSelected: i == 0, handler: {
                    if peer.peer.isChannel {
                        let peerId = peer.peer.id
                        let check = context.engine.messages.checkStoriesUploadAvailability(target: .peer(peerId)) |> deliverOnMainQueue
                        actionsDisposable.add(check.start(next: { availability in
                            switch availability {
                            case .available:
                                updateState { current in
                                    var current = current
                                    current.privacy.sendAsPeerId = peerId
                                    return current
                                }
                            case .channelBoostRequired:
                                let signal = showModalProgress(signal: combineLatest(context.engine.peers.getChannelBoostStatus(peerId: peerId), context.engine.peers.getMyBoostStatus()), for: context.window)
                                _ = signal.start(next: { stats, myStatus in
                                    if let stats = stats {
                                        showModal(with: BoostChannelModalController(context: context, peer: peer.peer, boosts: stats, myStatus: myStatus, infoOnly: true, source: .story, presentation: presentation), for: context.window)
                                    }
                                })
                            default:
                                break
                            }
                        }))

                    } else {
                        updateState { current in
                            var current = current
                            current.privacy.sendAsPeerId = peer.peer.id
                            return current
                        }
                    }
                }))
            }
                    
            for item in items {
                menu.addItem(item)
            }
            if let controller = getController?() {
                let view = controller.tableView.item(stableId: InputDataEntryId.custom(_id_header))?.view
                if let view = view {
                    AppMenu.show(menu: menu, event: event, for: view)
                }
            }
        }
    }, updateBlockList: {
        let current = stateValue.with { $0.blockedPeers.map { $0.peerId }}
        let behaviour = SelectContactsBehavior(customTheme: { GeneralRowItem.Theme.initialize(presentation) })
        _ = selectModalPeers(window: context.window, context: context, title: strings().storyPrivacySelectHideFrom, behavior: behaviour, selectedPeerIds: Set(current)).start(next: { updatedPeerIds in
            _ = blockedContext.updatePeerIds(updatedPeerIds).start()
        })
    }, showEmojis: { [weak emoji] control in
        if let emoji = emoji {
            showPopover(for: control, with: emoji)
        }
    })
    
    
    let signal = statePromise.get() |> filter { $0.initited } |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    let title: String
    switch reason {
    case .share:
        title = strings().storyPrivacyTitleRepost
    case .settings:
        title = strings().storyPrivacyTitlePrivacy
    }
    
    let controller = InputDataController(dataSignal: signal, title: title)
    
    controller.onDeinit = { [weak controller] in
        actionsDisposable.dispose()
        if let controller = controller {
            context.window.removeObserver(for: controller)
        }
        _ = blockedContext
        _ = emoji
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().modalDone, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true, customTheme: {
        .init(presentation: presentation)
    })
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(380, 300), presentation: presentation)
    
    controller.leftModalHeader = ModalHeaderData(image: presentation.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.getBackgroundColor = {
        presentation.colors.listBackground
    }
    
    controller.validateData = { _ in
        let textState = stateValue.with { $0.textState.textInputState() }
        let privacy = stateValue.with { $0.privacy }
        let selectedPrivacy = stateValue.with { $0.find($0.privacy.selectedPrivacy) }
        let sendAs: PeerId? = stateValue.with { $0.sendAsPeerId }
        switch reason {
        case let .share(story):
            let forwardInfo: Stories.PendingForwardInfo? = story.peerId.flatMap {
                .init(peerId: $0, storyId: story.storyItem.id, isModified: false)
            }
            let target: Stories.PendingTarget
            if let sendAs = sendAs {
                target = .peer(sendAs)
            } else {
                target = .myStories
            }
            
            actionsDisposable.add((context.engine.messages.checkStoriesUploadAvailability(target: target) |> deliverOnMainQueue).start(next: { availability in
                
                switch availability {
                case .available:
                    _ = context.engine.messages.uploadStory(target: target, media: .existing(media: story.storyItem.media._asMedia()), mediaAreas: [], text: textState.inputText, entities: textState.messageTextEntities(), pin: privacy.pin, privacy: selectedPrivacy, isForwardingDisabled: privacy.isForwardingDisabled, period: 24 * 60 * 60, randomId: arc4random64(), forwardInfo: forwardInfo).start()
                    showModalText(for: context.window, text: strings().storyPrivacySaveRepost)
                    close?()
                default:
                    showModal(with: PremiumBoardingController(context: context), for: context.window)
                }
                
            }))
        case let .settings(story):
            _ = context.engine.messages.editStoryPrivacy(id: story.storyItem.id, privacy: selectedPrivacy).startStandalone()
            showModalText(for: context.window, text: strings().storyPrivacySavePrivacy)
            close?()
        }
        return .none
    }
    
    controller.didAppear = { controller in
        
        context.window.set(handler: { [weak controller] _ -> KeyHandlerResult in
            let view = controller?.tableView.item(stableId: InputDataEntryId.custom(_id_preview))?.view as? StoryPreviewRowView
            view?.inputView.inputApplyTransform(.attribute(TextInputAttributes.bold))
            return .invoked
        }, with: controller, for: .B, priority: .modal, modifierFlags: [.command])

        
        context.window.set(handler: { [weak controller] _ -> KeyHandlerResult in
            let view = controller?.tableView.item(stableId: InputDataEntryId.custom(_id_preview))?.view as? StoryPreviewRowView
            view?.inputView.inputApplyTransform(.attribute(TextInputAttributes.underline))
            return .invoked
        }, with: controller, for: .U, priority: .modal, modifierFlags: [.shift, .command])
        
        context.window.set(handler: { [weak controller] _ -> KeyHandlerResult in
            let view = controller?.tableView.item(stableId: InputDataEntryId.custom(_id_preview))?.view as? StoryPreviewRowView
            view?.inputView.inputApplyTransform(.attribute(TextInputAttributes.spoiler))
            return .invoked
        }, with: controller, for: .P, priority: .modal, modifierFlags: [.shift, .command])
        
        context.window.set(handler: { [weak controller] _ -> KeyHandlerResult in
            let view = controller?.tableView.item(stableId: InputDataEntryId.custom(_id_preview))?.view as? StoryPreviewRowView
            view?.inputView.inputApplyTransform(.attribute(TextInputAttributes.strikethrough))
            return .invoked
        }, with: controller, for: .X, priority: .modal, modifierFlags: [.shift, .command])
        
        context.window.set(handler: { [weak controller] _ -> KeyHandlerResult in
            let view = controller?.tableView.item(stableId: InputDataEntryId.custom(_id_preview))?.view as? StoryPreviewRowView
            view?.inputView.inputApplyTransform(.clear)
            return .invoked
        }, with: controller, for: .Backslash, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { [weak controller] _ -> KeyHandlerResult in
            let view = controller?.tableView.item(stableId: InputDataEntryId.custom(_id_preview))?.view as? StoryPreviewRowView
            view?.inputView.inputApplyTransform(.url)
            return .invoked
        }, with: controller, for: .U, priority: .modal, modifierFlags: [.command])
        
        context.window.set(handler: { [weak controller] _ -> KeyHandlerResult in
            let view = controller?.tableView.item(stableId: InputDataEntryId.custom(_id_preview))?.view as? StoryPreviewRowView
            view?.inputView.inputApplyTransform(.attribute(TextInputAttributes.italic))
            return .invoked
        }, with: controller, for: .I, priority: .modal, modifierFlags: [.command])
    }
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    getController = { [weak controller] in
        return controller
    }
    
    return modalController
}

