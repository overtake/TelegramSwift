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
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramMedia


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
            return NSImage(named: "Icon_Premium_Limit_Stickers")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .folders:
            return NSImage(named: "Icon_Premium_Limit_Folders")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .publicLink:
            return NSImage(named: "Icon_Premium_Limit_Link")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .savedGifs:
            return NSImage(named: "Icon_Premium_Limit_GIF")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .uploadFile:
            return NSImage(named: "Icon_Premium_Limit_File")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .caption:
            return NSImage(named: "Icon_Premium_Limit_Chats")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .about:
            return NSImage(named: "Icon_Premium_Limit_Chats")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .accounts:
            return NSImage(named: "Icon_Premium_Limit_Accounts")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .sharedInvites:
            return NSImage(named: "Icon_Premium_Limit_Link")!.precomposed(NSColor(hexString: "#FFFFFF"))
        case .sharedFolders:
            return NSImage(named: "Icon_Premium_Limit_Folders")!.precomposed(NSColor(hexString: "#FFFFFF"))
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
    func descText(_ limits: PremiumLimitConfig, alreadyPremiumLimit: Bool = false) -> String {
        if limits.premium_purchase_blocked || alreadyPremiumLimit {
            switch self {
            case .pin:
                return strings().premiumLimitLockedPinInfo(defaultLimit(limits))
            case .pinInArchive:
                return strings().premiumLimitLockedPinInArchiveInfo("\(defaultLimit(limits))")
            case .savedGifs:
                return strings().premiumLimitLockedSavedGifsInfo("\(defaultLimit(limits))")
            case .publicLink:
                return strings().premiumLimitLockedPublicLinkInfo
            case .folders:
                return strings().premiumLimitLockedFoldersInfo("\(defaultLimit(limits))")
            case .faveStickers:
                return strings().premiumLimitLockedFaveStickersInfo("\(defaultLimit(limits))")
            case .chatInFolders:
                return strings().premiumLimitLockedChatInFoldersInfo("\(defaultLimit(limits))")
            case .pinInFolders:
                return strings().premiumLimitLockedPinInFoldersInfo("\(defaultLimit(limits))")
            case .channels:
                return strings().premiumLimitLockedChannelsInfo("\(defaultLimit(limits))")
            case .uploadFile:
                return strings().premiumLimitLockedFileSizeInfo("\(defaultLimit(limits))")
            case .caption:
                return strings().premiumLimitLockedCaptionInfo("\(defaultLimit(limits))")
            case .about:
                return strings().premiumLimitLockedAboutInfo("\(defaultLimit(limits))")
            case .accounts:
                return strings().premiumLimitLockedAccountsInfo("\(defaultLimit(limits))")
            case .sharedFolders:
                return strings().premiumLimitLockedSharedFoldersInfo("\(defaultLimit(limits))")
            case .sharedInvites:
                return strings().premiumLimitLockedSharedFoldersInvitesInfo("\(defaultLimit(limits))")


            }
        } else {
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
            case .about:
                return strings().premiumLimitAboutInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
            case .accounts:
                return strings().premiumLimitAccountsInfo("\(defaultLimit(limits))")
            case .sharedFolders:
                return strings().premiumLimitSharedFoldersInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
            case .sharedInvites:
                return strings().premiumLimitSharedFoldersInvitesInfo("\(defaultLimit(limits))", "\(premiumLimit(limits))")
            }
        }
    }
    
    func percent(_ limits: PremiumLimitConfig, counts: PremiumLimitController.Counts? = nil) -> CGFloat {
        switch self {
        case .pin:
            return CGFloat(counts?.pinnedCount ?? limits.dialog_pinned_limit_default) / CGFloat(limits.dialog_pinned_limit_premium)
        case .pinInArchive:
            return CGFloat(counts?.pinnedCount ?? limits.dialogs_folder_pinned_limit_default) / CGFloat(limits.dialogs_folder_pinned_limit_premium)
        case .savedGifs:
            return CGFloat(counts?.savedGifsCount ?? limits.saved_gifs_limit_default) / CGFloat(limits.saved_gifs_limit_premium)
        case .publicLink:
            return CGFloat(counts?.publicLinksCount ?? limits.channels_public_limit_default) / CGFloat(limits.channels_public_limit_premium)
        case .folders:
            return CGFloat(counts?.foldersCount ?? limits.dialog_filters_limit_default) / CGFloat(limits.dialog_filters_limit_premium)
        case .faveStickers:
            return CGFloat(counts?.savedStickersCount ?? limits.stickers_faved_limit_default) / CGFloat(limits.stickers_faved_limit_premium)
        case .chatInFolders:
            return CGFloat(limits.dialog_filters_chats_limit_default) / CGFloat(limits.dialog_filters_chats_limit_premium)
        case .pinInFolders:
            return CGFloat(counts?.pinnedCount ?? limits.dialog_filters_pinned_limit_default) / CGFloat(limits.dialog_filters_pinned_limit_premium)
        case .channels:
            return CGFloat(limits.channels_limit_default) / CGFloat(limits.channels_limit_premium)
        case let .caption(count):
            return CGFloat(counts != nil ? count : limits.caption_length_limit_default) / CGFloat(limits.caption_length_limit_premium)
        case let .about(count):
            return CGFloat(counts != nil ? count : limits.about_length_limit_default) / CGFloat(limits.about_length_limit_premium)
        case let .accounts(count):
            if count == 3 {
                return 0.5
            } else if count == 2 {
                return 0.3
            } else if count == 1 {
                return 0
            } else {
                return 1
            }
        case let .uploadFile(count):
            if counts != nil, let count = count {
                return CGFloat(count) / CGFloat(limits.upload_max_fileparts_premium)
            } else {
                return CGFloat(limits.upload_max_fileparts_default) / CGFloat(limits.upload_max_fileparts_premium)
            }
        case .sharedFolders:
            return 0.5
        case .sharedInvites:
            return 0.5
        }
    }
    
    func defaultLimit(_ limits: PremiumLimitConfig, counts: PremiumLimitController.Counts? = nil) -> String {
        switch self {
        case .pin:
            return "\(counts?.pinnedCount ?? limits.dialog_pinned_limit_default)"
        case .pinInArchive:
            return "\(counts?.pinnedCount ?? limits.dialogs_folder_pinned_limit_default)"
        case .savedGifs:
            return "\(counts?.savedGifsCount ?? limits.saved_gifs_limit_default)"
        case .publicLink:
            return "\(counts?.publicLinksCount ?? limits.channels_public_limit_default)"
        case .folders:
            return "\(counts?.foldersCount ?? limits.dialog_filters_limit_default)"
        case .faveStickers:
            return "\(counts?.savedStickersCount ?? limits.stickers_faved_limit_default)"
        case .chatInFolders:
            return "\(counts?.pinnedCount ?? limits.dialog_filters_chats_limit_default)"
        case .pinInFolders:
            return "\(limits.dialog_filters_pinned_limit_default)"
        case .accounts:
            return "\(normalAccountsLimit)"
        case .channels:
            return "\(limits.channels_limit_default)"
        case let .caption(count):
            return "\(counts != nil ? count : limits.caption_length_limit_default)"
        case let .about(count):
            return "\(counts != nil ? count : limits.about_length_limit_default)"
        case .sharedFolders:
            return "\(limits.communities_joined_limit_default)"
        case .sharedInvites:
            return "\(limits.community_invites_limit_default)"
        case let .uploadFile(count):
            if counts != nil, let count = count {
                return String.prettySized(with: count, afterDot: 1)
            } else {
                return String.prettySized(with: limits.upload_max_fileparts_default, afterDot: 0, round: true)
            }
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
        case .accounts:
            return "\(normalAccountsLimit + 1)"
        case .sharedFolders:
            return "\(limits.communities_joined_limit_premium)"
        case .sharedInvites:
            return "\(limits.community_invites_limit_premium)"
        case .uploadFile:
            return "\(String.prettySized(with: limits.upload_max_fileparts_premium, afterDot: 0, round: true))"
        case .about:
            return "\(limits.about_length_limit_premium)"
        }
    }
}

