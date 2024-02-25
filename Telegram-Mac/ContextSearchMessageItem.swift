//
//  ContextSearchMessageItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/11/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import DateUtils
import TGUIKit
import Postbox
import Strings

class ContextSearchMessageItem: GeneralRowItem {
    
    let message:Message
    
    let context: AccountContext
    let peer:Peer
    var peerId:PeerId {
        return peer.id
    }
    
    let photo: AvatarNodeState
    
   
    override var stableId: AnyHashable {
        return message.id
    }
    
    
    private var date:NSAttributedString?
    
    private var displayLayout:(TextNodeLayout, TextNode)?

    private var displaySelectedLayout:(TextNodeLayout, TextNode)?
    private var dateLayout:(TextNodeLayout, TextNode)?
    private var dateSelectedLayout:(TextNodeLayout, TextNode)?
    
    private var displayNode:TextNode = TextNode()
    private var displaySelectedNode:TextNode = TextNode()
    
    private let titleText:NSAttributedString
    
    private var messageLayout: TextViewLayout
    private var messageSelectedLayout: TextViewLayout

    
    init(_ initialSize:NSSize, context: AccountContext, message: Message, searchText: String, action: @escaping()->Void) {
        self.context = context
        self.message = message

        
        self.peer = message.chatPeer(context.peerId)!
        
        var peer:Peer = self.peer
        
        var title:String = peer.displayTitle
        let mainPeer = coreMessageMainPeer(message)

        if let _peer = mainPeer as? TelegramChannel, case .broadcast(_) = _peer.info {
            title = _peer.displayTitle
            peer = _peer
        }
        
        
        var nameColor:NSColor = theme.chat.linkColor(true, false)
        
        if mainPeer is TelegramChannel || mainPeer is TelegramGroup {
            if let peer = mainPeer as? TelegramChannel, case .broadcast(_) = peer.info {
                nameColor = theme.chat.linkColor(true, false)
            } else if context.peerId != peer.id {
                let value = abs(Int(peer.id.id._internalGetInt64Value()) % 7)
                nameColor = theme.chat.peerName(value)
            }
        }
        
        let titleText:NSMutableAttributedString = NSMutableAttributedString()
        let _ = titleText.append(string: title, color: nameColor, font: .medium(.text))
        titleText.setSelected(color: theme.colors.underSelectedColor ,range: titleText.range)
        
        self.titleText = titleText
        let messageTitle = NSMutableAttributedString()
        
        var text = pullText(from: message).string as String
        if text.isEmpty {
            text = serviceMessageText(message, account: context.account).0
        }
        _ = messageTitle.append(string: text, color: theme.colors.text, font: .normal(.text))
        
        let string = text
        let subranges = findSubstringRanges(in: string.lowercased(), query: searchText.lowercased()).0
//
        

        
        self.messageLayout = TextViewLayout(messageTitle.trimNewLinesToSpace, maximumNumberOfLines: 1, truncationType: .end, strokeLinks: true)
//        let selectRange = messageTitle.string.lowercased().nsstring.range(of: searchText.lowercased())
        
        
//        if selectRange.location != NSNotFound {
//            self.messageLayout.additionalSelections = [TextSelectedRange(range: selectRange, color: theme.colors.accentIcon.withAlphaComponent(0.5), def: false)]
//        }
        
        
        let selectedAttrText = messageTitle.mutableCopy() as! NSMutableAttributedString
        selectedAttrText.addAttribute(.foregroundColor, value: NSColor.white, range: selectedAttrText.range)
        self.messageSelectedLayout = TextViewLayout(selectedAttrText, maximumNumberOfLines: 1, truncationType: .end, strokeLinks: true)

        
        let date:NSMutableAttributedString = NSMutableAttributedString()
        var time:TimeInterval = TimeInterval(message.timestamp)
        time -= context.timeDifference
        let range = date.append(string: DateUtils.string(forMessageListDate: Int32(time)), color: theme.colors.grayText, font: .normal(.short))
        date.setSelected(color: theme.colors.underSelectedColor, range: range)
        self.date = date.copy() as? NSAttributedString
        
        dateLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, false, .left)
        dateSelectedLayout = TextNode.layoutText(maybeNode: nil,  date, nil, 1, .end, NSMakeSize( .greatestFiniteMagnitude, 20), nil, true, .left)
        
        self.photo = .PeerAvatar(peer, peer.displayLetters, peer.smallProfileImage, peer.nameColor, message, nil, peer.isForum)
        
