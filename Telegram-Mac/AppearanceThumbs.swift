//
//  AppearanceThumbs.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import TGUIKit
import SwiftSignalKit
import Postbox

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
                    backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
                case let.color(color):
                    backgroundMode = .color(color: NSColor(argb: color).withAlphaComponent(1.0))
                case let .gradient(top, bottom, rotation):
                    backgroundMode = .gradient(top: NSColor(argb: top).withAlphaComponent(1.0), bottom: NSColor(argb: bottom).withAlphaComponent(1.0), rotation: rotation)
                case let .image(representation, settings):
                    if let resource = largestImageRepresentation(representation)?.resource, let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(resource, settings: settings))) {
                        backgroundMode = .background(image: image)
                    } else {
                        backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
                    }
                    
                case let .file(_, file, settings, isPattern):
                    if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(file.resource, settings: settings))) {
                        backgroundMode = .background(image: image)
                    } else {
                        backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
                    }
                case .none:
                    backgroundMode = .color(color: palette.chatBackground)
                case let .custom(representation, blurred):
                    if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(representation.resource, settings: WallpaperSettings(blur: blurred)))) {
                        backgroundMode = .background(image: image)
                    } else {
                        backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
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
                if let outgoing = bubbleImage?.precomposed(palette.bubbleBackgroundTop_outgoing, bottomColor: palette.bubbleBackgroundBottom_outgoing, flipVertical: true, flipHorizontal: true) {
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
            
            switch backgroundMode {
            case let .background(image):
                let imageSize = image.size.aspectFilled(NSMakeSize(300, 300))
                ctx.saveGState()
                ctx.translateBy(x: 1, y: -1)
                ctx.draw(image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: rect.focus(imageSize))
                ctx.restoreGState()
                applyBubbles()
            case let .color(color):
                if bubbled {
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(rect)
                    applyBubbles()
                } else {
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(rect)
                    applyPlain()
                }
            case let .gradient(values):
                if bubbled {
                    let colors = [values.top, values.bottom].reversed()
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
                    ctx.rotate(by: CGFloat(values.rotation ?? 0) * CGFloat.pi / -180.0)
                    ctx.translateBy(x: -rect.width / 2.0, y: -rect.height / 2.0)
                    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: rect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                    ctx.restoreGState()
                    applyBubbles()
                } else {
                    applyPlain()
                }
                
            default:
                break
            }
            
        })!
        
        subscriber.putNext(image)
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}

func themeAppearanceThumbAndData(context: AccountContext, bubbled: Bool, source: ThemeSource) -> Signal<(TransformImageResult, InstallThemeSource), NoError> {
    
    switch source {
    case let .cloud(cloud):
        if let file = cloud.file {
            return cloudThemeData(context: context, theme: cloud, file: file) |> mapToSignal { data in
                return generateThumb(palette: data.0, bubbled: bubbled, wallpaper: data.1) |> map { image in
                    return (TransformImageResult(image, true), .cloud(cloud, InstallCloudThemeCachedData(palette: data.0, wallpaper: data.1, cloudWallpaper: data.2)))
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
                return generateThumb(palette: palette, bubbled: bubbled, wallpaper: wallpaper) |> map { image in
                    return (TransformImageResult(image, true), .cloud(cloud, InstallCloudThemeCachedData(palette: palette, wallpaper: wallpaper, cloudWallpaper: cloud.settings?.wallpaper)))
                }
            } else {
                return generateThumb(palette: palette, bubbled: bubbled, wallpaper: wallpaper) |> map { image in
                    return (TransformImageResult(image, true), .local(palette))
                }
            }
        }
    }
}


