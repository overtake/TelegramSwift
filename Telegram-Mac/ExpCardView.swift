//
//  ExpCardView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


struct ExpCardData {
    struct Button {
        var text: ()->String
        var selected: ()->Bool
        var image: ()->CGImage
        var click:()->Void
    }
    
    var title: ()->String
    var desc: ()->String
    var descClick:()->Void
    var buttons:[Button]
    
}

final class ExpCardView<T> : View  where T:View {
        
    private let titleView = TextView()
    private let descView = TextView()

    
    var dataView: T? {
        didSet {
            oldValue?.removeFromSuperview()
            if let dataView = self.dataView {
                addSubview(dataView)
            }
            layout()
        }
    }
    private let buttonsView = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(buttonsView)
        addSubview(descView)
        
        layer?.cornerRadius = 20
        
        layer?.borderWidth = 1
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        descView.userInteractionEnabled = true
        descView.isSelectable = false
    }
    
    fileprivate var data: ExpCardData?
    func update(_ data: ExpCardData) {
        self.data = data
        
        buttonsView.removeAllSubviews()
        for data in data.buttons {
            let button = ExpCardButton()
            buttonsView.addSubview(button)
            button.set(handler: { _ in
                data.click()
            }, for: .Click)
        }
        updateLocalizationAndTheme(theme: theme)
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        let theme = theme as! TelegramPresentationTheme
        
        self.backgroundColor = theme.colors.background
        
        if theme.bubbled {
            switch theme.backgroundMode {
            case .background, .tiled, .gradient:
                layer?.borderColor = .clear
            case .plain:
                if theme.colors.chatBackground == theme.colors.background {
                    layer?.borderColor = theme.colors.grayIcon.withAlphaComponent(0.6).cgColor
                } else {
                    layer?.borderColor = .clear
                }
            case let .color(color):
                if color == theme.colors.background {
                    layer?.borderColor = theme.colors.grayIcon.withAlphaComponent(0.6).cgColor
                } else {
                    layer?.borderColor = .clear
                }
            }
        } else {
            if theme.colors.chatBackground == theme.colors.background {
                layer?.borderColor = theme.colors.grayIcon.withAlphaComponent(0.6).cgColor
            } else {
                layer?.borderColor = .clear
            }
        }
       

        guard let data = self.data else {
            return
        }
        
        for (i, buttonData) in data.buttons.enumerated() {
            let button = self.buttonsView.subviews[i] as! ExpCardButton
            button.update(buttonData.selected(), icon: buttonData.image(), text: buttonData.text())
        }
        
        let descAttr = parseMarkdownIntoAttributedString(data.desc(), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.grayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.grayText), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  {_ in}))
        }))
        
        let descLayout = TextViewLayout(descAttr, alignment: .center)
        
        descLayout.interactions = TextViewInteractions(processURL:{ _ in
            data.descClick()
        })
        
        descLayout.measure(width: frame.width - 30)

        descView.update(descLayout)

        let titleLayout = TextViewLayout(.initialize(string: data.title(), color: theme.colors.text, font: .medium(.text)))
        titleLayout.measure(width: frame.width - 30)
        titleView.update(titleLayout)
    }
    
    override func layout() {
        super.layout()
        
        titleView.centerX(y: 18)

        if buttonsView.subviews.isEmpty {
            dataView?.frame = NSMakeRect(15, 53, frame.width - 30, 144 + 50)
        } else {
            dataView?.frame = NSMakeRect(15, 103, frame.width - 30, 144)
        }
        
        buttonsView.frame = NSMakeRect(15, 53, frame.width - 30, 30)

        let buttonsCount = CGFloat(buttonsView.subviews.count)
        let bestSize = (buttonsView.frame.width - 10 * (buttonsCount - 1)) / buttonsCount
        
        for (i, button) in buttonsView.subviews.enumerated() {
            let index: CGFloat = CGFloat(i)
            button.frame = NSMakeRect(index * bestSize + 10 * index, 0, bestSize, 30)
        }
        descView.centerX(y: frame.height - descView.frame.height - 20)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
