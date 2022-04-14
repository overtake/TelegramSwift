//
//  AvatarConstructorController.swift
//  Telegram
//
//  Created by Mike Renoir on 13.04.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
 
private final class AvatarConstructorView : View {
    private let leftView: View = View()
    private let rightView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(leftView)
        addSubview(rightView)
        leftView.backgroundColor = .random
        rightView.backgroundColor = .random
    }
    
    override func layout() {
        super.layout()
        leftView.frame = NSMakeRect(0, 0, 180, frame.height)
        rightView.frame = NSMakeRect(0, 0, frame.width - leftView.frame.width, frame.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class AvatarConstructorController : ModalViewController {
    enum Target {
        case avatar
        case peer(PeerId)
    }
    private let context: AccountContext
    private let target: Target
    init(_ context: AccountContext, target: Target) {
        self.context = context
        self.target = target
        super.init(frame: NSMakeRect(0, 0, 350, 450))
        bar = .init(height: 0)
    }
    
    override func measure(size: NSSize) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: effectiveSize(contentSize), animated: false)
        }
    }
    
    func effectiveSize(_ size: NSSize) -> NSSize {
        let updated = size - NSMakeSize(50, 20)
        
        return NSMakeSize(min(updated.width, 600), min(updated.height, 500))
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: effectiveSize(contentSize), animated: animated)
        }
    }
    
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return AvatarConstructorView.self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        readyOnce()
    }
}
