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
import TelegramMedia

private final class PremiumReactionsView : View {
    private let dismiss:ImageButton = ImageButton()
    private let containerView = View()
    var close:(()->Void)?
    
    private let dataDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    private let textView = TextView()
    
    fileprivate let unlock = AcceptView(frame: .zero)
    
    fileprivate final class AcceptView : Control {
        private let gradient: PremiumGradientView = PremiumGradientView(frame: .zero)
        private let shimmer = ShimmerEffectView()
        private let textView = TextView()
        private let imageView = LottiePlayerView(frame: NSMakeRect(0, 0, 24, 24))
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
            addSubview(shimmer)
            shimmer.isStatic = true
            container.addSubview(textView)
            container.addSubview(imageView)
            addSubview(container)
            scaleOnClick = true
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            gradient.frame = bounds
            shimmer.frame = bounds
            container.center()
            textView.centerY(x: 0)
            imageView.centerY(x: textView.frame.maxX + 10)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update() -> NSSize {
            let layout = TextViewLayout(.initialize(string: strings().reactionsPreviewUnlock, color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            let lottie = LocalAnimatedSticker.premium_unlock
            
            if let data = lottie.data {
                let colors:[LottieColor] = [.init(keyPath: "", color: NSColor(0xffffff))]
                imageView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("bundle_\(lottie.rawValue)"), size: NSMakeSize(24, 24), colors: colors), cachePurpose: .temporaryLZ4(.thumb), playPolicy: .loop, maximumFps: 60, colors: colors, runOnQueue: .mainQueue()))
            }
            container.setFrameSize(NSMakeSize(layout.layoutSize.width + 10 + imageView.frame.width, max(layout.layoutSize.height, imageView.frame.height)))
            
            let size = NSMakeSize(container.frame.width + 100, 40)
            
            shimmer.updateAbsoluteRect(size.bounds, within: size)
            shimmer.update(backgroundColor: .clear, foregroundColor: .clear, shimmeringColor: NSColor.white.withAlphaComponent(0.3), shapes: [.roundedRect(rect: size.bounds, cornerRadius: size.height / 2)], horizontal: true, size: size)


            needsLayout = true
            
            return size
        }
    }
    

    
    
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
        
        let size = unlock.update()
        unlock.setFrameSize(size)
        unlock.layer?.cornerRadius = 10
    }
    
    deinit {
        dataDisposable.dispose()
        fetchDisposable.dispose()
    }
    
    func set(context: AccountContext) -> Void {
        if carousel == nil {
            carousel = ReactionCarouselView(context: context, reactions: context.reactions.available?.reactions ?? [])
            containerView.addSubview(carousel!)
            
            carousel?.playReaction()
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
        
        let context = self.context
        
        genericView.set(context: context)
        
        genericView.unlock.set(handler: { _ in
            showModal(with: PremiumBoardingController(context: context, source: .infinite_reactions), for: context.window)
        }, for: .Click)
        
        readyOnce()
    }
    
    override func viewClass() -> AnyClass {
        return PremiumReactionsView.self
    }
}
