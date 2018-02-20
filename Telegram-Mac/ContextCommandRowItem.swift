//
//  ContextCommandRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 29/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

class ContextCommandRowItem: TableRowItem {

    fileprivate let _stableId:Int64
    fileprivate let account:Account
    let command:PeerCommand
    
    private let title:TextViewLayout
    private let desc:TextViewLayout
    
    private let titleSelected:TextViewLayout
    private let descSelected:TextViewLayout
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, _ account:Account, _ command:PeerCommand, _ index:Int64) {
        _stableId = index
        self.command = command
        self.account = account
        title = TextViewLayout(.initialize(string: "/" + command.command.text, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1, truncationType: .end)
        desc = TextViewLayout(.initialize(string: command.command.description, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end)
        
        titleSelected = TextViewLayout(.initialize(string: "/" + command.command.text, color: .white, font: .medium(.text)), maximumNumberOfLines: 1, truncationType: .end)
        descSelected = TextViewLayout(.initialize(string: command.command.description, color: .white, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end)
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return ContextCommandRowView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        title.measure(width: width - 60)
        desc.measure(width: width - 60)
        titleSelected.measure(width: width - 60)
        descSelected.measure(width: width - 60)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    var ctxTitle:TextViewLayout {
        return isSelected ? titleSelected : title
    }
    
    var ctxDesc:TextViewLayout {
        return isSelected ? descSelected : desc
    }
    
}



class ContextCommandRowView : TableRowView {
    private let textView:TextView = TextView()
    private let descView:TextView = TextView()
    private let photoView:AvatarControl = AvatarControl(font: .avatar(.title))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        descView.userInteractionEnabled = false
        photoView.userInteractionEnabled = false
        addSubview(textView)
        addSubview(descView)
        addSubview(photoView)
        photoView.frame = NSMakeRect(10, 5, 30, 30)
    }
    
    override func layout() {
        super.layout()
        if let item = item as? ContextCommandRowItem {
            textView.update(item.ctxTitle, origin:NSMakePoint(50, floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2 - item.ctxTitle.layoutSize.height)))
            descView.update(item.ctxDesc, origin:NSMakePoint(50, floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2)))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        if let item = item {
            return item.isSelected ? theme.colors.blueSelect : theme.colors.background
        } else {
            return theme.colors.background
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated:animated)
        if let item = item as? ContextCommandRowItem {
            photoView.setPeer(account: item.account, peer: item.command.peer)
        }
        textView.background = backdorColor
        descView.background = backdorColor
        needsLayout = true
    }
}
