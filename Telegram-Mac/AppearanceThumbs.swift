//
//  AppearanceThumbs.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import TGUIKit
import SwiftSignalKit
import Postbox

func drawBg(_ backgroundMode: TableBackgroundMode, bubbled: Bool, rect: NSRect, in ctx: CGContext) {
    switch backgroundMode {
    case let .background(image, intensity, colors, rotation):
        let imageSize = image.size.aspectFilled(rect.size)
        ctx.saveGState()
        ctx.translateBy(x: 1, y: -1)

        if let colors = colors, !colors.isEmpty {
            if colors.count > 2 {
                let preview = AnimatedGradientBackgroundView.generatePreview(size: NSMakeSize(200, 100).fitted(NSMakeSize(32, 32)), colors: colors)
                
                ctx.saveGState()
                ctx.translateBy(x: rect.width / 2.0, y: rect.height / 2.0)
                ctx.scaleBy(x: 1, y: -1.0)
                ctx.translateBy(x: -rect.width / 2.0, y: -rect.height / 2.0)

                ctx.draw(preview, in: rect.focus(NSMakeSize(500, 500)))
                ctx.restoreGState()
                
            } else if colors.count > 1 {
                let gradientColors = colors.map { $0.cgColor } as CFArray
                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                var locations: [CGFloat] = []
                for i in 0 ..< colors.count {
                    locations.append(delta * CGFloat(i))
                }
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                ctx.saveGState()
                ctx.translateBy(x: rect.width / 2.0, y: rect.height / 2.0)
                ctx.rotate(by: CGFloat(rotation ?? 0) * CGFloat.pi / -180.0)
                ctx.translateBy(x: -rect.width / 2.0, y: -rect.height / 2.0)
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: rect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                ctx.restoreGState()
            } else if let color = colors.first {
                ctx.setFillColor(color.cgColor)
                ctx.fill(rect)
            }
        }
        
        if let colors = colors, !colors.isEmpty {
            if let image = image._cgImage {
                ctx.setBlendMode(.softLight)
                ctx.setAlpha(CGFloat(abs(intensity ?? 50)) / 100.0 * 0.5)
                ctx.draw(image, in: rect.focus(imageSize))
            }
        } else {
            var bp = 0
            bp += 1
        }
        ctx.restoreGState()
    case let .color(color):
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
    case let .gradient(colors, rotation):
        if bubbled {
            if colors.count > 2 {
                let preview = AnimatedGradientBackgroundView.generatePreview(size: rect.size.fitted(NSMakeSize(32, 32)), colors: colors)
                ctx.saveGState()
                ctx.translateBy(x: rect.width / 2.0, y: rect.height / 2.0)
                ctx.scaleBy(x: 1, y: -1.0)
                ctx.translateBy(x: -rect.width / 2.0, y: -rect.height / 2.0)

                ctx.draw(preview, in: rect.size.bounds)
                ctx.restoreGState()
            } else {
                let colors = colors.reversed()
                let gradientColors = colors.map { $0.cgColor } as CFArray
                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                var locations: [CGFloat] = []
                for i in 0 ..< colors.count {
                    locations.append(delta * CGFloat(i))
                }
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                ctx.saveGState()
                ctx.translateBy(x: rect.width / 2.0, y: rect.height / 2.0)
                ctx.rotate(by: CGFloat(rotation ?? 0) * CGFloat.pi / -180.0)
                ctx.translateBy(x: -rect.width / 2.0, y: -rect.height / 2.0)
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: rect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                ctx.restoreGState()
            }
        }
    default:
        break
    }
}

