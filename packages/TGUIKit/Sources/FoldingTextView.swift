//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 24.05.2024.
//

import Foundation


public struct FoldingTextLayout {
    public var blocks:[TextViewLayout]
    public var revealed: Set<Int>
}

public class FoldingTextView : View {
    
    public var revealBlockAtIndex:((Int))? = nil
    
    private var layous: FoldingTextLayout?
    
    public var isSelectable: Bool = true {
        didSet {
            self.updateLayouts()
        }
    }
    
    public override var userInteractionEnabled: Bool {
        didSet {
            self.updateLayouts()
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(layout: FoldingTextLayout, animated: Bool) {
        self.layous = layout
        
        while self.subviews.count > layout.blocks.count {
            self.subviews.last?.removeFromSuperview()
        }
        while self.subviews.count < layout.blocks.count {
            self.subviews.append(TextView())
        }
        for (i, textLayout) in layout.blocks.enumerated() {
            let view = self.subviews[i] as! TextView
            view.update(textLayout)
            view.userInteractionEnabled = userInteractionEnabled
            view.isSelectable = isSelectable
        }
    }
    private func updateLayouts() {
        for subview in subviews {
            let view = subview as! TextView
            view.userInteractionEnabled = userInteractionEnabled
            view.isSelectable = isSelectable
        }
    }
    
}
