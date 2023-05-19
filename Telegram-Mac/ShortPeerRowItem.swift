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
    
    let selected:Set<PeerId>
    let peers:[PeerId: Peer]
    let limit:Int32
    let inputQueryResult: ChatPresentationInputQueryResult?
    let comment: Comment
    let multipleSelection: Bool
    private let someFlagsAsNotice: Bool
    static func ==(lhs:SelectPeerPresentation, rhs:SelectPeerPresentation) -> Bool {
        return lhs.selected == rhs.selected && lhs.limit == rhs.limit && lhs.someFlagsAsNotice == rhs.someFlagsAsNotice && lhs.inputQueryResult == rhs.inputQueryResult && lhs.comment == rhs.comment && lhs.multipleSelection == rhs.multipleSelection
    }
    
    init(_ selected:Set<PeerId> = Set(), peers:[PeerId: Peer] = [:], limit: Int32 = 0, someFlagsAsNotice:Bool = false, inputQueryResult: ChatPresentationInputQueryResult? = nil, comment: Comment = Comment(string: "", range: NSMakeRange(0, 0)), multipleSelection: Bool = true) {
        self.selected = selected
        self.peers = peers
        self.limit = limit
        self.someFlagsAsNotice = someFlagsAsNotice
        self.inputQueryResult = inputQueryResult
        self.comment = comment
        self.multipleSelection = multipleSelection
    }
    
    func deselect(peerId:PeerId) -> SelectPeerPresentation {
        var selectedIds:Set<PeerId> = Set<PeerId>()
        var peers:[PeerId: Peer] = self.peers
        selectedIds.formUnion(selected)
        let _ = selectedIds.remove(peerId)
        peers.removeValue(forKey: peerId)
        return SelectPeerPresentation(selectedIds, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: self.multipleSelection)
    }
    
    var isLimitReached: Bool {
        return limit > 0 && limit == selected.count
    }
    
    func withUpdateLimit(_ limit: Int32) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: multipleSelection)
    }
    func withUpdatedMultipleSelection(_ multipleSelection: Bool) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: multipleSelection)
    }
    
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: f(inputQueryResult), comment: comment, multipleSelection: multipleSelection)
    }
    
    func withUpdatedComment(_ comment: Comment) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: multipleSelection)
    }
    
    func withToggledSelected(_ peerId: PeerId, peer:Peer) -> SelectPeerPresentation {
        var someFlagsAsNotice: Bool = self.someFlagsAsNotice
        var selectedIds:Set<PeerId> = Set<PeerId>()
        var peers:[PeerId: Peer] = self.peers
        selectedIds.formUnion(selected)
        if selectedIds.contains(peerId) {
            let _ = selectedIds.remove(peerId)
            peers.removeValue(forKey: peerId)
        } else {
            if limit == 0 || selected.count < limit {
                selectedIds.insert(peerId)
                peers[peerId] = peer
            } else {
                someFlagsAsNotice = !someFlagsAsNotice
            }
        }
        return SelectPeerPresentation(selectedIds, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice, inputQueryResult: inputQueryResult, comment: comment, multipleSelection: multipleSelection)
    }
    
}

final class SelectPeerInteraction : InterfaceObserver {
    private(set) var presentation:SelectPeerPresentation = SelectPeerPresentation()
    var close: ()->Void = {}
    var action:(PeerId, Int64?)->Void = { _, _ in }
    var openForum:(PeerId)->Void = { _ in }
    var singleUpdater:((SelectPeerPresentation)->Void)? = nil
    func update(animated:Bool = true, _ f:(SelectPeerPresentation)->SelectPeerPresentation)->Void {
        let oldValue = self.presentation
        presentation = f(presentation)
        
        if oldValue != presentation {
            notifyObservers(value: presentation, oldValue:oldValue, animated:animated)
        }
        self.singleUpdater?(presentation)
    }
    
    func toggleSelection( _ peer: Peer) {
        self.update(animated: true, {
            $0.withToggledSelected(peer.id, peer: peer)
                .withUpdatedMultipleSelection(true)
        })
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
    case plain
    case deletable(onRemove:(PeerId)->Void, deletable:Bool)
    case selectable(SelectPeerInteraction)
}



class ShortPeerRowItem: GeneralRowItem {
    let peer:Peer
    let context: AccountContext?
    let account: Account
    let interactionType:ShortPeerItemInteractionType
    let drawSeparatorIgnoringInset:Bool
    var textInset:CGFloat {
        switch viewType {
        case .legacy:
            return inset.left + photoSize.width + 10.0 + (leftImage != nil ? leftImage!.backingSize.width + 5 : 0)
        case let .modern(_, insets):
            return photoSize.width + min(10, insets.left) + (leftImage != nil ? leftImage!.backingSize.width + 5 : 0)
        }
    }
    let badgeNode: GlobalBadgeNode?
    let deleteInset:CGFloat
    