private func cloudThemeData(context: AccountContext, theme: TelegramTheme, file: TelegramMediaFile) -> Signal<(ColorPalette, Wallpaper, TelegramWallpaper?), NoError> {
    return Signal { subscriber in
        
        let fetchDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.theme(theme: ThemeReference.slug(theme.slug), resource: file.resource)).start()
        let wallpaperDisposable = DisposableSet()
        
        let resourceData = context.account.postbox.mediaBox.resourceData(file.resource) |> filter { $0.complete } |> take(1)
        
        let dataDisposable = resourceData.start(next: { data in
            if let palette = importPalette(data.path) {
                var wallpaper: Signal<TelegramWallpaper?, GetWallpaperError> = .single(nil)
                var newSettings: WallpaperSettings = WallpaperSettings()
                switch palette.wallpaper {
                case .none:
                    wallpaper = .single(nil)
                case .builtin:
                    wallpaper = .single(.builtin(newSettings))
                case let .color(color):
                    wallpaper = .single(.color(color.argb))
                case let .url(string):
                    let link = inApp(for: string as NSString, context: context)
                    switch link {
                    case let .wallpaper(values):
                        switch values.preview {
                        case let .slug(slug, settings):
                            wallpaper = getWallpaper(network: context.account.network, slug: slug) |> map(Optional.init)
                            newSettings = settings
                        default:
                            break
                        }
                    default:
                        break
                    }
                }
                
                wallpaperDisposable.add(wallpaper.start(next: { cloud in
                    if let cloud = cloud {
                        let wp = Wallpaper(cloud).withUpdatedSettings(newSettings)
                        wallpaperDisposable.add(moveWallpaperToCache(postbox: context.account.postbox, wallpaper: wp).start(next: { wallpaper in
                            subscriber.putNext((palette, wallpaper, cloud))
                            subscriber.putCompletion()
                        }))
                    } else {
                        subscriber.putNext((palette, .none, nil))
                        subscriber.putCompletion()
                    }
                }, error: { _ in
                    subscriber.putCompletion()
                }))
            }
            
        })

        return ActionDisposable {
            fetchDisposable.dispose()
            dataDisposable.dispose()
            wallpaperDisposable.dispose()
        }
    }
}

private func localThemeData(context: AccountContext, theme: TelegramTheme, palette: ColorPalette) -> Signal<(ColorPalette, Wallpaper, TelegramWallpaper?), NoError> {
    return Signal { subscriber in
        
        var wallpaper: Signal<TelegramWallpaper?, GetWallpaperError> = .single(nil)
        var newSettings = WallpaperSettings()
        if let wp = theme.settings?.wallpaper {
            wallpaper = .single(wp)
        } else {
            switch palette.wallpaper {
            case .none:
                wallpaper = .single(nil)
            case .builtin:
                wallpaper = .single(.builtin(newSettings))
            case let .color(color):
                wallpaper = .single(.color(color.argb))
            case let .url(string):
                let link = inApp(for: string as NSString, context: context)
                switch link {
                case let .wallpaper(values):
                    switch values.preview {
                    case let .slug(slug, settings):
                        wallpaper = getWallpaper(network: context.account.network, slug: slug) |> map(Optional.init)
                        newSettings = settings
                    default:
                        break
                    }
                default:
                    break
                }
            }
        }
        
        let wallpaperDisposable = DisposableSet()
        
        wallpaperDisposable.add(wallpaper.start(next: { cloud in
            if let cloud = cloud {
                let wp = Wallpaper(cloud).withUpdatedSettings(newSettings)
                wallpaperDisposable.add(moveWallpaperToCache(postbox: context.account.postbox, wallpaper: wp).start(next: { wallpaper in
                    subscriber.putNext((palette, wallpaper, cloud))
                    subscriber.putCompletion()
                }))
            } else {
                subscriber.putNext((palette, .none, nil))
                subscriber.putCompletion()
            }
        }, error: { _ in
            subscriber.putCompletion()
        }))

        return ActionDisposable {
            wallpaperDisposable.dispose()
        }
    }
}


private func cloudThemeCrossplatformData(context: AccountContext, settings: TelegramThemeSettings) -> Signal<(ColorPalette, Wallpaper, TelegramWallpaper?), NoError> {
    
    let palette = settings.palette
    let wallpaper: Wallpaper = settings.wallpaper?.uiWallpaper ?? .none
    let cloud = settings.wallpaper
    return moveWallpaperToCache(postbox: context.account.postbox, wallpaper: wallpaper) |> map { wallpaper in
        return (palette, wallpaper, cloud)
    }
}


