//
//  ChatContactRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 22/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import Postbox
import SwiftSignalKit
import Contacts
import ColorPalette
import TelegramMedia

class ChatContactRowItem: ChatRowItem {

    let contactPeer:Peer?
    let phoneLayout:TextViewLayout
    let nameLayout: TextViewLayout
    let contact: TelegramMediaContact
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        
        if let message = object.message, let contact = message.media[0] as? TelegramMediaContact {
            let attr = NSMutableAttributedString()
            
            let isIncoming: Bool = message.isIncoming(context.account, object.renderType == .bubble)
            

            self.contact = contact
            
            let name = isNotEmptyStrings([contact.firstName + (!contact.firstName.isEmpty ? " " : "") + contact.lastName])

            if let peerId = contact.peerId {
                self.contactPeer = message.peers[peerId]
            } else {
                self.contactPeer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, firstName: name.components(separatedBy: " ").first ?? name, lastName: name.components(separatedBy: " ").count == 2 ? name.components(separatedBy: " ").last : "", username: nil, phone: contact.phoneNumber, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil)
            }
            
            let color = theme.chat.contactActivity(context.peerNameColors, contactPeer: contactPeer, account: context.account, isIncoming: isIncoming, bubbled: object.renderType == .bubble)


            if let peerId = contact.peerId {
                let range = attr.append(string: name, font: .medium(.text))
                attr.add(link: inAppLink.peerInfo(link: "", peerId:peerId,action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: color.main)
                phoneLayout = TextViewLayout(.initialize(string: formatPhoneNumber(contact.phoneNumber), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end, alignment: .left)

            } else {
                _ = attr.append(string: name, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                phoneLayout = TextViewLayout(.initialize(string: formatPhoneNumber(contact.phoneNumber), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
            }
            nameLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
            nameLayout.interactions = globalLinkExecutor
            
        } else {
            fatalError("contact not found for item")
        }
        
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
    }
    
    var color: PeerNameColors.Colors {
        return presentation.chat.contactActivity(context.peerNameColors, contactPeer: contactPeer, account: context.account, isIncoming: isIncoming, bubbled: renderType == .bubble)
    }
    
    override var isForceRightLine: Bool {
        if let line = phoneLayout.lines.last, (line.frame.width + 50) > realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
            return true
        }
        return super.isForceRightLine
    }   
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        nameLayout.measure(width: width - 50)
        phoneLayout.measure(width: width - 50)
        return NSMakeSize(max(nameLayout.layoutSize.width, phoneLayout.layoutSize.width) + 50 + 20, 8 + 40 + (contact.peerId != nil ? 40 : 8))
    }
    
    override func viewClass() -> AnyClass {
        return ChatContactRowView.self
    }
    
    func openContact() {
        if let peerId = contact.peerId {
            chatInteraction.openInfo(peerId, true , nil, nil)
        } else {
            copyToClipboard(formatPhoneNumber(contact.phoneNumber))
            showModalText(for: context.window, text: strings().shareLinkCopied)
        }
    }

}


class ChatContactRowView : ChatRowView {
    
    private final class Container : Control {
        private let contactPhotoView:AvatarControl = AvatarControl(font: .avatar(.title))
        private let nameView: TextView = TextView()
        private let phoneView: TextView = TextView()
        private var actionButton: TextButton?
        private var item: ChatContactRowItem?
        private let dashLayer = DashLayer()
        
        private var borderView = View()

        private var patternContentLayers: [SimpleLayer] = []
        private var patternTarget: InlineStickerItemLayer?

        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            isDynamicColorUpdateLocked = true
            
            self.layer?.addSublayer(dashLayer)
            
            addSubview(contactPhotoView)
            contactPhotoView.setFrameSize(40,40)
            nameView.isSelectable = false
            nameView.userInteractionEnabled = false
            addSubview(nameView)
            
            phoneView.isSelectable = false
            phoneView.userInteractionEnabled = false
            addSubview(phoneView)
            
            addSubview(borderView)
            
            contactPhotoView.userInteractionEnabled = false
            
            self.set(handler: { [weak self] control in
                if let peerId = self?.item?.contactPeer?.id {
                    self?.item?.openContact()
                }
            }, for: .Click)
            
            self.scaleOnClick = true
            self.layer?.cornerRadius = .cornerRadius

        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            contactPhotoView.setFrameOrigin(NSMakePoint(10, 8))
            nameView.setFrameOrigin(60, contactPhotoView.frame.minY + 3)
            phoneView.setFrameOrigin(60, nameView.frame.maxY + 1)
            actionButton?.setFrameOrigin(0, contactPhotoView.frame.maxY + 8)
            if let actionButton = self.actionButton {
                borderView.frame = NSMakeRect(10, actionButton.frame.minY, frame.width - 20, .borderSize)
            }
        }
        
