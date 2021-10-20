//
//  WidgetAppearance.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore

import SwiftSignalKit



private final class ThemePreview : Control {
    private class Container : View {
        private let disposable = MetaDisposable()
        private let imageView = TransformImageView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setup()
        }
        override init() {
            super.init(frame: .zero)
            setup()
        }
        private func setup() {
            addSubview(imageView)
        }
        
        func set(_ source: ThemeSource, bubbled: Bool, context: AccountContext) {
                        
            let signal = themeAppearanceThumbAndData(context: context, bubbled: bubbled, parent: theme.colors, source: source, thumbSource: .widget) |> deliverOnMainQueue
            
            self.imageView.setSignal(signal: cachedThemeThumb(source: source, bubbled: bubbled, thumbSource: .widget), clearInstantly: false)

            disposable.set(signal.start(next: { [weak self] image, data in
                self?.imageView.setSignal(signal: .single(image), clearInstantly: true, animate: false)
                cacheThemeThumb(image, source: source, bubbled: bubbled, thumbSource: .widget)
            }))
        }
        
        deinit {
            disposable.dispose()
        }
        
        override func layout() {
            super.layout()
            if bounds.size.width >= 4 && bounds.size.height >= 4 {
                imageView.frame = bounds.insetBy(dx: 4, dy: 4)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    private let container = Container()
    private let nameView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    override init() {
        super.init(frame: .zero)
        setup()
    }
    private func setup() {
        addSubview(container)
        addSubview(nameView)
        container.isEventLess = true
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        self.scaleOnClick = true
    }
    
    func update(_ text: String, source: ThemeSource, bubbled: Bool, context: AccountContext, isSelected: Bool) {
        let layout = TextViewLayout(.initialize(string: text, color: isSelected ? theme.colors.accent : theme.colors.text, font: .medium(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        
        self.nameView.update(layout)
        
        container.set(source, bubbled: bubbled, context: context)
        
        container.layer?.cornerRadius = 20
        container.layer?.borderWidth = isSelected ? 1.66 : 1
        container.layer?.borderColor = isSelected ? theme.colors.accent.cgColor : theme.colors.border.withAlphaComponent(0.6).cgColor

    }
    
    override func layout() {
        super.layout()
        container.frame = NSMakeRect(0, 0, frame.width, frame.height - 20)
        self.nameView.centerX(y: frame.height - nameView.frame.height)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class WidgetAppearanceView : View {
    
    private let minimalist = ThemePreview()
    private let colorful = ThemePreview()

    private let modeTitle = TextView()

    
    var selectMin:(()->Void)? = nil
    var selectColorful:(()->Void)? = nil
    
    var getContext:(()->AccountContext?)? = nil

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(minimalist)
        addSubview(colorful)
        addSubview(modeTitle)
        minimalist.set(handler: { [weak self] _ in
            self?.selectMin?()
        }, for: .Click)
        
        colorful.set(handler: { [weak self] _ in
            self?.selectColorful?()
        }, for: .Click)
        
        modeTitle.userInteractionEnabled = false
        modeTitle.isSelectable = false
    }
    

    var dayInstall: InstallThemeSource?
    var darkInstall: InstallThemeSource?

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        let theme = theme as! TelegramPresentationTheme
        
        if let context = getContext?() {
            let installSource: InstallThemeSource?
            if theme.colors.isDark {
                installSource = darkInstall
            } else {
                installSource = dayInstall
            }
            let source: ThemeSource
            if let installSource = installSource {
                switch installSource {
                case let .cloud(theme, _):
                    source = .cloud(theme)
                case let .local(palette):
                    source = .local(palette, nil)
                }
            } else {
                source = .local(theme.colors, nil)
            }
            minimalist.update(L10n.emptyChatAppearanceMin, source: source, bubbled: false, context: context, isSelected: !theme.bubbled)
            colorful.update(L10n.emptyChatAppearanceColorful, source: source, bubbled: true, context: context, isSelected: theme.bubbled)
        }
        
        let titleLayout = TextViewLayout.init(.initialize(string: L10n.emptyChatAppearanceChatMode, color: theme.colors.text, font: .medium(.text)))
        titleLayout.measure(width: frame.width - 20)
        modeTitle.update(titleLayout)


        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        modeTitle.resize(frame.width - 20)
        modeTitle.centerX()

       
        minimalist.frame = NSMakeRect(0, 30, 140, frame.height - 30)
        colorful.frame = NSMakeRect(frame.width - 140, 30, 140, frame.height - 30)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



final class WidgetAppearanceController : TelegramGenericViewController<WidgetView<WidgetAppearanceView>> {
    
    private struct State : Equatable {
        var dayInstall: InstallThemeSource?
        var darkInstall: InstallThemeSource?
    }
    
    private let disposable = MetaDisposable()
    override init(_ context: AccountContext) {
        super.init(context)
        bar = .init(height: 0)
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let initialState = State()
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        let loadSourcesDisposable = MetaDisposable()
        
        
        let nightSettings = autoNightSettings(accountManager: context.sharedContext.accountManager) |> deliverOnMainQueue
        
        let themeSettings = themeSettingsView(accountManager: context.sharedContext.accountManager) |> deliverOnMainQueue

        
        let context = self.context
        
        
        func apply(_ source: InstallThemeSource) {
            
            let update: Signal<Void, NoError>
                
            switch source {
            case let .local(palette):
                update = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                    var settings = settings
                    settings = settings.withUpdatedPalette(palette).withUpdatedCloudTheme(nil)
                    
                    let defaultTheme = DefaultTheme(local: palette.parent, cloud: nil)
                    if palette.isDark {
                        settings = settings.withUpdatedDefaultDark(defaultTheme)
                    } else {
                        settings = settings.withUpdatedDefaultDay(defaultTheme)
                    }
                    return settings.installDefaultWallpaper().installDefaultAccent().withUpdatedDefaultIsDark(palette.isDark).withSavedAssociatedTheme()
                })
            case let .cloud(cloud, cached):
                if let cached = cached {
                    update = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                        var settings = settings
                        settings = settings.withUpdatedPalette(cached.palette)
                        settings = settings.withUpdatedCloudTheme(cloud)
                        settings = settings.updateWallpaper { _ in
                            return ThemeWallpaper(wallpaper: cached.wallpaper, associated: AssociatedWallpaper(cloud: cached.cloudWallpaper, wallpaper: cached.wallpaper))
                        }
                        let defaultTheme = DefaultTheme(local: settings.palette.parent, cloud: DefaultCloudTheme(cloud: cloud, palette: cached.palette, wallpaper: AssociatedWallpaper(cloud: cached.cloudWallpaper, wallpaper: cached.wallpaper)))
                        if cached.palette.isDark {
                            settings = settings.withUpdatedDefaultDark(defaultTheme)
                        } else {
                            settings = settings.withUpdatedDefaultDay(defaultTheme)
                        }
                        return settings.saveDefaultWallpaper().withUpdatedDefaultIsDark(cached.palette.isDark).withSavedAssociatedTheme()
                    })
                    _ = downloadAndApplyCloudTheme(context: context, theme: cloud, install: true).start()
                } else if cloud.file != nil || cloud.settings != nil {
                    _ = showModalProgress(signal: downloadAndApplyCloudTheme(context: context, theme: cloud, install: true), for: context.window).start()
                    update = .single(Void())
                } else {
                    update = .single(Void())
                }
            }
            
            let night = updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                return current.withUpdatedSchedule(nil).withUpdatedSystemBased(false)
            })
            
            _ = (update |> then(night)).start()
            
        }
        
        genericView.dataView = WidgetAppearanceView(frame: .zero)
        
        genericView.dataView?.getContext = { [weak self] in
            return self?.context
        }

        genericView.dataView?.selectColorful = {
            let update = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.withUpdatedBubbled(true)
            })
            _ = update.start()
        }
        genericView.dataView?.selectMin = {
            let update = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                return settings.withUpdatedBubbled(false)
            })
            _ = update.start()
        }
                
        disposable.set(combineLatest(nightSettings, statePromise.get(), appearanceSignal).start(next: { [weak self] night, state, _ in
            
            let isSystemBased: Bool = night.systemBased

            self?.genericView.dataView?.dayInstall = state.dayInstall
            self?.genericView.dataView?.darkInstall = state.darkInstall
            self?.genericView.updateLocalizationAndTheme(theme: theme)
            
            var buttons:[WidgetData.Button] = []
            
            buttons.append(.init(text: { L10n.emptyChatAppearanceSystem }, selected: {
                return isSystemBased
            }, image: {
                return night.systemBased ? theme.icons.empty_chat_system_active : theme.icons.empty_chat_system
            }, click: {
                _ = updateAutoNightSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                    return current.withUpdatedSchedule(nil).withUpdatedSystemBased(true)
                }).start()
            }))
            
            let darkSelected = theme.colors.isDark && !isSystemBased
            let lightSelected = !theme.colors.isDark && !isSystemBased

            
            buttons.append(.init(text: { L10n.emptyChatAppearanceDark }, selected: {
                return darkSelected
            }, image: {
                return darkSelected ? theme.icons.empty_chat_dark_active : theme.icons.empty_chat_dark
            }, click: {
                if let source = state.darkInstall {
                    apply(source)
                }
            }))
            
            buttons.append(.init(text: { L10n.emptyChatAppearanceLight }, selected: {
                return lightSelected
            }, image: {
                return lightSelected ? theme.icons.empty_chat_light_active : theme.icons.empty_chat_light
            }, click: {
                if let source = state.dayInstall {
                    apply(source)
                }
            }))
            
            self?.genericView.update(.init(title: { L10n.emptyChatAppearance }, desc: { L10n.emptyChatAppearanceDesc }, descClick: {
                context.sharedContext.bindings.rootNavigation().push(AppAppearanceViewController(context: context))
            }, buttons: buttons))
            
            self?.readyOnce()
        }))
        
        let loadSources: Signal<[InstallThemeSource], NoError> = themeSettings |> mapToSignal { settings in
            let daySource: ThemeSource
            let darkSource: ThemeSource
            if let cloud = settings.defaultDay.cloud?.cloud {
                daySource = .cloud(cloud)
            } else {
                daySource = .local(settings.defaultDay.local.palette, nil)
            }
                        
            if let cloud = settings.defaultDark.cloud?.cloud {
                darkSource = .cloud(cloud)
            } else {
                darkSource = .local(settings.defaultDark.local.palette, nil)
            }
            
            return combineLatest(themeInstallSource(context: context, source: daySource), themeInstallSource(context: context, source: darkSource)) |> map {
                return [$0, $1]
            }
        } |> deliverOnMainQueue
        
        loadSourcesDisposable.set(loadSources.start(next: { sources in
            updateState { current in
                var current = current
                current.dayInstall = sources[0]
                current.darkInstall = sources[1]
                return current
            }
        }))
        
        
    }
}
