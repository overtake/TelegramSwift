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
import TelegramMedia

final class StickerPremiumHolderView: NSVisualEffectView {
    private let dismiss:ImageButton = ImageButton()
    private let containerView = View()
    private let stickerEffectView = LottiePlayerView()
    private let stickerView = LottiePlayerView()
    var close:(()->Void)?
    
    private let dataDisposable = MetaDisposable()
    private let dataEffectDisposable = MetaDisposable()
    private let fetchEffectDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()

    private let textView = TextView()
    
    private let unlock = AcceptView(frame: .zero)
    
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
            let layout = TextViewLayout(.initialize(string: strings().stickersPremiumUnlock, color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            let lottie = LocalAnimatedSticker.premium_unlock
            
            if let data = lottie.data {
                let colors:[LottieColor] = [.init(keyPath: "", color: NSColor(0xffffff))]
                imageView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("bundle_\(lottie.rawValue)"), size: NSMakeSize(24, 24), colors: colors), cachePurpose: .temporaryLZ4(.thumb), playPolicy: .loop, maximumFps: 60, colors: colors, runOnQueue: .mainQueue()))
            }
            container.setFrameSize(NSMakeSize(layout.layoutSize.width + 10 + imageView.frame.width, max(layout.layoutSize.height, imageView.frame.height)))
            
            let size = NSMakeSize(container.frame.width + 40, 40)
            
            shimmer.updateAbsoluteRect(size.bounds, within: size)
            shimmer.update(backgroundColor: .clear, foregroundColor: .clear, shimmeringColor: NSColor.white.withAlphaComponent(0.3), shapes: [.roundedRect(rect: size.bounds, cornerRadius: size.height / 2)], horizontal: true, size: size)


            needsLayout = true
            
            return size
        }
    }

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
        
        let size = unlock.update()
        unlock.setFrameSize(size)
        unlock.layer?.cornerRadius = size.height / 2
    }
    
    deinit {
        dataDisposable.dispose()
        fetchDisposable.dispose()
        fetchEffectDisposable.dispose()
        dataEffectDisposable.dispose()
    }
    
    func set(file: TelegramMediaFile, context: AccountContext, callback:@escaping()->Void) -> Void {
        
        
        var size = NSMakeSize(min(200, frame.width / 2.2), min(200, frame.width / 2.2))
        if let dimensions = file.dimensions?.size {
            size = dimensions.aspectFitted(size)
        }
        stickerView.setFrameSize(size)
        
        let parameters = ChatAnimatedStickerMediaLayoutParameters(playPolicy: nil, media: file)
        parameters.mirror = true
        
        let signal: Signal<LottieAnimation?, NoError> = context.account.postbox.mediaBox.resourceData(file.resource) |> filter { $0.complete } |> take(1) |> map { data in
            if data.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                return LottieAnimation(compressed: data, key: .init(key: .bundle("_sticker_premium_\(file.fileId)"), size: size, backingScale: Int(System.backingScale), mirror: true), cachePurpose: .temporaryLZ4(.effect), playPolicy: .loop)
            } else {
                return nil
            }
        } |> deliverOnMainQueue
        
        dataDisposable.set(signal.start(next: { [weak self] animation in
            self?.stickerView.set(animation)
        }))
        if let sticker = file.stickerReference {
            fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .stickerPackThumbnail(stickerPack: sticker, resource: file.resource)).start())
        }
        
        if let effect = file.premiumEffect {
            var animationSize = NSMakeSize(stickerView.frame.width * 1.5, stickerView.frame.height * 1.5)
            animationSize = effect.dimensions.size.aspectFitted(animationSize)
            
            stickerEffectView.setFrameSize(animationSize)
            
            let signal: Signal<LottieAnimation?, NoError> = context.account.postbox.mediaBox.resourceData(effect.resource) |> filter { $0.complete } |> take(1) |> map { data in
                if data.complete, let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    return LottieAnimation(compressed: data, key: .init(key: .bundle("_premium_\(file.fileId)"), size: animationSize, backingScale: Int(System.backingScale), mirror: true), cachePurpose: .temporaryLZ4(.effect), playPolicy: .loop)
                } else {
                    return nil
                }
            } |> deliverOnMainQueue
            
            dataEffectDisposable.set(signal.start(next: { [weak self] animation in
                self?.stickerEffectView.set(animation)
            }))
            if let sticker = file.stickerReference {
                fetchEffectDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .stickerPackThumbnail(stickerPack: sticker, resource: effect.resource)).start())
            }
        }
        
        unlock.removeAllHandlers()
        unlock.set(handler: { _ in
            callback()
        }, for: .Click)
               
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
        containerView.frame = NSMakeRect(0, 0, frame.width, stickerEffectView.frame.height)
        containerView.centerX(y: 50)
        stickerView.center()
        stickerEffectView.centerY(x: stickerView.frame.minX - 15, addition: -1)
        unlock.centerX(y: frame.height - unlock.frame.height - 20)
        textView.centerX(y: unlock.frame.minY - textView.frame.height - 10)
    }
}
