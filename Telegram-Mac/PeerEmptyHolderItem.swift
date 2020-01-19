//
//  PeerEmptyHolderItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class PeerEmptyHolderItem: GeneralRowItem {
    fileprivate let photoSize: NSSize
    init(_ initialSize: NSSize, stableId: AnyHashable, height: CGFloat, photoSize: NSSize, viewType: GeneralViewType) {
        self.photoSize = photoSize
        super.init(initialSize, height: height, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return PeerEmptyHolderView.self
    }
}

class PeerEmptyHolderView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let photoView: View = View()
    private let firstNameView = View()
    private let lastNameView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(firstNameView)
        containerView.addSubview(lastNameView)
        containerView.addSubview(photoView)
        addSubview(containerView)
        
        firstNameView.setFrameSize(NSMakeSize(50, 10))
        lastNameView.setFrameSize(NSMakeSize(50, 10))
        
        firstNameView.layer?.cornerRadius = 5
        lastNameView.layer?.cornerRadius = 5
    }
    
    override func viewDidMoveToWindow() {

    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        if let item = item as? GeneralRowItem {
            containerView.background = backdorColor
            backgroundColor = item.viewType.rowBackground
            photoView.backgroundColor = theme.colors.grayBackground
            firstNameView.backgroundColor = theme.colors.grayBackground
            lastNameView.backgroundColor = theme.colors.grayBackground
        }
    }
    
    override func layout() {
        super.layout()
        
        if let item = item as? PeerEmptyHolderItem {
            switch item.viewType {
            case .legacy:
                containerView.frame = bounds
            case .modern:
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
            }
            self.containerView.setCorners(item.viewType.corners)
            
            
            photoView.centerY(x: 10)
            
            firstNameView.centerY(x: photoView.frame.maxX + 10)
            lastNameView.centerY(x: firstNameView.frame.maxX + 10)
        }
    }
    
    deinit {
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? PeerEmptyHolderItem {
            let contentRect: NSRect
            switch item.viewType {
            case .legacy:
                contentRect = bounds
            case .modern:
                contentRect = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
            }
            self.containerView.change(size: contentRect.size, animated: animated, corners: item.viewType.corners)
            self.containerView.change(pos: contentRect.origin, animated: animated)
            
            photoView.setFrameSize(item.photoSize)
            photoView.layer?.cornerRadius = item.photoSize.height / 2
            needsLayout = true
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