private func generateThumb(palette: ColorPalette, bubbled: Bool, wallpaper: Wallpaper) -> Signal<CGImage, NoError> {
    return Signal { subscriber in
        let image = generateImage(NSMakeSize(80, 55), rotatedContext: { size, ctx in
            let rect = NSMakeRect(0, 0, size.width, size.height)
            ctx.clear(rect)
            ctx.round(size, 10)
            
            
            let backgroundMode: TableBackgroundMode
            if bubbled {
                switch wallpaper {
                case .builtin:
                    backgroundMode = TelegramPresentationTheme.defaultBackground
                case let.color(color):
                    backgroundMode = .color(color: NSColor(argb: color).withAlphaComponent(1.0))
                case let .gradient(_, colors, rotation):
                    backgroundMode = .gradient(colors: colors.map { NSColor(argb: $0).withAlphaComponent(1.0) }, rotation: rotation)
                case let .image(representation, settings):
                    if let resource = largestImageRepresentation(representation)?.resource, let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(resource, settings: settings))) {
                        backgroundMode = .background(image: image, intensity: settings.intensity, colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
                    } else {
                        backgroundMode = TelegramPresentationTheme.defaultBackground
                    }
                    
                case let .file(_, file, settings, isPattern):
                    if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(file.resource, settings: settings))) {
                        backgroundMode = .background(image: image, intensity: settings.intensity, colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
                    } else {
                        backgroundMode = TelegramPresentationTheme.defaultBackground
                    }
                case .none:
                    backgroundMode = .color(color: palette.chatBackground)
                case let .custom(representation, blurred):
                    if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(representation.resource, settings: WallpaperSettings(blur: blurred)))) {
                        backgroundMode = .background(image: image, intensity: nil, colors: nil, rotation: nil)
                    } else {
                        backgroundMode = TelegramPresentationTheme.defaultBackground
                    }
                }
            } else {
                backgroundMode = .color(color: palette.chatBackground)
            }
            
            func applyBubbles() {
                let bubbleImage = NSImage(named: "Icon_ThemeBubble")
                if let incoming = bubbleImage?.precomposed(palette.bubbleBackground_incoming, flipVertical: true) {
                    ctx.draw(incoming, in: NSMakeRect(7, 9, 48, 16))
                }
                if let outgoing = bubbleImage?.precomposed(palette.bubbleBackground_outgoing, flipVertical: true, flipHorizontal: true) {
                    ctx.draw(outgoing, in: NSMakeRect(size.width - 57, size.height - 24, 48, 16))
                }
            }
            
            func applyPlain() {
                ctx.setFillColor(palette.accent.cgColor)
                ctx.fillEllipse(in: NSMakeRect(10, 7, 17, 17))
                
                if true {
                    let name1 = generateImage(NSMakeSize(20, 4), rotatedContext: { size, ctx in
                        let rect = NSMakeRect(0, 0, size.width, size.height)
                        ctx.clear(rect)
                        ctx.round(size, 2)
                        ctx.setFillColor(palette.accent.cgColor)
                        ctx.fill(rect)
                    })!
                    ctx.draw(name1, in: NSMakeRect(10 + 17 + 3, 7 + 2, name1.backingSize.width, name1.backingSize.height))
                    
                    let text1 = generateImage(NSMakeSize(40, 4), rotatedContext: { size, ctx in
                        let rect = NSMakeRect(0, 0, size.width, size.height)
                        ctx.clear(rect)
                        ctx.round(size, 2)
                        ctx.setFillColor(palette.grayText.withAlphaComponent(0.5).cgColor)
                        ctx.fill(rect)
                    })!
                    ctx.draw(text1, in: NSMakeRect(10 + 17 + 3, 7 + 2 + 4 + 4, text1.backingSize.width, text1.backingSize.height))
                }
                
                if true {
                    ctx.setFillColor(palette.accent.cgColor)
                    ctx.fillEllipse(in: NSMakeRect(10, 7 + 17 + 7, 17, 17))
                    
                    let name1 = generateImage(NSMakeSize(20, 4), rotatedContext: { size, ctx in
                        let rect = NSMakeRect(0, 0, size.width, size.height)
                        ctx.clear(rect)
                        ctx.round(size, 2)
                        ctx.setFillColor(palette.accent.cgColor)
                        ctx.fill(rect)
                    })!
                    ctx.draw(name1, in: NSMakeRect(10 + 17 + 3, 7 + 17 + 7 + 2, name1.backingSize.width, name1.backingSize.height))
                    
                    let text1 = generateImage(NSMakeSize(40, 4), rotatedContext: { size, ctx in
                        let rect = NSMakeRect(0, 0, size.width, size.height)
                        ctx.clear(rect)
                        ctx.round(size, 2)
                        ctx.setFillColor(palette.grayText.withAlphaComponent(0.5).cgColor)
                        ctx.fill(rect)
                    })!
                    ctx.draw(text1, in: NSMakeRect(10 + 17 + 3, 7 + 17 + 7 + 2 + 4 + 4, text1.backingSize.width, text1.backingSize.height))
                }
                
                
            }
            drawBg(backgroundMode, bubbled: bubbled, rect: rect, in: ctx)
            if bubbled {
                applyBubbles()
            } else {
                applyPlain()
            }
            
        })!
        
        subscriber.putNext(image)
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}


