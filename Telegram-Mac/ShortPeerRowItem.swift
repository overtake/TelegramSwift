//
//  ShortPeerRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 29/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

final class SelectPeerPresentation : Equatable {
    
    struct Comment : Equatable {
        let string: String
        let range: NSRange
    }
    let premiumRequired:Set<PeerId>
    let selected:Set<PeerId>
    let peers:[PeerId: Peer]
    let limit:Int32
    let inputQueryResult: ChatPresentationInputQueryResult?
    let comment: Comment
    let multipleSelection: Bool
    private let someFlagsAsNotice: Bool
    static func ==(lhs:SelectPeerPresentation, rhs:SelectPeerPresentation) -> Bool {
        return lhs.selected == rhs.selected && lhs.limit == rhs.limit && lhs.someFlagsAsNotice == rhs.someFlagsAsNotice && lhs.inputQueryResult == rhs.inputQueryResult && lhs.comment == rhs.comment && lhs.multipleSelection == rhs.multipleSelection && lhs.premiumRequired == rhs.premiumRequired
    }
    
    init(_ selected:Set<PeerId> = Set(), peers:[PeerId: Peer] = [:], limit: Int32 = 0, someFlagsAsNotice:Bool = false, inputQueryResult: ChatPresentationInputQueryResult? = nil, comment: Comment = Comment(string: "", range: NSMakeRange(0, 0)), multipleSelection: Bool = true, premiumRequired: Set<PeerId> = Set()) {
        self.selected = selected
        self.peers = peers
        self.limit = limit
        self.someFlagsAsNotice = someFlagsAsNotice
        self.inputQueryResult = inputQueryResult
        self.comment = comment
        self.multipleSelection = multipleSelection
        self.premiumRequired = premiumRequired
    }
    
    func deselect(peerId:PeerId) -> SelectPeerPresentation {
        var selectedIds:Set<PeerId> = Set<PeerId>()
        var peers:[PeerId: Peer] = self.peers
        selectedIds.formUnion(selected)
        let _ = selectedIds.remove(peerId)
        peers.removeValue(forKey: peerId)
        return SelectPeerPresentation(selectedIds, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: self.multipleSelection, premiumRequired: premiumRequired)
    }
    
    var isLimitReached: Bool {
        return limit > 0 && limit == selected.count
    }
    
    func withUpdateLimit(_ limit: Int32) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: multipleSelection, premiumRequired: premiumRequired)
    }
    func withUpdatedMultipleSelection(_ multipleSelection: Bool) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: multipleSelection, premiumRequired: premiumRequired)
    }
    
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: f(inputQueryResult), comment: comment, multipleSelection: multipleSelection, premiumRequired: premiumRequired)
    }
    
    func withUpdatedComment(_ comment: Comment) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: multipleSelection, premiumRequired: premiumRequired)
    }
    
    func withUpdatedPremiumRequired(_ premiumRequired: Set<PeerId>) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: multipleSelection, premiumRequired: premiumRequired)
    }
    
    func withToggledSelected(_ peerId: PeerId, peer:Peer, toggle: Bool? = nil) -> SelectPeerPresentation {
        var someFlagsAsNotice: Bool = self.someFlagsAsNotice
        var selectedIds:Set<PeerId> = Set<PeerId>()
        var peers:[PeerId: Peer] = self.peers
        selectedIds.formUnion(selected)
        if selectedIds.contains(peerId), toggle == nil || toggle == false {
            let _ = selectedIds.remove(peerId)
            peers.removeValue(forKey: peerId)
        } else if !selectedIds.contains(peerId), toggle == nil || toggle == true {
            if limit == 0 || selected.count < limit {
                selectedIds.insert(peerId)
                peers[peerId] = peer
            } else {
                someFlagsAsNotice = !someFlagsAsNotice
            }
        }
        return SelectPeerPresentation(selectedIds, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: multipleSelection, premiumRequired: premiumRequired)
    }
    
}

final class SelectPeerInteraction : InterfaceObserver {
    private(set) var presentation:SelectPeerPresentation = SelectPeerPresentation()
    var close: ()->Void = {}
    var action:(PeerId, Int64?)->Void = { _, _ in }
    var openForum:(PeerId, Bool)->Bool = { _, _ in return false }
    var singleUpdater:((SelectPeerPresentation)->Void)? = nil
    
    var updateFolder:((ChatListFilter)->Void)? = nil
    var premiumRequiredAction:((PeerId)->Void)? = nil
    
