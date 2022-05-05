//
//  StickerPremiumHolderView.swift
//  Telegram
//
//  Created by Mike Renoir on 03.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit


final class StickerPremiumHolderView: NSVisualEffectView {
    private let dismiss:ImageButton = ImageButton()
    private let containerView = View()
    private let stickerEffectView = LottiePlayerView()
    private let stickerView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 140, 140))
    var close:(()->Void)?
    
    private let dataDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    private let textView = TextView()
    
    private let unlock = TitleButton()
        
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(stickerView)
        containerView.addSubview(stickerEffectView)
        addSubview(dismiss)
        addSubview(textView)
        addSubview(unlock)
        wantsLayer = true
        self.state = .active
        self.blendingMode = .withinWindow
        self.material = theme.colors.isDark ? .dark : .light
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        dismiss.scaleOnClick = true
        
        dismiss.set(image: theme.icons.stickerPackClose, for: .Normal)
        _ = dismiss.sizeToFit()
        
        dismiss.set(handler: { [weak self] _ in
            self?.close?()
        }, for: .Click)
        
        let layout = TextViewLayout(.initialize(string: strings().stickersPreviewPremium, color: theme.colors.grayText, font: .normal(.text)), alignment: .center)
        layout.measure(width: frame.width - 40)
        textView.update(layout)
        
        
        unlock.disableActions()
        unlock.setFrameSize(190, 30)
        
        unlock.set(color: theme.colors.underSelectedColor, for: .Normal)
        unlock.set(font: .medium(.title), for: .Normal)
        unlock.set(background: theme.colors.accent, for: .Normal)
        unlock.set(background: theme.colors.accent, for: .Hover)
        unlock.set(background: theme.colors.accent, for: .Highlight)
        unlock.set(text: strings().stickersPremiumUnlock, for: .Normal)
        unlock.scaleOnClick = true
        unlock.autohighlight = false
        unlock.set(image: theme.icons.premium_account_active, for: .Normal)
        unlock.sizeToFit(NSMakeSize(20, 0), NSMakeSize(0, 30), thatFit: true)
        unlock.layer?.cornerRadius = 15
        

    }
    
    deinit {
        dataDisposable.dispose()
        fetchDisposable.dispose()
    }
    
    func set(file: TelegramMediaFile, context: AccountContext) -> Void {
        
        
        var size = NSMakeSize(min(200, frame.width / 2.2), min(200, frame.width / 2.2))
        if let dimensions = file.dimensions?.size {
            size = dimensions.aspectFitted(size)
        }
        stickerView.setFrameSize(size)
        stickerView.update(with: file, size: size, context: context, table: nil, animated: false)
        
        if let effect = file.premiumEffect {
            var animationSize = NSMakeSize(stickerView.frame.width * 2, stickerView.frame.height * 2)
            animationSize = effect.dimensions.size.aspectFitted(animationSize)
            
            stickerEffectView.setFrameSize(animationSize)
            
            let signal: Signal<LottieAnimation?, NoError> = context.account.postbox.mediaBox.resourceData(effect.resource) |> filter { $0.complete } |> take(1) |> map { data in
                if data.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    return LottieAnimation(compressed: data, key: .init(key: .bundle("_premium_\(file.fileId)"), size: animationSize, backingScale: Int(System.backingScale)), cachePurpose: .temporaryLZ4(.effect), playPolicy: .loop)
                } else {
                    return nil
                }
            } |> deliverOnMainQueue
            
            dataDisposable.set(signal.start(next: { [weak self] animation in
                self?.stickerEffectView.set(animation)
            }))
            if let sticker = file.stickerReference {
                fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .stickerPackThumbnail(stickerPack: sticker, resource: effect.resource)).start())
            }
        }
        
               
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        dismiss.setFrameOrigin(NSMakePoint(12, 10))
        containerView.frame = stickerEffectView.frame.size.bounds
        containerView.centerX(y: 0)
        stickerEffectView.center()
        stickerView.centerY(x: containerView.bounds.width - stickerView.frame.width - 20)
        unlock.centerX(y: frame.height - unlock.frame.height - 20)
        textView.centerX(y: unlock.frame.minY - textView.frame.height - 10)
    }
}
