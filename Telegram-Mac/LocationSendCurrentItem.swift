//
//  LocationSendCurrent.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import MapKit
enum LocationSelectCurrentState : Equatable {
    case accurate(location: CLLocation?, expanded: Bool)
    case selected(location: String)
}

class LocationSendCurrentItem: GeneralRowItem {
    fileprivate let statusLayout: TextViewLayout
    fileprivate let state: LocationSelectCurrentState
    init(_ initialSize: NSSize, stableId: AnyHashable, state: LocationSelectCurrentState, action:@escaping()->Void) {
        self.state = state
        let text: String
        switch state {
        case let .accurate(location, _):
            if let location = location {
                let formatter = MKDistanceFormatter()
                formatter.unitStyle = .full
                formatter.locale = Locale(identifier: appAppearance.language.languageCode)
                let formatted = formatter.string(fromDistance: location.horizontalAccuracy)
                text = L10n.locationSendAccurateTo("\(formatted)")
            } else {
                text = L10n.locationSendLocating
            }
            
        case let .selected(location):
            text = location
        }
        statusLayout = TextViewLayout.init(.initialize(string: text, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 60, stableId: stableId, action: action, inset: NSEdgeInsetsMake(0, 10, 0, 10))
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        statusLayout.measure(width: width - inset.left - inset.right - theme.icons.locationPin.backingSize.width - 10)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return LocationSendCurrentView.self
    }
}


private final class LocationSendCurrentView : TableRowView {
    private let iconView: ImageView = ImageView()
    private let statusView = TextView()
    private let button: TitleButton = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
        addSubview(iconView)
        addSubview(statusView)
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        button.userInteractionEnabled = false
        button.isEventLess = true
        statusView.isEventLess = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() {
            guard let item = item as? GeneralRowItem else {return}
            item.action()
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? LocationSendCurrentItem else {return}

        
        button.set(font: .medium(.title), for: .Normal)
        button.set(color: theme.colors.blueUI, for: .Normal)
        let text: String
        switch item.state {
        case .accurate:
            text = L10n.locationSendMyLocation
        case .selected:
            text = L10n.locationSendThisLocation
        }
        button.set(text: text, for: .Normal)
        _ = button.sizeToFit()
        
        statusView.update(item.statusLayout)
        
        iconView.image = theme.icons.locationPin
        _ = iconView.sizeToFit()
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        guard let item = item as? LocationSendCurrentItem else {return}
        
        switch item.state {
        case let .accurate(_, expanded):
            if expanded {
                ctx.setFillColor(theme.colors.border.cgColor)
                ctx.fill(NSMakeRect(statusView.frame.minX, frame.height - .borderSize, frame.width - statusView.frame.minX, .borderSize))
            }
        default:
            break
        }
        
    }
    
    override func layout() {
        guard let item = item as? GeneralRowItem else {return}
        
        iconView.centerY(x: item.inset.left)
        
        button.setFrameOrigin(iconView.frame.maxX + 3, frame.height / 2 - button.frame.height)
        statusView.setFrameOrigin(iconView.frame.maxX + 10,  frame.height / 2)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
