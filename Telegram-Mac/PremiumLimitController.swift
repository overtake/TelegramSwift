//
//  PremiumLimitController.swift
//  Telegram
//
//  Created by Mike Renoir on 05.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import AppKit


extension PremiumLimitController.LimitType {
    var icon: CGImage {
        switch self {
        case .pin:
            return NSImage(named: "Icon_Premium_Limit_Pin")!.precomposed(NSColor(hexString: "#FFFFFF"))
        }
    }
    var acceptText: String {
        switch self {
        case .pin:
            return strings().premiumLimitIncrease
        }
    }
    var titleText: String {
        switch self {
        case .pin:
            return strings().premiumLimitReached
        }
    }
    func descText(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .pin:
            return strings().premiumLimitPinInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        }
    }
    
    func defaultLimit(_ limits: PremiumLimitConfig) -> Int32 {
        switch self {
        case .pin:
            return limits.dialog_pinned_limit_default
        }
    }
    func premiumLimit(_ limits: PremiumLimitConfig) -> Int32 {
        switch self {
        case .pin:
            return limits.dialog_pinned_limit_premium
        }
    }
}



private final class PremiumLimitView: View {
    
    private final class GradientView : View {
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.layer = CAGradientLayer()
            
            gradient.colors = [NSColor(hexString: "#F17B2F"), NSColor(hexString: "#C94787"), NSColor(hexString: "#9650E8"), NSColor(hexString: "#407AF0")].reversed().compactMap { $0?.cgColor }
            gradient.startPoint = CGPoint(x: 0, y: 1)
            gradient.endPoint = CGPoint(x: 1, y: 1)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        var gradient: CAGradientLayer {
            return self.layer! as! CAGradientLayer
        }
    }
    
    private class TypeView : View {
        private let gradient: GradientView = GradientView(frame: .zero)
        private let textView = TextView()
        private let imageView = ImageView()
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
            container.addSubview(textView)
            container.addSubview(imageView)
            addSubview(container)
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            gradient.frame = bounds
            
            container.center()
            imageView.centerY(x: 0)
            textView.centerY(x: imageView.frame.maxX + 10)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(type: PremiumLimitController.LimitType, context: AccountContext) -> NSSize {
            let layout = TextViewLayout(.initialize(string: "\(type.defaultLimit(context.premiumLimits))", color: NSColor.white, font: .avatar(20)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            imageView.image = type.icon
            imageView.sizeToFit()
            
            container.setFrameSize(NSMakeSize(layout.layoutSize.width + 10 + imageView.frame.width, max(layout.layoutSize.height, imageView.frame.height)))
            
            needsLayout = true
            
            return NSMakeSize(container.frame.width + 40, 40)
        }

    }
    
    private final class AcceptView : Control {
        private let gradient: GradientView = GradientView(frame: .zero)
        private let textView = TextView()
        private let imageView = ImageView()
        private let container = View()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(gradient)
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
            
            container.center()
            textView.centerY(x: 0)
            imageView.centerY(x: textView.frame.maxX + 10)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(type: PremiumLimitController.LimitType) -> NSSize {
            let layout = TextViewLayout(.initialize(string: type.acceptText, color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            imageView.image = NSImage(named: "Icon_Premium_Limit_2x")?.precomposed(.white)
            imageView.sizeToFit()
            
            container.setFrameSize(NSMakeSize(layout.layoutSize.width + 10 + imageView.frame.width, max(layout.layoutSize.height, imageView.frame.height)))
            
            needsLayout = true
            
            return NSMakeSize(container.frame.width + 80, 40)
        }
    }
    
    private let dismiss = ImageButton()
    private let accept = AcceptView(frame: .zero)
    private let title = TextView()
    private let desc = TextView()
    private let top = TypeView(frame: .zero)
    
    var close:(()->Void)? = nil
    var premium:(()->Void)? = nil

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(dismiss)
        addSubview(top)
        addSubview(desc)
        addSubview(title)
        addSubview(accept)
        
        dismiss.set(handler: { [weak self] _ in
            self?.close?()
        }, for: .Click)
        
        accept.set(handler: { [weak self] _ in
            self?.premium?()
        }, for: .Click)
        
        dismiss.scaleOnClick = true
        dismiss.autohighlight = false
        
        
        title.userInteractionEnabled = false
        title.isSelectable = false
        
        desc.userInteractionEnabled = false
        desc.isSelectable = false
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        
        dismiss.set(image: theme.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        backgroundColor = theme.colors.background
        
        accept.setFrameSize(NSMakeSize(100, 40))
        accept.layer?.cornerRadius = 10
    }
    
    func update(with type: PremiumLimitController.LimitType, context: AccountContext, animated: Bool) {
        var size = accept.update(type: type)
        accept.setFrameSize(size)
        
        size = top.update(type: type, context: context)
        top.setFrameSize(size)
        
        let title = TextViewLayout.init(.initialize(string: type.titleText, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1, truncationType: .middle)
        title.measure(width: frame.width - 40)
        
        let desc = TextViewLayout.init(.initialize(string: type.descText(context.premiumLimits), color: theme.colors.grayText, font: .normal(.text)), alignment: .center)
        desc.measure(width: frame.width - 40)
        
        self.title.update(title)
        self.desc.update(desc)

        top.layer?.cornerRadius = size.height / 2
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        dismiss.setFrameOrigin(NSMakePoint(10, 10))
        accept.centerX(y: frame.height - 30 - accept.frame.height)
        top.centerX(y: 80)
        title.centerX(y: top.frame.maxY + 20)
        desc.centerX(y: title.frame.maxY + 10)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PremiumLimitController : ModalViewController {
    
    enum LimitType {
        case pin
    }
    
    private let context: AccountContext
    private let type: LimitType
    init(context: AccountContext, type: LimitType) {
        self.context = context
        self.type = type
        super.init(frame: NSMakeRect(0, 0, 350, 350))
        bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.genericView.update(with: self.type, context: context, animated: false)
        
        self.genericView.close = { [weak self] in
            self?.close()
        }
        self.genericView.premium = { [weak self] in
            self?.close()
        }
        
        readyOnce()
    }
    
    override func viewClass() -> AnyClass {
        return PremiumLimitView.self
    }
    
    private var genericView: PremiumLimitView {
        return self.view as! PremiumLimitView
    }
    
}
