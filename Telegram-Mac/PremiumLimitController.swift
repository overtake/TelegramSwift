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
        case .pinInArchive:
            return NSImage(named: "Icon_Premium_Limit_Pin")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .chatInFolders:
            return NSImage(named: "Icon_Premium_Limit_Chats")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .channels:
            return NSImage(named: "Icon_Premium_Limit_Chats")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .pinInFolders:
            return NSImage(named: "Icon_Premium_Limit_Pin")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .faveStickers:
            return NSImage(named: "Icon_Premium_Limit_Pin")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .folders:
            return NSImage(named: "Icon_Premium_Limit_Folders")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .publicLink:
            return NSImage(named: "Icon_Premium_Limit_Link")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .savedGifs:
            return NSImage(named: "Icon_Premium_Limit_Pin")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .uploadFile:
            return NSImage(named: "Icon_Premium_Limit_Pin")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .caption:
            return NSImage(named: "Icon_Premium_Limit_Pin")!.precomposed(NSColor(hexString: "#FFFFFF"))
        }
    }
    var acceptText: String {
        switch self {
        default:
            return strings().premiumLimitIncrease
        }
    }
    var titleText: String {
        switch self {
        default:
            return strings().premiumLimitReached
        }
    }
    func descText(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .pin:
            return strings().premiumLimitPinInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        case .pinInArchive:
            return strings().premiumLimitPinInArchiveInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        case .savedGifs:
            return strings().premiumLimitSavedGifsInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        case .publicLink:
            return strings().premiumLimitPublicLinkInfo("\(premiumLimit(limits))")
        case .folders:
            return strings().premiumLimitFoldersInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        case .faveStickers:
            return strings().premiumLimitFaveStickersInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        case .chatInFolders:
            return strings().premiumLimitChatInFoldersInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        case .pinInFolders:
            return strings().premiumLimitPinInFoldersInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        case .channels:
            return strings().premiumLimitChannelsInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        case .uploadFile:
            return strings().premiumLimitFileSizeInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        case .caption:
            return strings().premiumLimitCaptionInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
        }
    }
    
    func defaultLimit(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .pin:
            return "\(limits.dialog_pinned_limit_default)"
        case .pinInArchive:
            return "\(limits.dialogs_folder_pinned_limit_default)"
        case .savedGifs:
            return "\(limits.saved_gifs_limit_default)"
        case .publicLink:
            return "\(limits.channels_public_limit_default)"
        case .folders:
            return "\(limits.dialog_filters_limit_default)"
        case .faveStickers:
            return "\(limits.stickers_faved_limit_default)"
        case .chatInFolders:
            return "\(limits.dialog_filters_chats_limit_default)"
        case .pinInFolders:
            return "\(limits.dialog_filters_pinned_limit_default)"
        case .channels:
            return "\(limits.channels_limit_default)"
        case .caption:
            return "\(limits.caption_length_limit_default)"
        case .uploadFile:
            return "\(String.prettySized(with: limits.upload_max_fileparts_default))"
        }
    }
    func premiumLimit(_ limits: PremiumLimitConfig) -> String {
        switch self {
        case .pin:
            return "\(limits.dialog_pinned_limit_premium)"
        case .pinInArchive:
            return "\(limits.dialogs_folder_pinned_limit_premium)"
        case .savedGifs:
            return "\(limits.saved_gifs_limit_premium)"
        case .publicLink:
            return "\(limits.channels_public_limit_premium)"
        case .folders:
            return "\(limits.dialog_filters_limit_premium)"
        case .faveStickers:
            return "\(limits.stickers_faved_limit_premium)"
        case .chatInFolders:
            return "\(limits.dialog_filters_chats_limit_premium)"
        case .pinInFolders:
            return "\(limits.dialog_filters_pinned_limit_premium)"
        case .channels:
            return "\(limits.channels_limit_premium)"
        case .caption:
            return "\(limits.caption_length_limit_premium)"
        case .uploadFile:
            return "\(String.prettySized(with: limits.upload_max_fileparts_premium))"
        }
    }
}

final class PremiumGradientView : View {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer = CAGradientLayer()
        
        gradient.colors = [NSColor(hexString: "#6B93FF"), NSColor(hexString: "#976FFF"), NSColor(hexString: "#E46ACE")].compactMap { $0?.cgColor }
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


final class PremiumLimitView: View {
    
    private class LineView: View {
        
        private let normalText = TextView()
        private let premiumText = TextView()
        private let premiumCount = TextView()

        private let normalBackground = View()
        private let premiumBackground = PremiumGradientView(frame: .zero)
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(normalBackground)
            addSubview(premiumBackground)
            addSubview(normalText)
            addSubview(premiumText)
            addSubview(premiumCount)

            normalText.userInteractionEnabled = false
            premiumText.userInteractionEnabled = false
            premiumCount.userInteractionEnabled = false
            
            normalText.isSelectable = false
            premiumText.isSelectable = false
            premiumCount.isSelectable = false
        }
        
