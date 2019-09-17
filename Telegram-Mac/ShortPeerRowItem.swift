//
//  ShortPeerRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 29/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

final class SelectPeerPresentation : Equatable {
    let selected:Set<PeerId>
    let peers:[PeerId: Peer]
    let limit:Int32
    private let someFlagsAsNotice: Bool
    static func ==(lhs:SelectPeerPresentation, rhs:SelectPeerPresentation) -> Bool {
        return lhs.selected == rhs.selected && lhs.limit == rhs.limit && lhs.someFlagsAsNotice == rhs.someFlagsAsNotice
    }
    
    init(_ selected:Set<PeerId> = Set(), peers:[PeerId: Peer] = [:], limit: Int32 = 0, someFlagsAsNotice:Bool = false) {
        self.selected = selected
        self.peers = peers
        self.limit = limit
        self.someFlagsAsNotice = someFlagsAsNotice
    }
    
    func deselect(peerId:PeerId) -> SelectPeerPresentation {
        var selectedIds:Set<PeerId> = Set<PeerId>()
        var peers:[PeerId: Peer] = self.peers
        selectedIds.formUnion(selected)
        let _ = selectedIds.remove(peerId)
        peers.removeValue(forKey: peerId)
        return SelectPeerPresentation(selectedIds, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice)
    }
    
    var isLimitReached: Bool {
        return limit > 0 && limit == selected.count
    }
    
    func withUpdateLimit(_ limit: Int32) -> SelectPeerPresentation {
        return SelectPeerPresentation(selected, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice)
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
        return SelectPeerPresentation(selectedIds, peers: peers, limit: limit, someFlagsAsNotice: someFlagsAsNotice)
    }
    
}

final class SelectPeerInteraction : InterfaceObserver {
    private(set) var presentation:SelectPeerPresentation = SelectPeerPresentation()
    var close: ()->Void = {}
    var action:(PeerId)->Void = {_ in}
    func update(animated:Bool = true, _ f:(SelectPeerPresentation)->SelectPeerPresentation)->Void {
        let oldValue = self.presentation
        presentation = f(presentation)
        
        if oldValue != presentation {
            notifyObservers(value: presentation, oldValue:oldValue, animated:animated)
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
    case plain
    case deletable(onRemove:(PeerId)->Void, deletable:Bool)
    case selectable(SelectPeerInteraction)
}



class ShortPeerRowItem: GeneralRowItem {
    let peer:Peer
    let account:Account

    let interactionType:ShortPeerItemInteractionType
    let drawSeparatorIgnoringInset:Bool
    var textInset:CGFloat {
        switch viewType {
        case .legacy:
            return inset.left + photoSize.width + 10.0 + (leftImage != nil ? leftImage!.backingSize.width + 5 : 0)
        case let .modern(_, insets):
            return photoSize.width + insets.left + (leftImage != nil ? leftImage!.backingSize.width + 5 : 0)
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
    private let contextMenuItems:()->[ContextMenuItem]
    init(_ initialSize:NSSize, peer: Peer, account:Account, stableId:AnyHashable? = nil, enabled: Bool = true, height:CGFloat = 50, photoSize:NSSize = NSMakeSize(36, 36), titleStyle:ControlStyle = ControlStyle(font: .medium(.title), foregroundColor: theme.colors.text, highlightColor: .white), titleAddition:String? = nil, leftImage:CGImage? = nil, statusStyle:ControlStyle = ControlStyle(font:.normal(.text), foregroundColor: theme.colors.grayText, highlightColor:.white), status:String? = nil, borderType:BorderType = [], drawCustomSeparator:Bool = true, isLookSavedMessage: Bool = false, deleteInset:CGFloat? = nil, drawLastSeparator:Bool = false, inset:NSEdgeInsets = NSEdgeInsets(left:10.0), drawSeparatorIgnoringInset: Bool = false, interactionType:ShortPeerItemInteractionType = .plain, generalType:GeneralInteractedType = .none, viewType: GeneralViewType = .legacy, action:@escaping ()->Void = {}, contextMenuItems:@escaping()->[ContextMenuItem] = {[]}, inputActivity: PeerInputActivity? = nil, highlightOnHover: Bool = false, alwaysHighlight: Bool = false, badgeNode: GlobalBadgeNode? = nil, compactText: Bool = false, highlightVerified: Bool = false) {
        self.peer = peer
        self.contextMenuItems = contextMenuItems
        self.account = account
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
        let icon = theme.icons.searchSaved

        
        let tAttr:NSMutableAttributedString = NSMutableAttributedString()
        if isLookSavedMessage && account.peerId == peer.id {
            photo = generateEmptyPhoto(photoSize, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(photoSize.width - 15, photoSize.height - 15)), cornerRadius: nil)) |> map {($0, false)}
        }
        let _ = tAttr.append(string: isLookSavedMessage && account.peerId == peer.id ? L10n.peerSavedMessages : (compactText ? peer.compactDisplayTitle + (account.testingEnvironment ? " [🤖]" : "") : peer.displayTitle), color: enabled ? titleStyle.foregroundColor : theme.colors.grayText, font: self.titleStyle.font)
        
        if let titleAddition = titleAddition {
            _ = tAttr.append(string: titleAddition, color: enabled ? titleStyle.foregroundColor : theme.colors.grayText, font: self.titleStyle.font)
        }
        
        tAttr.addAttribute(.selectedColor, value: theme.colors.underSelectedColor, range: tAttr.range)

        
        titleAttr = tAttr.copy() as? NSAttributedString
        
        
        if let status = status {
            let sAttr:NSMutableAttributedString = NSMutableAttributedString()
            let _ = sAttr.append(string: status, color: enabled ? self.statusStyle.foregroundColor : theme.colors.grayText, font: self.statusStyle.font, coreText: true)
            sAttr.addAttribute(.selectedColor, value: theme.colors.underSelectedColor, range: sAttr.range)
            statusAttr = sAttr.copy() as? NSAttributedString
        }
        
        super.init(initialSize, height: height, stableId: stableId ?? AnyHashable(peer.id), type:generalType, viewType: viewType, action:action, drawCustomSeparator:drawCustomSeparator, border:borderType,inset:inset, enabled: enabled)
        
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return .single(contextMenuItems())
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
        
        switch viewType {
        case .legacy:
            if let titleAttr = titleAttr {
                title = TextNode.layoutText(maybeNode: nil,  titleAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset - (inset.right == 0 ? 10 : inset.right) - addition - textAdditionInset, 20), nil,false, .left)
                titleSelected = TextNode.layoutText(maybeNode: nil,  titleAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset - (inset.right == 0 ? 10 : inset.right) - addition - textAdditionInset, 20), nil,true, .left)
            }
            if let statusAttr = statusAttr {
                status = TextNode.layoutText(maybeNode: nil,  statusAttr, nil, 1, .end, NSMakeSize(self.size.width - textInset - (inset.right == 0 ? 10 : inset.right) - addition - textAdditionInset, 20), nil,false, .left)
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
