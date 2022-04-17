//
//  Avatar_BgListView.swift
//  Telegram
//
//  Created by Mike Renoir on 15.04.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import AppKit
import ThemeSettings
import ColorPalette

private final class Avatar_PatternListItem : GeneralRowItem {
    
    struct Item {
        var wallpaper:Wallpaper
        var selected: Bool
        var color: AvatarColor
        var frame: NSRect
    }
    
    let wallpapers: [AvatarColor]
    let context: AccountContext
    let select: (AvatarColor)->Void
    private var __height: CGFloat = 0
    
    private(set) var items:[Item] = []
    
    init(_ initialSize: NSSize, height: CGFloat, wallpapers: [AvatarColor], select:@escaping(AvatarColor)->Void, context: AccountContext, stableId: AnyHashable) {
        self.wallpapers = wallpapers
        self.select = select
        self.context = context
        self.items = wallpapers.map { .init(wallpaper: $0.wallpaper!, selected: $0.selected, color: $0, frame: .zero) }
        super.init(initialSize, height: height, stableId: stableId)
        _ = makeSize(initialSize.width)
    }
    override func viewClass() -> AnyClass {
        return Avatar_PatternListView.self
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        let size = NSMakeSize(100, 100)
        
        let rowCount = ceil((width - 40) / size.width)
        
        let colls = ceil(CGFloat(wallpapers.count) / rowCount)
        
        __height = colls * size.height + (colls * 10)
        
        
        var point: NSPoint = NSMakePoint(20, 0)
        var items = items
        for i in 0 ..< items.count {
            items[i].frame = CGRect(origin: point, size: size)
            point.x += size.width + 10
            if point.x + size.width > width - 20 {
                point.y += size.height + 10
                point.x = 20
            }
        }
        self.items = items
        
        return true
    }
    
    override var height: CGFloat {
        return __height
    }
}