private func generateWidgetThumb(palette: ColorPalette, bubbled: Bool, wallpaper: Wallpaper) -> Signal<CGImage, NoError> {
    return Signal { subscriber in
        let image = generateImage(NSMakeSize(132, 86), rotatedContext: { size, ctx in
            let rect = NSMakeRect(0, 0, size.width, size.height)
            ctx.clear(rect)
            ctx.round(size, 17)
            
            
            let backgroundMode: TableBackgroundMode
            if bubbled {
                switch wallpaper {
                case .builtin:
                    backgroundMode = TelegramPresentationTheme.defaultBackground
                case let.color(color):
                    backgroundMode = .color(color: NSColor(argb: color).withAlphaComponent(1.0))
                case let .gradient(_, colors, rotation):
                    backgroundMode = .gradient(colors: colors.map { NSColor(argb: $0).withAlphaComponent(1.0) }, rotation: rotation)
                case let .image(representation, settings):
                    if let resource = largestImageRepresentation(representation)?.resource, let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(resource, settings: settings))) {
                        backgroundMode = .background(image: image, intensity: settings.intensity, colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
                    } else {
                        backgroundMode = TelegramPresentationTheme.defaultBackground
                    }
                    
                case let .file(_, file, settings, isPattern):
                    if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(file.resource, settings: settings))) {
                        backgroundMode = .background(image: image, intensity: settings.intensity, colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
                    } else {
                        backgroundMode = TelegramPresentationTheme.defaultBackground
                    }
                case .none:
                    backgroundMode = .color(color: palette.chatBackground)
                case let .custom(representation, blurred):
                    if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(representation.resource, settings: WallpaperSettings(blur: blurred)))) {
                        backgroundMode = .background(image: image, intensity: nil, colors: nil, rotation: nil)
                    } else {
                        backgroundMode = TelegramPresentationTheme.defaultBackground
                    }
                }
            } else {
                backgroundMode = .color(color: palette.chatBackground)
            }
            
            func applyBubbles() {
                
                ctx.draw(NSImage(named: "Icon_ThemePreview_Dino")!.precomposed(flipVertical: true), in: NSMakeRect(10, 24, 24, 24))
                ctx.draw(NSImage(named: "Icon_ThemePreview_Duck")!.precomposed(flipVertical: true), in: NSMakeRect(10, 54, 24, 24))

                let bubble1 = generateImage(NSMakeSize(80, 38), rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    ctx.round(size, 12)
                    ctx.setFillColor(palette.bubbleBackground_incoming.cgColor)
                    ctx.fill(rect)
                })!
                
                ctx.draw(bubble1, in: NSMakeRect(40, 10, 80, 38))
                
                let bubble1Text1 = generateImage(NSMakeSize(62, 6), rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    ctx.round(size, size.height / 2)
                    ctx.setFillColor(palette.grayText.withAlphaComponent(0.5).cgColor)
                    ctx.fill(rect)
                })!
                ctx.draw(bubble1Text1, in: NSMakeRect(49, 19, 62, 6))
                
                let bubble1Text2 = generateImage(NSMakeSize(38, 6), rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    ctx.round(size, size.height / 2)
                    ctx.setFillColor(palette.grayText.withAlphaComponent(0.5).cgColor)
                    ctx.fill(rect)
                })!
                ctx.draw(bubble1Text2, in: NSMakeRect(49, 33, 38, 6))

                
                let bubble2 = generateImage(NSMakeSize(54, 24), rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    ctx.round(size, 12)
                    ctx.setFillColor(palette.bubbleBackground_incoming.cgColor)
                    ctx.fill(rect)
                })!
                
                ctx.draw(bubble2, in: NSMakeRect(40, 54, 54, 24))
                
                let bubble2Text1 = generateImage(NSMakeSize(36, 6), rotatedContext: { size, ctx in
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    ctx.round(size, size.height / 2)
                    ctx.setFillColor(palette.grayText.withAlphaComponent(0.5).cgColor)
                    ctx.fill(rect)
                })!
                ctx.draw(bubble2Text1, in: NSMakeRect(49, 63, 36, 6))
            }
            
            func applyPlain() {
                ctx.draw(NSImage(named: "Icon_ThemePreview_Dino")!.precomposed(flipVertical: true), in: NSMakeRect(10, 10, 24, 24))
                if true {
                    let name1 = generateImage(NSMakeSize(32, 6), rotatedContext: { size, ctx in
                        let rect = NSMakeRect(0, 0, size.width, size.height)
                        ctx.clear(rect)
                        ctx.round(size, size.height / 2)
                        ctx.setFillColor(palette.peerAvatarGreenTop.cgColor)
                        ctx.fill(rect)
                    })!
                    ctx.draw(name1, in: NSMakeRect(42, 13, name1.backingSize.width, name1.backingSize.height))
                    
                    let text1 = generateImage(NSMakeSize(80, 6), rotatedContext: { size, ctx in
                        let rect = NSMakeRect(0, 0, size.width, size.height)
                        ctx.clear(rect)
                        ctx.round(size, size.height / 2)
                        ctx.setFillColor(palette.grayText.withAlphaComponent(0.5).cgColor)
                        ctx.fill(rect)
                    })!
                    ctx.draw(text1, in: NSMakeRect(42, 25, text1.backingSize.width, text1.backingSize.height))
                    
                    let text2 = generateImage(NSMakeSize(48, 6), rotatedContext: { size, ctx in
                        let rect = NSMakeRect(0, 0, size.width, size.height)
                        ctx.clear(rect)
                        ctx.round(size, size.height / 2)
                        ctx.setFillColor(palette.grayText.withAlphaComponent(0.5).cgColor)
                        ctx.fill(rect)
                    })!
                    ctx.draw(text2, in: NSMakeRect(42, 37, text2.backingSize.width, text2.backingSize.height))

                }
                
                if true {
                    ctx.draw(NSImage(named: "Icon_ThemePreview_Duck")!.precomposed(flipVertical: true), in: NSMakeRect(10, 54, 24, 24))

                    let name1 = generateImage(NSMakeSize(32, 6), rotatedContext: { size, ctx in
                        let rect = NSMakeRect(0, 0, size.width, size.height)
                        ctx.clear(rect)
                        ctx.round(size, size.height / 2)
                        ctx.setFillColor(palette.peerAvatarVioletTop.cgColor)
                        ctx.fill(rect)
                    })!
                    ctx.draw(name1, in: NSMakeRect(42, 57, name1.backingSize.width, name1.backingSize.height))
                    
                    let text1 = generateImage(NSMakeSize(80, 6), rotatedContext: { size, ctx in
                        let rect = NSMakeRect(0, 0, size.width, size.height)
                        ctx.clear(rect)
                        ctx.round(size, size.height / 2)
                        ctx.setFillColor(palette.grayText.withAlphaComponent(0.5).cgColor)
                        ctx.fill(rect)
                    })!
                    ctx.draw(text1, in: NSMakeRect(42, 69, text1.backingSize.width, text1.backingSize.height))
                }
            }
            drawBg(backgroundMode, bubbled: bubbled, rect: rect, in: ctx)
            if bubbled {
                applyBubbles()
            } else {
                applyPlain()
            }
        })!
        
        subscriber.putNext(image)
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}



