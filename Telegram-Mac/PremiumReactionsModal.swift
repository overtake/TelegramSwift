//
//  PremiumReactionsModalView.swift
//  Telegram
//
//  Created by Mike Renoir on 03.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit

private final class PremiumReactionsView : View {
    private let dismiss:ImageButton = ImageButton()
    private let containerView = View()
    var close:(()->Void)?
    
    private let dataDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    private let textView = TextView()
    
    private let unlock = TitleButton()
    
    private var carousel: ReactionCarouselView?
        
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        addSubview(dismiss)
        addSubview(textView)
        addSubview(unlock)
        wantsLayer = true
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        dismiss.scaleOnClick = true
        
        dismiss.set(image: theme.icons.stickerPackClose, for: .Normal)
        _ = dismiss.sizeToFit()
        
        dismiss.set(handler: { [weak self] _ in
            self?.close?()
        }, for: .Click)
        
        let layout = TextViewLayout(.initialize(string: strings().reactionsPreviewPremium, color: theme.colors.grayText, font: .normal(.text)), alignment: .center)
        layout.measure(width: frame.width - 40)
        textView.update(layout)
        
        
        unlock.disableActions()
        unlock.setFrameSize(190, 30)
        
        unlock.set(color: theme.colors.underSelectedColor, for: .Normal)
        unlock.set(font: .medium(.title), for: .Normal)
        unlock.set(background: theme.colors.accent, for: .Normal)
        unlock.set(background: theme.colors.accent, for: .Hover)
        unlock.set(background: theme.colors.accent, for: .Highlight)
        unlock.set(text: strings().reactionsPreviewUnlock, for: .Normal)
        
        unlock.set(image: theme.icons.premium_account_active, for: .Normal)
        
        unlock.scaleOnClick = true
        unlock.autohighlight = false
        unlock.sizeToFit(NSMakeSize(20, 0), NSMakeSize(0, 30), thatFit: true)
        unlock.layer?.cornerRadius = 15
    }
    
    deinit {
        dataDisposable.dispose()
        fetchDisposable.dispose()
    }
    
    func set(context: AccountContext) -> Void {
        if carousel == nil {
            carousel = ReactionCarouselView(context: context, reactions: context.reactions.available?.reactions ?? [])
            containerView.addSubview(carousel!)
        }
        needsLayout = true
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        containerView.frame = NSMakeRect(0, 0, frame.width, 340)
        carousel?.frame = containerView.bounds
        dismiss.setFrameOrigin(NSMakePoint(12, 10))
        containerView.centerX(y: 0)
        unlock.centerX(y: frame.height - unlock.frame.height - 20)
        textView.centerX(y: unlock.frame.minY - textView.frame.height - 10)
    }

}

final class PremiumReactionsModal : ModalViewController {
    private let context: AccountContext
    init(context: AccountContext) {
        self.context = context
        super.init(frame: NSMakeRect(0, 0, 350, 400))
        self.bar = .init(height: 0)
    }
    
    fileprivate var genericView:PremiumReactionsView {
        return view as! PremiumReactionsView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.set(context: context)
        readyOnce()
    }
    
    override func viewClass() -> AnyClass {
        return PremiumReactionsView.self
    }
}
