//
//  MessageContactMenuItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore

final class MessageContactMenuItem : ContextMenuItem {
   
    private let context: AccountContext
    private let phoneNumber: String
    init(handler:@escaping()->Void, phoneNumber: String, context: AccountContext) {
        self.phoneNumber = phoneNumber
        self.context = context
        super.init("", handler: handler, removeTail: false)
    }
    
    override var cuttail: Int? {
        return nil
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return MessageContactItem(item: self, phoneNumber: phoneNumber, interaction: interaction, presentation: presentation, context: context)
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



private final class MessageContactItem : AppMenuRowItem {

    let phoneNumber: String
    let context: AccountContext
    
    let disposable = MetaDisposable()
    
    enum State {
        case loading
        case loaded(EnginePeer?)
    }
    
    var state: State = .loading {
        didSet {
            self.item.redraw?()
        }
    }
    
    init(item: ContextMenuItem, phoneNumber: String, interaction: AppMenuBasicItem.Interaction, presentation: AppMenu.Presentation, context: AccountContext) {
        self.phoneNumber = phoneNumber
        self.context = context
        super.init(.zero, item: item, interaction: interaction, presentation: presentation)
        
        let signal = context.engine.peers.resolvePeerByPhone(phone: phoneNumber) |> deliverOnMainQueue
        
        disposable.set(signal.startStrict(next: { [weak self] peer in
            self?.state = .loaded(peer)
        }))
    }
    
    public override var height: CGFloat {
        return 28 + 13
    }
    
//    override var effectiveSize: NSSize {
//        var size = super.effectiveSize
//        if let _ = reaction {
//            size.width += 16 + 2 + self.innerInset
//        }
//        if let s = PremiumStatusControl.controlSize(peer, false) {
//            size.width += s.width + 2
//        }
//        return size
//    }
    
    override func viewClass() -> AnyClass {
        return MessageContactItemVIew.self
    }

}

private final class MessageContactItemVIew: AppMenuRowView {
    
    final class UserContainer : View {
        private let nameView = TextView()
        private let showProfileView = TextView()
        private let avatar = AvatarControl(font: .avatar(12))
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(nameView)
            addSubview(showProfileView)
            addSubview(avatar)
            avatar.setFrameSize(NSMakeSize(30, 30))
        }
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(peer: EnginePeer, context: AccountContext, presentation: AppMenu.Presentation) {
            let nameLayout = TextViewLayout(.initialize(string: peer._asPeer().displayTitle, color: presentation.textColor, font: .medium(.text)))
            let showProfileLayout = TextViewLayout(.initialize(string: "Show Profile", color: presentation.disabledTextColor, font: .normal(.text)))
            
            nameLayout.measure(width: frame.width - avatar.frame.width - 10)
            showProfileLayout.measure(width: frame.width - avatar.frame.width - 10)
            
            self.nameView.update(nameLayout)
            self.showProfileView.update(showProfileLayout)
            
            self.avatar.setPeer(account: context.account, peer: peer._asPeer())
        }
        
        override func layout() {
            super.layout()
            
            avatar.centerY(x: 0)
            nameView.setFrameOrigin(NSMakePoint(avatar.frame.maxX + 10, 4))
            showProfileView.setFrameOrigin(NSMakePoint(nameView.frame.minX, frame.height - showProfileView.frame.height - 4))
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var container: UserContainer?
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? MessageContactItem else {
            return
        }
       
    }
}