    func update(animated:Bool = true, _ f:(SelectPeerPresentation)->SelectPeerPresentation)->Void {
        let oldValue = self.presentation
        presentation = f(presentation)
        
        if oldValue != presentation {
            notifyObservers(value: presentation, oldValue:oldValue, animated:animated)
        }
        self.singleUpdater?(presentation)
    }
    
    func toggleSelection( _ peer: Peer) {
        if presentation.premiumRequired.contains(peer.id) {
            self.premiumRequiredAction?(peer.id)
            return
        }
        self.update(animated: true, {
            $0.withToggledSelected(peer.id, peer: peer)
                .withUpdatedMultipleSelection(true)
        })
    }
    func toggleSelection( _ peerId: PeerId) {
        if presentation.premiumRequired.contains(peerId) {
            self.premiumRequiredAction?(peerId)
            return
        }
        if let peer = self.presentation.peers[peerId] {
            self.toggleSelection(peer)
        }
    }
}

struct ShortPeerDeleting  : Equatable {
    let editable:Bool
    static func ==(lhs:ShortPeerDeleting, rhs:ShortPeerDeleting) -> Bool {
        return lhs.editable == rhs.editable
    }
}

enum ShortPeerDeletableState : Int {
    case plain = 0
    case progress = 1
}

enum ShortPeerItemInteractionType {
    enum Side {
        case left
        case right
    }
    case plain
    case deletable(onRemove:(PeerId)->Void, deletable:Bool)
    case selectable(SelectPeerInteraction, side: Side)
    case interactable(SelectPeerInteraction)
}





class ShortPeerRowItem: GeneralRowItem {
    let peer:Peer
    let context: AccountContext?
    let account: Account
    let interactionType:ShortPeerItemInteractionType
    let drawSeparatorIgnoringInset:Bool
    
    struct RightActions : Equatable {
        static func == (lhs: ShortPeerRowItem.RightActions, rhs: ShortPeerRowItem.RightActions) -> Bool {
            return lhs.actions == rhs.actions
        }
        
        struct RightAction : Equatable {
            var icon: CGImage
            var index: Int
        }
        var actions: [RightAction] = []
        var callback:(PeerId, Int)->Void = { _, _ in }
    }
    
    func textInset(_ status: Bool) -> CGFloat {
        switch viewType {
        case .legacy:
            var width = inset.left + photoSize.width + 10.0 + (leftImage != nil ? leftImage!.backingSize.width + 5 : 0)
            
            #if !SHARE
            if self.highlightVerified, (!self.isLookSavedMessage || self.peerId != self.account.peerId) {
                if let size = PremiumStatusControl.controlSize(self.monoforumPeer ?? self.peer, false, left: true), !status {
                    width += size.width + 2
                }
            }
            if status, let statusImage {
                width += statusImage.backingSize.width + 4
            }

            #endif
            return width
        case let .modern(_, insets):
            var width = photoSize.width + min(10, insets.left) + (leftImage != nil ? leftImage!.backingSize.width + 5 : 0)
            
            #if !SHARE
            if self.highlightVerified, (!self.isLookSavedMessage || self.peerId != self.account.peerId) {
                if let size = PremiumStatusControl.controlSize(self.monoforumPeer ?? self.peer, false, left: true), !status {
                    width += size.width + 2
                }
            }
            if status, let statusImage {
                width += statusImage.backingSize.width + 4
            }
            #endif
            return width
        }
    }
    let badgeNode: GlobalBadgeNode?
    let deleteInset:CGFloat
    
    let photoSize:NSSize
    
    let monoforumPeer: Peer?
    
    
    private var titleNode:TextNode = TextNode()
    private var statusNode:TextNode = TextNode()
    
    private(set) var title:(TextNodeLayout, TextNode)?
    private(set) var status:(TextNodeLayout, TextNode)?
    
    private(set) var titleSelected:(TextNodeLayout, TextNode)?
    private(set) var statusSelected:(TextNodeLayout, TextNode)?
    
    let leftImage:CGImage?
    
    private(set) var photo:Signal<(CGImage?, Bool), NoError>?

    let isLookSavedMessage: Bool
    let titleStyle:ControlStyle
    let statusStyle:ControlStyle
    
    private var titleAttr:NSAttributedString?
    private var statusAttr:NSAttributedString?
    let inputActivity: PeerInputActivity?
    let drawLastSeparator:Bool
    let highlightVerified: Bool
    let highlightOnHover: Bool
    let alwaysHighlight: Bool
    let drawPhotoOuter: Bool
    let photoBadge: CGImage?
    private let contextMenuItems:()->Signal<[ContextMenuItem], NoError>
    fileprivate let _peerId: PeerId?
    let disabledAction: (()->Void)?
    
    
    let story: EngineStorySubscriptions.Item?
    