func themeAppearanceThumbAndData(context: AccountContext, bubbled: Bool, source: ThemeSource, thumbSource: AppearanceThumbSource = .general) -> Signal<(TransformImageResult, InstallThemeSource), NoError> {
    
    var thumbGenerator = generateThumb
    switch thumbSource {
    case .widget:
        thumbGenerator = generateWidgetThumb
    case .general:
        thumbGenerator = generateThumb
    }
    
    switch source {
    case let .cloud(cloud):
        if let file = cloud.file {
            return cloudThemeData(context: context, theme: cloud, file: file) |> mapToSignal { data in
                return thumbGenerator(data.0, bubbled, data.1) |> map { image in
                    return (TransformImageResult(image, true), .cloud(cloud, InstallCloudThemeCachedData(palette: data.0, wallpaper: data.1, cloudWallpaper: data.2)))
                }
            }
        } else if let palette = cloud.settings?.palette {
            
            let settings = themeSettingsView(accountManager: context.sharedContext.accountManager) |> take(1)
            
            return settings |> map { settings -> (Wallpaper, ColorPalette) in
                let settings = settings
                    .withUpdatedPalette(palette)
                    .withUpdatedCloudTheme(cloud)
                    .installDefaultAccent()
                    .installDefaultWallpaper()
                return (settings.wallpaper.wallpaper, settings.palette)
            } |> mapToSignal { wallpaper, palette in
                return thumbGenerator(palette, bubbled, wallpaper) |> map { image in
                    return (TransformImageResult(image, true), .cloud(cloud, InstallCloudThemeCachedData(palette: palette, wallpaper: wallpaper, cloudWallpaper: cloud.settings?.wallpaper)))
                }
            }
        } else {
            return .single((TransformImageResult(theme.icons.appearanceAddPlatformTheme, true), .cloud(cloud, nil)))
        }
    case let .local(palette, cloud):
        let settings = themeSettingsView(accountManager: context.sharedContext.accountManager) |> take(1)
        
        return settings |> map { settings -> (Wallpaper, ColorPalette) in
            let settings = settings
                .withUpdatedPalette(palette)
                .withUpdatedCloudTheme(cloud)
                .installDefaultAccent()
                .installDefaultWallpaper()
            return (settings.wallpaper.wallpaper, settings.palette)
        } |> mapToSignal { wallpaper, palette in
            if let cloud = cloud {
                return thumbGenerator(palette, bubbled, wallpaper) |> map { image in
                    return (TransformImageResult(image, true), .cloud(cloud, InstallCloudThemeCachedData(palette: palette, wallpaper: wallpaper, cloudWallpaper: cloud.settings?.wallpaper)))
                }
            } else {
                return thumbGenerator(palette, bubbled, wallpaper) |> map { image in
                    return (TransformImageResult(image, true), .local(palette))
                }
            }
        }
    }
}





func themeInstallSource(context: AccountContext, source: ThemeSource) -> Signal<InstallThemeSource, NoError> {
    
    switch source {
    case let .cloud(cloud):
        if let file = cloud.file {
            return cloudThemeData(context: context, theme: cloud, file: file) |> map { data in
                return .cloud(cloud, InstallCloudThemeCachedData(palette: data.0, wallpaper: data.1, cloudWallpaper: data.2))
            }
        } else {
            return .single(.cloud(cloud, nil))
        }
    case let .local(palette, cloud):
        let settings = themeSettingsView(accountManager: context.sharedContext.accountManager) |> take(1)
        
        return settings |> map { settings -> (Wallpaper, ColorPalette) in
            let settings = settings
                .withUpdatedPalette(palette)
                .withUpdatedCloudTheme(cloud)
                .installDefaultAccent()
                .installDefaultWallpaper()
            return (settings.wallpaper.wallpaper, settings.palette)
        } |> map { wallpaper, palette in
            if let cloud = cloud {
                return .cloud(cloud, InstallCloudThemeCachedData(palette: palette, wallpaper: wallpaper, cloudWallpaper: cloud.settings?.wallpaper))
            } else {
                return .local(palette)
            }
        }
    }
}
