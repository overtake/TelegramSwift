//
//  SoftwareGradientBackgroundItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class SoftwareGradientBackgroundItem : GeneralRowItem {
    init(_ initialSize: NSSize, _ stableId: AnyHashable) {
        super.init(initialSize, height: 300, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return SoftwareGradientBackgroundView.self
    }
}


private final class SoftwareGradientBackgroundView: TableRowView {
    private let view: GradientBackgroundView
    required init(frame frameRect: NSRect) {
        view = GradientBackgroundView(colors: nil, useSharedAnimationPhase: true)
        super.init(frame: frameRect)
        addSubview(view)
    }
    
    override func layout() {
        super.layout()
        view.frame = bounds
        view.updateLayout(size: bounds.size, transition: .immediate)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        view.animateEvent(transition: .animated(duration: 0.5, curve: .spring))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
