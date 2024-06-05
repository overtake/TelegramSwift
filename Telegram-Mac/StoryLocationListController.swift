//
//  StoryLocationListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import MapKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let presentaiton: TelegramPresentationTheme
    init(context: AccountContext, presentaiton: TelegramPresentationTheme) {
        self.context = context
        self.presentaiton = presentaiton
    }
}


private final class AnnotationView : MKAnnotationView {
    private let locationPin = ImageView()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        
        self.wantsLayer = true
        
        layer?.masksToBounds = false
        
        
        
        locationPin.image = darkAppearance.icons.locationMapPin
        locationPin.sizeToFit()

        
        frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        wantsLayer = true
                        
        
        addSubview(locationPin)

        
        update()
    }
    override var annotation: MKAnnotation? {
        didSet {
            update()
        }
    }
    
    override func layout() {
        super.layout()
        locationPin.center()
        locationPin.setFrameOrigin(NSMakePoint(locationPin.frame.minX, locationPin.frame.minY - locationPin.frame.height / 2))
    }
    
    private func update() {
        
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    static var reuseIdentifier: String {
        return "peer"
    }
    
}

private class MapRowItem: GeneralRowItem {
    let context: AccountContext
    fileprivate let location: State.Location
    fileprivate let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, height: CGFloat, stableId: AnyHashable, context: AccountContext, location: State.Location, presentation: TelegramPresentationTheme, viewType: GeneralViewType, action: @escaping()->Void) {
        self.context = context
        self.location = location
        self.presentation = presentation
        super.init(initialSize, height: height + 60, stableId: stableId, viewType: viewType, action: action, inset: NSEdgeInsets())
    }
    
    deinit {
       
    }
    
    override func viewClass() -> AnyClass {
        return MapRowItemView.self
    }
    
}

private final class MapRowItemView : GeneralContainableRowView, MKMapViewDelegate {
    
    final class VenueView : View {
        private let imageView = ImageView()
        private let titleView = TextView()
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            
            imageView.image = theme.icons.locationPin
            imageView.sizeToFit()
        }
        
        override func layout() {
            super.layout()
            imageView.centerY(x: 10)
        }
        
        func update(item: MapRowItem, animated: Bool) {
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    
    private let mapView: MKMapView = MKMapView()
    private let overlay = Control()
    
    
    private let venueView: VenueView = .init(frame: .zero)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(mapView)
        mapView.register(AnnotationView.self, forAnnotationViewWithReuseIdentifier: AnnotationView.reuseIdentifier)
        mapView.delegate = self
        
        mapView.showsZoomControls = false
        mapView.showsUserLocation = false
        
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        
        mapView.showsBuildings = false
        addSubview(overlay)
        
        addSubview(venueView)
        
        overlay.set(handler: { [weak self] _ in
            if let item = self?.item as? GeneralRowItem {
                item.action()
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        mapView.delegate = nil
    }
    
    override func layout() {
        super.layout()
        mapView.frame = CGRect(origin: .zero, size: NSMakeSize(containerView.frame.width, containerView.frame.height - 60))
        overlay.frame = mapView.frame
        venueView.frame = NSMakeRect(0, mapView.frame.maxY, mapView.frame.width, 60)
    }

    
    func focusVenue() {
        guard let item = item as? MapRowItem else {
            return
        }
        let userLocation = item.location.coordinate
        var region = MKCoordinateRegion()
        var span = MKCoordinateSpan()
        span.latitudeDelta = CLLocationDegrees(0.005)
        span.longitudeDelta = CLLocationDegrees(0.005)
        var location = CLLocationCoordinate2D()
        location.latitude = userLocation.latitude
        location.longitude = userLocation.longitude
        region.span = span
        region.center = location
        mapView.setRegion(region, animated: false)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case is State.Location:
            return mapView.dequeueReusableAnnotationView(withIdentifier: AnnotationView.reuseIdentifier, for: annotation)
        default:
            return nil
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
    }
    
    func mapViewDidStopLocatingUser(_ mapView: MKMapView) {
        
    }
    
        
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
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
        
        layout()
        
        guard let item = item as? MapRowItem else {
            return
        }

        mapView.appearance = theme.appearance
        
        
    
        mapView.addAnnotation(item.location)

        focusVenue()

    }
}



private struct State : Equatable {
    class Location : NSObject, MKAnnotation {
        var coordinate: CLLocationCoordinate2D
        var venue: MapVenue?
        init(coordinate: CLLocationCoordinate2D, venue: MapVenue?) {
            self.coordinate = coordinate
            self.venue = venue
        }
    }
    
    var location: Location?
}

private let _id_map_map = InputDataIdentifier("_id_map_map")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
  
    if let location = state.location {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_map_map, equatable: .init(location), comparable: nil, item: { initialSize, stableId in
            return MapRowItem(initialSize, height: 200, stableId: stableId, context: arguments.context, location: location, presentation: arguments.presentaiton, viewType: .legacy, action: { })
        }))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func StoryLocationListController(context: AccountContext, presentation: TelegramPresentationTheme) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(location: .init(coordinate: CLLocationCoordinate2D.init(latitude: 0.1, longitude: 0.1), venue: nil))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil

    let arguments = Arguments(context: context, presentaiton: presentation)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Location")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    let modalController = InputDataModalController(controller, modalInteractions: nil)
    
    
    modalController.getModalTheme = {
        .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: presentation.colors.background, border: presentation.colors.border)
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}



