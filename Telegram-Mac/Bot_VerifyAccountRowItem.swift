//
//  Bot_VerifyAccountRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13.12.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//
import TelegramCore
import SwiftSignalKit
import TGUIKit
import Cocoa


final class Bot_VerifyAccountRowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let peer: EnginePeer
    fileprivate let fileId: Int64
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: EnginePeer, context: AccountContext, fileId: Int64) {
        self.context = context
        self.peer = peer
        self.fileId = fileId
        
        super.init(initialSize, height: 50, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        return true
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return Bot_VerifyAccountRowView.self
    }
}

private final class Bot_VerifyAccountRowView : GeneralRowView {
    private final class PeerView: Control {
        private let avatarView = AvatarControl(font: .avatar(10))
        private let nameView: TextView = TextView()
        private var stickerView: InlineStickerView?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(avatarView)
            addSubview(nameView)
            
            nameView.userInteractionEnabled = false
            
            self.avatarView.setFrameSize(NSMakeSize(26, 26))
            
            layer?.cornerRadius = 13
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(_ peer: EnginePeer, _ context: AccountContext, file: TelegramMediaFile, maxWidth: CGFloat) {
            self.avatarView.setPeer(account: context.account, peer: peer._asPeer())
            
            let nameLayout = TextViewLayout(.initialize(string: peer._asPeer().displayTitle, color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 1)
            nameLayout.measure(width: maxWidth)
            
            nameView.update(nameLayout)
            
            if let stickerView {
                performSubviewRemoval(stickerView, animated: true)
            }
            
            let current: InlineStickerView = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: file.fileId.id, file: file, emoji: ""), size: NSMakeSize(20, 20))
            addSubview(current)
            self.stickerView = current
            
            setFrameSize(NSMakeSize(avatarView.frame.width + 10 + nameLayout.layoutSize.width + (stickerView != nil ? 20 : 0) + 10, 26))
            
            self.background = theme.colors.grayForeground
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            if let stickerView {
                stickerView.centerY(x: self.avatarView.frame.maxX + 6)
                nameView.centerY(x: stickerView.frame.maxX + 2, addition: -1)
            } else {
                nameView.centerY(x: self.avatarView.frame.maxX + 10, addition: -1)
            }
        }
    }
    
    private let peerView: PeerView = .init(frame: .zero)
        
    private var timer: SwiftSignalKit.Timer?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(peerView)
    }
    
     required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Bot_VerifyAccountRowItem else {
            return
        }
        
        let signal = item.context.inlinePacksContext.load(fileId: item.fileId) |> deliverOnMainQueue
        
        _ = signal.start(next: { [weak self, weak item] file in
            if let self, let item, let file {
                self.peerView.set(item.peer, item.context, file: file, maxWidth: self.frame.width - 40)
                self.needsLayout = true
            }
        })
    }
    
    
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func layout() {
        super.layout()
        
        peerView.centerX(y: 0)
    }
}