    let avatarStoryIndicator: AvatarStoryIndicatorComponent?

    let openStory:(StoryInitialIndex?)->Void
    let menuOnAction: Bool
    
    let customActionText: TextViewLayout?
    let customActionTextSelected: TextViewLayout?
    
    let customAction: CustomAction?
    
    struct CustomAction {
        var title: String
        var callback:()->Void
    }
    
    let makeAvatarRound: Bool
    let drawStarsPaid: StarsAmount?
    let statusImage: CGImage?
    
    let passLeftAction: Bool
    
    let rightActions: RightActions
    
    let monoforumMessages: TextViewLayout?
    let monoforumMessagesSelected: TextViewLayout?

    
    init(_ initialSize:NSSize, peer: Peer, account: Account, context: AccountContext?, peerId: PeerId? = nil, stableId:AnyHashable? = nil, enabled: Bool = true, height:CGFloat = 50, photoSize:NSSize = NSMakeSize(36, 36), titleStyle:ControlStyle = ControlStyle(font: .medium(.title), foregroundColor: theme.colors.text, highlightColor: .white), titleAddition:String? = nil, leftImage:CGImage? = nil, statusStyle:ControlStyle = ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status:String? = nil, borderType:BorderType = [], drawCustomSeparator:Bool = true, isLookSavedMessage: Bool = false, deleteInset:CGFloat? = nil, drawLastSeparator:Bool = false, inset:NSEdgeInsets = NSEdgeInsets(left:10.0), drawSeparatorIgnoringInset: Bool = false, interactionType:ShortPeerItemInteractionType = .plain, generalType:GeneralInteractedType = .none, viewType: GeneralViewType = .legacy, action:@escaping ()->Void = {}, contextMenuItems:@escaping()->Signal<[ContextMenuItem], NoError> = { .single([]) }, inputActivity: PeerInputActivity? = nil, highlightOnHover: Bool = false, alwaysHighlight: Bool = false, badgeNode: GlobalBadgeNode? = nil, compactText: Bool = false, highlightVerified: Bool = false, customTheme: GeneralRowItem.Theme? = nil, drawPhotoOuter: Bool = false, disabledAction:(()->Void)? = nil, story: EngineStorySubscriptions.Item? = nil, openStory: @escaping(StoryInitialIndex?)->Void = { _ in }, menuOnAction: Bool = false, photoBadge: CGImage? = nil, customAction: CustomAction? = nil, makeAvatarRound: Bool = false, drawStarsPaid: StarsAmount? = nil, statusImage: CGImage? = nil, passLeftAction: Bool = false, rightActions: RightActions = .init(), monoforumPeer: Peer? = nil) {
        self.peer = peer
        self.drawPhotoOuter = drawPhotoOuter
        self.contextMenuItems = contextMenuItems
        self.context = context
        self.account = account
        self._peerId = peerId
        self.passLeftAction = passLeftAction
        self.story = story
        self.drawStarsPaid = drawStarsPaid
        self.openStory = openStory
        self.photoSize = photoSize
        self.leftImage = leftImage
        self.photoBadge = photoBadge
        self.disabledAction = disabledAction
        self.inputActivity = inputActivity
        self.menuOnAction = menuOnAction
        self.customAction = customAction
        
        self.statusImage = statusImage

        
        self.makeAvatarRound = makeAvatarRound
        self.rightActions = rightActions
        if let deleteInset = deleteInset {
            self.deleteInset = deleteInset
        } else {
            switch viewType {
            case .legacy:
                self.deleteInset = inset.left
            case let .modern(_, insets):
                self.deleteInset = insets.left
            }
        }
        
        if let customAction {
            self.customActionText = .init(.initialize(string: customAction.title, color: theme.colors.underSelectedColor, font: .medium(.text)), alignment: .center)
            self.customActionText?.measure(width: .greatestFiniteMagnitude)
            
            self.customActionTextSelected = .init(.initialize(string: customAction.title, color: theme.colors.accent, font: .medium(.text)), alignment: .center)
            self.customActionTextSelected?.measure(width: .greatestFiniteMagnitude)
        } else {
            self.customActionText = nil
            self.customActionTextSelected = nil
        }
        
        self.badgeNode = badgeNode
        self.badgeNode?.customLayout = true
        self.alwaysHighlight = alwaysHighlight
        self.highlightOnHover = highlightOnHover
        self.interactionType = interactionType
        self.drawLastSeparator = drawLastSeparator
        self.drawSeparatorIgnoringInset = drawSeparatorIgnoringInset
        self.titleStyle = titleStyle
        self.statusStyle = statusStyle
        self.isLookSavedMessage = isLookSavedMessage
        self.highlightVerified = highlightVerified
        self.monoforumPeer = monoforumPeer
        
        if let _ = monoforumPeer, peer.isMonoForum {
            self.monoforumMessages = .init(.initialize(string: strings().chatListMonoforumHolder, color: theme.colors.grayText, font: .normal(.small)), alignment: .center)
            self.monoforumMessagesSelected = .init(.initialize(string: strings().chatListMonoforumHolder, color: theme.colors.accentSelect, font: .normal(.small)), alignment: .center)
            
            self.monoforumMessages?.measure(width: .greatestFiniteMagnitude)
            self.monoforumMessagesSelected?.measure(width: .greatestFiniteMagnitude)

        } else {
            self.monoforumMessages = nil
            self.monoforumMessagesSelected = nil
        }

        if let story = story {
            self.avatarStoryIndicator = .init(story: story, presentation: theme)
        } else {
            self.avatarStoryIndicator = nil
        }
        
        
        let tAttr:NSMutableAttributedString = NSMutableAttributedString()
        if isLookSavedMessage && peer.id.isAnonymousSavedMessages {
            let icon = theme.icons.chat_hidden_author
            photo = generateEmptyPhoto(photoSize, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photoSize.width - 5, photoSize.height - 5)), cornerRadius: nil), bubble: false) |> map {($0, false)}
        } else if isLookSavedMessage && account.peerId == peer.id {
            let icon = theme.icons.searchSaved
            photo = generateEmptyPhoto(photoSize, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photoSize.width - 15, photoSize.height - 15)), cornerRadius: nil), bubble: false) |> map {($0, false)}
        } else if isLookSavedMessage && peer.id == repliesPeerId {
            let icon = theme.icons.chat_replies_avatar
            photo = generateEmptyPhoto(photoSize, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photoSize.width - 17, photoSize.height - 17)), cornerRadius: nil), bubble: false) |> map {($0, false)}

        }
        
        if let emptyAvatar = peer.emptyAvatar {
            self.photo = generateEmptyPhoto(photoSize, type: emptyAvatar, bubble: false) |> map {($0, false)}
        }
        
        if let monoforumPeer, peer.isMonoForum {
            let _ = tAttr.append(string: monoforumPeer.displayTitle, color: enabled ? titleStyle.foregroundColor : customTheme?.grayTextColor ?? theme.colors.grayText, font: self.titleStyle.font)
        } else {
            let _ = tAttr.append(string: isLookSavedMessage && account.peerId == peer.id ? strings().peerSavedMessages : (compactText ? peer.compactDisplayTitle + (account.testingEnvironment ? " [🤖]" : "") : peer.displayTitle), color: enabled ? titleStyle.foregroundColor : customTheme?.grayTextColor ?? theme.colors.grayText, font: self.titleStyle.font)
        }
        
        
        if let titleAddition = titleAddition {
            _ = tAttr.append(string: titleAddition, color: enabled ? titleStyle.foregroundColor : customTheme?.grayTextColor ?? theme.colors.grayText, font: self.titleStyle.font)
        }
        
        tAttr.addAttribute(.selectedColor, value: customTheme?.underSelectedColor ?? theme.colors.underSelectedColor, range: tAttr.range)

        
        titleAttr = tAttr.copy() as? NSAttributedString
        
        
        if let status = status {
            let sAttr:NSMutableAttributedString = NSMutableAttributedString()
            let _ = sAttr.append(string: status, color: enabled ? self.statusStyle.foregroundColor : customTheme?.grayTextColor ?? theme.colors.grayText, font: self.statusStyle.font)
            sAttr.addAttribute(.selectedColor, value: customTheme?.underSelectedColor ?? theme.colors.underSelectedColor, range: sAttr.range)
            statusAttr = sAttr.copy() as? NSAttributedString
        }
        
        super.init(initialSize, height: height, stableId: stableId ?? AnyHashable(peerId ?? peer.id), type:generalType, viewType: viewType, action:action, drawCustomSeparator:drawCustomSeparator, border:borderType,inset:inset, enabled: enabled, customTheme: customTheme)
        
    }
    
    func openPeerStory() {
        let table = self.table
        self.openStory(.init(peerId: peerId, id: nil, messageId: nil, takeControl: { [weak table] peerId, _, storyId in
            var view: NSView?
            table?.enumerateItems(with: { item in
                if let item = item as? ShortPeerRowItem, item.peerId == peerId {
                    view = item.takeStoryControl()
                }
                return view == nil
            })
            return view
        }, setProgress: { [weak self] value in
            self?.setOpenProgress(value)
        }))
    }
    
    private func takeStoryControl() -> NSView? {
        (self.view as? ShortPeerRowView)?.takeStoryControl()
    }
    
    func setOpenProgress(_ signal:Signal<Never, NoError>) {
        (self.view as? ShortPeerRowView)?.setOpenProgress(signal)
    }
    
    
    var peerId: PeerId {
        return _peerId ?? peer.id
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return contextMenuItems()
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        prepare(self.isSelected)
        return result
    }
    
    var textAdditionInset:CGFloat {
        return 0
    }
    
    

    
    override func prepare(_ selected:Bool) {
        
        var addition:CGFloat = 0
        var additionStatus: CGFloat = 0
        switch interactionType {
        case .selectable:
            addition += 30
        case .deletable:
            addition += 24 + 12
        default:
            break
        }
        
        switch type {
        case .switchable:
            addition += 48
        case .selectable:
            addition += 20
        case let .context(text):
            let attr = NSAttributedString.initialize(string: text, color: .text, font: statusStyle.font)
            addition += attr.size().width + 10
        case let .nextContext(text):
            let attr = NSAttributedString.initialize(string: text, color: .text, font: statusStyle.font)
            addition += attr.size().width + 10
        default:
            break
        }
        
        if let _ = badgeNode {
            addition += 40
        }
        
        if let monoforumMessagesSelected {
            addition += monoforumMessagesSelected.layoutSize.width + 4
        }
        
        if self.peer.isScam {
            addition += 20
        }
        if self.peer.isFake {
            addition += 20
        }
        
        if let statusImage {
            additionStatus += statusImage.backingSize.width + 4
        }
        
        if !rightActions.actions.isEmpty {
            
        }
        
        
        if let customActionText {
            addition += customActionText.layoutSize.width + 10
        }
        
        if self.highlightVerified  {
            if peer.isPremium || peer.isVerified || peer.isScam || peer.isFake {
                addition += 25
            }
        }
        switch viewType {
        case .legacy:
            if let titleAttr = titleAttr {
                title = TextNode.layoutText(maybeNode: nil,  titleAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset(false) - (inset.right) - addition - textAdditionInset - 10, 20), nil,false, .left)
                titleSelected = TextNode.layoutText(maybeNode: nil,  titleAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset(false) - (inset.right) - addition - textAdditionInset - 10, 20), nil,true, .left)
            }
            if let statusAttr = statusAttr {
                status = TextNode.layoutText(maybeNode: nil,  statusAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset(true) - (inset.right) - addition - textAdditionInset - 10, 20), nil,false, .left)
                statusSelected = TextNode.layoutText(maybeNode: nil,  statusAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset(true) - inset.right - addition - additionStatus - textAdditionInset - 10, 20), nil,true, .left)
            }
        case let .modern(_, insets):
            let textSize = NSMakeSize(self.width - textInset(false) - insets.left - insets.right - inset.left - inset.right - addition - additionStatus - textAdditionInset, 20)
            if let titleAttr = titleAttr {
                title = TextNode.layoutText(maybeNode: nil,  titleAttr, nil, 1, .end, textSize, nil, false, .left)
                titleSelected = TextNode.layoutText(maybeNode: nil, titleAttr, nil, 1, .end, textSize, nil,true, .left)
            }
            if let statusAttr = statusAttr {
                status = TextNode.layoutText(maybeNode: nil,  statusAttr, nil, 1, .end, textSize, nil,false, .left)
                statusSelected = TextNode.layoutText(maybeNode: nil,  statusAttr, nil, 1, .end, textSize, nil,true, .left)
            }
        }
        
        
    }
    
    var ctxMonoforumMessages: TextViewLayout? {
        if isSelected {
            return monoforumMessagesSelected
        }
        return monoforumMessages
    }
   
    var ctxTitle:(TextNodeLayout, TextNode)? {
        return isSelected ? titleSelected : title
    }
    var ctxStatus:(TextNodeLayout, TextNode)? {
        return isSelected ? statusSelected : status
    }
    override func viewClass() -> AnyClass {
        return ShortPeerRowView.self
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}
