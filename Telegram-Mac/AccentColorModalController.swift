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
import PostboxMac

fileprivate final class SelectAccentColorView : View {
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    func update(_ colors: [NSColor], selected: NSColor, callback: @escaping(NSColor)->Void) -> Void {
        var x: CGFloat = 20
        var y: CGFloat = 20
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
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AccentColorModalController: ModalViewController {

    fileprivate let current: NSColor
    fileprivate let context: AccountContext

    
    
    init(_ context: AccountContext, current: NSColor) {
        self.context = context
        self.current = current
        
        super.init(frame: NSMakeRect(0, 0, 40 * 4 + 20 * 5, 40 * 2 + 20 * 3))
        bar = .init(height: 0)
    }
    
    private var genericView: SelectAccentColorView {
        return self.view as! SelectAccentColorView
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: nil, center: ModalHeaderData(title: L10n.generalSettingsAccentColor), right: ModalHeaderData(image: theme.icons.modalClose, handler: {
            
        }))
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        
        self.modal?.resize(with: NSMakeSize(self.frame.width, self.frame.height), animated: false)
        
        var colorList: [NSColor]
        if theme.dark {
            colorList = [
                NSColor(0xf83b4c).darker(amount: 0.23), // red
                NSColor(0xff7519).darker(amount: 0.23), // orange
                NSColor(0xeba239).darker(amount: 0.23), // yellow
                NSColor(0x29b327).darker(amount: 0.23), // green
                NSColor(0x00c2ed).darker(amount: 0.23), // light blue
                theme.colors.basicAccent, // blue
                NSColor(0x7748ff).darker(amount: 0.23), // purple
                NSColor(0xff5da2).darker(amount: 0.23)  // pink
            ]
        } else {
            colorList = [
                NSColor(0xf83b4c), // red
                NSColor(0xff7519), // orange
                NSColor(0xeba239), // yellow
                NSColor(0x29b327), // green
                NSColor(0x00c2ed), // light blue
                theme.colors.basicAccent, // blue
                NSColor(0x7748ff), // purple
                NSColor(0xff5da2)  // pink
            ]
        }
        
        genericView.update(colorList, selected: current, callback: { [weak self] color in
            _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                if color == theme.colors.basicAccent {
                    return settings.withUpdatedPalette(theme.colors.withoutAccentColor())
                } else {
                    return settings.withUpdatedPalette(theme.colors.withAccentColor(color))
                }
            }).start()
            delay(0.2, closure: {
                self?.close()
            })
        })
        readyOnce()
    }
    
    override func viewClass() -> AnyClass {
        return SelectAccentColorView.self
    }
    
}
