//
//  DockIconRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24.01.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Dock
import TelegramCore
import SwiftSignalKit
import Postbox


struct DockIconData {
    let icon: TelegramApplicationIcons.Icon
    let selected: Bool
    let frame: NSRect

}

private let dockPremiumIcon = generateImage(NSMakeSize(24, 24), contextGenerator: { size, ctx in
    ctx.clear(size.bounds)
    
        
    let path = CGMutablePath()
    path.addRoundedRect(in: size.bounds, cornerWidth: size.width / 2, cornerHeight: size.height / 2)
    ctx.addPath(path)
    ctx.clip()
    
    let colors = [NSColor(hexString: "#1391FF")!, NSColor(hexString: "#F977CC")!].map { $0.cgColor } as NSArray
    let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
    
    var locations: [CGFloat] = []
    for i in 0 ..< colors.count {
        locations.append(delta * CGFloat(i))
    }

    let colorSpace = deviceColorSpace
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
    
    ctx.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    
    let image = generateLockPremium(theme.colors)

    ctx.draw(image, in: size.bounds.focus(image.backingSize))
    
    
})!




private func createNSImage(fromIcnsFile filePath: String, withSize size: NSSize) -> NSImage? {
    guard let iconFile = NSImage(contentsOfFile: filePath) else {
        print("Failed to load .icns file")
        return nil
    }

    // Create a representation from the icns file for the specific size
    guard let representation = iconFile.bestRepresentation(for: NSRect(x: 0, y: 0, width: size.width, height: size.height), context: nil, hints: nil) else {
        print("Failed to get representation for the specified size")
        return nil
    }

    // Create a new NSImage with the specific size
    let image = NSImage(size: size)
    image.addRepresentation(representation)

    return image
}



final class DockIconRowItem: GeneralRowItem {
    private(set) var wallpaperImage: CGImage?
    let icons: [DockIconData]
    let context: AccountContext
    let callback: (TelegramApplicationIcons.Icon)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, context: AccountContext, dockIcons: TelegramApplicationIcons, selected: String?, action: @escaping(TelegramApplicationIcons.Icon)->Void) {
        self.context = context
        self.callback = action
        var icons: [DockIconData] = []
        var frame: CGRect = CGRect(origin: CGPointMake(20, 20), size: DockIconRowItem.iconSize)
        for (i, icon) in dockIcons.icons.enumerated() {
            icons.append(DockIconData(icon: icon, selected: selected == icon.file.fileName || (icon.file.fileName == TelegramApplicationIcons.Icon.defaultIconName && selected == nil), frame: frame))
            frame.origin.x += DockIconRowItem.iconSize.width
            if (i + 1) % Int(DockIconRowItem.rowCount) == 0 {
                frame.origin.y += DockIconRowItem.iconSize.height
                frame.origin.x = 20
            }
        }
        
        self.icons = icons
        
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        let workspace = NSWorkspace.shared
        if let screen = NSScreen.main, let wallpaperURL = workspace.desktopImageURL(for: screen), let image = NSImage(contentsOf: wallpaperURL)?._cgImage {
            self.wallpaperImage = generateImage(NSMakeSize(blockWidth, height), contextGenerator: { size, ctx in
                ctx.draw(image, in: size.bounds.focus(image.backingSize), byTiling: false)
            })
        } else {
            self.wallpaperImage = nil
        }
    }
    
    override func viewClass() -> AnyClass {
        return DockIconRowView.self
    }
    
    var containerSize: NSSize {
        return NSMakeSize(DockIconRowItem.rowCount * DockIconRowItem.iconSize.width + 40, ceil(CGFloat(icons.count) / DockIconRowItem.rowCount) * DockIconRowItem.iconSize.height + 30)
    }
    
    static var iconSize: NSSize {
        return NSMakeSize(60, 70)
    }
    static var rowCount: CGFloat {
        return 4.0
    }
    
    override var height: CGFloat {
        var height: CGFloat = 20
        
        height += containerSize.height
        
        height += 20
        return height
    }
}

