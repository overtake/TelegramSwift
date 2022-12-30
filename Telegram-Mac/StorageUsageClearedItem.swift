//
//  StorageUsageClearedItem.swift
//  Telegram
//
//  Created by Mike Renoir on 24.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class StorageUsageClearedItem: GeneralRowItem {
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType) {
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return StorageUsageClearedView.self
    }
    
    override var height: CGFloat {
        return 200
    }
}

private final class StorageUsageClearedView : TableRowView {
    private var circle: ImageView?
    private var check: ImageView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

    }
    
    override func layout() {
        super.layout()
        circle?.center()
        check?.center()
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        
        let check = NSImage(named: "Icon_StorageCleared_Check")!.precomposed(theme.colors.greenUI)
        let circle = NSImage(named: "Icon_StorageCleared_Circle")!.precomposed(theme.colors.greenUI)

        let current_circle: ImageView
        if let view = self.circle {
            current_circle = view
        } else {
            current_circle = ImageView()
            self.circle = current_circle
            addSubview(current_circle)
            current_circle.image = circle
            current_circle.setFrameSize(circle.backingSize.width * 0.8, circle.backingSize.height * 0.8)

            current_circle.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            current_circle.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.45)

        }
        current_circle.image = circle
        current_circle.setFrameSize(circle.backingSize.width * 0.8, circle.backingSize.height * 0.8)
        
        let current_check: ImageView
        if let view = self.check {
            current_check = view
        } else {
            current_check = ImageView()
            self.check = current_check
            addSubview(current_check)
            current_check.image = check
            current_check.setFrameSize(check.backingSize.width * 0.8, check.backingSize.height * 0.8)

            current_check.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            current_check.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.45)

        }
        current_check.image = check
        current_check.setFrameSize(check.backingSize.width * 0.8, check.backingSize.height * 0.8)

        
        needsLayout = true
    }
}
