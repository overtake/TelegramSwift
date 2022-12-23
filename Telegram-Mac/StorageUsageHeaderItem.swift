//
//  StorageUsageHeaderItem.swift
//  Telegram
//
//  Created by Mike Renoir on 21.12.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class StorageUsageHeaderItem : GeneralRowItem {
    let progress: CGFloat
    let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, string: String, progress: CGFloat, viewType: GeneralViewType) {
        
        let attr = NSMutableAttributedString()
        attr.append(string: string, color: theme.colors.listGrayText, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        self.textLayout = .init(attr, alignment: .center)
        self.progress = progress
        super.init(initialSize, stableId: stableId, viewType: viewType)
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        self.textLayout.measure(width: width - 60)
        return true
    }
    
    override var height: CGFloat {
        return 10 + self.textLayout.layoutSize.height + 10
    }
    
    override func viewClass() -> AnyClass {
        return StorageUsageHeaderItemView.self
    }
}


private final class StorageUsageHeaderItemView: GeneralRowView {
    private let textView = TextView()
    private let progressView = LinearProgressControl(progressHeight: 4)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(progressView)
        progressView.roundCorners = true
        progressView.layer?.cornerRadius = 2
//        progressView.alignment = .center
        progressView.liveScrobbling = false
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        textView.centerX(y: 10)
        progressView.centerX(y: textView.frame.maxY + 5)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StorageUsageHeaderItem else {
            return
        }
        textView.update(item.textLayout)
        progressView.style = ControlStyle(foregroundColor: theme.colors.accent.withAlphaComponent(0.8), backgroundColor: theme.colors.accent.withAlphaComponent(0.2), highlightColor: .clear)
        progressView.setFrameSize(NSMakeSize(min(textView.frame.width - 40, 260), 4))

        progressView.set(progress: item.progress, animated: animated)
        needsLayout = true
    }
}
