//
//  AccentColorModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/01/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

fileprivate final class SelectAccentColorView : View {
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    func update(_ colors: [NSColor], selected: NSColor, callback: @escaping(NSColor)->Void) -> Void {
        var x: CGFloat = 20
        var y: CGFloat = 70
        for i in 0 ..< colors.count {
            let button = ImageButton(frame: NSMakeRect(x, y, 40, 40))
            button.autohighlight = false
            button.layer?.cornerRadius = 20
            button.set(background: colors[i], for: .Normal)
            button.set(background: colors[i], for: .Hover)
            button.set(background: colors[i], for: .Highlight)
            button.set(handler: { _ in
                callback(colors[i])
            }, for: .Click)
            if colors[i].hexString == selected.hexString {
                button.set(image: theme.icons.accentColorSelect, for: .Normal)
            }
            addSubview(button)
            x += 60
            if (i + 1) % 4 == 0 {
                y += 60
                x = 20
            }
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        let textNode = TextNode.layoutText(NSAttributedString.initialize(string: tr(L10n.generalSettingsAccentColor), color: theme.colors.text, font: .normal(.text)), theme.colors.background, 1, .end, NSMakeSize(frame.width - 40, 20), nil, false, .center)
        
        let point = NSMakePoint(floorToScreenPixels(scaleFactor: backingScaleFactor, (frame.width - textNode.0.size.width)/2), floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - textNode.0.size.height)/2))
        textNode.1.draw(NSMakeRect(point.x, point.y, textNode.0.size.width, textNode.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(0, 50, frame.width, .borderSize))
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AccentColorModalController: ModalViewController {

    fileprivate let current: NSColor
    fileprivate let account: Account

    
    private let colorList: [NSColor] = [
        NSColor(0xf83b4c), // red
        NSColor(0xff7519), // orange
        NSColor(0xeba239), // yellow
        NSColor(0x29b327), // green
        NSColor(0x00c2ed), // light blue
        NSColor(0x2481cc), // blue
        NSColor(0x7748ff), // purple
        NSColor(0xff5da2)  // pink
    ]
    
    init(_ account: Account, current: NSColor) {
        self.account = account
        self.current = current
        
        super.init(frame: NSMakeRect(0, 0, 40 * 4 + 20 * 5, 40 * 2 + 50 + 20 * 3))
        bar = .init(height: 0)
    }
    
    private var genericView: SelectAccentColorView {
        return self.view as! SelectAccentColorView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let postbox = self.account.postbox
        
        genericView.update(colorList, selected: current, callback: { [weak self] color in
            if color == whitePalette.blueUI {
                _ = updateThemeSettings(postbox: postbox, palette: whitePalette).start()
            } else {
                _ = updateThemeSettings(postbox: postbox, palette: whitePalette.withAccentColor(color)).start()    
            }
            delay(0.3, closure: {
                self?.close()
            })
        })
        readyOnce()
    }
    
    override func viewClass() -> AnyClass {
        return SelectAccentColorView.self
    }
    
}