private final class DockIconView : Control {
    
    
    private class Indicator : View {
        private let loading = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            backgroundColor = NSColor.black.withAlphaComponent(0.2)
            self.layer?.cornerRadius = 10
            addSubview(loading)
            loading.progressColor = NSColor.white.withAlphaComponent(0.6)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            loading.center()
        }
    }
    
    
    private let content = SimpleLayer()
    private let selected = SimpleLayer()
    
    private var locker: SimpleLayer?
    
    private var item: DockIconData?
    private weak var rowItem: DockIconRowItem?
    private var loading: Indicator?
    
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        scaleOnClick = true
        content.frame = NSMakeRect(0, 0, 60, 60)
        self.layer?.addSublayer(content)
        self.layer?.addSublayer(selected)
        
        
        selected.frame = NSMakeRect(0, 0, 4, 4)
        selected.cornerRadius = selected.frame.height / 2.0
        selected.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        
        set(handler: { [weak self] _ in
            if let rowItem = self?.rowItem, let item = self?.item {
                rowItem.callback(item.icon)
            }
        }, for: .Click)
        
        self.layer?.masksToBounds = false
    }
    
    override func layout() {
        super.layout()
        self.selected.frame = CGRect(origin: NSMakePoint((frame.width - selected.frame.width) / 2, content.frame.maxY), size: selected.frame.size)
    }
    
    func set(item: DockIconData, rowItem: DockIconRowItem, context: AccountContext, animated: Bool) {
       
        if self.item?.icon != item.icon {
            self.content.contents = nil
        }
        self.item = item
        self.rowItem = rowItem
        
        let signal = context.account.postbox.mediaBox.resourceStatus(item.icon.file.resource, approximateSynchronousValue: true) |> deliverOnMainQueue
        
        
        statusDisposable.set(signal.start(next: { [weak self] status in
            self?.updateItem(item, context: context, status: status)
        }))
        
        fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .media(media: AnyMediaReference.message(message: item.icon.reference, media: item.icon.file), resource: item.icon.file.resource)).start())
        
        if !context.isPremium, item.icon.isPremium {
            let current: SimpleLayer
            if let layer = self.locker {
                current = layer
            } else {
                current = SimpleLayer()
                self.layer?.addSublayer(current)
                self.locker = current
            }
            let image = dockPremiumIcon
            current.contents = image
            current.frame = CGRect(origin: NSMakePoint(content.frame.maxX - image.backingSize.width, content.frame.minY), size: image.backingSize)
        } else if let locker = locker {
            performSublayerRemoval(locker, animated: animated)
            self.locker = nil
        }
        self.selected.isHidden = self.locker != nil
    }
    
    deinit {
        fetchDisposable.dispose()
        statusDisposable.dispose()
    }
    
    private func updateItem(_ item: DockIconData, context: AccountContext, status: MediaResourceStatus) {
        let progress: Float?
        switch status {
        case let .Fetching(_, value):
            progress = value
        case .Local:
            progress = nil
        default:
            progress = 0
        }
        
        if let _ = progress {
            let current: Indicator
            if let view = self.loading {
                current = view
            } else {
                current = Indicator(frame: NSMakeRect(5, 5, 50, 50))
                self.loading = current
                addSubview(current)
            }
        } else if let view = loading {
            performSubviewRemoval(view, animated: true)
            self.loading = nil
        }
        
        self.userInteractionEnabled = progress == nil
        
        self.selected.opacity = item.selected ? 1.0 : 0.0
        self.selected.animateOpacity()
        

        
        if progress == nil {
            let signal: Signal<CGImage?, NoError> = Signal { subscriber in
                let image = createNSImage(fromIcnsFile: context.account.postbox.mediaBox.resourcePath(item.icon.file.resource), withSize: NSMakeSize(60, 60))?._cgImage
                subscriber.putNext(image)
                subscriber.putCompletion()
                return EmptyDisposable
            } 
            |> runOn(.concurrentDefaultQueue())
            |> deliverOnMainQueue
            
            if self.content.contents == nil {
                _ = signal.startStandalone(next: { [weak self] image in
                    self?.content.contents = image
                    self?.content.animateContents()
                })
            }
        } else {
            self.content.contents = nil
            self.selected.opacity = 0
            self.content.animateContents()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class Container : NSVisualEffectView {
    override var isFlipped: Bool {
        return true
    }
}

private final class DockIconRowView : GeneralContainableRowView {
    private let backgroundView = BackgroundView(frame: .zero)
    private let visualEffect = Container()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(visualEffect)
        
        visualEffect.wantsLayer = true
        visualEffect.state = .active
        visualEffect.blendingMode = .withinWindow
        visualEffect.autoresizingMask = []
        visualEffect.material = .light
        
        visualEffect.layer?.cornerRadius = 10
        visualEffect.layer?.borderWidth = 1
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? DockIconRowItem else {
            return
        }
        backgroundView.frame = containerView.bounds
        visualEffect.frame = containerView.focus(item.containerSize)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? DockIconRowItem else {
            return
        }
        
        while visualEffect.subviews.count > item.icons.count {
            visualEffect.subviews.last?.removeFromSuperview()
        }
        while visualEffect.subviews.count < item.icons.count {
            let iconView = DockIconView(frame: DockIconRowItem.iconSize.bounds)
            visualEffect.addSubview(iconView)
        }
        
        for (i, icon) in item.icons.enumerated() {
            let view = visualEffect.subviews[i] as! DockIconView
            view.set(item: icon, rowItem: item, context: item.context, animated: animated)
            view.frame = icon.frame
        }
        
        backgroundView.backgroundMode = theme.backgroundMode
        
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        

    }
}