    let photoSize:NSSize
    
    
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
    private let contextMenuItems:()->Signal<[ContextMenuItem], NoError>
    fileprivate let _peerId: PeerId?
    init(_ initialSize:NSSize, peer: Peer, account: Account, context: AccountContext?, peerId: PeerId? = nil, stableId:AnyHashable? = nil, enabled: Bool = true, height:CGFloat = 50, photoSize:NSSize = NSMakeSize(36, 36), titleStyle:ControlStyle = ControlStyle(font: .medium(.title), foregroundColor: theme.colors.text, highlightColor: .white), titleAddition:String? = nil, leftImage:CGImage? = nil, statusStyle:ControlStyle = ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status:String? = nil, borderType:BorderType = [], drawCustomSeparator:Bool = true, isLookSavedMessage: Bool = false, deleteInset:CGFloat? = nil, drawLastSeparator:Bool = false, inset:NSEdgeInsets = NSEdgeInsets(left:10.0), drawSeparatorIgnoringInset: Bool = false, interactionType:ShortPeerItemInteractionType = .plain, generalType:GeneralInteractedType = .none, viewType: GeneralViewType = .legacy, action:@escaping ()->Void = {}, contextMenuItems:@escaping()->Signal<[ContextMenuItem], NoError> = { .single([]) }, inputActivity: PeerInputActivity? = nil, highlightOnHover: Bool = false, alwaysHighlight: Bool = false, badgeNode: GlobalBadgeNode? = nil, compactText: Bool = false, highlightVerified: Bool = false, customTheme: GeneralRowItem.Theme? = nil, drawPhotoOuter: Bool = false) {
        self.peer = peer
        self.drawPhotoOuter = drawPhotoOuter
        self.contextMenuItems = contextMenuItems
        self.context = context
        self.account = account
        self._peerId = peerId
        self.photoSize = photoSize
        self.leftImage = leftImage
        self.inputActivity = inputActivity
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

        
        let tAttr:NSMutableAttributedString = NSMutableAttributedString()
        if isLookSavedMessage && account.peerId == peer.id {
            let icon = theme.icons.searchSaved
            photo = generateEmptyPhoto(photoSize, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photoSize.width - 15, photoSize.height - 15)), cornerRadius: nil)) |> map {($0, false)}
        } else if isLookSavedMessage && peer.id == repliesPeerId {
            let icon = theme.icons.chat_replies_avatar
            photo = generateEmptyPhoto(photoSize, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photoSize.width - 17, photoSize.height - 17)), cornerRadius: nil)) |> map {($0, false)}

        }
        
        if let emptyAvatar = peer.emptyAvatar {
            self.photo = generateEmptyPhoto(photoSize, type: emptyAvatar) |> map {($0, false)}
        }
        
        let _ = tAttr.append(string: isLookSavedMessage && account.peerId == peer.id ? strings().peerSavedMessages : (compactText ? peer.compactDisplayTitle + (account.testingEnvironment ?? false ? " [🤖]" : "") : peer.displayTitle), color: enabled ? titleStyle.foregroundColor : customTheme?.grayTextColor ?? theme.colors.grayText, font: self.titleStyle.font)
        
        if let titleAddition = titleAddition {
            _ = tAttr.append(string: titleAddition, color: enabled ? titleStyle.foregroundColor : customTheme?.grayTextColor ?? theme.colors.grayText, font: self.titleStyle.font)
        }
        
        tAttr.addAttribute(.selectedColor, value: customTheme?.underSelectedColor ?? theme.colors.underSelectedColor, range: tAttr.range)

        
        titleAttr = tAttr.copy() as? NSAttributedString
        
        
        if let status = status {
            let sAttr:NSMutableAttributedString = NSMutableAttributedString()
            let _ = sAttr.append(string: status, color: enabled ? self.statusStyle.foregroundColor : customTheme?.grayTextColor ?? theme.colors.grayText, font: self.statusStyle.font, coreText: true)
            sAttr.addAttribute(.selectedColor, value: customTheme?.underSelectedColor ?? theme.colors.underSelectedColor, range: sAttr.range)
            statusAttr = sAttr.copy() as? NSAttributedString
        }
        
        super.init(initialSize, height: height, stableId: stableId ?? AnyHashable(peerId ?? peer.id), type:generalType, viewType: viewType, action:action, drawCustomSeparator:drawCustomSeparator, border:borderType,inset:inset, enabled: enabled, customTheme: customTheme)
        
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
        switch interactionType {
        case .selectable(_):
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
        
        if self.peer.isScam {
            addition += 20
        }
        if self.peer.isFake {
            addition += 20
        }
        if self.highlightVerified  {
            if peer.isPremium || peer.isVerified || peer.isScam || peer.isFake {
                addition += 25
            }
        }
        switch viewType {
        case .legacy:
            if let titleAttr = titleAttr {
                title = TextNode.layoutText(maybeNode: nil,  titleAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset - (inset.right) - addition - textAdditionInset, 20), nil,false, .left)
                titleSelected = TextNode.layoutText(maybeNode: nil,  titleAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset - (inset.right) - addition - textAdditionInset, 20), nil,true, .left)
            }
            if let statusAttr = statusAttr {
                status = TextNode.layoutText(maybeNode: nil,  statusAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset - (inset.right) - addition - textAdditionInset, 20), nil,false, .left)
                statusSelected = TextNode.layoutText(maybeNode: nil,  statusAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset - inset.right - addition - textAdditionInset, 20), nil,true, .left)
            }
        case let .modern(_, insets):
            let textSize = NSMakeSize(self.width - textInset - insets.left - insets.right - inset.left - inset.right - addition - textAdditionInset, 20)
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