        func update(_ limitType: PremiumLimitController.LimitType, context: AccountContext) {
            let normalLayout = TextViewLayout(.initialize(string: strings().premiumLimitFree, color: theme.colors.text, font: .medium(13)))
            normalLayout.measure(width: .greatestFiniteMagnitude)
            
            normalText.update(normalLayout)
            
            let premiumCountLayout = TextViewLayout(.initialize(string: limitType.premiumLimit(context.premiumLimits), color: .white, font: .medium(13)))
            premiumCountLayout.measure(width: .greatestFiniteMagnitude)

            premiumCount.update(premiumCountLayout)
            
            let premiumLayout = TextViewLayout(.initialize(string: strings().premiumLimitPremium, color: .white, font: .medium(13)))
            premiumLayout.measure(width: .greatestFiniteMagnitude)

            premiumText.update(premiumLayout)

            
            normalBackground.backgroundColor = theme.colors.grayForeground
        }
        
        override func layout() {
            super.layout()
            let width = frame.width / 2 - 4

            
            normalText.centerY(x: 10)
            premiumText.centerY(x: width + 4 + 10)
            premiumCount.centerY(x: frame.width - 10 - premiumCount.frame.width)
            
            
            normalBackground.frame = NSMakeRect(0, 0, width, frame.height)
            premiumBackground.frame = NSMakeRect(width + 4, 0, width + 4, frame.height)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    
    private class TypeView : View {
        
        
        private let gradient: PremiumGradientView = PremiumGradientView(frame: .zero)
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
        private let gradient: PremiumGradientView = PremiumGradientView(frame: .zero)
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
            
            return NSMakeSize(container.frame.width + 100, 40)
        }
    }
    private let header = View()
    private let dismiss = ImageButton()
    private let accept = AcceptView(frame: .zero)
    private let title = TextView()
    private let desc = TextView()
    private let top = TypeView(frame: .zero)
    private let lineView = LineView(frame: .zero)
    var close:(()->Void)? = nil
    var premium:(()->Void)? = nil

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(header)
        header.addSubview(dismiss)
        addSubview(top)
        addSubview(lineView)
        addSubview(desc)
        header.addSubview(title)
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
    }
    
    @discardableResult func update(with type: PremiumLimitController.LimitType, context: AccountContext, animated: Bool, hasDismiss: Bool = true) -> NSSize {
        var size = accept.update(type: type)
        accept.setFrameSize(size)
        
        dismiss.isHidden = !hasDismiss
        
        size = top.update(type: type, context: context)
        top.setFrameSize(size)
        
        
        lineView.update(type, context: context)
        lineView.setFrameSize(NSMakeSize(frame.width - 40, 30))
        lineView.layer?.cornerRadius = lineView.frame.height / 2
        
        let title = TextViewLayout.init(.initialize(string: type.titleText, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1, truncationType: .middle)
        title.measure(width: frame.width - 40)
        
        let attr = NSMutableAttributedString()
        attr.append(.initialize(string: type.descText(context.premiumLimits), color: theme.colors.text, font: .normal(.text)))
        attr.detectBoldColorInString(with: .medium(.text))
        let desc = TextViewLayout.init(attr, alignment: .center)
        desc.measure(width: frame.width - 40)
        
        self.title.update(title)
        self.desc.update(desc)

        top.layer?.cornerRadius = size.height / 2
        accept.layer?.cornerRadius = accept.frame.height / 2

        return NSMakeSize(frame.width, accept.frame.height + 30 + self.desc.frame.height + 20 + self.title.frame.height + 10 + top.frame.height + lineView.frame.height + 20 + 20 + 30)
        
    }
    
    override func layout() {
        super.layout()
        header.frame = NSMakeRect(0, 0, frame.width, 50)
        dismiss.centerY(x: 10)
        title.center()
        accept.centerX(y: frame.height - 30 - accept.frame.height)
        desc.centerX(y: accept.frame.minY - desc.frame.height - 20)
        lineView.centerX(y: desc.frame.minY - lineView.frame.height - 20)
        top.centerX(y: lineView.frame.minY - top.frame.height - 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PremiumLimitController : ModalViewController {
    
    enum LimitType {
        case pin
        case pinInArchive
        case savedGifs
        case folders
        case chatInFolders
        case pinInFolders
        case faveStickers
        case publicLink
        case channels
        case uploadFile
        case caption
    }
    
    private let context: AccountContext
    private let type: LimitType
    init(context: AccountContext, type: LimitType) {
        self.context = context
        self.type = type
        super.init(frame: NSMakeRect(0, 0, 350, 300))
        bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let size = self.genericView.update(with: self.type, context: context, animated: false)
        
        
        self.modal?.resize(with:size, animated: false)

        
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


func showPremiumLimit(context: AccountContext, type: PremiumLimitController.LimitType) {
    showModal(with: PremiumLimitController(context: context, type: type), for: context.window)
}