private final class Avatar_PatternListView : TableRowView {
    private let contentView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(contentView)
    }
    
    private class Container : Control {
        let imageView = TransformImageView()
        private var selectedView: View?
        private var select: ((AvatarColor)->Void)?
        private var color: AvatarColor?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            scaleOnClick = true
            set(handler: { [weak self] _ in
                if let color = self?.color {
                    self?.select?(color)
                }
            }, for: .Click)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(pattern: Avatar_PatternListItem.Item, select: @escaping(AvatarColor)->Void, context: AccountContext, animated: Bool) {
            
            self.select = select
            self.color = pattern.color
            
            let emptyColor: TransformImageEmptyColor
            
            let colors = pattern.wallpaper.settings.colors.compactMap { NSColor($0) }
            
            if colors.count > 1 {
                let colors = colors.map {
                    return $0.withAlphaComponent($0.alpha == 0 ? 0.5 : $0.alpha)
                }
                emptyColor = .gradient(colors: colors, intensity: colors.first!.alpha, rotation: nil)
            } else if let color = colors.first {
                emptyColor = .color(color)
            } else {
                emptyColor = .color(NSColor(rgb: 0xd6e2ee, alpha: 0.5))
            }
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: 0), imageSize: pattern.wallpaper.dimensions.aspectFilled(NSMakeSize(300, 300)), boundingSize: pattern.frame.size, intrinsicInsets: NSEdgeInsets(), emptyColor: emptyColor)
            
            imageView.set(arguments: arguments)


            switch pattern.wallpaper {
            case let .file(_, file, _, _):
                var representations:[TelegramMediaImageRepresentation] = []
                if let dimensions = file.dimensions {
                    representations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
                } else {
                    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(pattern.frame.size), resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil))
                }
                
                let updateImageSignal = chatWallpaper(account: context.account, representations: representations, file: file, mode: .thumbnail, isPattern: true, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred: false, synchronousLoad: false, drawPatternOnly: false, palette: dayClassicPalette)
                
                                
                
                imageView.setSignal(signal: cachedMedia(media: file, arguments: arguments, scale: backingScaleFactor), clearInstantly: false)
                 
                 if !imageView.isFullyLoaded {
                     imageView.setSignal(updateImageSignal, animate: true, cacheImage: { result in
                         cacheMedia(result, media: file, arguments: arguments, scale: System.backingScale)
                     })
                 }
                
            default:
                break
            }
            
            if pattern.selected {
                let current: View
                if let view = self.selectedView {
                    current = view
                } else {
                    current = View(frame: frame.insetBy(dx: 2, dy: 2))
                    current.layer?.cornerRadius = current.frame.height / 2
                    self.addSubview(current)
                    self.selectedView = current
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
//                        current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                    }
                }
                current.layer?.borderColor = theme.colors.listBackground.cgColor
                current.layer?.borderWidth = 2
            } else if let view = self.selectedView {
                performSubviewRemoval(view, animated: animated)
                self.selectedView = nil
            }
            
            needsLayout = true
        }
        override func layout() {
            super.layout()
            imageView.frame = bounds
            imageView.layer?.cornerRadius = frame.height / 2
            selectedView?.center()
        }
    }
    
    override func layout() {
        super.layout()
        contentView.frame = bounds
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Avatar_PatternListItem else {
            return
        }
        
        while contentView.subviews.count > item.items.count {
            contentView.subviews.last?.removeFromSuperview()
        }
        while contentView.subviews.count < item.items.count {
            contentView.addSubview(Container(frame: .zero))
        }
        
        for (i, pattern) in item.items.enumerated() {
            let view = contentView.subviews[i] as! Container
            view.frame = pattern.frame
            view.update(pattern: pattern, select: item.select, context: item.context, animated: animated)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class Avatar_BgColorListItem : GeneralRowItem {
    let colors: [AvatarColor]
    let select: (AvatarColor) -> Void
    init(_ initialSize: NSSize, height: CGFloat, colors: [AvatarColor], select: @escaping(AvatarColor)->Void, stableId: AnyHashable) {
        self.colors = colors
        self.select = select
        super.init(initialSize, height: height, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return Avatar_BgColorListView.self
    }
}

private final class Avatar_BgColorListView : TableRowView {
    
    
    private class ColorPreviewView : Control {
        
        private var gradientView: View = View()
        private let imageView = ImageView()
        private var selectedView: View?
        private var color: AvatarColor?
        private var select:((AvatarColor)->Void)?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            scaleOnClick = true
            set(handler: { [weak self] _ in
                if let color = self?.color {
                    self?.select?(color)
                }
            }, for: .Click)
        }
        
        func set(color: AvatarColor, select:@escaping(AvatarColor)->Void, animated: Bool) {
            self.select = select
            self.color = color
            var colors: [NSColor] = []
            switch color.content {
            case let .solid(color):
                colors = [color]
            case let .gradient(c):
                colors = c
            default:
                break
            }
            
            imageView.layer?.contents = generateImage(frame.size, contextGenerator: { size, ctx in
                ctx.clear(size.bounds)
                let imageRect = size.bounds
                if colors.count == 1, let color = colors.first {
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(imageRect)
                } else {
                    let gradientColors = colors.map { $0.cgColor } as CFArray
                    let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                    
                    var locations: [CGFloat] = []
                    for i in 0 ..< colors.count {
                        locations.append(delta * CGFloat(i))
                    }
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                                        
                    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: imageRect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
            })
            
            
            if color.selected {
                let current: View
                if let view = self.selectedView {
                    current = view
                } else {
                    current = View(frame: frame.insetBy(dx: 2, dy: 2))
                    current.layer?.cornerRadius = current.frame.height / 2
                    self.addSubview(current)
                    self.selectedView = current
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
//                        current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                    }
                }
                current.layer?.borderColor = theme.colors.listBackground.cgColor
                current.layer?.borderWidth = 2
            } else if let view = self.selectedView {
                performSubviewRemoval(view, animated: animated)
                self.selectedView = nil
            }
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            imageView.frame = bounds
            selectedView?.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let scrollView = HorizontalScrollView()
    private let documentView = View()
    private let contentView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scrollView)
        documentView.addSubview(contentView)
        documentView.backgroundColor = .clear
        contentView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.background = .clear
        scrollView.documentView = documentView
    }
    
    override func layout() {
        super.layout()
        
        var x: CGFloat = 0
        for view in contentView.subviews {
            view.setFrameOrigin(NSMakePoint(x, 0))
            x += view.frame.width
            x += 10
        }
        
        contentView.frame = NSMakeRect(20, 0, x - 10, frame.height)
        
        documentView.frame = NSMakeSize(x + 40, frame.height).bounds
        scrollView.frame = bounds.insetBy(dx: 0, dy: 0)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Avatar_BgColorListItem else {
            return
        }
        
        while item.colors.count < contentView.subviews.count {
            contentView.subviews.last?.removeFromSuperview()
        }
        while item.colors.count > contentView.subviews.count {
            let view = ColorPreviewView(frame: NSMakeRect(0, 0, item.height, item.height))
            view.layer?.cornerRadius = item.height / 2
            contentView.addSubview(view)
        }
        
        for (i, view) in contentView.subviews.enumerated() {
            let view = view as! ColorPreviewView
            let color = item.colors[i]
            
            view.set(color: color, select: item.select, animated: animated)
        }
        
        layout()
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class Avatar_BgListView : View {
   

    
    private let tableView = TableView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        tableView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "1", backgroundColor: .clear))
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "2", backgroundColor: .clear))
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "3", backgroundColor: .clear))
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "4", backgroundColor: .clear))
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "5", backgroundColor: .clear))
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: "6", backgroundColor: .clear))
    }
    
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
    
    func set(colors: [AvatarColor], context: AccountContext, select: @escaping(AvatarColor)->Void, animated: Bool) {
        tableView.beginTableUpdates()
        
        
        tableView.replace(item: GeneralRowItem(frame.size, height: 20, stableId: "1", backgroundColor: .clear), at: 0, animated: animated)
        
        
        tableView.replace(item: GeneralTextRowItem(frame.size, stableId: "2", text: .initialize(string: "PLAIN GRADIENT", color: theme.colors.listGrayText, font: .normal(12)), inset: NSEdgeInsets(), viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 20, 5, 0))), at: 1, animated: animated)
        
        tableView.replace(item: Avatar_BgColorListItem(frame.size, height: 35, colors: colors.filter { !$0.isWallpaper }, select: select, stableId: "3"), at: 2, animated: animated)
        
        tableView.replace(item: GeneralRowItem(frame.size, height: 20, stableId: "4", backgroundColor: .clear), at: 3, animated: animated)

        tableView.replace(item: GeneralTextRowItem(frame.size, stableId: "5", text: .initialize(string: "GRADIENT WITH PATTERN", color: theme.colors.listGrayText, font: .normal(12)), inset: NSEdgeInsets(), viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 20, 5, 0))), at: 4, animated: animated)

        tableView.replace(item: Avatar_PatternListItem(frame.size, height: 35, wallpapers: colors.filter { $0.isWallpaper }, select: select, context: context, stableId: "6"), at: 5, animated: animated)

        
        tableView.endTableUpdates()
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
