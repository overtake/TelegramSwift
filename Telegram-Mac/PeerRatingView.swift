//
//  PeerRatingView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11.07.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import Svg

final class PeerRatingView : Control {
    private let backgroundView = ImageView()
    private let borderView = ImageView()
    
    private var data: TelegramStarRating = .init(level: 0, currentLevelStars: 0, stars: 0, nextLevelStars: 0)
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(borderView)
        addSubview(backgroundView)
        
        self.scaleOnClick = true

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    func toggleState(animated: Bool) {
//        self.state = self.state.toggle()
//        let size = self.set(data: self.data, animated: animated)
//        
//        self.change(size: size, animated: true)
//        self.updateLayout(size: size, transition: .animated(duration: 0.2, curve: .easeOut))
//
//    }
//
    
    var smallSize: NSSize {
        return NSMakeSize(26, 26)
    }
    
    func set(data: TelegramStarRating, context: AccountContext, borderColor: NSColor, bgColor: NSColor, textColor: NSColor, animated: Bool) {
        
        
        let iconSize = smallSize

        
        let levelIndex: Int32
        if data.level <= 10 {
            levelIndex = max(0, data.level)
        } else if data.level <= 90 {
            levelIndex = (data.level / 10) * 10
        } else {
            levelIndex = 90
        }
        let borderImage = generateImage(iconSize, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            if let url = Bundle.main.url(forResource: "profile_level\(levelIndex)_outer", withExtension: "svg"), let data = try? Data(contentsOf: url) {
                let cgImage = drawSvgImage(data, size, nil, nil, 0.0, false)?._cgImage
                if let cgImage, let image = generateTintedImage(image: cgImage, color: borderColor) {
                    context.draw(image, in: CGRect(origin: CGPoint(), size: size))
                }
            }
        })
        
        self.borderView.image = borderImage
        
        let backgroundImage = generateImage(iconSize, rotatedContext: { size, context in
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            if let url = Bundle.main.url(forResource: "profile_level\(levelIndex)_inner", withExtension: "svg"), let data = try? Data(contentsOf: url) {
                let cgImage = drawSvgImage(data, size, nil, nil, 0.0, false)?._cgImage
                if let cgImage, let image = generateTintedImage(image: cgImage, color: bgColor) {
                    context.draw(image, in: CGRect(origin: CGPoint(), size: size))
                }
            }
            
            if textColor.alpha < 1.0 {
                context.setBlendMode(.copy)
            } else {
                context.setBlendMode(.normal)
            }
            
            let attributedText = NSAttributedString.initialize(string: "\(data.level)", color: textColor, font: NSFont.bold(11))
            
            let titleScale: CGFloat
            if data.level < 10 {
                titleScale = 1.0
            } else if data.level < 100 {
                titleScale = 0.8
            } else {
                titleScale = 0.6
            }
            
            let textNode = TextNode.layoutText(attributedText, nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
            
            let textSize = textNode.0.size

            var textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) * 0.5), y: floorToScreenPixels((size.height - textSize.height) * 0.5)), size: textSize)
            textFrame.origin.y += System.pixel

            
            context.saveGState()
            context.translateBy(x: textFrame.midX, y: textFrame.midY)
            context.scaleBy(x: titleScale, y: titleScale)
            context.translateBy(x: -textFrame.midX, y: -textFrame.midY)
            
            textNode.1.draw(textFrame, in: context, backingScaleFactor: System.backingScale, backgroundColor: .clear)

            
            context.restoreGState()
        })
        self.backgroundView.image = backgroundImage

        
        self.data = data
    
        
    }
    
    
    override func layout() {
        super.layout()
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        transition.updateFrame(view: self.borderView, frame: size.bounds)
        transition.updateFrame(view: self.backgroundView, frame: size.bounds)

    }
}
