//
//  WallpaperPatternPreview.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

private class WallpaperPatternView : Control {
    let imageView = TransformImageView()
    let checkbox: ImageView = ImageView()
    private let emptyTextView = TextView()
    fileprivate var pattern: Wallpaper?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        //addSubview(emptyTextView)
        addSubview(imageView)
        addSubview(checkbox)
        checkbox.image = theme.icons.chatGroupToggleSelected
        checkbox.sizeToFit()
        self.layer?.cornerRadius = .cornerRadius

        emptyTextView.userInteractionEnabled = false
        emptyTextView.isSelectable = false
    }
    
    override func layout() {
        super.layout()
        imageView.frame = bounds
        emptyTextView.center()
        checkbox.setFrameOrigin(NSMakePoint(frame.width - checkbox.frame.width - 5, 5))
    }
    
    func update(with pattern: Wallpaper?, isSelected: Bool, account: Account, color: NSColor) {
        checkbox.isHidden = !isSelected
        self.pattern = pattern
        
        let layout = TextViewLayout(.initialize(string: L10n.chatWPPatternNone, color: color.brightnessAdjustedColor, font: .normal(.title)))
        layout.measure(width: 80)
        emptyTextView.update(layout)
        
        if let pattern = pattern {
            emptyTextView.isHidden = true
            imageView.isHidden = false
            imageView.set(arguments: TransformImageArguments(corners: ImageCorners(radius: .cornerRadius), imageSize: pattern.dimensions.aspectFilled(NSMakeSize(400, 400)), boundingSize: bounds.size, intrinsicInsets: NSEdgeInsets(), emptyColor: color))
            switch pattern {
            case let .file(_, file, _, _):
                var representations:[TelegramMediaImageRepresentation] = []
                representations.append(contentsOf: file.previewRepresentations)
                if let dimensions = file.dimensions {
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource))
                }
                imageView.setSignal(chatWallpaper(account: account, representations: representations, mode: .screen, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred: false, synchronousLoad: false), animate: false, synchronousLoad: false)
            default:
                break
            }
        } else {
            backgroundColor = color
            emptyTextView.isHidden = false
            imageView.isHidden = true
        }
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class WallpaperPatternPreviewView: View {
    private let documentView: View = View()
    private let scrollView = NSScrollView()
    private let sliderView = LinearProgressControl(progressHeight: 5)
    private let intensityTextView = TextView()
    private let intensityContainerView = View()
    private let borderView = View()
    var updateIntensity: ((Float) -> Void)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scrollView)
        scrollView.documentView = documentView
        backgroundColor = theme.colors.background
        
        scrollView.backgroundColor = theme.colors.grayBackground.withAlphaComponent(0.7)
        
        borderView.backgroundColor = theme.colors.border
        sliderView.scrubberImage = theme.icons.videoPlayerSliderInteractor
        sliderView.roundCorners = true
        sliderView.alignment = .center
        sliderView.containerBackground = NSColor.grayBackground.withAlphaComponent(0.2)
        sliderView.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: theme.colors.grayForeground)
        sliderView.set(progress: 0.8)
        sliderView.userInteractionEnabled = true
        sliderView.insets = NSEdgeInsetsMake(0, 4.5, 0, 4.5)
        sliderView.containerBackground = theme.colors.grayForeground
        sliderView.onUserChanged = { [weak self] value in
            guard let `self` = self else {return}
            self.updateIntensity?(value)
        }
        
        let layout = TextViewLayout(.initialize(string: L10n.chatWPIntensity, color: theme.colors.grayText, font: .normal(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        intensityTextView.update(layout)
        
        intensityContainerView.addSubview(sliderView)
        intensityContainerView.addSubview(intensityTextView)
        intensityTextView.userInteractionEnabled = false
        intensityTextView.isSelectable = false
        addSubview(intensityContainerView)
        addSubview(borderView)
    }
    
    func updateColor(_ color: NSColor, account: Account) {
        self.color = color
        for subview in self.documentView.subviews {
            if let subview = (subview as? WallpaperPatternView) {
                subview.update(with: subview.pattern, isSelected: !subview.checkbox.isHidden, account: account, color: color)
            }
        }
    }
    
    fileprivate var color: NSColor = NSColor(rgb: 0xd6e2ee, alpha: 0.5)
    
    func updateSelected(_ pattern: Wallpaper?) {
        
        for subview in self.documentView.subviews {
            if let subview = (subview as? WallpaperPatternView) {
                if let pattern = pattern {
                    subview.checkbox.isHidden = subview.pattern == nil || subview.pattern?.isSemanticallyEqual(to: pattern) == false
                } else {
                    subview.checkbox.isHidden = pattern != subview.pattern
                }
            }
        }
        if let pattern = pattern {
            intensityContainerView.isHidden = false
            if let intensity = pattern.settings.intensity {
                sliderView.set(progress: CGFloat(intensity) / 100.0)
            }
        } else {
            intensityContainerView.isHidden = true
        }
    }
    
    func update(with patterns: [Wallpaper?], selected: Wallpaper?, account: Account, select: @escaping(Wallpaper?) -> Void) {
        documentView.removeAllSubviews()
        var x: CGFloat = 10
        for pattern in patterns {
            let patternView = WallpaperPatternView(frame: NSMakeRect(x, 10, 80, 80))
            patternView.update(with: pattern, isSelected: pattern == selected, account: account, color: self.color)
            patternView.set(handler: { [weak self] _ in
                guard let `self` = self else {return}
                select(pattern)
                self.updateSelected(pattern)
            }, for: .Click)
            documentView.addSubview(patternView)
            x += patternView.frame.width + 10
        }
        documentView.setFrameSize(NSMakeSize(x, 100))
    }
    
    override func layout() {
        super.layout()
        scrollView.frame = NSMakeRect(0, 0, frame.width, 100)
        
        intensityContainerView.setFrameSize(frame.width - 80, intensityTextView.frame.height + 12 + 3)
        sliderView.setFrameSize(NSMakeSize(intensityContainerView.frame.width - 20, 12))
        intensityTextView.centerX(y: 0)
        sliderView.centerX(y: intensityTextView.frame.height + 3)
        
        intensityContainerView.centerX(y: 110)
        borderView.frame = NSMakeRect(0, 0, frame.width, .borderSize)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class WallpaperPatternPreviewController: GenericViewController<WallpaperPatternPreviewView> {
    private let disposable = MetaDisposable()
    private let context: AccountContext
    
    var color: NSColor = NSColor(rgb: 0xd6e2ee, alpha: 0.5) {
        didSet {
            genericView.updateColor(color, account: context.account)
        }
    }
    
    var selected:((Wallpaper?) -> Void)?
    
    var intensity: Int32? = nil {
        didSet {
            self.selected?(pattern?.withUpdatedSettings(WallpaperSettings(color: pattern?.settings.color, intensity: intensity)))
        }
    }
    
    var pattern: Wallpaper? {
        didSet {
            let intensity = self.intensity ?? pattern?.settings.intensity
            self.intensity = intensity
            
            if let pattern = pattern {
                switch pattern {
                case .file:
                    genericView.updateSelected(pattern)
                default:
                    genericView.updateSelected(nil)
                }
            }
        }
    }
    
    init(context: AccountContext) {
        self.context = context
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.updateIntensity = { [weak self] intensity in
            guard let `self` = self else {return}
            self.intensity = Int32(intensity * 100)
        }
        
        let signal = telegramWallpapers(postbox: context.account.postbox, network: context.account.network) |> map { wallpapers -> [Wallpaper] in
            return wallpapers.compactMap { wallpaper in
                switch wallpaper {
                case let .file(_, _, _, _, isPattern, _, _, _, _):
                    return isPattern ? Wallpaper(wallpaper) : nil
                default:
                    return nil
                }
            }
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] patterns in
            guard let `self` = self else {return}
            self.genericView.update(with: [nil] + patterns, selected: nil, account: self.context.account, select: { [weak self] wallpaper in
                self?.selected?(wallpaper)
            })
        }))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
}