        super.init(initialSize, height: 44, action: action)

        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    let margin:CGFloat = 5
    
    var titleWidth:CGFloat {
        var dateSize:CGFloat = 0
        if let dateLayout = dateLayout {
            dateSize = dateLayout.0.size.width
        }
        
        return size.width - 50 - margin * 4 - dateSize
    }
    var messageWidth:CGFloat {
        var dateSize:CGFloat = 0
        if let dateLayout = dateLayout {
            dateSize = dateLayout.0.size.width
        }
        return size.width - 70 - margin * 4 - dateSize
    }
    
    let leftInset:CGFloat = 40 + 20;
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        if displayLayout == nil || !displayLayout!.0.isPerfectSized || self.oldWidth > width {
            displayLayout = TextNode.layoutText(maybeNode: displayNode,  titleText, nil, 1, .end, NSMakeSize(titleWidth, size.height), nil, false, .left)
        }
        
        messageLayout.measure(width: messageWidth)
        messageSelectedLayout.measure(width: messageWidth)
        
        if displaySelectedLayout == nil || !displaySelectedLayout!.0.isPerfectSized || self.oldWidth > width {
            displaySelectedLayout = TextNode.layoutText(maybeNode: displaySelectedNode,  titleText, nil, 1, .end, NSMakeSize(titleWidth, size.height), nil, true, .left)
        }
        
        return result
    }


  
    
    var ctxDisplayLayout:(TextNodeLayout, TextNode)? {
        if isSelected {
            return displaySelectedLayout
        }
        return displayLayout
    }
    var ctxMessageLayout: TextViewLayout {
        if isSelected {
            return messageSelectedLayout
        }

        return messageLayout
    }
    var ctxDateLayout:(TextNodeLayout, TextNode)? {
        if isSelected {
            return dateSelectedLayout
        }
        return dateLayout
    }

    override var instantlyResize: Bool {
        return true
    }
    

    override func viewClass() -> AnyClass {
        return ContextSearchMessageView.self
    }
}

private class ContextSearchMessageView : GeneralRowView {
    
    
    private var titleText:TextNode = TextNode()
    private var messageText:TextView = TextView()
    private var photo:AvatarControl = AvatarControl(font: .avatar(14))

    
    
    override var isFlipped: Bool {
        return true
    }
    
    
    
    
    override var backdorColor: NSColor {
        if let item = item {
            if item.isHighlighted && !item.isSelected {
                return theme.colors.grayHighlight
            } else if item.isSelected {
                return theme.chatList.selectedBackgroundColor
            }
            
        }
        
        return theme.colors.background
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        

        super.draw(layer, in: ctx)
        //
        if let item = self.item as? ContextSearchMessageItem {

            
            if !item.isSelected {
                
                if backingScaleFactor == 1.0 {
                    ctx.setFillColor(backdorColor.cgColor)
                    ctx.fill(layer.bounds)
                }
                
                ctx.setFillColor(theme.colors.border.cgColor)
                ctx.fill(NSMakeRect(item.leftInset, NSHeight(layer.bounds) - .borderSize, layer.bounds.width - item.leftInset, .borderSize))
            }
            
            
            
            if let displayLayout = item.ctxDisplayLayout {
                
                displayLayout.1.draw(NSMakeRect(item.leftInset, item.margin - 1, displayLayout.0.size.width, displayLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                
                
                
                if let dateLayout = item.ctxDateLayout {
                    let dateX = frame.width - dateLayout.0.size.width - 20
                    let dateFrame = focus(dateLayout.0.size)
                    dateLayout.1.draw(NSMakeRect(dateX, dateFrame.minY, dateLayout.0.size.width, dateLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                    
                }
            }
        }
        
    }
    
    
    
    required init(frame frameRect: NSRect) {
        
        
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        photo.userInteractionEnabled = false
        photo.frame = NSMakeRect(20, 8, 30, 30)
        addSubview(photo)
        addSubview(messageText)
        messageText.userInteractionEnabled = false
        messageText.isSelectable = false
        
        
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? ContextSearchMessageItem else {return}
        photo.centerY(x: 20)
        messageText.setFrameOrigin(item.leftInset, frame.height - messageText.frame.height - item.margin - 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func updateColors() {
        super.updateColors()
        messageText.backgroundColor = backdorColor
    }

    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ContextSearchMessageItem else {return}
        
        photo.setState(account: item.context.account, state: item.photo)
        messageText.update(item.ctxMessageLayout)
        
        self.toolTip = item.ctxMessageLayout.attributedString.string.prefixWithDots(300)
    }
    
}
