//
//  CheckBox.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 16/02/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa

public class CheckBox: Control {
    private let textView: TextView = TextView()
    private let selectedImage: CGImage
    private let unselectedImage: CGImage
    private let imageView:ImageView = ImageView()
    required public init(frame frameRect: NSRect) {
         fatalError("init(frame:) has not been implemented")
    }
    
    public init(selectedImage: CGImage, unselectedImage: CGImage) {
        self.selectedImage = selectedImage
        self.unselectedImage = unselectedImage
        super.init(frame: NSZeroRect)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.isEventLess = true
        
        addSubview(textView)
        addSubview(imageView)
        isSelected = false
    }
    
    public override var isSelected: Bool {
        didSet {
            imageView.image = isSelected ? selectedImage : unselectedImage
            imageView.sizeToFit()
            needsLayout = true
        }
    }
    
    public override func layout() {
        imageView.centerY(x: 0)
        textView.centerY(x: imageView.frame.maxX + 10)
    }
    
    override public func send(event: ControlEvent) {
        switch event {
        case .Click:
            self.isSelected = !isSelected
        default:
            break
        }
        super.send(event: event)
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(with text: String, maxWidth: CGFloat)  {
        let textLayout = TextViewLayout(.initialize(string: text, color: presentation.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        textLayout.measure(width: maxWidth - (imageView.frame.width + 10))
        textView.update(textLayout)
        needsLayout = true
        setFrameSize(NSMakeSize(textLayout.layoutSize.width + (imageView.frame.width + 10), max(imageView.frame.height, textLayout.layoutSize.height)))
    }
    

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
