//
//  WallpaperAdditionColorView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class WallpaperAdditionColorView : View, TGModernGrowingDelegate {
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
    }
    
    func textViewEnterPressed(_ event: NSEvent) -> Bool {
        return true
    }
    
    func textViewTextDidChange(_ string: String) {
        var filtered = String(string.unicodeScalars.filter {CharacterSet(charactersIn: "#0123456789abcdefABCDEF").contains($0)}).uppercased()
        if string != filtered {
            if filtered.isEmpty {
                filtered = "#"
            } else if filtered.first != "#" {
                filtered = "#" + filtered
            }
            textView.setString(filtered)
        }
        if filtered.length == maxCharactersLimit(textView) {
            let color = NSColor(hexString: filtered)
            if let color = color, !ignoreUpdate {
                colorChanged?(color)
            }
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        background = theme.colors.background
        textView.background = theme.colors.background
        textView.textColor = theme.colors.text
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        
        let text = pasteboard.string(forType: .string)
        if let text = text, let color = NSColor(hexString: text) {
            defaultColor = color
        }
        return true
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        return textView.frame.size
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        return 7
    }
    
    private var ignoreUpdate: Bool = false
    
    var defaultColor: NSColor = NSColor(hexString: "#FFFFFF")! {
        didSet {
            ignoreUpdate = true
            textView.setString(defaultColor.hexString)
            ignoreUpdate = false
        }
    }
    
    var colorChanged: ((NSColor) -> Void)? = nil
    var resetClick:(()->Void)? = nil
    fileprivate let resetButton = ImageButton()

    let textView: TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect, unscrollable: true)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        
        
        layer?.cornerRadius = frameRect.height / 2
        layer?.borderWidth = .borderSize
        layer?.borderColor = theme.colors.border.cgColor
        textView.delegate = self
        textView.setString("#")
        textView.textFont = .normal(.text)
        backgroundColor = theme.colors.background
        textView.cursorColor = theme.colors.indicatorColor
        resetButton.set(image: theme.icons.wallpaper_color_close, for: .Normal)
        _ = resetButton.sizeToFit()
        addSubview(resetButton)
        
        textView.setBackgroundColor(theme.colors.background)
        
        resetButton.set(handler: { [weak self] _ in
            self?.resetClick?()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: textView, frame: NSMakeRect(6, 0, frame.width - resetButton.frame.width - 15, frame.height))
        transition.updateFrame(view: resetButton, frame: resetButton.centerFrameY(x: frame.width - resetButton.frame.width - 5))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
