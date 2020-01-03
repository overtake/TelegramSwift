//
//  AccentColorRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/01/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import TGUIKit

private func generateAccentColor(_ color: PaletteAccentColor, bubbled: Bool) -> CGImage {
    return generateImage(CGSize(width: 42.0, height: 42.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)

        context.setFillColor(color.accent.cgColor)
        context.fillEllipse(in: bounds)
        
        if let messages = color.messages, bubbled {
            let imageSize = CGSize(width: 16, height: 16)
            let image = generateImage(imageSize, contextGenerator: { size, ctx in
                let rect = NSMakeRect(0, 0, size.width, size.height)
                ctx.clear(rect)
                ctx.round(size, size.height / 2)
                let colors = [messages.top, messages.bottom].reversed()
                let gradientColors = colors.map { $0.cgColor } as CFArray
                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                var locations: [CGFloat] = []
                for i in 0 ..< colors.count {
                    locations.append(delta * CGFloat(i))
                }
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: rect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            })!
            
            context.draw(image, in: bounds.focus(imageSize))
        }
    })!
}

private func generateCustomSwatchImage() -> CGImage {
    return generateImage(CGSize(width: 42.0, height: 42.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let dotSize = CGSize(width: 10.0, height: 10.0)
        
        context.setFillColor(NSColor(rgb: 0xd33213).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 14.0, y: 16.0), size: dotSize))
        
        context.setFillColor(NSColor(rgb: 0xf08200).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 14.0, y: 0.0), size: dotSize))
        
        context.setFillColor(NSColor(rgb: 0xedb400).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 28.0, y: 8.0), size: dotSize))
        
        context.setFillColor(NSColor(rgb: 0x70bb23).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 28.0, y: 24.0), size: dotSize))
        
        context.setFillColor(NSColor(rgb: 0x5396fa).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 14.0, y: 32.0), size: dotSize))
        
        context.setFillColor(NSColor(rgb: 0x9472ee).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 24.0), size: dotSize))
        
        context.setFillColor(NSColor(rgb: 0xeb6ca4).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 8.0), size: dotSize))
    })!
}

private func generateSelectedRing(backgroundColor: NSColor) -> CGImage {
    return generateImage(CGSize(width: 32, height: 32), rotatedContext: { size, context in
        context.clear(NSMakeRect(0, 0, size.width, size.height))
        context.setStrokeColor(backgroundColor.cgColor)
        context.setLineWidth(2.0)
        context.strokeEllipse(in: NSMakeRect(1.0, 1.0, size.width - 2.0, size.height - 2.0))
    })!
}


class AccentColorRowItem: GeneralRowItem {
    let selectAccentColor:(AppearanceAccentColor?)->Void
    let menuItems: (AppearanceAccentColor)->[ContextMenuItem]
    let list: [AppearanceAccentColor]
    let isNative: Bool
    let theme: TelegramPresentationTheme
    init(_ initialSize: NSSize, stableId: AnyHashable, list: [AppearanceAccentColor], isNative: Bool, theme: TelegramPresentationTheme, viewType: GeneralViewType = .legacy, selectAccentColor: @escaping(AppearanceAccentColor?)->Void, menuItems: @escaping(AppearanceAccentColor)->[ContextMenuItem]) {
        self.selectAccentColor = selectAccentColor
        self.list = list
        self.theme = theme
        self.isNative = isNative
        self.menuItems = menuItems
        super.init(initialSize, height: 36 + viewType.innerInset.top + viewType.innerInset.bottom, stableId: stableId, viewType: viewType)
    }
    
    
    override func viewClass() -> AnyClass {
        return AccentColorRowView.self
    }
}


private final class AccentScrollView : ScrollView {
    override func scrollWheel(with event: NSEvent) {
        
        var scrollPoint = contentView.bounds.origin
        let isInverted: Bool = System.isScrollInverted
        if event.scrollingDeltaY != 0 {
            if isInverted {
                scrollPoint.x += -event.scrollingDeltaY
            } else {
                scrollPoint.x -= event.scrollingDeltaY
            }
        }
        if event.scrollingDeltaX != 0 {
            if !isInverted {
                scrollPoint.x += -event.scrollingDeltaX
            } else {
                scrollPoint.x -= event.scrollingDeltaX
            }
        }
        if documentView!.frame.width > frame.width {
            scrollPoint.x = min(max(0, scrollPoint.x), documentView!.frame.width - frame.width)
            clipView.scroll(to: scrollPoint)
        } else {
            superview?.scrollWheel(with: event)
        }
    }
}

