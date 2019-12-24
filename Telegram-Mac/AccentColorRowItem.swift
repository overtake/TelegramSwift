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
        
        if let bubble = color.bubble, bubbled {
            context.setFillColor(bubble.cgColor)
            context.fillEllipse(in: bounds.focus(NSMakeSize(16, 16)))
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
    let selectAccentColor:(PaletteAccentColor?)->Void
    let list: [PaletteAccentColor]
    let isNative: Bool
    let theme: TelegramPresentationTheme
    init(_ initialSize: NSSize, stableId: AnyHashable, list: [PaletteAccentColor], isNative: Bool, theme: TelegramPresentationTheme, viewType: GeneralViewType = .legacy, selectAccentColor: @escaping(PaletteAccentColor?)->Void) {
        self.selectAccentColor = selectAccentColor
        self.list = list
        self.theme = theme
        self.isNative = isNative
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
        let colorList: [PaletteAccentColor] = item.list
        
        borderView.isHidden = !item.viewType.hasBorder
        
        let insetWidth: CGFloat = 20
        
        var x: CGFloat = insetWidth
        
        for i in 0 ..< colorList.count {
            let button = ImageButton(frame: NSMakeRect(x, 0, 36, 36))
            button.autohighlight = false
            button.layer?.cornerRadius = button.frame.height / 2
            let icon = generateAccentColor(colorList[i], bubbled: theme.bubbled)
            button.set(image: icon, for: .Normal)
            button.set(image: icon, for: .Hover)
            button.set(image: icon, for: .Highlight)
            button.set(handler: { _ in
                item.selectAccentColor(colorList[i])
            }, for: .Click)
            if colorList[i].accent == theme.colors.accent {
                button.addSubview(selectedImageView)
                selectedImageView.center()
            }
            documentView.addSubview(button)
            x += button.frame.width + insetWidth
        }
        
       
        if !colorList.contains(where: { $0.accent == theme.colors.accent }) {
            let button = ImageButton(frame: NSMakeRect(x, 0, 36, 36))
            button.autohighlight = false
            button.layer?.cornerRadius = button.frame.height / 2
            button.set(background: theme.colors.accent, for: .Normal)
            button.addSubview(selectedImageView)
            selectedImageView.center()
            x += button.frame.width + insetWidth
            documentView.addSubview(button)
        }
        if item.isNative {
            let custom = ImageButton(frame: NSMakeRect(x, 0, 36, 36))
            custom.autohighlight = false
            custom.set(image: generateCustomSwatchImage(), for: .Normal)
            custom.setImageContentGravity(.resize)
            custom.set(handler: { _ in
                item.selectAccentColor(nil)
            }, for: .Click)
            documentView.addSubview(custom)
            
            x += custom.frame.width
        }
       
        
        documentView.setFrameSize(NSMakeSize(x + insetWidth, frame.height))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