final class PremiumGradientView : View {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer = CAGradientLayer()
        
        self.gradient.startPoint = CGPoint(x: 0, y: 1)
        self.gradient.endPoint = CGPoint(x: 1, y: 0)
        
        gradient.colors = premiumGradient.compactMap { $0.cgColor }
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
        private let normalCount = TextView()

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
            addSubview(normalCount)
            normalText.userInteractionEnabled = false
            premiumText.userInteractionEnabled = false
            premiumCount.userInteractionEnabled = false
            normalCount.userInteractionEnabled = false
            
            normalText.isSelectable = false
            premiumText.isSelectable = false
            premiumCount.isSelectable = false
            normalCount.isSelectable = false
        }
        
        func update(_ limitType: PremiumLimitController.LimitType, context: AccountContext) {
            let normalLayout = TextViewLayout(.initialize(string: strings().premiumLimitFree, color: theme.colors.text, font: .medium(13)))
            normalLayout.measure(width: .greatestFiniteMagnitude)
            
            normalText.update(normalLayout)
            
            
            let normalCountLayout = TextViewLayout(.initialize(string: limitType.defaultLimit(context.premiumLimits), color: theme.colors.text, font: .medium(13)))
            normalCountLayout.measure(width: .greatestFiniteMagnitude)

            normalCount.update(normalCountLayout)

            
            let premiumCountLayout = TextViewLayout(.initialize(string: limitType.premiumLimit(context.premiumLimits), color: .white, font: .medium(13)))
            premiumCountLayout.measure(width: .greatestFiniteMagnitude)

            premiumCount.update(premiumCountLayout)
            
            let premiumLayout = TextViewLayout(.initialize(string: strings().premiumLimitPremium, color: .white, font: .medium(13)))
            premiumLayout.measure(width: .greatestFiniteMagnitude)

            premiumText.update(premiumLayout)

            
            normalBackground.backgroundColor = theme.colors.grayForeground
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            let width = frame.width / 2

            
            normalText.centerY(x: 10)
            
            normalCount.centerY(x: bounds.midX - 2 - normalCount.frame.width - 10)
            
            premiumText.centerY(x: width + 10)
            premiumCount.centerY(x: bounds.width - 10 - premiumCount.frame.width)
            
            
            normalBackground.frame = NSMakeRect(0, 0, width, frame.height)
            premiumBackground.frame = NSMakeRect(width, 0, width, frame.height)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    
    private class TypeView : View {
        
                
        private let backgrounView = ImageView()
        
        private let textView = TextView()
        private let imageView = ImageView()
        private let container = View()
        
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(backgrounView)
            container.addSubview(textView)
            container.addSubview(imageView)
            addSubview(container)
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        override func layout() {
            super.layout()
            backgrounView.frame = bounds
            container.centerX()
            imageView.centerY(x: 0)
            textView.centerY(x: imageView.frame.maxX + 10)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        func update(type: PremiumLimitController.LimitType, counts: PremiumLimitController.Counts?, context: AccountContext) -> NSSize {
            let layout = TextViewLayout(.initialize(string: "\(type.defaultLimit(context.premiumLimits, counts: counts))", color: NSColor.white, font: .avatar(20)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            imageView.image = type.icon
            imageView.sizeToFit()
            

            container.setFrameSize(NSMakeSize(layout.layoutSize.width + 10 + imageView.frame.width, 40))
            
            let canPremium = !context.premiumIsBlocked
            
            let size = NSMakeSize(container.frame.width + 40, canPremium ? 50 : 40)
            
            let image = generateImage(NSMakeSize(size.width, canPremium ? size.height - 10 : size.height), contextGenerator: { size, ctx in
                ctx.clear(size.bounds)
               
                let path = CGMutablePath()
                path.addRoundedRect(in: NSMakeRect(0, 0, size.width, size.height), cornerWidth: size.height / 2, cornerHeight: size.height / 2)
                
                ctx.addPath(path)
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fillPath()
                
            })!
            
            let corner = generateImage(NSMakeSize(30, 10), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(NSColor.black.cgColor)
                context.scaleBy(x: 0.333, y: 0.333)
                let _ = try? drawSvgPath(context, path: "M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ")
                context.fillPath()
            })!

            let clipImage = generateImage(size, rotatedContext: { size, ctx in
                ctx.clear(size.bounds)
                ctx.draw(image, in: NSMakeRect(0, 0, image.backingSize.width, image.backingSize.height))
                
                ctx.draw(corner, in: NSMakeRect(size.bounds.focus(corner.backingSize).minX, image.backingSize.height, corner.backingSize.width, corner.backingSize.height))
            })!
            
            let fullImage = generateImage(size, contextGenerator: { size, ctx in
                ctx.clear(size.bounds)

                if !canPremium {
                    ctx.clip(to: size.bounds, mask: image)
                    ctx.setFillColor(theme.colors.accent.cgColor)
                    ctx.fill(size.bounds)
                } else {
                    ctx.clip(to: size.bounds, mask: clipImage)
                    
                    let colors = premiumGradient.compactMap { $0.cgColor } as NSArray
                    
                    let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                    
                    var locations: [CGFloat] = []
                    for i in 0 ..< colors.count {
                        locations.append(delta * CGFloat(i))
                    }
                    let colorSpace = deviceColorSpace
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
                    
                    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
                }
            })!
            
            self.backgrounView.image = fullImage
            
            
            needsLayout = true
            
            return size
        }

    }
    
    private final class AcceptView : Control {
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
        
        func update(type: PremiumLimitController.LimitType, lottie: LocalAnimatedSticker) -> NSSize {
            let layout = TextViewLayout(.initialize(string: type.acceptText, color: NSColor.white, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
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
    private let header = View()
    private let dismiss = ImageButton()
    private let accept = AcceptView(frame: .zero)
    private let acceptOK = TextButton(frame: .zero)
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
        addSubview(acceptOK)
        dismiss.set(handler: { [weak self] _ in
            self?.close?()
        }, for: .Click)
        
        accept.set(handler: { [weak self] _ in
            self?.premium?()
        }, for: .Click)
        
        acceptOK.set(handler: { [weak self] _ in
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
        
    }
    
    func playAppearanceAnimation() {
        
        if lineView.isHidden {
            return
        }
        
        self.top.layer!.animateScaleSpring(from: 0.1, to: 1.0, duration: 1.0)
        
        let now = self.top.layer!.convertTime(CACurrentMediaTime(), from: nil)
        
        
        
        
        let positionAnimation = CABasicAnimation(keyPath: "position.x")
        positionAnimation.timingFunction = .init(name: .easeInEaseOut)
        positionAnimation.fromValue = NSValue(point: CGPoint(x: -frame.width / 2.0, y: 0.0))
        positionAnimation.toValue = NSValue(point: CGPoint())
        positionAnimation.isAdditive = true
        positionAnimation.duration = 0.2
        positionAnimation.fillMode = .forwards
        positionAnimation.beginTime = now
        
        
        self.top.layer?.add(positionAnimation, forKey: "appearance1")
//        self.top.layer?.add(rotateAnimation, forKey: "appearance2")
//        self.top.layer?.add(returnAnimation, forKey: "appearance3")
    
    }
    
    private var topPercent: CGFloat = 0.5

    @discardableResult func update(with type: PremiumLimitController.LimitType, counts: PremiumLimitController.Counts?, context: AccountContext, animated: Bool, hasDismiss: Bool = true) -> NSSize {
        let lottie: LocalAnimatedSticker
        if case .accounts = type {
            lottie = LocalAnimatedSticker.premium_addone
        } else {
            lottie = LocalAnimatedSticker.premium_double
        }
        var size = accept.update(type: type, lottie: lottie)
        accept.setFrameSize(size)
        
        acceptOK.set(font: .medium(.text), for: .Normal)
        acceptOK.set(background: theme.colors.accent, for: .Normal)
        acceptOK.set(color: theme.colors.underSelectedColor, for: .Normal)
        acceptOK.set(text: strings().modalOK, for: .Normal)
        acceptOK.layer?.cornerRadius = 10
        acceptOK.sizeToFit(NSMakeSize(0, 0), NSMakeSize(size.width, size.height), thatFit: true)
        acceptOK.autohighlight = false
        acceptOK.scaleOnClick = true
        
        
        accept.isHidden = context.premiumIsBlocked
        acceptOK.isHidden = !context.premiumIsBlocked || !hasDismiss

        dismiss.isHidden = !hasDismiss
        
        size = top.update(type: type, counts: counts, context: context)
        top.setFrameSize(size)
        
        let percent = type.percent(context.premiumLimits, counts: counts)

        self.topPercent = percent
        
        
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

//        top.layer?.cornerRadius = size.height / 2
        accept.layer?.cornerRadius = 10
    
        
        self.lineView.isHidden = context.premiumIsBlocked

        var height: CGFloat = 0
        
        height += accept.frame.height + 30
        height += self.desc.frame.height + 20
        height += self.title.frame.height + 10 + top.frame.height
        
        if !lineView.isHidden {
            height += lineView.frame.height + 10
        }
        
        return NSMakeSize(frame.width, height + 20 + 30)
        
    }
    
    override func layout() {
        super.layout()
        header.frame = NSMakeRect(0, 0, frame.width, 50)
        dismiss.centerY(x: 10)
        title.center()
        accept.centerX(y: frame.height - 30 - accept.frame.height)
        acceptOK.centerX(y: frame.height - 30 - accept.frame.height)
        desc.centerX(y: accept.frame.minY - desc.frame.height - 20)
        lineView.centerX(y: desc.frame.minY - lineView.frame.height - 20)
        
        //let topX = max(lineView.frame.minX, min(lineView.frame.maxX - top.frame.width, lineView.frame.width * topPercent))
        

        if lineView.isHidden {
            top.centerX(y: header.frame.maxY + 10)
        } else {
            let topX = lineView.frame.minX + (lineView.frame.width - top.frame.width) * max(min(1, topPercent), 0)
            top.setFrameOrigin(NSMakePoint(topX, lineView.frame.minY - top.frame.height - 10))
        }
        
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
        case pinInFolders(PeerGroupId)
        case faveStickers
        case publicLink
        case channels
        case uploadFile(Int?)
        case caption(Int)
        case about(Int)
        case accounts(Int)
        case sharedFolders
        case sharedInvites
        var eventSource: PremiumLogEventsSource {
            switch self {
            case .pin:
                return .double_limits(.dialog_pinned)
            case .pinInArchive:
                return .double_limits(.dialogs_folder_pinned)
            case .savedGifs:
                return .double_limits(.saved_gifs)
            case .folders:
                return .double_limits(.dialog_filters)
            case .chatInFolders:
                return .double_limits(.dialog_filters_chats)
            case .pinInFolders:
                return .double_limits(.dialog_filters_pinned)
            case .faveStickers:
                return .double_limits(.stickers_faved)
            case .publicLink:
                return .double_limits(.channels_public)
            case .channels:
                return .double_limits(.channels)
            case .uploadFile:
                return .double_limits(.upload_max_fileparts)
            case .caption:
                return .double_limits(.caption_length)
            case .accounts:
                return .double_limits(.accounts)
            case .about:
                return .double_limits(.about)
            case .sharedFolders:
                return .double_limits(.communities_joined)
            case .sharedInvites:
                return .double_limits(.community_invites)
            }
        }
    }
    
    struct Counts : Equatable {
        let pinnedCount: Int?
        let foldersCount: Int?
        let savedGifsCount: Int?
        let savedStickersCount: Int?
        let publicLinksCount: Int?
        init(pinnedCount: Int? = nil, foldersCount: Int? = nil, savedGifsCount: Int? = nil, savedStickersCount: Int? = nil, publicLinksCount: Int? = nil) {
            self.pinnedCount = pinnedCount
            self.foldersCount = foldersCount
            self.savedGifsCount = savedGifsCount
            self.savedStickersCount = savedStickersCount
            self.publicLinksCount = publicLinksCount
        }
    }
    
    private let context: AccountContext
    private let type: LimitType
    init(context: AccountContext, type: LimitType) {
        self.context = context
        self.type = type
        super.init(frame: NSMakeRect(0, 0, 350, 300))
        bar = .init(height: 0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let actionsDisposable = DisposableSet()
        
        self.onDeinit = {
            actionsDisposable.dispose()
        }
        
        let type = self.type
        
        let size = self.genericView.update(with: self.type, counts: nil, context: context, animated: false)
        
        let context = self.context

        
        self.modal?.resize(with:size, animated: false)
                
        self.genericView.close = { [weak self] in
            self?.close()
        }
        
        let source = type.eventSource
        
        self.genericView.premium = { [weak self] in
            if !context.premiumIsBlocked {
                showModal(with: PremiumBoardingController(context: context, source: source), for: context.window)
            }
            self?.close()
        }
        
        let pinnedCount:Signal<Int?, NoError> = context.account.postbox.transaction { transaction in
            switch type {
            case .pin:
                return transaction.getPinnedItemIds(groupId: .root).count
            case .pinInArchive:
                return transaction.getPinnedItemIds(groupId: Namespaces.PeerGroup.archive).count
            case let .pinInFolders(groupId):
                return transaction.getPinnedItemIds(groupId: groupId).count
            default:
                return nil
            }
        }
        let foldersCount:Signal<Int, NoError> = context.engine.peers.updatedChatListFilters() |> take(1) |> map { $0.count }
        
        let savedStickersCount: Signal<Int, NoError> = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 100) |> take(1) |> map {
            $0.orderedItemListsViews[0].items.count
        }
        
        let savedGifsCount: Signal<Int, NoError> = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentGifs], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 100) |> take(1) |> map {
            $0.orderedItemListsViews[0].items.count
        }
        
        let publicLinksCount: Signal<Int?, NoError> = .single(nil) |> then(context.engine.peers.channelAddressNameAssignmentAvailability(peerId: nil) |> mapToSignal { result -> Signal<Int?, NoError> in
            if case .addressNameLimitReached = result {
                return context.engine.peers.adminedPublicChannels()
                |> map { Optional($0.count) }
            } else {
                return .single(0)
            }
        })
        
        let signal: Signal<Counts, NoError> = combineLatest(pinnedCount, foldersCount, savedGifsCount, savedStickersCount, publicLinksCount)
        |> map { pinnedCount, foldersCount, savedGifsCount, savedStickersCount, publicLinksCount in
            return Counts(pinnedCount: pinnedCount, foldersCount: foldersCount, savedGifsCount: savedGifsCount, savedStickersCount: savedStickersCount, publicLinksCount: publicLinksCount)
        }
        |> deliverOnMainQueue
        
        
        actionsDisposable.add(signal.start(next: { [weak self] counts in
            self?.genericView.update(with: type, counts: counts, context: context, animated: false)
            if self?.didSetReady == false {
                self?.genericView.playAppearanceAnimation()
            }
            self?.readyOnce()
        }))
        
    }
    
    override func viewClass() -> AnyClass {
        return PremiumLimitView.self
    }
    
    private var genericView: PremiumLimitView {
        return self.view as! PremiumLimitView
    }
    
}


func showPremiumLimit(context: AccountContext, type: PremiumLimitController.LimitType) {
    if context.isPremium {
        alert(for: context.window, info: type.descText(context.premiumLimits, alreadyPremiumLimit: true))
    } else {
        showModal(with: PremiumLimitController(context: context, type: type), for: context.window)
    }
}
