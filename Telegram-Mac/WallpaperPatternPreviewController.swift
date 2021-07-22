//
//  WallpaperPatternPreviewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

final class WallpaperPatternPreviewView: View {
    private let documentView: View = View()
    private let scrollView = HorizontalScrollView()
    private let sliderView = LinearProgressControl(progressHeight: 5)
    private let intensityTextView = TextView()
    private let intensityContainerView = View()
    private let borderView = View()
    var updateIntensity: ((Float) -> Void)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scrollView)
        
        sliderView.highlightOnHover = false
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
        sliderView.liveScrobbling = true
        sliderView.onUserChanged = { [weak self] value in
            guard let `self` = self else {return}
            self.sliderView.set(progress: CGFloat(value))
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
    
    func updateColor(_ colors: [NSColor], rotation: Int32?, account: Account) {
        self.colors = colors
        for subview in self.documentView.subviews {
            if let subview = (subview as? WallpaperPatternView) {
                subview.update(with: subview.pattern, isSelected: !subview.checkbox.isHidden, account: account, colors: colors, rotation: rotation)
            }
        }
    }
    
    fileprivate var colors: [NSColor] = [NSColor(rgb: 0xd6e2ee, alpha: 0.5)]
    fileprivate var rotation: Int32? = nil

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
        
        let selectedView = self.documentView.subviews.first { view -> Bool in
            return !(view as! WallpaperPatternView).checkbox.isHidden
        }
        if let selectedView = selectedView {
            scrollView.clipView.scroll(to: NSMakePoint(min(max(selectedView.frame.midX - frame.width / 2, 0), max(documentView.frame.width - frame.width, 0)), 0), animated: true)
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
            patternView.update(with: pattern, isSelected: pattern == selected, account: account, colors: self.colors, rotation: self.rotation)
            patternView.set(handler: { [weak self] _ in
                guard let `self` = self else {return}
                select(pattern)
              //  self.updateSelected(pattern)
            }, for: .Click)
            documentView.addSubview(patternView)
            x += patternView.frame.width + 10
        }
        documentView.setFrameSize(NSMakeSize(x, 100))
        
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        let intensitySize = NSMakeSize(frame.width - 20, intensityTextView.frame.height + 12 + 3)
        var intensityRect = focus(intensitySize)
        intensityRect.origin.y = 110
        
        transition.updateFrame(view: scrollView, frame: NSMakeRect(0, 0, frame.width, 100))
        transition.updateFrame(view: intensityContainerView, frame: intensityRect)
        
        transition.updateFrame(view: intensityTextView, frame: intensityTextView.centerFrameX(y: 0))
        transition.updateFrame(view: borderView, frame: NSMakeRect(0, 0, frame.width, .borderSize))

        
        let sliderSize = NSMakeSize(intensityContainerView.frame.width, 12)
        var sliderRect = intensityContainerView.focus(sliderSize)
        sliderRect.origin.y = intensityTextView.frame.height + 3
        
        transition.updateFrame(view: sliderView, frame: sliderRect)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class WallpaperPatternPreviewController: GenericViewController<WallpaperPatternPreviewView> {
    private let disposable = MetaDisposable()
    private let context: AccountContext
    
    var colors: ([NSColor], Int32?) = ([NSColor(rgb: 0xd6e2ee, alpha: 0.5)], nil) {
        didSet {
            genericView.updateColor(self.colors.0, rotation: self.colors.1, account: context.account)
        }
    }
    
    var selected:((Wallpaper?) -> Void)?
    
    var intensity: Int32? = nil {
        didSet {
            NSLog("intensity: \(intensity)")
            if oldValue != nil, oldValue != intensity {
                self.selected?(pattern?.withUpdatedSettings(WallpaperSettings(colors: pattern?.settings.colors ?? [], intensity: intensity)))
            }
        }
    }
    
    var pattern: Wallpaper? {
        didSet {
            let intensity = self.intensity ?? pattern?.settings.intensity ?? 80
            self.intensity = intensity
            
            if let pattern = pattern {
                switch pattern {
                case .file:
                    genericView.updateSelected(pattern.withUpdatedSettings(.init(colors: pattern.settings.colors, intensity: intensity, rotation: pattern.settings.rotation)))
                default:
                    break
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
                self?.pattern = wallpaper
                self?.selected?(wallpaper)
            })
            self.pattern = patterns.first
        }))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
}