final class AccentColorRowView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let scrollView: AccentScrollView = AccentScrollView()
    private let borderView:View = View()
    private let documentView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(scrollView)
        scrollView.documentView = documentView
        scrollView.backgroundColor = .clear
        scrollView.background = .clear
        containerView.addSubview(borderView)
        documentView.backgroundColor = .clear
        addSubview(containerView)
    }

    override var backdorColor: NSColor {
        guard let item = item as? AccentColorRowItem else {
            return theme.colors.background
        }
        return item.theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? AccentColorRowItem else {
            return
        }
        self.containerView.backgroundColor = backdorColor
        borderView.backgroundColor = item.theme.colors.border
        self.backgroundColor = item.viewType.rowBackground
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? AccentColorRowItem else {
            return
        }
        
        let innerInset = item.viewType.innerInset
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        self.borderView.frame = NSMakeRect(innerInset.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - innerInset.left - innerInset.right, .borderSize)

        scrollView.frame = NSMakeRect(0, innerInset.top, item.blockWidth, containerView.frame.height - innerInset.top - innerInset.bottom)
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let item = item as? AccentColorRowItem else {
            return nil
        }
        
        let documentPoint = documentView.convert(event.locationInWindow, from: nil)
        
        for (_, subview) in documentView.subviews.enumerated() {
            if NSPointInRect(documentPoint, subview.frame), let accent = (subview as? Button)?.contextObject as? AppearanceAccentColor {
                let items = item.menuItems(accent)
                let menu = ContextMenu()
                menu.items = items
                
                return menu
            }
        }
        
        return nil
    }
    
    private let selectedImageView = ImageView()
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        documentView.removeAllSubviews()
        
        guard let item = item as? AccentColorRowItem else {
            return
        }
        
        self.layout()
        
        selectedImageView.image = generateSelectedRing(backgroundColor: theme.colors.background)
        selectedImageView.setFrameSize(NSMakeSize(32, 32))
        selectedImageView.removeFromSuperview()
        var colorList: [AppearanceAccentColor] = item.list
        
        borderView.isHidden = !item.viewType.hasBorder
        
        let insetWidth: CGFloat = 20
        
        var x: CGFloat = insetWidth
        
       
        if item.isNative {
            let custom = ImageButton(frame: NSMakeRect(x, 0, 36, 36))
            custom.autohighlight = false
            custom.set(image: generateCustomSwatchImage(), for: .Normal)
            custom.setImageContentGravity(.resize)
            custom.set(handler: { _ in
                item.selectAccentColor(nil)
            }, for: .Click)
            documentView.addSubview(custom)
            
            x += custom.frame.width + insetWidth
        }
        
        if !colorList.contains(where: { $0.accent.accent == theme.colors.accent && $0.cloudTheme?.id == theme.cloudTheme?.id }) {
            let button = ImageButton(frame: NSMakeRect(x, 0, 36, 36))
            button.autohighlight = false
            button.layer?.cornerRadius = button.frame.height / 2
            button.set(background: theme.colors.accent, for: .Normal)
            button.addSubview(selectedImageView)
            selectedImageView.center()
            x += button.frame.width + insetWidth
            documentView.addSubview(button)
        }
        
        
        for i in 0 ..< colorList.count {
            let button = ImageButton(frame: NSMakeRect(x, 0, 36, 36))
            button.autohighlight = false
            button.layer?.cornerRadius = button.frame.height / 2
            let icon = generateAccentColor(colorList[i].accent, bubbled: theme.bubbled)
            button.contextObject = colorList[i]
            button.setImageContentGravity(.resize)
            button.set(image: icon, for: .Normal)
            button.set(image: icon, for: .Hover)
            button.set(image: icon, for: .Highlight)
            button.set(handler: { _ in
                item.selectAccentColor(colorList[i])
            }, for: .Click)
            if colorList[i].accent.accent == theme.colors.accent {
                if colorList[i].cloudTheme?.id == theme.cloudTheme?.id {
                    button.addSubview(selectedImageView)
                    selectedImageView.center()
                }
            }
            documentView.addSubview(button)
            x += button.frame.width + insetWidth
            
            if i == colorList.count - 1 {
                x -= insetWidth
            }
        }
        
       
 
        
      
        
        
        documentView.setFrameSize(NSMakeSize(x + insetWidth, frame.height))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