        func set(item: ChatContactRowItem, animated: Bool) {
            
            self.item = item
            
            contactPhotoView.setPeer(account: item.context.account, peer: item.contactPeer)
            
            let color = item.color
            
            self.backgroundColor = color.main.withMultipliedAlpha(0.1)
            self.borderView.backgroundColor = color.main.withMultipliedAlpha(0.1)
            
            nameView.update(item.nameLayout)
            phoneView.update(item.phoneLayout)
            
            var x: CGFloat = 0
            var y: CGFloat = 0
            var width: CGFloat = 3
            var height: CGFloat = item.contentSize.height
            var cornerRadius: CGFloat = 0
            
            
            let borderRect = NSMakeRect(x, y, width, height)
            dashLayer.frame = borderRect
            dashLayer.cornerRadius = cornerRadius
            
            dashLayer.colors = item.color
            borderView.isHidden = item.contact.peerId == nil
            
            if let _ = item.contact.peerId {
                let current: TextButton
                if let view = self.actionButton {
                    current = view
                } else {
                    current = TextButton()
                    current.userInteractionEnabled = false
                    current.disableActions()
                    current.set(font: .medium(.text), for: .Normal)
                    addSubview(current)
                    self.actionButton = current
                }
                
                current.removeAllHandlers()
                current.set(text: strings().chatContactSendMessage, for: .Normal)
                current.set(background: .clear, for: .Normal)
                current.set(color: color.main, for: .Normal)
                _ = current.sizeToFit(NSZeroSize, NSMakeSize(item.contentSize.width, 30), thatFit: true)
                
            } else if let view = self.actionButton {
                performSubviewRemoval(view, animated: animated)
                actionButton = nil
            }
            if let pattern = item.contactPeer?.backgroundEmojiId {
                if patternTarget?.textColor != color.main {
                    patternTarget = .init(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: pattern, file: nil, emoji: ""), size: NSMakeSize(64, 64), playPolicy: .framesCount(1), textColor: color.main)
                    patternTarget?.noDelayBeforeplay = true
                    patternTarget?.isPlayable = true
                    self.updatePatternLayerImages()
                }
                patternTarget?.contentDidUpdate = { [weak self] content in
                    self?.updatePatternLayerImages()
                }
            } else {
                patternTarget = nil
                self.updatePatternLayerImages()
            }
            
            if patternTarget != nil {
                var maxIndex = 0
                
                struct Placement {
                    var position: CGPoint
                    var size: CGFloat
                    
                    init(_ position: CGPoint, _ size: CGFloat) {
                        self.position = position
                        self.size = size
                    }
                }
                
                let placements: [Placement] = [
                    Placement(CGPoint(x: 176.0, y: 13.0), 38.0),
                    Placement(CGPoint(x: 51.0, y: 45.0), 58.0),
                    Placement(CGPoint(x: 349.0, y: 36.0), 58.0),
                    Placement(CGPoint(x: 132.0, y: 64.0), 46.0),
                    Placement(CGPoint(x: 241.0, y: 64.0), 54.0),
                    Placement(CGPoint(x: 68.0, y: 121.0), 44.0),
                    Placement(CGPoint(x: 178.0, y: 122.0), 47.0),
                    Placement(CGPoint(x: 315.0, y: 122.0), 47.0),
                ]
                
                for placement in placements {
                    let patternContentLayer: SimpleLayer
                    if maxIndex < self.patternContentLayers.count {
                        patternContentLayer = self.patternContentLayers[maxIndex]
                    } else {
                        patternContentLayer = SimpleLayer()
                        patternContentLayer.layerTintColor = color.main.cgColor
                        self.layer?.addSublayer(patternContentLayer)
                        self.patternContentLayers.append(patternContentLayer)
                    }
                   // patternContentLayer.contents = patternTarget?.contents // self.patternContentsTarget?.contents
                    
                    let itemSize = CGSize(width: placement.size / 3.0, height: placement.size / 3.0)
                    patternContentLayer.frame = CGRect(origin: CGPoint(x: item.contentSize.width - placement.position.x / 3.0 - itemSize.width * 0.5, y: placement.position.y / 3.0 - itemSize.height * 0.5), size: itemSize)
                    
                    var alphaFraction = abs(placement.position.x) / 400.0
                    alphaFraction = min(1.0, max(0.0, alphaFraction))
                    patternContentLayer.opacity = 0.3 * Float(1.0 - alphaFraction)
                    
                    maxIndex += 1
                }
                
                if maxIndex < self.patternContentLayers.count {
                    for i in maxIndex ..< self.patternContentLayers.count {
                        self.patternContentLayers[i].removeFromSuperlayer()
                    }
                    self.patternContentLayers.removeSubrange(maxIndex ..< self.patternContentLayers.count)
                }
            } else {
                for patternContentLayer in self.patternContentLayers {
                    patternContentLayer.removeFromSuperlayer()
                }
                self.patternContentLayers.removeAll()
            }
        }
        private func updatePatternLayerImages() {
            let image = self.patternTarget?.contents
            for patternContentLayer in self.patternContentLayers {
                patternContentLayer.contents = image
            }
        }
    }
        
    private let container = Container(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
    }
    
    override func updateColors() {
        super.updateColors()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ChatContactRowItem {
            self.container.set(item: item, animated: animated)
            self.container.setFrameSize(item.contentSize)
        }
    }
    
}
