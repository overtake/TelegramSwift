//
//  ExpCardButton.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class ExpCardButton: Button {
    private let textView = TextView()
    private let image = ImageView()
    private var text: String = ""
    private let view = View()
    override init() {
        super.init(frame: .zero)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    private func setup() {
        view.addSubview(textView)
        view.addSubview(image)
        addSubview(view)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        scaleOnClick = true
    }
    

    func update(_ isSelected: Bool, icon: CGImage, text: String) {
        self.text = text
        
        let color = isSelected ? theme.colors.accent : theme.colors.text

        let textLayout = TextViewLayout(.initialize(string: text, color: color, font: .medium(.short)))
        textLayout.measure(width: .greatestFiniteMagnitude)
        textView.update(textLayout)

        self.isSelected = isSelected
        layer?.borderColor = isSelected ? theme.colors.accent.cgColor : theme.colors.grayText.withAlphaComponent(0.6).cgColor
        layer?.borderWidth = isSelected ? 1.66 : 1
        
        image.image = icon
        image.sizeToFit()

    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
    }
    
    override func layout() {
        super.layout()
        
        view.setFrameSize(NSMakeSize(image.frame.width + 4 + textView.frame.width, frame.height))
        image.centerY(x: 0)
        layer?.cornerRadius = frame.height / 2
        textView.centerY(x: image.frame.maxX + 4, addition: -1)
        
        view.center()
    }
    
    func size() -> CGSize {
        return NSMakeSize(textView.frame.width + 20 + image.frame.width + 4, 30)
    }
}
