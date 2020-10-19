//
//  LocationPreviewMapRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import MapKit
import TelegramCore
import SyncCore
import Postbox


private final class MapPin : NSObject, MKAnnotation
{
    let coordinate: CLLocationCoordinate2D
    let peer: Peer?
    let account: Account
    
    var focusRegion: (()->Void)?
    
    init (coordinate: CLLocationCoordinate2D, account: Account, peer: Peer?)
    {
        self.coordinate = coordinate
        self.peer = peer
        self.account = account
    }
    
    
}

private final class MapPinView: View {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        background = .random
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class LocationAnnotationView : MKAnnotationView {
    private let avatar = AvatarControl(font: .avatar(14))
    private let border = View()
    fileprivate let control = OverlayControl()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        
        frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        wantsLayer = true
        
        
        border.setFrameSize(NSMakeSize(42, 42))
        border.layer?.cornerRadius = border.frame.width / 2
        border.background = .white
        addSubview(border)
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSMakeSize(0, 0)
        self.border.shadow = shadow
        
        
        avatar.setFrameSize(NSMakeSize(40, 40))
        avatar.layer?.cornerRadius = avatar.frame.width / 2
        addSubview(avatar)
        
        control.frame = bounds
        
        addSubview(control)
        
        control.set(handler: { [weak self] _ in
            var bp:Int = 0
            bp += 1
            (self?.annotation as? MapPin)?.focusRegion?()
        }, for: .Click)
        
        update()
    }
    override var annotation: MKAnnotation? {
        didSet {
            update()
        }
    }
    
    override func layout() {
        avatar.center()
        border.center()
    }
    
    private func update() {
        
        if let annotation = self.annotation as? MapPin {
            self.avatar.setPeer(account: annotation.account, peer: annotation.peer)
        }
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    static var reuseIdentifier: String {
        return "peer"
    }
    
}
@available(macOS 10.13, *)
class LocationPreviewMapRowItem: GeneralRowItem {
    let map: TelegramMediaMap
    let peer: Peer?
    let context: AccountContext
    fileprivate let pin: MapPin
    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable, context: AccountContext, map: TelegramMediaMap, peer: Peer?, viewType: GeneralViewType) {
        self.map = map
        self.peer = peer
        self.context = context
        self.pin = MapPin(coordinate: CLLocationCoordinate2D(latitude: map.latitude, longitude: map.longitude), account: context.account, peer: peer)
        super.init(initialSize, height: height, stableId: stableId, viewType: viewType)
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override func viewClass() -> AnyClass {
        return LocationPreviewMapRowView.self
    }
    
}

@available(macOS 10.13, *)
private final class LocationPreviewMapRowView : TableRowView, MKMapViewDelegate {
    private let mapView: MKMapView = MKMapView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(mapView)
        mapView.register(LocationAnnotationView.self, forAnnotationViewWithReuseIdentifier: LocationAnnotationView.reuseIdentifier)
        mapView.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        mapView.delegate = nil
    }
    
    override func layout() {
        super.layout()
        mapView.frame = bounds
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case is MapPin:
            return mapView.dequeueReusableAnnotationView(withIdentifier: LocationAnnotationView.reuseIdentifier, for: annotation)
        default:
            return nil
        }
    }
    
    private var doNotUpdateRegion: Bool = false
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if location != nil {
            doNotUpdateRegion = true
        }
    }

    private var location: NSPoint? = nil
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        location = nil
       
    }
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        location = event.locationInWindow
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        let previousItem = self.item
        super.set(item: item, animated: animated)
        
        mapView.showsZoomControls = true
        
        guard let item = item as? LocationPreviewMapRowItem else {
            return
        }
        
        let focus:(Bool)->Void = { [weak self, unowned item] animated in
            let center = CLLocationCoordinate2D(latitude: item.map.latitude, longitude: item.map.longitude)
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            self?.mapView.setRegion(region, animated: animated)
            self?.doNotUpdateRegion = false
        }
        
        if !doNotUpdateRegion {
            focus(animated)
        }
        
        if let previousItem = previousItem as? LocationPreviewMapRowItem {
            mapView.removeAnnotation(previousItem.pin)
        }
        item.pin.focusRegion = {
            focus(true)
        }
        
        mapView.addAnnotation(item.pin)
    }
}
