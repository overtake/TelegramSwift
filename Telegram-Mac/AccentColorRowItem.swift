//
//  AccentColorRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/01/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import TGUIKit

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
    let selectAccentColor:(NSColor?)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, selectAccentColor: @escaping(NSColor?)->Void) {
        self.selectAccentColor = selectAccentColor
        super.init(initialSize, height: 50, stableId: stableId)
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
    private let scrollView: AccentScrollView = AccentScrollView()
    private let documentView: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scrollView)
        scrollView.documentView = documentView
        scrollView.backgroundColor = .clear
        scrollView.background = .clear
        
        documentView.backgroundColor = .clear
    }

    
    
    override func layout() {
        super.layout()
        
        guard let item = item as? AccentColorRowItem else {
            return
        }
        scrollView.frame = NSMakeRect(item.inset.left, 0, frame.width - item.inset.left - item.inset.right, frame.height)
    }
    
    private let selectedImageView = ImageView()
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        documentView.removeAllSubviews()
        
        guard let item = item as? AccentColorRowItem else {
            return
        }
        
        scrollView.frame = NSMakeRect(item.inset.left, 0, frame.width - item.inset.left - item.inset.right, frame.height)

        
        selectedImageView.image = generateSelectedRing(backgroundColor: theme.colors.background)
        selectedImageView.sizeToFit()
        selectedImageView.removeFromSuperview()
        let colorList: [NSColor]
        if theme.dark {
            colorList = [
                theme.colors.basicAccent, // blue
                NSColor(0xf83b4c), // red
                NSColor(0xff7519), // orange
                NSColor(0xeba239), // yellow
                NSColor(0x29b327), // green
                NSColor(0x00c2ed), // light blue
                NSColor(0x7748ff), // purple
                NSColor(0xff5da2)  // pink
            ]
        } else {
            colorList = [
                theme.colors.basicAccent,
                NSColor(0xf83b4c), // red
                NSColor(0xff7519), // orange
                NSColor(0xeba239), // yellow
                NSColor(0x29b327), // green
                NSColor(0x00c2ed), // light blue
                NSColor(0x7748ff), // purple
                NSColor(0xff5da2)  // pink
            ]
        }
        
        let addition: Int = 1 + (!colorList.contains(theme.colors.accent) ? 1 : 0)
        
        var insetWidth = ( scrollView.frame.width - (36 * CGFloat(colorList.count + addition)) )
        
        insetWidth = max(min(insetWidth / CGFloat(colorList.count - 1 + addition), 15), 15)
        
        var x: CGFloat = 0
        
        for i in 0 ..< colorList.count {
            let button = ImageButton(frame: NSMakeRect(x, 10, 36, 36))
            button.autohighlight = false
            button.layer?.cornerRadius = button.frame.height / 2
            button.set(background: colorList[i], for: .Normal)
            button.set(background: colorList[i], for: .Hover)
            button.set(background: colorList[i], for: .Highlight)
            button.set(handler: { _ in
                item.selectAccentColor(colorList[i])
            }, for: .Click)
            if colorList[i].hexString == theme.colors.accent.hexString {
                button.addSubview(selectedImageView)
                selectedImageView.center()
            }
            documentView.addSubview(button)
            x += button.frame.width + insetWidth
        }
        
       
        if !colorList.contains(theme.colors.accent) {
            let button = ImageButton(frame: NSMakeRect(x, 10, 36, 36))
            button.autohighlight = false
            button.layer?.cornerRadius = button.frame.height / 2
            button.set(background: theme.colors.accent, for: .Normal)
            button.addSubview(selectedImageView)
            selectedImageView.center()
            x += button.frame.width + insetWidth
            documentView.addSubview(button)
        }
        
        let custom = ImageButton(frame: NSMakeRect(x, 10, 36, 36))
        custom.autohighlight = false
        custom.set(image: generateCustomSwatchImage(), for: .Normal)
        custom.setImageContentGravity(.resize)
        custom.set(handler: { _ in
            item.selectAccentColor(nil)
        }, for: .Click)
        documentView.addSubview(custom)
        
        x += custom.frame.width
        
        documentView.setFrameSize(NSMakeSize(x, frame.height))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
