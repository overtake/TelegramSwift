//
//  ChartVisibilityItemView.swift
//  Graph
//
//  Created by Mikhail Filimonov on 24.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore

class ChartVisibilityItemView: View {
    static let textFont = NSFont.systemFont(ofSize: 14, weight: .medium)
    
    let checkButton: TitleButton = TitleButton()
    
    required init(frame: CGRect) {
        super.init(frame: frame)
        
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    func setupView() {
        checkButton._thatFit = true
        checkButton.frame = bounds
        checkButton.set(font: ChartVisibilityItemView.textFont, for: .Normal)
        checkButton.layer?.cornerRadius = 6
        checkButton.layer?.masksToBounds = true
        checkButton.set(handler: { [weak self] _ in
            self?.didTapButton()
        }, for: .Click)
        addSubview(checkButton)
    }
    
    var tapClosure: (() -> Void)?
    var longTapClosure: (() -> Void)?
    
    private func updateStyle(animated: Bool) {
        guard let item = item else {
            return
        }
        View.perform(animated: animated, animations: {
            if self.isChecked {
                self.checkButton.set(color: .white, for: .Normal)
                self.checkButton.backgroundColor = item.color
                self.checkButton.layer?.borderColor = nil
                self.checkButton.layer?.borderWidth = 0
                self.checkButton.set(text: "✓ " + item.title, for: .Normal)
            } else {
                self.checkButton.backgroundColor = .clear
                self.checkButton.layer?.borderColor = item.color.cgColor
                self.checkButton.layer?.borderWidth = 1
                self.checkButton.set(color: item.color, for: .Normal)
                self.checkButton.set(text: item.title, for: .Normal)
            }
            
        })
    }
    
    override func layout() {
        super.layout()
        
        checkButton.frame = bounds
    }
    
    @objc private func didTapButton() {
        tapClosure?()
    }
    
    @objc private func didRecognizedLongPress(recognizer: NSGestureRecognizer) {
        if recognizer.state == .began {
            longTapClosure?()
        }
    }
    
    var item: ChartVisibilityItem? = nil {
        didSet {
            updateStyle(animated: false)
        }
    }
    
    private(set) var isChecked: Bool = true
    func setChecked(isChecked: Bool, animated: Bool) {
        self.isChecked = isChecked
        updateStyle(animated: true)
    }
}
