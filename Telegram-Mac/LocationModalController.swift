//
//  LocationModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import MapKit

private final class LocationMapView : View {
    private let mapView: MKMapView = MKMapView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(mapView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class LocationModalController: ModalViewController {

    private let chatInteraction: ChatInteraction
    init(_ chatInteraction: ChatInteraction) {
        self.chatInteraction = chatInteraction
        super.init(frame: NSMakeRect(0, 0, 360, 380))
    }
    
    override func viewClass() -> AnyClass {
        return LocationMapView.self
    }
    
    private var genericView: LocationMapView {
        return view as! LocationMapView
    }
}
